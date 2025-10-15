// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ChoreInstance} from "./interfaces/ICommuneViewer.sol";
import {Commune} from "./interfaces/ICommuneRegistry.sol";
import {ChoreSchedule} from "./interfaces/IChoreScheduler.sol";
import {Expense} from "./interfaces/IExpenseManager.sol";
import {Dispute} from "./interfaces/IVotingModule.sol";
import "./CommuneRegistry.sol";
import "./MemberRegistry.sol";
import "./ChoreScheduler.sol";
import "./ExpenseManager.sol";
import "./VotingModule.sol";
import "./CollateralManager.sol";

/// @title CommuneViewer
/// @notice Provides comprehensive view functions for querying commune data
/// @dev Separated from CommuneOS to keep main contract focused on state changes
abstract contract CommuneViewer {
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

    /// @notice Get basic commune info and members with their collaterals for a user
    /// @param user The user address to find commune for
    /// @return communeId The commune ID the user belongs to
    /// @return communeData The commune basic information
    /// @return members Array of all member addresses
    /// @return memberCollaterals Collateral balance for each member (parallel to members array)
    /// @return memberUsernames Username for each member (parallel to members array)
    function getCommuneBasicInfo(address user)
        external
        view
        returns (
            uint256 communeId,
            Commune memory communeData,
            address[] memory members,
            uint256[] memory memberCollaterals,
            string[] memory memberUsernames
        )
    {
        // Get the commune this user belongs to
        communeId = memberRegistry.memberCommuneId(user);
        require(communeId != 0, "User is not a member of any commune");

        // Get commune basic data
        communeData = communeRegistry.getCommune(communeId);

        // Get all members
        members = memberRegistry.getCommuneMembers(communeId);

        // Get collateral balance and username for each member
        memberCollaterals = new uint256[](members.length);
        memberUsernames = new string[](members.length);
        for (uint256 i = 0; i < members.length; i++) {
            memberCollaterals[i] = collateralManager.getCollateralBalance(members[i]);
            memberUsernames[i] = memberRegistry.memberUsername(members[i]);
        }
    }

    /// @notice Get all chore instances for a date range with completion status
    /// @param user The user address to find commune for
    /// @param startDate Unix timestamp for the start of the period
    /// @param endDate Unix timestamp for the end of the period
    /// @return communeId The commune ID the user belongs to
    /// @return instances Array of all chore instances in the date range
    function getCommuneChores(address user, uint256 startDate, uint256 endDate)
        external
        view
        returns (uint256 communeId, ChoreInstance[] memory instances)
    {
        communeId = memberRegistry.memberCommuneId(user);
        require(communeId != 0, "User is not a member of any commune");

        ChoreSchedule[] memory schedules = choreScheduler.getChoreSchedules(communeId);
        address[] memory members = memberRegistry.getCommuneMembers(communeId);

        // Calculate max possible instances: +1 to cover both start and end dates inclusively
        // This is just an upper bound estimate; the actual array is trimmed to size later
        uint256 daysInRange = (endDate - startDate) / 1 days + 1;
        ChoreInstance[] memory tempInstances = new ChoreInstance[](schedules.length * daysInRange);
        uint256 count = 0;

        for (uint256 i = 0; i < schedules.length; i++) {
            count = _generateChoreInstances(communeId, schedules[i], members, startDate, endDate, tempInstances, count);
        }

        // Trim to actual size
        instances = new ChoreInstance[](count);
        for (uint256 i = 0; i < count; i++) {
            instances[i] = tempInstances[i];
        }
    }

    /// @notice Helper to generate chore instances for a single schedule
    function _generateChoreInstances(
        uint256 communeId,
        ChoreSchedule memory schedule,
        address[] memory members,
        uint256 startDate,
        uint256 endDate,
        ChoreInstance[] memory instances,
        uint256 startIndex
    ) private view returns (uint256) {
        if (schedule.startTime >= endDate) return startIndex;

        uint256 instanceStart = schedule.startTime;
        // If schedule started before the requested range, fast-forward to the first instance within range
        // by calculating how many complete periods have elapsed and adding them to startTime
        if (instanceStart < startDate) {
            instanceStart =
                schedule.startTime + ((startDate - schedule.startTime) / schedule.frequency) * schedule.frequency;
        }

        uint256 count = startIndex;
        while (instanceStart < endDate) {
            uint256 period = (instanceStart - schedule.startTime) / schedule.frequency;
            address assignee =
                choreScheduler.getChoreAssigneeForPeriod(communeId, schedule.id, period, members, memberRegistry);

            instances[count++] = ChoreInstance({
                scheduleId: schedule.id,
                title: schedule.title,
                frequency: schedule.frequency,
                periodNumber: period,
                periodStart: instanceStart,
                periodEnd: instanceStart + schedule.frequency,
                assignedTo: assignee,
                assignedToUsername: memberRegistry.memberUsername(assignee),
                completed: choreScheduler.isChoreComplete(communeId, schedule.id, period)
            });

            instanceStart += schedule.frequency;
        }

        return count;
    }

    /// @notice Get expenses for a specific month, categorized by status for a user's commune
    /// @param user The user address to find commune for
    /// @param monthStart Unix timestamp of the start of the month
    /// @param monthEnd Unix timestamp of the end of the month (start of next month)
    /// @return communeId The commune ID the user belongs to
    /// @return paidExpenses Expenses that have been paid (specified month only)
    /// @return pendingExpenses Expenses not paid and not disputed (specified month only)
    /// @return disputedExpenses Expenses currently under dispute (specified month only)
    /// @return overdueExpenses Expenses past due date and unpaid (specified month only)
    function getCommuneExpenses(address user, uint256 monthStart, uint256 monthEnd)
        external
        view
        returns (
            uint256 communeId,
            Expense[] memory paidExpenses,
            Expense[] memory pendingExpenses,
            Expense[] memory disputedExpenses,
            Expense[] memory overdueExpenses
        )
    {
        // Get the commune this user belongs to
        communeId = memberRegistry.memberCommuneId(user);
        require(communeId != 0, "User is not a member of any commune");

        (paidExpenses, pendingExpenses, disputedExpenses, overdueExpenses) =
            _getMonthExpenses(communeId, monthStart, monthEnd);
    }

    /// @notice Get expenses for specified month only, categorized by status
    function _getMonthExpenses(uint256 communeId, uint256 monthStart, uint256 monthEnd)
        internal
        view
        returns (
            Expense[] memory paidExpenses,
            Expense[] memory pendingExpenses,
            Expense[] memory disputedExpenses,
            Expense[] memory overdueExpenses
        )
    {
        Expense[] memory allExpenses = expenseManager.getCommuneExpenses(communeId);

        // Allocate arrays with max size (will have empty slots at end)
        paidExpenses = new Expense[](allExpenses.length);
        pendingExpenses = new Expense[](allExpenses.length);
        disputedExpenses = new Expense[](allExpenses.length);
        overdueExpenses = new Expense[](allExpenses.length);

        uint256[4] memory indices; // [paid, pending, disputed, overdue]

        for (uint256 i = 0; i < allExpenses.length; i++) {
            Expense memory expense = allExpenses[i];

            // Only include expenses with due date in specified month
            if (expense.dueDate < monthStart || expense.dueDate >= monthEnd) {
                continue;
            }

            if (expenseManager.isExpensePaid(expense.id)) {
                paidExpenses[indices[0]++] = expense;
            } else if (expense.disputed) {
                disputedExpenses[indices[2]++] = expense;
            } else if (block.timestamp > expense.dueDate) {
                overdueExpenses[indices[3]++] = expense;
            } else {
                pendingExpenses[indices[1]++] = expense;
            }
        }

        return (paidExpenses, pendingExpenses, disputedExpenses, overdueExpenses);
    }

    /// @notice Get all disputes for a commune's expenses
    /// @param communeId The commune ID
    /// @return disputes Array of disputes related to commune expenses
    function getCommuneDisputes(uint256 communeId) external view returns (Dispute[] memory disputes) {
        Expense[] memory expenses = expenseManager.getCommuneExpenses(communeId);

        // Count disputed expenses
        uint256 disputeCount = 0;
        for (uint256 i = 0; i < expenses.length; i++) {
            if (expenses[i].disputed) {
                disputeCount++;
            }
        }

        // Collect disputes
        disputes = new Dispute[](disputeCount);
        uint256 index = 0;

        // Try to get dispute for each expense ID
        for (uint256 i = 0; i < expenses.length; i++) {
            if (expenses[i].disputed && index < disputeCount) {
                // Search for the dispute by trying sequential IDs
                // This is a workaround since we don't have expense->dispute mapping
                for (uint256 disputeId = 1; disputeId <= 1000; disputeId++) {
                    try votingModule.getDispute(disputeId) returns (Dispute memory dispute) {
                        if (dispute.expenseId == expenses[i].id) {
                            disputes[index] = dispute;
                            index++;
                            break;
                        }
                    } catch {
                        break;
                    }
                }
            }
        }

        return disputes;
    }

    /// @notice Get voters for a specific dispute
    /// @param disputeId The dispute ID
    /// @param communeId The commune ID to get member list
    /// @return voters Array of addresses that have voted on the dispute
    function getDisputeVoters(uint256 disputeId, uint256 communeId) external view returns (address[] memory voters) {
        address[] memory members = memberRegistry.getCommuneMembers(communeId);

        // Count voters
        uint256 voterCount = 0;
        for (uint256 i = 0; i < members.length; i++) {
            if (votingModule.hasVotedOnDispute(disputeId, members[i])) {
                voterCount++;
            }
        }

        // Collect voters
        voters = new address[](voterCount);
        uint256 index = 0;
        for (uint256 i = 0; i < members.length; i++) {
            if (votingModule.hasVotedOnDispute(disputeId, members[i])) {
                voters[index] = members[i];
                index++;
            }
        }

        return voters;
    }

    /// @notice Get usernames for an array of addresses
    /// @param addresses Array of addresses to get usernames for
    /// @return usernames Array of usernames (parallel to addresses array)
    function getUsernames(address[] memory addresses) external view returns (string[] memory usernames) {
        usernames = new string[](addresses.length);
        for (uint256 i = 0; i < addresses.length; i++) {
            usernames[i] = memberRegistry.memberUsername(addresses[i]);
        }
        return usernames;
    }
}
