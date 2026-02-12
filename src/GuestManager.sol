// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {GuestInvite, GuestPolicy, InviteStatus} from "./interfaces/IGuestManager.sol";
import "./interfaces/IGuestManager.sol";
import "./CommuneOSModule.sol";

/// @title GuestManager
/// @notice Manages guest invitations with approval workflow and policy enforcement
contract GuestManager is CommuneOSModule, IGuestManager {
    mapping(uint256 => GuestInvite) internal _invites;
    mapping(uint256 => GuestPolicy) public guestPolicies;
    mapping(uint256 => mapping(address => bool)) public hasApproved;
    uint256 public inviteCount;

    uint256 public constant MAX_STAY_DURATION = 30 days;

    function createGuestInvite(
        uint256 communeId,
        string memory guestName,
        uint256 arrival,
        uint256 departure,
        string memory reason
    ) external onlyCommuneOS returns (uint256 inviteId) {
        if (arrival >= departure) revert InvalidTimes();
        if (departure - arrival > MAX_STAY_DURATION) revert StayTooLong();

        GuestPolicy memory policy = guestPolicies[communeId];
        if (policy.maxDurationSeconds > 0 && departure - arrival > policy.maxDurationSeconds) {
            revert StayTooLong();
        }

        inviteId = inviteCount++;

        _invites[inviteId] = GuestInvite({
            id: inviteId,
            communeId: communeId,
            host: tx.origin,
            guestName: guestName,
            arrivalTime: arrival,
            departureTime: departure,
            reason: reason,
            status: policy.requireApproval ? InviteStatus.Pending : InviteStatus.Approved,
            approvals: 0
        });

        emit GuestInviteCreated(inviteId, communeId, tx.origin, guestName);
    }

    function approveGuest(uint256 inviteId) external onlyCommuneOS {
        if (inviteId >= inviteCount) revert InvalidInviteId();
        GuestInvite storage invite = _invites[inviteId];
        if (invite.status != InviteStatus.Pending) revert NotPending();
        if (hasApproved[inviteId][tx.origin]) revert AlreadyApproved();

        hasApproved[inviteId][tx.origin] = true;
        invite.approvals++;

        emit GuestInviteApproved(inviteId, tx.origin);

        GuestPolicy memory policy = guestPolicies[invite.communeId];
        if (invite.approvals >= policy.approvalThreshold) {
            invite.status = InviteStatus.Approved;
        }
    }

    function cancelInvite(uint256 inviteId) external onlyCommuneOS {
        if (inviteId >= inviteCount) revert InvalidInviteId();
        GuestInvite storage invite = _invites[inviteId];
        if (invite.status == InviteStatus.Active) revert NotPending();
        if (invite.status == InviteStatus.Completed || invite.status == InviteStatus.Cancelled) revert AlreadyCancelled();

        invite.status = InviteStatus.Cancelled;
        emit GuestInviteCancelled(inviteId);
    }

    function checkInGuest(uint256 inviteId) external onlyCommuneOS {
        if (inviteId >= inviteCount) revert InvalidInviteId();
        GuestInvite storage invite = _invites[inviteId];
        if (invite.status != InviteStatus.Approved) revert NotApproved();

        invite.status = InviteStatus.Active;
        emit GuestCheckedIn(inviteId);
    }

    function checkOutGuest(uint256 inviteId) external onlyCommuneOS {
        if (inviteId >= inviteCount) revert InvalidInviteId();
        GuestInvite storage invite = _invites[inviteId];
        if (invite.status != InviteStatus.Active) revert NotActive();

        invite.status = InviteStatus.Completed;
        emit GuestCheckedOut(inviteId);
    }

    function extendStay(uint256 inviteId, uint256 newDeparture) external onlyCommuneOS {
        if (inviteId >= inviteCount) revert InvalidInviteId();
        GuestInvite storage invite = _invites[inviteId];
        if (invite.status == InviteStatus.Cancelled || invite.status == InviteStatus.Completed) revert AlreadyCancelled();
        if (newDeparture <= invite.departureTime) revert InvalidTimes();
        if (newDeparture - invite.arrivalTime > MAX_STAY_DURATION) revert StayTooLong();

        invite.departureTime = newDeparture;
        emit GuestStayExtended(inviteId, newDeparture);
    }

    function updateGuestPolicy(uint256 communeId, GuestPolicy memory policy) external onlyCommuneOS {
        guestPolicies[communeId] = policy;
        emit GuestPolicyUpdated(communeId);
    }

    function getGuestInvite(uint256 inviteId) external view returns (GuestInvite memory) {
        if (inviteId >= inviteCount) revert InvalidInviteId();
        return _invites[inviteId];
    }

    function getGuestPolicy(uint256 communeId) external view returns (GuestPolicy memory) {
        return guestPolicies[communeId];
    }

    function getCommuneGuests(uint256 communeId) external view returns (GuestInvite[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < inviteCount; i++) {
            if (_invites[i].communeId == communeId) count++;
        }
        GuestInvite[] memory result = new GuestInvite[](count);
        uint256 idx = 0;
        for (uint256 i = 0; i < inviteCount; i++) {
            if (_invites[i].communeId == communeId) {
                result[idx++] = _invites[i];
            }
        }
        return result;
    }
}
