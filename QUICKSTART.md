# CommuneOS - Quick Start Guide

## Installation

```bash
# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Install dependencies
forge install
```

## Build & Test

```bash
# Build contracts
forge build

# Run tests
forge test

# Run tests with gas report
forge test --gas-report

# Run tests with detailed output
forge test -vvv
```

## Deploy

### 1. Set up environment

```bash
cp .env.example .env
# Edit .env with your private key
```

### 2. Deploy to Gnosis Chain

```bash
forge script script/Deploy.s.sol:DeployScript \
  --rpc-url gnosis \
  --broadcast \
  --verify
```

### 3. Deploy to Local Network

```bash
# Terminal 1: Start local node
anvil

# Terminal 2: Deploy
forge script script/Deploy.s.sol:DeployScript \
  --rpc-url http://localhost:8545 \
  --broadcast
```

## Contract Sizes

| Contract          | Size    | Status |
|-------------------|---------|--------|
| CommuneOS         | 9.4 KB  | ✅     |
| ChoreScheduler    | 4.8 KB  | ✅     |
| ExpenseManager    | 4.6 KB  | ✅     |
| CommuneRegistry   | 3.4 KB  | ✅     |
| MemberRegistry    | 1.7 KB  | ✅     |
| CollateralManager | 1.2 KB  | ✅     |

All contracts well within 24KB limit.

## Basic Usage

### Create a Commune

```solidity
ChoreSchedule[] memory schedules = new ChoreSchedule[](1);
schedules[0] = ChoreSchedule({
    id: 0,
    title: "Kitchen Cleaning",
    frequency: 1 days,
    startTime: block.timestamp
});

uint256 communeId = communeOS.createCommune(
    "My Commune",
    true,        // require collateral
    1 ether,     // collateral amount
    schedules
);
```

### Invite a Member

```javascript
// Off-chain: Generate signature
const messageHash = ethers.utils.solidityKeccak256(
    ['uint256', 'uint256'],
    [communeId, nonce]
);
const signature = await creator.signMessage(ethers.utils.arrayify(messageHash));
```

```solidity
// On-chain: Member joins
communeOS.joinCommune{value: 1 ether}(communeId, nonce, signature);
```

### Mark Chore Complete

```solidity
communeOS.markChoreComplete(communeId, choreId);
```

### Create Expense

```solidity
uint256 expenseId = communeOS.createExpense(
    communeId,
    100 ether,
    "Groceries",
    block.timestamp + 7 days,
    assignedMember
);
```

### Mark Expense Paid

```solidity
communeOS.markExpensePaid(communeId, expenseId);
```

### Dispute Expense

```solidity
// Create dispute
uint256 disputeId = communeOS.disputeExpense(
    communeId,
    expenseId,
    newAssignee
);

// Vote
communeOS.voteOnDispute(communeId, disputeId, true);

// Resolve
communeOS.resolveDispute(communeId, disputeId);
```

## Testing

All 8 tests passing:
- ✅ Commune creation
- ✅ Member joining with collateral
- ✅ Chore completion
- ✅ Expense creation
- ✅ Expense payment
- ✅ Dispute flow with slashing
- ✅ Period calculation
- ✅ Access control

## Documentation

- `README.md` - Original technical specification
- `IMPLEMENTATION.md` - Detailed implementation guide
- `SUMMARY.md` - Implementation summary
- `QUICKSTART.md` - This file

## Support

For issues or questions:
1. Check the documentation
2. Review test cases in `test/CommuneOS.t.sol`
3. Review inline NatSpec comments in contracts
