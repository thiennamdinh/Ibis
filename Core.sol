pragma solidity ^0.4.13;

contract Core {

    address public controller;
    mapping(address => bool) public approved;

    mapping(address => uint256) public balances;
    mapping(address => mapping (address => uint256)) public allowed;

    mapping(address => bool) public charityStatus;
    mapping(address => uint256) public charityBlocknum;

    mapping(address => uint256) public frozenValue;
    mapping(address => uint256) public frozenBlocknum;

    modifier isController() {
	require(msg.sender == controller);
	_;
    }

    modifier isApproved() {
	require(approved[msg.sender]);
	_;
    }

    function Core() {
	controller = msg.sender;
    }

    function upgrade(address _addr) isController {
	controller = _addr;
    }

    function addApproved(address _addr) isController {
	approved[_addr] = true;
    }

    function removeApproved(address _addr) isController {
	approved[_addr] = false;
    }

    function setBalances(address _addr, uint256 _value) isApproved {
	balances[_addr] = _value;
    }

    function setCharityStatus(address _addr, bool _status) isApproved {
	charityStatus[_addr] = _status;
    }

    function setCharityBlocknum(address _addr, uint _blocknum) isApproved {
	charityBlocknum[_addr] = _blocknum;
    }

    function setAllowed(address _addr, address _allowed, uint256 _value) isApproved {
	allowed[_addr][_allowed] = _value;
    }

    function setFrozenValue(address _addr, uint256 _value) isApproved {
	frozenValue[_addr] = _value;
    }

    function setFrozenBlocknum(address _addr, uint256 _blocknum) isApproved {
	frozenBlocknum[_addr] = _blocknum;
    }

    function transfer(address _to, address _from,  uint256 _value) isApproved {
	balances[_to] += _value;
	balances[_from] -= _value;
    }
}
