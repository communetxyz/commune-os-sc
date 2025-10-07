// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Dispute} from "../Types.sol";

/// @title IVotingModule
/// @notice Interface for managing voting on expense disputes
interface IVotingModule {
    // Events
    event DisputeCreated(uint256 indexed disputeId, uint256 indexed expenseId, address proposedNewAssignee);
    event VoteCast(uint256 indexed disputeId, address indexed voter, bool support);
    event DisputeResolved(uint256 indexed disputeId, bool upheld);

    // Errors
    error Unauthorized();
    error InvalidAssignee();
    error InvalidDisputeId();
    error AlreadyResolved();
    error AlreadyVoted();
    error NoVotesCast();

    // Functions
    function createDispute(uint256 expenseId, address proposedNewAssignee) external returns (uint256 disputeId);

    function voteOnDispute(uint256 disputeId, address voter, bool support) external;

    function resolveDispute(uint256 disputeId, uint256 totalMembers) external returns (bool upheld);

    function getDispute(uint256 disputeId) external view returns (Dispute memory);

    function hasVotedOnDispute(uint256 disputeId, address voter) external view returns (bool);

    function tallyVotes(uint256 disputeId) external view returns (uint256 votesFor, uint256 votesAgainst);
}
