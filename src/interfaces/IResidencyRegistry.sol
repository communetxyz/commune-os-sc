// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title IResidencyRegistry
/// @notice Interface for deriving commune membership from ZuCity room receipts
/// @dev Each Room-type item in ZuCity corresponds to a commune
interface IResidencyRegistry {
    // Events
    event RoomCommuneCreated(uint256 indexed roomId, uint256 indexed communeId, string name);
    event RoomCommuneLinked(uint256 indexed roomId, uint256 indexed communeId);

    // Errors
    error NotRoomType();
    error RoomAlreadyRegistered();
    error InvalidRoom();

    /// @notice Check if address is a resident (has redeemed receipt for room)
    /// @param communeId The commune ID
    /// @param resident Address to check
    /// @return True if they have a Redeemed receipt for this room
    function isResident(uint256 communeId, address resident) external view returns (bool);

    /// @notice Get all current residents of a commune (room)
    /// @param communeId The commune ID
    /// @return residents Array of addresses with redeemed receipts
    function getResidents(uint256 communeId) external view returns (address[] memory residents);

    /// @notice Get resident count for a commune
    /// @param communeId The commune ID
    /// @return count Number of residents
    function getResidentCount(uint256 communeId) external view returns (uint256 count);

    /// @notice Get the commune ID for a ZuCity room
    /// @param roomId The ZuCity item ID
    /// @return communeId The corresponding commune ID
    function roomToCommune(uint256 roomId) external view returns (uint256 communeId);

    /// @notice Get the ZuCity room ID for a commune
    /// @param communeId The commune ID
    /// @return roomId The corresponding ZuCity item ID
    function communeToRoom(uint256 communeId) external view returns (uint256 roomId);

    /// @notice Register a ZuCity room and create its corresponding commune
    /// @param roomId The ZuCity item ID (must be Room type)
    /// @param communeName Name for the commune
    /// @return communeId The created commune ID
    function registerRoom(uint256 roomId, string memory communeName) external returns (uint256 communeId);

    /// @notice Link an existing commune to a ZuCity room
    /// @param roomId The ZuCity item ID (must be Room type)
    /// @param communeId Existing commune ID
    function linkRoomToCommune(uint256 roomId, uint256 communeId) external;

    /// @notice Check if a room has been registered
    /// @param roomId The ZuCity item ID
    /// @return True if the room is registered
    function isRoomRegistered(uint256 roomId) external view returns (bool);
}
