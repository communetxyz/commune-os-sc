// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/CommuneOS.sol";
import {ChoreSchedule} from "../src/interfaces/IChoreScheduler.sol";
import {Commune} from "../src/interfaces/ICommuneRegistry.sol";
import "./MockERC20.sol";

contract CommuneRegistryTest is Test {
    CommuneOS public communeOS;
    MockERC20 public token;
    CommuneRegistry public registry;

    uint256 creatorKey = 0x1;
    address creator;

    function setUp() public {
        token = new MockERC20();
        communeOS = new CommuneOS(address(token));
        registry = communeOS.communeRegistry();
        creator = vm.addr(creatorKey);
        token.mint(creator, 1e18);
    }

    function testCreateCommune() public {
        vm.prank(creator);
        ChoreSchedule[] memory s = new ChoreSchedule[](0);
        uint256 id = communeOS.createCommune("My Commune", false, 0, s, "c");

        assertEq(id, 1);
        Commune memory c = registry.getCommune(id);
        assertEq(c.name, "My Commune");
        assertEq(c.creator, creator);
        assertFalse(c.collateralRequired);
    }

    function testCreateCommuneWithCollateral() public {
        vm.startPrank(creator);
        token.approve(address(communeOS.collateralManager()), 100);
        ChoreSchedule[] memory s = new ChoreSchedule[](0);
        uint256 id = communeOS.createCommune("Secure", true, 100, s, "c");
        vm.stopPrank();

        Commune memory c = registry.getCommune(id);
        assertTrue(c.collateralRequired);
        assertEq(c.collateralAmount, 100);
    }

    function testCreateMultipleCommunes() public {
        vm.startPrank(creator);
        ChoreSchedule[] memory s = new ChoreSchedule[](0);
        uint256 id1 = communeOS.createCommune("First", false, 0, s, "c");
        vm.stopPrank();

        // Need a different creator for second commune since creator is already in commune 1
        address creator2 = address(0x99);
        vm.prank(creator2);
        uint256 id2 = communeOS.createCommune("Second", false, 0, s, "c2");

        assertEq(id1, 1);
        assertEq(id2, 2);
    }

    function testGetCommuneInvalidId() public {
        vm.expectRevert();
        registry.getCommune(999);
    }

    function testValidateInvite() public {
        vm.prank(creator);
        ChoreSchedule[] memory s = new ChoreSchedule[](0);
        uint256 cid = communeOS.createCommune("Test", false, 0, s, "c");

        uint256 nonce = 42;
        bytes32 mh = keccak256(abi.encodePacked(cid, nonce));
        bytes32 emh = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", mh));
        (uint8 v, bytes32 r, bytes32 ss) = vm.sign(creatorKey, emh);
        bytes memory sig = abi.encodePacked(r, ss, v);

        bool valid = registry.validateInvite(cid, nonce, sig);
        assertTrue(valid);
    }

    function testInvalidInviteWrongSigner() public {
        vm.prank(creator);
        ChoreSchedule[] memory s = new ChoreSchedule[](0);
        uint256 cid = communeOS.createCommune("Test", false, 0, s, "c");

        uint256 nonce = 42;
        bytes32 mh = keccak256(abi.encodePacked(cid, nonce));
        bytes32 emh = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", mh));
        (uint8 v, bytes32 r, bytes32 ss) = vm.sign(0x9999, emh); // wrong key
        bytes memory sig = abi.encodePacked(r, ss, v);

        bool valid = registry.validateInvite(cid, nonce, sig);
        assertFalse(valid);
    }

    function testCommuneCountStartsAt1() public view {
        assertEq(registry.communeCount(), 1);
    }

    function testOnlyCommuneOSCanCreate() public {
        vm.expectRevert();
        registry.createCommune("Bad", address(0x1), false, 0);
    }
}
