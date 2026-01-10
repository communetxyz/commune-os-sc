// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ZuCitySystem} from "zucity-contracts/ZuCitySystem.sol";
import "./interfaces/IResidencyRegistry.sol";
import "./interfaces/ICommuneRegistry.sol";

/// @title ResidencyRegistry
/// @notice Derives commune membership from ZuCity room receipts
/// @dev Each Room-type item in ZuCity corresponds to a commune
contract ResidencyRegistry is IResidencyRegistry {
    /// @notice The ZuCity system contract to read from
    ZuCitySystem public immutable zuCity;

    /// @notice The CommuneRegistry to create/link communes
    ICommuneRegistry public immutable communeRegistry;

    /// @notice Maps ZuCity room itemId => communeId
    mapping(uint256 => uint256) public roomToCommune;

    /// @notice Maps communeId => ZuCity room itemId
    mapping(uint256 => uint256) public communeToRoom;

    /// @notice Tracks which rooms have been registered
    mapping(uint256 => bool) public isRoomRegistered;

    /// @notice Initializes the ResidencyRegistry
    /// @param _zuCity Address of the ZuCitySystem contract
    /// @param _communeRegistry Address of the CommuneRegistry contract
    constructor(address _zuCity, address _communeRegistry) {
        zuCity = ZuCitySystem(_zuCity);
        communeRegistry = ICommuneRegistry(_communeRegistry);
    }

    /// @notice Register a ZuCity room and create its corresponding commune
    /// @param roomId The ZuCity item ID (must be Room type)
    /// @param communeName Name for the commune
    /// @return communeId The created commune ID
    function registerRoom(uint256 roomId, string memory communeName) external returns (uint256 communeId) {
        // Verify it's a Room type
        (, ZuCitySystem.ItemType itemType,,,) = zuCity.items(roomId);
        if (itemType != ZuCitySystem.ItemType.Room) revert NotRoomType();
        if (isRoomRegistered[roomId]) revert RoomAlreadyRegistered();

        // Create commune for this room (no collateral required for residency-based communes)
        communeId = communeRegistry.createCommune(communeName, msg.sender, false, 0);

        // Link room ↔ commune
        roomToCommune[roomId] = communeId;
        communeToRoom[communeId] = roomId;
        isRoomRegistered[roomId] = true;

        emit RoomCommuneCreated(roomId, communeId, communeName);
    }

    /// @notice Link an existing commune to a ZuCity room
    /// @param roomId The ZuCity item ID (must be Room type)
    /// @param communeId Existing commune ID
    function linkRoomToCommune(uint256 roomId, uint256 communeId) external {
        // Verify it's a Room type
        (, ZuCitySystem.ItemType itemType,,,) = zuCity.items(roomId);
        if (itemType != ZuCitySystem.ItemType.Room) revert NotRoomType();
        if (isRoomRegistered[roomId]) revert RoomAlreadyRegistered();

        // Verify commune exists (will revert if not)
        communeRegistry.getCommune(communeId);

        // Link room ↔ commune
        roomToCommune[roomId] = communeId;
        communeToRoom[communeId] = roomId;
        isRoomRegistered[roomId] = true;

        emit RoomCommuneLinked(roomId, communeId);
    }

    /// @notice Check if address is a resident (has redeemed receipt for room)
    /// @param communeId The commune ID
    /// @param resident Address to check
    /// @return True if they have a Redeemed receipt for this room
    function isResident(uint256 communeId, address resident) external view returns (bool) {
        uint256 roomId = communeToRoom[communeId];
        if (roomId == 0) return false;

        // Scan receipts for this room with Redeemed status
        uint256 receiptCount = zuCity.receiptsCounter();
        for (uint256 i = 0; i < receiptCount; i++) {
            (
                uint256 listingId,
                ZuCitySystem.ReceiptStatus status,
                ,,,
                address recipient,
            ) = zuCity.receipts(i);

            if (
                listingId == roomId && status == ZuCitySystem.ReceiptStatus.Redeemed && recipient == resident
            ) {
                return true;
            }
        }
        return false;
    }

    /// @notice Get all current residents of a commune (room)
    /// @param communeId The commune ID
    /// @return residents Array of addresses with redeemed receipts
    function getResidents(uint256 communeId) external view returns (address[] memory residents) {
        uint256 roomId = communeToRoom[communeId];
        if (roomId == 0) return residents;

        uint256 receiptCount = zuCity.receiptsCounter();

        // First pass: count residents
        uint256 residentCount = 0;
        for (uint256 i = 0; i < receiptCount; i++) {
            (uint256 listingId, ZuCitySystem.ReceiptStatus status,,,,,) = zuCity.receipts(i);
            if (listingId == roomId && status == ZuCitySystem.ReceiptStatus.Redeemed) {
                residentCount++;
            }
        }

        // Second pass: collect addresses
        residents = new address[](residentCount);
        uint256 idx = 0;
        for (uint256 i = 0; i < receiptCount; i++) {
            (uint256 listingId, ZuCitySystem.ReceiptStatus status,,,,address recipient,) = zuCity.receipts(i);

            if (listingId == roomId && status == ZuCitySystem.ReceiptStatus.Redeemed) {
                residents[idx++] = recipient;
            }
        }
    }

    /// @notice Get resident count for a commune
    /// @param communeId The commune ID
    /// @return count Number of residents
    function getResidentCount(uint256 communeId) external view returns (uint256 count) {
        uint256 roomId = communeToRoom[communeId];
        if (roomId == 0) return 0;

        uint256 receiptCount = zuCity.receiptsCounter();
        for (uint256 i = 0; i < receiptCount; i++) {
            (uint256 listingId, ZuCitySystem.ReceiptStatus status,,,,,) = zuCity.receipts(i);
            if (listingId == roomId && status == ZuCitySystem.ReceiptStatus.Redeemed) {
                count++;
            }
        }
    }
}
