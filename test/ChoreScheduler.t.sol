// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/CommuneOS.sol";
import {ChoreSchedule} from "../src/interfaces/IChoreScheduler.sol";
import "./MockERC20.sol";

contract ChoreSchedulerTest is Test {
    CommuneOS public communeOS;
    MockERC20 public token;
    ChoreScheduler public scheduler;

    uint256 creatorKey = 0x1;
    address creator;
    address member1;
    uint256 communeId;

    function setUp() public {
        token = new MockERC20();
        communeOS = new CommuneOS(address(token));
        scheduler = communeOS.choreScheduler();

        creator = vm.addr(creatorKey);
        member1 = address(0x11);

        vm.prank(creator);
        ChoreSchedule[] memory s = new ChoreSchedule[](0);
        communeId = communeOS.createCommune("Test", false, 0, s, "c");

        bytes32 mh = keccak256(abi.encodePacked(communeId, uint256(1)));
        bytes32 emh = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", mh));
        (uint8 v, bytes32 r, bytes32 ss) = vm.sign(creatorKey, emh);
        vm.prank(member1);
        communeOS.joinCommune(communeId, 1, abi.encodePacked(r, ss, v), "m1");
    }

    function testAddChores() public {
        ChoreSchedule[] memory s = new ChoreSchedule[](2);
        s[0] = ChoreSchedule(0, "Kitchen", 1 days, block.timestamp, false);
        s[1] = ChoreSchedule(0, "Bath", 1 weeks, block.timestamp, false);

        vm.prank(creator);
        communeOS.addChores(communeId, s);

        ChoreSchedule[] memory result = scheduler.getChoreSchedules(communeId);
        assertEq(result.length, 2);
        assertEq(result[0].title, "Kitchen");
        assertEq(result[1].title, "Bath");
    }

    function testRemoveChore() public {
        ChoreSchedule[] memory s = new ChoreSchedule[](2);
        s[0] = ChoreSchedule(0, "Kitchen", 1 days, block.timestamp, false);
        s[1] = ChoreSchedule(0, "Bath", 1 weeks, block.timestamp, false);

        vm.prank(creator);
        communeOS.addChores(communeId, s);

        vm.prank(creator);
        communeOS.removeChore(communeId, 0);

        assertEq(scheduler.getChoreSchedules(communeId).length, 1);
    }

    function testMarkChoreComplete() public {
        ChoreSchedule[] memory s = new ChoreSchedule[](1);
        s[0] = ChoreSchedule(0, "Kitchen", 1 days, block.timestamp, false);

        vm.prank(creator);
        communeOS.addChores(communeId, s);

        vm.prank(creator);
        communeOS.markChoreComplete(communeId, 0, 0);

        assertTrue(scheduler.isChoreComplete(communeId, 0, 0));
    }

    function testCannotCompleteDeletedChore() public {
        ChoreSchedule[] memory s = new ChoreSchedule[](1);
        s[0] = ChoreSchedule(0, "Kitchen", 1 days, block.timestamp, false);

        vm.prank(creator);
        communeOS.addChores(communeId, s);

        vm.prank(creator);
        communeOS.removeChore(communeId, 0);

        vm.prank(creator);
        vm.expectRevert();
        communeOS.markChoreComplete(communeId, 0, 0);
    }

    function testCannotCompleteTwice() public {
        ChoreSchedule[] memory s = new ChoreSchedule[](1);
        s[0] = ChoreSchedule(0, "Kitchen", 1 days, block.timestamp, false);

        vm.prank(creator);
        communeOS.addChores(communeId, s);

        vm.prank(creator);
        communeOS.markChoreComplete(communeId, 0, 0);

        vm.prank(creator);
        vm.expectRevert();
        communeOS.markChoreComplete(communeId, 0, 0);
    }

    function testPeriodCalculation() public {
        ChoreSchedule[] memory s = new ChoreSchedule[](1);
        s[0] = ChoreSchedule(0, "Daily", 1 days, block.timestamp, false);

        vm.prank(creator);
        communeOS.addChores(communeId, s);

        assertEq(scheduler.getCurrentPeriod(communeId, 0), 0);

        vm.warp(block.timestamp + 1 days);
        assertEq(scheduler.getCurrentPeriod(communeId, 0), 1);

        vm.warp(block.timestamp + 6 days);
        assertEq(scheduler.getCurrentPeriod(communeId, 0), 7);
    }

    function testSetChoreAssignee() public {
        ChoreSchedule[] memory s = new ChoreSchedule[](1);
        s[0] = ChoreSchedule(0, "Kitchen", 1 days, block.timestamp, false);

        vm.prank(creator);
        communeOS.addChores(communeId, s);

        vm.prank(creator);
        communeOS.setChoreAssignee(communeId, 0, 0, member1);

        address[] memory members = communeOS.memberRegistry().getCommuneMembers(communeId);
        address assignee = scheduler.getChoreAssigneeForPeriod(communeId, 0, 0, members, communeOS.memberRegistry());
        assertEq(assignee, member1);
    }

    function testRotationAssignment() public {
        ChoreSchedule[] memory s = new ChoreSchedule[](1);
        s[0] = ChoreSchedule(0, "Kitchen", 1 days, block.timestamp, false);

        vm.prank(creator);
        communeOS.addChores(communeId, s);

        // 2 members: creator and member1
        // choreId=0, period=0: idx = (0+0) % 2 = 0 -> creator
        // choreId=0, period=1: idx = (0+1) % 2 = 1 -> member1
        uint256 idx0 = scheduler.getAssignedMemberIndex(0, 0, 2);
        uint256 idx1 = scheduler.getAssignedMemberIndex(0, 1, 2);
        assertEq(idx0, 0);
        assertEq(idx1, 1);
    }

    function testGetCurrentChores() public {
        ChoreSchedule[] memory s = new ChoreSchedule[](2);
        s[0] = ChoreSchedule(0, "Kitchen", 1 days, block.timestamp, false);
        s[1] = ChoreSchedule(0, "Bath", 1 weeks, block.timestamp, false);

        vm.prank(creator);
        communeOS.addChores(communeId, s);

        (ChoreSchedule[] memory schedules, uint256[] memory periods, bool[] memory completed) =
            scheduler.getCurrentChores(communeId);

        assertEq(schedules.length, 2);
        assertEq(periods[0], 0);
        assertEq(periods[1], 0);
        assertFalse(completed[0]);
        assertFalse(completed[1]);
    }

    function testEmptyScheduleReverts() public {
        ChoreSchedule[] memory s = new ChoreSchedule[](0);
        vm.prank(creator);
        vm.expectRevert();
        communeOS.addChores(communeId, s);
    }

    function testInvalidFrequencyReverts() public {
        ChoreSchedule[] memory s = new ChoreSchedule[](1);
        s[0] = ChoreSchedule(0, "Bad", 0, block.timestamp, false);
        vm.prank(creator);
        vm.expectRevert();
        communeOS.addChores(communeId, s);
    }

    function testEmptyTitleReverts() public {
        ChoreSchedule[] memory s = new ChoreSchedule[](1);
        s[0] = ChoreSchedule(0, "", 1 days, block.timestamp, false);
        vm.prank(creator);
        vm.expectRevert();
        communeOS.addChores(communeId, s);
    }
}
