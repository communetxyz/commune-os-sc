// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/ICollateralManager.sol";
import "./CommuneOSModule.sol";

/// @title CollateralManager
/// @notice Manages collateral deposits and slashing (no withdrawals)
/// @dev Supports ERC20 tokens for collateral
contract CollateralManager is CommuneOSModule, ICollateralManager {
    using SafeERC20 for IERC20;

    /// @custom:storage-location erc7201:commune.storage.CollateralManager
    struct CollateralManagerStorage {
        IERC20 collateralToken;
        mapping(address => uint256) collateralBalance;
    }

    // keccak256(abi.encode(uint256(keccak256("commune.storage.CollateralManager")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant CollateralManagerStorageLocation =
        0x1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d9e0f1a00;

    function _getCollateralManagerStorage() private pure returns (CollateralManagerStorage storage $) {
        assembly {
            $.slot := CollateralManagerStorageLocation
        }
    }

    /// @notice Thrown when member has insufficient collateral
    error InsufficientCollateral();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Returns the collateral token address
    function collateralToken() public view returns (IERC20) {
        CollateralManagerStorage storage $ = _getCollateralManagerStorage();
        return $.collateralToken;
    }

    /// @notice Returns the collateral balance for a member
    function collateralBalance(address member) public view returns (uint256) {
        CollateralManagerStorage storage $ = _getCollateralManagerStorage();
        return $.collateralBalance[member];
    }

    /// @notice Initializes the CollateralManager with token configuration
    /// @param _communeOS Address of the main CommuneOS contract
    /// @param _collateralToken Address of ERC20 token
    function initialize(address _communeOS, address _collateralToken) external initializer {
        __CommuneOSModule_init(_communeOS);
        if (_collateralToken == address(0)) revert InvalidTokenAddress();
        CollateralManagerStorage storage $ = _getCollateralManagerStorage();
        $.collateralToken = IERC20(_collateralToken);
    }

    /// @notice Deposit collateral for a member
    /// @param member The member address
    /// @param amount The amount to deposit
    /// @dev Uses safeTransferFrom to pull ERC20 tokens from member
    function depositCollateral(address member, uint256 amount) external onlyCommuneOS {
        if (amount == 0) revert InvalidDepositAmount();
        CollateralManagerStorage storage $ = _getCollateralManagerStorage();

        // ERC20 token transfer using SafeERC20
        $.collateralToken.safeTransferFrom(member, address(this), amount);

        $.collateralBalance[member] += amount;
        emit CollateralDeposited(member, amount);
    }

    /// @notice Slash collateral from a member and transfer to recipient
    /// @param member The member to slash from
    /// @param amount The amount to slash
    /// @param recipient The recipient of slashed funds
    /// @dev Uses checks-effects-interactions pattern with SafeERC20 to prevent reentrancy
    function slashCollateral(address member, uint256 amount, address recipient) external onlyCommuneOS {
        CollateralManagerStorage storage $ = _getCollateralManagerStorage();

        // Checks
        if ($.collateralBalance[member] < amount) revert InsufficientCollateral();

        // Effects
        $.collateralBalance[member] -= amount;

        // Interactions - SafeERC20 automatically reverts on failure
        $.collateralToken.safeTransfer(recipient, amount);

        emit CollateralSlashed(member, amount, recipient);
    }

    /// @notice Check if member has sufficient collateral
    /// @param member The member to check
    /// @param amount The required amount
    /// @return bool True if member has sufficient collateral
    function isCollateralSufficient(address member, uint256 amount) external view returns (bool) {
        CollateralManagerStorage storage $ = _getCollateralManagerStorage();
        return $.collateralBalance[member] >= amount;
    }

    /// @notice Get collateral balance for a member
    /// @param member The member address
    /// @return uint256 The collateral balance
    function getCollateralBalance(address member) external view returns (uint256) {
        CollateralManagerStorage storage $ = _getCollateralManagerStorage();
        return $.collateralBalance[member];
    }

    /// @notice Withdraw all remaining collateral for a member
    /// @param member The member address
    /// @dev Uses checks-effects-interactions pattern with SafeERC20 to prevent reentrancy
    function withdrawCollateral(address member) external onlyCommuneOS {
        CollateralManagerStorage storage $ = _getCollateralManagerStorage();

        // Get the full balance
        uint256 amount = $.collateralBalance[member];

        // Checks - only withdraw if there's a balance
        if (amount == 0) return;

        // Effects
        $.collateralBalance[member] = 0;

        // Interactions - SafeERC20 automatically reverts on failure
        $.collateralToken.safeTransfer(member, amount);

        emit CollateralWithdrawn(member, amount);
    }
}
