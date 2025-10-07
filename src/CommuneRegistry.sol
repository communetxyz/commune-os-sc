// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Commune} from "./Types.sol";
import "./interfaces/ICommuneRegistry.sol";
import "./CommuneOSModule.sol";

/// @title CommuneRegistry
/// @notice Creates and manages communes with invite-based access
contract CommuneRegistry is CommuneOSModule, ICommuneRegistry {
    // CommuneId => Commune data
    mapping(uint256 => Commune) public communes;

    // CommuneId => nonce => used status
    mapping(uint256 => mapping(uint256 => bool)) public usedNonces;

    uint256 public communeCount;

    /// @notice Create a new commune
    /// @param name The commune name
    /// @param creator The creator address
    /// @param collateralRequired Whether collateral is required
    /// @param collateralAmount The required collateral amount
    /// @return communeId The ID of the created commune
    function createCommune(string memory name, address creator, bool collateralRequired, uint256 collateralAmount)
        external
        onlyCommuneOS
        returns (uint256 communeId)
    {
        if (bytes(name).length == 0) revert EmptyName();
        if (creator == address(0)) revert InvalidCreator();
        if (collateralRequired && collateralAmount == 0) revert InvalidCollateralAmount();

        communeId = communeCount++;

        communes[communeId] = Commune({
            id: communeId,
            name: name,
            creator: creator,
            collateralRequired: collateralRequired,
            collateralAmount: collateralAmount
        });

        emit CommuneCreated(communeId, name, creator, collateralRequired, collateralAmount);
        return communeId;
    }

    /// @notice Validate an invite signature and nonce
    /// @param communeId The commune ID
    /// @param nonce The nonce for this invite
    /// @param signature The signature from the creator
    /// @return bool True if valid
    function validateInvite(uint256 communeId, uint256 nonce, bytes memory signature) external view returns (bool) {
        if (communeId >= communeCount) revert InvalidCommuneId();
        if (usedNonces[communeId][nonce]) revert NonceAlreadyUsed();

        // Create the message hash
        bytes32 messageHash = getMessageHash(communeId, nonce);
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);

        // Recover the signer
        address signer = recoverSigner(ethSignedMessageHash, signature);

        // Verify the signer is the commune creator
        return signer == communes[communeId].creator;
    }

    /// @notice Mark a nonce as used
    /// @param communeId The commune ID
    /// @param nonce The nonce to mark as used
    function markNonceUsed(uint256 communeId, uint256 nonce) external onlyCommuneOS {
        if (communeId >= communeCount) revert InvalidCommuneId();
        if (usedNonces[communeId][nonce]) revert NonceAlreadyUsed();
        usedNonces[communeId][nonce] = true;
    }

    /// @notice Get commune details
    /// @param communeId The commune ID
    /// @return Commune The commune data
    function getCommune(uint256 communeId) external view returns (Commune memory) {
        if (communeId >= communeCount) revert InvalidCommuneId();
        return communes[communeId];
    }

    /// @notice Check if a nonce has been used
    /// @param communeId The commune ID
    /// @param nonce The nonce to check
    /// @return bool True if used
    function isNonceUsed(uint256 communeId, uint256 nonce) external view returns (bool) {
        return usedNonces[communeId][nonce];
    }

    // Internal helper functions for signature verification

    function getMessageHash(uint256 communeId, uint256 nonce) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(communeId, nonce));
    }

    function getEthSignedMessageHash(bytes32 messageHash) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));
    }

    function recoverSigner(bytes32 ethSignedMessageHash, bytes memory signature) internal pure returns (address) {
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(signature);
        return ecrecover(ethSignedMessageHash, v, r, s);
    }

    function splitSignature(bytes memory sig) internal pure returns (bytes32 r, bytes32 s, uint8 v) {
        require(sig.length == 65, "Invalid signature length");

        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }
    }
}
