// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Dispute} from "./Types.sol";
import "./interfaces/IVotingModule.sol";
import "./CommuneOSModule.sol";

/// @title VotingModule
/// @notice Manages voting on expense disputes
contract VotingModule is CommuneOSModule, IVotingModule {
    // DisputeId => Dispute data
    mapping(uint256 => Dispute) public disputes;

    // DisputeId => voter => hasVoted
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    // DisputeId => voter => vote (true = for, false = against)
    mapping(uint256 => mapping(address => bool)) public votes;

    uint256 public disputeCount;

    /// @notice Create a new dispute for an expense
    /// @param expenseId The expense being disputed
    /// @param proposedNewAssignee The proposed new assignee
    /// @return disputeId The ID of the created dispute
    function createDispute(uint256 expenseId, address proposedNewAssignee)
        external
        onlyCommuneOS
        returns (uint256 disputeId)
    {
        if (proposedNewAssignee == address(0)) revert InvalidAssignee();

        disputeId = disputeCount++;

        disputes[disputeId] = Dispute({
            expenseId: expenseId,
            proposedNewAssignee: proposedNewAssignee,
            votesFor: 0,
            votesAgainst: 0,
            resolved: false,
            upheld: false,
            createdAt: block.timestamp
        });

        emit DisputeCreated(disputeId, expenseId, proposedNewAssignee);
        return disputeId;
    }

    /// @notice Vote on a dispute
    /// @param disputeId The dispute ID
    /// @param voter The address of the voter
    /// @param support True to support the dispute, false to reject
    function voteOnDispute(uint256 disputeId, address voter, bool support) external onlyCommuneOS {
        if (disputeId >= disputeCount) revert InvalidDisputeId();
        if (disputes[disputeId].resolved) revert AlreadyResolved();
        if (hasVoted[disputeId][voter]) revert AlreadyVoted();

        hasVoted[disputeId][voter] = true;
        votes[disputeId][voter] = support;

        if (support) {
            disputes[disputeId].votesFor++;
        } else {
            disputes[disputeId].votesAgainst++;
        }

        emit VoteCast(disputeId, voter, support);
    }

    /// @notice Resolve a dispute based on votes
    /// @param disputeId The dispute ID
    /// @param totalMembers Total number of commune members
    /// @return upheld True if dispute was upheld
    function resolveDispute(uint256 disputeId, uint256 totalMembers) external onlyCommuneOS returns (bool upheld) {
        if (disputeId >= disputeCount) revert InvalidDisputeId();
        if (disputes[disputeId].resolved) revert AlreadyResolved();

        Dispute storage dispute = disputes[disputeId];

        // Simple majority: more than 50% of members voted in favor
        uint256 totalVotes = dispute.votesFor + dispute.votesAgainst;
        if (totalVotes == 0) revert NoVotesCast();

        upheld = dispute.votesFor > dispute.votesAgainst;

        dispute.resolved = true;
        dispute.upheld = upheld;

        emit DisputeResolved(disputeId, upheld);
        return upheld;
    }

    /// @notice Get dispute details
    /// @param disputeId The dispute ID
    /// @return Dispute The dispute data
    function getDispute(uint256 disputeId) external view returns (Dispute memory) {
        if (disputeId >= disputeCount) revert InvalidDisputeId();
        return disputes[disputeId];
    }

    /// @notice Check if address has voted on a dispute
    /// @param disputeId The dispute ID
    /// @param voter The voter address
    /// @return bool True if has voted
    function hasVotedOnDispute(uint256 disputeId, address voter) external view returns (bool) {
        return hasVoted[disputeId][voter];
    }

    /// @notice Get vote tallies for a dispute
    /// @param disputeId The dispute ID
    /// @return votesFor Number of votes in favor
    /// @return votesAgainst Number of votes against
    function tallyVotes(uint256 disputeId) external view returns (uint256 votesFor, uint256 votesAgainst) {
        if (disputeId >= disputeCount) revert InvalidDisputeId();
        Dispute memory dispute = disputes[disputeId];
        return (dispute.votesFor, dispute.votesAgainst);
    }
}
