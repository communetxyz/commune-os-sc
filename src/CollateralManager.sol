// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./interfaces/ICollateralManager.sol";
import "./CommuneOSModule.sol";

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
}

/// @title CollateralManager
/// @notice Manages collateral deposits and slashing (no withdrawals)
/// @dev Supports ERC20 tokens for collateral
contract CollateralManager is CommuneOSModule, ICollateralManager {
    /// @notice The ERC20 token contract used for collateral
    IERC20 public immutable collateralToken;

    /// @notice Tracks collateral balance for each member
    /// @dev Maps member address => collateral balance in token units
    mapping(address => uint256) public collateralBalance;

    /// @notice Initializes the CollateralManager with token configuration
    /// @param _collateralToken Address of ERC20 token
    constructor(address _collateralToken) {
        require(_collateralToken != address(0), "Invalid token address");
        collateralToken = IERC20(_collateralToken);
    }

    /// @notice Deposit collateral for a member
    /// @param member The member address
    /// @param amount The amount to deposit
    /// @dev Uses transferFrom to pull ERC20 tokens from member
    function depositCollateral(address member, uint256 amount) external onlyCommuneOS {
        if (amount == 0) revert InvalidDepositAmount();

        // ERC20 token transfer
        bool success = collateralToken.transferFrom(member, address(this), amount);
        if (!success) revert TransferFailed();

        collateralBalance[member] += amount;
        emit CollateralDeposited(member, amount);
    }

    /// @notice Slash collateral from a member and transfer to recipient
    /// @param member The member to slash from
    /// @param amount The amount to slash
    /// @param recipient The recipient of slashed funds
    /// @dev Uses token.transfer to send ERC20 tokens to recipient
    function slashCollateral(address member, uint256 amount, address recipient) external onlyCommuneOS {
        collateralBalance[member] -= amount; // Will revert if insufficient balance

        // ERC20 token transfer
        bool success = collateralToken.transfer(recipient, amount);
        if (!success) revert TransferFailed();

        emit CollateralSlashed(member, amount, recipient);
    }

    /// @notice Check if member has sufficient collateral
    /// @param member The member to check
    /// @param amount The required amount
    /// @return bool True if member has sufficient collateral
    function isCollateralSufficient(address member, uint256 amount) external view returns (bool) {
        return collateralBalance[member] >= amount;
    }

    /// @notice Get collateral balance for a member
    /// @param member The member address
    /// @return uint256 The collateral balance
    function getCollateralBalance(address member) external view returns (uint256) {
        return collateralBalance[member];
    }
}
