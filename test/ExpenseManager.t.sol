// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/CommuneOS.sol";
import {ChoreSchedule} from "../src/interfaces/IChoreScheduler.sol";
import {Expense} from "../src/interfaces/IExpenseManager.sol";
import "./MockERC20.sol";

contract ExpenseManagerTest is Test {
    CommuneOS public communeOS;
    MockERC20 public token;
    ExpenseManager public em;

    uint256 creatorKey = 0x1;
    address creator;
    address member1;
    uint256 communeId;

    function setUp() public {
        token = new MockERC20();
        communeOS = new CommuneOS(address(token));
        em = communeOS.expenseManager();
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

    function testCreateExpenseWithoutAmount() public {
        address[] memory assignees = new address[](1);
        assignees[0] = member1;

        vm.prank(creator);
        uint256 eid = communeOS.createExpense(communeId, "Utility bill", assignees);

        Expense memory e = em.getExpense(eid);
        assertEq(e.description, "Utility bill");
        assertFalse(e.hasAmount);
        assertEq(e.amount, 0);
        assertFalse(e.isPaid);
    }

    function testCreateExpenseWithAmount() public {
        address[] memory assignees = new address[](2);
        assignees[0] = creator;
        assignees[1] = member1;

        vm.prank(creator);
        uint256 eid = communeOS.createExpenseWithAmount(communeId, "Groceries", 50, assignees);

        Expense memory e = em.getExpense(eid);
        assertTrue(e.hasAmount);
        assertEq(e.amount, 50);
    }

    function testSetAmountLater() public {
        address[] memory assignees = new address[](1);
        assignees[0] = member1;

        vm.prank(creator);
        uint256 eid = communeOS.createExpense(communeId, "Bill", assignees);

        vm.prank(creator);
        communeOS.setExpenseAmount(eid, 200);

        Expense memory e = em.getExpense(eid);
        assertTrue(e.hasAmount);
        assertEq(e.amount, 200);
    }

    function testUpdateAmount() public {
        address[] memory assignees = new address[](1);
        assignees[0] = member1;

        vm.prank(creator);
        uint256 eid = communeOS.createExpenseWithAmount(communeId, "Dinner", 100, assignees);

        vm.prank(creator);
        communeOS.setExpenseAmount(eid, 150);

        assertEq(em.getExpense(eid).amount, 150);
    }

    function testMarkPaid() public {
        address[] memory assignees = new address[](1);
        assignees[0] = member1;

        vm.prank(creator);
        uint256 eid = communeOS.createExpenseWithAmount(communeId, "Rent", 1000, assignees);

        vm.prank(creator);
        communeOS.markExpensePaid(eid);

        assertTrue(em.getExpense(eid).isPaid);
    }

    function testCannotPayWithoutAmount() public {
        address[] memory assignees = new address[](1);
        assignees[0] = member1;

        vm.prank(creator);
        uint256 eid = communeOS.createExpense(communeId, "Unknown", assignees);

        vm.prank(creator);
        vm.expectRevert();
        communeOS.markExpensePaid(eid);
    }

    function testCannotPayTwice() public {
        address[] memory assignees = new address[](1);
        assignees[0] = member1;

        vm.prank(creator);
        uint256 eid = communeOS.createExpenseWithAmount(communeId, "Rent", 100, assignees);

        vm.prank(creator);
        communeOS.markExpensePaid(eid);

        vm.prank(creator);
        vm.expectRevert();
        communeOS.markExpensePaid(eid);
    }

    function testCannotUpdateAmountAfterPaid() public {
        address[] memory assignees = new address[](1);
        assignees[0] = member1;

        vm.prank(creator);
        uint256 eid = communeOS.createExpenseWithAmount(communeId, "Rent", 100, assignees);

        vm.prank(creator);
        communeOS.markExpensePaid(eid);

        vm.prank(creator);
        vm.expectRevert();
        communeOS.setExpenseAmount(eid, 200);
    }

    function testGetCommuneExpenses() public {
        address[] memory assignees = new address[](1);
        assignees[0] = member1;

        vm.prank(creator);
        communeOS.createExpense(communeId, "A", assignees);
        vm.prank(creator);
        communeOS.createExpenseWithAmount(communeId, "B", 50, assignees);

        Expense[] memory expenses = em.getCommuneExpenses(communeId);
        assertEq(expenses.length, 2);
    }

    function testNonMemberCannotCreateExpense() public {
        address[] memory assignees = new address[](1);
        assignees[0] = member1;

        vm.prank(address(0x99));
        vm.expectRevert();
        communeOS.createExpense(communeId, "Bad", assignees);
    }
}
