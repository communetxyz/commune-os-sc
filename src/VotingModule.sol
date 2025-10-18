// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Dispute, DisputeStatus} from "./interfaces/IVotingModule.sol";
import "./interfaces/IVotingModule.sol";
import "./CommuneOSModule.sol";

/// @title VotingModule
/// @notice Manages voting on task disputes with automatic 2/3 majority resolution
/// @dev Disputes auto-resolve when either votesFor or votesAgainst reaches 2/3 of total members
contract VotingModule is CommuneOSModule, IVotingModule {
    /// @custom:storage-location erc7201:commune.storage.VotingModule
    struct VotingModuleStorage {
        mapping(uint256 => Dispute) disputes;
        mapping(uint256 => mapping(address => bool)) hasVoted;
        mapping(uint256 => mapping(address => bool)) votes;
        uint256 disputeCount;
    }

    // keccak256(abi.encode(uint256(keccak256("commune.storage.VotingModule")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant VotingModuleStorageLocation =
        0x6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a00;

    function _getVotingModuleStorage() private pure returns (VotingModuleStorage storage $) {
        assembly {
            $.slot := VotingModuleStorageLocation
        }
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Returns a dispute by ID
    function disputes(uint256 disputeId) public view returns (Dispute memory) {
        VotingModuleStorage storage $ = _getVotingModuleStorage();
        return $.disputes[disputeId];
    }

    /// @notice Returns whether an address has voted on a dispute
    function hasVoted(uint256 disputeId, address voter) public view returns (bool) {
        VotingModuleStorage storage $ = _getVotingModuleStorage();
        return $.hasVoted[disputeId][voter];
    }

    /// @notice Returns the vote choice for a voter on a dispute
    function votes(uint256 disputeId, address voter) public view returns (bool) {
        VotingModuleStorage storage $ = _getVotingModuleStorage();
        return $.votes[disputeId][voter];
    }

    /// @notice Returns the total number of disputes
    function disputeCount() public view returns (uint256) {
        VotingModuleStorage storage $ = _getVotingModuleStorage();
        return $.disputeCount;
    }

    /// @notice Initializes the VotingModule
    /// @param _communeOS Address of the main CommuneOS contract
    function initialize(address _communeOS) external initializer {
        __CommuneOSModule_init(_communeOS);
    }

    /// @notice Create a new dispute for a task
    /// @param taskId The task being disputed
    /// @param proposedNewAssignee The proposed new assignee
    /// @return disputeId The ID of the created dispute
    function createDispute(uint256 taskId, address proposedNewAssignee)
        external
        onlyCommuneOS
        returns (uint256 disputeId)
    {
        if (proposedNewAssignee == address(0)) revert InvalidAssignee();

        VotingModuleStorage storage $ = _getVotingModuleStorage();
        disputeId = $.disputeCount++;

        $.disputes[disputeId] = Dispute({
            taskId: taskId,
            proposedNewAssignee: proposedNewAssignee,
            votesFor: 0,
            votesAgainst: 0,
            status: DisputeStatus.Pending
        });

        emit DisputeCreated(disputeId, taskId, proposedNewAssignee);
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
        VotingModuleStorage storage $ = _getVotingModuleStorage();
        if (disputeId >= $.disputeCount) revert InvalidDisputeId();
        if ($.disputes[disputeId].status != DisputeStatus.Pending) revert AlreadyResolved();
        if ($.hasVoted[disputeId][voter]) revert AlreadyVoted();

        $.hasVoted[disputeId][voter] = true;
        $.votes[disputeId][voter] = support;

        Dispute storage dispute = $.disputes[disputeId];

        if (support) {
            dispute.votesFor++;
        } else {
            dispute.votesAgainst++;
        }

        emit VoteCast(disputeId, voter, support);

        // Check if 2/3 majority has been reached (either for or against)
        uint256 requiredVotes = (totalMembers * 2) / 3;

        if (dispute.votesFor >= requiredVotes) {
            // 2/3 voted in favor - dispute is upheld
            dispute.status = DisputeStatus.Upheld;
            emit DisputeResolved(disputeId, true);
        } else if (dispute.votesAgainst >= requiredVotes) {
            // 2/3 voted against - dispute is rejected
            dispute.status = DisputeStatus.Rejected;
            emit DisputeResolved(disputeId, false);
        }
    }

    /// @notice Get dispute details
    /// @param disputeId The dispute ID
    /// @return Dispute The dispute data
    function getDispute(uint256 disputeId) external view returns (Dispute memory) {
        VotingModuleStorage storage $ = _getVotingModuleStorage();
        if (disputeId >= $.disputeCount) revert InvalidDisputeId();
        return $.disputes[disputeId];
    }

    /// @notice Check if address has voted on a dispute
    /// @param disputeId The dispute ID
    /// @param voter The voter address
    /// @return bool True if has voted
    function hasVotedOnDispute(uint256 disputeId, address voter) external view returns (bool) {
        VotingModuleStorage storage $ = _getVotingModuleStorage();
        return $.hasVoted[disputeId][voter];
    }

    /// @notice Get vote tallies for a dispute
    /// @param disputeId The dispute ID
    /// @return votesFor Number of votes in favor
    /// @return votesAgainst Number of votes against
    function tallyVotes(uint256 disputeId) external view returns (uint256 votesFor, uint256 votesAgainst) {
        VotingModuleStorage storage $ = _getVotingModuleStorage();
        if (disputeId >= $.disputeCount) revert InvalidDisputeId();
        Dispute memory dispute = $.disputes[disputeId];
        return (dispute.votesFor, dispute.votesAgainst);
    }
}
