// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IVerifier {
    /// @notice Verify zk-Proof of Service over a batch of receipts
    /// @param proof Opaque proof bytes
    /// @param publicInputs ABI-encoded public inputs (sid, W_value, etc.)
    /// @return ok true if valid
    function verifyPoS(bytes calldata proof, bytes calldata publicInputs) external view returns (bool ok);

    /// @notice Optional: PoP can be routed/verified for eligibility
    function verifyPoP(bytes calldata proof, bytes calldata publicInputs) external view returns (bool ok);

    /// @notice current code hash/version id for canary gating
    function verifierVersion() external view returns (bytes32);
}
