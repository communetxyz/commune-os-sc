// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ChoreSchedule} from "./interfaces/IChoreScheduler.sol";
import "./interfaces/IChoreScheduler.sol";
import "./CommuneOSModule.sol";

/// @title ChoreScheduler
/// @notice Manages chore schedules and completions without storing instances
/// @dev Uses period-based completion tracking for O(1) storage per completion
contract ChoreScheduler is CommuneOSModule, IChoreScheduler {
    /// @notice Stores all chore schedules for each commune
    /// @dev Maps commune ID => array of ChoreSchedule structs
    mapping(uint256 => ChoreSchedule[]) public choreSchedules;

    /// @notice Tracks completion status for each chore period
    /// @dev Maps commune ID => chore ID => period number => completion status (true/false)
    mapping(uint256 => mapping(uint256 => mapping(uint256 => bool))) public completions;

    /// @notice Stores manual assignee overrides for specific chores per period
    /// @dev Maps commune ID => chore ID => period number => assignee address (address(0) means use rotation)
    mapping(uint256 => mapping(uint256 => mapping(uint256 => address))) public choreAssigneeOverrides;

    /// @notice Add chore schedules for a commune
    /// @param communeId The commune ID
    /// @param schedules Array of chore schedules to add
    /// @dev Assigns sequential IDs to new chores starting from current count
    function addChores(uint256 communeId, ChoreSchedule[] memory schedules) external onlyCommuneOS {
        if (schedules.length == 0) revert NoSchedulesProvided();

        uint256 currentChoreCount = choreSchedules[communeId].length;

        for (uint256 i = 0; i < schedules.length; i++) {
            if (schedules[i].frequency == 0) revert InvalidFrequency();
            if (bytes(schedules[i].title).length == 0) revert EmptyTitle();
            if (schedules[i].startTime == 0) revert InvalidStartTime();

            uint256 choreId = currentChoreCount + i;

            ChoreSchedule memory schedule = ChoreSchedule({
                id: choreId,
                title: schedules[i].title,
                frequency: schedules[i].frequency,
                startTime: schedules[i].startTime
            });

            choreSchedules[communeId].push(schedule);
            emit ChoreCreated(communeId, choreId, schedule.title);
        }
    }

    /// @notice Remove a chore schedule from a commune
    /// @param communeId The commune ID
    /// @param choreId The chore ID to remove
    /// @dev Removes the chore by replacing it with the last element and popping the array
    /// @dev After removal, the last chore's ID changes to the removed chore's position
    function removeChore(uint256 communeId, uint256 choreId) external onlyCommuneOS {
        if (choreId >= choreSchedules[communeId].length) revert InvalidChoreId();

        uint256 lastIndex = choreSchedules[communeId].length - 1;

        // If not removing the last element, swap with last element
        if (choreId != lastIndex) {
            choreSchedules[communeId][choreId] = choreSchedules[communeId][lastIndex];
            // Update the ID of the moved chore to reflect its new position
            choreSchedules[communeId][choreId].id = choreId;
        }

        // Remove the last element
        choreSchedules[communeId].pop();

        emit ChoreRemoved(communeId, choreId);
    }

    /// @notice Mark a chore as complete for the current period
    /// @param communeId The commune ID
    /// @param choreId The chore ID
    /// @dev Automatically calculates the current period and marks it complete
    function markChoreComplete(uint256 communeId, uint256 choreId) external onlyCommuneOS {
        if (choreId >= choreSchedules[communeId].length) revert InvalidChoreId();

        uint256 period = getCurrentPeriod(communeId, choreId);
        if (completions[communeId][choreId][period]) revert AlreadyCompleted();

        completions[communeId][choreId][period] = true;
        emit ChoreCompleted(communeId, choreId, period, block.timestamp);
    }

    /// @notice Calculate the current period for a chore
    /// @param communeId The commune ID
    /// @param choreId The chore ID
    /// @return uint256 The current period number
    /// @dev Returns 0 if current time is before startTime, otherwise calculates elapsed periods
    function getCurrentPeriod(uint256 communeId, uint256 choreId) public view returns (uint256) {
        if (choreId >= choreSchedules[communeId].length) revert InvalidChoreId();

        ChoreSchedule memory schedule = choreSchedules[communeId][choreId];
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
        return completions[communeId][choreId][period];
    }

    /// @notice Get all chore schedules for a commune
    /// @param communeId The commune ID
    /// @return ChoreSchedule[] Array of chore schedules
    function getChoreSchedules(uint256 communeId) external view returns (ChoreSchedule[] memory) {
        return choreSchedules[communeId];
    }

    /// @notice Get current chores with their completion status
    /// @param communeId The commune ID
    /// @return schedules Array of schedules
    /// @return periods Current period for each chore
    /// @return completed Completion status for current period
    function getCurrentChores(uint256 communeId)
        external
        view
        returns (ChoreSchedule[] memory schedules, uint256[] memory periods, bool[] memory completed)
    {
        schedules = choreSchedules[communeId];
        uint256 count = schedules.length;

        periods = new uint256[](count);
        completed = new bool[](count);

        for (uint256 i = 0; i < count; i++) {
            periods[i] = getCurrentPeriod(communeId, i);
            completed[i] = completions[communeId][i][periods[i]];
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
        if (choreId >= choreSchedules[communeId].length) revert InvalidChoreId();
        choreAssigneeOverrides[communeId][choreId][period] = assignee;
        emit ChoreAssigneeSet(communeId, choreId, assignee);
    }

    /// @notice Get the assigned member for a chore in the current period
    /// @param communeId The commune ID
    /// @param choreId The chore ID
    /// @param members Array of commune members
    /// @return address The assigned member
    /// @dev Returns override assignee if set for current period, otherwise uses rotation based on (choreId + period) % memberCount
    function getChoreAssignee(uint256 communeId, uint256 choreId, address[] memory members)
        external
        view
        returns (address)
    {
        if (choreId >= choreSchedules[communeId].length) revert InvalidChoreId();

        // Get current period
        uint256 period = getCurrentPeriod(communeId, choreId);

        // Check if there's an override for this period
        address override_ = choreAssigneeOverrides[communeId][choreId][period];
        if (override_ != address(0)) {
            return override_;
        }

        // Use rotation based on current period
        if (members.length == 0) revert NoMembers();
        uint256 memberIndex = (choreId + period) % members.length;
        return members[memberIndex];
    }

    /// @notice Get the assigned member for a chore in a specific period
    /// @param communeId The commune ID
    /// @param choreId The chore ID
    /// @param period The period number
    /// @param members Array of commune members
    /// @return address The assigned member for that period
    /// @dev Returns override assignee if set for the period, otherwise uses rotation
    function getChoreAssigneeForPeriod(uint256 communeId, uint256 choreId, uint256 period, address[] memory members)
        external
        view
        returns (address)
    {
        if (choreId >= choreSchedules[communeId].length) revert InvalidChoreId();

        // Check if there's an override for this period
        address override_ = choreAssigneeOverrides[communeId][choreId][period];
        if (override_ != address(0)) {
            return override_;
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
