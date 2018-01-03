var Core = artifacts.require("Core");
var Ibis = artifacts.require("Ibis");
var IbisUpgrade = artifacts.require("IbisNewConcrete");

contract("Votes", function(accounts) {

    var ibis;
    var core;
    var ibisUpgrade;

    var delay;
    var voteDuration;
    var issue;
    var initTime;

    var votes1;

    owner1 = accounts[0];

    voter1 = accounts[4];
    voter2 = accounts[5];
    voter3 = accounts[6];

    balance1 = 10e9;
    balance2 = 10e9;
    balance3 = 10e9;

    votes1 = 4e9;
    votes2 = 5e9;
    votes3 = 6e9;

    it("should be set up", function() {
	return Ibis.deployed().then(function(instance) {
	    ibis = instance;
	    return Core.deployed()
	}).then(function(instance) {
	    core = instance;
	    return IbisUpgrade.deployed();
	}).then(function(instance) {
	    ibisUpgrade = instance;
	    return ibis.delayDuration();
	}).then(function(result) {
	    delay = result.toNumber();
	    return ibis.voteDuration();
	}).then(function(result) {
	    voteDuration = result.toNumber();
	});
    });

    it("should allow voter registration", function() {

	return ibis.deposit({from: voter1, value: balance1}).then(function() {
	    ibis.deposit({from: voter2, value: balance2});
	}).then(function() {
	    ibis.deposit({from: voter3, value: balance3});
	}).then(function() {
	    ibis.register(votes1, {from: voter1});
	}).then(function() {
	    ibis.register(votes2, {from: voter2});
	}).then(function() {
	    ibis.register(votes3, {from: voter3});
	}).then(function() {
	    return ibis.balanceOf(voter1);
	}).then(function(balance) {
	    assert.equal(balance.toNumber(), balance1 - votes1, "Voter 1 incorrect tokens");
	    return ibis.balanceOf(voter2);
	}).then(function(balance) {
	    assert.equal(balance.toNumber(), balance2 - votes2, "Voter 2 incorrect tokens");
	    return ibis.balanceOf(voter3);
	}).then(function(balance) {
	    assert.equal(balance.toNumber(), balance3 - votes3, "Voter 3 incorrect tokens");
	    return ibis.votingStake(voter1);
	}).then(function(votes) {
	    assert.equal(votes.toNumber(), votes1, "Voter 1 incorrect votes");
	    return ibis.votingStake(voter2);
	}).then(function(votes) {
	    assert.equal(votes.toNumber(), votes2, "Voter 2 incorrect votes");
	    return ibis.votingStake(voter3);
	}).then(function(votes) {
	    assert.equal(votes.toNumber(), votes3, "Voter 3 incorrect votes");
	});
    });

    it("should create voteable issues", function() {
	return ibis.upgradeEmergency(IbisUpgrade.address, {from: owner1}).then(function(transaction) {
	    var data = web3.eth.getTransaction(transaction.tx).input
	    initTime = web3.eth.getBlock(transaction.receipt.blockNumber).timestamp;
	    issue = web3.sha3(data, {encoding: "hex"});
	    return ibis.issues(issue);
	}).then(function(result) {
	    assert.equal(result[0].toNumber(), initTime, "Vote was not initiated");
	});
    });

    it("should allow vote casting", function() {
	return ibis.vote(issue, false, {from: voter1}).then(function() {
	    ibis.vote(issue, false, {from: voter2});
	}).then(function() {
 	    ibis.vote(issue, true, {from: voter3});
	}).then(function() {
	    // attempted double vote
	    ibis.vote(issue, true, {from: voter1});
	}).then(function() {
	    // attempted double vote
	    ibis.vote(issue, false, {from: voter1});
	}).then(function() {
	    return ibis.issues(issue);
	}).then(function(result) {
	    assert.equal(result[2].toNumber(), votes3, "Incorrect supporting total");
	    assert.equal(result[3].toNumber(), votes1 + votes2, "Incorrect dissenting total");
	});
    });

    it("should allow unvoting and unregistering", function() {
	return ibis.unregister({from: voter1}).then(function() {
	    return ibis.votingStake(voter1);
	}).then(function(balance) {
	    assert.equal(balance.toNumber(), votes1, "User was incorrectly able to unregister");
	    ibis.unvote(issue, {from: voter1});
	}).then(function() {
	    return ibis.issues(issue);
	}).then(function(result) {
	    assert.equal(result[3].toNumber(), votes2, "Vote did not decrease correctly");
	    ibis.unregister({from: voter1});
	}).then(function() {
	    return ibis.votingStake(voter1);
	}).then(function(balance) {
	    assert.equal(balance.toNumber(), 0, "Voter did not unregister");
	    return ibis.balanceOf(voter1);
	}).then(function(balance) {
	    assert.equal(balance.toNumber(), balance, "Tokens were not refunded");
	});
    });

    it("should allow successful votes to execute", function() {
	return ibis.register(votes1 * 2, {from: voter1}).then(function() {
	    ibis.vote(issue, true, {from: voter1});
	}).then(function() {
	    ibis.upgradeEmergency(IbisUpgrade.address, {from: owner1});
	}).then(function() {
	    var totalEth = web3.eth.getBalance(Ibis.address).toNumber();
	    assert.equal(totalEth, balance1 + balance2 + balance3, "Call should not have executed");
	    var wait = {jsonrpc: "2.0", method: "evm_increaseTime", params: [voteDuration], id: 0};
	    web3.currentProvider.send(wait);
	}).then(function() {
	    ibis.upgradeEmergency(IbisUpgrade.address, {from: owner1});
	}).then(function() {
	    return ibis.delayDuration(); //for some reason the upgrade doesn't happen immediately
	}).then(function() {
	    var oldEth = web3.eth.getBalance(Ibis.address).toNumber();
	    assert.equal(oldEth, 0, "Call should have executed");
	    var newEth = web3.eth.getBalance(IbisUpgrade.address).toNumber();
	    assert.equal(newEth, balance1 + balance2 + balance3, "Call should have completed");
	});
    });
});
