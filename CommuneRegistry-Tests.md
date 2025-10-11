# CommuneRegistry Contract Test Suite

## Test Structure

```
CommuneRegistry Tests
├── Unit Tests
│   ├── Constructor
│   │   ├── test_constructor_initializesCommuneCount
│   │   └── test_constructor_startsAtOne
│   │
│   ├── createCommune
│   │   ├── test_createCommune_success
│   │   ├── test_createCommune_withCollateralRequired
│   │   ├── test_createCommune_withoutCollateralRequired
│   │   ├── test_createCommune_incrementsCommuneId
│   │   ├── test_createCommune_storesName
│   │   ├── test_createCommune_storesCreator
│   │   ├── test_createCommune_storesCollateralSettings
│   │   ├── test_createCommune_emitsCommuneCreatedEvent
│   │   ├── test_createCommune_returnsCommuneId
│   │   ├── test_createCommune_revertsWithEmptyName
│   │   ├── test_createCommune_revertsWithZeroAddressCreator
│   │   ├── test_createCommune_revertsWithZeroCollateralWhenRequired
│   │   └── test_createCommune_revertsWhenNotCommuneOS
│   │
│   ├── validateInvite
│   │   ├── test_validateInvite_validSignature
│   │   ├── test_validateInvite_returnsTrueForValid
│   │   ├── test_validateInvite_returnsFalseForInvalidSignature
│   │   ├── test_validateInvite_checksCreatorSignature
│   │   ├── test_validateInvite_verifiesNonceNotUsed
│   │   ├── test_validateInvite_revertsWithInvalidCommuneId
│   │   ├── test_validateInvite_revertsWithUsedNonce
│   │   └── test_validateInvite_doesNotMarkNonceAsUsed
│   │
│   ├── markNonceUsed
│   │   ├── test_markNonceUsed_success
│   │   ├── test_markNonceUsed_preventsReuse
│   │   ├── test_markNonceUsed_revertsWithInvalidCommuneId
│   │   ├── test_markNonceUsed_revertsWithUsedNonce
│   │   └── test_markNonceUsed_revertsWhenNotCommuneOS
│   │
│   ├── getCommune
│   │   ├── test_getCommune_returnsCompleteData
│   │   ├── test_getCommune_returnsId
│   │   ├── test_getCommune_returnsName
│   │   ├── test_getCommune_returnsCreator
│   │   ├── test_getCommune_returnsCollateralRequired
│   │   ├── test_getCommune_returnsCollateralAmount
│   │   └── test_getCommune_revertsWithInvalidCommuneId
│   │
│   ├── isNonceUsed
│   │   ├── test_isNonceUsed_returnsTrueWhenUsed
│   │   ├── test_isNonceUsed_returnsFalseWhenNotUsed
│   │   ├── test_isNonceUsed_tracksPerCommune
│   │   └── test_isNonceUsed_separateNonceSpaces
│   │
│   ├── Signature Validation (EIP-191)
│   │   ├── test_getMessageHash_createsCorrectHash
│   │   ├── test_getEthSignedMessageHash_addsEIP191Prefix
│   │   ├── test_recoverSigner_recoversCorrectAddress
│   │   ├── test_splitSignature_splitsCorrectly
│   │   ├── test_splitSignature_extractsR
│   │   ├── test_splitSignature_extractsS
│   │   ├── test_splitSignature_extractsV
│   │   ├── test_splitSignature_revertsWithWrongLength
│   │   └── test_signatureVerification_endToEnd
│   │
│   └── Access Control
│       ├── test_onlyCommuneOS_createCommune
│       ├── test_onlyCommuneOS_markNonceUsed
│       └── test_communeOSCanCallAll
│
└── Fuzz Tests
    ├── fuzz_createCommune_variousNames
    ├── fuzz_createCommune_variousCollateralAmounts
    ├── fuzz_validateInvite_variousNonces
    ├── fuzz_validateInvite_variousSignatures
    ├── fuzz_markNonceUsed_multipleNonces
    ├── fuzz_signatureValidation_randomKeys
    ├── fuzz_signatureValidation_wrongSigners
    ├── fuzz_integration_multipleCommunes
    └── fuzz_integration_inviteWorkflow
```
