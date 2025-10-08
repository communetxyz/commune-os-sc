// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./interfaces/ICollateralManager.sol";
import "./CommuneOSModule.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title CollateralManager
/// @notice Manages collateral deposits and slashing (no withdrawals)
/// @dev Supports ERC20 tokens for collateral
contract CollateralManager is CommuneOSModule, ICollateralManager {
    using SafeERC20 for IERC20;

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
    /// @dev Uses safeTransferFrom to pull ERC20 tokens from member
    function depositCollateral(address member, uint256 amount) external onlyCommuneOS {
        if (amount == 0) revert InvalidDepositAmount();

        // ERC20 token transfer using SafeERC20
        collateralToken.safeTransferFrom(member, address(this), amount);

        collateralBalance[member] += amount;
        emit CollateralDeposited(member, amount);
    }

    /// @notice Slash collateral from a member and transfer to recipient
    /// @param member The member to slash from
    /// @param amount The amount to slash
    /// @param recipient The recipient of slashed funds
    /// @dev Uses safeTransfer to send ERC20 tokens to recipient
    function slashCollateral(address member, uint256 amount, address recipient) external onlyCommuneOS {
        collateralBalance[member] -= amount; // Will revert if insufficient balance

        // ERC20 token transfer using SafeERC20
        collateralToken.safeTransfer(recipient, amount);

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
