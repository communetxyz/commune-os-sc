// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/CommuneOS.sol";
import {ChoreSchedule} from "../src/interfaces/IChoreScheduler.sol";
import {Dispute, DisputeStatus} from "../src/interfaces/IVotingModule.sol";
import "./MockERC20.sol";

contract CollateralManagerTest is Test {
    CommuneOS public communeOS;
    MockERC20 public token;
    CollateralManager public cm;

    uint256 creatorKey = 0x1;
    address creator;
    address member1;
    address member2;
    address member3;
    uint256 communeId;
    uint256 constant COLLATERAL = 100;

    function setUp() public {
        token = new MockERC20();
        communeOS = new CommuneOS(address(token));
        cm = communeOS.collateralManager();
        creator = vm.addr(creatorKey);
        member1 = address(0x11);
        member2 = address(0x12);
        member3 = address(0x13);

        token.mint(creator, 1e18);
        token.mint(member1, 1e18);
        token.mint(member2, 1e18);
        token.mint(member3, 1e18);

        vm.prank(creator);
        token.approve(address(cm), COLLATERAL);
        vm.prank(creator);
        ChoreSchedule[] memory s = new ChoreSchedule[](0);
        communeId = communeOS.createCommune("Test", true, COLLATERAL, s, "c");

        _addMember(member1, 1);
        _addMember(member2, 2);
        _addMember(member3, 3);
    }

    function _addMember(address m, uint256 nonce) internal {
        bytes32 mh = keccak256(abi.encodePacked(communeId, nonce));
        bytes32 emh = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", mh));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(creatorKey, emh);
        vm.startPrank(m);
        token.approve(address(cm), COLLATERAL);
        communeOS.joinCommune(communeId, nonce, abi.encodePacked(r, s, v), "");
        vm.stopPrank();
    }

    function testDepositOnJoin() public view {
        assertEq(cm.getCollateralBalance(creator), COLLATERAL);
        assertEq(cm.getCollateralBalance(member1), COLLATERAL);
        assertEq(cm.getCollateralBalance(member2), COLLATERAL);
    }

    function testIsCollateralSufficient() public view {
        assertTrue(cm.isCollateralSufficient(creator, COLLATERAL));
        assertTrue(cm.isCollateralSufficient(creator, 1));
        assertFalse(cm.isCollateralSufficient(creator, COLLATERAL + 1));
    }

    function testSlashOnDisputeUpheld() public {
        vm.prank(creator);
        uint256 taskId = communeOS.createTask(communeId, 50, "task", block.timestamp + 1 days, member1);

        vm.prank(member2);
        uint256 disputeId = communeOS.disputeTask(communeId, taskId, member3);

        // Vote to uphold (need 3 out of 4 with ceiling division)
        vm.prank(creator);
        communeOS.voteOnDispute(communeId, disputeId, true);
        vm.prank(member2);
        communeOS.voteOnDispute(communeId, disputeId, true);
        vm.prank(member3);
        communeOS.voteOnDispute(communeId, disputeId, true);

        // member1 should have been slashed min(50, 100) = 50
        assertEq(cm.getCollateralBalance(member1), COLLATERAL - 50);
    }

    function testWithdrawOnRemoval() public {
        uint256 balBefore = token.balanceOf(member1);
        vm.prank(creator);
        communeOS.removeMember(communeId, member1);
        assertEq(cm.getCollateralBalance(member1), 0);
        assertEq(token.balanceOf(member1), balBefore + COLLATERAL);
    }

    function testOnlyCommuneOSCanDeposit() public {
        vm.expectRevert();
        cm.depositCollateral(address(0x99), 10);
    }

    function testOnlyCommuneOSCanSlash() public {
        vm.expectRevert();
        cm.slashCollateral(member1, 10, member2);
    }

    function testCollateralToken() public view {
        assertEq(address(cm.collateralToken()), address(token));
    }
}
