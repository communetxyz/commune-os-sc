// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../script/InviteGenerator.s.sol";
import "../src/CommuneOS.sol";
import "../src/interfaces/ICommuneOS.sol";
import "../src/interfaces/IMemberRegistry.sol";
import {Commune} from "../src/interfaces/ICommuneRegistry.sol";
import {ChoreSchedule} from "../src/interfaces/IChoreScheduler.sol";
import "./MockERC20.sol";

/// @title InviteGeneratorTest
/// @notice Tests for the InviteGenerator utility to ensure invite signatures work correctly
contract InviteGeneratorTest is Test {
    InviteGenerator public inviteGenerator;
    CommuneOS public communeOS;
    MockERC20 public token;

    uint256 public creatorPrivateKey = 0xABCDEF;
    uint256 public member1PrivateKey = 0x123456;
    uint256 public member2PrivateKey = 0x789012;

    address public creator;
    address public member1;
    address public member2;

    uint256 public constant COLLATERAL_AMOUNT = 5 ether;

    function setUp() public {
        inviteGenerator = new InviteGenerator();
        token = new MockERC20();
        communeOS = new CommuneOS(address(token));

        creator = vm.addr(creatorPrivateKey);
        member1 = vm.addr(member1PrivateKey);
        member2 = vm.addr(member2PrivateKey);

        // Mint tokens
        token.mint(creator, 1000 ether);
        token.mint(member1, 1000 ether);
        token.mint(member2, 1000 ether);
    }

    /// @notice Test generating a single invite and using it to join a commune
    function testGenerateSingleInvite() public {
        // Create commune
        vm.startPrank(creator);
        ChoreSchedule[] memory schedules = new ChoreSchedule[](0);
        token.approve(address(communeOS.collateralManager()), COLLATERAL_AMOUNT);
        uint256 communeId = communeOS.createCommune("Test Commune", true, COLLATERAL_AMOUNT, schedules, "creator");
        vm.stopPrank();

        // Generate invite using utility
        uint256 nonce = 1;
        bytes memory signature = inviteGenerator.generateInvite(creatorPrivateKey, communeId, nonce);

        // Verify signature is 65 bytes
        assertEq(signature.length, 65, "Signature should be 65 bytes");

        // Member1 joins with generated invite
        vm.startPrank(member1);
        token.approve(address(communeOS.collateralManager()), COLLATERAL_AMOUNT);
        communeOS.joinCommune(communeId, nonce, signature, "alice");
        vm.stopPrank();

        // Verify member joined successfully
        (, uint256 memberCount,,) = communeOS.getCommuneStatistics(communeId);
        assertEq(memberCount, 2, "Should have 2 members");

        address[] memory members = communeOS.memberRegistry().getCommuneMembers(communeId);
        assertEq(members[0], creator, "First member should be creator");
        assertEq(members[1], member1, "Second member should be member1");
    }

    /// @notice Test generating multiple invites in batch
    function testGenerateBatchInvites() public {
        // Create commune
        vm.startPrank(creator);
        ChoreSchedule[] memory schedules = new ChoreSchedule[](0);
        token.approve(address(communeOS.collateralManager()), COLLATERAL_AMOUNT);
        uint256 communeId = communeOS.createCommune("Test Commune", true, COLLATERAL_AMOUNT, schedules, "creator");
        vm.stopPrank();

        // Generate multiple invites
        uint256[] memory nonces = new uint256[](2);
        nonces[0] = 1;
        nonces[1] = 2;

        bytes[] memory signatures = inviteGenerator.generateInvites(creatorPrivateKey, communeId, nonces);

        // Verify we got 2 signatures
        assertEq(signatures.length, 2, "Should have 2 signatures");
        assertEq(signatures[0].length, 65, "First signature should be 65 bytes");
        assertEq(signatures[1].length, 65, "Second signature should be 65 bytes");

        // Member1 joins with first invite
        vm.startPrank(member1);
        token.approve(address(communeOS.collateralManager()), COLLATERAL_AMOUNT);
        communeOS.joinCommune(communeId, nonces[0], signatures[0], "bob");
        vm.stopPrank();

        // Member2 joins with second invite
        vm.startPrank(member2);
        token.approve(address(communeOS.collateralManager()), COLLATERAL_AMOUNT);
        communeOS.joinCommune(communeId, nonces[1], signatures[1], "charlie");
        vm.stopPrank();

        // Verify both members joined
        (, uint256 memberCount,,) = communeOS.getCommuneStatistics(communeId);
        assertEq(memberCount, 3, "Should have 3 members");
    }

    /// @notice Test that invite from wrong private key fails
    function testInvalidSignerFails() public {
        // Create commune
        vm.startPrank(creator);
        ChoreSchedule[] memory schedules = new ChoreSchedule[](0);
        token.approve(address(communeOS.collateralManager()), COLLATERAL_AMOUNT);
        uint256 communeId = communeOS.createCommune("Test Commune", true, COLLATERAL_AMOUNT, schedules, "creator");
        vm.stopPrank();

        // Generate invite with wrong private key (not creator)
        uint256 nonce = 1;
        bytes memory invalidSignature = inviteGenerator.generateInvite(member1PrivateKey, communeId, nonce);

        // Try to join with invalid signature - should fail
        vm.startPrank(member1);
        token.approve(address(communeOS.collateralManager()), COLLATERAL_AMOUNT);
        vm.expectRevert(IMemberRegistry.InvalidInvite.selector);
        communeOS.joinCommune(communeId, nonce, invalidSignature, "alice");
        vm.stopPrank();
    }

    /// @notice Test that reusing the same nonce fails
    function testNonceReuseFails() public {
        // Create commune
        vm.startPrank(creator);
        ChoreSchedule[] memory schedules = new ChoreSchedule[](0);
        token.approve(address(communeOS.collateralManager()), COLLATERAL_AMOUNT);
        uint256 communeId = communeOS.createCommune("Test Commune", true, COLLATERAL_AMOUNT, schedules, "creator");
        vm.stopPrank();

        // Generate invite
        uint256 nonce = 1;
        bytes memory signature = inviteGenerator.generateInvite(creatorPrivateKey, communeId, nonce);

        // Member1 joins
        vm.startPrank(member1);
        token.approve(address(communeOS.collateralManager()), COLLATERAL_AMOUNT);
        communeOS.joinCommune(communeId, nonce, signature, "alice");
        vm.stopPrank();

        // Try to reuse same nonce - should fail
        vm.startPrank(member2);
        token.approve(address(communeOS.collateralManager()), COLLATERAL_AMOUNT);
        vm.expectRevert(); // Will revert with NonceAlreadyUsed
        communeOS.joinCommune(communeId, nonce, signature, "bob");
        vm.stopPrank();
    }

    /// @notice Test that invites are commune-specific
    function testInviteIsCommuneSpecific() public {
        // Create first commune
        vm.startPrank(creator);
        ChoreSchedule[] memory schedules = new ChoreSchedule[](0);
        uint256 communeId1 = communeOS.createCommune("Test Commune 1", false, 0, schedules, "creator");
        vm.stopPrank();

        // Create second commune with different creator (member2)
        vm.startPrank(member2);
        uint256 communeId2 = communeOS.createCommune("Test Commune 2", false, 0, schedules, "member2");
        vm.stopPrank();

        // Generate invite for commune 1 from creator
        uint256 nonce = 1;
        bytes memory signature = inviteGenerator.generateInvite(creatorPrivateKey, communeId1, nonce);

        // Try to use invite for commune 1 to join commune 2 - should fail
        // (signature is from creator, but member2 is the creator of commune 2)
        vm.startPrank(member1);
        vm.expectRevert(IMemberRegistry.InvalidInvite.selector);
        communeOS.joinCommune(communeId2, nonce, signature, "alice");
        vm.stopPrank();
    }

    /// @notice Test getAddressFromPrivateKey helper
    function testGetAddressFromPrivateKey() public view {
        address derivedAddress = inviteGenerator.getAddressFromPrivateKey(creatorPrivateKey);
        assertEq(derivedAddress, creator, "Derived address should match creator");

        address derivedMember1 = inviteGenerator.getAddressFromPrivateKey(member1PrivateKey);
        assertEq(derivedMember1, member1, "Derived address should match member1");
    }

    /// @notice Test invite generation without collateral requirement
    function testInviteWithoutCollateral() public {
        // Create commune without collateral
        vm.startPrank(creator);
        ChoreSchedule[] memory schedules = new ChoreSchedule[](0);
        uint256 communeId = communeOS.createCommune("No Collateral Commune", false, 0, schedules, "creator");
        vm.stopPrank();

        // Generate invite
        uint256 nonce = 1;
        bytes memory signature = inviteGenerator.generateInvite(creatorPrivateKey, communeId, nonce);

        // Member joins without needing to approve collateral
        vm.startPrank(member1);
        communeOS.joinCommune(communeId, nonce, signature, "alice");
        vm.stopPrank();

        // Verify member joined
        (, uint256 memberCount,,) = communeOS.getCommuneStatistics(communeId);
        assertEq(memberCount, 2, "Should have 2 members");

        // Verify no collateral was deposited
        uint256 collateral = communeOS.collateralManager().getCollateralBalance(member1);
        assertEq(collateral, 0, "Member should have no collateral");
    }

    /// @notice Test generating many invites at once
    function testGenerateManyInvites() public {
        // Create commune
        vm.startPrank(creator);
        ChoreSchedule[] memory schedules = new ChoreSchedule[](0);
        uint256 communeId = communeOS.createCommune("Test Commune", false, 0, schedules, "creator");
        vm.stopPrank();

        // Generate 10 invites
        uint256[] memory nonces = new uint256[](10);
        for (uint256 i = 0; i < 10; i++) {
            nonces[i] = i + 1;
        }

        bytes[] memory signatures = inviteGenerator.generateInvites(creatorPrivateKey, communeId, nonces);

        // Verify we got 10 valid signatures
        assertEq(signatures.length, 10, "Should have 10 signatures");

        for (uint256 i = 0; i < 10; i++) {
            assertEq(signatures[i].length, 65, "Each signature should be 65 bytes");
            // Verify each signature is different
            if (i > 0) {
                assertTrue(keccak256(signatures[i]) != keccak256(signatures[i - 1]), "Signatures should be unique");
            }
        }
    }

    /// @notice Test that username is stored in mapping and accessible
    function testUsernameMapping() public {
        // Create commune
        vm.startPrank(creator);
        ChoreSchedule[] memory schedules = new ChoreSchedule[](0);
        token.approve(address(communeOS.collateralManager()), COLLATERAL_AMOUNT);
        uint256 communeId = communeOS.createCommune("Test Commune", true, COLLATERAL_AMOUNT, schedules, "alice");
        vm.stopPrank();

        // Verify creator's username is stored
        assertEq(communeOS.memberRegistry().memberUsername(creator), "alice", "Creator username should be alice");

        // Generate invite
        uint256 nonce = 1;
        bytes memory signature = inviteGenerator.generateInvite(creatorPrivateKey, communeId, nonce);

        // Member1 joins with username "bob"
        vm.startPrank(member1);
        token.approve(address(communeOS.collateralManager()), COLLATERAL_AMOUNT);
        communeOS.joinCommune(communeId, nonce, signature, "bob");
        vm.stopPrank();

        // Verify member1's username is stored
        assertEq(communeOS.memberRegistry().memberUsername(member1), "bob", "Member1 username should be bob");

        // Test getUsernames function
        address[] memory addresses = new address[](2);
        addresses[0] = creator;
        addresses[1] = member1;
        string[] memory usernames = communeOS.getUsernames(addresses);
        assertEq(usernames[0], "alice", "Creator username from getUsernames should be alice");
        assertEq(usernames[1], "bob", "Member1 username from getUsernames should be bob");
    }

    /// @notice Test that the message hash format matches CommuneRegistry
    function testMessageHashFormat() public view {
        uint256 communeId = 123;
        uint256 nonce = 456;

        // Generate signature
        bytes memory signature = inviteGenerator.generateInvite(creatorPrivateKey, communeId, nonce);

        // Manually verify the hash format matches
        bytes32 messageHash = keccak256(abi.encodePacked(communeId, nonce));
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));

        // Recover signer from our signature
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(signature);
        address recoveredSigner = ecrecover(ethSignedMessageHash, v, r, s);

        // Verify recovered signer matches creator
        assertEq(recoveredSigner, creator, "Recovered signer should match creator");
    }

    // Helper to split signature (same as CommuneRegistry)
    function splitSignature(bytes memory sig) internal pure returns (bytes32 r, bytes32 s, uint8 v) {
        require(sig.length == 65, "Invalid signature length");

        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }
    }
}
