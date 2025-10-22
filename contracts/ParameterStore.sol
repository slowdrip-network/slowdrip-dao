// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AccessControlLite} from "./lib/Utils.sol";

/// @title ParameterStore (bounded, timelocked changes)
contract ParameterStore is AccessControlLite {
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");

    struct Bounds { uint256 min; uint256 max; bool exists; }
    struct Change { uint256 newValue; uint64 eta; }

    mapping(bytes32 => uint256) public valueOf;
    mapping(bytes32 => Bounds)  public boundsOf;
    mapping(bytes32 => Change)  public pending;

    uint64 public delay; // seconds; governance timelock for param updates

    event ParamBounded(bytes32 indexed key, uint256 min, uint256 max);
    event ParamQueued(bytes32 indexed key, uint256 newValue, uint64 eta);
    event ParamCommitted(bytes32 indexed key, uint256 newValue);

    constructor(uint64 _delay, address governance) {
        delay = _delay;
        _grantRole(GOVERNANCE_ROLE, governance);
    }

    function setBounds(bytes32 key, uint256 minv, uint256 maxv, uint256 initial) external onlyRole(GOVERNANCE_ROLE) {
        require(minv <= initial && initial <= maxv, "INIT_OOB");
        boundsOf[key] = Bounds({min:minv, max:maxv, exists:true});
        valueOf[key]  = initial;
        emit ParamBounded(key, minv, maxv);
        emit ParamCommitted(key, initial);
    }

    function queue(bytes32 key, uint256 newValue) external onlyRole(GOVERNANCE_ROLE) {
        Bounds memory b = boundsOf[key];
        require(b.exists, "NO_BOUNDS");
        require(b.min <= newValue && newValue <= b.max, "OOB");
        uint64 eta = uint64(block.timestamp) + delay;
        pending[key] = Change({newValue:newValue, eta:eta});
        emit ParamQueued(key, newValue, eta);
    }

    function commit(bytes32 key) external {
        Change memory c = pending[key];
        require(c.eta != 0 && block.timestamp >= c.eta, "NOT_READY");
        valueOf[key] = c.newValue;
        delete pending[key];
        emit ParamCommitted(key, c.newValue);
    }
}
