// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Commune} from "../Types.sol";

/// @title ICommuneRegistry
/// @notice Interface for commune creation and invite-based access control
interface ICommuneRegistry {
    // Events
    event CommuneCreated(
        uint256 indexed communeId,
        string name,
        address indexed creator,
        bool collateralRequired,
        uint256 collateralAmount
    );

    // Errors
    error EmptyName();
    error InvalidCreator();
    error InvalidCollateralAmount();
    error InvalidCommuneId();
    error NonceAlreadyUsed();

    // Functions
    function createCommune(string memory name, address creator, bool collateralRequired, uint256 collateralAmount)
        external
        returns (uint256 communeId);

    function validateInvite(uint256 communeId, uint256 nonce, bytes memory signature) external view returns (bool);

    function markNonceUsed(uint256 communeId, uint256 nonce) external;

    function getCommune(uint256 communeId) external view returns (Commune memory);

    function isNonceUsed(uint256 communeId, uint256 nonce) external view returns (bool);
}
