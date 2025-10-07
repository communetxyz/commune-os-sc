// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Expense} from "../Types.sol";

/// @title IExpenseManager
/// @notice Interface for managing expense lifecycle including creation, assignment, payments, and disputes
interface IExpenseManager {
    // Events
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

    // Errors
    error InvalidAssignee();
    error InvalidAmount();
    error EmptyDescription();
    error InvalidExpenseId();
    error AlreadyPaid();

    // Functions
    function createExpense(
        uint256 communeId,
        uint256 amount,
        string memory description,
        uint256 dueDate,
        address assignedTo
    ) external returns (uint256 expenseId);

    function markExpensePaid(uint256 expenseId) external;

    function markExpenseDisputed(uint256 expenseId, uint256 disputeId) external;

    function reassignExpense(uint256 expenseId, address newAssignee) external;

    function isExpensePaid(uint256 expenseId) external view returns (bool);

    function getExpenseStatus(uint256 expenseId) external view returns (Expense memory);

    function getCommuneExpenses(uint256 communeId) external view returns (Expense[] memory);

    function getExpenseAssignee(uint256 expenseId) external view returns (address);
}
