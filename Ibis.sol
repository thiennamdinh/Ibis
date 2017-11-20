pragma solidity ^0.4.13;

import "./Token.sol";
import "./Restricted.sol";
import "./Democratic.sol";
import "./Core.sol";

/// Implements the Ibis charity currency as an ERC20 token.
contract Ibis is Token, Restricted, Democratic {

    // constant values
    uint256 MAX_UINT256 = 2**256-1;
    uint constant MAJORITY = 50;
    uint constant SUPERMAJORITY = 67;
    uint constant VOTE_DURATION = 960 * 7;         // # of blocks per voting period
    uint constant MAX_NUKES = 3;

    // human standard token fields
    string public name = "Ibis";
    string public symbol = "IBI";
    string public version = '1.1';
    uint8 public decimals = 18;

    // address of core contract core
    Core core;

    // state for address freezing/redistribution
    uint256 public awardMax;                      // maximum award that can be claimed in one block
    uint public frozenMinTime;                    // min time between freezing and redistribution
    uint public awardMinTime;                     // min time to wait for charities to claim reward
    mapping(uint => uint256) awardValue;          // value of award at a given block
    mapping(uint => address) awardClosest;        // current winning bid for block award
    mapping(address => bool) frozenVoted;         // votes cast by previously frozen accounts

    // state to allow immediate upgrade within the initial "grace period"
    uint graceInit;
    uint graceDuration = 960 * 21;

    // signals that the system has been nuked by the master address
    bool nuked;

    // custom events (non ERC20)
    event LogDeposit(address indexed _from, uint _value);
    event LogWithdraw(address indexed _to, uint _value);
    event LogChangeCharities(address indexed _charity, bool _isCharity);
    event LogFreeze(address indexed _account, bool frozen);
    event LogAward(uint indexed _blocknum, address _addr, string _state);
    event LogUpgrade(address _addr);

    /// Assign ownership of contract and establish Ibis as the charity firstonly
    function Ibis(address _core, address [] _owners, uint _ownerThreshold, address nukeMaster)
        Restricted(_owners, _ownerThreshold, nukeMaster) Democratic(VOTE_DURATION, MAX_NUKES)
    {
	graceInit = block.number;
	core = Core(_core);
    }

    // Return the balance of an address
    function balanceOf(address _owner) constant returns (uint256) {
	return core.balances(_owner);
    }

    /// Transfer value from the sending address to a given recipient
    function transfer(address _to, uint256 _value) returns (bool) {
	if(core.balances(msg.sender) >= _value && _value > 0) {
	    core.transfer(msg.sender, _to, _value);
	    Transfer(msg.sender, _to, _value);
	    return true;
	}
    }

    /// Transfer value on behalf of another account if approved by the owner
    function transferFrom(address _from, address _to, uint256 _value) returns (bool) {
        if(core.balances(_from) >= _value && core.allowed(_from, msg.sender) >= _value
	   && _value > 0) {
	    core.transfer(_from, _to, _value);
	    core.setAllowed(_from, msg.sender, core.allowed(_from, msg.sender) - _value);
	    Transfer(_from, _to, _value);
	    return true;
	}
    }

    /// Convert Ether to Ibis coins for the message sender
    function deposit() payable {
	//core.setBalances(msg.sender, core.balances(msg.sender) + msg.value);
	core.setBalances(msg.sender, msg.value);
	totalSupply += msg.value;
	LogDeposit(msg.sender, msg.value);
    }

    /// Convert Ether to Ibis coins for an address other than the message sender
    function depositTo(address _to) payable {
        core.setBalances(_to, core.balances(_to) + msg.value);
	totalSupply += msg.value;
	LogDeposit(_to, msg.value);
    }

    /// Convert Ibis coins to Ether for message sender
    function withdraw(uint256 _value) suspendable returns (bool) {
	if ((core.charityStatus(msg.sender) || nuked) && _value <= core.balances(msg.sender)
	    && _value > 0) {
	    core.setBalances(msg.sender, core.balances(msg.sender) - _value);
	    totalSupply -= _value;
	    msg.sender.transfer(_value);
	    LogWithdraw(msg.sender, _value);
	    return true;
	}
    }

    /// Convert Ibis coins to Ether for someone other than message sender (requires pre-approval)
    function withdrawFrom(address _from, uint256 _value) suspendable returns (bool) {
	if((core.charityStatus(_from) || nuked) && core.balances(_from) >= _value &&
	   core.allowed(_from, msg.sender) >= _value && _value > 0) {
	    core.setBalances(_from, core.balances(_from) - _value);
	    totalSupply -= _value;
	    _from.transfer(_value);
	    LogWithdraw(_from, _value);
	    return true;
 	}
    }

    /// Approve a third party address to manage funds on behalf of the owner
    function approve(address _spender, uint256 _value) returns (bool) {
	core.setAllowed(msg.sender, _spender, _value);
	Approval(msg.sender, _spender, _value);
	return true;
    }

    /// Return the amount by which a third party is approved to transfer an owner's funds
    function allowance(address _owner, address _spender) constant returns (uint256) {
	return core.allowed(_owner, _spender);
    }

    /// Approve a third party to manange funds and callback a predesignated function signature
    function approveAndCall(address _spender, uint256 _value, bytes _extraCore) returns (bool) {
        core.setAllowed(msg.sender, _spender, _value);
        Approval(msg.sender, _spender, _value);

        if(!_spender.call(bytes4(sha3("receiveApproval(address,uint256,address,bytes)")),
			  msg.sender, _value, this, _extraCore)) {
	    revert();
	}
        return true;
    }

    /// Approve a new charity
    function addCharity(address _charity) isOwner delayed(sha3(msg.data)) returns (bool) {
	if(!core.charityStatus(_charity)) {
	    core.setCharityStatus(_charity, true);
	    core.setCharityBlocknum(_charity, block.number);
	    LogChangeCharities(_charity, true);
	    return true;
	}
    }

    /// Remove an existing charity
    function removeCharity(address _charity) isOwner delayed(sha3(msg.data)) returns (bool) {
	if(core.charityStatus(_charity)) {
	    core.setCharityStatus(_charity, false);
	    core.setCharityBlocknum(_charity, 0);
	    LogChangeCharities(_charity, false);
	    return true;
	}
    }

    ///---------------------------------- Freeze Methods ------------------------------------///

    /// Suspend accounts by moving the existing balance into a frozen funds table
    function freezeAccounts(address[] _accounts) isOwner suspendable {
	uint blocknum = block.number + frozenMinTime;
	for(uint i = 0; i < _accounts.length; i++) {
	    uint256 balance = core.balances(_accounts[i]);
	    core.setBalances(_accounts[i], 0);
	    core.setFrozenValue(_accounts[i], balance);
	    core.setFrozenBlocknum(_accounts[i], blocknum);
	    LogFreeze(_accounts[i], true);
	}
    }

    /// Reinstantiate frozen accounts
    function unfreezeAccounts(address[] _accounts) isOwner delayed(sha3(msg.data)) suspendable {
	for(uint i = 0; i < _accounts.length; i++) {
	    uint256 frozen = core.frozenValue(_accounts[i]);
	    core.setFrozenValue(_accounts[i], 0);
	    core.setFrozenBlocknum(_accounts[i], 0);
	    core.setBalances(_accounts[i], frozen);
	    LogFreeze(_accounts[i], false);
	}
    }

    /// Liquidate frozen accounts and offer funds as reward for a randomly selected charity
    function awardExcess(address[] _accounts) multiowner(sha3(msg.data)) delayed(sha3(msg.data)) {
	uint256 frozenAward;

	for(uint i = 0; i < _accounts.length; i++) {
	    uint256 frozen = core.frozenValue(_accounts[i]);
	    if(frozenAward + frozen < awardMax) {
		core.setFrozenValue(_accounts[i], 0);
		frozenAward += frozen;
	    }
	    else {
		core.setFrozenValue(_accounts[i], frozen - (awardMax - frozenAward));
		frozenAward = awardMax;
	    }
	}
	awardValue[block.number] = frozenAward;
	awardClosest[block.number] = address(MAX_UINT256);
	LogAward(block.number, address(MAX_UINT256), "initialized");
    }

    /// Claim that a charity is the closest to the random target for a given award
    function claimAward(uint256 _blocknum, address _charity) suspendable returns (bool) {

	uint target = uint(address(block.blockhash(_blocknum)));
	uint closest = uint(awardClosest[_blocknum]);
	uint challenge = uint(_charity);

	if(target - challenge < target - closest) {
	    awardClosest[_blocknum] = _charity;
	    LogAward(_blocknum, _charity, "claimed");
	    return true;
	}
    }

    /// Move funds into the balance of a winning charity after enough time has passed
    function cashAward(uint256 _blocknum, address _charity) suspendable returns (bool) {
	if(_blocknum < block.number - awardMinTime && awardClosest[_blocknum] == _charity) {
	    uint256 award = awardValue[_blocknum];
	    delete awardValue[_blocknum];
	    delete awardClosest[_blocknum];
	    core.setBalances(_charity, core.balances(_charity) + award);
	    LogAward(_blocknum, _charity, "awarded");
	    return true;
	}
    }

    /// Set the minimum time for an account to be frozen before distribution (block height)
    function setFrozenMinTime(uint _frozenMinTime) multiowner(sha3(msg.data))
	delayed(sha3(msg.data)) {
	frozenMinTime = _frozenMinTime;
    }

    /// Set the window of time that charities can claim to be the closest to an award
    function setAwardMinTime(uint _awardMinTime) multiowner(sha3(msg.data)) {
	awardMinTime = _awardMinTime;
    }

    /// Set the maximum amount of funds that can be placed on a single block
    function setAwardMax(uint _awardMax) multiowner(sha3(msg.data)) {
	awardMax = _awardMax;
    }

    ///---------------------------------- Upgrade Methods -----------------------------------///

    /// Standard path to propose a new controlling contract
    function upgradeStandard(address _addr) multiowner(sha3(msg.data)) suspendable
	votable(sha3(msg.data), MAJORITY, false)
    {
	upgrade(_addr);
    }

    /// Emergency path to upgrade contracts if majority owner keys have been compromised
    function upgradeInitEmergency(address _addr) isOwner suspendable
	votable(sha3(msg.data), SUPERMAJORITY, false) {

	upgrade(_addr);
    }

    /// Emergency path to upgrade if something has gone wrong at first
    function upgradeInitial(address _addr) isOwner() {
	if(graceInit + graceDuration < block.number) {
	    upgrade(_addr);
	}
    }

    /// Perform actual upgrade
    function upgrade(address _addr) internal {
	if(IbisNew(_addr).init(totalSupply)) {
	    core.upgrade(_addr);
	    LogUpgrade(_addr);
	    selfdestruct(_addr);
	}
    }

    ///---------------------------------- Nuke Methods -----------------------------------///

    /// Supermajority vote to nuke the contract logic and allow free ether withdrawal
    function nuke() isMaster votable(sha3(msg.data), SUPERMAJORITY, true) {
	RestrictedDestruct();
	nuked = true;
    }
}

/// Abstract contract placeholder to facilitate a future transition to the next version of Ibis
contract IbisNew {
    /// This method will be implemented in the future contract version to process legacy data
    function init(uint256 totalSupply) returns (bool);
}
