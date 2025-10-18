// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/// @title CommuneOSModule
/// @notice Base contract for all CommuneOS modules with shared access control
/// @dev All module contracts inherit from this to ensure only CommuneOS can call them
abstract contract CommuneOSModule is Initializable {
    /// @custom:storage-location erc7201:commune.storage.CommuneOSModule
    struct CommuneOSModuleStorage {
        address communeOS;
    }

    // keccak256(abi.encode(uint256(keccak256("commune.storage.CommuneOSModule")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant CommuneOSModuleStorageLocation =
        0x8c8b8c8b8c8b8c8b8c8b8c8b8c8b8c8b8c8b8c8b8c8b8c8b8c8b8c8b8c8b8c00;

    function _getCommuneOSModuleStorage() private pure returns (CommuneOSModuleStorage storage $) {
        assembly {
            $.slot := CommuneOSModuleStorageLocation
        }
    }

    /// @notice Thrown when a non-CommuneOS address attempts a restricted operation
    error Unauthorized();

    /// @notice Returns the CommuneOS address
    function communeOS() public view returns (address) {
        CommuneOSModuleStorage storage $ = _getCommuneOSModuleStorage();
        return $.communeOS;
    }

    /// @notice Initializes the CommuneOS address
    /// @dev Must be called by the CommuneOS contract during deployment
    /// @param _communeOS Address of the main CommuneOS contract
    function __CommuneOSModule_init(address _communeOS) internal onlyInitializing {
        CommuneOSModuleStorage storage $ = _getCommuneOSModuleStorage();
        $.communeOS = _communeOS;
    }

    /// @notice Restricts function access to only the CommuneOS contract
    /// @dev Reverts with Unauthorized if called by any address other than communeOS
    modifier onlyCommuneOS() {
        CommuneOSModuleStorage storage $ = _getCommuneOSModuleStorage();
        if (msg.sender != $.communeOS) revert Unauthorized();
        _;
    }
}
