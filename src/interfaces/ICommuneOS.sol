// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Commune} from "./ICommuneRegistry.sol";
import {ChoreSchedule} from "./IChoreScheduler.sol";
import {Expense} from "./IExpenseManager.sol";

interface ICommuneOS {
    // Events
    event MemberJoined(address indexed member, uint256 indexed communeId, uint256 collateralAmount, uint256 timestamp);

    // Errors
    error InvalidInvite();
    error InsufficientCollateral();
    error NotAMember();
    error AssigneeNotAMember();
    error NewAssigneeNotAMember();

    // Functions
    function createCommune(
        string memory name,
        bool collateralRequired,
        uint256 collateralAmount,
        ChoreSchedule[] memory choreSchedules
    ) external returns (uint256 communeId);

    function joinCommune(uint256 communeId, uint256 nonce, bytes memory signature) external;

    function markChoreComplete(uint256 communeId, uint256 choreId) external;

    function createExpense(
        uint256 communeId,
        uint256 amount,
        string memory description,
        uint256 dueDate,
        address assignedTo
    ) external returns (uint256 expenseId);

    function markExpensePaid(uint256 communeId, uint256 expenseId) external;

    function disputeExpense(uint256 communeId, uint256 expenseId, address newAssignee)
        external
        returns (uint256 disputeId);

    function voteOnDispute(uint256 communeId, uint256 disputeId, bool support) external;

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
}
