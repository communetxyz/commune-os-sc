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
    /// @notice Username chosen by the member (optional, can be empty string)
    string username;
}

/// @title IMemberRegistry
/// @notice Interface for managing commune members and their status
interface IMemberRegistry {
    // Events
    event MemberRegistered(
        address indexed member, uint256 indexed communeId, uint256 collateral, uint256 timestamp, string username
    );
    event MemberJoined(
        address indexed member, uint256 indexed communeId, uint256 collateralAmount, uint256 timestamp, string username
    );

    // Errors
    error InvalidAddress();
    error AlreadyRegistered();
    error InvalidInvite();
    error NonceAlreadyUsed();
    error InvalidSignatureLength();

    // Functions
    function validateInvite(uint256 communeId, address creatorAddress, uint256 nonce, bytes memory signature)
        external
        view;

    function joinCommune(
        uint256 communeId, address memberAddress, uint256 nonce, uint256 collateralAmount, string memory username
    ) external;

    function isNonceUsed(uint256 communeId, uint256 nonce) external view returns (bool);

    function registerMember(uint256 communeId, address memberAddress, uint256 collateralAmount, string memory username)
        external;

    function isMember(uint256 communeId, address memberAddress) external view returns (bool);

    function areMembers(uint256 communeId, address[] memory addresses) external view returns (bool[] memory results);

    function getCommuneMembers(uint256 communeId) external view returns (address[] memory);

    function getMemberCount(uint256 communeId) external view returns (uint256);

    function getMemberStatus(address memberAddress) external view returns (Member memory);

    function memberUsername(address memberAddress) external view returns (string memory);
}
