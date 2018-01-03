var Core = artifacts.require("Core");
var Ibis = artifacts.require("Ibis");

contract("Votes", function(accounts) {

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

});
