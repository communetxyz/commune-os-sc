// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./interfaces/ICollateralManager.sol";

/// @title CollateralManager
/// @notice Manages collateral deposits and slashing (no withdrawals)
contract CollateralManager is ICollateralManager {
    address public immutable communeOS;

    // Member address => collateral balance
    mapping(address => uint256) public collateralBalance;

    constructor() {
        communeOS = msg.sender;
    }

    modifier onlyCommuneOS() {
        if (msg.sender != communeOS) revert Unauthorized();
        _;
    }

    /// @notice Deposit collateral for a member
    /// @param member The member address
    function depositCollateral(address member) external payable onlyCommuneOS {
        if (msg.value == 0) revert InvalidDepositAmount();
        collateralBalance[member] += msg.value;
        emit CollateralDeposited(member, msg.value);
    }

    /// @notice Slash collateral from a member and transfer to recipient
    /// @param member The member to slash from
    /// @param amount The amount to slash
    /// @param recipient The recipient of slashed funds
    /// @return actualSlashed The actual amount slashed (may be less if insufficient collateral)
    function slashCollateral(address member, uint256 amount, address recipient)
        external
        onlyCommuneOS
        returns (uint256 actualSlashed)
    {
        uint256 available = collateralBalance[member];
        actualSlashed = amount > available ? available : amount;

        if (actualSlashed > 0) {
            collateralBalance[member] -= actualSlashed;
            (bool success,) = recipient.call{value: actualSlashed}("");
            if (!success) revert TransferFailed();
            emit CollateralSlashed(member, actualSlashed, recipient);
        }

        return actualSlashed;
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
