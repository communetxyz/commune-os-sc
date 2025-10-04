# CommuneOS Smart Contracts - Implementation

This repository contains the Foundry implementation of the CommuneOS smart contracts for commune management on Gnosis Chain.

## Architecture

The system is implemented as a modular architecture with the following contracts:

### Core Contracts

1. **CommuneOS.sol** - Main contract that integrates all modules
2. **Types.sol** - Shared data structures (Commune, Member, ChoreSchedule, Expense, Dispute)

### Module Contracts

3. **CommuneRegistry.sol** - Manages commune creation and invite-based access control
4. **MemberRegistry.sol** - Tracks commune membership
5. **ChoreScheduler.sol** - Manages chore schedules with period-based completion tracking
6. **ExpenseManager.sol** - Handles expense lifecycle (creation, assignment, payment, disputes)
7. **VotingModule.sol** - Manages dispute voting
8. **CollateralManager.sol** - Handles collateral deposits and slashing

## Key Design Decisions

### 1. Modular Architecture
- Each module is a separate contract for separation of concerns
- CommuneOS acts as the orchestrator, delegating to specialized modules
- Allows for easier testing, upgrading, and maintenance

### 2. Period-Based Chore Tracking
- **No instance storage**: Chore schedules are stored once, instances are calculated
- Current period = `(now - startTime) / frequency`
- Completion tracking: `completions[choreId][period] = bool`
- **O(1) storage** regardless of how long the commune exists

### 3. Invite-Based Access Control
- EIP-191 signature verification for commune invites
- Nonce-based replay protection
- Creator signs: `keccak256(communeId, nonce)`
- Each nonce can only be used once

### 4. Optional Collateralization
- Communes can require collateral deposits on joining
- Collateral is **permanent** (no withdrawal mechanism)
- Ensures long-term accountability
- Slashing mechanism for unpaid expenses

### 5. Direct Expense Assignment
- Creator assigns expenses directly to members
- No voting required for initial assignment
- ANY member can dispute ANY expense at ANY time
- Dispute resolution through simple majority voting

### 6. Dual Expense Storage
- `expenses` mapping: canonical source of truth
- `communeExpenseIds` array: track which expenses belong to each commune
- `getCommuneExpenses()` builds result from mapping to ensure data consistency

### 7. Voter Identity Preservation
- VotingModule accepts voter address as parameter
- Prevents msg.sender collision when called through CommuneOS
- Ensures each member can vote independently

## Contract Interactions

```
User
  ↓
CommuneOS (orchestrator)
  ├→ CommuneRegistry (commune creation, invite validation)
  ├→ MemberRegistry (membership tracking)
  ├→ ChoreScheduler (chore schedules, completions)
  ├→ ExpenseManager (expense lifecycle)
  ├→ VotingModule (dispute voting)
  └→ CollateralManager (collateral, slashing)
```

## Gas Optimization

1. **Chore Schedules**: No instance storage, all calculation via view functions
2. **Gnosis Chain**: Target deployment for ~$0.01/tx fees
3. **Minimal State**: Only essential data stored on-chain
4. **View Functions**: Heavy computation in read-only functions (no gas cost)

## Testing

Comprehensive test suite covering:
- ✅ Commune creation with chore schedules
- ✅ Member joining with invite signatures
- ✅ Collateral deposit and verification
- ✅ Chore completion marking
- ✅ Period calculation for chores
- ✅ Expense creation and assignment
- ✅ Expense payment tracking
- ✅ Dispute creation and voting
- ✅ Collateral slashing on upheld disputes
- ✅ Expense reassignment after disputes
- ✅ Insufficient collateral rejection

Run tests:
```bash
forge test -vv
```

## Deployment

### Prerequisites
1. Install Foundry: `curl -L https://foundry.paradigm.xyz | bash && foundryup`
2. Set up environment variables:
   ```bash
   export PRIVATE_KEY=your_private_key
   export GNOSISSCAN_API_KEY=your_api_key  # optional, for verification
   ```

### Deploy to Gnosis Chain

```bash
forge script script/Deploy.s.sol:DeployScript \
  --rpc-url gnosis \
  --broadcast \
  --verify
```

### Deploy to Local/Testnet

```bash
# Start local node
anvil

# Deploy
forge script script/Deploy.s.sol:DeployScript \
  --rpc-url http://localhost:8545 \
  --broadcast
```

## Usage Examples

### Create a Commune

```solidity
ChoreSchedule[] memory schedules = new ChoreSchedule[](2);
schedules[0] = ChoreSchedule({
    id: 0,
    title: "Kitchen Cleaning",
    frequency: 1 days,
    startTime: block.timestamp
});
schedules[1] = ChoreSchedule({
    id: 1,
    title: "Bathroom Cleaning",
    frequency: 1 weeks,
    startTime: block.timestamp
});

uint256 communeId = communeOS.createCommune(
    "My Commune",
    true,                    // require collateral
    1 ether,                 // collateral amount
    schedules
);
```

### Join a Commune

```solidity
// Creator generates invite signature off-chain
bytes memory signature = getInviteSignature(communeId, nonce);

// New member joins with collateral
communeOS.joinCommune{value: 1 ether}(communeId, nonce, signature);
```

### Mark Chore Complete

```solidity
communeOS.markChoreComplete(communeId, choreId);
```

### Create and Assign Expense

```solidity
uint256 expenseId = communeOS.createExpense(
    communeId,
    100 ether,
    "Groceries",
    block.timestamp + 7 days,
    memberAddress
);
```

### Dispute an Expense

```solidity
// Any member can dispute
uint256 disputeId = communeOS.disputeExpense(
    communeId,
    expenseId,
    newAssigneeAddress
);

// Members vote
communeOS.voteOnDispute(communeId, disputeId, true);

// Resolve dispute
communeOS.resolveDispute(communeId, disputeId);
```

## Security Considerations

1. **Signature Verification**: Uses EIP-191 standard for invite signatures
2. **Nonce Protection**: Prevents replay attacks on invites
3. **Access Control**: All functions verify commune membership
4. **Collateral Safety**: Direct transfers with require checks, no reentrancy risk
5. **Vote Integrity**: One vote per member per dispute
6. **Immutable Records**: All completions and payments are permanent

## Known Limitations

1. **No Member Removal**: Members cannot be removed or leave (by design)
2. **No Collateral Withdrawal**: Deposits are permanent
3. **Single Commune Per Contract**: No cross-commune interactions
4. **Simple Majority Voting**: No quorum requirements or weighted voting
5. **No Chore Reassignment**: Schedule modifications require new commune

## Future Enhancements

Potential improvements for future versions:
- Weighted voting based on tenure or contribution
- Chore schedule modification through governance
- Cross-commune resource sharing
- Reputation system based on completion history
- Integration with external oracles for automated verification
- Support for ERC20 token collateral

## License

MIT
