// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title ICollateralManager
/// @notice Interface for managing collateral deposits and slashing (no withdrawals)
interface ICollateralManager {
    // Events
    event CollateralDeposited(address indexed member, uint256 amount);
    event CollateralSlashed(address indexed member, uint256 amount, address indexed recipient);

    // Errors
    error InvalidDepositAmount();
    error TransferFailed();

    // Functions
    function depositCollateral(address member) external payable;

    function slashCollateral(address member, uint256 amount, address recipient)
        external
        returns (uint256 actualSlashed);

    function isCollateralSufficient(address member, uint256 amount) external view returns (bool);

    function getCollateralBalance(address member) external view returns (uint256);
}
