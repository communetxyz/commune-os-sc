# CollateralManager Contract Test Suite

## Test Structure

```
CollateralManager Tests
├── Unit Tests
│   ├── Constructor
│   │   ├── test_constructor_withERC20Token
│   │   ├── test_constructor_withNativeETH
│   │   ├── test_constructor_setsUseERC20Flag
│   │   └── test_constructor_setsCollateralToken
│   │
│   ├── depositCollateral (ERC20)
│   │   ├── test_depositCollateral_ERC20_success
│   │   ├── test_depositCollateral_ERC20_transfersTokens
│   │   ├── test_depositCollateral_ERC20_updatesBalance
│   │   ├── test_depositCollateral_ERC20_emitsEvent
│   │   ├── test_depositCollateral_ERC20_revertsWithZeroAmount
│   │   ├── test_depositCollateral_ERC20_revertsWithInsufficientAllowance
│   │   ├── test_depositCollateral_ERC20_revertsWithInsufficientBalance
│   │   └── test_depositCollateral_ERC20_revertsWhenNotCommuneOS
│   │
│   ├── depositCollateral (Native ETH)
│   │   ├── test_depositCollateral_ETH_success
│   │   ├── test_depositCollateral_ETH_acceptsValue
│   │   ├── test_depositCollateral_ETH_updatesBalance
│   │   ├── test_depositCollateral_ETH_emitsEvent
│   │   ├── test_depositCollateral_ETH_revertsWithZeroAmount
│   │   ├── test_depositCollateral_ETH_revertsWithMismatchedValue
│   │   └── test_depositCollateral_ETH_revertsWhenNotCommuneOS
│   │
│   ├── slashCollateral (ERC20)
│   │   ├── test_slashCollateral_ERC20_success
│   │   ├── test_slashCollateral_ERC20_transfersToRecipient
│   │   ├── test_slashCollateral_ERC20_decreasesBalance
│   │   ├── test_slashCollateral_ERC20_emitsEvent
│   │   ├── test_slashCollateral_ERC20_revertsWithInsufficientBalance
│   │   ├── test_slashCollateral_ERC20_revertsWithTransferFailure
│   │   └── test_slashCollateral_ERC20_revertsWhenNotCommuneOS
│   │
│   ├── slashCollateral (Native ETH)
│   │   ├── test_slashCollateral_ETH_success
│   │   ├── test_slashCollateral_ETH_sendsToRecipient
│   │   ├── test_slashCollateral_ETH_decreasesBalance
│   │   ├── test_slashCollateral_ETH_emitsEvent
│   │   ├── test_slashCollateral_ETH_revertsWithInsufficientBalance
│   │   ├── test_slashCollateral_ETH_revertsWithTransferFailure
│   │   └── test_slashCollateral_ETH_revertsWhenNotCommuneOS
│   │
│   ├── isCollateralSufficient
│   │   ├── test_isCollateralSufficient_returnsTrue
│   │   ├── test_isCollateralSufficient_returnsFalse
│   │   ├── test_isCollateralSufficient_exactAmount
│   │   └── test_isCollateralSufficient_zeroBalance
│   │
│   ├── getCollateralBalance
│   │   ├── test_getCollateralBalance_returnsCorrectAmount
│   │   ├── test_getCollateralBalance_returnsZeroForNewMember
│   │   ├── test_getCollateralBalance_updatesAfterDeposit
│   │   └── test_getCollateralBalance_updatesAfterSlash
│   │
│   └── Access Control
│       ├── test_onlyCommuneOS_depositCollateral
│       ├── test_onlyCommuneOS_slashCollateral
│       └── test_communeOSCanCall
│
└── Fuzz Tests
    ├── fuzz_depositCollateral_ERC20_variousAmounts
    ├── fuzz_depositCollateral_ETH_variousAmounts
    ├── fuzz_slashCollateral_ERC20_variousAmounts
    ├── fuzz_slashCollateral_ETH_variousAmounts
    ├── fuzz_slashCollateral_partialSlashing
    ├── fuzz_multipleDeposits_accumulatesCorrectly
    ├── fuzz_multipleSlashes_decreasesCorrectly
    ├── fuzz_isCollateralSufficient_edgeCases
    └── fuzz_integration_depositAndSlashCycles
```
 
 
## Sequence Diagrams
 
### Depositing Collateral with ERC20
 
