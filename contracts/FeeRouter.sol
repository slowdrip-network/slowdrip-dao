// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, AccessControlLite} from "./lib/Utils.sol";

/// @title FeeRouter (splits protocol fee between validators and treasury)
contract FeeRouter is AccessControlLite {
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");

    address public validatorsPool; // e.g., a simple payout address or a pool contract
    address public treasury;       // TreasuryVault
    uint256 public thetaBps;       // θ in basis points (0..10000)
    uint256 public constant BPS = 10_000;

    event SplitUpdated(uint256 thetaBps);
    event EndpointsUpdated(address validatorsPool, address treasury);
    event FeesDistributed(address indexed token, uint256 totalFee, uint256 toValidators, uint256 toTreasury);

    constructor(address governance, address _validatorsPool, address _treasury, uint256 _thetaBps) {
        require(_thetaBps <= BPS, "THETA_GT_100_PERCENT");
        _grantRole(GOVERNANCE_ROLE, governance);
        validatorsPool = _validatorsPool;
        treasury = _treasury;
        thetaBps = _thetaBps;
    }

    function setSplit(uint256 _thetaBps) external onlyRole(GOVERNANCE_ROLE) {
        require(_thetaBps <= BPS, "THETA_GT_100_PERCENT");
        thetaBps = _thetaBps;
        emit SplitUpdated(_thetaBps);
    }

    function setEndpoints(address vp, address t) external onlyRole(GOVERNANCE_ROLE) {
        validatorsPool = vp;
        treasury = t;
        emit EndpointsUpdated(vp, t);
    }

    /// @notice Distribute an already-collected fee (ERC20)
    function distributeFeesToken(IERC20 token, uint256 totalFee) external {
        uint256 vAmt = (totalFee * thetaBps) / BPS;
        uint256 tAmt = totalFee - vAmt;
        SafeTransfer.safeTransfer(token, validatorsPool, vAmt);
        SafeTransfer.safeTransfer(token, treasury, tAmt);
        emit FeesDistributed(address(token), totalFee, vAmt, tAmt);
    }

    /// @notice Distribute an already-collected fee (native)
    function distributeFeesETH() external payable {
        uint256 vAmt = (msg.value * thetaBps) / BPS;
        uint256 tAmt = msg.value - vAmt;
        (bool ok1, ) = validatorsPool.call{value: vAmt}("");
        require(ok1, "VAL_ETH_FAIL");
        (bool ok2, ) = treasury.call{value: tAmt}("");
        require(ok2, "TRE_ETH_FAIL");
        emit FeesDistributed(address(0), msg.value, vAmt, tAmt);
    }
}
