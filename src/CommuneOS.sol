// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./interfaces/ICommuneOS.sol";
import "./CommuneRegistry.sol";
import "./MemberRegistry.sol";
import "./ChoreScheduler.sol";
import "./ExpenseManager.sol";
import "./VotingModule.sol";
import "./CollateralManager.sol";

/// @title CommuneOS
/// @notice Main contract integrating all commune management modules
/// @dev Deployed on Gnosis Chain for low gas fees. Coordinates all module interactions.
contract CommuneOS is ICommuneOS {
    /// @notice Registry for commune creation and invite validation
    CommuneRegistry public communeRegistry;

    /// @notice Registry for commune member management
    MemberRegistry public memberRegistry;

    /// @notice Scheduler for recurring chore management
    ChoreScheduler public choreScheduler;

    /// @notice Manager for expense tracking and assignment
    ExpenseManager public expenseManager;

    /// @notice Voting system for dispute resolution
    VotingModule public votingModule;

    /// @notice Manager for member collateral deposits and slashing
    CollateralManager public collateralManager;

    /// @notice Modifier to check if caller is a member of the commune
    /// @param communeId The commune ID to check membership for
    modifier onlyMember(uint256 communeId) {
        if (!memberRegistry.isMember(communeId, msg.sender)) revert NotAMember();
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

        // Initialize MemberRegistry with CommuneRegistry reference
        memberRegistry.setCommuneRegistry(address(communeRegistry));
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
        // Validate invite and get commune details from MemberRegistry
        Commune memory commune = memberRegistry.validateInvite(communeId, nonce, signature);

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
    ) external returns (uint256 expenseId) {
        // Verify both creator and assignee are members
        address[] memory addresses = new address[](2);
        addresses[0] = msg.sender;
        addresses[1] = assignedTo;
        bool[] memory results = memberRegistry.areMembers(communeId, addresses);

        if (!results[0]) revert NotAMember();
        if (!results[1]) revert AssigneeNotAMember();

        // Create expense
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
        returns (uint256 disputeId)
    {
        // Verify both disputer and new assignee are members
        address[] memory addresses = new address[](2);
        addresses[0] = msg.sender;
        addresses[1] = newAssignee;
        bool[] memory results = memberRegistry.areMembers(communeId, addresses);

        if (!results[0]) revert NotAMember();
        if (!results[1]) revert NotAMember();

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

        votingModule.voteOnDispute(disputeId, msg.sender, support, totalMembers);
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
}