```mermaid
sequenceDiagram
    participant Member
    participant CommuneOS
    participant CollateralManager
    participant ERC20Token
 
    Note over Member: Member wants to join commune<br/>Must deposit collateral first
 
    Member->>ERC20Token: approve(CollateralManager, amount)
    activate ERC20Token
    ERC20Token->>ERC20Token: Set allowance[member][CollateralManager] = amount
    ERC20Token-->>Member: Approval granted
    deactivate ERC20Token
 
    Member->>CommuneOS: joinCommune(communeId, nonce, signature)
    activate CommuneOS
 
    CommuneOS->>CollateralManager: depositCollateral(communeId, member, amount)
    activate CollateralManager
 
    CollateralManager->>CollateralManager: Verify caller is CommuneOS
 
    alt Amount is zero
        CollateralManager-->>CommuneOS: Revert: InvalidDepositAmount
        CommuneOS-->>Member: Error: Invalid amount
    else Valid amount
        CollateralManager->>ERC20Token: Check allowance(member, CollateralManager)
        activate ERC20Token
        ERC20Token-->>CollateralManager: Return allowance
        deactivate ERC20Token
 
        alt Insufficient allowance
            CollateralManager-->>CommuneOS: Revert: InsufficientAllowance
            CommuneOS-->>Member: Error: Approve tokens first
        else Sufficient allowance
            CollateralManager->>ERC20Token: Check balanceOf(member)
            activate ERC20Token
            ERC20Token-->>CollateralManager: Return balance
            deactivate ERC20Token
 
            alt Insufficient balance
                CollateralManager-->>CommuneOS: Revert: InsufficientBalance
                CommuneOS-->>Member: Error: Not enough tokens
            else Sufficient balance
                CollateralManager->>ERC20Token: safeTransferFrom(member, this, amount)
                activate ERC20Token
                ERC20Token->>ERC20Token: Transfer tokens
                ERC20Token->>ERC20Token: Decrease member balance
                ERC20Token->>ERC20Token: Increase CollateralManager balance
                ERC20Token-->>CollateralManager: Transfer successful
                deactivate ERC20Token
 
                CollateralManager->>CollateralManager: collateralBalance[member] += amount
                CollateralManager->>CollateralManager: Emit CollateralDeposited event
                CollateralManager-->>CommuneOS: Deposit successful
                deactivate CollateralManager
 
                CommuneOS-->>Member: Successfully joined commune
            end
        end
    end
 
    deactivate CommuneOS
 
    Note over CollateralManager: Member's collateral now tracked<br/>Can be slashed if disputes occur
```
 
### Slashing Collateral
 
```mermaid
sequenceDiagram
    participant CommuneOS
    participant CollateralManager
    participant ERC20Token
    participant Recipient
 
    Note over CommuneOS: Dispute was upheld<br/>Original assignee must be slashed
 
    CommuneOS->>CollateralManager: slashCollateral(communeId, member, amount, recipient)
    activate CollateralManager
 
    CollateralManager->>CollateralManager: Verify caller is CommuneOS
    CollateralManager->>CollateralManager: Get current balance = collateralBalance[member]
 
    alt Insufficient collateral
        CollateralManager->>CollateralManager: Check balance >= amount: NO
        CollateralManager-->>CommuneOS: Revert: InsufficientCollateral
        Note over CommuneOS: Cannot slash more than deposited
    else Sufficient collateral
        CollateralManager->>CollateralManager: Check balance >= amount: YES
        CollateralManager->>CollateralManager: collateralBalance[member] -= amount
 
        Note over CollateralManager: Balance updated before transfer<br/>(checks-effects-interactions pattern)
 
        CollateralManager->>ERC20Token: safeTransfer(recipient, amount)
        activate ERC20Token
 
        ERC20Token->>ERC20Token: Transfer tokens from contract
        ERC20Token->>ERC20Token: Decrease CollateralManager balance
        ERC20Token->>ERC20Token: Increase recipient balance
 
        alt Transfer fails
            ERC20Token-->>CollateralManager: Revert: TransferFailed
            Note over CollateralManager: State reverts (balance restore)
            CollateralManager-->>CommuneOS: Error: Transfer failed
        else Transfer succeeds
            ERC20Token-->>CollateralManager: Transfer successful
            deactivate ERC20Token
 
            CollateralManager->>CollateralManager: Emit CollateralSlashed event
            CollateralManager-->>CommuneOS: Slash successful
            deactivate CollateralManager
 
            Note over Recipient: Recipient receives slashed tokens<br/>Member's collateral decreased
        end
    end
```
 
