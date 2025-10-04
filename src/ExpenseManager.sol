// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./Types.sol";
import "./interfaces/IExpenseManager.sol";

/// @title ExpenseManager
/// @notice Manages expense lifecycle including creation, assignment, payments, and disputes
contract ExpenseManager is IExpenseManager {
    // ExpenseId (global) => Expense
    mapping(uint256 => Expense) public expenses;

    // ExpenseId => communeId (to track which commune an expense belongs to)
    mapping(uint256 => uint256) public expenseToCommuneId;

    // CommuneId => array of expense IDs
    mapping(uint256 => uint256[]) public communeExpenseIds;

    // ExpenseId => current assigned member
    mapping(uint256 => address) public expenseAssignments;

    // ExpenseId => member => payment status
    mapping(uint256 => mapping(address => bool)) public expensePayments;

    // ExpenseId => disputeId
    mapping(uint256 => uint256) public expenseDisputes;

    uint256 public expenseCount;

    /// @notice Create a new expense with direct assignment
    /// @param communeId The commune ID
    /// @param amount The expense amount
    /// @param description Description of the expense
    /// @param dueDate Due date for the expense
    /// @param assignedTo The member assigned to pay
    /// @return expenseId The ID of the created expense
    function createExpense(
        uint256 communeId,
        uint256 amount,
        string memory description,
        uint256 dueDate,
        address assignedTo
    ) external returns (uint256 expenseId) {
        if (assignedTo == address(0)) revert InvalidAssignee();
        if (amount == 0) revert InvalidAmount();
        if (bytes(description).length == 0) revert EmptyDescription();

        expenseId = expenseCount++;

        Expense memory expense = Expense({
            id: expenseId,
            amount: amount,
            description: description,
            assignedTo: assignedTo,
            dueDate: dueDate,
            paid: false,
            disputed: false,
            createdAt: block.timestamp
        });

        expenses[expenseId] = expense;
        expenseToCommuneId[expenseId] = communeId;
        communeExpenseIds[communeId].push(expenseId);
        expenseAssignments[expenseId] = assignedTo;

        emit ExpenseCreated(expenseId, communeId, assignedTo, amount, description, dueDate);
        return expenseId;
    }

    /// @notice Mark an expense as paid
    /// @param expenseId The expense ID
    function markExpensePaid(uint256 expenseId) external {
        if (expenseId >= expenseCount) revert InvalidExpenseId();
        if (expenses[expenseId].paid) revert AlreadyPaid();

        expenses[expenseId].paid = true;
        expensePayments[expenseId][msg.sender] = true;

        emit ExpensePaid(expenseId, msg.sender);
    }

    /// @notice Mark an expense as disputed
    /// @param expenseId The expense ID
    /// @param disputeId The dispute ID from VotingModule
    function markExpenseDisputed(uint256 expenseId, uint256 disputeId) external {
        if (expenseId >= expenseCount) revert InvalidExpenseId();

        expenses[expenseId].disputed = true;
        expenseDisputes[expenseId] = disputeId;

        emit ExpenseDisputed(expenseId, disputeId);
    }

    /// @notice Reassign an expense to a new member (after dispute resolution)
    /// @param expenseId The expense ID
    /// @param newAssignee The new assignee
    function reassignExpense(uint256 expenseId, address newAssignee) external {
        if (expenseId >= expenseCount) revert InvalidExpenseId();
        if (newAssignee == address(0)) revert InvalidAssignee();

        address oldAssignee = expenses[expenseId].assignedTo;

        expenses[expenseId].assignedTo = newAssignee;
        expenses[expenseId].paid = false; // Reset paid status
        expenseAssignments[expenseId] = newAssignee;

        emit ExpenseReassigned(expenseId, oldAssignee, newAssignee);
    }

    /// @notice Check if an expense is paid
    /// @param expenseId The expense ID
    /// @return bool True if paid
    function isExpensePaid(uint256 expenseId) external view returns (bool) {
        if (expenseId >= expenseCount) revert InvalidExpenseId();
        return expenses[expenseId].paid;
    }

    /// @notice Get expense status
    /// @param expenseId The expense ID
    /// @return Expense The expense data
    function getExpenseStatus(uint256 expenseId) external view returns (Expense memory) {
        if (expenseId >= expenseCount) revert InvalidExpenseId();
        return expenses[expenseId];
    }

    /// @notice Get all expenses for a commune
    /// @param communeId The commune ID
    /// @return Expense[] Array of expenses
    function getCommuneExpenses(uint256 communeId) external view returns (Expense[] memory) {
        uint256[] memory expenseIds = communeExpenseIds[communeId];
        Expense[] memory result = new Expense[](expenseIds.length);

        for (uint256 i = 0; i < expenseIds.length; i++) {
            result[i] = expenses[expenseIds[i]];
        }

        return result;
    }

    /// @notice Get current assignee for an expense
    /// @param expenseId The expense ID
    /// @return address The assigned member
    function getExpenseAssignee(uint256 expenseId) external view returns (address) {
        if (expenseId >= expenseCount) revert InvalidExpenseId();
        return expenseAssignments[expenseId];
    }
}
