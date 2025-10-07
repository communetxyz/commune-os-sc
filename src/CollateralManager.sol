// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./interfaces/ICollateralManager.sol";

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
}

/// @title CollateralManager
/// @notice Manages collateral deposits and slashing (no withdrawals)
/// @dev Supports both native ETH and ERC20 tokens for collateral
contract CollateralManager is ICollateralManager {
    address public immutable communeOS;
    IERC20 public immutable collateralToken;
    bool public immutable useERC20;

    // Member address => collateral balance
    mapping(address => uint256) public collateralBalance;

    /// @param _collateralToken Address of ERC20 token (address(0) for native ETH)
    constructor(address _collateralToken) {
        communeOS = msg.sender;
        useERC20 = _collateralToken != address(0);
        collateralToken = IERC20(_collateralToken); // Safe to set even if address(0)
    }

    modifier onlyCommuneOS() {
        if (msg.sender != communeOS) revert Unauthorized();
        _;
    }

    /// @notice Deposit collateral for a member
    /// @param member The member address
    /// @param amount The amount to deposit
    /// @dev For ERC20: uses transferFrom. For ETH: expects msg.value
    function depositCollateral(address member, uint256 amount) external payable onlyCommuneOS {
        if (amount == 0) revert InvalidDepositAmount();

        if (useERC20) {
            // ERC20 token transfer
            bool success = collateralToken.transferFrom(member, address(this), amount);
            if (!success) revert TransferFailed();
        } else {
            // Native ETH transfer
            if (msg.value != amount) revert InvalidDepositAmount();
        }

        collateralBalance[member] += amount;
        emit CollateralDeposited(member, amount);
    }

    /// @notice Slash collateral from a member and transfer to recipient
    /// @param member The member to slash from
    /// @param amount The amount to slash
    /// @param recipient The recipient of slashed funds
    /// @dev For ERC20: uses token.transfer. For ETH: uses call
    function slashCollateral(address member, uint256 amount, address recipient) external onlyCommuneOS {
        collateralBalance[member] -= amount; // Will revert if insufficient balance

        if (useERC20) {
            // ERC20 token transfer
            bool success = collateralToken.transfer(recipient, amount);
            if (!success) revert TransferFailed();
        } else {
            // Native ETH transfer
            (bool success,) = recipient.call{value: amount}("");
            if (!success) revert TransferFailed();
        }

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
