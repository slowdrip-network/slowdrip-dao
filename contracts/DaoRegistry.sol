// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AccessControlLite} from "./lib/Utils.sol";

/// @title DaoRegistry (Primary contract address to list in Articles of Organization)
contract DaoRegistry is AccessControlLite {
    bytes32 public constant ADMIN_ROLE      = keccak256("ADMIN_ROLE");       // bootstrap key to set initial roles
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");  // Governor/Timelock
    bytes32 public constant OPERATOR_ROLE   = keccak256("OPERATOR_ROLE");    // service ops (optional)

    string  public daoName;
    bytes32 public constitutionHash; // hash(IPFS Operating Agreement/Constitution)

    // Declared module pointers (updatable only by Governance)
    address public treasury;
    address public governance;
    address public verifier;       // zk-PoS/PoP verifier/registry
    address public feeRouter;
    address public parameterStore;
    address public bondingManager;
    address public fraudProof;
    address public sessionEscrow;

    event RegistryInitialized(string name, bytes32 constitutionHash, address admin);
    event ModuleUpdated(string indexed key, address indexed value);

    constructor(string memory _name, bytes32 _constitutionHash, address admin) {
        daoName = _name;
        constitutionHash = _constitutionHash;
        _grantRole(ADMIN_ROLE, admin);
        _grantRole(GOVERNANCE_ROLE, admin); // can later be revoked from EOA when Governor takes over
        emit RegistryInitialized(_name, _constitutionHash, admin);
    }

    // --- Governance-only setters ---
    function setTreasury(address a) external onlyRole(GOVERNANCE_ROLE) { treasury = a; emit ModuleUpdated("treasury", a); }
    function setGovernance(address a) external onlyRole(GOVERNANCE_ROLE) { governance = a; emit ModuleUpdated("governance", a); }
    function setVerifier(address a) external onlyRole(GOVERNANCE_ROLE) { verifier = a; emit ModuleUpdated("verifier", a); }
    function setFeeRouter(address a) external onlyRole(GOVERNANCE_ROLE) { feeRouter = a; emit ModuleUpdated("feeRouter", a); }
    function setParameterStore(address a) external onlyRole(GOVERNANCE_ROLE) { parameterStore = a; emit ModuleUpdated("parameterStore", a); }
    function setBondingManager(address a) external onlyRole(GOVERNANCE_ROLE) { bondingManager = a; emit ModuleUpdated("bondingManager", a); }
    function setFraudProof(address a) external onlyRole(GOVERNANCE_ROLE) { fraudProof = a; emit ModuleUpdated("fraudProof", a); }
    function setSessionEscrow(address a) external onlyRole(GOVERNANCE_ROLE) { sessionEscrow = a; emit ModuleUpdated("sessionEscrow", a); }
}
