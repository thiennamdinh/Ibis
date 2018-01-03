var Core = artifacts.require("Core");
var Ibis = artifacts.require("Ibis");

contract("Votes", function(accounts) {

    var ibis;
    var core;
    var delay;
    var issue;
    var initTime;

    var votes1;

    owner1 = accounts[0];

    voter1 = accounts[4];
    voter2 = accounts[5];
    voter3 = accounts[6];

    votes1 = 3e9;
    votes2 = 4e9;
    votes3 = 5e9;

    it("should be set up", function() {
	return Ibis.deployed().then(function(instance) {
	    ibis = instance;
	    return Core.deployed()
	}).then(function(instance) {
	    core = instance;
	    return ibis.delayDuration();
	}).then(function(duration) {
	    delay = duration.toNumber();
	});
    });

    it("should create voteable issues", function() {
	return ibis.upgradeEmergency(Core.address).then(function(transaction) {
	    var data = web3.eth.getTransaction(transaction.tx).input
	    initTime = web3.eth.getBlock(transaction.receipt.blockNumber).timestamp;
	    issue = web3.sha3(data, {encoding: "hex"});
	    return ibis.issues(issue);
	}).then(function(result) {
	    assert.equal(result[0].toNumber(), initTime, "Vote was not initiated");
	});
    });

    it("should allow vote registration", function() {

	return ibis.deposit({from: voter1, value: votes1}).then(function() {
	    ibis.deposit({from: voter2, value: votes2});
	}).then(function() {
	    ibis.deposit({from: voter3, value: votes3});
	}).then(function() {
	    ibis.register({from: voter1});
	}).then(function() {
	    ibis.register({from: voter2});
	}).then(function() {
	    ibis.register({from: voter3});
	}).then(function() {
	    return ibis.balanceOf(voter1);
	}).then(function(balance) {
	    assert.equal(balance.toNumber(), 0, "Voter 1 still has funds");
	    return ibis.balanceOf(voter2);
	}).then(function(balance) {
	    assert.equal(balance.toNumber(), 0, "Voter 2 still has funds");
	    return ibis.balanceOf(voter3);
	}).then(function(balance) {
	    assert.equal(balance.toNumber(), 0, "Voter 3 still has funds");
	    return ibis.votingBalance(voter1);
	}).then(function(votes) {
	    assert.equal(votes.toNumber(), votes1, "Voter 1 has incorrect number of votes");
	    return ibis.votingBalance(voter2);
	}).then(function(votes) {
	    assert.equal(votes.toNumber(), votes2, "Voter 2 has incorrect number of votes");
	    return ibis.votingBalance(voter3);
	}).then(function(votes) {
	    assert.equal(votes.toNumber(), votes3, "Voter 3 has incorrect number of votes");
	});
    });
});
