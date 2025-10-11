# VotingModule Contract Test Suite

## Test Structure

```
VotingModule Tests
├── Unit Tests
│   ├── createDispute
│   │   ├── test_createDispute_success
│   │   ├── test_createDispute_incrementsDisputeCount
│   │   ├── test_createDispute_returnsDisputeId
│   │   ├── test_createDispute_storesExpenseId
│   │   ├── test_createDispute_storesProposedAssignee
│   │   ├── test_createDispute_initializesVoteCounters
│   │   ├── test_createDispute_setsCreatedTimestamp
│   │   ├── test_createDispute_emitsEvent
│   │   ├── test_createDispute_revertsWithZeroAddress
│   │   └── test_createDispute_revertsWhenNotCommuneOS
│   │
│   ├── voteOnDispute
│   │   ├── test_voteOnDispute_votesFor
│   │   ├── test_voteOnDispute_votesAgainst
│   │   ├── test_voteOnDispute_incrementsVotesFor
│   │   ├── test_voteOnDispute_incrementsVotesAgainst
│   │   ├── test_voteOnDispute_marksVoterAsVoted
│   │   ├── test_voteOnDispute_recordsVoteChoice
│   │   ├── test_voteOnDispute_emitsVoteCastEvent
│   │   ├── test_voteOnDispute_revertsWithInvalidDisputeId
│   │   ├── test_voteOnDispute_revertsWhenAlreadyResolved
│   │   ├── test_voteOnDispute_revertsWhenAlreadyVoted
│   │   └── test_voteOnDispute_revertsWhenNotCommuneOS
│   │
│   ├── voteOnDispute (Auto-Resolution)
│   │   ├── test_voteOnDispute_autoResolvesWhen2_3VoteFor
│   │   ├── test_voteOnDispute_autoResolvesWhen2_3VoteAgainst
│   │   ├── test_voteOnDispute_setsUpheldTrueOn2_3For
│   │   ├── test_voteOnDispute_setsUpheldFalseOn2_3Against
│   │   ├── test_voteOnDispute_emitsDisputeResolvedEvent
│   │   ├── test_voteOnDispute_doesNotResolveBeforeMajority
│   │   ├── test_voteOnDispute_calculatesRequiredVotesCorrectly
│   │   ├── test_voteOnDispute_handlesExact2_3Majority
│   │   ├── test_voteOnDispute_with3Members_requires2Votes
│   │   ├── test_voteOnDispute_with6Members_requires4Votes
│   │   └── test_voteOnDispute_roundsDownFor2_3Calculation
│   │
│   ├── getDispute
│   │   ├── test_getDispute_returnsCompleteData
│   │   ├── test_getDispute_returnsExpenseId
│   │   ├── test_getDispute_returnsProposedAssignee
│   │   ├── test_getDispute_returnsVoteCounts
│   │   ├── test_getDispute_returnsResolvedStatus
│   │   ├── test_getDispute_returnsUpheldStatus
│   │   ├── test_getDispute_returnsCreatedTimestamp
│   │   └── test_getDispute_revertsWithInvalidDisputeId
│   │
│   ├── hasVotedOnDispute
│   │   ├── test_hasVotedOnDispute_returnsTrueAfterVoting
│   │   ├── test_hasVotedOnDispute_returnsFalseBeforeVoting
│   │   ├── test_hasVotedOnDispute_tracksMultipleVoters
│   │   └── test_hasVotedOnDispute_separateForEachDispute
│   │
│   ├── tallyVotes
│   │   ├── test_tallyVotes_returnsZeroInitially
│   │   ├── test_tallyVotes_returnsCorrectVotesFor
│   │   ├── test_tallyVotes_returnsCorrectVotesAgainst
│   │   ├── test_tallyVotes_returnsBothCounts
│   │   ├── test_tallyVotes_updatesAfterEachVote
│   │   └── test_tallyVotes_revertsWithInvalidDisputeId
│   │
│   └── Access Control
│       ├── test_onlyCommuneOS_createDispute
│       ├── test_onlyCommuneOS_voteOnDispute
│       └── test_communeOSCanCallAll
│
└── Fuzz Tests
    ├── fuzz_createDispute_multipleDisputes
    ├── fuzz_voteOnDispute_variousMemberCounts
    ├── fuzz_voteOnDispute_variousVotingPatterns
    ├── fuzz_voteOnDispute_2_3MajorityEdgeCases
    ├── fuzz_voteOnDispute_requiredVotesCalculation
    ├── fuzz_hasVotedOnDispute_multipleVoters
    ├── fuzz_tallyVotes_variousVoteCombinations
    ├── fuzz_integration_multipleDisputesVoting
    └── fuzz_integration_sequentialDisputeResolution
```
