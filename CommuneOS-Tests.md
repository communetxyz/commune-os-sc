# CommuneOS Contract Test Suite

## Test Structure

```
CommuneOS Tests
├── Unit Tests
│   ├── Constructor
│   │   ├── test_constructor_deploysAllModules
│   │   ├── test_constructor_setsCollateralToken
│   │   └── test_constructor_initializesModuleAddresses
│   │
│   ├── createCommune
│   │   ├── test_createCommune_success
│   │   ├── test_createCommune_withCollateral
│   │   ├── test_createCommune_withoutCollateral
│   │   ├── test_createCommune_withChoreSchedules
│   │   ├── test_createCommune_emitsEvent
│   │   ├── test_createCommune_returnsValidCommuneId
│   │   ├── test_createCommune_registersCreatorAsMember
│   │   ├── test_createCommune_depositsCollateralForCreator
│   │   └── test_createCommune_revertsWithInsufficientCollateral
│   │
│   ├── joinCommune
│   │   ├── test_joinCommune_success
│   │   ├── test_joinCommune_withValidSignature
│   │   ├── test_joinCommune_withCollateralRequired
│   │   ├── test_joinCommune_withoutCollateralRequired
│   │   ├── test_joinCommune_marksNonceUsed
│   │   ├── test_joinCommune_emitsMemberJoinedEvent
│   │   ├── test_joinCommune_revertsWithInvalidInvite
│   │   ├── test_joinCommune_revertsWithUsedNonce
│   │   ├── test_joinCommune_revertsWithInsufficientCollateral
│   │   └── test_joinCommune_revertsWithInvalidSignature
│   │
│   ├── markChoreComplete
│   │   ├── test_markChoreComplete_success
│   │   ├── test_markChoreComplete_byMember
│   │   ├── test_markChoreComplete_updatesScheduler
│   │   ├── test_markChoreComplete_revertsWhenNotMember
│   │   └── test_markChoreComplete_revertsWithInvalidChoreId
│   │
│   ├── createExpense
│   │   ├── test_createExpense_success
│   │   ├── test_createExpense_withValidAssignee
│   │   ├── test_createExpense_returnsExpenseId
│   │   ├── test_createExpense_emitsEvent
│   │   ├── test_createExpense_revertsWhenCreatorNotMember
│   │   ├── test_createExpense_revertsWhenAssigneeNotMember
│   │   └── test_createExpense_revertsWithInvalidAmount
│   │
│   ├── markExpensePaid
│   │   ├── test_markExpensePaid_success
│   │   ├── test_markExpensePaid_byMember
│   │   ├── test_markExpensePaid_updatesExpenseManager
│   │   ├── test_markExpensePaid_revertsWhenNotMember
│   │   └── test_markExpensePaid_revertsWithInvalidExpenseId
│   │
│   ├── disputeExpense
│   │   ├── test_disputeExpense_success
│   │   ├── test_disputeExpense_createsDispute
│   │   ├── test_disputeExpense_marksExpenseDisputed
│   │   ├── test_disputeExpense_returnsDisputeId
│   │   ├── test_disputeExpense_emitsEvent
│   │   ├── test_disputeExpense_revertsWhenDisputerNotMember
│   │   ├── test_disputeExpense_revertsWhenNewAssigneeNotMember
│   │   └── test_disputeExpense_revertsWithInvalidExpenseId
│   │
│   ├── voteOnDispute
│   │   ├── test_voteOnDispute_success
│   │   ├── test_voteOnDispute_supportsDispute
│   │   ├── test_voteOnDispute_rejectsDispute
│   │   ├── test_voteOnDispute_autoResolvesAt2_3Majority
│   │   ├── test_voteOnDispute_revertsWhenNotMember
│   │   ├── test_voteOnDispute_revertsWithInvalidDisputeId
│   │   └── test_voteOnDispute_revertsWhenAlreadyVoted
│   │
│   ├── getCommuneStatistics
│   │   ├── test_getCommuneStatistics_returnsCorrectCommuneData
│   │   ├── test_getCommuneStatistics_returnsCorrectMemberCount
│   │   ├── test_getCommuneStatistics_returnsCorrectChoreCount
│   │   ├── test_getCommuneStatistics_returnsCorrectExpenseCount
│   │   └── test_getCommuneStatistics_revertsWithInvalidCommuneId
│   │
│   ├── getCurrentChores
│   │   ├── test_getCurrentChores_returnsSchedules
│   │   ├── test_getCurrentChores_returnsCurrentPeriods
│   │   ├── test_getCurrentChores_returnsCompletionStatus
│   │   └── test_getCurrentChores_handlesEmptyChoreList
│   │
│   ├── getCommuneMembers
│   │   ├── test_getCommuneMembers_returnsAllMembers
│   │   ├── test_getCommuneMembers_handlesEmptyMemberList
│   │   └── test_getCommuneMembers_revertsWithInvalidCommuneId
│   │
│   ├── getCommuneExpenses
│   │   ├── test_getCommuneExpenses_returnsAllExpenses
│   │   ├── test_getCommuneExpenses_handlesEmptyExpenseList
│   │   └── test_getCommuneExpenses_revertsWithInvalidCommuneId
│   │
│   └── getCollateralBalance
│       ├── test_getCollateralBalance_returnsCorrectBalance
│       ├── test_getCollateralBalance_returnsZeroForNonMember
│       └── test_getCollateralBalance_updatesAfterDeposit
│
└── Fuzz Tests
    ├── fuzz_createCommune_variousInputs
    ├── fuzz_createCommune_collateralAmounts
    ├── fuzz_createCommune_choreScheduleLengths
    ├── fuzz_joinCommune_multipleMembers
    ├── fuzz_joinCommune_variousNonces
    ├── fuzz_markChoreComplete_multiplePeriods
    ├── fuzz_createExpense_variousAmounts
    ├── fuzz_createExpense_variousAssignees
    ├── fuzz_disputeExpense_multipleDisputes
    ├── fuzz_voteOnDispute_variousVotingPatterns
    ├── fuzz_voteOnDispute_edgeCaseMajorities
    ├── fuzz_getCommuneStatistics_variousCommuneStates
    └── fuzz_integration_multiCommuneOperations
```
