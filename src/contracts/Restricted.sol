pragma solidity ^0.4.13;

/// Defines various access striction modifiers to be used by inheriting class
contract Restricted {

    uint256 MAX_UINT256 = 2**256-1;
    uint numOwners;
    uint threshold;
    mapping(address => bool) public owners;

    address masterAddress;

    mapping(bytes32 => mapping(address => bool)) supporting;
    mapping(bytes32 => uint) numSupporting;
    mapping(bytes32 => uint) initBlock;

    uint public delayDuration;

    event LogOwnerChange(address indexed _addr, bool isOwner);
    event LogChangeThreshold(uint thresh);
    event LogChangeDelay(uint thresh);
    event LogNuke();

    ///--------------------------------- Function Modifiers ---------------------------------///

    /// Function is only accessible to owners
    modifier isOwner() {
	require(owners[msg.sender] == true);
	_;
    }

    /// Function call must be approved by the stated threshold of owners
    modifier multiowner(bytes32 _operation) {
	if(checkOwners(_operation)) {
	    _;
	    delete initBlock[_operation];
	}
    }

    modifier isMaster() {
	if(msg.sender == masterAddress) {
	    _;
	}
    }

    /// Function call will be delayed by a set number of blocks regardless of approval
    modifier delayed(bytes32 _operation) {
	if(checkDelay(_operation)) {
	    _;
	    delete initBlock[_operation];
	}
    }

    ///---------------------------------- Public Methods ------------------------------------///

    /// Constructor takes a list of owners and a threshold
    function Restricted(address[] _ownerList, uint _threshold, address _masterAddress,
			uint _delayDuration) public {

	threshold = _threshold;
	delayDuration = _delayDuration;
	LogChangeThreshold(threshold);

	masterAddress = _masterAddress;

	for(uint256 i = 0; i < _ownerList.length; i++) {
	    owners[_ownerList[i]] = true;
	    numOwners++;
	    LogOwnerChange(_ownerList[i], true);
	}
    }

    /// Add address to list of owners
    function addOwner(address _owner) public multiowner(keccak256(msg.data))
	delayed(keccak256(msg.data)) {
	owners[_owner] = true;
	numOwners++;
	LogOwnerChange(_owner, true);
    }

    /// Remove address from list of owners
    function removeOwner(address _owner) public multiowner(keccak256(msg.data)) {
	owners[_owner] = false;
	numOwners--;
	LogOwnerChange(_owner, false);
    }

    /// Atomically swap out an owner address (avoids corner cases from changing # of owners)
    function switchOwner(address _old, address _new) public multiowner(keccak256(msg.data))
	delayed(keccak256(msg.data)) {

	owners[_old] = false;
	owners[_new] = true;

	LogOwnerChange(_old, false);
	LogOwnerChange(_new, true);
    }

    /// Instantly remove oneself as an owner (useful if a key has been compromised)
    function removeSelf() public isOwner {
	owners[msg.sender] = false;
	LogOwnerChange(msg.sender, false);
    }

    /// Change the min number of approving owners
    function changeThreshold(uint _threshold) public multiowner(keccak256(msg.data))
	delayed(keccak256(msg.data)) {

	threshold = _threshold;
	LogChangeThreshold(threshold);
    }

    /// Change the duration of the delay modifier
    function changeDelay(uint _delayDuration) public multiowner(keccak256(msg.data))
	delayed(keccak256(msg.data)) {
	delayDuration = _delayDuration;
	LogChangeDelay(delayDuration);
    }

    /// Cancel a currently delayed block
    function killDelayed(bytes32 _operation) public multiowner(keccak256(msg.data)) {
	delete initBlock[_operation];
    }

    /// Allow an owner to revoke a previously approved call in a multi-owner vote
    function ownerRevoke(bytes32 _operation) public isOwner {
	supporting[_operation][msg.sender] = false;
	if(numSupporting[_operation] == 0) {
	    delete initBlock[_operation];
	}
    }

    /// Cast vote for a multi-owner function call and return true if the call has been approved
    function checkOwners(bytes32 _operation) private returns (bool) {
	if(owners[msg.sender] == true && supporting[_operation][msg.sender] == false) {
	    supporting[_operation][msg.sender] == true;
	    numSupporting[_operation]++;
	    if(numSupporting[_operation] >= threshold) {
		initBlock[_operation] = block.number;
		return true;
	    }
	}
	return false;
    }

    /// Check to see if the call has been sufficiently delayed and if so return true
    function checkDelay(bytes32 _operation) private view returns (bool) {
	if(initBlock[_operation] == 0) {
	    initBlock[_operation] = block.number;
	}

	if(block.number >= initBlock[_operation] + delayDuration) {
	    return true;
	}
    }

    function RestrictedDestruct() internal {
	threshold = MAX_UINT256;
    }
}
