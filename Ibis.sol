/**
 * Define primary business logic for the Ibis token. The module includes code
 * for handling standard user accounting (deposit/withdraw/transfer), mechanisms
 * for freezing and liquidiating rogue or lost accounts, and contract
 * upgrades. This contract inherits restricted access control and democratic
 * voting from parent contracts.
 */

pragma solidity ^0.4.13;

import "./Token.sol";
import "./Restricted.sol";
import "./Democratic.sol";
import "./Core.sol";

/// Implements the Ibis charity currency as an ERC20 token.
contract Ibis is Token, Restricted, Democratic {

    // constant values
    uint MAX_UINT256 = 2**256-1;                 // maximum unsigned integer value
    uint constant MAJORITY = 50;                 // majority percentage (voting)
    uint constant SUPERMAJORITY = 67;            // supermajority percentage (voting)
    uint constant VOTE_DURATION = 960 * 7;       // # of blocks per voting period
    uint constant MAX_NUKES = 3;                 // # of nukes available to nuke master

    // human standard token fields
    string public name = "Ibis";
    string public symbol = "IBI";
    string public version = '1.1';
    uint8 public decimals = 18;

    // address of core contract core
    Core core;

    // address freezing/redistribution
    uint public awardMax;                      // maximum award that can be claimed in one block
    uint public frozenMinTime;                 // min time between freezing and redistribution
    uint public awardMinTime;                  // min time to wait for charities to claim reward
    mapping(uint => uint) awardValue;          // value of award at a given block
    mapping(uint => address) awardClosest;     // current winning bid for block award
    mapping(address => bool) frozenVoted;      // votes cast by previously frozen accounts

    // initial grace period emergency update
    uint graceInit;
    uint graceDuration = 960 * 21;

    // if true then system has been nuked
    bool nuked;

    // business logic events
    event LogDeposit(address indexed _from, uint _value);
    event LogWithdraw(address indexed _to, uint _value);
    event LogChangeCharities(address indexed _charity, bool _isCharity);
    event LogFreeze(address indexed _account, bool frozen);
    event LogAward(uint indexed _blocknum, address _addr, string _state);
    event LogUpgrade(address _addr);

    /// Define restricted ownership, voting parameters, and the Core contract
    function Ibis(address _core, address [] _owners, uint _ownerThreshold, address nukeMaster)
        Restricted(_owners, _ownerThreshold, nukeMaster) Democratic(VOTE_DURATION, MAX_NUKES)
    {
	graceInit = block.number;
	core = Core(_core);
    }

    ///-------------------------------- User Account Methods --------------------------------///

    // Return the balance of an address
    function balanceOf(address _owner) constant returns (uint) {
	return core.balances(_owner);
    }

    /// Transfer value from the sending address to a given recipient
    function transfer(address _to, uint _value) returns (bool) {
	if(core.balances(msg.sender) >= _value) {
	    core.transfer(msg.sender, _to, _value);
	    Transfer(msg.sender, _to, _value);
	    return true;
	}
    }

    /// Transfer value on behalf of another account if approved by the owner
    function transferFrom(address _from, address _to, uint _value) returns (bool) {
        if(core.balances(_from) >= _value && core.allowed(_from, msg.sender) >= _value) {
	    core.transfer(_from, _to, _value);
	    core.setAllowed(_from, msg.sender, core.allowed(_from, msg.sender) - _value);
	    Transfer(_from, _to, _value);
	    return true;
	}
    }

    /// Convert Ether to Ibis coins for the message sender
    function deposit() payable {
	depositTo(msg.sender);
    }

    /// Convert Ether to Ibis coins for an address other than the message sender
    function depositTo(address _to) payable {
        core.setBalances(_to, core.balances(_to) + msg.value);
	totalSupply += msg.value;
	LogDeposit(_to, msg.value);
    }

    /// Convert Ibis coins to Ether for message sender
    function withdraw(uint _value) suspendable returns (bool) {
	if ((core.charityStatus(msg.sender) || nuked) && _value <= core.balances(msg.sender)) {
	    core.setBalances(msg.sender, core.balances(msg.sender) - _value);
	    totalSupply -= _value;
	    msg.sender.transfer(_value);
	    LogWithdraw(msg.sender, _value);
	    return true;
	}
    }

    /// Convert Ibis coins to Ether for someone other than message sender (requires pre-approval)
    function withdrawFrom(address _from, uint _value) suspendable returns (bool) {
	if((core.charityStatus(_from) || nuked) && core.balances(_from) >= _value &&
	   core.allowed(_from, msg.sender) >= _value) {
	    core.setBalances(_from, core.balances(_from) - _value);
	    core.setAllowed(_from, msg.sender, core.allowed(_from, msg.sender) - _value);
	    totalSupply -= _value;
	    _from.transfer(_value);
	    LogWithdraw(_from, _value);
	    return true;
 	}
    }

    /// Approve a third party address to manage funds on behalf of the owner
    function approve(address _spender, uint _value) returns (bool) {
	core.setAllowed(msg.sender, _spender, _value);
	Approval(msg.sender, _spender, _value);
	return true;
    }

    /// Return the amount by which a third party is approved to transfer an owner's funds
    function allowance(address _owner, address _spender) constant returns (uint) {
	return core.allowed(_owner, _spender);
    }

    /// Approve a third party to manange funds and callback a predesignated function signature
    function approveAndCall(address _spender, uint _value, bytes _extraCore) returns (bool) {
        core.setAllowed(msg.sender, _spender, _value);
        Approval(msg.sender, _spender, _value);

        if(!_spender.call(bytes4(sha3("receiveApproval(address,uint,address,bytes)")),
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
	uint blocknum = block.number;
	for(uint i = 0; i < _accounts.length; i++) {
	    uint balance = core.balances(_accounts[i]);
	    core.setBalances(_accounts[i], 0);
	    core.setFrozenValue(_accounts[i], balance);
	    core.setFrozenBlocknum(_accounts[i], blocknum);
	    LogFreeze(_accounts[i], true);
	}
    }

    /// Reinstantiate frozen accounts
    function unfreezeAccounts(address[] _accounts) isOwner delayed(sha3(msg.data)) suspendable {
	for(uint i = 0; i < _accounts.length; i++) {
	    uint frozen = core.frozenValue(_accounts[i]);
	    core.setFrozenValue(_accounts[i], 0);
	    core.setFrozenBlocknum(_accounts[i], 0);
	    core.setBalances(_accounts[i], frozen);
	    LogFreeze(_accounts[i], false);
	}
    }

    /// Liquidate frozen accounts and offer funds as reward for a randomly selected charity
    function awardExcess(address[] _accounts) multiowner(sha3(msg.data)) delayed(sha3(msg.data)) {
	uint frozenAward;

	for(uint i = 0; i < _accounts.length; i++) {
	    if(core.frozenBlocknum(_accounts[i]) + frozenMinTime < block.number) {
		continue;
	    }
	    uint frozen = core.frozenValue(_accounts[i]);
	    if(frozenAward + frozen <= awardMax) {
		core.setFrozenValue(_accounts[i], 0);
		frozenAward += frozen;
	    }
	    else {
		core.setFrozenValue(_accounts[i], frozen - (awardMax - frozenAward));
		frozenAward = awardMax;
		break;
	    }
	}
	awardValue[block.number] = frozenAward;
	awardClosest[block.number] = address(MAX_UINT256);
	LogAward(block.number, address(MAX_UINT256), "initialized");
    }

    /// Claim that a charity is the closest to the random target for a given award
    function claimAward(uint _blocknum, address _charity) suspendable returns (bool) {

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
    function cashAward(uint _blocknum, address _charity) suspendable returns (bool) {
	if(_blocknum <= block.number - awardMinTime && awardClosest[_blocknum] == _charity) {
	    uint award = awardValue[_blocknum];
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
    function setAwardMinTime(uint _awardMinTime) multiowner(sha3(msg.data))
	delayed(sha3(msg.data)) {
	awardMinTime = _awardMinTime;
    }

    /// Set the maximum amount of funds that can be placed on a single block
    function setAwardMax(uint _awardMax) multiowner(sha3(msg.data))
	delayed(sha3(msg.data)) {
	awardMax = _awardMax;
    }

    ///---------------------------------- Upgrade Methods -----------------------------------///

    /// Standard path to propose a new controlling contract
    function upgradeStandard(address _addr) multiowner(sha3(msg.data)) suspendable
	votable(sha3(msg.data), MAJORITY, false) {
	upgrade(_addr);
    }

    /// Emergency path to upgrade contracts if majority owner keys have been compromised
    function upgradeInitEmergency(address _addr) isOwner suspendable
	votable(sha3(msg.data), SUPERMAJORITY, false) {

	upgrade(_addr);
    }

    /// Emergency path to upgrade if something has gone wrong within the grace period
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
    function init(uint totalSupply) returns (bool);
}
