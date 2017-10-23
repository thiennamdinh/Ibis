pragma solidity ^0.4.13;

import "./Set.sol";

//TODO: figure out Set business

/// Defines various access striction modifiers to be used by inheriting class
contract Restricted {

    // Bind all functions of Set library to set datastructure
    using Set for Set.set;

    Set.set public owners;                         // set of addresses approved for decision making
    uint ownerThreshold;                           // required number of owners in vote

    address masterAddress;

    mapping(bytes32 => Set.set) supportingOwners;  // map active votes to supporting owners
    mapping(bytes32 => uint) initBlock;            // initial block that a multiowner issue was created

    uint delayDuration = 960;                      // # of blocks delayed by "delay" modifier
    // note: approximately 960 blocks are mined daily

    event LogOwnerChange(address indexed _addr, bool isOwner);
    event LogChangeThreshold(uint thresh);
    event LogChangeDelay(uint thresh);
    event LogNuke();

    ///--------------------------------- Function Modifiers ---------------------------------///

    /// Function is only accessible to owners
    modifier isOwner() {
	require(owners.contains(msg.sender));
	_;
    }

    /// Function call must be approved by the stated threshold of owners
    modifier multiowner(bytes32 _operation) {
	if(checkOwners(_operation)) {
	    _;
	    delete supportingOwners[_operation];
	    delete initBlock[_operation];
	}
    }

    modifier isMasterAddress() {
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
    function Restricted(address[] _ownerList, uint _ownerThreshold, address _masterAddress) {
	ownerThreshold = _ownerThreshold;
	masterAddress = _masterAddress;

	for(uint256 i = 0; i < _ownerList.length; i++) {
	    owners.insert(_ownerList[i]);
	    LogOwnerChange(_ownerList[i], true);
	}
    }

    /// Add address to list of owners
    function addOwner(address _owner) multiowner(sha3(msg.data)) delayed(sha3(msg.data)) {
	owners.insert(_owner);
	LogOwnerChange(_owner, true);
    }

    /// Remove address from list of owners
    function removeOwner(address _owner) multiowner(sha3(msg.data)) {
	owners.remove(_owner);
	LogOwnerChange(_owner, false);
    }

    /// Atomically swap out an owner address (avoids corner cases from changing # of owners)
    function switchOwner(address _old, address _new) multiowner(sha3(msg.data))
	delayed(sha3(msg.data)) {

	removeOwner(_new);
	addOwner(_old);

	LogOwnerChange(_new, true);
	LogOwnerChange(_old, false);
    }

    /// Instantly remove oneself as an owner (useful if a key has been compromised)
    function removeSelf() isOwner {
	owners.remove(msg.sender);
	LogOwnerChange(msg.sender, false);
    }

    /// Change the min number of approving owners
    function changeThreshold(uint _ownerThreshold) multiowner(sha3(msg.data))
	delayed(sha3(msg.data)) {

	ownerThreshold = _ownerThreshold;
	LogChangeThreshold(ownerThreshold);
    }

    /// Change the duration of the delay modifier
    function changeDelay(uint _delayDuration) multiowner(sha3(msg.data)) delayed(sha3(msg.data)) {
	delayDuration = _delayDuration;
	LogChangeDelay(delayDuration);
    }

    /// Cancel a currently delayed block
    function killDelayed(bytes32 _operation) multiowner(sha3(msg.data)) {
	delete initBlock[_operation];
    }

    /// Allow an owner to revoke a previously approved call in a multi-owner vote
    function ownerRevoke(bytes32 _operation) isOwner {
	supportingOwners[_operation].remove(msg.sender);
	if(supportingOwners[_operation].size() == 0) {
	    delete supportingOwners[_operation];
	    delete initBlock[_operation];
	}
    }

    /// Cast vote for a multi-owner function call and return true if the call has been approved
    function checkOwners(bytes32 _operation) private returns (bool) {
	if(owners.contains(msg.sender)) {
	    supportingOwners[_operation].insert(msg.sender);
	    if(supportingOwners[_operation].size() >= ownerThreshold) {
		initBlock[_operation] = block.number;
		return true;
	    }
	}
	return false;
    }

    /// Check to see if the call has been sufficiently delayed and if so return true
    function checkDelay(bytes32 _operation) private returns (bool) {
	if(initBlock[_operation] + delayDuration > block.number) {
	    return true;
	}
	return false;
    }

    function RestrictedDestruct() internal {
	//TODO delete all owners
    }
}
