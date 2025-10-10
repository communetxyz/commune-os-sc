// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Status of a dispute
enum DisputeStatus {
    Pending,    // Voting in progress
    Upheld,     // Dispute accepted, reassignment occurs
    Rejected    // Dispute rejected, no changes
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
    /// @notice Current status of the dispute
    DisputeStatus status;
}

/// @title IVotingModule
/// @notice Interface for managing voting on expense disputes
interface IVotingModule {
    // Events
    event DisputeCreated(uint256 indexed disputeId, uint256 indexed expenseId, address proposedNewAssignee);
    event VoteCast(uint256 indexed disputeId, address indexed voter, bool support);
    event DisputeResolved(uint256 indexed disputeId, bool upheld);

    // Errors
    error InvalidAssignee();
    error InvalidDisputeId();
    error AlreadyResolved();
    error AlreadyVoted();

    // Functions
    function createDispute(uint256 expenseId, address proposedNewAssignee) external returns (uint256 disputeId);

    function voteOnDispute(uint256 disputeId, address voter, bool support, uint256 totalMembers) external;

    function getDispute(uint256 disputeId) external view returns (Dispute memory);

    function hasVotedOnDispute(uint256 disputeId, address voter) external view returns (bool);

    function tallyVotes(uint256 disputeId) external view returns (uint256 votesFor, uint256 votesAgainst);
}
