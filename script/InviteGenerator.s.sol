// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";

/// @title InviteGenerator
/// @notice Utility for generating invite signatures for CommuneOS
/// @dev This is a script/utility contract, not deployed on-chain
contract InviteGenerator is Script {
    /// @notice Directory where invite files will be saved
    string public constant INVITES_DIR = "./invites/";

    /// @notice Default frontend URL (gnosis config)
    string public constant DEFAULT_FRONTEND_URL = "https://www.share-house.fun";

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
            "Commune ID: ",
            vm.toString(communeId),
            "\n",
            "Nonce: ",
            vm.toString(nonce),
            "\n",
            "Signature: 0x",
            _bytesToHexString(signature),
            "\n",
            "\n",
            "To use this invite, call:\n",
            "communeOS.joinCommune(",
            vm.toString(communeId),
            ", ",
            vm.toString(nonce),
            ", 0x",
            _bytesToHexString(signature),
            ")\n"
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

    /// @notice Batch generates multiple invites and saves them to a single file as URLs
    /// @param privateKey The creator's private key
    /// @param communeId The commune ID to generate invites for
    /// @param nonces Array of unique nonces for the invites
    /// @return signatures Array of generated signature bytes
    function generateAndSaveInvites(uint256 privateKey, uint256 communeId, uint256[] memory nonces)
        public
        returns (bytes[] memory signatures)
    {
        // Try to read frontend URL from config, fallback to default
        string memory frontendUrl;
        try vm.readFile("./config/gnosis.json") returns (string memory configJson) {
            frontendUrl = _extractFrontendUrl(configJson);
            if (bytes(frontendUrl).length == 0) {
                frontendUrl = DEFAULT_FRONTEND_URL;
            }
        } catch {
            frontendUrl = DEFAULT_FRONTEND_URL;
        }

        signatures = new bytes[](nonces.length);
        string memory allInvites = "";

        for (uint256 i = 0; i < nonces.length; i++) {
            signatures[i] = generateInvite(privateKey, communeId, nonces[i]);

            // Build URL in format: https://www.share-house.fun/join?communeId=1&nonce=16&signature=0x...
            string memory inviteUrl = string.concat(
                frontendUrl,
                "/join?communeId=",
                vm.toString(communeId),
                "&nonce=",
                vm.toString(nonces[i]),
                "&signature=0x",
                _bytesToHexString(signatures[i]),
                "\n"
            );

            allInvites = string.concat(allInvites, inviteUrl);
        }

        // Write all invites to a single file
        string memory filename = string.concat(INVITES_DIR, "invites.txt");
        vm.writeFile(filename, allInvites);

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

    /// @notice Helper to extract frontendUrl from JSON config
    /// @param json The JSON string to parse
    /// @return url The extracted frontend URL, or empty string if not found
    function _extractFrontendUrl(string memory json) internal pure returns (string memory) {
        bytes memory jsonBytes = bytes(json);
        bytes memory searchKey = bytes('"frontendUrl":');

        // Find the frontendUrl key
        for (uint256 i = 0; i < jsonBytes.length - searchKey.length; i++) {
            bool found = true;
            for (uint256 j = 0; j < searchKey.length; j++) {
                if (jsonBytes[i + j] != searchKey[j]) {
                    found = false;
                    break;
                }
            }

            if (found) {
                // Skip whitespace and find the opening quote
                uint256 start = i + searchKey.length;
                while (
                    start < jsonBytes.length
                        && (jsonBytes[start] == " " || jsonBytes[start] == "\t" || jsonBytes[start] == "\n")
                ) {
                    start++;
                }

                if (start < jsonBytes.length && jsonBytes[start] == '"') {
                    start++; // Skip opening quote

                    // Find closing quote
                    uint256 end = start;
                    while (end < jsonBytes.length && jsonBytes[end] != '"') {
                        end++;
                    }

                    // Extract the URL
                    bytes memory urlBytes = new bytes(end - start);
                    for (uint256 k = 0; k < end - start; k++) {
                        urlBytes[k] = jsonBytes[start + k];
                    }

                    return string(urlBytes);
                }
            }
        }

        return "";
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
