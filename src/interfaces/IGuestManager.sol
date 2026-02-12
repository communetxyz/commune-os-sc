// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

enum InviteStatus { Pending, Approved, Active, Completed, Cancelled }

struct GuestInvite {
    uint256 id;
    uint256 communeId;
    address host;
    string guestName;
    uint256 arrivalTime;
    uint256 departureTime;
    string reason;
    InviteStatus status;
    uint256 approvals;
}

struct GuestPolicy {
    uint256 maxGuestsAtOnce;
    uint256 maxDurationSeconds;
    bool requireApproval;
    uint256 approvalThreshold;
}

interface IGuestManager {
    event GuestInviteCreated(uint256 indexed inviteId, uint256 indexed communeId, address indexed host, string guestName);
    event GuestInviteApproved(uint256 indexed inviteId, address indexed approver);
    event GuestInviteCancelled(uint256 indexed inviteId);
    event GuestStayExtended(uint256 indexed inviteId, uint256 newDeparture);
    event GuestPolicyUpdated(uint256 indexed communeId);
    event GuestCheckedIn(uint256 indexed inviteId);
    event GuestCheckedOut(uint256 indexed inviteId);

    error InvalidInviteId();
    error InvalidTimes();
    error StayTooLong();
    error AlreadyApproved();
    error NotPending();
    error NotApproved();
    error NotActive();
    error AlreadyCancelled();
    error TooManyGuests();

    function createGuestInvite(uint256 communeId, string memory guestName, uint256 arrival, uint256 departure, string memory reason) external returns (uint256);
    function approveGuest(uint256 inviteId) external;
    function cancelInvite(uint256 inviteId) external;
    function checkInGuest(uint256 inviteId) external;
    function checkOutGuest(uint256 inviteId) external;
    function extendStay(uint256 inviteId, uint256 newDeparture) external;
    function updateGuestPolicy(uint256 communeId, GuestPolicy memory policy) external;
    function getGuestInvite(uint256 inviteId) external view returns (GuestInvite memory);
    function getGuestPolicy(uint256 communeId) external view returns (GuestPolicy memory);
    function getCommuneGuests(uint256 communeId) external view returns (GuestInvite[] memory);
}
