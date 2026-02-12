// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/CommuneOS.sol";
import {ChoreSchedule} from "../src/interfaces/IChoreScheduler.sol";
import {Member} from "../src/interfaces/IMemberRegistry.sol";
import "./MockERC20.sol";

contract MemberRegistryTest is Test {
    CommuneOS public communeOS;
    MockERC20 public token;
    MemberRegistry public registry;

    uint256 creatorKey = 0x1;
    address creator;
    address member1;
    address member2;
    uint256 communeId;

    function setUp() public {
        token = new MockERC20();
        communeOS = new CommuneOS(address(token));
        registry = communeOS.memberRegistry();
        creator = vm.addr(creatorKey);
        member1 = address(0x11);
        member2 = address(0x12);

        vm.prank(creator);
        ChoreSchedule[] memory s = new ChoreSchedule[](0);
        communeId = communeOS.createCommune("Test", false, 0, s, "boss");
    }

    function _addMember(address m, uint256 nonce, string memory name) internal {
        bytes32 mh = keccak256(abi.encodePacked(communeId, nonce));
        bytes32 emh = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", mh));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(creatorKey, emh);
        vm.prank(m);
        communeOS.joinCommune(communeId, nonce, abi.encodePacked(r, s, v), name);
    }

    function testCreatorIsMember() public view {
        assertTrue(registry.isMember(communeId, creator));
        assertEq(registry.getMemberCount(communeId), 1);
    }

    function testJoinCommune() public {
        _addMember(member1, 1, "alice");
        assertTrue(registry.isMember(communeId, member1));
        assertEq(registry.getMemberCount(communeId), 2);
        assertEq(registry.memberUsername(member1), "alice");
    }

    function testCannotJoinTwice() public {
        _addMember(member1, 1, "alice");
        // Generate another invite
        bytes32 mh = keccak256(abi.encodePacked(communeId, uint256(2)));
        bytes32 emh = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", mh));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(creatorKey, emh);
        vm.prank(member1);
        vm.expectRevert();
        communeOS.joinCommune(communeId, 2, abi.encodePacked(r, s, v), "alice");
    }

    function testCannotReuseNonce() public {
        _addMember(member1, 1, "alice");
        assertTrue(registry.isNonceUsed(communeId, 1));

        bytes32 mh = keccak256(abi.encodePacked(communeId, uint256(1)));
        bytes32 emh = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", mh));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(creatorKey, emh);
        vm.prank(member2);
        vm.expectRevert();
        communeOS.joinCommune(communeId, 1, abi.encodePacked(r, s, v), "bob");
    }

    function testGetCommuneMembers() public {
        _addMember(member1, 1, "alice");
        _addMember(member2, 2, "bob");

        address[] memory members = registry.getCommuneMembers(communeId);
        assertEq(members.length, 3);
        assertEq(members[0], creator);
        assertEq(members[1], member1);
        assertEq(members[2], member2);
    }

    function testAreMembers() public {
        _addMember(member1, 1, "alice");

        address[] memory addrs = new address[](3);
        addrs[0] = creator;
        addrs[1] = member1;
        addrs[2] = address(0x99); // not a member

        bool[] memory results = registry.areMembers(communeId, addrs);
        assertTrue(results[0]);
        assertTrue(results[1]);
        assertFalse(results[2]);
    }

    function testRemoveMember() public {
        _addMember(member1, 1, "alice");
        assertTrue(registry.isMember(communeId, member1));

        vm.prank(creator);
        communeOS.removeMember(communeId, member1);
        assertFalse(registry.isMember(communeId, member1));
        assertEq(registry.getMemberCount(communeId), 1);
    }

    function testGetMemberStatus() public {
        _addMember(member1, 1, "alice");
        Member memory m = registry.getMemberStatus(member1);
        assertEq(m.walletAddress, member1);
        assertEq(m.communeId, communeId);
        assertTrue(m.active);
        assertEq(m.username, "alice");
    }

    function testGetMemberStatusNotRegistered() public {
        vm.expectRevert();
        registry.getMemberStatus(address(0x99));
    }

    function testIsMemberReturnsFalseForCommuneZero() public view {
        assertFalse(registry.isMember(0, creator));
    }

    function testInvalidSignatureReverts() public {
        bytes memory badSig = new bytes(65);
        vm.prank(member1);
        vm.expectRevert();
        communeOS.joinCommune(communeId, 99, badSig, "bad");
    }

    function testOnlyCommuneOSCanRegister() public {
        vm.expectRevert();
        registry.registerMember(communeId, address(0x99), 0, "x");
    }

    function testUsernameStored() public {
        vm.prank(creator);
        assertEq(registry.memberUsername(creator), "boss");
    }
}
