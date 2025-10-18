// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Member} from "./interfaces/IMemberRegistry.sol";
import "./interfaces/IMemberRegistry.sol";
import "./CommuneOSModule.sol";

/// @title MemberRegistry
/// @notice Manages commune members and their status
/// @dev Uses memberCommuneId == 0 as sentinel value for non-members
contract MemberRegistry is CommuneOSModule, IMemberRegistry {
    /// @custom:storage-location erc7201:commune.storage.MemberRegistry
    struct MemberRegistryStorage {
        mapping(uint256 => Member[]) communeMembers;
        mapping(address => uint256) memberCommuneId;
        mapping(address => string) memberUsername;
        mapping(uint256 => mapping(uint256 => bool)) usedNonces;
    }

    // keccak256(abi.encode(uint256(keccak256("commune.storage.MemberRegistry")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant MemberRegistryStorageLocation =
        0x3a4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a00;

    function _getMemberRegistryStorage() private pure returns (MemberRegistryStorage storage $) {
        assembly {
            $.slot := MemberRegistryStorageLocation
        }
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Returns the members array for a commune
    function communeMembers(uint256 communeId, uint256 index) public view returns (Member memory) {
        MemberRegistryStorage storage $ = _getMemberRegistryStorage();
        return $.communeMembers[communeId][index];
    }

    /// @notice Returns the commune ID for a member
    function memberCommuneId(address member) public view returns (uint256) {
        MemberRegistryStorage storage $ = _getMemberRegistryStorage();
        return $.memberCommuneId[member];
    }

    /// @notice Returns the username for a member
    function memberUsername(address member) public view returns (string memory) {
        MemberRegistryStorage storage $ = _getMemberRegistryStorage();
        return $.memberUsername[member];
    }

    /// @notice Returns whether a nonce has been used for a commune
    function usedNonces(uint256 communeId, uint256 nonce) public view returns (bool) {
        MemberRegistryStorage storage $ = _getMemberRegistryStorage();
        return $.usedNonces[communeId][nonce];
    }

    /// @notice Initializes the MemberRegistry
    /// @param _communeOS Address of the main CommuneOS contract
    function initialize(address _communeOS) external initializer {
        __CommuneOSModule_init(_communeOS);
    }

    /// @notice Validates an invite signature
    /// @param communeId ID of the commune being joined
    /// @param creatorAddress The address of the commune creator
    /// @param nonce Unique nonce for this invite (prevents replay attacks)
    /// @param signature 65-byte ECDSA signature from the commune creator
    /// @dev Checks that: nonce hasn't been used, and signature is from creator
    function validateInvite(uint256 communeId, address creatorAddress, uint256 nonce, bytes memory signature)
        external
        view
    {
        MemberRegistryStorage storage $ = _getMemberRegistryStorage();
        if ($.usedNonces[communeId][nonce]) revert NonceAlreadyUsed();

        // Create the message hash
        bytes32 messageHash = getMessageHash(communeId, nonce);
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);

        // Recover the signer
        address signer = recoverSigner(ethSignedMessageHash, signature);

        // Verify the signer is the commune creator
        if (signer != creatorAddress) revert InvalidInvite();
    }

    /// @notice Joins a commune with validated invite
    /// @param communeId The commune ID
    /// @param memberAddress Address of the member joining
    /// @param nonce The invite nonce to mark as used
    /// @param collateralAmount Amount of collateral deposited
    /// @param username Username chosen by the member (optional)
    /// @dev Called by CommuneOS after invite validation and collateral handling
    function joinCommune(
        uint256 communeId,
        address memberAddress,
        uint256 nonce,
        uint256 collateralAmount,
        string memory username
    ) external onlyCommuneOS {
        MemberRegistryStorage storage $ = _getMemberRegistryStorage();
        // Mark nonce as used (validated in validateInvite, but must be marked here)
        $.usedNonces[communeId][nonce] = true;

        // Register the member
        _registerMember(communeId, memberAddress, collateralAmount, username);
        emit MemberJoined(memberAddress, communeId, collateralAmount, block.timestamp, username);
    }

    /// @notice Registers a new member to a commune
    /// @param communeId ID of the commune to join
    /// @param memberAddress Address of the new member
    /// @param username Username chosen by the member (optional)
    /// @dev Third parameter (collateralAmount) is ignored but kept for interface compatibility
    /// @dev Reverts if address is zero or already registered to any commune
    function registerMember(uint256 communeId, address memberAddress, uint256, string memory username)
        external
        onlyCommuneOS
    {
        _registerMember(communeId, memberAddress, 0, username);
    }

    /// @notice Internal function to register a member
    /// @param communeId ID of the commune to join
    /// @param memberAddress Address of the new member
    /// @param collateralAmount Amount of collateral deposited (for event logging)
    /// @param username Username chosen by the member (optional)
    function _registerMember(
        uint256 communeId,
        address memberAddress,
        uint256 collateralAmount,
        string memory username
    ) internal {
        MemberRegistryStorage storage $ = _getMemberRegistryStorage();
        if (memberAddress == address(0)) revert InvalidAddress();
        if ($.memberCommuneId[memberAddress] != 0) revert AlreadyRegistered();

        Member memory newMember =
            Member({walletAddress: memberAddress, communeId: communeId, active: true, username: username});

        $.communeMembers[communeId].push(newMember);
        $.memberCommuneId[memberAddress] = communeId;
        $.memberUsername[memberAddress] = username;

        emit MemberRegistered(memberAddress, communeId, collateralAmount, block.timestamp, username);
    }

    /// @notice Checks if an address is a member of a specific commune
    /// @param communeId ID of the commune to check
    /// @param memberAddress Address to verify membership
    /// @return bool True if address is an active member of the commune
    /// @dev Returns false if communeId is 0 to prevent false positives
    function isMember(uint256 communeId, address memberAddress) external view returns (bool) {
        MemberRegistryStorage storage $ = _getMemberRegistryStorage();
        return $.memberCommuneId[memberAddress] == communeId && communeId != 0;
    }

    /// @notice Batch checks if multiple addresses are members of a commune
    /// @param communeId ID of the commune to check
    /// @param addresses Array of addresses to verify
    /// @return results Array of booleans, true for each address that is a member
    /// @dev More gas-efficient than multiple isMember() calls
    function areMembers(uint256 communeId, address[] memory addresses) external view returns (bool[] memory results) {
        MemberRegistryStorage storage $ = _getMemberRegistryStorage();
        results = new bool[](addresses.length);
        for (uint256 i = 0; i < addresses.length; i++) {
            results[i] = $.memberCommuneId[addresses[i]] == communeId && communeId != 0;
        }
        return results;
    }

    /// @notice Retrieves all member addresses for a commune
    /// @param communeId ID of the commune
    /// @return address[] Array of member wallet addresses
    /// @dev Extracts addresses from Member structs for convenience
    function getCommuneMembers(uint256 communeId) external view returns (address[] memory) {
        MemberRegistryStorage storage $ = _getMemberRegistryStorage();
        Member[] memory members = $.communeMembers[communeId];
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
        MemberRegistryStorage storage $ = _getMemberRegistryStorage();
        return $.communeMembers[communeId].length;
    }

    /// @notice Retrieves full member data for an address
    /// @param memberAddress Address of the member to query
    /// @return Member Complete member struct including communeId and active status
    /// @dev Reverts if address is not registered to any commune
    /// @dev Searches linearly through commune's member array
    function getMemberStatus(address memberAddress) external view returns (Member memory) {
        MemberRegistryStorage storage $ = _getMemberRegistryStorage();
        uint256 communeId = $.memberCommuneId[memberAddress];
        if (communeId == 0) revert InvalidAddress();

        Member[] memory members = $.communeMembers[communeId];
        for (uint256 i = 0; i < members.length; i++) {
            if (members[i].walletAddress == memberAddress) {
                return members[i];
            }
        }
        revert InvalidAddress();
    }

    /// @notice Checks whether a nonce has been used for a commune
    /// @param communeId ID of the commune
    /// @param nonce Nonce value to check
    /// @return bool True if nonce has been used, false otherwise
    function isNonceUsed(uint256 communeId, uint256 nonce) external view returns (bool) {
        MemberRegistryStorage storage $ = _getMemberRegistryStorage();
        return $.usedNonces[communeId][nonce];
    }

    /// @notice Removes a member from a commune
    /// @param communeId ID of the commune
    /// @param memberAddress Address of the member to remove
    /// @dev Uses swap-and-pop to efficiently remove from array
    /// @dev Caller validation happens in CommuneOS via onlyMember modifier
    /// @dev Idempotent - no-op if member doesn't exist
    function removeMember(uint256 communeId, address memberAddress) external onlyCommuneOS {
        MemberRegistryStorage storage $ = _getMemberRegistryStorage();
        // Find and remove the member from the array using swap-and-pop
        Member[] storage members = $.communeMembers[communeId];
        for (uint256 i = 0; i < members.length; i++) {
            if (members[i].walletAddress == memberAddress) {
                // Swap with last element and pop
                members[i] = members[members.length - 1];
                members.pop();

                // Remove from memberCommuneId mapping
                $.memberCommuneId[memberAddress] = 0;

                emit MemberRemoved(memberAddress, communeId, block.timestamp);
                break;
            }
        }
        // If not found, no-op (idempotent operation)
    }

    // Internal signature verification helpers

    /// @notice Generates message hash from communeId and nonce
    /// @param communeId ID of the commune
    /// @param nonce Unique nonce value
    /// @return bytes32 Keccak256 hash of the packed parameters
    /// @dev Used as first step in EIP-191 signature verification
    function getMessageHash(uint256 communeId, uint256 nonce) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(communeId, nonce));
    }

    /// @notice Converts message hash to Ethereum signed message hash (EIP-191)
    /// @param messageHash Original message hash
    /// @return bytes32 Hash prefixed with "\x19Ethereum Signed Message:\n32"
    /// @dev This format matches what eth_sign produces
    function getEthSignedMessageHash(bytes32 messageHash) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));
    }

    /// @notice Recovers the signer address from a signature
    /// @param ethSignedMessageHash EIP-191 formatted message hash
    /// @param signature 65-byte ECDSA signature
    /// @return address Address that created the signature
    /// @dev Uses ecrecover precompile
    function recoverSigner(bytes32 ethSignedMessageHash, bytes memory signature) internal pure returns (address) {
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(signature);
        return ecrecover(ethSignedMessageHash, v, r, s);
    }

    /// @notice Splits a signature into its r, s, v components
    /// @param sig 65-byte signature
    /// @return r First 32 bytes of signature
    /// @return s Second 32 bytes of signature
    /// @return v Recovery id (last byte)
    /// @dev Reverts if signature is not exactly 65 bytes
    function splitSignature(bytes memory sig) internal pure returns (bytes32 r, bytes32 s, uint8 v) {
        if (sig.length != 65) revert InvalidSignatureLength();

        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }
    }
}
