# ExpenseManager Contract Test Suite

## Test Structure

```
ExpenseManager Tests
├── Unit Tests
│   ├── createExpense
│   │   ├── test_createExpense_success
│   │   ├── test_createExpense_incrementsExpenseCount
│   │   ├── test_createExpense_returnsExpenseId
│   │   ├── test_createExpense_storesAmount
│   │   ├── test_createExpense_storesDescription
│   │   ├── test_createExpense_storesAssignedTo
│   │   ├── test_createExpense_storesDueDate
│   │   ├── test_createExpense_storesCommuneId
│   │   ├── test_createExpense_initializesPaidFalse
│   │   ├── test_createExpense_initializesDisputedFalse
│   │   ├── test_createExpense_emitsExpenseCreatedEvent
│   │   ├── test_createExpense_revertsWithZeroAddress
│   │   ├── test_createExpense_revertsWithZeroAmount
│   │   ├── test_createExpense_revertsWithEmptyDescription
│   │   └── test_createExpense_revertsWhenNotCommuneOS
│   │
│   ├── markExpensePaid
│   │   ├── test_markExpensePaid_success
│   │   ├── test_markExpensePaid_setsPaidTrue
│   │   ├── test_markExpensePaid_emitsExpensePaidEvent
│   │   ├── test_markExpensePaid_revertsWithInvalidExpenseId
│   │   ├── test_markExpensePaid_revertsWhenAlreadyPaid
│   │   └── test_markExpensePaid_revertsWhenNotCommuneOS
│   │
│   ├── markExpenseDisputed
│   │   ├── test_markExpenseDisputed_success
│   │   ├── test_markExpenseDisputed_setsDisputedTrue
│   │   ├── test_markExpenseDisputed_linksDisputeId
│   │   ├── test_markExpenseDisputed_emitsExpenseDisputedEvent
│   │   ├── test_markExpenseDisputed_revertsWithInvalidExpenseId
│   │   └── test_markExpenseDisputed_revertsWhenNotCommuneOS
│   │
│   ├── reassignExpense
│   │   ├── test_reassignExpense_success
│   │   ├── test_reassignExpense_updatesAssignedTo
│   │   ├── test_reassignExpense_resetsPaidStatus
│   │   ├── test_reassignExpense_emitsExpenseReassignedEvent
│   │   ├── test_reassignExpense_emitsEventWithOldAndNewAssignee
│   │   ├── test_reassignExpense_revertsWithInvalidExpenseId
│   │   ├── test_reassignExpense_revertsWithZeroAddress
│   │   └── test_reassignExpense_revertsWhenNotCommuneOS
│   │
│   ├── isExpensePaid
│   │   ├── test_isExpensePaid_returnsTrueWhenPaid
│   │   ├── test_isExpensePaid_returnsFalseWhenUnpaid
│   │   ├── test_isExpensePaid_returnsFalseAfterReassignment
│   │   └── test_isExpensePaid_revertsWithInvalidExpenseId
│   │
│   ├── getExpenseStatus
│   │   ├── test_getExpenseStatus_returnsCompleteData
│   │   ├── test_getExpenseStatus_returnsId
│   │   ├── test_getExpenseStatus_returnsCommuneId
│   │   ├── test_getExpenseStatus_returnsAmount
│   │   ├── test_getExpenseStatus_returnsDescription
│   │   ├── test_getExpenseStatus_returnsAssignedTo
│   │   ├── test_getExpenseStatus_returnsDueDate
│   │   ├── test_getExpenseStatus_returnsPaidStatus
│   │   ├── test_getExpenseStatus_returnsDisputedStatus
│   │   └── test_getExpenseStatus_revertsWithInvalidExpenseId
│   │
│   ├── getCommuneExpenses
│   │   ├── test_getCommuneExpenses_returnsAllForCommune
│   │   ├── test_getCommuneExpenses_returnsEmptyForNewCommune
│   │   ├── test_getCommuneExpenses_filtersCorrectly
│   │   ├── test_getCommuneExpenses_separatePerCommune
│   │   ├── test_getCommuneExpenses_handlesMultipleExpenses
│   │   └── test_getCommuneExpenses_O_n_complexity
│   │
│   ├── getExpenseAssignee
│   │   ├── test_getExpenseAssignee_returnsCorrectAddress
│   │   ├── test_getExpenseAssignee_updatesAfterReassignment
│   │   └── test_getExpenseAssignee_revertsWithInvalidExpenseId
│   │
│   └── Access Control
│       ├── test_onlyCommuneOS_createExpense
│       ├── test_onlyCommuneOS_markExpensePaid
│       ├── test_onlyCommuneOS_markExpenseDisputed
│       ├── test_onlyCommuneOS_reassignExpense
│       └── test_communeOSCanCallAll
│
└── Fuzz Tests
    ├── fuzz_createExpense_variousAmounts
    ├── fuzz_createExpense_variousDescriptions
    ├── fuzz_createExpense_variousDueDates
    ├── fuzz_createExpense_multipleExpenses
    ├── fuzz_markExpensePaid_variousExpenseIds
    ├── fuzz_reassignExpense_variousAssignees
    ├── fuzz_reassignExpense_multipleTimes
    ├── fuzz_getCommuneExpenses_variousCommuneSizes
    ├── fuzz_integration_expenseLifecycle
    └── fuzz_integration_multiCommuneExpenses
```
