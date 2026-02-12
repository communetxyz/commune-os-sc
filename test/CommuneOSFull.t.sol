// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/CommuneOS.sol";
import {ChoreSchedule} from "../src/interfaces/IChoreScheduler.sol";
import {Commune} from "../src/interfaces/ICommuneRegistry.sol";
import {Task} from "../src/interfaces/ITaskManager.sol";
import {Dispute, DisputeStatus} from "../src/interfaces/IVotingModule.sol";
import {GuestPolicy} from "../src/interfaces/IGuestManager.sol";
import {Message} from "../src/interfaces/IMessageBoard.sol";
import {Expense} from "../src/interfaces/IExpenseManager.sol";
import "./MockERC20.sol";

/// @title Comprehensive CommuneOS Test Suite (Issue #37)
contract CommuneOSFullTest is Test {
    CommuneOS public communeOS;
    MockERC20 public token;

    uint256 creatorKey = 0x1;
    address creator;
    address member1;
    address member2;
    address member3;
    uint256 communeId;

    function setUp() public {
        token = new MockERC20();
        communeOS = new CommuneOS(address(token));
        creator = vm.addr(creatorKey);
        member1 = address(0x11);
        member2 = address(0x12);
        member3 = address(0x13);

        token.mint(creator, 1e18);
        token.mint(member1, 1e18);
        token.mint(member2, 1e18);
        token.mint(member3, 1e18);
    }

    function _createCommune(bool collateral, uint256 amount) internal returns (uint256) {
        vm.startPrank(creator);
        if (collateral) token.approve(address(communeOS.collateralManager()), amount);
        ChoreSchedule[] memory s = new ChoreSchedule[](0);
        uint256 id = communeOS.createCommune("Test", collateral, amount, s, "creator");
        vm.stopPrank();
        return id;
    }

    function _addMember(uint256 cid, address m, uint256 nonce) internal {
        bytes32 mh = keccak256(abi.encodePacked(cid, nonce));
        bytes32 emh = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", mh));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(creatorKey, emh);
        vm.prank(m);
        communeOS.joinCommune(cid, nonce, abi.encodePacked(r, s, v), "");
    }

    function _addMemberWithCollateral(uint256 cid, address m, uint256 nonce, uint256 amount) internal {
        bytes32 mh = keccak256(abi.encodePacked(cid, nonce));
        bytes32 emh = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", mh));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(creatorKey, emh);
        vm.startPrank(m);
        token.approve(address(communeOS.collateralManager()), amount);
        communeOS.joinCommune(cid, nonce, abi.encodePacked(r, s, v), "");
        vm.stopPrank();
    }

    // ============ Module Deployment ============

    function testAllModulesDeployed() public view {
        assertTrue(address(communeOS.communeRegistry()) != address(0));
        assertTrue(address(communeOS.memberRegistry()) != address(0));
        assertTrue(address(communeOS.choreScheduler()) != address(0));
        assertTrue(address(communeOS.taskManager()) != address(0));
        assertTrue(address(communeOS.votingModule()) != address(0));
        assertTrue(address(communeOS.collateralManager()) != address(0));
        assertTrue(address(communeOS.expenseManager()) != address(0));
        assertTrue(address(communeOS.guestManager()) != address(0));
        assertTrue(address(communeOS.messageBoard()) != address(0));
    }

    // ============ Commune Creation ============

    function testCreateCommuneNoCollateral() public {
        uint256 cid = _createCommune(false, 0);
        Commune memory c = communeOS.communeRegistry().getCommune(cid);
        assertEq(c.name, "Test");
        assertFalse(c.collateralRequired);
    }

    function testCreateCommuneWithCollateral() public {
        uint256 cid = _createCommune(true, 100);
        Commune memory c = communeOS.communeRegistry().getCommune(cid);
        assertTrue(c.collateralRequired);
        assertEq(c.collateralAmount, 100);
    }

    function testCreateCommuneWithChores() public {
        ChoreSchedule[] memory s = new ChoreSchedule[](1);
        s[0] = ChoreSchedule(0, "Clean", 1 days, block.timestamp, false);
        vm.prank(creator);
        uint256 cid = communeOS.createCommune("WithChores", false, 0, s, "c");
        assertEq(communeOS.choreScheduler().getChoreSchedules(cid).length, 1);
    }

    // ============ Membership ============

    function testJoinAndLeaveFlow() public {
        uint256 cid = _createCommune(false, 0);
        _addMember(cid, member1, 1);
        assertTrue(communeOS.memberRegistry().isMember(cid, member1));

        vm.prank(creator);
        communeOS.removeMember(cid, member1);
        assertFalse(communeOS.memberRegistry().isMember(cid, member1));
    }

    function testNonMemberCannotAct() public {
        uint256 cid = _createCommune(false, 0);
        _addMember(cid, member1, 1);

        // Non-member cannot create task
        vm.prank(address(0x99));
        vm.expectRevert();
        communeOS.createTask(cid, 0, "task", block.timestamp + 1 days, member1);
    }

    // ============ Full Dispute Flow ============

    function testFullDisputeWithSlashing() public {
        uint256 cid = _createCommune(true, 100);
        _addMemberWithCollateral(cid, member1, 1, 100);
        _addMemberWithCollateral(cid, member2, 2, 100);
        _addMemberWithCollateral(cid, member3, 3, 100);

        vm.prank(creator);
        uint256 taskId = communeOS.createTask(cid, 50, "task", block.timestamp + 1 days, member1);

        vm.prank(member2);
        uint256 did = communeOS.disputeTask(cid, taskId, member3);

        // 4 members, need ceil(8/3)=3 votes
        vm.prank(creator);
        communeOS.voteOnDispute(cid, did, true);
        vm.prank(member2);
        communeOS.voteOnDispute(cid, did, true);
        vm.prank(member3);
        communeOS.voteOnDispute(cid, did, true);

        Dispute memory d = communeOS.votingModule().getDispute(did);
        assertTrue(d.status == DisputeStatus.Upheld);
        assertEq(communeOS.collateralManager().getCollateralBalance(member1), 50); // slashed 50
    }

    // ============ Viewer Functions ============

    function testGetCommuneStatistics() public {
        uint256 cid = _createCommune(false, 0);
        _addMember(cid, member1, 1);

        ChoreSchedule[] memory s = new ChoreSchedule[](1);
        s[0] = ChoreSchedule(0, "Clean", 1 days, block.timestamp, false);
        vm.prank(creator);
        communeOS.addChores(cid, s);

        vm.prank(creator);
        communeOS.createTask(cid, 0, "task", block.timestamp + 1 days, member1);

        (Commune memory commune, uint256 mc, uint256 cc, uint256 tc) = communeOS.getCommuneStatistics(cid);
        assertEq(commune.name, "Test");
        assertEq(mc, 2);
        assertEq(cc, 1);
        assertEq(tc, 1);
    }

    // ============ Guest Invite ============

    function testGuestInviteFlow() public {
        uint256 cid = _createCommune(false, 0);

        vm.prank(creator);
        uint256 inviteId = communeOS.createGuestInvite(cid, "Bob", block.timestamp + 1 hours, block.timestamp + 1 days, "Visit");

        vm.prank(creator);
        communeOS.checkInGuest(cid, inviteId);

        vm.prank(creator);
        communeOS.checkOutGuest(cid, inviteId);
    }

    // ============ Message Board ============

    function testMessageBoardFlow() public {
        uint256 cid = _createCommune(false, 0);

        vm.prank(creator);
        uint256 mid = communeOS.postMessage(cid, "Hello commune!");

        Message memory m = communeOS.messageBoard().getMessage(mid);
        assertEq(m.content, "Hello commune!");
        assertEq(m.author, creator);

        vm.prank(creator);
        communeOS.editMessage(cid, mid, "Updated!");

        m = communeOS.messageBoard().getMessage(mid);
        assertEq(m.content, "Updated!");
    }

    // ============ Expense ============

    function testExpenseFlow() public {
        uint256 cid = _createCommune(false, 0);
        _addMember(cid, member1, 1);

        address[] memory assignees = new address[](1);
        assignees[0] = member1;

        vm.prank(creator);
        uint256 eid = communeOS.createExpense(cid, "Bill", assignees);

        vm.prank(creator);
        communeOS.setExpenseAmount(eid, 100);

        vm.prank(creator);
        communeOS.markExpensePaid(eid);

        Expense memory e = communeOS.expenseManager().getExpense(eid);
        assertTrue(e.isPaid);
        assertEq(e.amount, 100);
    }
}
