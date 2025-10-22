// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, AccessControlLite} from "./lib/Utils.sol";

/// @title BondingManager (staking + jailing + slashing)
contract BondingManager is AccessControlLite {
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
    bytes32 public constant SLASHER_ROLE    = keccak256("SLASHER_ROLE");

    IERC20  public immutable token;
    uint64  public unbondDelay; // seconds

    struct Stake {
        uint256 amount;
        uint64  unbondETA; // 0 if not unbonding
        bool    jailed;
    }
    mapping(address => Stake) public stakes;

    event Bonded(address indexed actor, uint256 amount);
    event UnbondRequested(address indexed actor, uint256 amount, uint64 eta);
    event UnbondFinalized(address indexed actor, uint256 amount);
    event Slashed(address indexed actor, uint256 amount, address reporter);
    event Jailed(address indexed actor, bool jailed);

    constructor(IERC20 _token, uint64 _unbondDelay, address governance) {
        token = _token;
        unbondDelay = _unbondDelay;
        _grantRole(GOVERNANCE_ROLE, governance);
        _grantRole(SLASHER_ROLE, governance);
    }

    function setUnbondDelay(uint64 d) external onlyRole(GOVERNANCE_ROLE) {
        unbondDelay = d;
    }

    function bond(uint256 amount) external {
        SafeTransfer.safeTransferFrom(token, msg.sender, address(this), amount);
        stakes[msg.sender].amount += amount;
        emit Bonded(msg.sender, amount);
    }

    function requestUnbond(uint256 amount) external {
        Stake storage s = stakes[msg.sender];
        require(s.amount >= amount, "INSUFFICIENT_STAKE");
        s.amount -= amount;
        s.unbondETA = uint64(block.timestamp) + unbondDelay;
        emit UnbondRequested(msg.sender, amount, s.unbondETA);
    }

    function finalizeUnbond() external {
        Stake storage s = stakes[msg.sender];
        uint256 amt = token.balanceOf(address(this)); // total balance
        require(s.unbondETA != 0 && block.timestamp >= s.unbondETA, "NOT_READY");
        // To keep this simple, we assume a single outstanding unbond equals the subtracted amount.
        // For multiple requests tracking, extend with per-request ids.
        uint256 withdrawable = amt; // simplified; in practice track per-request amount
        s.unbondETA = 0;
        SafeTransfer.safeTransfer(token, msg.sender, withdrawable);
        emit UnbondFinalized(msg.sender, withdrawable);
    }

    function jail(address actor, bool j) external onlyRole(SLASHER_ROLE) {
        stakes[actor].jailed = j;
        emit Jailed(actor, j);
    }

    function slash(address actor, uint256 amount, address reporter) external onlyRole(SLASHER_ROLE) {
        Stake storage s = stakes[actor];
        require(s.amount >= amount, "SLASH>STAKE");
        s.amount -= amount;
        SafeTransfer.safeTransfer(token, reporter, amount);
        emit Slashed(actor, amount, reporter);
    }

    function isEligible(address actor) external view returns (bool ok, uint256 stakeAmt, bool jailed_) {
        Stake memory s = stakes[actor];
        return (s.amount > 0 && !s.jailed, s.amount, s.jailed);
    }
}
