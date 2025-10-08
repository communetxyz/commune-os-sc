// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title CommuneOSModule
/// @notice Base contract for all CommuneOS modules with shared access control
/// @dev All module contracts inherit from this to ensure only CommuneOS can call them
abstract contract CommuneOSModule {
    /// @notice Address of the main CommuneOS orchestrator contract
    /// @dev Set immutably in constructor to msg.sender (the deploying CommuneOS contract)
    address public immutable communeOS;

    /// @notice Thrown when a non-CommuneOS address attempts a restricted operation
    error Unauthorized();

    /// @notice Sets the CommuneOS address to the contract deployer
    /// @dev Must be deployed by the CommuneOS contract for proper access control
    constructor() {
        communeOS = msg.sender;
    }

    /// @notice Restricts function access to only the CommuneOS contract
    /// @dev Reverts with Unauthorized if called by any address other than communeOS
    modifier onlyCommuneOS() {
        if (msg.sender != communeOS) revert Unauthorized();
        _;
    }
}
