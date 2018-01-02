var Core = artifacts.require("Core");
var Ibis = artifacts.require("Ibis");

contract("Ibis", function(accounts) {

    owner1 = accounts[0];
    owner2 = accounts[1];
    owner3 = accounts[2];
    nukeMaster = accounts[3];

    user1 = accounts[4];
    user2 = accounts[5];

    charity1 = accounts[6];

    var core;
    var ibis;

    var deposit1 = 2e9;
    var deposit2 = 1e9;
    var transfer = 0.5e9;

    it("should linked to the Core contract", function() {
	return Core.deployed().then(function(instance) {
	    core = instance;
	    return Ibis.deployed();
	}).then(function(instance) {
	    ibis = instance;
	    return ibis.core();
	}).then(function(address) {
	    assert.equal(address, Core.address, "Core is not linked to Ibis");
	    return core.controller();
	}).then(function(address) {
	    assert.equal(address, Ibis.address, "Ibis is no the controller");
	    return core.approved(Ibis.address);
	}).then(function(bool) {
	    assert.equal(bool, true, "Ibis is not approved");
	});
    });

    it("should accept deposits", function() {

	return Ibis.deployed().then(function(instance) {
	    ibis.deposit({from: user1, value: deposit1});
	}).then(function() {
	    return ibis.balanceOf(user1);
	}).then(function(balance) {
	    assert.equal(balance.toNumber(), deposit1, "balance of account 1 is incorrect");
	    return ibis.deposit({from: user2, value: deposit2});
	}).then(function() {
	    return ibis.balanceOf(user2);
	}).then(function(balance) {
	    assert.equal(balance.toNumber(), deposit2, "balance of account 2 is incorrect");
	});
    });

    it("should transfer tokens", function() {

	return Ibis.deployed().then(function(instance) {
	    ibis.transfer(user2, transfer, {from: user1});
	}).then(function() {
	    return ibis.balanceOf(user1);
	}).then(function(balance) {
	    assert.equal(balance.toNumber(), deposit1 - transfer, "balance of account 1 is wrong");
	    return ibis.balanceOf(user2);
	}).then(function(balance) {
	    assert.equal(balance.toNumber(), deposit2 + transfer, "balance of account 2 is wrong");
	});

    });

    it("should allow charities to withdraw", function() {

	return Ibis.deployed().then(function(instance) {
	    ibis.addCharity(charity1, {from: owner1});
	}).then(function() {
	    console.log(web3.eth.getBlock(web3.eth.blockNumber).timestamp)
	    return core.charityStatus(charity1);
	}).then(function(bool) {
	    assert.equal(bool, false, "Should not be a charity yet");
	}).then(function() {
	    for(i = 0; i < 10; i++){
		web3.currentProvider.send({jsonrpc: "2.0", method: "evm_mine", params: [], id: 0})
	    }
	}).then(function() {
	    console.log(web3.eth.getBlock(web3.eth.blockNumber).timestamp)
	    ibis.addCharity(charity1, {from: owner1});
	}).then(function() {
	    return core.charityStatus(charity1);
	}).then(function(bool) {
	    assert.equal(bool, true, "Should be a charity now");
	});
    });

});
