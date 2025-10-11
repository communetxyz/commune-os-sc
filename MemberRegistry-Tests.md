# MemberRegistry Contract Test Suite

## Test Structure

```
MemberRegistry Tests
├── Unit Tests
│   ├── registerMember
│   │   ├── test_registerMember_success
│   │   ├── test_registerMember_addsToCommuneMembers
│   │   ├── test_registerMember_setsMemberCommuneId
│   │   ├── test_registerMember_setsActiveTrue
│   │   ├── test_registerMember_emitsMemberRegisteredEvent
│   │   ├── test_registerMember_revertsWithZeroAddress
│   │   ├── test_registerMember_revertsWhenAlreadyRegistered
│   │   ├── test_registerMember_allowsDifferentCommuneMembers
│   │   └── test_registerMember_revertsWhenNotCommuneOS
│   │
│   ├── isMember
│   │   ├── test_isMember_returnsTrueForMember
│   │   ├── test_isMember_returnsFalseForNonMember
│   │   ├── test_isMember_returnsFalseForZeroCommuneId
│   │   ├── test_isMember_returnsFalseForDifferentCommune
│   │   ├── test_isMember_checksSentinelValue
│   │   └── test_isMember_handlesMultipleCommunes
│   │
│   ├── areMembers
│   │   ├── test_areMembers_returnsCorrectArray
│   │   ├── test_areMembers_handlesMixedMembers
│   │   ├── test_areMembers_handlesAllMembers
│   │   ├── test_areMembers_handlesAllNonMembers
│   │   ├── test_areMembers_handlesEmptyArray
│   │   └── test_areMembers_efficientBatchCheck
│   │
│   ├── getCommuneMembers
│   │   ├── test_getCommuneMembers_returnsAllAddresses
│   │   ├── test_getCommuneMembers_returnsEmptyForNewCommune
│   │   ├── test_getCommuneMembers_returnsCorrectOrder
│   │   ├── test_getCommuneMembers_handlesMultipleMembers
│   │   └── test_getCommuneMembers_separatePerCommune
│   │
│   ├── getMemberCount
│   │   ├── test_getMemberCount_returnsZeroForNewCommune
│   │   ├── test_getMemberCount_returnsCorrectCount
│   │   ├── test_getMemberCount_incrementsAfterRegistration
│   │   └── test_getMemberCount_separatePerCommune
│   │
│   ├── getMemberStatus
│   │   ├── test_getMemberStatus_returnsCompleteData
│   │   ├── test_getMemberStatus_returnsWalletAddress
│   │   ├── test_getMemberStatus_returnsCommuneId
│   │   ├── test_getMemberStatus_returnsActiveStatus
│   │   ├── test_getMemberStatus_revertsForNonMember
│   │   └── test_getMemberStatus_revertsForZeroAddress
│   │
│   ├── Sentinel Value Logic
│   │   ├── test_sentinelValue_communeIdsStartAtOne
│   │   ├── test_sentinelValue_zeroMeansNotRegistered
│   │   ├── test_sentinelValue_preventsZeroCommuneIdCheck
│   │   └── test_sentinelValue_worksWith_isMember
│   │
│   └── Access Control
│       ├── test_onlyCommuneOS_registerMember
│       └── test_communeOSCanCall
│
└── Fuzz Tests
    ├── fuzz_registerMember_multipleMembers
    ├── fuzz_registerMember_multipleCommunesParallel
    ├── fuzz_isMember_variousAddresses
    ├── fuzz_areMembers_variousArraySizes
    ├── fuzz_areMembers_randomMembershipPatterns
    ├── fuzz_getCommuneMembers_variousCommuneSizes
    ├── fuzz_getMemberCount_afterRandomRegistrations
    ├── fuzz_getMemberStatus_variousMembers
    └── fuzz_integration_multiCommuneMembership
```
