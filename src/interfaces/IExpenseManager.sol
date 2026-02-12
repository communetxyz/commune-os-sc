// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Represents an expense within a commune
struct Expense {
    uint256 id;
    uint256 communeId;
    address creator;
    string description;
    uint256 amount;
    bool hasAmount;
    address[] assignedTo;
    bool isPaid;
    uint256 createdAt;
}

/// @title IExpenseManager
/// @notice Interface for managing shared expenses within communes
interface IExpenseManager {
    // Events
    event ExpenseCreated(uint256 indexed expenseId, uint256 indexed communeId, address indexed creator, string description, bool hasAmount, uint256 amount);
    event ExpenseAmountSet(uint256 indexed expenseId, uint256 amount);
    event ExpenseAmountUpdated(uint256 indexed expenseId, uint256 oldAmount, uint256 newAmount);
    event ExpensePaid(uint256 indexed expenseId, address indexed paidBy);

    // Errors
    error InvalidExpenseId();
    error EmptyDescription();
    error NoAssignees();
    error AlreadyPaid();
    error AmountNotSet();
    error AmountAlreadyLocked();
    error NotExpenseParticipant();

    // Functions
    function createExpense(uint256 communeId, string memory description, address[] memory assignedTo) external returns (uint256);
    function createExpenseWithAmount(uint256 communeId, string memory description, uint256 amount, address[] memory assignedTo) external returns (uint256);
    function setExpenseAmount(uint256 expenseId, uint256 amount) external;
    function markExpensePaid(uint256 expenseId) external;
    function getExpense(uint256 expenseId) external view returns (Expense memory);
    function getCommuneExpenses(uint256 communeId) external view returns (Expense[] memory);
}
