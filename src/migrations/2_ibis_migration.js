var Core = artifacts.require("Core");
var Ibis = artifacts.require("Ibis");

module.exports = function(deployer, network, accounts) {

    deployer.deploy(Core, {from: accounts[0]}).then(function(){
	return deployer.deploy(Ibis, Core.address, [accounts[0], accounts[1], accounts[2]], 2,
			       accounts[3], {from: accounts[0], gas: 10000000});
    }).then(function() {
	// pass Core ownership to Ibis
	Core.deployed().then(function(instance) {
	    instance.addApproved(Ibis.address, {from: accounts[0]});
	    instance.upgrade(Ibis.address, {from: accounts[0]});
	});
    });


};
