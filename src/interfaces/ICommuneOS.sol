// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ChoreSchedule} from "./IChoreScheduler.sol";

interface ICommuneOS {
    // Errors
    error InsufficientCollateral();
    error NotAMember();

    // Functions
    function createCommune(
        string memory name,
        bool collateralRequired,
        uint256 collateralAmount,
        ChoreSchedule[] memory choreSchedules,
        string memory username
    ) external returns (uint256 communeId);

    function joinCommune(uint256 communeId, uint256 nonce, bytes memory signature, string memory username) external;

    function addChores(uint256 communeId, ChoreSchedule[] memory choreSchedules) external;

    function markChoreComplete(uint256 communeId, uint256 choreId, uint256 period) external;

    function createTask(
        uint256 communeId,
        uint256 budget,
        string memory description,
        uint256 dueDate,
        address assignedTo
    ) external returns (uint256 taskId);

    function markTaskDone(uint256 communeId, uint256 taskId) external;

    function disputeTask(uint256 communeId, uint256 taskId, address newAssignee) external returns (uint256 disputeId);

    function voteOnDispute(uint256 communeId, uint256 disputeId, bool support) external;

    function removeMember(uint256 communeId, address memberAddress) external;

    function setChoreAssignee(uint256 communeId, uint256 choreId, uint256 period, address assignee) external;
}
