// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/CommuneOS.sol";
import "../src/interfaces/ICommuneOS.sol";
import {Commune} from "../src/interfaces/ICommuneRegistry.sol";
import {Member} from "../src/interfaces/IMemberRegistry.sol";
import {ChoreSchedule} from "../src/interfaces/IChoreScheduler.sol";
import {Task} from "../src/interfaces/ITaskManager.sol";
import {Dispute, DisputeStatus} from "../src/interfaces/IVotingModule.sol";
import "./MockERC20.sol";

contract CommuneOSTest is Test {
    CommuneOS public communeOS;
    MockERC20 public token;

    uint256 public creatorPrivateKey = 0x1;
    uint256 public member1PrivateKey = 0x2;
    uint256 public member2PrivateKey = 0x3;
    uint256 public member3PrivateKey = 0x4;

    address public creator;
    address public member1;
    address public member2;
    address public member3;

    uint256 public constant COLLATERAL_AMOUNT = 3; // Small amount for testnet

    function setUp() public {
        token = new MockERC20();
        communeOS = new CommuneOS(address(token));

        creator = vm.addr(creatorPrivateKey);
        member1 = vm.addr(member1PrivateKey);
        member2 = vm.addr(member2PrivateKey);
        member3 = vm.addr(member3PrivateKey);

        // Mint tokens for testing (small amounts)
        token.mint(creator, 1000);
        token.mint(member1, 1000);
        token.mint(member2, 1000);
        token.mint(member3, 1000);
    }

    function testCreateCommune() public {
        vm.startPrank(creator);

        ChoreSchedule[] memory schedules = new ChoreSchedule[](2);
        schedules[0] = ChoreSchedule({
            id: 0, title: "Kitchen Cleaning", frequency: 1 days, startTime: block.timestamp, deleted: false
        });
        schedules[1] = ChoreSchedule({
            id: 1, title: "Bathroom Cleaning", frequency: 1 weeks, startTime: block.timestamp, deleted: false
        });

        // Approve collateral for creator
        token.approve(address(communeOS.collateralManager()), COLLATERAL_AMOUNT);
        uint256 communeId = communeOS.createCommune("Test Commune", true, COLLATERAL_AMOUNT, schedules, "creator");

        assertEq(communeId, 1); // Commune IDs start at 1

        (Commune memory commune, uint256 memberCount, uint256 choreCount, uint256 taskCount) =
            communeOS.getCommuneStatistics(communeId);

        assertEq(commune.name, "Test Commune");
        assertEq(commune.creator, creator);
        assertTrue(commune.collateralRequired);
        assertEq(commune.collateralAmount, COLLATERAL_AMOUNT);
        assertEq(memberCount, 1); // Creator is first member
        assertEq(choreCount, 2);
        assertEq(taskCount, 0);

        vm.stopPrank();
    }

    function testJoinCommuneWithCollateral() public {
        vm.startPrank(creator);

        ChoreSchedule[] memory schedules = new ChoreSchedule[](0);
        token.approve(address(communeOS.collateralManager()), COLLATERAL_AMOUNT);
        uint256 communeId = communeOS.createCommune("Test Commune", true, COLLATERAL_AMOUNT, schedules, "creator");

        // Generate invite signature
        uint256 nonce = 1;
        bytes32 messageHash = keccak256(abi.encodePacked(communeId, nonce));
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(creatorPrivateKey, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.stopPrank();

        // Member joins with collateral
        vm.startPrank(member1);
        token.approve(address(communeOS.collateralManager()), COLLATERAL_AMOUNT);
        communeOS.joinCommune(communeId, nonce, signature, "alice");

        assertEq(communeOS.collateralManager().getCollateralBalance(member1), COLLATERAL_AMOUNT);

        (, uint256 memberCount,,) = communeOS.getCommuneStatistics(communeId);
        assertEq(memberCount, 2);

        vm.stopPrank();
    }

    function testMarkChoreComplete() public {
        vm.startPrank(creator);

        ChoreSchedule[] memory schedules = new ChoreSchedule[](1);
        schedules[0] = ChoreSchedule({
            id: 0, title: "Kitchen Cleaning", frequency: 1 days, startTime: block.timestamp, deleted: false
        });

        uint256 communeId = communeOS.createCommune("Test Commune", false, 0, schedules, "creator");

        // Mark chore complete for period 0
        communeOS.markChoreComplete(communeId, 0, 0);

        // Check completion
        (ChoreSchedule[] memory returnedSchedules, uint256[] memory periods, bool[] memory completed) =
            communeOS.choreScheduler().getCurrentChores(communeId);

        assertEq(returnedSchedules.length, 1);
        assertEq(periods[0], 0); // Current period
        assertTrue(completed[0]); // Should be marked complete

        vm.stopPrank();
    }

    function testCreateTask() public {
        vm.startPrank(creator);

        ChoreSchedule[] memory schedules = new ChoreSchedule[](0);
        uint256 communeId = communeOS.createCommune("Test Commune", false, 0, schedules, "creator");

        // Generate invite and add member1
        uint256 nonce = 1;
        bytes32 messageHash = keccak256(abi.encodePacked(communeId, nonce));
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(creatorPrivateKey, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.stopPrank();

        vm.startPrank(member1);
        communeOS.joinCommune(communeId, nonce, signature, "alice");
        vm.stopPrank();

        vm.startPrank(creator);

        // Create task assigned to member1
        uint256 taskId = communeOS.createTask(communeId, 100 ether, "Groceries", block.timestamp + 7 days, member1);

        assertEq(taskId, 0);

        Task[] memory tasks = communeOS.taskManager().getCommuneTasks(communeId);
        assertEq(tasks.length, 1);
        assertEq(tasks[0].budget, 100 ether);
        assertEq(tasks[0].assignedTo, member1);
        assertFalse(tasks[0].done);

        vm.stopPrank();
    }

    function testMarkTaskDone() public {
        vm.startPrank(creator);

        ChoreSchedule[] memory schedules = new ChoreSchedule[](0);
        uint256 communeId = communeOS.createCommune("Test Commune", false, 0, schedules, "creator");

        // Generate invite and add member1
        uint256 nonce = 1;
        bytes32 messageHash = keccak256(abi.encodePacked(communeId, nonce));
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(creatorPrivateKey, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.stopPrank();

        vm.startPrank(member1);
        communeOS.joinCommune(communeId, nonce, signature, "bob");
        vm.stopPrank();

        vm.startPrank(creator);

        uint256 taskId = communeOS.createTask(communeId, 100 ether, "Groceries", block.timestamp + 7 days, member1);

        vm.stopPrank();

        // Member1 marks task as done
        vm.startPrank(member1);
        communeOS.markTaskDone(communeId, taskId);

        Task[] memory tasks = communeOS.taskManager().getCommuneTasks(communeId);
        assertTrue(tasks[0].done);

        vm.stopPrank();
    }

    function testDisputeTaskFlow() public {
        vm.startPrank(creator);

        ChoreSchedule[] memory schedules = new ChoreSchedule[](0);
        token.approve(address(communeOS.collateralManager()), COLLATERAL_AMOUNT);
        uint256 communeId = communeOS.createCommune("Test Commune", true, COLLATERAL_AMOUNT, schedules, "creator");

        vm.stopPrank();

        // Add members with collateral
        _addMemberWithCollateral(communeId, member1, 1);
        _addMemberWithCollateral(communeId, member2, 2);
        _addMemberWithCollateral(communeId, member3, 3);

        // Create task assigned to member1
        vm.startPrank(creator);
        uint256 taskId = communeOS.createTask(communeId, 0.5 ether, "Utilities", block.timestamp + 7 days, member1);
        vm.stopPrank();

        // Member2 disputes the task, proposing member3 as new assignee
        vm.startPrank(member2);
        uint256 disputeId = communeOS.disputeTask(communeId, taskId, member3);
        vm.stopPrank();

        // Members vote on dispute - need 2/3 majority (4 members total, so 2 votes needed)
        vm.prank(creator);
        communeOS.voteOnDispute(communeId, disputeId, true);

        // Check dispute is not yet resolved after 1 vote
        Dispute memory disputeAfterVote1 = communeOS.votingModule().getDispute(disputeId);
        assertEq(disputeAfterVote1.votesFor, 1);
        assertTrue(disputeAfterVote1.status == DisputeStatus.Pending);

        vm.prank(member2);
        communeOS.voteOnDispute(communeId, disputeId, true);

        // After 2nd vote, 2/3 majority is reached and dispute auto-resolves
        Dispute memory dispute = communeOS.votingModule().getDispute(disputeId);
        assertEq(dispute.taskId, taskId);
        assertEq(dispute.proposedNewAssignee, member3);
        assertEq(dispute.votesFor, 2); // creator and member2 voted for
        assertEq(dispute.votesAgainst, 0);
        assertTrue(dispute.status == DisputeStatus.Upheld); // Dispute was upheld

        // Verify task is marked as disputed
        Task[] memory tasks = communeOS.taskManager().getCommuneTasks(communeId);
        assertTrue(tasks[0].disputed);
    }

    function testChoreSchedulePeriodCalculation() public {
        vm.startPrank(creator);

        ChoreSchedule[] memory schedules = new ChoreSchedule[](1);
        schedules[0] =
            ChoreSchedule({id: 0, title: "Daily Chore", frequency: 1 days, startTime: block.timestamp, deleted: false});

        uint256 communeId = communeOS.createCommune("Test Commune", false, 0, schedules, "creator");

        // Check period 0
        (, uint256[] memory periods0,) = communeOS.choreScheduler().getCurrentChores(communeId);
        assertEq(periods0[0], 0);

        // Advance time by 1 day
        vm.warp(block.timestamp + 1 days);

        // Check period 1
        (, uint256[] memory periods1,) = communeOS.choreScheduler().getCurrentChores(communeId);
        assertEq(periods1[0], 1);

        // Advance time by 5 more days
        vm.warp(block.timestamp + 5 days);

        // Check period 6
        (, uint256[] memory periods6,) = communeOS.choreScheduler().getCurrentChores(communeId);
        assertEq(periods6[0], 6);

        vm.stopPrank();
    }

    function testCannotJoinWithInsufficientCollateral() public {
        vm.startPrank(creator);

        ChoreSchedule[] memory schedules = new ChoreSchedule[](0);
        token.approve(address(communeOS.collateralManager()), COLLATERAL_AMOUNT);
        uint256 communeId = communeOS.createCommune("Test Commune", true, COLLATERAL_AMOUNT, schedules, "creator");

        uint256 nonce = 1;
        bytes32 messageHash = keccak256(abi.encodePacked(communeId, nonce));
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(creatorPrivateKey, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.stopPrank();

        vm.startPrank(member1);

        // Try to join with insufficient collateral (only approve 1, need 3)
        token.approve(address(communeOS.collateralManager()), 1);
        vm.expectRevert(); // Will revert on transferFrom due to insufficient approval
        communeOS.joinCommune(communeId, nonce, signature, "alice");

        vm.stopPrank();
    }

    function testRemoveChore() public {
        vm.startPrank(creator);

        ChoreSchedule[] memory schedules = new ChoreSchedule[](3);
        schedules[0] = ChoreSchedule({
            id: 0, title: "Kitchen Cleaning", frequency: 1 days, startTime: block.timestamp, deleted: false
        });
        schedules[1] = ChoreSchedule({
            id: 1, title: "Bathroom Cleaning", frequency: 1 weeks, startTime: block.timestamp, deleted: false
        });
        schedules[2] =
            ChoreSchedule({id: 2, title: "Garden Work", frequency: 2 days, startTime: block.timestamp, deleted: false});

        token.approve(address(communeOS.collateralManager()), COLLATERAL_AMOUNT);
        uint256 communeId = communeOS.createCommune("Test Commune", true, COLLATERAL_AMOUNT, schedules, "creator");

        // Verify initial chore count
        ChoreSchedule[] memory initialChores = communeOS.choreScheduler().getChoreSchedules(communeId);
        assertEq(initialChores.length, 3);
        assertEq(initialChores[0].title, "Kitchen Cleaning");
        assertEq(initialChores[1].title, "Bathroom Cleaning");
        assertEq(initialChores[2].title, "Garden Work");

        // Remove chore at index 1 (Bathroom Cleaning)
        communeOS.removeChore(communeId, 1);

        // Verify chore count decreased (soft delete filters out deleted chores)
        ChoreSchedule[] memory choresAfterRemoval = communeOS.choreScheduler().getChoreSchedules(communeId);
        assertEq(choresAfterRemoval.length, 2);

        // Verify remaining chores - IDs are preserved with soft delete
        assertEq(choresAfterRemoval[0].title, "Kitchen Cleaning");
        assertEq(choresAfterRemoval[0].id, 0);
        assertEq(choresAfterRemoval[1].title, "Garden Work");
        assertEq(choresAfterRemoval[1].id, 2); // Original ID preserved

        // Remove another chore (removing index 0)
        communeOS.removeChore(communeId, 0);

        ChoreSchedule[] memory finalChores = communeOS.choreScheduler().getChoreSchedules(communeId);
        assertEq(finalChores.length, 1);
        assertEq(finalChores[0].title, "Garden Work");
        assertEq(finalChores[0].id, 2); // Original ID still preserved

        // Verify cannot operate on deleted chores
        vm.expectRevert();
        communeOS.markChoreComplete(communeId, 0, 0); // Chore 0 is deleted

        vm.expectRevert();
        communeOS.markChoreComplete(communeId, 1, 0); // Chore 1 is deleted

        vm.stopPrank();
    }

    function testRemoveMember() public {
        vm.startPrank(creator);

        ChoreSchedule[] memory schedules = new ChoreSchedule[](0);
        token.approve(address(communeOS.collateralManager()), COLLATERAL_AMOUNT);
        uint256 communeId = communeOS.createCommune("Test Commune", true, COLLATERAL_AMOUNT, schedules, "creator");

        vm.stopPrank();

        // Add member1 with collateral
        _addMemberWithCollateral(communeId, member1, 1);

        // Verify member1 is a member
        assertTrue(communeOS.memberRegistry().isMember(communeId, member1));
        assertEq(communeOS.collateralManager().getCollateralBalance(member1), COLLATERAL_AMOUNT);

        // Get initial token balance
        uint256 initialBalance = token.balanceOf(member1);

        // Remove member1
        vm.prank(creator);
        communeOS.removeMember(communeId, member1);

        // Verify member1 is no longer a member
        assertFalse(communeOS.memberRegistry().isMember(communeId, member1));

        // Verify collateral was returned
        assertEq(communeOS.collateralManager().getCollateralBalance(member1), 0);
        assertEq(token.balanceOf(member1), initialBalance + COLLATERAL_AMOUNT);

        // Verify member count decreased
        (, uint256 memberCount,,) = communeOS.getCommuneStatistics(communeId);
        assertEq(memberCount, 1); // Only creator remains
    }

    function testRemoveMemberWithoutCollateral() public {
        vm.startPrank(creator);

        ChoreSchedule[] memory schedules = new ChoreSchedule[](0);
        uint256 communeId = communeOS.createCommune("Test Commune", false, 0, schedules, "creator");

        // Generate invite and add member1
        uint256 nonce = 1;
        bytes32 messageHash = keccak256(abi.encodePacked(communeId, nonce));
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(creatorPrivateKey, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.stopPrank();

        vm.startPrank(member1);
        communeOS.joinCommune(communeId, nonce, signature, "member1");
        vm.stopPrank();

        // Verify member1 is a member
        assertTrue(communeOS.memberRegistry().isMember(communeId, member1));

        // Remove member1
        vm.prank(creator);
        communeOS.removeMember(communeId, member1);

        // Verify member1 is no longer a member
        assertFalse(communeOS.memberRegistry().isMember(communeId, member1));
    }

    function testCannotRemoveMemberIfNotCreator() public {
        vm.startPrank(creator);

        ChoreSchedule[] memory schedules = new ChoreSchedule[](0);
        uint256 communeId = communeOS.createCommune("Test Commune", false, 0, schedules, "creator");

        // Generate invite and add member1
        uint256 nonce = 1;
        bytes32 messageHash = keccak256(abi.encodePacked(communeId, nonce));
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(creatorPrivateKey, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.stopPrank();

        // member1 joins
        vm.prank(member1);
        communeOS.joinCommune(communeId, nonce, signature, "member1");

        // Generate another invite for member2
        nonce = 2;
        messageHash = keccak256(abi.encodePacked(communeId, nonce));
        ethSignedMessageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));
        (v, r, s) = vm.sign(creatorPrivateKey, ethSignedMessageHash);
        signature = abi.encodePacked(r, s, v);

        // member2 joins
        vm.prank(member2);
        communeOS.joinCommune(communeId, nonce, signature, "member2");

        // member1 tries to remove member2 (should fail, only creator can remove)
        vm.startPrank(member1);
        vm.expectRevert(ICommuneOS.NotCreator.selector);
        communeOS.removeMember(communeId, member2);
        vm.stopPrank();

        // Non-member tries to remove another address (should also fail with NotCreator)
        vm.startPrank(address(0x999));
        vm.expectRevert(ICommuneOS.NotCreator.selector);
        communeOS.removeMember(communeId, member2);
        vm.stopPrank();
    }

    function testRemoveMemberClearsChoreAssignments() public {
        vm.startPrank(creator);

        ChoreSchedule[] memory schedules = new ChoreSchedule[](1);
        schedules[0] = ChoreSchedule({
            id: 0, title: "Kitchen Cleaning", frequency: 1 days, startTime: block.timestamp, deleted: false
        });
        uint256 communeId = communeOS.createCommune("Test Commune", false, 0, schedules, "creator");

        // Generate invite and add member1
        uint256 nonce = 1;
        bytes32 messageHash = keccak256(abi.encodePacked(communeId, nonce));
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(creatorPrivateKey, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.stopPrank();

        vm.startPrank(member1);
        communeOS.joinCommune(communeId, nonce, signature, "member1");
        vm.stopPrank();

        // Assign chore to member1 for current period
        uint256 currentPeriod = communeOS.choreScheduler().getCurrentPeriod(communeId, 0);
        vm.prank(creator);
        communeOS.setChoreAssignee(communeId, 0, currentPeriod, member1);

        // Get members list for checking assignment
        address[] memory members = communeOS.memberRegistry().getCommuneMembers(communeId);
        address assignee = communeOS.choreScheduler()
            .getChoreAssigneeForPeriod(communeId, 0, currentPeriod, members, communeOS.memberRegistry());
        assertEq(assignee, member1);

        // Remove member1
        vm.prank(creator);
        communeOS.removeMember(communeId, member1);

        // Verify assignment was cleared (now uses rotation, should be creator)
        members = communeOS.memberRegistry().getCommuneMembers(communeId);
        assignee = communeOS.choreScheduler()
            .getChoreAssigneeForPeriod(communeId, 0, currentPeriod, members, communeOS.memberRegistry());
        assertEq(assignee, creator); // Should fall back to rotation
    }

    // Helper function to add members with collateral
    function _addMemberWithCollateral(uint256 communeId, address member, uint256 nonce) internal {
        bytes32 messageHash = keccak256(abi.encodePacked(communeId, nonce));
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(creatorPrivateKey, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.startPrank(member);
        token.approve(address(communeOS.collateralManager()), COLLATERAL_AMOUNT);
        communeOS.joinCommune(communeId, nonce, signature, "");
        vm.stopPrank();
    }
}
