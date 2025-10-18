// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/ICommuneOS.sol";
import {DisputeStatus, Dispute} from "./interfaces/IVotingModule.sol";
import "./CommuneViewer.sol";

/// @title CommuneOS
/// @notice Main contract integrating all commune management modules
/// @dev Deployed on Gnosis Chain for low gas fees. Coordinates all module interactions.
contract CommuneOS is CommuneViewer, ICommuneOS {
    /// @notice Modifier to check if caller is a member of the commune
    /// @param communeId The commune ID to check membership for
    modifier onlyMember(uint256 communeId) {
        if (!memberRegistry().isMember(communeId, msg.sender)) revert NotAMember();
        _;
    }

    /// @notice Modifier to check if both caller and another address are members
    /// @param communeId The commune ID to check membership for
    /// @param otherAddress The other address to check
    modifier onlyMembers(uint256 communeId, address otherAddress) {
        address[] memory addresses = new address[](2);
        addresses[0] = msg.sender;
        addresses[1] = otherAddress;
        bool[] memory results = memberRegistry().areMembers(communeId, addresses);
        if (!results[0] || !results[1]) revert NotAMember();
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes CommuneOS with all module contract addresses
    /// @param _communeRegistry Address of the CommuneRegistry proxy
    /// @param _memberRegistry Address of the MemberRegistry proxy
    /// @param _choreScheduler Address of the ChoreScheduler proxy
    /// @param _taskManager Address of the TaskManager proxy
    /// @param _votingModule Address of the VotingModule proxy
    /// @param _collateralManager Address of the CollateralManager proxy
    /// @dev Module contracts must be deployed and initialized before calling this
    function initialize(
        address _communeRegistry,
        address _memberRegistry,
        address _choreScheduler,
        address _taskManager,
        address _votingModule,
        address _collateralManager
    ) external initializer {
        __CommuneViewer_init(
            _communeRegistry, _memberRegistry, _choreScheduler, _taskManager, _votingModule, _collateralManager
        );
    }

    /// @notice Create a new commune with initial chore schedules
    /// @param name The commune name
    /// @param collateralRequired Whether collateral is required
    /// @param collateralAmount The required collateral amount
    /// @param choreSchedules Initial chore schedules
    /// @param username Username for the creator (optional)
    /// @return communeId The ID of the created commune
    function createCommune(
        string memory name,
        bool collateralRequired,
        uint256 collateralAmount,
        ChoreSchedule[] memory choreSchedules,
        string memory username
    ) external returns (uint256 communeId) {
        // Create the commune
        communeId = communeRegistry().createCommune(name, msg.sender, collateralRequired, collateralAmount);

        // Add chore schedules if provided
        if (choreSchedules.length > 0) {
            choreScheduler().addChores(communeId, choreSchedules);
        }

        // Deposit collateral if required (creator must also deposit)
        uint256 depositedCollateral = 0;
        if (collateralRequired) {
            depositedCollateral = collateralAmount;
            collateralManager().depositCollateral(msg.sender, collateralAmount);
        }

        // Register creator as first member
        memberRegistry().registerMember(communeId, msg.sender, depositedCollateral, username);

        return communeId;
    }

    /// @notice Join a commune with a valid invite
    /// @param communeId The commune ID
    /// @param nonce The invite nonce
    /// @param signature The creator's signature
    /// @param username Username for the joining member (optional)
    /// @dev MemberRegistry handles invite validation, nonce tracking, and registration
    function joinCommune(uint256 communeId, uint256 nonce, bytes memory signature, string memory username) external {
        // Get commune details
        Commune memory commune = communeRegistry().getCommune(communeId);

        // Validate invite signature with MemberRegistry
        memberRegistry().validateInvite(communeId, commune.creator, nonce, signature);

        // Check collateral requirement and deposit
        uint256 collateralAmount = 0;
        if (commune.collateralRequired) {
            collateralAmount = commune.collateralAmount;
            collateralManager().depositCollateral(msg.sender, collateralAmount);
        }

        // Register the member via MemberRegistry (which marks nonce as used)
        memberRegistry().joinCommune(communeId, msg.sender, nonce, collateralAmount, username);
    }

    /// @notice Add chore schedules to a commune
    /// @param communeId The commune ID
    /// @param choreSchedules Array of chore schedules to add
    /// @dev Caller must be a member of the commune
    function addChores(uint256 communeId, ChoreSchedule[] memory choreSchedules) external onlyMember(communeId) {
        choreScheduler().addChores(communeId, choreSchedules);
    }

    /// @notice Remove a chore schedule from a commune
    /// @param communeId The commune ID
    /// @param choreId The chore ID to remove
    /// @dev Caller must be a member of the commune
    function removeChore(uint256 communeId, uint256 choreId) external onlyMember(communeId) {
        choreScheduler().removeChore(communeId, choreId);
    }

    /// @notice Mark a chore as complete
    /// @param communeId The commune ID
    /// @param choreId The chore ID
    /// @param period The period number to mark complete
    /// @dev Caller must be a member of the commune
    function markChoreComplete(uint256 communeId, uint256 choreId, uint256 period) external onlyMember(communeId) {
        choreScheduler().markChoreComplete(communeId, choreId, period);
    }

    /// @notice Create a task with direct assignment
    /// @param communeId The commune ID
    /// @param budget The task budget (0 is valid)
    /// @param description Task description
    /// @param dueDate Due date
    /// @param assignedTo The member to assign
    /// @return taskId The created task ID
    /// @dev Both caller and assignee must be members of the commune
    function createTask(
        uint256 communeId,
        uint256 budget,
        string memory description,
        uint256 dueDate,
        address assignedTo
    ) external onlyMembers(communeId, assignedTo) returns (uint256 taskId) {
        return taskManager().createTask(communeId, budget, description, dueDate, assignedTo);
    }

    /// @notice Mark a task as done
    /// @param communeId The commune ID
    /// @param taskId The task ID
    /// @dev Caller must be a member of the commune
    function markTaskDone(uint256 communeId, uint256 taskId) external onlyMember(communeId) {
        taskManager().markTaskDone(taskId);
    }

    /// @notice Dispute a task
    /// @param communeId The commune ID
    /// @param taskId The task ID
    /// @param newAssignee Proposed new assignee
    /// @return disputeId The created dispute ID
    /// @dev Both caller and new assignee must be members of the commune
    function disputeTask(uint256 communeId, uint256 taskId, address newAssignee)
        external
        onlyMembers(communeId, newAssignee)
        returns (uint256 disputeId)
    {
        // Create dispute
        disputeId = votingModule().createDispute(taskId, newAssignee);

        // Mark task as disputed
        taskManager().markTaskDisputed(taskId, disputeId);

        return disputeId;
    }

    /// @notice Vote on a task dispute
    /// @param communeId The commune ID
    /// @param disputeId The dispute ID
    /// @param support True to support the dispute
    /// @dev Caller must be a member of the commune. Auto-resolves at 2/3 majority.
    function voteOnDispute(uint256 communeId, uint256 disputeId, bool support) external onlyMember(communeId) {
        // Get total member count for the commune
        uint256 totalMembers = memberRegistry().getMemberCount(communeId);

        // Cast vote
        votingModule().voteOnDispute(disputeId, msg.sender, support, totalMembers);

        // Check if dispute was resolved by this vote
        Dispute memory dispute = votingModule().getDispute(disputeId);

        if (dispute.status == DisputeStatus.Upheld) {
            // Get task details
            Task memory task = taskManager().getTaskStatus(dispute.taskId);
            address oldAssignee = task.assignedTo;
            address newAssignee = dispute.proposedNewAssignee;

            // Calculate slash amount (min of task budget and available collateral)
            uint256 availableCollateral = collateralManager().getCollateralBalance(oldAssignee);
            uint256 slashAmount = task.budget < availableCollateral ? task.budget : availableCollateral;

            // Slash collateral and transfer to new assignee if amount > 0
            if (slashAmount > 0) {
                collateralManager().slashCollateral(oldAssignee, slashAmount, newAssignee);
            }

            // Create a new task as a copy for the new assignee
            taskManager().createTask(task.communeId, task.budget, task.description, task.dueDate, newAssignee);
        }
    }

    /// @notice Set an assignee override for a specific chore period
    /// @param communeId The commune ID
    /// @param choreId The chore ID
    /// @param period The period number
    /// @param assignee The member to assign (address(0) to use rotation)
    /// @dev Caller must be a member of the commune
    function setChoreAssignee(uint256 communeId, uint256 choreId, uint256 period, address assignee)
        external
        onlyMember(communeId)
    {
        choreScheduler().setChoreAssignee(communeId, choreId, period, assignee);
    }

    /// @notice Remove a member from a commune
    /// @param communeId The commune ID
    /// @param memberAddress Address of the member to remove
    /// @dev Caller must be the creator of the commune. Withdraws all collateral. Chore assignments are automatically invalidated.
    function removeMember(uint256 communeId, address memberAddress) external {
        // Get commune details
        Commune memory commune = communeRegistry().getCommune(communeId);

        // Check if caller is the creator
        if (msg.sender != commune.creator) revert NotCreator();

        // Withdraw all collateral (if any exists)
        collateralManager().withdrawCollateral(memberAddress);

        // Remove member from registry
        // Note: Chore assignment overrides for this member are automatically invalidated
        // by getChoreAssignee() which validates the member is still in the commune
        memberRegistry().removeMember(communeId, memberAddress);
    }
}
