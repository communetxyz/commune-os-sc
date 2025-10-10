// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";

/// @title InviteGenerator
/// @notice Utility for generating invite signatures for CommuneOS
/// @dev This is a script/utility contract, not deployed on-chain
contract InviteGenerator is Script {
    /// @notice Generates an invite signature for a commune
    /// @param privateKey The creator's private key
    /// @param communeId The commune ID to generate invite for
    /// @param nonce Unique nonce for this invite
    /// @return signature The generated signature bytes
    /// @dev Uses EIP-191 signing format to match CommuneRegistry validation
    function generateInvite(uint256 privateKey, uint256 communeId, uint256 nonce)
        public
        pure
        returns (bytes memory signature)
    {
        // Create the message hash (same as CommuneRegistry.getMessageHash)
        bytes32 messageHash = keccak256(abi.encodePacked(communeId, nonce));

        // Convert to Ethereum signed message hash (EIP-191)
        bytes32 ethSignedMessageHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash)
        );

        // Sign the message
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, ethSignedMessageHash);

        // Combine into signature bytes
        signature = abi.encodePacked(r, s, v);

        return signature;
    }

    /// @notice Batch generates multiple invite signatures
    /// @param privateKey The creator's private key
    /// @param communeId The commune ID to generate invites for
    /// @param nonces Array of unique nonces for the invites
    /// @return signatures Array of generated signature bytes
    function generateInvites(uint256 privateKey, uint256 communeId, uint256[] memory nonces)
        public
        pure
        returns (bytes[] memory signatures)
    {
        signatures = new bytes[](nonces.length);
        for (uint256 i = 0; i < nonces.length; i++) {
            signatures[i] = generateInvite(privateKey, communeId, nonces[i]);
        }
        return signatures;
    }

    /// @notice Helper to derive address from private key
    /// @param privateKey The private key
    /// @return addr The corresponding address
    function getAddressFromPrivateKey(uint256 privateKey) public pure returns (address addr) {
        return vm.addr(privateKey);
    }
}
