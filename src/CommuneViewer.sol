// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ChoreInstance} from "./interfaces/ICommuneViewer.sol";
import {Commune} from "./interfaces/ICommuneRegistry.sol";
import {ChoreSchedule} from "./interfaces/IChoreScheduler.sol";
import {Task} from "./interfaces/ITaskManager.sol";
import {Dispute} from "./interfaces/IVotingModule.sol";
import "./CommuneRegistry.sol";
import "./MemberRegistry.sol";
import "./ChoreScheduler.sol";
import "./TaskManager.sol";
import "./VotingModule.sol";
import "./CollateralManager.sol";

/// @title CommuneViewer
/// @notice Provides comprehensive view functions for querying commune data
/// @dev Separated from CommuneOS to keep main contract focused on state changes
abstract contract CommuneViewer is Initializable {
    /// @custom:storage-location erc7201:commune.storage.CommuneViewer
    struct CommuneViewerStorage {
        CommuneRegistry communeRegistry;
        MemberRegistry memberRegistry;
        ChoreScheduler choreScheduler;
        TaskManager taskManager;
        VotingModule votingModule;
        CollateralManager collateralManager;
    }

    // keccak256(abi.encode(uint256(keccak256("commune.storage.CommuneViewer")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant CommuneViewerStorageLocation =
        0x7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a00;

    function _getCommuneViewerStorage() private pure returns (CommuneViewerStorage storage $) {
        assembly {
            $.slot := CommuneViewerStorageLocation
        }
    }

    /// @notice Returns the CommuneRegistry contract
    function communeRegistry() public view virtual returns (CommuneRegistry) {
        CommuneViewerStorage storage $ = _getCommuneViewerStorage();
        return $.communeRegistry;
    }

    /// @notice Returns the MemberRegistry contract
    function memberRegistry() public view virtual returns (MemberRegistry) {
        CommuneViewerStorage storage $ = _getCommuneViewerStorage();
        return $.memberRegistry;
    }

    /// @notice Returns the ChoreScheduler contract
    function choreScheduler() public view virtual returns (ChoreScheduler) {
        CommuneViewerStorage storage $ = _getCommuneViewerStorage();
        return $.choreScheduler;
    }

    /// @notice Returns the TaskManager contract
    function taskManager() public view virtual returns (TaskManager) {
        CommuneViewerStorage storage $ = _getCommuneViewerStorage();
        return $.taskManager;
    }

    /// @notice Returns the VotingModule contract
    function votingModule() public view virtual returns (VotingModule) {
        CommuneViewerStorage storage $ = _getCommuneViewerStorage();
        return $.votingModule;
    }

    /// @notice Returns the CollateralManager contract
    function collateralManager() public view virtual returns (CollateralManager) {
        CommuneViewerStorage storage $ = _getCommuneViewerStorage();
        return $.collateralManager;
    }

    /// @notice Initializes the CommuneViewer with module addresses
    /// @param _communeRegistry Address of the CommuneRegistry
    /// @param _memberRegistry Address of the MemberRegistry
    /// @param _choreScheduler Address of the ChoreScheduler
    /// @param _taskManager Address of the TaskManager
    /// @param _votingModule Address of the VotingModule
    /// @param _collateralManager Address of the CollateralManager
    function __CommuneViewer_init(
        address _communeRegistry,
        address _memberRegistry,
        address _choreScheduler,
        address _taskManager,
        address _votingModule,
        address _collateralManager
    ) internal onlyInitializing {
        CommuneViewerStorage storage $ = _getCommuneViewerStorage();
        $.communeRegistry = CommuneRegistry(_communeRegistry);
        $.memberRegistry = MemberRegistry(_memberRegistry);
        $.choreScheduler = ChoreScheduler(_choreScheduler);
        $.taskManager = TaskManager(_taskManager);
        $.votingModule = VotingModule(_votingModule);
        $.collateralManager = CollateralManager(_collateralManager);
    }

    /// @notice Get commune statistics
    /// @param communeId The commune ID
    /// @return commune The commune data
    /// @return memberCount Number of members
    /// @return choreCount Number of chore schedules
    /// @return taskCount Number of tasks
    function getCommuneStatistics(uint256 communeId)
        external
        view
        returns (Commune memory commune, uint256 memberCount, uint256 choreCount, uint256 taskCount)
    {
        commune = communeRegistry().getCommune(communeId);
        memberCount = memberRegistry().getMemberCount(communeId);
        choreCount = choreScheduler().getChoreSchedules(communeId).length;
        taskCount = taskManager().getCommuneTasks(communeId).length;

        return (commune, memberCount, choreCount, taskCount);
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
        return choreScheduler().getCurrentChores(communeId);
    }

    /// @notice Get all members of a commune
    /// @param communeId The commune ID
    /// @return address[] Array of member addresses
    function getCommuneMembers(uint256 communeId) external view returns (address[] memory) {
        return memberRegistry().getCommuneMembers(communeId);
    }

    /// @notice Get all tasks for a commune
    /// @param communeId The commune ID
    /// @return Task[] Array of tasks
    function getCommuneTasks(uint256 communeId) external view returns (Task[] memory) {
        return taskManager().getCommuneTasks(communeId);
    }

    /// @notice Get member's collateral balance
    /// @param member The member address
    /// @return uint256 Collateral balance
    function getCollateralBalance(address member) external view returns (uint256) {
        return collateralManager().getCollateralBalance(member);
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
        communeId = memberRegistry().memberCommuneId(user);
        require(communeId != 0, "User is not a member of any commune");

        // Get commune basic data
        communeData = communeRegistry().getCommune(communeId);

        // Get all members
        members = memberRegistry().getCommuneMembers(communeId);

        // Get collateral balance and username for each member
        memberCollaterals = new uint256[](members.length);
        memberUsernames = new string[](members.length);
        for (uint256 i = 0; i < members.length; i++) {
            memberCollaterals[i] = collateralManager().getCollateralBalance(members[i]);
            memberUsernames[i] = memberRegistry().memberUsername(members[i]);
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
        communeId = memberRegistry().memberCommuneId(user);
        require(communeId != 0, "User is not a member of any commune");

        ChoreSchedule[] memory schedules = choreScheduler().getChoreSchedules(communeId);
        address[] memory members = memberRegistry().getCommuneMembers(communeId);

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
                choreScheduler().getChoreAssigneeForPeriod(communeId, schedule.id, period, members, memberRegistry());

            instances[count++] = ChoreInstance({
                scheduleId: schedule.id,
                title: schedule.title,
                frequency: schedule.frequency,
                periodNumber: period,
                periodStart: instanceStart,
                periodEnd: instanceStart + schedule.frequency,
                assignedTo: assignee,
                assignedToUsername: memberRegistry().memberUsername(assignee),
                completed: choreScheduler().isChoreComplete(communeId, schedule.id, period)
            });

            instanceStart += schedule.frequency;
        }

        return count;
    }

    /// @notice Get tasks for a specific month, categorized by status for a user's commune
    /// @param user The user address to find commune for
    /// @param monthStart Unix timestamp of the start of the month
    /// @param monthEnd Unix timestamp of the end of the month (start of next month)
    /// @return communeId The commune ID the user belongs to
    /// @return doneTasks Tasks that have been completed (specified month only)
    /// @return pendingTasks Tasks not done and not disputed (specified month only)
    /// @return disputedTasks Tasks currently under dispute (specified month only)
    /// @return overdueTasks Tasks past due date and not done (specified month only)
    function getCommuneTasks(address user, uint256 monthStart, uint256 monthEnd)
        external
        view
        returns (
            uint256 communeId,
            Task[] memory doneTasks,
            Task[] memory pendingTasks,
            Task[] memory disputedTasks,
            Task[] memory overdueTasks
        )
    {
        // Get the commune this user belongs to
        communeId = memberRegistry().memberCommuneId(user);
        require(communeId != 0, "User is not a member of any commune");

        (doneTasks, pendingTasks, disputedTasks, overdueTasks) = _getMonthTasks(communeId, monthStart, monthEnd);
    }

    /// @notice Get tasks for specified month only, categorized by status
    function _getMonthTasks(uint256 communeId, uint256 monthStart, uint256 monthEnd)
        internal
        view
        returns (
            Task[] memory doneTasks,
            Task[] memory pendingTasks,
            Task[] memory disputedTasks,
            Task[] memory overdueTasks
        )
    {
        Task[] memory allTasks = taskManager().getCommuneTasks(communeId);

        // Allocate arrays with max size (will have empty slots at end)
        doneTasks = new Task[](allTasks.length);
        pendingTasks = new Task[](allTasks.length);
        disputedTasks = new Task[](allTasks.length);
        overdueTasks = new Task[](allTasks.length);

        uint256[4] memory indices; // [done, pending, disputed, overdue]

        for (uint256 i = 0; i < allTasks.length; i++) {
            Task memory task = allTasks[i];

            // Only include tasks with due date in specified month
            if (task.dueDate < monthStart || task.dueDate >= monthEnd) {
                continue;
            }

            if (taskManager().isTaskDone(task.id)) {
                doneTasks[indices[0]++] = task;
            } else if (task.disputed) {
                disputedTasks[indices[2]++] = task;
            } else if (block.timestamp > task.dueDate) {
                overdueTasks[indices[3]++] = task;
            } else {
                pendingTasks[indices[1]++] = task;
            }
        }

        return (doneTasks, pendingTasks, disputedTasks, overdueTasks);
    }

    /// @notice Get all disputes for a commune's tasks
    /// @param communeId The commune ID
    /// @return disputes Array of disputes related to commune tasks
    function getCommuneDisputes(uint256 communeId) external view returns (Dispute[] memory disputes) {
        Task[] memory tasks = taskManager().getCommuneTasks(communeId);

        // Count disputed tasks
        uint256 disputeCount = 0;
        for (uint256 i = 0; i < tasks.length; i++) {
            if (tasks[i].disputed) {
                disputeCount++;
            }
        }

        // Collect disputes
        disputes = new Dispute[](disputeCount);
        uint256 index = 0;

        // Try to get dispute for each task ID
        for (uint256 i = 0; i < tasks.length; i++) {
            if (tasks[i].disputed && index < disputeCount) {
                // Search for the dispute by trying sequential IDs
                // This is a workaround since we don't have task->dispute mapping
                for (uint256 disputeId = 1; disputeId <= 1000; disputeId++) {
                    try votingModule().getDispute(disputeId) returns (Dispute memory dispute) {
                        if (dispute.taskId == tasks[i].id) {
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
        address[] memory members = memberRegistry().getCommuneMembers(communeId);

        // Count voters
        uint256 voterCount = 0;
        for (uint256 i = 0; i < members.length; i++) {
            if (votingModule().hasVotedOnDispute(disputeId, members[i])) {
                voterCount++;
            }
        }

        // Collect voters
        voters = new address[](voterCount);
        uint256 index = 0;
        for (uint256 i = 0; i < members.length; i++) {
            if (votingModule().hasVotedOnDispute(disputeId, members[i])) {
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
            usernames[i] = memberRegistry().memberUsername(addresses[i]);
        }
        return usernames;
    }
}
