// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Represents a commune - a group living arrangement with shared responsibilities
/// @dev Commune IDs start at 1 (0 is reserved as a sentinel value)
struct Commune {
    /// @notice Unique identifier for the commune
    uint256 id;
    /// @notice Human-readable name of the commune
    string name;
    /// @notice Address of the commune creator (can issue invites)
    address creator;
    /// @notice Whether members must deposit collateral to join
    bool collateralRequired;
    /// @notice Amount of collateral required (in wei or token units)
    uint256 collateralAmount;
}

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
