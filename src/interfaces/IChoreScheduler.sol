// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../Types.sol";

/// @title IChoreScheduler
/// @notice Interface for managing chore schedules and completions
interface IChoreScheduler {
    // Events
    event ChoreCreated(uint256 indexed communeId, uint256 indexed choreId, string title, address indexed assignedTo);
    event ChoreCompleted(uint256 indexed communeId, uint256 indexed choreId, uint256 period, uint256 timestamp);

    // Errors
    error Unauthorized();
    error NoSchedulesProvided();
    error InvalidFrequency();
    error EmptyTitle();
    error InvalidChoreId();
    error AlreadyCompleted();
    error InvalidStartTime();
    error InvalidAssignedMember();

    // Functions
    function addChores(uint256 communeId, ChoreSchedule[] memory schedules) external;

    function markChoreComplete(uint256 communeId, uint256 choreId) external;

    function getCurrentPeriod(uint256 communeId, uint256 choreId) external view returns (uint256);

    function isChoreComplete(uint256 communeId, uint256 choreId, uint256 period) external view returns (bool);

    function getChoreSchedules(uint256 communeId) external view returns (ChoreSchedule[] memory);

    function getCurrentChores(uint256 communeId)
        external
        view
        returns (ChoreSchedule[] memory schedules, uint256[] memory periods, bool[] memory completed);

    function getAssignedMemberIndex(uint256 communeId, uint256 choreId, uint256 period, uint256 memberCount)
        external
        pure
        returns (uint256);
}
