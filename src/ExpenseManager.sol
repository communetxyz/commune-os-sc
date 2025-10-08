// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Expense} from "./Types.sol";
import "./interfaces/IExpenseManager.sol";
import "./CommuneOSModule.sol";

/// @title ExpenseManager
/// @notice Manages expense lifecycle including creation, assignment, payments, and disputes
/// @dev Expenses are globally unique and can be assigned, paid, disputed, and reassigned
contract ExpenseManager is CommuneOSModule, IExpenseManager {
    /// @notice Stores expense data by globally unique expense ID
    /// @dev Maps expense ID => Expense struct containing all expense information
    mapping(uint256 => Expense) public expenses;

    /// @notice Links expenses to their associated disputes
    /// @dev Maps expense ID => dispute ID (only set when expense is disputed)
    mapping(uint256 => uint256) public expenseDisputes;

    /// @notice Total number of expenses created (also serves as next expense ID)
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
    ) external onlyCommuneOS returns (uint256 expenseId) {
        if (assignedTo == address(0)) revert InvalidAssignee();
        if (amount == 0) revert InvalidAmount();
        if (bytes(description).length == 0) revert EmptyDescription();

        expenseId = expenseCount++;

        expenses[expenseId] = Expense({
            id: expenseId,
            communeId: communeId,
            amount: amount,
            description: description,
            assignedTo: assignedTo,
            dueDate: dueDate,
            paid: false,
            disputed: false
        });

        emit ExpenseCreated(expenseId, communeId, assignedTo, amount, description, dueDate);
        return expenseId;
    }

    /// @notice Mark an expense as paid
    /// @param expenseId The expense ID
    function markExpensePaid(uint256 expenseId) external onlyCommuneOS {
        if (expenseId >= expenseCount) revert InvalidExpenseId();
        if (expenses[expenseId].paid) revert AlreadyPaid();

        expenses[expenseId].paid = true;

        emit ExpensePaid(expenseId, msg.sender);
    }

    /// @notice Mark an expense as disputed
    /// @param expenseId The expense ID
    /// @param disputeId The dispute ID from VotingModule
    function markExpenseDisputed(uint256 expenseId, uint256 disputeId) external onlyCommuneOS {
        if (expenseId >= expenseCount) revert InvalidExpenseId();

        expenses[expenseId].disputed = true;
        expenseDisputes[expenseId] = disputeId;

        emit ExpenseDisputed(expenseId, disputeId);
    }

    /// @notice Reassign an expense to a new member (after dispute resolution)
    /// @param expenseId The expense ID
    /// @param newAssignee The new assignee
    /// @dev Resets the paid status to false when reassigning
    function reassignExpense(uint256 expenseId, address newAssignee) external onlyCommuneOS {
        if (expenseId >= expenseCount) revert InvalidExpenseId();
        if (newAssignee == address(0)) revert InvalidAssignee();

        address oldAssignee = expenses[expenseId].assignedTo;

        expenses[expenseId].assignedTo = newAssignee;
        expenses[expenseId].paid = false; // Reset paid status

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
    /// @dev Iterates through all expenses and filters by commune ID (O(n) complexity)
    function getCommuneExpenses(uint256 communeId) external view returns (Expense[] memory) {
        // First, count how many expenses belong to this commune
        uint256 count = 0;
        for (uint256 i = 0; i < expenseCount; i++) {
            if (expenses[i].communeId == communeId) {
                count++;
            }
        }

        // Create result array and populate it
        Expense[] memory result = new Expense[](count);
        uint256 resultIndex = 0;
        for (uint256 i = 0; i < expenseCount; i++) {
            if (expenses[i].communeId == communeId) {
                result[resultIndex] = expenses[i];
                resultIndex++;
            }
        }

        return result;
    }

    /// @notice Get current assignee for an expense
    /// @param expenseId The expense ID
    /// @return address The assigned member
    function getExpenseAssignee(uint256 expenseId) external view returns (address) {
        if (expenseId >= expenseCount) revert InvalidExpenseId();
        return expenses[expenseId].assignedTo;
    }
}
