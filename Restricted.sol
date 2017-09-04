pragma solidity ^0.4.13;

import "./Set.sol";

/// Defines various access striction modifiers to be used by inheriting class
contract Restricted {

    uint constant MAJORITY = 50;
    uint constant SUPERMAJORITY = 67;

    // Bind all functions of Set library to set datastructure
    using Set for Set.set;

    Set.set public owners;                         // set of addresses approved for decision making
    uint ownerThreshold;                           // required number of owners in vote

    mapping(bytes32 => Set.set) supportingOwners;  // map active votes to supporting owners
    mapping(bytes32 => Set.set) supportingPublic;  // map active votes to supporting public add
    mapping(bytes32 => Set.set) dissentingPublic;  // map active votes to dissenting public addrs
    mapping(bytes32 => uint) initBlock;            // map active votes to scheduled block times

    uint delayDuration = 960;                      // # of blocks delayed by "delay" modifier
    uint constant VOTE_DURATION = 960 * 7;         // # of blocks per voting period
    // note: approximately 960 blocks are mined daily

    bool suspended;                                // flags the state of the system as suspended
    bytes32 suspendOp;                                // operation on which the state is suspended

    address nukeMasterKey;                         // only address that can be used to arm a nuke
    uint nukesLeft = 3;                            // # of nuke attempts left (to prevent DoS)
    bool nukeArmed;                                // flags the nuke as armed by the nuke master
    bool public nuked;                             // flags the nuke as dropped

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
    modifier ownerVote(bytes32 _operation) {
	if(checkOwnerVote(_operation)) {
	    _;
	    delete supportingOwners[_operation];
	    delete initBlock[_operation];
	}
    }

    /// Funcion call must be approved by a majority of token stakeholders
    modifier publicVote(bytes32 _operation, bool supporting, uint percent) {
	if(checkPublicVote(_operation, supporting, percent)) {
	    suspended = true;
	    _;
	    delete supportingPublic[_operation];
	    delete dissentingPublic[_operation];
	    delete initBlock[_operation];
	    suspended = false;
	}
    }

    /// Function call will be delayed by a set number of blocks regardless of approval
    modifier delayed(bytes32 _operation) {
	if(checkDelay(_operation)) {
	    _;
	    delete initBlock[_operation];
	}
    }

    modifier suspend(bytes32 _operation) {
	suspended = true;
	suspendOp = _operation;
	_;
	suspended = false;
    }

    /// Funcion is inaccessible of the system is suspended for any reason
    modifier suspendable(bytes32 _operation) {
	require(checkSuspended(_operation));
	_;
    }

    /// Function call must be approved by the constant nuke master address
    modifier nuke_master {
	suspended = true;
	_;
	nuked = true;
	suspended = false;
    }

    ///---------------------------------- Public Methods ------------------------------------///

    /// Constructor takes a list of owners, a threshold, and a fixed nuke key
    function Restricted(address[] _ownerList, uint _ownerThreshold, address _nukeMasterKey) {
	ownerThreshold = _ownerThreshold;
	nukeMasterKey = _nukeMasterKey;

	for(uint256 i = 0; i < _ownerList.length; i++) {
	    owners.insert(_ownerList[i]);
	    LogOwnerChange(_ownerList[i], true);
	}
    }

    /// Add address to list of owners
    function addOwner(address _owner) ownerVote(sha3(msg.data)) delayed(sha3(msg.data)) {
	owners.insert(_owner);
	LogOwnerChange(_owner, true);
    }

    /// Remove address from list of owners
    function removeOwner(address _owner) ownerVote(sha3(msg.data)) {
	owners.remove(_owner);
	LogOwnerChange(_owner, false);
    }

    /// Atomically swap out an owner address (avoids corner cases from changing # of owners)
    function switchOwner(address _old, address _new) ownerVote(sha3(msg.data))
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
    function changeThreshold(uint _ownerThreshold) ownerVote(sha3(msg.data))
	delayed(sha3(msg.data)) {

	ownerThreshold = _ownerThreshold;
	LogChangeThreshold(ownerThreshold);
    }

    /// Change the duration of the delay modifier
    function changeDelay(uint _delayDuration) ownerVote(sha3(msg.data)) delayed(sha3(msg.data)) {
	delayDuration = _delayDuration;
	LogChangeDelay(delayDuration);
    }

    /// Cancel a currently delayed block
    function killDelayed(bytes32 _operation) ownerVote(sha3(msg.data)) {
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

    ///---------------------------------- Private Methods -----------------------------------///

    /// Cast vote for a multi-owner function call and return true if the call has been approved
    function checkOwnerVote(bytes32 _operation) private returns (bool) {
	if(owners.contains(msg.sender)) {
	    supportingOwners[_operation].insert(msg.sender);
	    if(supportingOwners[_operation].size() >= ownerThreshold) {
		initBlock[_operation] = block.number;
		return true;
	    }
	}
	return false;
    }

    /// Public signalling of support/dissent for an open vote; return true if the voting duration
    /// is over AND a sufficient majority has been reached
    function checkPublicVote(bytes32 _operation, bool supporting, uint percent) private returns (bool) {

	// if polls have closed then count votes and exit
	if(initBlock[_operation] + VOTE_DURATION > block.number) {
	    uint256 supportingStake;
	    uint256 dissentingStake;

	    supportingPublic[_operation].iterateStart();
	    dissentingPublic[_operation].iterateStart();

	    address current;

	    while(supportingPublic[_operation].contains(current)) {
		supportingStake += votingStake(current);
		current = supportingPublic[_operation].iterateNext();
	    }
	    while(dissentingPublic[_operation].contains(current)) {
		dissentingStake += votingStake(current);
		current = dissentingPublic[_operation].iterateNext();
	    }

	    initBlock[_operation] = block.number;
	    return supportingStake * percent > (supportingStake + dissentingStake) * 100;
	}

	// if no votes have been cast then set vote deadline
	if(supportingPublic[_operation].size() + dissentingPublic[_operation].size() == 0) {
	    initBlock[_operation] = block.number;
	}

	// count vote and remove from the opposite bin in case user changed their mind
	if(supporting) {
	    dissentingPublic[_operation].remove(msg.sender);
	    supportingPublic[_operation].insert(msg.sender);
	}
	else {
	    supportingPublic[_operation].remove(msg.sender);
	    dissentingPublic[_operation].insert(msg.sender);
	}
    }

    /// Check to see if the call has been sufficiently delayed and if so return true
    function checkDelay(bytes32 _operation) private returns (bool) {
	if(initBlock[_operation] + delayDuration > block.number) {
	    return true;
	}
	return false;
    }

    function checkSuspended(bytes32 _operation) private returns (bool) {
	if(!suspended) {
	    return true;
	}

	// check all possible blocking reasons and unsuspend the system if no reasons are found
	if(initBlock[_operation] == uint(0) && !nukeArmed) {
	    suspended = false;
	    return true;
	}
    }

    /// Check if the nuke has been set and arm it otherwise (if allowed)
    function armNuke() private returns (bool) {
	if(!nukeArmed) {
	    if(msg.sender == nukeMasterKey && nukesLeft > 0) {
		nukesLeft--;
		return true;
	    }
	    return false;
	}
	return true;
    }

    /// Supermajority vote to nuke the contract logic and allow free ether withdrawal
    function nuke(bool supporting) nuke_master suspend(sha3(msg.data))
	publicVote(sha3(msg.data), supporting, MAJORITY) {
	ownerThreshold = 2**256 - 1;
	LogNuke();
    }

    ///---------------------------------- Abstract Methods ----------------------------------///

    /// Determine stake modifier for given address; necessary to enable sybil-resistent votingx
    function votingStake(address _addr) internal returns (uint256) {
	return 1;
    }
}
