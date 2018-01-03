pragma solidity ^0.4.13;

contract Democratic {

    enum Ballot {EMPTY, SUPPORTING, DISSENTING}

    struct Issue {
	uint initTime;
	uint threshold;

	uint supportingTotal;
	uint dissentingTotal;

	mapping(address => Ballot) ballots;
    }

    // constructor-defined constants
    uint public maxSuspensions;
    uint public voteDuration;

    // variables to track suspensions
    uint public usedSuspensions;
    uint public activeSuspensions;

    // variables to track voting issues
    uint activeIssues;
    mapping(bytes32 => Issue) public issues;          // map of active issues to be voted by the public
    mapping(address => uint) public numParticipating;
    mapping(address => uint) public votingStake;    // balance that a user has spent on voting power

    /// Function call must be approved by a majority of token stakeholders
    modifier votable(bytes32 _operation, uint percent, bool suspend) {
	if(!checkVotes(_operation, percent, suspend)) {
	    assembly{stop}
	}
	_;
	delete issues[_operation];
    }

    modifier suspendable() {
	if(activeSuspensions == 0) {
	    _;
	}
    }

    function Democratic(uint _voteDuration, uint _maxSuspensions) public {
	voteDuration = _voteDuration;
	maxSuspensions = _maxSuspensions;
    }

    function register(uint _votes) public {
	// cannot register if already registered
	if(votingStake[msg.sender] == 0) {
	    votingStake[msg.sender] = purchaseVotes(msg.sender, _votes);
	}
    }

    /// Allow users to unregister themselves if they are not actively participating
    function unregister() public {
	if(votingStake[msg.sender] != 0 && numParticipating[msg.sender] == 0) {
	    delete votingStake[msg.sender];
	    returnVotes(msg.sender);
	}
    }

    /// Allow anybody to unregister a voter if there are no active issues
    function unregisterFor(address _addr) public {
	if(votingStake[_addr] != 0 && activeIssues == 0) {
	    delete votingStake[_addr];
	    returnVotes(_addr);
	}
    }

    function vote(bytes32 _operation, bool _supporting) public {

	// already voted on this issue
	if(issues[_operation].ballots[msg.sender] != Ballot.EMPTY) {
	    return;
	}

	// reference the issue created in "publicVote"
	if(_supporting) {
	    issues[_operation].ballots[msg.sender] = Ballot.SUPPORTING;
	    issues[_operation].supportingTotal += votingStake[msg.sender];
	}
	else {
	    issues[_operation].ballots[msg.sender] = Ballot.DISSENTING;
	    issues[_operation].dissentingTotal += votingStake[msg.sender];
	}

	numParticipating[msg.sender]++;
    }

    function unvote(bytes32 _operation) public {

	// user hasn't voted on this issue
	if(issues[_operation].ballots[msg.sender] == Ballot.EMPTY) {
	    return;
	}

	if(issues[_operation].ballots[msg.sender] == Ballot.SUPPORTING) {
	    issues[_operation].supportingTotal -= votingStake[msg.sender];
	}
	else if(issues[_operation].ballots[msg.sender] == Ballot.DISSENTING) {
	    issues[_operation].dissentingTotal -= votingStake[msg.sender];
	}

	numParticipating[msg.sender]--;
	issues[_operation].ballots[msg.sender] = Ballot.EMPTY;
    }

    // Allow anybody to clear the space taken by a prior issue vote
    function clearVote(bytes32 _operation, address _addr) public {
	if(block.timestamp < issues[_operation].initTime + voteDuration) {
	    if(issues[_operation].ballots[_addr] != Ballot.EMPTY) {
		numParticipating[_addr]--;
	    }

	    delete issues[_operation].ballots[_addr];
	}
    }

    /// Public signalling of support/dissent for an open vote; return true if the voting duration
    /// is over AND a sufficient majority has been reached
    function checkVotes(bytes32 _operation, uint _percent, bool _suspend)
	private returns (bool) {

	// if this is the first call then create a new issue and set the initial block time
	if(issues[_operation].initTime == 0) {
	    if(_suspend && usedSuspensions >= maxSuspensions) {
		return false;
	    }

	    if(_suspend) {
		usedSuspensions ++;
		activeSuspensions++;
	    }

	    issues[_operation].initTime = block.timestamp;
	    issues[_operation].threshold = _percent;
	    activeIssues++;

	    return false;
	}

	// if the voting period has ended then tally the votes and return the result
	if (block.timestamp >= issues[_operation].initTime + voteDuration) {
	    if(_suspend) activeSuspensions--;
	    activeIssues--;
	    issues[_operation].threshold = 5;
 	    uint total = issues[_operation].supportingTotal + issues[_operation].dissentingTotal;
	    return issues[_operation].supportingTotal * 100 > total * issues[_operation].threshold;
	}
    }

    ///---------------------------------- Abstract Methods ----------------------------------///

    function purchaseVotes(address, uint) internal returns (uint) {
	// implement in child to freeze funds, etc
    }

    function returnVotes(address) internal {
	// implement in child to unfreeze funds, etc
    }
}
