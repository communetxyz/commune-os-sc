# ChoreScheduler Contract Test Suite

## Test Structure

```
ChoreScheduler Tests
├── Unit Tests
│   ├── addChores
│   │   ├── test_addChores_singleChore
│   │   ├── test_addChores_multipleChores
│   │   ├── test_addChores_assignsSequentialIds
│   │   ├── test_addChores_emitsChoreCreatedEvents
│   │   ├── test_addChores_storesScheduleData
│   │   ├── test_addChores_revertsWithEmptyArray
│   │   ├── test_addChores_revertsWithZeroFrequency
│   │   ├── test_addChores_revertsWithEmptyTitle
│   │   ├── test_addChores_revertsWithZeroStartTime
│   │   └── test_addChores_revertsWhenNotCommuneOS
│   │
│   ├── markChoreComplete
│   │   ├── test_markChoreComplete_success
│   │   ├── test_markChoreComplete_marksCurrentPeriod
│   │   ├── test_markChoreComplete_emitsEvent
│   │   ├── test_markChoreComplete_allowsMultiplePeriods
│   │   ├── test_markChoreComplete_revertsWithInvalidChoreId
│   │   ├── test_markChoreComplete_revertsWhenAlreadyCompleted
│   │   └── test_markChoreComplete_revertsWhenNotCommuneOS
│   │
│   ├── getCurrentPeriod
│   │   ├── test_getCurrentPeriod_beforeStart
│   │   ├── test_getCurrentPeriod_atStartTime
│   │   ├── test_getCurrentPeriod_firstPeriod
│   │   ├── test_getCurrentPeriod_multiplePeriods
│   │   ├── test_getCurrentPeriod_calculatesCorrectly
│   │   ├── test_getCurrentPeriod_withDifferentFrequencies
│   │   └── test_getCurrentPeriod_revertsWithInvalidChoreId
│   │
│   ├── isChoreComplete
│   │   ├── test_isChoreComplete_returnsTrueWhenComplete
│   │   ├── test_isChoreComplete_returnsFalseWhenIncomplete
│   │   ├── test_isChoreComplete_checksPreviousPeriods
│   │   ├── test_isChoreComplete_checksCurrentPeriod
│   │   └── test_isChoreComplete_checksFuturePeriods
│   │
│   ├── getChoreSchedules
│   │   ├── test_getChoreSchedules_returnsAllSchedules
│   │   ├── test_getChoreSchedules_returnsEmptyForNewCommune
│   │   ├── test_getChoreSchedules_returnsCorrectData
│   │   └── test_getChoreSchedules_afterMultipleAdditions
│   │
│   ├── getCurrentChores
│   │   ├── test_getCurrentChores_returnsSchedules
│   │   ├── test_getCurrentChores_returnsPeriods
│   │   ├── test_getCurrentChores_returnsCompletionStatus
│   │   ├── test_getCurrentChores_handlesEmptyChoreList
│   │   └── test_getCurrentChores_handlesMultipleChores
│   │
│   ├── setChoreAssignee
│   │   ├── test_setChoreAssignee_setsOverride
│   │   ├── test_setChoreAssignee_emitsEvent
│   │   ├── test_setChoreAssignee_clearOverrideWithZeroAddress
│   │   ├── test_setChoreAssignee_revertsWithInvalidChoreId
│   │   └── test_setChoreAssignee_revertsWhenNotCommuneOS
│   │
│   ├── getChoreAssignee
│   │   ├── test_getChoreAssignee_returnsOverride
│   │   ├── test_getChoreAssignee_returnsRotationWhenNoOverride
│   │   ├── test_getChoreAssignee_rotatesBasedOnPeriod
│   │   ├── test_getChoreAssignee_handlesMultipleMembers
│   │   ├── test_getChoreAssignee_revertsWithInvalidChoreId
│   │   └── test_getChoreAssignee_revertsWithNoMembers
│   │
│   ├── getAssignedMemberIndex
│   │   ├── test_getAssignedMemberIndex_calculatesCorrectly
│   │   ├── test_getAssignedMemberIndex_handlesPeriodZero
│   │   ├── test_getAssignedMemberIndex_rotatesProperly
│   │   ├── test_getAssignedMemberIndex_withDifferentMemberCounts
│   │   └── test_getAssignedMemberIndex_revertsWithZeroMembers
│   │
│   └── Access Control
│       ├── test_onlyCommuneOS_addChores
│       ├── test_onlyCommuneOS_markChoreComplete
│       ├── test_onlyCommuneOS_setChoreAssignee
│       └── test_communeOSCanCallAll
│
└── Fuzz Tests
    ├── fuzz_addChores_variousScheduleLengths
    ├── fuzz_addChores_variousFrequencies
    ├── fuzz_addChores_variousStartTimes
    ├── fuzz_markChoreComplete_multiplePeriods
    ├── fuzz_getCurrentPeriod_variousTimestamps
    ├── fuzz_getCurrentPeriod_variousFrequencies
    ├── fuzz_getChoreAssignee_variousMemberCounts
    ├── fuzz_getChoreAssignee_variousPeriods
    ├── fuzz_getAssignedMemberIndex_rotationPattern
    ├── fuzz_integration_choreLifecycle
    └── fuzz_integration_multipleCommunes
```
