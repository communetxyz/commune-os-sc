// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Member} from "./Types.sol";
import "./interfaces/IMemberRegistry.sol";
import "./CommuneOSModule.sol";

/// @title MemberRegistry
/// @notice Manages commune members and their status
contract MemberRegistry is CommuneOSModule, IMemberRegistry {
    // CommuneId => array of Members
    mapping(uint256 => Member[]) public communeMembers;

    // Member address => is registered
    mapping(address => bool) public isRegistered;

    // Member address => commune ID
    mapping(address => uint256) public memberCommuneId;

    /// @notice Register a new member to a commune
    /// @param communeId The commune ID
    /// @param memberAddress The member's address
    function registerMember(uint256 communeId, address memberAddress, uint256) external onlyCommuneOS {
        if (memberAddress == address(0)) revert InvalidAddress();
        if (isRegistered[memberAddress]) revert AlreadyRegistered();

        Member memory newMember =
            Member({walletAddress: memberAddress, joinDate: block.timestamp, communeId: communeId, active: true});

        communeMembers[communeId].push(newMember);
        isRegistered[memberAddress] = true;
        memberCommuneId[memberAddress] = communeId;

        emit MemberRegistered(memberAddress, communeId, 0, block.timestamp);
    }

    /// @notice Check if an address is a member of a commune
    /// @param communeId The commune ID
    /// @param memberAddress The member's address
    /// @return bool True if member belongs to commune
    function isMember(uint256 communeId, address memberAddress) external view returns (bool) {
        return isRegistered[memberAddress] && memberCommuneId[memberAddress] == communeId;
    }

    /// @notice Check if multiple addresses are members of a commune
    /// @param communeId The commune ID
    /// @param addresses Array of addresses to check
    /// @return results Array of booleans indicating membership status
    function areMembers(uint256 communeId, address[] memory addresses) external view returns (bool[] memory results) {
        results = new bool[](addresses.length);
        for (uint256 i = 0; i < addresses.length; i++) {
            results[i] = isRegistered[addresses[i]] && memberCommuneId[addresses[i]] == communeId;
        }
        return results;
    }

    /// @notice Get all members of a commune
    /// @param communeId The commune ID
    /// @return address[] Array of member addresses
    function getCommuneMembers(uint256 communeId) external view returns (address[] memory) {
        Member[] memory members = communeMembers[communeId];
        address[] memory addresses = new address[](members.length);
        for (uint256 i = 0; i < members.length; i++) {
            addresses[i] = members[i].walletAddress;
        }
        return addresses;
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
        if (!isRegistered[memberAddress]) revert InvalidAddress();

        uint256 communeId = memberCommuneId[memberAddress];
        Member[] memory members = communeMembers[communeId];
        for (uint256 i = 0; i < members.length; i++) {
            if (members[i].walletAddress == memberAddress) {
                return members[i];
            }
        }
        revert InvalidAddress();
    }
}
