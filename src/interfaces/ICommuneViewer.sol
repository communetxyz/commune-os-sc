// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Commune} from "./ICommuneRegistry.sol";
import {ChoreSchedule} from "./IChoreScheduler.sol";
import {Expense} from "./IExpenseManager.sol";
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
    bool completed;
}

interface ICommuneViewer {
    function getCommuneStatistics(uint256 communeId)
        external
        view
        returns (Commune memory commune, uint256 memberCount, uint256 choreCount, uint256 expenseCount);

    function getCurrentChores(uint256 communeId)
        external
        view
        returns (ChoreSchedule[] memory schedules, uint256[] memory periods, bool[] memory completed);

    function getCommuneMembers(uint256 communeId) external view returns (address[] memory);

    function getCommuneExpenses(uint256 communeId) external view returns (Expense[] memory);

    function getCollateralBalance(address member) external view returns (uint256);

    function getCommuneBasicInfo(address user)
        external
        view
        returns (uint256 communeId, Commune memory communeData, address[] memory members, uint256[] memory memberCollaterals);

    function getCommuneChores(address user)
        external
        view
        returns (
            uint256 communeId,
            ChoreSchedule[] memory schedules,
            uint256[] memory currentPeriods,
            bool[] memory completionStatus
        );

    function getCommuneExpenses(address user, uint256 monthStart, uint256 monthEnd)
        external
        view
        returns (
            uint256 communeId,
            Expense[] memory paidExpenses,
            Expense[] memory pendingExpenses,
            Expense[] memory disputedExpenses,
            Expense[] memory overdueExpenses
        );

    function getCommuneDisputes(uint256 communeId) external view returns (Dispute[] memory disputes);

    function getDisputeVoters(uint256 disputeId, uint256 communeId) external view returns (address[] memory voters);
}
