// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title CommuneOS Domain Types
/// @notice Core data structures for the CommuneOS smart contract system

/// @notice Represents a commune - a group living arrangement with shared responsibilities
/// @dev Commune IDs start at 1 (0 is reserved as a sentinel value)
struct Commune {
    /// @notice Unique identifier for the commune
    uint256 id;
    /// @notice Human-readable name of the commune
    string name;
    /// @notice Address of the commune creator (can issue invites)
    address creator;
    /// @notice Whether members must deposit collateral to join
    bool collateralRequired;
    /// @notice Amount of collateral required (in wei or token units)
    uint256 collateralAmount;
}

/// @notice Represents a member of a commune
/// @dev Members are stored in arrays per commune for efficient iteration
struct Member {
    /// @notice Ethereum address of the member
    address walletAddress;
    /// @notice ID of the commune this member belongs to
    uint256 communeId;
    /// @notice Whether the member is currently active
    bool active;
}

/// @notice Represents a recurring chore schedule
/// @dev Chores are period-based with automatic rotation assignment
struct ChoreSchedule {
    /// @notice Unique identifier for the chore within a commune
    uint256 id;
    /// @notice Description of the chore
    string title;
    /// @notice How often the chore repeats (in seconds)
    uint256 frequency;
    /// @notice Unix timestamp when the chore schedule starts
    uint256 startTime;
}

/// @notice Represents a financial expense within a commune
/// @dev Expenses can be assigned, paid, and disputed
struct Expense {
    /// @notice Global unique identifier for the expense
    uint256 id;
    /// @notice ID of the commune this expense belongs to
    uint256 communeId;
    /// @notice Amount of the expense (in wei or token units)
    uint256 amount;
    /// @notice Description of what the expense is for
    string description;
    /// @notice Address of the member assigned to pay this expense
    address assignedTo;
    /// @notice Unix timestamp when payment is due
    uint256 dueDate;
    /// @notice Whether the expense has been paid
    bool paid;
    /// @notice Whether the expense assignment is being disputed
    bool disputed;
}

/// @notice Represents a dispute over an expense assignment
/// @dev Disputes auto-resolve when 2/3 majority is reached
struct Dispute {
    /// @notice ID of the expense being disputed
    uint256 expenseId;
    /// @notice Address proposed as the new assignee if dispute is upheld
    address proposedNewAssignee;
    /// @notice Number of votes in favor of the dispute
    uint256 votesFor;
    /// @notice Number of votes against the dispute
    uint256 votesAgainst;
    /// @notice Whether the dispute has been resolved
    bool resolved;
    /// @notice If resolved, whether the dispute was upheld (true) or rejected (false)
    bool upheld;
    /// @notice Unix timestamp when the dispute was created
    uint256 createdAt;
}
