// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./interfaces/ICollateralManager.sol";

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
}

/// @title CollateralManager
/// @notice Manages collateral deposits and slashing (no withdrawals)
contract CollateralManager is ICollateralManager {
    address public immutable communeOS;
    IERC20 public immutable collateralToken;

    // Member address => collateral balance
    mapping(address => uint256) public collateralBalance;

    constructor(address _collateralToken) {
        communeOS = msg.sender;
        collateralToken = IERC20(_collateralToken);
    }

    modifier onlyCommuneOS() {
        if (msg.sender != communeOS) revert Unauthorized();
        _;
    }

    /// @notice Deposit collateral for a member using transferFrom pattern
    /// @param member The member address
    /// @param amount The amount to deposit
    function depositCollateral(address member, uint256 amount) external onlyCommuneOS {
        if (amount == 0) revert InvalidDepositAmount();

        bool success = collateralToken.transferFrom(member, address(this), amount);
        if (!success) revert TransferFailed();

        collateralBalance[member] += amount;
        emit CollateralDeposited(member, amount);
    }

    /// @notice Slash collateral from a member and transfer to recipient
    /// @param member The member to slash from
    /// @param amount The amount to slash
    /// @param recipient The recipient of slashed funds
    function slashCollateral(address member, uint256 amount, address recipient) external onlyCommuneOS {
        collateralBalance[member] -= amount; // Will revert if insufficient balance

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
