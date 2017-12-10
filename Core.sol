/**
 * Track the core values of the charity currency state. This contract will be
 * valid for the rest of time. At any given point, there will be one master
 * controller contract for the currency. This controller will in turn delegate
 * the ability to modify core state. In the event of an upgrade to the
 * controller, approved contracts should be removed and a new address
 * supplied to the Core contract.
 *
 * The Core contract tracks precisely the following state:
 *     - ERC20 balances
 *     - ERC20 allowed spenders
 *     - Flags declaring designated charity addresses
 *     - Block number in which a charity was flagged
 *     - Temporarily frozen user funds
 *     - Block number in which funds were frozen
 */

pragma solidity ^0.4.13;

contract Core {

    address public controller;
    mapping(address => bool) public approved;

    mapping(address => uint) public balances;
    mapping(address => mapping (address => uint)) public allowed;
    mapping(address => bool) public charityStatus;
    mapping(address => uint) public charityBlocknum;
    mapping(address => uint) public frozenValue;
    mapping(address => uint) public frozenBlocknum;

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

    function upgrade(address _addr) {
	controller = _addr;
    }

    function addApproved(address _addr) isController {
	approved[_addr] = true;
    }

    function removeApproved(address _addr) isController {
	approved[_addr] = false;
    }

    function setBalances(address _addr, uint _value) isApproved {
	balances[_addr] = _value;
    }

    function setCharityStatus(address _addr, bool _status) isApproved {
	charityStatus[_addr] = _status;
    }

    function setCharityBlocknum(address _addr, uint _blocknum) isApproved {
	charityBlocknum[_addr] = _blocknum;
    }

    function setAllowed(address _addr, address _allowed, uint _value) isApproved {
	allowed[_addr][_allowed] = _value;
    }

    function setFrozenValue(address _addr, uint _value) isApproved {
	frozenValue[_addr] = _value;
    }

    function setFrozenBlocknum(address _addr, uint _blocknum) isApproved {
	frozenBlocknum[_addr] = _blocknum;
    }

    function transfer(address _to, address _from,  uint _value) isApproved {
	balances[_to] -= _value;
	balances[_from] += _value;
    }
}
