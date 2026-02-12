// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Expense} from "./interfaces/IExpenseManager.sol";
import "./interfaces/IExpenseManager.sol";
import "./CommuneOSModule.sol";

/// @title ExpenseManager
/// @notice Manages shared expenses within communes with optional amounts
/// @dev Amount field is optional — expenses can be created without an amount and set later
contract ExpenseManager is CommuneOSModule, IExpenseManager {
    /// @notice Stores expense data by expense ID
    mapping(uint256 => Expense) internal _expenses;

    /// @notice Total number of expenses created
    uint256 public expenseCount;

    /// @notice Create an expense without an amount
    /// @param communeId The commune ID
    /// @param description Expense description
    /// @param assignedTo Members responsible for this expense
    /// @return expenseId The ID of the created expense
    function createExpense(uint256 communeId, string memory description, address[] memory assignedTo)
        external
        onlyCommuneOS
        returns (uint256 expenseId)
    {
        if (bytes(description).length == 0) revert EmptyDescription();
        if (assignedTo.length == 0) revert NoAssignees();

        expenseId = expenseCount++;

        _expenses[expenseId] = Expense({
            id: expenseId,
            communeId: communeId,
            creator: tx.origin,
            description: description,
            amount: 0,
            hasAmount: false,
            assignedTo: assignedTo,
            isPaid: false,
            createdAt: block.timestamp
        });

        emit ExpenseCreated(expenseId, communeId, tx.origin, description, false, 0);
    }

    /// @notice Create an expense with an amount
    /// @param communeId The commune ID
    /// @param description Expense description
    /// @param amount The expense amount
    /// @param assignedTo Members responsible for this expense
    /// @return expenseId The ID of the created expense
    function createExpenseWithAmount(
        uint256 communeId,
        string memory description,
        uint256 amount,
        address[] memory assignedTo
    ) external onlyCommuneOS returns (uint256 expenseId) {
        if (bytes(description).length == 0) revert EmptyDescription();
        if (assignedTo.length == 0) revert NoAssignees();

        expenseId = expenseCount++;

        _expenses[expenseId] = Expense({
            id: expenseId,
            communeId: communeId,
            creator: tx.origin,
            description: description,
            amount: amount,
            hasAmount: true,
            assignedTo: assignedTo,
            isPaid: false,
            createdAt: block.timestamp
        });

        emit ExpenseCreated(expenseId, communeId, tx.origin, description, true, amount);
    }

    /// @notice Set or update the amount on an expense
    /// @param expenseId The expense ID
    /// @param amount The amount to set
    function setExpenseAmount(uint256 expenseId, uint256 amount) external onlyCommuneOS {
        if (expenseId >= expenseCount) revert InvalidExpenseId();
        Expense storage expense = _expenses[expenseId];
        if (expense.isPaid) revert AmountAlreadyLocked();

        uint256 oldAmount = expense.amount;
        bool hadAmount = expense.hasAmount;

        expense.amount = amount;
        expense.hasAmount = true;

        if (hadAmount) {
            emit ExpenseAmountUpdated(expenseId, oldAmount, amount);
        } else {
            emit ExpenseAmountSet(expenseId, amount);
        }
    }

    /// @notice Mark an expense as paid
    /// @param expenseId The expense ID
    function markExpensePaid(uint256 expenseId) external onlyCommuneOS {
        if (expenseId >= expenseCount) revert InvalidExpenseId();
        Expense storage expense = _expenses[expenseId];
        if (expense.isPaid) revert AlreadyPaid();
        if (!expense.hasAmount) revert AmountNotSet();

        expense.isPaid = true;
        emit ExpensePaid(expenseId, tx.origin);
    }

    /// @notice Get expense details
    /// @param expenseId The expense ID
    /// @return The expense data
    function getExpense(uint256 expenseId) external view returns (Expense memory) {
        if (expenseId >= expenseCount) revert InvalidExpenseId();
        return _expenses[expenseId];
    }

    /// @notice Get all expenses for a commune
    /// @param communeId The commune ID
    /// @return Expense[] Array of expenses
    function getCommuneExpenses(uint256 communeId) external view returns (Expense[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < expenseCount; i++) {
            if (_expenses[i].communeId == communeId) count++;
        }

        Expense[] memory result = new Expense[](count);
        uint256 idx = 0;
        for (uint256 i = 0; i < expenseCount; i++) {
            if (_expenses[i].communeId == communeId) {
                result[idx++] = _expenses[i];
            }
        }
        return result;
    }
}
