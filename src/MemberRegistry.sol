// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./Types.sol";
import "./interfaces/IMemberRegistry.sol";

/// @title MemberRegistry
/// @notice Manages commune members and their status
contract MemberRegistry is IMemberRegistry {
    address public immutable communeOS;

    // CommuneId => array of member addresses
    mapping(uint256 => address[]) public communeMembers;

    // Member address => Member data
    mapping(address => Member) public members;

    constructor() {
        communeOS = msg.sender;
    }

    modifier onlyCommuneOS() {
        if (msg.sender != communeOS) revert Unauthorized();
        _;
    }

    /// @notice Register a new member to a commune
    /// @param communeId The commune ID
    /// @param memberAddress The member's address
    /// @param collateralAmount The collateral deposited
    function registerMember(uint256 communeId, address memberAddress, uint256 collateralAmount)
        external
        onlyCommuneOS
    {
        if (memberAddress == address(0)) revert InvalidAddress();
        if (members[memberAddress].active) revert AlreadyRegistered();

        members[memberAddress] = Member({
            walletAddress: memberAddress,
            joinDate: block.timestamp,
            communeId: communeId,
            collateralDeposited: collateralAmount,
            active: true
        });

        communeMembers[communeId].push(memberAddress);

        emit MemberRegistered(memberAddress, communeId, collateralAmount, block.timestamp);
    }

    /// @notice Check if an address is a member of a commune
    /// @param communeId The commune ID
    /// @param memberAddress The member's address
    /// @return bool True if member belongs to commune
    function isMember(uint256 communeId, address memberAddress) external view returns (bool) {
        return members[memberAddress].active && members[memberAddress].communeId == communeId;
    }

    /// @notice Get all members of a commune
    /// @param communeId The commune ID
    /// @return address[] Array of member addresses
    function getCommuneMembers(uint256 communeId) external view returns (address[] memory) {
        return communeMembers[communeId];
    }

    /// @notice Get member count for a commune
    /// @param communeId The commune ID
    /// @return uint256 Number of members
    function getMemberCount(uint256 communeId) external view returns (uint256) {
        return communeMembers[communeId].length;
    }

    /// @notice Get member status
    /// @param memberAddress The member's address
    /// @return Member The member data
    function getMemberStatus(address memberAddress) external view returns (Member memory) {
        return members[memberAddress];
    }
}
