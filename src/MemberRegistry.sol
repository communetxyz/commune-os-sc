// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Member} from "./interfaces/IMemberRegistry.sol";
import "./interfaces/IMemberRegistry.sol";
import "./CommuneOSModule.sol";

/// @title MemberRegistry
/// @notice Manages commune members and their status
/// @dev Uses memberCommuneId == 0 as sentinel value for non-members
contract MemberRegistry is CommuneOSModule, IMemberRegistry {
    /// @notice Stores all members for each commune in an array
    /// @dev communeId => Member[]
    mapping(uint256 => Member[]) public communeMembers;

    /// @notice Maps member addresses to their commune ID
    /// @dev 0 means not registered (since commune IDs start at 1)
    mapping(address => uint256) public memberCommuneId;

    /// @notice Registers a new member to a commune
    /// @param communeId ID of the commune to join
    /// @param memberAddress Address of the new member
    /// @dev Third parameter (collateralAmount) is ignored but kept for interface compatibility
    /// @dev Reverts if address is zero or already registered to any commune
    function registerMember(uint256 communeId, address memberAddress, uint256) external onlyCommuneOS {
        if (memberAddress == address(0)) revert InvalidAddress();
        if (memberCommuneId[memberAddress] != 0) revert AlreadyRegistered();

        Member memory newMember = Member({walletAddress: memberAddress, communeId: communeId, active: true});

        communeMembers[communeId].push(newMember);
        memberCommuneId[memberAddress] = communeId;

        emit MemberRegistered(memberAddress, communeId, 0, block.timestamp);
    }

    /// @notice Checks if an address is a member of a specific commune
    /// @param communeId ID of the commune to check
    /// @param memberAddress Address to verify membership
    /// @return bool True if address is an active member of the commune
    /// @dev Returns false if communeId is 0 to prevent false positives
    function isMember(uint256 communeId, address memberAddress) external view returns (bool) {
        return memberCommuneId[memberAddress] == communeId && communeId != 0;
    }

    /// @notice Batch checks if multiple addresses are members of a commune
    /// @param communeId ID of the commune to check
    /// @param addresses Array of addresses to verify
    /// @return results Array of booleans, true for each address that is a member
    /// @dev More gas-efficient than multiple isMember() calls
    function areMembers(uint256 communeId, address[] memory addresses) external view returns (bool[] memory results) {
        results = new bool[](addresses.length);
        for (uint256 i = 0; i < addresses.length; i++) {
            results[i] = memberCommuneId[addresses[i]] == communeId && communeId != 0;
        }
        return results;
    }

    /// @notice Retrieves all member addresses for a commune
    /// @param communeId ID of the commune
    /// @return address[] Array of member wallet addresses
    /// @dev Extracts addresses from Member structs for convenience
    function getCommuneMembers(uint256 communeId) external view returns (address[] memory) {
        Member[] memory members = communeMembers[communeId];
        address[] memory addresses = new address[](members.length);
        for (uint256 i = 0; i < members.length; i++) {
            addresses[i] = members[i].walletAddress;
        }
        return addresses;
    }

    /// @notice Gets the total number of members in a commune
    /// @param communeId ID of the commune
    /// @return uint256 Count of members
    /// @dev Simply returns the length of the members array
    function getMemberCount(uint256 communeId) external view returns (uint256) {
        return communeMembers[communeId].length;
    }

    /// @notice Retrieves full member data for an address
    /// @param memberAddress Address of the member to query
    /// @return Member Complete member struct including communeId and active status
    /// @dev Reverts if address is not registered to any commune
    /// @dev Searches linearly through commune's member array
    function getMemberStatus(address memberAddress) external view returns (Member memory) {
        uint256 communeId = memberCommuneId[memberAddress];
        if (communeId == 0) revert InvalidAddress();

        Member[] memory members = communeMembers[communeId];
        for (uint256 i = 0; i < members.length; i++) {
            if (members[i].walletAddress == memberAddress) {
                return members[i];
            }
        }
        revert InvalidAddress();
    }
}
