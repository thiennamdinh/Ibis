pragma solidity ^0.4.13;

contract Democratic {

    struct Issue {
	uint initBlock;
	uint threshold;

	mapping(address => uint) supporting;
	mapping(address => uint) dissenting;

	uint supportingTotal;
	uint dissentingTotal;
    }

    // constructor-defined constants
    uint maxSuspensions;
    uint voteDuration;

    // variables to track suspensions
    uint usedSuspensions;
    uint activeSuspensions;

    // variables to track voting issues
    uint activeIssues;
    mapping(bytes32 => Issue) issues;           // map of active issues to be voted by the public
    mapping(address => uint) numParticipating;
    mapping(address => uint) votingBalance;  // balance that a user has spent on voting power

    /// Function call must be approved by a majority of token stakeholders
    modifier votable(bytes32 _operation, uint percent, bool suspend) {
	if(checkVotes(_operation, percent, suspend)) {
	    _;
	    delete issues[_operation];
	}
    }

    modifier suspendable() {
	if(activeSuspensions == 0) {
	    _;
	}
    }

    function Democratic(uint _voteDuration, uint _maxSuspensions) {
	voteDuration = _voteDuration;
	maxSuspensions = _maxSuspensions;
    }

    function register() {
	votingBalance[msg.sender] = purchaseVotes(msg.sender);
    }

    function unregister(address _addr) {

	// allow user to clear their own vote if they are not participating in any issues
	if(_addr == msg.sender && numParticipating[msg.sender] == 0 && returnVotes(_addr)) {
	    delete votingBalance[_addr];
	}

	// allow anyone to clear votes if there are no issues to vote on
	if(activeIssues == 0 && returnVotes(_addr)) {
	    delete votingBalance[_addr];
	}
    }

    function vote(bytes32 _operation, bool _supporting) {

	// already voted on this issue
	if(issues[_operation].supporting[msg.sender] + issues[_operation].dissenting[msg.sender] != 0) {
	    return;
	}

	// reference the issue created in "publicVote"
	if(_supporting) {
	    issues[_operation].supporting[msg.sender] += votingBalance[msg.sender];
	    issues[_operation].supportingTotal += votingBalance[msg.sender];
	}
	else {
	    issues[_operation].dissenting[msg.sender] += votingBalance[msg.sender];
	    issues[_operation].dissentingTotal += votingBalance[msg.sender];
	}

	numParticipating[msg.sender]++;
    }

    function unvote(bytes32 _operation) {

	// user hasn't voted on this issue
	if(issues[_operation].supporting[msg.sender] + issues[_operation].dissenting[msg.sender] == 0) {
	    return;
	}

	issues[_operation].supportingTotal -= issues[_operation].supporting[msg.sender];
        issues[_operation].supporting[msg.sender] = 0;

	issues[_operation].dissentingTotal -= issues[_operation].dissenting[msg.sender];
	issues[_operation].dissenting[msg.sender] = 0;

	numParticipating[msg.sender]--;
    }

    // Allow anybody to clear the space taken by a prior issue vote
    function clearVote(bytes32 _operation, address _addr) {
	if(block.number < issues[_operation].initBlock + voteDuration) {
	    if(issues[_operation].supporting[_addr] + issues[_operation].dissenting[_addr] != 0) {
		numParticipating[msg.sender]--;
	    }

	    delete issues[_operation].supporting[_addr];
	    delete issues[_operation].dissenting[_addr];
	}
    }

    /// Public signalling of support/dissent for an open vote; return true if the voting duration
    /// is over AND a sufficient majority has been reached
    function checkVotes(bytes32 _operation, uint _percent, bool _suspend)
	private returns (bool) {

	// if this is the first call then create a new issue and set the initial block number
	if(issues[_operation].initBlock != 0) {
	    if(_suspend && usedSuspensions >= maxSuspensions) {
		return false;
	    }

	    if(_suspend) {
		usedSuspensions ++;
		activeSuspensions++;
	    }

	    issues[_operation].initBlock = block.number;
	    issues[_operation].threshold = _percent;

	    return false;
	}

	// if the voting period has ended then tally the votes and return the result
	if (block.number > issues[_operation].initBlock + voteDuration) {
	    if(_suspend) activeSuspensions--;

 	    uint total = issues[_operation].supportingTotal + issues[_operation].dissentingTotal;
	    return issues[_operation].supportingTotal > total * issues[_operation].threshold;
	}
    }

    ///---------------------------------- Abstract Methods ----------------------------------///

    function purchaseVotes(address _addr) internal returns (uint) {
	// implement in child to freeze funds, etc
    }

    function returnVotes(address _addr) internal returns (bool) {
	// implement in child to unfreeze funds, etc
    }
}
