// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";

/// @title InviteGenerator
/// @notice Utility for generating invite signatures for CommuneOS
/// @dev This is a script/utility contract, not deployed on-chain
contract InviteGenerator is Script {
    /// @notice Directory where invite files will be saved
    string public constant INVITES_DIR = "./invites/";

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
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));

        // Sign the message
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, ethSignedMessageHash);

        // Combine into signature bytes
        signature = abi.encodePacked(r, s, v);

        return signature;
    }

    /// @notice Generates an invite and writes it to a file
    /// @param privateKey The creator's private key
    /// @param communeId The commune ID to generate invite for
    /// @param nonce Unique nonce for this invite
    /// @return signature The generated signature bytes
    function generateAndSaveInvite(uint256 privateKey, uint256 communeId, uint256 nonce)
        public
        returns (bytes memory signature)
    {
        signature = generateInvite(privateKey, communeId, nonce);

        // Create file content with invite details
        string memory content = string.concat(
            "Commune ID: ", vm.toString(communeId), "\n",
            "Nonce: ", vm.toString(nonce), "\n",
            "Signature: 0x", _bytesToHexString(signature), "\n",
            "\n",
            "To use this invite, call:\n",
            "communeOS.joinCommune(", vm.toString(communeId), ", ", vm.toString(nonce), ", 0x", _bytesToHexString(signature), ")\n"
        );

        // Write to file named <nonce>.txt
        string memory filename = string.concat(INVITES_DIR, vm.toString(nonce), ".txt");
        vm.writeFile(filename, content);

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

    /// @notice Batch generates multiple invites and saves them to files
    /// @param privateKey The creator's private key
    /// @param communeId The commune ID to generate invites for
    /// @param nonces Array of unique nonces for the invites
    /// @return signatures Array of generated signature bytes
    function generateAndSaveInvites(uint256 privateKey, uint256 communeId, uint256[] memory nonces)
        public
        returns (bytes[] memory signatures)
    {
        signatures = new bytes[](nonces.length);
        for (uint256 i = 0; i < nonces.length; i++) {
            signatures[i] = generateAndSaveInvite(privateKey, communeId, nonces[i]);
        }
        return signatures;
    }

    /// @notice Helper to derive address from private key
    /// @param privateKey The private key
    /// @return addr The corresponding address
    function getAddressFromPrivateKey(uint256 privateKey) public pure returns (address addr) {
        return vm.addr(privateKey);
    }

    /// @notice Helper to convert bytes to hex string
    /// @param data The bytes to convert
    /// @return result The hex string representation
    function _bytesToHexString(bytes memory data) internal pure returns (string memory) {
        bytes memory hexChars = "0123456789abcdef";
        bytes memory result = new bytes(data.length * 2);

        for (uint256 i = 0; i < data.length; i++) {
            result[i * 2] = hexChars[uint8(data[i] >> 4)];
            result[i * 2 + 1] = hexChars[uint8(data[i] & 0x0f)];
        }

        return string(result);
    }

    /// @notice Example script to run locally - generates invites for a commune
    /// @dev Run with: forge script script/InviteGenerator.s.sol:InviteGenerator -s "run(uint256,uint256,uint256)" <privateKey> <communeId> <startNonce>
    function run(uint256 privateKey, uint256 communeId, uint256 startNonce) public {
        // Generate 5 invites starting from startNonce
        uint256[] memory nonces = new uint256[](5);
        for (uint256 i = 0; i < 5; i++) {
            nonces[i] = startNonce + i;
        }

        generateAndSaveInvites(privateKey, communeId, nonces);

        console.log("Generated 5 invites for commune", communeId);
        console.log("Nonces:", startNonce, "to", startNonce + 4);
        console.log("Saved to:", INVITES_DIR);
    }
}
