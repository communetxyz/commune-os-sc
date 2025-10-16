// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Represents a task within a commune
/// @dev Tasks can be assigned, completed, and disputed
struct Task {
    /// @notice Global unique identifier for the task
    uint256 id;
    /// @notice ID of the commune this task belongs to
    uint256 communeId;
    /// @notice Budget allocated for the task (in wei or token units), 0 is valid
    uint256 budget;
    /// @notice Description of what the task is for
    string description;
    /// @notice Address of the member assigned to the task
    address assignedTo;
    /// @notice Unix timestamp when completion is due
    uint256 dueDate;
    /// @notice Whether the task has been completed
    bool done;
    /// @notice Whether the task assignment is being disputed
    bool disputed;
}

/// @title ITaskManager
/// @notice Interface for managing task lifecycle including creation, assignment, payments, and disputes
interface ITaskManager {
    // Events
    event TaskCreated(
        uint256 indexed taskId,
        uint256 indexed communeId,
        address indexed assignedTo,
        uint256 budget,
        string description,
        uint256 dueDate
    );
    event TaskDone(uint256 indexed taskId, address indexed completedBy);
    event TaskDisputed(uint256 indexed taskId, uint256 indexed disputeId);

    // Errors
    error InvalidAssignee();
    error EmptyDescription();
    error InvalidTaskId();
    error AlreadyDone();
    error AlreadyDisputed();

    // Functions
    function createTask(
        uint256 communeId,
        uint256 budget,
        string memory description,
        uint256 dueDate,
        address assignedTo
    ) external returns (uint256 taskId);

    function markTaskDone(uint256 taskId) external;

    function markTaskDisputed(uint256 taskId, uint256 disputeId) external;

    function isTaskDone(uint256 taskId) external view returns (bool);

    function getTaskStatus(uint256 taskId) external view returns (Task memory);

    function getCommuneTasks(uint256 communeId) external view returns (Task[] memory);

    function getTaskAssignee(uint256 taskId) external view returns (address);
}
