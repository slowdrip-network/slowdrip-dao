// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AccessControlLite} from "./lib/Utils.sol";
import {IVerifier} from "./interfaces/IVerifier.sol";

/// @title VerifierRegistry (switchable verifier with canary gates)
contract VerifierRegistry is AccessControlLite, IVerifier {
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");

    IVerifier public current;

    event VerifierUpdated(address indexed implementation, bytes32 version);

    constructor(address governance, IVerifier impl) {
        _grantRole(GOVERNANCE_ROLE, governance);
        current = impl;
        emit VerifierUpdated(address(impl), impl.verifierVersion());
    }

    function setVerifier(IVerifier impl) external onlyRole(GOVERNANCE_ROLE) {
        current = impl;
        emit VerifierUpdated(address(impl), impl.verifierVersion());
    }

    // passthrough
    function verifyPoS(bytes calldata proof, bytes calldata publicInputs) external view override returns (bool ok) {
        return current.verifyPoS(proof, publicInputs);
    }

    function verifyPoP(bytes calldata proof, bytes calldata publicInputs) external view override returns (bool ok) {
        return current.verifyPoP(proof, publicInputs);
    }

    function verifierVersion() external view override returns (bytes32) {
        return current.verifierVersion();
    }
}
