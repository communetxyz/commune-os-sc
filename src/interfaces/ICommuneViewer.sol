// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Commune} from "./ICommuneRegistry.sol";
import {ChoreSchedule} from "./IChoreScheduler.sol";
import {Task} from "./ITaskManager.sol";
import {Dispute} from "./IVotingModule.sol";

/// @notice Individual chore instance for frontend
struct ChoreInstance {
    uint256 scheduleId;
    string title;
    uint256 frequency;
    uint256 periodNumber;
    uint256 periodStart;
    uint256 periodEnd;
    address assignedTo;
    string assignedToUsername;
    bool completed;
}

interface ICommuneViewer {
    function getCommuneStatistics(uint256 communeId)
        external
        view
        returns (Commune memory commune, uint256 memberCount, uint256 choreCount, uint256 taskCount);

    function getCurrentChores(uint256 communeId)
        external
        view
        returns (ChoreSchedule[] memory schedules, uint256[] memory periods, bool[] memory completed);

    function getCommuneMembers(uint256 communeId) external view returns (address[] memory);

    function getCommuneTasks(uint256 communeId) external view returns (Task[] memory);

    function getCollateralBalance(address member) external view returns (uint256);

    function getCommuneBasicInfo(address user)
        external
        view
        returns (
            uint256 communeId,
            Commune memory communeData,
            address[] memory members,
            uint256[] memory memberCollaterals,
            string[] memory memberUsernames
        );

    function getCommuneChores(address user, uint256 startDate, uint256 endDate)
        external
        view
        returns (uint256 communeId, ChoreInstance[] memory instances);

    function getCommuneTasks(address user, uint256 monthStart, uint256 monthEnd)
        external
        view
        returns (
            uint256 communeId,
            Task[] memory doneTasks,
            Task[] memory pendingTasks,
            Task[] memory disputedTasks,
            Task[] memory overdueTasks
        );

    function getCommuneDisputes(uint256 communeId) external view returns (Dispute[] memory disputes);

    function getDisputeVoters(uint256 disputeId, uint256 communeId) external view returns (address[] memory voters);

    function getUsernames(address[] memory addresses) external view returns (string[] memory usernames);
}
