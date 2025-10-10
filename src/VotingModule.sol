// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Dispute} from "./interfaces/IVotingModule.sol";
import "./interfaces/IVotingModule.sol";
import "./CommuneOSModule.sol";

/// @title VotingModule
/// @notice Manages voting on expense disputes with automatic 2/3 majority resolution
/// @dev Disputes auto-resolve when either votesFor or votesAgainst reaches 2/3 of total members
contract VotingModule is CommuneOSModule, IVotingModule {
    /// @notice Minimum time that must pass before a dispute can be resolved
    uint256 public constant MIN_VOTING_PERIOD = 1 days;

    /// @notice Stores dispute data by dispute ID
    /// @dev Maps dispute ID => Dispute struct containing all dispute information
    mapping(uint256 => Dispute) public disputes;

    /// @notice Tracks whether an address has voted on a specific dispute
    /// @dev Maps dispute ID => voter address => has voted (true/false)
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    /// @notice Records the vote choice for each voter on each dispute
    /// @dev Maps dispute ID => voter address => vote (true = for, false = against)
    mapping(uint256 => mapping(address => bool)) public votes;

    /// @notice Total number of disputes created (also serves as next dispute ID)
    uint256 public disputeCount;

    /// @notice Thrown when trying to resolve dispute before minimum voting period
    error VotingPeriodNotEnded();

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

    /// @notice Vote on a dispute and automatically resolve if 2/3 majority is reached
    /// @param disputeId The dispute ID
    /// @param voter The address of the voter
    /// @param support True to support the dispute, false to reject
    /// @param totalMembers Total number of commune members
    /// @dev Auto-resolves when votesFor or votesAgainst reaches (totalMembers * 2) / 3
    function voteOnDispute(uint256 disputeId, address voter, bool support, uint256 totalMembers)
        external
        onlyCommuneOS
    {
        if (disputeId >= disputeCount) revert InvalidDisputeId();
        if (disputes[disputeId].resolved) revert AlreadyResolved();
        if (hasVoted[disputeId][voter]) revert AlreadyVoted();

        hasVoted[disputeId][voter] = true;
        votes[disputeId][voter] = support;

        Dispute storage dispute = disputes[disputeId];

        if (support) {
            dispute.votesFor++;
        } else {
            dispute.votesAgainst++;
        }

        emit VoteCast(disputeId, voter, support);

        // Check if minimum voting period has passed
        if (block.timestamp < dispute.createdAt + MIN_VOTING_PERIOD) {
            return; // Cannot resolve yet, voting period not ended
        }

        // Check if 2/3 majority has been reached (either for or against)
        uint256 requiredVotes = (totalMembers * 2) / 3;

        if (dispute.votesFor >= requiredVotes) {
            // 2/3 voted in favor - dispute is upheld
            dispute.resolved = true;
            dispute.upheld = true;
            emit DisputeResolved(disputeId, true);
        } else if (dispute.votesAgainst >= requiredVotes) {
            // 2/3 voted against - dispute is rejected
            dispute.resolved = true;
            dispute.upheld = false;
            emit DisputeResolved(disputeId, false);
        }
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
