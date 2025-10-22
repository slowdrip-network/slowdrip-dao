// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/IVerifier.sol";

contract MockVerifier is IVerifier {
    bytes32 private _ver = keccak256("mock-verifier-v1");

    function verifyPoS(bytes calldata, bytes calldata) external pure returns (bool ok) {
        return true; // always valid for tests
    }

    function verifyPoP(bytes calldata, bytes calldata) external pure returns (bool ok) {
        return true;
    }

    function verifierVersion() external view returns (bytes32) {
        return _ver;
    }
}
