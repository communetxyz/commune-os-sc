// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Task} from "./interfaces/ITaskManager.sol";
import "./interfaces/ITaskManager.sol";
import "./CommuneOSModule.sol";

/// @title TaskManager
/// @notice Manages task lifecycle including creation, assignment, completion, and disputes
/// @dev Tasks are globally unique and can be assigned, completed, disputed, and reassigned
contract TaskManager is CommuneOSModule, ITaskManager {
    /// @notice Stores task data by globally unique task ID
    /// @dev Maps task ID => Task struct containing all task information
    mapping(uint256 => Task) public tasks;

    /// @notice Links tasks to their associated disputes
    /// @dev Maps task ID => dispute ID (only set when task is disputed)
    mapping(uint256 => uint256) public taskDisputes;

    /// @notice Total number of tasks created (also serves as next task ID)
    uint256 public taskCount;

    /// @notice Create a new task with direct assignment
    /// @param communeId The commune ID
    /// @param budget The task budget (0 is valid)
    /// @param description Description of the task
    /// @param dueDate Due date for the task
    /// @param assignedTo The member assigned to the task
    /// @return taskId The ID of the created task
    function createTask(
        uint256 communeId,
        uint256 budget,
        string memory description,
        uint256 dueDate,
        address assignedTo
    ) external onlyCommuneOS returns (uint256 taskId) {
        if (assignedTo == address(0)) revert InvalidAssignee();
        if (bytes(description).length == 0) revert EmptyDescription();

        taskId = taskCount++;

        tasks[taskId] = Task({
            id: taskId,
            communeId: communeId,
            budget: budget,
            description: description,
            assignedTo: assignedTo,
            dueDate: dueDate,
            done: false,
            disputed: false
        });

        emit TaskCreated(taskId, communeId, assignedTo, budget, description, dueDate);
        return taskId;
    }

    /// @notice Mark a task as done
    /// @param taskId The task ID
    function markTaskDone(uint256 taskId) external onlyCommuneOS {
        if (taskId >= taskCount) revert InvalidTaskId();
        if (tasks[taskId].done) revert AlreadyDone();

        tasks[taskId].done = true;

        emit TaskDone(taskId, msg.sender);
    }

    /// @notice Mark a task as disputed
    /// @param taskId The task ID
    /// @param disputeId The dispute ID from VotingModule
    /// @dev Reverts if task has already been disputed (one dispute per task)
    function markTaskDisputed(uint256 taskId, uint256 disputeId) external onlyCommuneOS {
        if (taskId >= taskCount) revert InvalidTaskId();
        if (tasks[taskId].disputed) revert AlreadyDisputed();

        tasks[taskId].disputed = true;
        taskDisputes[taskId] = disputeId;

        emit TaskDisputed(taskId, disputeId);
    }

    /// @notice Check if a task is done
    /// @param taskId The task ID
    /// @return bool True if done
    function isTaskDone(uint256 taskId) external view returns (bool) {
        if (taskId >= taskCount) revert InvalidTaskId();
        return tasks[taskId].done;
    }

    /// @notice Get task status
    /// @param taskId The task ID
    /// @return Task The task data
    function getTaskStatus(uint256 taskId) external view returns (Task memory) {
        if (taskId >= taskCount) revert InvalidTaskId();
        return tasks[taskId];
    }

    /// @notice Get all tasks for a commune
    /// @param communeId The commune ID
    /// @return Task[] Array of tasks
    /// @dev Iterates through all tasks and filters by commune ID (O(n) complexity)
    function getCommuneTasks(uint256 communeId) external view returns (Task[] memory) {
        // First, count how many tasks belong to this commune
        uint256 count = 0;
        for (uint256 i = 0; i < taskCount; i++) {
            if (tasks[i].communeId == communeId) {
                count++;
            }
        }

        // Create result array and populate it
        Task[] memory result = new Task[](count);
        uint256 resultIndex = 0;
        for (uint256 i = 0; i < taskCount; i++) {
            if (tasks[i].communeId == communeId) {
                result[resultIndex] = tasks[i];
                resultIndex++;
            }
        }

        return result;
    }

    /// @notice Get current assignee for a task
    /// @param taskId The task ID
    /// @return address The assigned member
    function getTaskAssignee(uint256 taskId) external view returns (address) {
        if (taskId >= taskCount) revert InvalidTaskId();
        return tasks[taskId].assignedTo;
    }
}
