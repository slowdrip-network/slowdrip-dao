// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, AccessControlLite} from "./lib/Utils.sol";
import {IVerifier} from "./interfaces/IVerifier.sol";

interface IFeeRouterLike {
    function distributeFeesToken(IERC20 token, uint256 totalFee) external;
    function distributeFeesETH() external payable;
}

interface IParameterStoreLike {
    function valueOf(bytes32 key) external view returns (uint256);
}

/// @title SessionEscrow (client deposits -> zk-PoS -> miner + fee split)
contract SessionEscrow is AccessControlLite {
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
    bytes32 public constant VALIDATOR_ROLE  = keccak256("VALIDATOR_ROLE");

    IERC20  public immutable token;      // DRIP or stablecoin used for payments
    IVerifier public verifier;
    IFeeRouterLike public feeRouter;
    IParameterStoreLike public params;   // holds f (protocol fee, in bps)

    uint256 public constant BPS = 10_000;

    struct Escrow {
        address client;
        address miner;
        uint256 amount;   // total funded
        bool    settled;
    }
    mapping(bytes32 => Escrow) public escrows; // sid => escrow

    event EscrowFunded(bytes32 indexed sid, address indexed client, uint256 amount);
    event MinerAssigned(bytes32 indexed sid, address indexed miner);
    event Settled(bytes32 indexed sid, address miner, uint256 minerNet, uint256 fee);

    constructor(IERC20 _token, IVerifier _verifier, IFeeRouterLike _feeRouter, IParameterStoreLike _params, address governance) {
        token = _token;
        verifier = _verifier;
        feeRouter = _feeRouter;
        params = _params;
        _grantRole(GOVERNANCE_ROLE, governance);
        _grantRole(VALIDATOR_ROLE, governance);
    }

    function fund(bytes32 sid, uint256 amount) external {
        Escrow storage e = escrows[sid];
        require(e.client == address(0) || e.client == msg.sender, "CLIENT_MISMATCH");
        e.client = msg.sender;
        e.amount += amount;
        SafeTransfer.safeTransferFrom(token, msg.sender, address(this), amount);
        emit EscrowFunded(sid, msg.sender, amount);
    }

    function assignMiner(bytes32 sid, address miner) external onlyRole(VALIDATOR_ROLE) {
        Escrow storage e = escrows[sid];
        require(e.client != address(0), "NO_ESCROW");
        e.miner = miner;
        emit MinerAssigned(sid, miner);
    }

    /// @notice publicInputs encodes: sid, W_value, ...
    function settle(bytes32 sid, bytes calldata proofPoS, bytes calldata publicInputs) external onlyRole(VALIDATOR_ROLE) {
        Escrow storage e = escrows[sid];
        require(!e.settled, "ALREADY_SETTLED");
        require(e.client != address(0) && e.miner != address(0), "INCOMPLETE");

        require(verifier.verifyPoS(proofPoS, publicInputs), "INVALID_PROOF");

        // extract W_value from publicInputs (ABI-encoded as (bytes32 sid, uint256 wValue, ...))
        (bytes32 sidPi, uint256 wValue) = abi.decode(publicInputs, (bytes32, uint256));
        require(sidPi == sid, "SID_MISMATCH");

        uint256 payableAmount = wValue > e.amount ? e.amount : wValue;

        // protocol fee f (bps) from params
        uint256 fBps = params.valueOf(keccak256("protocol_fee_bps"));
        require(fBps <= BPS, "BAD_FEE");

        uint256 fee = (payableAmount * fBps) / BPS;
        uint256 minerNet = payableAmount - fee;

        // pay miner and route fee
        SafeTransfer.safeTransfer(token, e.miner, minerNet);
        SafeTransfer.safeTransfer(token, address(feeRouter), fee);
        feeRouter.distributeFeesToken(token, fee);

        e.amount -= payableAmount;
        e.settled = true;

        emit Settled(sid, e.miner, minerNet, fee);
    }
}
