// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AccessControlLite} from "./lib/Utils.sol";

interface ISlasher {
    function slash(address actor, uint256 amount, address reporter) external;
    function jail(address actor) external;
}

/// @title FraudProof (evidence intake + governance verdict hook)
contract FraudProof is AccessControlLite {
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");

    struct Case {
        address accused;
        address reporter;
        bytes   evidence; // opaque
        bool    decided;
        bool    valid;
    }

    ISlasher public slasher;
    uint256 public bounty; // paid from DAO (via a separate governance payment) or stake slash routed here

    Case[] public cases;

    event CaseSubmitted(uint256 indexed id, address indexed accused, address indexed reporter);
    event CaseDecided(uint256 indexed id, bool valid, uint256 slashAmount, uint256 reporterBounty);

    constructor(address governance, ISlasher _slasher, uint256 _bounty) {
        _grantRole(GOVERNANCE_ROLE, governance);
        slasher = _slasher;
        bounty  = _bounty;
    }

    function submit(address accused, bytes calldata evidence) external returns (uint256 id) {
        id = cases.length;
        cases.push(Case({accused:accused, reporter:msg.sender, evidence:evidence, decided:false, valid:false}));
        emit CaseSubmitted(id, accused, msg.sender);
    }

    /// @notice Governance decides outcome and amount to slash; bounty paid by treasury off-chain (or via a separate payout hook)
    function decide(uint256 id, bool valid, uint256 slashAmount, bool jailAccused) external onlyRole(GOVERNANCE_ROLE) {
        Case storage c = cases[id];
        require(!c.decided, "ALREADY_DECIDED");
        c.decided = true;
        c.valid = valid;

        if (valid && slashAmount > 0) {
            slasher.slash(c.accused, slashAmount, c.reporter);
            if (jailAccused) slasher.jail(c.accused);
        }
        emit CaseDecided(id, valid, slashAmount, valid ? bounty : 0);
    }

    function getCasesCount() external view returns (uint256) { return cases.length; }
}
