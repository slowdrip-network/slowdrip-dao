// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title DRIP — Fixed-supply ERC20 with genesis allocations (no mint/burn)
/// @notice Total supply is minted once in the constructor to the provided recipients.
///         No further minting/burning is possible. Minimal ERC-20, no OZ dependencies.
contract DRIP {
    // --- ERC20 metadata ---
    string public constant name = "SlowDrip Token";
    string public constant symbol = "DRIP";
    uint8  public constant decimals = 18;

    // 221,000,000 * 10^18  (using ether unit for readability)
    uint256 public constant totalSupply = 221_000_000 ether;

    // --- ERC20 storage ---
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    // --- ERC20 events ---
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /// @param recipients addresses to receive genesis tokens
    /// @param amounts token amounts (18 decimals) matching recipients; sum must equal totalSupply
    constructor(address[] memory recipients, uint256[] memory amounts) {
        require(recipients.length == amounts.length, "LEN_MISMATCH");
        uint256 sum;
        for (uint256 i = 0; i < recipients.length; i++) {
            address to = recipients[i];
            uint256 amt = amounts[i];
            require(to != address(0), "ZERO_ADDR");
            balanceOf[to] += amt;
            sum += amt;
            emit Transfer(address(0), to, amt);
        }
        require(sum == totalSupply, "BAD_SUM_SUPPLY");
    }

    // --- ERC20 logic ---
    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 a = allowance[from][msg.sender];
        require(a >= amount, "ALLOW_LOW");
        // unchecked is safe because require above
        unchecked { allowance[from][msg.sender] = a - amount; }
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(to != address(0), "TO_ZERO");
        uint256 bal = balanceOf[from];
        require(bal >= amount, "BAL_LOW");
        unchecked {
            balanceOf[from] = bal - amount;
            balanceOf[to] += amount;
        }
        emit Transfer(from, to, amount);
    }
}
