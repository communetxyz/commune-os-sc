// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title CommuneOS Domain Types
/// @notice Core data structures for the CommuneOS smart contract system

struct Commune {
    uint256 id;
    string name;
    address creator;
    bool collateralRequired;
    uint256 collateralAmount;
}

struct Member {
    address walletAddress;
    uint256 joinDate;
    uint256 communeId;
    uint256 collateralDeposited;
    bool active;
}

struct ChoreSchedule {
    uint256 id;
    string title;
    uint256 frequency; // in seconds
    uint256 startTime; // Unix timestamp
}

struct Expense {
    uint256 id;
    uint256 amount;
    string description;
    address assignedTo;
    uint256 dueDate;
    bool paid;
    bool disputed;
    uint256 createdAt;
}

struct Dispute {
    uint256 expenseId;
    address proposedNewAssignee;
    uint256 votesFor;
    uint256 votesAgainst;
    bool resolved;
    bool upheld;
    uint256 createdAt;
}
