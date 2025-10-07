// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../Types.sol";

/// @title IMemberRegistry
/// @notice Interface for managing commune members and their status
interface IMemberRegistry {
    // Events
    event MemberRegistered(address indexed member, uint256 indexed communeId, uint256 collateral, uint256 timestamp);

    // Errors
    error Unauthorized();
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
