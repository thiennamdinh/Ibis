// ./node_modules/.bin/testrpc -l 6700000


fs = require('fs')
Web3 = require('web3')
solc = require('solc')

web3 = new Web3(new Web3.providers.HttpProvider("http://localhost:8545"));

compiled = solc.compile({sources : {
    'Core.sol' : fs.readFileSync('contracts/Core.sol').toString(),
    'Restricted.sol': fs.readFileSync('contracts/Restricted.sol').toString(),
    'Democratic.sol': fs.readFileSync('contracts/Democratic.sol').toString(),
    'Token.sol':fs.readFileSync('contracts/Token.sol').toString(),
    'Ibis.sol': fs.readFileSync('contracts/Ibis.sol').toString()
}}, 1);

abi_core = JSON.parse(compiled.contracts['Core.sol:Core'].interface)
abi_ibis = JSON.parse(compiled.contracts['Ibis.sol:Ibis'].interface)

bytecode_core = compiled.contracts['Core.sol:Core'].bytecode
bytecode_ibis = compiled.contracts['Ibis.sol:Ibis'].bytecode

contract_core = new web3.eth.Contract(abi_core)
contract_ibis = new web3.eth.Contract(abi_ibis)

contract_core.options.data = bytecode_core

contract_core.deploy({arguments: []}).send({from: account_address, gas:4700000, gasPrice: '30000000'}).then(function(newContractInstance){ contract_core.options.address = newContractInstance.options.address;});

//---------- break here------------------------------------------------------------------------------

bytecode_ibis = solc.linkBytecode(bytecode_ibis, {
    'Core.sol:Core': contract_core.options.address,
});

contract_ibis.options.data = bytecode_ibis

contract_ibis.deploy({arguments: [contract_core.options.address, [account_address], 1, account_address]}).send({from: account_address, gas:6700000, gasPrice: '30000000'}).then(function(newContractInstance){ contract_ibis.options.address = newContractInstance.options.address;});

//---------- break here------------------------------------------------------------------------------

contract_core.methods.addApproved(contract_ibis.options.address).send({from: account_address}).then(console.log)

contract_ibis.methods.balanceOf(account_address).call({from: account_address}).then(console.log)

contract_ibis.methods.approve(account_address, 3000).call({from: account_address}).then(console.log)

contract_ibis.methods.deposit().call({from: account_address, value: 1e18}).then(console.log)

contract_ibis.methods.transfer(account_address, 50).call({from: account_address}).then(console.log)


//-------------------------------------------

compiled = solc.compile({sources : {
    'Core.sol' : fs.readFileSync('contracts/Core.sol').toString(),
    'Restricted.sol': fs.readFileSync('contracts/Restricted.sol').toString(),
    'Democratic.sol': fs.readFileSync('contracts/Democratic.sol').toString(),
    'Token.sol':fs.readFileSync('contracts/Token.sol').toString(),
    'Ibis.sol': fs.readFileSync('contracts/Ibis.sol').toString()
}}, 1);

abi_ibis = JSON.parse(compiled.contracts['Ibis.sol:Ibis'].interface)
bytecode_ibis = compiled.contracts['Ibis.sol:Ibis'].bytecode
contract_ibis = new web3.eth.Contract(abi_ibis)
bytecode_ibis = solc.linkBytecode(bytecode_ibis, {
    'Core.sol:Core': contract_core.options.address,
});

contract_ibis.options.data = bytecode_ibis

contract_ibis.deploy({arguments: [contract_core.options.address, [account_address], 1, account_address]}).send({from: account_address, gas:6700000, gasPrice: '30000000'}).then(function(newContractInstance){ contract_ibis.options.address = newContractInstance.options.address;});

contract_core.methods.addApproved(contract_ibis.options.address).send({from: account_address}).then(console.log)

contract_ibis.methods.balanceOf(account_address).call({from: account_address}).then(console.log)

contract_ibis.methods.deposit().send({from: account_address, gas: 900000, value: 1e18}).then(console.log)

contract_ibis.methods.transfer(account_address_2, 1500000).send({from: account_address, gas: 900000}).then(console.log)

web3.eth.getBalance(account_address_2).then(console.log)
