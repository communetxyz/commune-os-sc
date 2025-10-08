// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Commune} from "./Types.sol";
import "./interfaces/ICommuneRegistry.sol";
import "./CommuneOSModule.sol";

/// @title CommuneRegistry
/// @notice Creates and manages communes with invite-based access
/// @dev Uses EIP-191 signature verification for invite system
contract CommuneRegistry is CommuneOSModule, ICommuneRegistry {
    /// @notice Mapping of commune ID to commune data
    mapping(uint256 => Commune) public communes;

    /// @notice Tracks which nonces have been used for each commune to prevent replay attacks
    /// @dev communeId => nonce => used
    mapping(uint256 => mapping(uint256 => bool)) public usedNonces;

    /// @notice Counter for assigning unique commune IDs
    /// @dev Starts at 1 so 0 can be used as a sentinel value for "not a member"
    uint256 public communeCount = 1;

    /// @notice Creates a new commune with specified configuration
    /// @param name Human-readable name for the commune
    /// @param creator Address that will be able to issue invites
    /// @param collateralRequired Whether members must deposit collateral to join
    /// @param collateralAmount Amount of collateral required (ignored if collateralRequired is false)
    /// @return communeId Unique identifier for the newly created commune
    /// @dev Reverts if name is empty, creator is zero address, or collateralAmount is 0 when collateral is required
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

    /// @notice Validates an invite signature using EIP-191 standard
    /// @param communeId ID of the commune being joined
    /// @param nonce Unique nonce for this invite (prevents replay attacks)
    /// @param signature 65-byte ECDSA signature from the commune creator
    /// @return bool True if signature is valid and from the commune creator, false otherwise
    /// @dev Checks that: communeId exists, nonce hasn't been used, and signature is from creator
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

    /// @notice Marks a nonce as used to prevent replay attacks
    /// @param communeId ID of the commune
    /// @param nonce Nonce value to mark as used
    /// @dev Reverts if communeId is invalid or nonce already used
    function markNonceUsed(uint256 communeId, uint256 nonce) external onlyCommuneOS {
        if (communeId >= communeCount) revert InvalidCommuneId();
        if (usedNonces[communeId][nonce]) revert NonceAlreadyUsed();
        usedNonces[communeId][nonce] = true;
    }

    /// @notice Retrieves full commune data
    /// @param communeId ID of the commune to query
    /// @return Commune Complete commune struct with all fields
    /// @dev Reverts if communeId doesn't exist
    function getCommune(uint256 communeId) external view returns (Commune memory) {
        if (communeId >= communeCount) revert InvalidCommuneId();
        return communes[communeId];
    }

    /// @notice Checks whether a nonce has been used for a commune
    /// @param communeId ID of the commune
    /// @param nonce Nonce value to check
    /// @return bool True if nonce has been used, false otherwise
    function isNonceUsed(uint256 communeId, uint256 nonce) external view returns (bool) {
        return usedNonces[communeId][nonce];
    }

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
        require(sig.length == 65, "Invalid signature length");

        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }
    }
}
