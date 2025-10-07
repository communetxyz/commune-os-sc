// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title CommuneOSModule
/// @notice Base contract for all CommuneOS modules with shared access control
abstract contract CommuneOSModule {
    address public immutable communeOS;

    error Unauthorized();

    constructor() {
        communeOS = msg.sender;
    }

    modifier onlyCommuneOS() {
        if (msg.sender != communeOS) revert Unauthorized();
        _;
    }
}
