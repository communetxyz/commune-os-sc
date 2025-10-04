// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./Types.sol";
import "./IEvents.sol";
import "./CommuneRegistry.sol";
import "./MemberRegistry.sol";
import "./ChoreScheduler.sol";
import "./ExpenseManager.sol";
import "./VotingModule.sol";
import "./CollateralManager.sol";

/// @title CommuneOS
/// @notice Main contract integrating all commune management modules
/// @dev Deployed on Gnosis Chain for low gas fees
contract CommuneOS is IEvents {
    CommuneRegistry public communeRegistry;
    MemberRegistry public memberRegistry;
    ChoreScheduler public choreScheduler;
    ExpenseManager public expenseManager;
    VotingModule public votingModule;
    CollateralManager public collateralManager;

    constructor() {
        communeRegistry = new CommuneRegistry();
        memberRegistry = new MemberRegistry();
        choreScheduler = new ChoreScheduler();
        expenseManager = new ExpenseManager();
        votingModule = new VotingModule();
        collateralManager = new CollateralManager();
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

        // Initialize chore schedules if provided
        if (choreSchedules.length > 0) {
            choreScheduler.initializeChores(communeId, choreSchedules);
        }

        // Register creator as first member (no collateral required for creator)
        memberRegistry.registerMember(communeId, msg.sender, 0);

        return communeId;
    }

    /// @notice Join a commune with a valid invite
    /// @param communeId The commune ID
    /// @param nonce The invite nonce
    /// @param signature The creator's signature
    function joinCommune(uint256 communeId, uint256 nonce, bytes memory signature) external payable {
        // Validate the invite
        require(communeRegistry.validateInvite(communeId, nonce, signature), "CommuneOS: invalid invite");

        // Get commune details
        Commune memory commune = communeRegistry.getCommune(communeId);

        // Check collateral requirement
        if (commune.collateralRequired) {
            require(msg.value >= commune.collateralAmount, "CommuneOS: insufficient collateral");
            collateralManager.depositCollateral{value: msg.value}(msg.sender);
        }

        // Mark nonce as used
        communeRegistry.markNonceUsed(communeId, nonce);

        // Register the member
        memberRegistry.registerMember(communeId, msg.sender, msg.value);

        emit MemberJoined(msg.sender, communeId, msg.value, block.timestamp);
    }

    /// @notice Mark a chore as complete
    /// @param communeId The commune ID
    /// @param choreId The chore ID
    function markChoreComplete(uint256 communeId, uint256 choreId) external {
        // Verify member is part of commune
        require(memberRegistry.isMember(communeId, msg.sender), "CommuneOS: not a member");

        // Mark chore complete
        choreScheduler.markChoreComplete(communeId, choreId);
    }

    /// @notice Create an expense with direct assignment
    /// @param communeId The commune ID
    /// @param amount The expense amount
    /// @param description Expense description
    /// @param dueDate Due date
    /// @param assignedTo The member to assign
    /// @return expenseId The created expense ID
    function createExpense(
        uint256 communeId,
        uint256 amount,
        string memory description,
        uint256 dueDate,
        address assignedTo
    ) external returns (uint256 expenseId) {
        // Verify creator is a member
        require(memberRegistry.isMember(communeId, msg.sender), "CommuneOS: not a member");

        // Verify assignee is a member
        require(memberRegistry.isMember(communeId, assignedTo), "CommuneOS: assignee not a member");

        // Create expense
        return expenseManager.createExpense(communeId, amount, description, dueDate, assignedTo);
    }

    /// @notice Mark an expense as paid
    /// @param communeId The commune ID
    /// @param expenseId The expense ID
    function markExpensePaid(uint256 communeId, uint256 expenseId) external {
        // Verify member is part of commune
        require(memberRegistry.isMember(communeId, msg.sender), "CommuneOS: not a member");

        expenseManager.markExpensePaid(expenseId);
    }

    /// @notice Dispute an expense
    /// @param communeId The commune ID
    /// @param expenseId The expense ID
    /// @param newAssignee Proposed new assignee
    /// @return disputeId The created dispute ID
    function disputeExpense(uint256 communeId, uint256 expenseId, address newAssignee)
        external
        returns (uint256 disputeId)
    {
        // Verify member is part of commune
        require(memberRegistry.isMember(communeId, msg.sender), "CommuneOS: not a member");

        // Verify new assignee is a member
        require(memberRegistry.isMember(communeId, newAssignee), "CommuneOS: new assignee not a member");

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
    function voteOnDispute(uint256 communeId, uint256 disputeId, bool support) external {
        // Verify member is part of commune
        require(memberRegistry.isMember(communeId, msg.sender), "CommuneOS: not a member");

        votingModule.voteOnDispute(disputeId, msg.sender, support);
    }

    /// @notice Resolve a dispute and handle collateral slashing if upheld
    /// @param communeId The commune ID
    /// @param disputeId The dispute ID
    function resolveDispute(uint256 communeId, uint256 disputeId) external {
        // Get total member count
        uint256 totalMembers = memberRegistry.getMemberCount(communeId);

        // Resolve the dispute
        bool upheld = votingModule.resolveDispute(disputeId, totalMembers);

        if (upheld) {
            // Get dispute details
            Dispute memory dispute = votingModule.getDispute(disputeId);

            // Get expense details
            Expense memory expense = expenseManager.getExpenseStatus(dispute.expenseId);

            // Slash collateral from old assignee
            uint256 slashed =
                collateralManager.slashCollateral(expense.assignedTo, expense.amount, dispute.proposedNewAssignee);

            // Reassign expense to new assignee
            expenseManager.reassignExpense(dispute.expenseId, dispute.proposedNewAssignee);
        }
    }

    // View functions

    /// @notice Get commune statistics
    /// @param communeId The commune ID
    /// @return commune The commune data
    /// @return memberCount Number of members
    /// @return choreCount Number of chore schedules
    /// @return expenseCount Number of expenses
    function getCommuneStatistics(uint256 communeId)
        external
        view
        returns (Commune memory commune, uint256 memberCount, uint256 choreCount, uint256 expenseCount)
    {
        commune = communeRegistry.getCommune(communeId);
        memberCount = memberRegistry.getMemberCount(communeId);
        choreCount = choreScheduler.getChoreSchedules(communeId).length;
        expenseCount = expenseManager.getCommuneExpenses(communeId).length;

        return (commune, memberCount, choreCount, expenseCount);
    }

    /// @notice Get current chores for a commune
    /// @param communeId The commune ID
    /// @return schedules Array of schedules
    /// @return periods Current period for each chore
    /// @return completed Completion status for current period
    function getCurrentChores(uint256 communeId)
        external
        view
        returns (ChoreSchedule[] memory schedules, uint256[] memory periods, bool[] memory completed)
    {
        return choreScheduler.getCurrentChores(communeId);
    }

    /// @notice Get all members of a commune
    /// @param communeId The commune ID
    /// @return address[] Array of member addresses
    function getCommuneMembers(uint256 communeId) external view returns (address[] memory) {
        return memberRegistry.getCommuneMembers(communeId);
    }

    /// @notice Get all expenses for a commune
    /// @param communeId The commune ID
    /// @return Expense[] Array of expenses
    function getCommuneExpenses(uint256 communeId) external view returns (Expense[] memory) {
        return expenseManager.getCommuneExpenses(communeId);
    }

    /// @notice Get member's collateral balance
    /// @param member The member address
    /// @return uint256 Collateral balance
    function getCollateralBalance(address member) external view returns (uint256) {
        return collateralManager.getCollateralBalance(member);
    }
}
