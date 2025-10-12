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
        if (!memberRegistry.isMember(communeId, msg.sender)) revert NotAMember();
        _;
    }

    /// @notice Modifier to check if both caller and another address are members
    /// @param communeId The commune ID to check membership for
    /// @param otherAddress The other address to check
    modifier onlyMembers(uint256 communeId, address otherAddress) {
        address[] memory addresses = new address[](2);
        addresses[0] = msg.sender;
        addresses[1] = otherAddress;
        bool[] memory results = memberRegistry.areMembers(communeId, addresses);
        if (!results[0] || !results[1]) revert NotAMember();
        _;
    }

    /// @notice Initializes CommuneOS with all module contracts
    /// @param collateralToken Address of ERC20 token for collateral
    /// @dev Creates all module contracts in constructor for atomic deployment
    constructor(address collateralToken) {
        communeRegistry = new CommuneRegistry();
        memberRegistry = new MemberRegistry();
        choreScheduler = new ChoreScheduler();
        expenseManager = new ExpenseManager();
        votingModule = new VotingModule();
        collateralManager = new CollateralManager(collateralToken);
    }

    /// @notice Create a new commune with initial chore schedules
    /// @param name The commune name
    /// @param collateralRequired Whether collateral is required
    /// @param collateralAmount The required collateral amount
    /// @param choreSchedules Initial chore schedules
    /// @return communeId The ID of the created commune
    function createCommune(
        string memory name,
        bool collateralRequired,
        uint256 collateralAmount,
        ChoreSchedule[] memory choreSchedules
    ) external returns (uint256 communeId) {
        // Create the commune
        communeId = communeRegistry.createCommune(name, msg.sender, collateralRequired, collateralAmount);

        // Add chore schedules if provided
        if (choreSchedules.length > 0) {
            choreScheduler.addChores(communeId, choreSchedules);
        }

        // Deposit collateral if required (creator must also deposit)
        uint256 depositedCollateral = 0;
        if (collateralRequired) {
            depositedCollateral = collateralAmount;
            collateralManager.depositCollateral(msg.sender, collateralAmount);
        }

        // Register creator as first member
        memberRegistry.registerMember(communeId, msg.sender, depositedCollateral);

        return communeId;
    }

    /// @notice Join a commune with a valid invite
    /// @param communeId The commune ID
    /// @param nonce The invite nonce
    /// @param signature The creator's signature
    /// @dev MemberRegistry handles invite validation, nonce tracking, and registration
    function joinCommune(uint256 communeId, uint256 nonce, bytes memory signature) external {
        // Get commune details
        Commune memory commune = communeRegistry.getCommune(communeId);

        // Validate invite signature with MemberRegistry
        memberRegistry.validateInvite(communeId, commune.creator, nonce, signature);

        // Check collateral requirement and deposit
        uint256 collateralAmount = 0;
        if (commune.collateralRequired) {
            collateralAmount = commune.collateralAmount;
            collateralManager.depositCollateral(msg.sender, collateralAmount);
        }

        // Register the member via MemberRegistry (which marks nonce as used)
        memberRegistry.joinCommune(communeId, msg.sender, nonce, collateralAmount);
    }

    /// @notice Add chore schedules to a commune
    /// @param communeId The commune ID
    /// @param choreSchedules Array of chore schedules to add
    /// @dev Caller must be a member of the commune
    function addChores(uint256 communeId, ChoreSchedule[] memory choreSchedules) external onlyMember(communeId) {
        choreScheduler.addChores(communeId, choreSchedules);
    }

    /// @notice Mark a chore as complete
    /// @param communeId The commune ID
    /// @param choreId The chore ID
    /// @dev Caller must be a member of the commune
    function markChoreComplete(uint256 communeId, uint256 choreId) external onlyMember(communeId) {
        choreScheduler.markChoreComplete(communeId, choreId);
    }

    /// @notice Create an expense with direct assignment
    /// @param communeId The commune ID
    /// @param amount The expense amount
    /// @param description Expense description
    /// @param dueDate Due date
    /// @param assignedTo The member to assign
    /// @return expenseId The created expense ID
    /// @dev Both caller and assignee must be members of the commune
    function createExpense(
        uint256 communeId,
        uint256 amount,
        string memory description,
        uint256 dueDate,
        address assignedTo
    ) external onlyMembers(communeId, assignedTo) returns (uint256 expenseId) {
        return expenseManager.createExpense(communeId, amount, description, dueDate, assignedTo);
    }

    /// @notice Mark an expense as paid
    /// @param communeId The commune ID
    /// @param expenseId The expense ID
    /// @dev Caller must be a member of the commune
    function markExpensePaid(uint256 communeId, uint256 expenseId) external onlyMember(communeId) {
        expenseManager.markExpensePaid(expenseId);
    }

    /// @notice Dispute an expense
    /// @param communeId The commune ID
    /// @param expenseId The expense ID
    /// @param newAssignee Proposed new assignee
    /// @return disputeId The created dispute ID
    /// @dev Both caller and new assignee must be members of the commune
    function disputeExpense(uint256 communeId, uint256 expenseId, address newAssignee)
        external
        onlyMembers(communeId, newAssignee)
        returns (uint256 disputeId)
    {
        // Create dispute
        disputeId = votingModule.createDispute(expenseId, newAssignee);

        // Mark expense as disputed
        expenseManager.markExpenseDisputed(expenseId, disputeId);

        return disputeId;
    }

    /// @notice Vote on an expense dispute
    /// @param communeId The commune ID
    /// @param disputeId The dispute ID
    /// @param support True to support the dispute
    /// @dev Caller must be a member of the commune. Auto-resolves at 2/3 majority.
    function voteOnDispute(uint256 communeId, uint256 disputeId, bool support) external onlyMember(communeId) {
        // Get total member count for the commune
        uint256 totalMembers = memberRegistry.getMemberCount(communeId);

        // Cast vote
        votingModule.voteOnDispute(disputeId, msg.sender, support, totalMembers);

        // Check if dispute was resolved by this vote
        Dispute memory dispute = votingModule.getDispute(disputeId);

        if (dispute.status == DisputeStatus.Upheld) {
            // Get expense details
            Expense memory expense = expenseManager.getExpenseStatus(dispute.expenseId);
            address oldAssignee = expense.assignedTo;
            address newAssignee = dispute.proposedNewAssignee;

            // Calculate slash amount (min of expense amount and available collateral)
            uint256 availableCollateral = collateralManager.getCollateralBalance(oldAssignee);
            uint256 slashAmount = expense.amount < availableCollateral ? expense.amount : availableCollateral;

            // Slash collateral and transfer to new assignee if amount > 0
            if (slashAmount > 0) {
                collateralManager.slashCollateral(oldAssignee, slashAmount, newAssignee);
            }

            // Create a new expense as a copy for the new assignee
            expenseManager.createExpense(
                expense.communeId, expense.amount, expense.description, expense.dueDate, newAssignee
            );
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
        choreScheduler.setChoreAssignee(communeId, choreId, period, assignee);
    }

    /// @notice Remove a member from a commune
    /// @param communeId The commune ID
    /// @param memberAddress Address of the member to remove
    /// @dev Caller must be a member of the commune. Withdraws all collateral and clears assignments.
    function removeMember(uint256 communeId, address memberAddress) external onlyMember(communeId) {
        // Withdraw all collateral (if any exists)
        collateralManager.withdrawCollateral(memberAddress);

        // Clear any chore assignments for this member
        choreScheduler.clearMemberAssignments(communeId, memberAddress);

        // Remove member from registry
        memberRegistry.removeMember(communeId, memberAddress);
    }
}
