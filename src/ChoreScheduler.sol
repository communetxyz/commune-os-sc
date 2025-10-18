// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ChoreSchedule} from "./interfaces/IChoreScheduler.sol";
import "./interfaces/IChoreScheduler.sol";
import "./interfaces/IMemberRegistry.sol";
import "./CommuneOSModule.sol";

/// @title ChoreScheduler
/// @notice Manages chore schedules and completions without storing instances
/// @dev Uses period-based completion tracking for O(1) storage per completion
contract ChoreScheduler is CommuneOSModule, IChoreScheduler {
    /// @custom:storage-location erc7201:commune.storage.ChoreScheduler
    struct ChoreSchedulerStorage {
        mapping(uint256 => ChoreSchedule[]) choreSchedules;
        mapping(uint256 => mapping(uint256 => ChoreSchedule)) choreScheduleById;
        mapping(uint256 => uint256) nextChoreId;
        mapping(uint256 => mapping(uint256 => mapping(uint256 => bool))) completions;
        mapping(uint256 => mapping(uint256 => mapping(uint256 => address))) choreAssigneeOverrides;
    }

    // keccak256(abi.encode(uint256(keccak256("commune.storage.ChoreScheduler")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant ChoreSchedulerStorageLocation =
        0x4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a00;

    function _getChoreSchedulerStorage() private pure returns (ChoreSchedulerStorage storage $) {
        assembly {
            $.slot := ChoreSchedulerStorageLocation
        }
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Returns a chore schedule from the array
    function choreSchedules(uint256 communeId, uint256 index) public view returns (ChoreSchedule memory) {
        ChoreSchedulerStorage storage $ = _getChoreSchedulerStorage();
        return $.choreSchedules[communeId][index];
    }

    /// @notice Returns a chore schedule by ID
    function choreScheduleById(uint256 communeId, uint256 choreId) public view returns (ChoreSchedule memory) {
        ChoreSchedulerStorage storage $ = _getChoreSchedulerStorage();
        return $.choreScheduleById[communeId][choreId];
    }

    /// @notice Returns the next chore ID for a commune
    function nextChoreId(uint256 communeId) public view returns (uint256) {
        ChoreSchedulerStorage storage $ = _getChoreSchedulerStorage();
        return $.nextChoreId[communeId];
    }

    /// @notice Returns the completion status for a chore period
    function completions(uint256 communeId, uint256 choreId, uint256 period) public view returns (bool) {
        ChoreSchedulerStorage storage $ = _getChoreSchedulerStorage();
        return $.completions[communeId][choreId][period];
    }

    /// @notice Returns the assignee override for a chore period
    function choreAssigneeOverrides(uint256 communeId, uint256 choreId, uint256 period) public view returns (address) {
        ChoreSchedulerStorage storage $ = _getChoreSchedulerStorage();
        return $.choreAssigneeOverrides[communeId][choreId][period];
    }

    /// @notice Initializes the ChoreScheduler
    /// @param _communeOS Address of the main CommuneOS contract
    function initialize(address _communeOS) external initializer {
        __CommuneOSModule_init(_communeOS);
    }

    /// @notice Gets a chore schedule and validates it exists and is not deleted
    /// @param communeId The commune ID
    /// @param choreId The chore ID to get
    /// @return schedule The chore schedule
    /// @dev Reverts if chore doesn't exist or is deleted
    function _getValidChore(uint256 communeId, uint256 choreId) internal view returns (ChoreSchedule memory schedule) {
        ChoreSchedulerStorage storage $ = _getChoreSchedulerStorage();
        schedule = $.choreScheduleById[communeId][choreId];
        if (schedule.startTime == 0) revert InvalidChoreId();
        if (schedule.deleted) revert InvalidChoreId();
    }

    /// @notice Add chore schedules for a commune
    /// @param communeId The commune ID
    /// @param schedules Array of chore schedules to add
    /// @dev Assigns unique sequential IDs and stores in both array and mapping
    function addChores(uint256 communeId, ChoreSchedule[] memory schedules) external onlyCommuneOS {
        if (schedules.length == 0) revert NoSchedulesProvided();

        ChoreSchedulerStorage storage $ = _getChoreSchedulerStorage();

        for (uint256 i = 0; i < schedules.length; i++) {
            if (schedules[i].frequency == 0) revert InvalidFrequency();
            if (bytes(schedules[i].title).length == 0) revert EmptyTitle();
            if (schedules[i].startTime == 0) revert InvalidStartTime();

            uint256 choreId = $.nextChoreId[communeId]++;

            ChoreSchedule memory schedule = ChoreSchedule({
                id: choreId,
                title: schedules[i].title,
                frequency: schedules[i].frequency,
                startTime: schedules[i].startTime,
                deleted: false
            });

            // Store in array for iteration
            $.choreSchedules[communeId].push(schedule);
            // Store in mapping for stable ID lookups
            $.choreScheduleById[communeId][choreId] = schedule;

            emit ChoreCreated(communeId, choreId, schedule.title);
        }
    }

    /// @notice Remove a chore schedule from a commune
    /// @param communeId The commune ID
    /// @param choreId The chore ID to remove
    /// @dev Marks chore as deleted in mapping and removes from array using swap-and-pop
    /// @dev Chore ID remains stable in mapping, preserving completions and overrides
    function removeChore(uint256 communeId, uint256 choreId) external onlyCommuneOS {
        // Validate chore exists and is not already deleted
        _getValidChore(communeId, choreId);

        ChoreSchedulerStorage storage $ = _getChoreSchedulerStorage();

        // Mark as deleted in the mapping (preserves ID for historical lookups)
        $.choreScheduleById[communeId][choreId].deleted = true;

        // Find and remove from array
        ChoreSchedule[] storage schedules = $.choreSchedules[communeId];
        for (uint256 i = 0; i < schedules.length; i++) {
            if (schedules[i].id == choreId) {
                // Swap with last element and pop
                schedules[i] = schedules[schedules.length - 1];
                schedules.pop();
                break;
            }
        }

        emit ChoreRemoved(communeId, choreId);
    }

    /// @notice Mark a chore as complete for a specific period
    /// @param communeId The commune ID
    /// @param choreId The chore ID
    /// @param period The period number to mark complete
    /// @dev Marks the specified period as complete
    function markChoreComplete(uint256 communeId, uint256 choreId, uint256 period) external onlyCommuneOS {
        _getValidChore(communeId, choreId);

        ChoreSchedulerStorage storage $ = _getChoreSchedulerStorage();

        if ($.completions[communeId][choreId][period]) revert AlreadyCompleted();

        $.completions[communeId][choreId][period] = true;
        emit ChoreCompleted(communeId, choreId, period, block.timestamp);
    }

    /// @notice Calculate the current period for a chore
    /// @param communeId The commune ID
    /// @param choreId The chore ID
    /// @return uint256 The current period number
    /// @dev Returns 0 if current time is before startTime, otherwise calculates elapsed periods
    function getCurrentPeriod(uint256 communeId, uint256 choreId) public view returns (uint256) {
        ChoreSchedule memory schedule = _getValidChore(communeId, choreId);

        if (block.timestamp < schedule.startTime) {
            return 0;
        }

        return (block.timestamp - schedule.startTime) / schedule.frequency;
    }

    /// @notice Check if a chore is complete for a specific period
    /// @param communeId The commune ID
    /// @param choreId The chore ID
    /// @param period The period number
    /// @return bool True if completed
    function isChoreComplete(uint256 communeId, uint256 choreId, uint256 period) external view returns (bool) {
        ChoreSchedulerStorage storage $ = _getChoreSchedulerStorage();
        return $.completions[communeId][choreId][period];
    }

    /// @notice Get all chore schedules for a commune
    /// @param communeId The commune ID
    /// @return ChoreSchedule[] Array of active chore schedules
    function getChoreSchedules(uint256 communeId) external view returns (ChoreSchedule[] memory) {
        ChoreSchedulerStorage storage $ = _getChoreSchedulerStorage();
        return $.choreSchedules[communeId];
    }

    /// @notice Get current chores with their completion status
    /// @param communeId The commune ID
    /// @return schedules Array of active schedules
    /// @return periods Current period for each chore
    /// @return completed Completion status for current period
    function getCurrentChores(uint256 communeId)
        external
        view
        returns (ChoreSchedule[] memory schedules, uint256[] memory periods, bool[] memory completed)
    {
        ChoreSchedulerStorage storage $ = _getChoreSchedulerStorage();
        schedules = $.choreSchedules[communeId];
        uint256 count = schedules.length;

        periods = new uint256[](count);
        completed = new bool[](count);

        for (uint256 i = 0; i < count; i++) {
            uint256 choreId = schedules[i].id;
            periods[i] = getCurrentPeriod(communeId, choreId);
            completed[i] = $.completions[communeId][choreId][periods[i]];
        }

        return (schedules, periods, completed);
    }

    /// @notice Set an override assignee for a specific chore period
    /// @param communeId The commune ID
    /// @param choreId The chore ID
    /// @param period The period number
    /// @param assignee The member to assign (address(0) to use rotation)
    function setChoreAssignee(uint256 communeId, uint256 choreId, uint256 period, address assignee)
        external
        onlyCommuneOS
    {
        _getValidChore(communeId, choreId);
        ChoreSchedulerStorage storage $ = _getChoreSchedulerStorage();
        $.choreAssigneeOverrides[communeId][choreId][period] = assignee;
        emit ChoreAssigneeSet(communeId, choreId, assignee);
    }

    /// @notice Get the assigned member for a chore in a specific period
    /// @param communeId The commune ID
    /// @param choreId The chore ID
    /// @param period The period number
    /// @param members Array of commune members
    /// @param memberRegistry MemberRegistry instance for validating overrides
    /// @return address The assigned member for that period
    /// @dev Returns override assignee if set and still a member, otherwise uses rotation
    function getChoreAssigneeForPeriod(
        uint256 communeId,
        uint256 choreId,
        uint256 period,
        address[] memory members,
        IMemberRegistry memberRegistry
    ) external view returns (address) {
        _getValidChore(communeId, choreId);

        ChoreSchedulerStorage storage $ = _getChoreSchedulerStorage();

        // Check if there's an override for this period
        address override_ = $.choreAssigneeOverrides[communeId][choreId][period];
        if (override_ != address(0)) {
            // Verify override is still a valid member using O(1) lookup
            if (memberRegistry.isMember(communeId, override_)) {
                return override_;
            }
            // Override is no longer a member, fall through to rotation
        }

        // Use rotation based on period
        if (members.length == 0) revert NoMembers();
        uint256 memberIndex = (choreId + period) % members.length;
        return members[memberIndex];
    }

    /// @notice Calculate which member index is assigned to a chore in a given period
    /// @param choreId The chore ID
    /// @param period The period number
    /// @param memberCount Total number of members
    /// @return uint256 The index of the assigned member (rotation)
    /// @dev Uses formula: (choreId + period) % memberCount for deterministic rotation
    function getAssignedMemberIndex(uint256 choreId, uint256 period, uint256 memberCount)
        external
        pure
        returns (uint256)
    {
        if (memberCount == 0) revert NoMembers();
        // Simple rotation: period % memberCount
        return (choreId + period) % memberCount;
    }
}
