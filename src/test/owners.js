var Core = artifacts.require("Core");
var Ibis = artifacts.require("Ibis");

contract("Owners", function(accounts) {

    var ibis;
    var core;
    var delay;

    owner1 = accounts[0];
    owner2 = accounts[1];
    owner3 = accounts[2];
    nukeMaster = accounts[3];

    owner4 = accounts[4];

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

    it("should allow owners to be added", function() {

	return Ibis.deployed().then(function(instance) {
	    return ibis.owners(owner4);
	}).then(function(bool) {
	    assert.equal(bool, false, "Owner was already registered");
	    return ibis.addOwner(owner4, {from: owner1});
	}).then(function() {
	    return ibis.addOwner(owner4, {from: owner1});
	}).then(function() {
	    var delayCmd = {jsonrpc: "2.0", method: "evm_increaseTime", params: [delay], id: 0};
	    web3.currentProvider.send(delayCmd)
	}).then(function() {
	    return ibis.addOwner(owner4, {from: owner1});
	}).then(function() {
	    return ibis.owners(owner4);
	}).then(function(bool) {
	    assert.equal(bool, false, "Owner was added without threshold approval");
	    return ibis.addOwner(owner4, {from: owner2});
	}).then(function() {
	    var delayCmd = {jsonrpc: "2.0", method: "evm_increaseTime", params: [delay], id: 0};
	    web3.currentProvider.send(delayCmd)
	}).then(function() {
	    return ibis.addOwner(owner4, {from: owner1});
	}).then(function() {
	    return ibis.owners(owner4);
	}).then(function(bool) {
	    assert.equal(bool, true, "Owner should have been added");
	});
    });
});
