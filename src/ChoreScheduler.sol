// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./Types.sol";

/// @title ChoreScheduler
/// @notice Manages chore schedules and completions without storing instances
/// @dev Uses period-based completion tracking for O(1) storage
contract ChoreScheduler {
    // CommuneId => array of ChoreSchedules
    mapping(uint256 => ChoreSchedule[]) public choreSchedules;

    // CommuneId => ChoreId => Period => completion status
    mapping(uint256 => mapping(uint256 => mapping(uint256 => bool))) public completions;

    event ChoreScheduleInitialized(uint256 indexed communeId, uint256 indexed choreId, string title);
    event ChoreCompleted(uint256 indexed communeId, uint256 indexed choreId, uint256 period, uint256 timestamp);

    /// @notice Initialize chore schedules for a commune
    /// @param communeId The commune ID
    /// @param schedules Array of chore schedules to initialize
    function initializeChores(uint256 communeId, ChoreSchedule[] memory schedules) external {
        require(schedules.length > 0, "ChoreScheduler: no schedules provided");
        require(choreSchedules[communeId].length == 0, "ChoreScheduler: already initialized");

        for (uint256 i = 0; i < schedules.length; i++) {
            require(schedules[i].frequency > 0, "ChoreScheduler: invalid frequency");
            require(bytes(schedules[i].title).length > 0, "ChoreScheduler: empty title");

            ChoreSchedule memory schedule = ChoreSchedule({
                id: i,
                title: schedules[i].title,
                frequency: schedules[i].frequency,
                startTime: schedules[i].startTime > 0 ? schedules[i].startTime : block.timestamp
            });

            choreSchedules[communeId].push(schedule);
            emit ChoreScheduleInitialized(communeId, i, schedule.title);
        }
    }

    /// @notice Mark a chore as complete for the current period
    /// @param communeId The commune ID
    /// @param choreId The chore ID
    function markChoreComplete(uint256 communeId, uint256 choreId) external {
        require(choreId < choreSchedules[communeId].length, "ChoreScheduler: invalid choreId");

        uint256 period = getCurrentPeriod(communeId, choreId);
        require(!completions[communeId][choreId][period], "ChoreScheduler: already completed");

        completions[communeId][choreId][period] = true;
        emit ChoreCompleted(communeId, choreId, period, block.timestamp);
    }

    /// @notice Calculate the current period for a chore
    /// @param communeId The commune ID
    /// @param choreId The chore ID
    /// @return uint256 The current period number
    function getCurrentPeriod(uint256 communeId, uint256 choreId) public view returns (uint256) {
        require(choreId < choreSchedules[communeId].length, "ChoreScheduler: invalid choreId");

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
    function isChoreComplete(uint256 communeId, uint256 choreId, uint256 period)
        external
        view
        returns (bool)
    {
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
        returns (
            ChoreSchedule[] memory schedules,
            uint256[] memory periods,
            bool[] memory completed
        )
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

    /// @notice Calculate which member is assigned to a chore in a given period
    /// @param communeId The commune ID
    /// @param choreId The chore ID
    /// @param period The period number
    /// @param memberCount Total number of members
    /// @return uint256 The index of the assigned member (rotation)
    function getAssignedMemberIndex(uint256 communeId, uint256 choreId, uint256 period, uint256 memberCount)
        external
        pure
        returns (uint256)
    {
        require(memberCount > 0, "ChoreScheduler: no members");
        // Simple rotation: period % memberCount
        return (choreId + period) % memberCount;
    }
}
