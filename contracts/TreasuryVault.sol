// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, AccessControlLite} from "./lib/Utils.sol";

/// @title TreasuryVault (DAO funds)
contract TreasuryVault is AccessControlLite {
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");

    event ReceivedETH(address indexed from, uint256 amount);
    event ERC20Withdrawn(address indexed token, address indexed to, uint256 amount, bytes32 ref);
    event ETHWithdrawn(address indexed to, uint256 amount, bytes32 ref);

    receive() external payable { emit ReceivedETH(msg.sender, msg.value); }

    constructor(address governance) {
        _grantRole(GOVERNANCE_ROLE, governance);
    }

    function withdrawToken(IERC20 token, address to, uint256 amount, bytes32 ref)
        external onlyRole(GOVERNANCE_ROLE)
    {
        SafeTransfer.safeTransfer(token, to, amount);
        emit ERC20Withdrawn(address(token), to, amount, ref);
    }

    function withdrawETH(address to, uint256 amount, bytes32 ref)
        external onlyRole(GOVERNANCE_ROLE)
    {
        SafeTransfer.safeTransferETH(to, amount);
        emit ETHWithdrawn(to, amount, ref);
    }
}
