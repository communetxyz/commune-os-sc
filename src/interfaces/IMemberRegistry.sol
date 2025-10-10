// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Represents a member of a commune
/// @dev Members are stored in arrays per commune for efficient iteration
struct Member {
    /// @notice Ethereum address of the member
    address walletAddress;
    /// @notice ID of the commune this member belongs to
    uint256 communeId;
    /// @notice Whether the member is currently active
    bool active;
}

/// @title IMemberRegistry
/// @notice Interface for managing commune members and their status
interface IMemberRegistry {
    // Events
    event MemberRegistered(address indexed member, uint256 indexed communeId, uint256 collateral, uint256 timestamp);

    // Errors
    error InvalidAddress();
    error AlreadyRegistered();

    // Functions
    function registerMember(uint256 communeId, address memberAddress, uint256 collateralAmount) external;

    function isMember(uint256 communeId, address memberAddress) external view returns (bool);

    function areMembers(uint256 communeId, address[] memory addresses) external view returns (bool[] memory results);

    function getCommuneMembers(uint256 communeId) external view returns (address[] memory);

    function getMemberCount(uint256 communeId) external view returns (uint256);

    function getMemberStatus(address memberAddress) external view returns (Member memory);
}