### Checking Collateral Sufficiency
 
```mermaid
sequenceDiagram
    participant CommuneOS
    participant CollateralManager
 
    Note over CommuneOS: Before allowing join or risky action<br/>Check if member has enough collateral
 
    CommuneOS->>CollateralManager: isCollateralSufficient(communeId, member, requiredAmount)
    activate CollateralManager
 
    CollateralManager->>CollateralManager: Get balance = collateralBalance[member]
 
    alt balance >= requiredAmount
        CollateralManager->>CollateralManager: Sufficient collateral check: PASS
        CollateralManager-->>CommuneOS: Return true
        Note over CommuneOS: Member has sufficient collateral<br/>Can proceed with action
    else balance < requiredAmount
        CollateralManager->>CollateralManager: Sufficient collateral check: FAIL
        CollateralManager-->>CommuneOS: Return false
        Note over CommuneOS: Member lacks collateral<br/>Cannot proceed (reject join/action)
    end
 
    deactivate CollateralManager
 
    Note over CollateralManager: View function - no state changes<br/>Used for validation before operations
```
 
### Multiple Deposits and Slashes
 
```mermaid
sequenceDiagram
    participant Member
    participant CommuneOS
    participant CollateralManager
    participant ERC20Token
    participant Recipient
 
    Note over Member: Initial balance: 0
 
    Member->>ERC20Token: approve(CollateralManager, 100)
    ERC20Token-->>Member: Approved
 
    CommuneOS->>CollateralManager: depositCollateral(communeId, member, 100)
    activate CollateralManager
    CollateralManager->>ERC20Token: safeTransferFrom(member, this, 100)
    ERC20Token-->>CollateralManager: Transfer successful
    CollateralManager->>CollateralManager: collateralBalance[member] = 0 + 100 = 100
    CollateralManager-->>CommuneOS: Success
    deactivate CollateralManager
 
    Note over CollateralManager: Balance: 100
 
    Member->>ERC20Token: approve(CollateralManager, 50)
    ERC20Token-->>Member: Approved
 
    CommuneOS->>CollateralManager: depositCollateral(communeId, member, 50)
    activate CollateralManager
    CollateralManager->>ERC20Token: safeTransferFrom(member, this, 50)
    ERC20Token-->>CollateralManager: Transfer successful
    CollateralManager->>CollateralManager: collateralBalance[member] = 100 + 50 = 150
    CollateralManager-->>CommuneOS: Success
    deactivate CollateralManager
 
    Note over CollateralManager: Balance: 150 (accumulated)
 
    CommuneOS->>CollateralManager: slashCollateral(communeId, member, 30, recipient)
    activate CollateralManager
    CollateralManager->>CollateralManager: collateralBalance[member] = 150 - 30 = 120
    CollateralManager->>ERC20Token: safeTransfer(recipient, 30)
    ERC20Token-->>Recipient: Received 30 tokens
    ERC20Token-->>CollateralManager: Success
    CollateralManager-->>CommuneOS: Slashed
    deactivate CollateralManager
 
    Note over CollateralManager: Balance: 120
 
    CommuneOS->>CollateralManager: slashCollateral(communeId, member, 20, recipient)
    activate CollateralManager
    CollateralManager->>CollateralManager: collateralBalance[member] = 120 - 20 = 100
    CollateralManager->>ERC20Token: safeTransfer(recipient, 20)
    ERC20Token-->>Recipient: Received 20 tokens
    ERC20Token-->>CollateralManager: Success
    CollateralManager-->>CommuneOS: Slashed
    deactivate CollateralManager
 
    Note over CollateralManager: Final balance: 100<br/>Total deposited: 150<br/>Total slashed: 50
 
    CommuneOS->>CollateralManager: isCollateralSufficient(communeId, member, 100)
    activate CollateralManager
    CollateralManager-->>CommuneOS: Return true (100 >= 100)
    deactivate CollateralManager
 
    CommuneOS->>CollateralManager: isCollateralSufficient(communeId, member, 150)
    activate CollateralManager
    CollateralManager-->>CommuneOS: Return false (100 < 150)
    deactivate CollateralManager
```