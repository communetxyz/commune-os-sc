// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/CommuneOS.sol";
import {ChoreSchedule} from "../src/interfaces/IChoreScheduler.sol";
import {Dispute, DisputeStatus} from "../src/interfaces/IVotingModule.sol";
import "./MockERC20.sol";

contract VotingModuleTest is Test {
    CommuneOS public communeOS;
    MockERC20 public token;
    VotingModule public voting;

    uint256 creatorKey = 0x1;
    address creator;
    address member1;
    address member2;
    address member3;
    address member4;

    uint256 communeId;

    function setUp() public {
        token = new MockERC20();
        communeOS = new CommuneOS(address(token));
        voting = communeOS.votingModule();

        creator = vm.addr(creatorKey);
        member1 = address(0x11);
        member2 = address(0x12);
        member3 = address(0x13);
        member4 = address(0x14);

        token.mint(creator, 1e18);
        token.mint(member1, 1e18);
        token.mint(member2, 1e18);
        token.mint(member3, 1e18);
        token.mint(member4, 1e18);

        // Create commune without collateral
        vm.prank(creator);
        ChoreSchedule[] memory s = new ChoreSchedule[](0);
        communeId = communeOS.createCommune("TestCommune", false, 0, s, "creator");

        // Add members
        _addMember(member1, 1);
        _addMember(member2, 2);
        _addMember(member3, 3);
    }

    function _addMember(address m, uint256 nonce) internal {
        bytes32 mh = keccak256(abi.encodePacked(communeId, nonce));
        bytes32 emh = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", mh));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(creatorKey, emh);
        vm.prank(m);
        communeOS.joinCommune(communeId, nonce, abi.encodePacked(r, s, v), "");
    }

    function testCreateDispute() public {
        vm.prank(creator);
        uint256 taskId = communeOS.createTask(communeId, 0, "task", block.timestamp + 1 days, member1);

        vm.prank(member2);
        uint256 disputeId = communeOS.disputeTask(communeId, taskId, member3);

        Dispute memory d = voting.getDispute(disputeId);
        assertEq(d.taskId, taskId);
        assertEq(d.proposedNewAssignee, member3);
        assertTrue(d.status == DisputeStatus.Pending);
    }

    function testVotingThresholdCeilingDivision() public {
        // 4 members: requiredVotes should be ceil(4*2/3) = ceil(8/3) = 3
        // With old code: (4*2)/3 = 2 (wrong)
        // With fix: (4*2+2)/3 = 10/3 = 3 (correct)
        vm.prank(creator);
        uint256 taskId = communeOS.createTask(communeId, 0, "task", block.timestamp + 1 days, member1);

        vm.prank(member2);
        uint256 disputeId = communeOS.disputeTask(communeId, taskId, member3);

        // Vote 1
        vm.prank(creator);
        communeOS.voteOnDispute(communeId, disputeId, true);
        assertEq(uint256(voting.getDispute(disputeId).status), uint256(DisputeStatus.Pending));

        // Vote 2 - should still be pending with ceiling division fix
        vm.prank(member2);
        communeOS.voteOnDispute(communeId, disputeId, true);
        assertEq(uint256(voting.getDispute(disputeId).status), uint256(DisputeStatus.Pending));

        // Vote 3 - should resolve now
        vm.prank(member3);
        communeOS.voteOnDispute(communeId, disputeId, true);
        assertEq(uint256(voting.getDispute(disputeId).status), uint256(DisputeStatus.Upheld));
    }

    function testThresholdWith2Members() public {
        // Create a new commune with a fresh creator (not already registered)
        uint256 creator2Key = 0xA;
        address creator2 = vm.addr(creator2Key);

        vm.prank(creator2);
        ChoreSchedule[] memory s = new ChoreSchedule[](0);
        uint256 cid2 = communeOS.createCommune("Small", false, 0, s, "c");

        // Add 1 member (total 2 with creator2)
        address m = address(0x99);
        bytes32 mh = keccak256(abi.encodePacked(cid2, uint256(1)));
        bytes32 emh = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", mh));
        (uint8 v, bytes32 r, bytes32 ss) = vm.sign(creator2Key, emh);
        vm.prank(m);
        communeOS.joinCommune(cid2, 1, abi.encodePacked(r, ss, v), "");

        vm.prank(creator2);
        uint256 taskId = communeOS.createTask(cid2, 0, "task", block.timestamp + 1 days, m);

        vm.prank(creator2);
        uint256 disputeId = communeOS.disputeTask(cid2, taskId, creator2);

        // With 2 members, ceil(2*2/3) = ceil(4/3) = 2, so need both votes
        vm.prank(creator2);
        communeOS.voteOnDispute(cid2, disputeId, true);
        assertEq(uint256(voting.getDispute(disputeId).status), uint256(DisputeStatus.Pending));

        vm.prank(m);
        communeOS.voteOnDispute(cid2, disputeId, true);
        assertEq(uint256(voting.getDispute(disputeId).status), uint256(DisputeStatus.Upheld));
    }

    function testCannotVoteTwice() public {
        vm.prank(creator);
        uint256 taskId = communeOS.createTask(communeId, 0, "task", block.timestamp + 1 days, member1);

        vm.prank(member2);
        uint256 disputeId = communeOS.disputeTask(communeId, taskId, member3);

        vm.prank(creator);
        communeOS.voteOnDispute(communeId, disputeId, true);

        vm.prank(creator);
        vm.expectRevert();
        communeOS.voteOnDispute(communeId, disputeId, true);
    }

    function testCannotVoteOnResolvedDispute() public {
        vm.prank(creator);
        uint256 taskId = communeOS.createTask(communeId, 0, "task", block.timestamp + 1 days, member1);

        vm.prank(member2);
        uint256 disputeId = communeOS.disputeTask(communeId, taskId, member3);

        // Resolve it
        vm.prank(creator);
        communeOS.voteOnDispute(communeId, disputeId, true);
        vm.prank(member2);
        communeOS.voteOnDispute(communeId, disputeId, true);
        vm.prank(member3);
        communeOS.voteOnDispute(communeId, disputeId, true);

        // Already resolved
        vm.prank(member1);
        vm.expectRevert();
        communeOS.voteOnDispute(communeId, disputeId, true);
    }

    function testDisputeRejection() public {
        vm.prank(creator);
        uint256 taskId = communeOS.createTask(communeId, 0, "task", block.timestamp + 1 days, member1);

        vm.prank(member2);
        uint256 disputeId = communeOS.disputeTask(communeId, taskId, member3);

        // Vote against
        vm.prank(creator);
        communeOS.voteOnDispute(communeId, disputeId, false);
        vm.prank(member1);
        communeOS.voteOnDispute(communeId, disputeId, false);
        vm.prank(member3);
        communeOS.voteOnDispute(communeId, disputeId, false);

        assertEq(uint256(voting.getDispute(disputeId).status), uint256(DisputeStatus.Rejected));
    }

    function testTallyVotes() public {
        vm.prank(creator);
        uint256 taskId = communeOS.createTask(communeId, 0, "task", block.timestamp + 1 days, member1);

        vm.prank(member2);
        uint256 disputeId = communeOS.disputeTask(communeId, taskId, member3);

        vm.prank(creator);
        communeOS.voteOnDispute(communeId, disputeId, true);
        vm.prank(member1);
        communeOS.voteOnDispute(communeId, disputeId, false);

        (uint256 vf, uint256 va) = voting.tallyVotes(disputeId);
        assertEq(vf, 1);
        assertEq(va, 1);
    }

    function testHasVotedOnDispute() public {
        vm.prank(creator);
        uint256 taskId = communeOS.createTask(communeId, 0, "task", block.timestamp + 1 days, member1);

        vm.prank(member2);
        uint256 disputeId = communeOS.disputeTask(communeId, taskId, member3);

        assertFalse(voting.hasVotedOnDispute(disputeId, creator));
        vm.prank(creator);
        communeOS.voteOnDispute(communeId, disputeId, true);
        assertTrue(voting.hasVotedOnDispute(disputeId, creator));
    }

    function testInvalidDisputeIdReverts() public {
        vm.expectRevert();
        voting.getDispute(999);

        vm.expectRevert();
        voting.tallyVotes(999);
    }
}
