// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./CommuneOSModule.sol";

/// @title DisputeResolver
/// @notice Enhanced dispute resolution with types, evidence, appeals, and time-limited voting
contract DisputeResolver is CommuneOSModule {
    enum DisputeType { Expense, Chore, Guest, General }
    enum DisputeState { Active, Resolved, Appealed, AppealResolved, Expired }

    struct EnhancedDispute {
        uint256 id;
        uint256 communeId;
        address initiator;
        address defendant;
        DisputeType disputeType;
        uint256 relatedEntityId;
        string description;
        DisputeState state;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 createdAt;
        uint256 resolvedAt;
        uint256 votingDeadline;
        bool appealed;
        string appealReason;
    }

    struct Evidence {
        address submitter;
        string content;
        uint256 timestamp;
    }

    mapping(uint256 => EnhancedDispute) public disputes;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    mapping(uint256 => Evidence[]) public evidences;
    uint256 public disputeCount;

    uint256 public constant VOTING_PERIOD = 7 days;
    uint256 public constant MAX_DISPUTE_AGE = 30 days;

    event EnhancedDisputeCreated(uint256 indexed disputeId, uint256 indexed communeId, DisputeType disputeType);
    event EvidenceSubmitted(uint256 indexed disputeId, address indexed submitter);
    event DisputeVoteCast(uint256 indexed disputeId, address indexed voter, bool support);
    event DisputeResolved(uint256 indexed disputeId, bool upheld);
    event DisputeAppealed(uint256 indexed disputeId, string reason);
    event DisputeExpired(uint256 indexed disputeId);

    error InvalidDisputeId();
    error DisputeNotActive();
    error AlreadyVoted();
    error VotingEnded();
    error VotingNotEnded();
    error AlreadyAppealed();
    error CannotAppeal();
    error EntityTooOld();

    function createDispute(
        uint256 communeId,
        address defendant,
        DisputeType disputeType,
        uint256 relatedEntityId,
        string memory description
    ) external onlyCommuneOS returns (uint256 disputeId) {
        disputeId = disputeCount++;

        disputes[disputeId] = EnhancedDispute({
            id: disputeId,
            communeId: communeId,
            initiator: tx.origin,
            defendant: defendant,
            disputeType: disputeType,
            relatedEntityId: relatedEntityId,
            description: description,
            state: DisputeState.Active,
            votesFor: 0,
            votesAgainst: 0,
            createdAt: block.timestamp,
            resolvedAt: 0,
            votingDeadline: block.timestamp + VOTING_PERIOD,
            appealed: false,
            appealReason: ""
        });

        emit EnhancedDisputeCreated(disputeId, communeId, disputeType);
    }

    function submitEvidence(uint256 disputeId, string memory content) external onlyCommuneOS {
        if (disputeId >= disputeCount) revert InvalidDisputeId();
        EnhancedDispute storage d = disputes[disputeId];
        if (d.state != DisputeState.Active && d.state != DisputeState.Appealed) revert DisputeNotActive();

        evidences[disputeId].push(Evidence({
            submitter: tx.origin,
            content: content,
            timestamp: block.timestamp
        }));

        emit EvidenceSubmitted(disputeId, tx.origin);
    }

    function vote(uint256 disputeId, address voter, bool support, uint256 totalMembers) external onlyCommuneOS {
        if (disputeId >= disputeCount) revert InvalidDisputeId();
        EnhancedDispute storage d = disputes[disputeId];
        if (d.state != DisputeState.Active && d.state != DisputeState.Appealed) revert DisputeNotActive();
        if (block.timestamp > d.votingDeadline) revert VotingEnded();
        if (hasVoted[disputeId][voter]) revert AlreadyVoted();

        hasVoted[disputeId][voter] = true;
        if (support) d.votesFor++;
        else d.votesAgainst++;

        emit DisputeVoteCast(disputeId, voter, support);

        // Check >50% majority with quorum (50% of members must vote)
        uint256 totalVotes = d.votesFor + d.votesAgainst;
        uint256 quorum = (totalMembers + 1) / 2; // ceiling
        if (totalVotes >= quorum) {
            if (d.votesFor > d.votesAgainst) {
                d.state = d.appealed ? DisputeState.AppealResolved : DisputeState.Resolved;
                d.resolvedAt = block.timestamp;
                emit DisputeResolved(disputeId, true);
            } else if (d.votesAgainst > d.votesFor) {
                d.state = d.appealed ? DisputeState.AppealResolved : DisputeState.Resolved;
                d.resolvedAt = block.timestamp;
                emit DisputeResolved(disputeId, false);
            }
        }
    }

    function appeal(uint256 disputeId, string memory reason) external onlyCommuneOS {
        if (disputeId >= disputeCount) revert InvalidDisputeId();
        EnhancedDispute storage d = disputes[disputeId];
        if (d.state != DisputeState.Resolved) revert CannotAppeal();
        if (d.appealed) revert AlreadyAppealed();

        d.state = DisputeState.Appealed;
        d.appealed = true;
        d.appealReason = reason;
        d.votesFor = 0;
        d.votesAgainst = 0;
        d.votingDeadline = block.timestamp + VOTING_PERIOD;

        // Clear votes for re-voting
        emit DisputeAppealed(disputeId, reason);
    }

    function getDispute(uint256 disputeId) external view returns (EnhancedDispute memory) {
        if (disputeId >= disputeCount) revert InvalidDisputeId();
        return disputes[disputeId];
    }

    function getEvidenceCount(uint256 disputeId) external view returns (uint256) {
        return evidences[disputeId].length;
    }

    function getEvidence(uint256 disputeId, uint256 idx) external view returns (Evidence memory) {
        return evidences[disputeId][idx];
    }
}
