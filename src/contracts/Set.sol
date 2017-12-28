pragma solidity ^0.4.11;

/// Implements functions to support an iterable set structure modeled as a mapping overlayed with
/// a doubly linked list of iterable nodes
library Set {

    /// Actual set data structure
    struct set {
	address head;
	address tail;
	address current;
	uint setSize;
	mapping (address => node) map;
    }

    /// Node of mapping which stores linked list references
    struct node {
	address prev;
	address next;
	bool member;
    }

    function Set() {}

    /// Add an address to the set
    function insert(set storage self, address _addr) returns (bool) {
	if(!self.map[_addr].member) {
	    if(self.setSize == 0) {
		self.head = _addr;
	    }
	    else {
		self.map[_addr].prev = self.tail;
	    }

	    self.tail = _addr;
	    self.map[_addr].member = true;
	    self.setSize++;
	}
	return false;
    }

    // Remove an address from the set
    function remove(set storage self, address _addr) returns (bool) {
	if(self.map[_addr].member) {
	    if(self.setSize == 1) {
		delete self.head;
		delete self.tail;
            }
	    else {
		self.map[self.map[_addr].prev].next = self.map[_addr].next;
		self.map[self.map[_addr].next].prev = self.map[_addr].prev;
		if(_addr == self.head)
		    self.head = self.map[_addr].next;
		if(_addr == self.tail)
		    self.tail = self.map[_addr].prev;
	    }

	    delete self.map[_addr];
	    self.setSize--;
	}
	return false;
    }

    // Returns the size of the set
    function size(set storage self) returns (uint) {
	return self.setSize;
    }

    // Returns true if the address belongs to the set
    function contains(set storage self, address _addr) returns (bool) {
	return self.map[_addr].member;
    }

    // Reset the iterator to point at the head of the list
    function iterateStart (set storage self) {
	self.current = self.head;
    }

    // Obtain the next address and iterate
    function iterateNext (set storage self) returns (address) {
	if(self.map[self.map[self.current].next].member) {
	    return self.map[self.current].next;
	}
    }

//----------------------------------------------------------------------


    function getStuff(set storage self) returns (bool) {
	self.map[self.map[self.current].next].member; self.map[self.map[self.head].next].member;
    }
    function getStuff2(set storage self) returns (bool) {
	self.map[self.map[self.current].next].member; self.map[self.map[self.head].next].member;
    }
    function getStuff3(set storage self) returns (bool) {
	self.map[self.map[self.current].next].member; self.map[self.map[self.head].next].member;
    }
    function getStuff4(set storage self) returns (bool) {
	self.map[self.map[self.current].next].member; self.map[self.map[self.head].next].member;
    }
    function getStuff5(set storage self) returns (bool) {
	self.map[self.map[self.current].next].member; self.map[self.map[self.head].next].member;
    }
    function getStuff6(set storage self) returns (bool) {
	self.map[self.map[self.current].next].member; self.map[self.map[self.head].next].member;
    }
    function getStuff7(set storage self) returns (bool) {
	self.map[self.map[self.current].next].member; self.map[self.map[self.head].next].member;
    }
    function getThings(set storage self) returns (bool) {
	self.map[self.map[self.current].next].member; self.map[self.map[self.head].next].member;
    }
    function getThings2(set storage self) returns (bool) {
	self.map[self.map[self.current].next].member; self.map[self.map[self.head].next].member;
    }
    function getThings3(set storage self) returns (bool) {
	self.map[self.map[self.current].next].member; self.map[self.map[self.head].next].member;
    }
    function getThings4(set storage self) returns (bool) {
	self.map[self.map[self.current].next].member; self.map[self.map[self.head].next].member;
    }
    function getThings5(set storage self) returns (bool) {
	self.map[self.map[self.current].next].member; self.map[self.map[self.head].next].member;
    }
    function getThings6(set storage self) returns (bool) {
	self.map[self.map[self.current].next].member; self.map[self.map[self.head].next].member;
    }
    function getThings7(set storage self) returns (bool) {
	self.map[self.map[self.current].next].member; self.map[self.map[self.head].next].member;
    }
    function takeStuff(set storage self) returns (bool) {
	self.map[self.map[self.current].next].member; self.map[self.map[self.head].next].member;
    }
    function takeStuff2(set storage self) returns (bool) {
	self.map[self.map[self.current].next].member; self.map[self.map[self.head].next].member;
    }
    function takeStuff3(set storage self) returns (bool) {
	self.map[self.map[self.current].next].member; self.map[self.map[self.head].next].member;
    }
    function takeStuff4(set storage self) returns (bool) {
	self.map[self.map[self.current].next].member; self.map[self.map[self.head].next].member;
    }
    function takeStuff5(set storage self) returns (bool) {
	self.map[self.map[self.current].next].member; self.map[self.map[self.head].next].member;
    }
    function takeStuff6(set storage self) returns (bool) {
	self.map[self.map[self.current].next].member; self.map[self.map[self.head].next].member;
    }
    function takeStuff7(set storage self) returns (bool) {
	self.map[self.map[self.current].next].member; self.map[self.map[self.head].next].member;
    }
    function takeThings(set storage self) returns (bool) {
	self.map[self.map[self.current].next].member; self.map[self.map[self.head].next].member;
    }
    function takeThings2(set storage self) returns (bool) {
	self.map[self.map[self.current].next].member; self.map[self.map[self.head].next].member;
    }
    function takeThings3(set storage self) returns (bool) {
	self.map[self.map[self.current].next].member; self.map[self.map[self.head].next].member;
    }
    function takeThings4(set storage self) returns (bool) {
	self.map[self.map[self.current].next].member; self.map[self.map[self.head].next].member;
    }
    function takeThings5(set storage self) returns (bool) {
	self.map[self.map[self.current].next].member; self.map[self.map[self.head].next].member;
    }
    function takeThings6(set storage self) returns (bool) {
	self.map[self.map[self.current].next].member; self.map[self.map[self.head].next].member;
    }
    function takeThings7(set storage self) returns (bool) {
	self.map[self.map[self.current].next].member; self.map[self.map[self.head].next].member;
    }

}
