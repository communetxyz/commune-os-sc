// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title IEvents
/// @notice Interface containing all events emitted by CommuneOS contracts
interface IEvents {
    // CommuneRegistry Events
    event CommuneCreated(
        uint256 indexed communeId,
        string name,
        address indexed creator,
        bool collateralRequired,
        uint256 collateralAmount
    );

    // MemberRegistry Events
    event MemberRegistered(address indexed member, uint256 indexed communeId, uint256 collateral, uint256 timestamp);

    // ChoreScheduler Events
    event ChoreScheduleInitialized(uint256 indexed communeId, uint256 indexed choreId, string title);
    event ChoreCompleted(uint256 indexed communeId, uint256 indexed choreId, uint256 period, uint256 timestamp);

    // ExpenseManager Events
    event ExpenseCreated(
        uint256 indexed expenseId,
        uint256 indexed communeId,
        address indexed assignedTo,
        uint256 amount,
        string description,
        uint256 dueDate
    );
    event ExpensePaid(uint256 indexed expenseId, address indexed paidBy);
    event ExpenseDisputed(uint256 indexed expenseId, uint256 indexed disputeId);
    event ExpenseReassigned(uint256 indexed expenseId, address indexed oldAssignee, address indexed newAssignee);

    // VotingModule Events
    event DisputeCreated(uint256 indexed disputeId, uint256 indexed expenseId, address proposedNewAssignee);
    event VoteCast(uint256 indexed disputeId, address indexed voter, bool support);
    event DisputeResolved(uint256 indexed disputeId, bool upheld);

    // CollateralManager Events
    event CollateralDeposited(address indexed member, uint256 amount);
    event CollateralSlashed(address indexed member, uint256 amount, address indexed recipient);

    // CommuneOS Events
    event MemberJoined(address indexed member, uint256 indexed communeId, uint256 collateral, uint256 timestamp);
}
