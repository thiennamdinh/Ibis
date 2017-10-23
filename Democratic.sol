pragma solidity ^0.4.13;

contract Democratic {

    struct Issue {
	uint initBlock;
	uint threshold;

	mapping(address => uint256) supporting;
	mapping(address => uint256) dissenting;

	uint256 supportingTotal;
	uint256 dissentingTotal;
    }

    uint voteDuration;
    uint constant MAX_SUSPENSIONS = 3;

    uint activeIssues;
    uint activeSuspended;                       // tracks the number of active suspendable votes

    mapping(address => uint256) votingBalance;  // balance that a user has spent on voting power
    mapping(bytes32 => Issue) issues;           // map of active issues to be voted by the public

    /// Function call must be approved by a majority of token stakeholders
    modifier votable(bytes32 _operation, uint percent, bool suspend) {
	if(checkVote(_operation, percent, suspend)) {
	    _;
	    delete issues[_operation];
	}
    }

    modifier suspendable() {
	if(activeSuspended == 0) {
	    _;
	}
    }

    function Democratic(uint _voteDuration) {
	voteDuration = _voteDuration;
    }

    function registerVote() {
	votingBalance[msg.sender] = purchaseVotes(msg.sender);
    }

    // TODO: option to withdraw vote if they are not voting in any open issues?

    // Allow anybody to clear vote if no issues left to vote on
    function unregisterVote(address _addr) {
	if(activeIssues == 0 && returnVotes(_addr)) {
	    delete votingBalance[_addr];
	}
    }

    function vote(bytes32 _operation, bool _supporting, uint256 _amount) {
	// reference the issue created in "publicVote"
	uint256 voteUsed = issues[_operation].supporting[msg.sender] -
	    issues[_operation].dissenting[msg.sender];

	if(_amount <= votingBalance[msg.sender] - voteUsed && _amount > 0) {
	    if(_supporting) {
		issues[_operation].supporting[msg.sender] += _amount;
		issues[_operation].supportingTotal += _amount;
	    }
	    else {
		issues[_operation].dissenting[msg.sender] += _amount;
		issues[_operation].dissentingTotal += _amount;
	    }
	}
    }

    function unvote(bytes32 _operation) {
	issues[_operation].supportingTotal -= issues[_operation].supporting[msg.sender];
        issues[_operation].supporting[msg.sender] = 0;

	issues[_operation].dissentingTotal -= issues[_operation].dissenting[msg.sender];
	issues[_operation].dissenting[msg.sender] = 0;
    }

    // Allow anybody to clear the space taken by a prior issue vote
    function clearVotingStake(bytes32 _operation, address _addr) {
	if(block.number < issues[_operation].initBlock + voteDuration) {
	    delete issues[_operation].supporting[_addr];
	    delete issues[_operation].dissenting[_addr];
	}
    }

    /// Public signalling of support/dissent for an open vote; return true if the voting duration
    /// is over AND a sufficient majority has been reached
    function checkVote(bytes32 _operation, uint _percent, bool _suspend)
	private returns (bool) {

	// if this is the first call then create a new issue and set the initial block number
	if(issues[_operation].initBlock != 0) {
	    issues[_operation].initBlock = block.number;
	    issues[_operation].threshold = _percent;

	    activeIssues++;
	    if(_suspend) activeSuspended++;

	    return false;
	}

	// if the voting period has ended then tally the votes and return the result
	if (block.number > issues[_operation].initBlock + voteDuration) {
	    activeIssues--;
	    if(_suspend) activeSuspended--;

 	    uint total = issues[_operation].supportingTotal + issues[_operation].dissentingTotal;
	    return issues[_operation].supportingTotal > total * issues[_operation].threshold;
	}
    }

    ///---------------------------------- Abstract Methods ----------------------------------///

    function purchaseVotes(address _addr) internal returns (uint256) {
	// implement in child to freeze funds, etc
    }

    function returnVotes(address _addr) internal returns (bool) {
	// implement in child to unfreeze funds, etc
    }
}
