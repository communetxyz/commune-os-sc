# Invite Generator Utility

## Overview

The `InviteGenerator` is a Solidity utility contract for generating cryptographic signatures that allow new members to join CommuneOS communes. It uses EIP-191 signature format to create secure, single-use invites.

## Usage

### Importing the Utility

```solidity
import "./InviteGenerator.s.sol";

InviteGenerator inviteGenerator = new InviteGenerator();
```

### Generating a Single Invite

```solidity
uint256 creatorPrivateKey = 0xYourPrivateKey; // Keep this secret!
uint256 communeId = 1;
uint256 nonce = 1; // Must be unique for each invite

bytes memory signature = inviteGenerator.generateInvite(
    creatorPrivateKey,
    communeId,
    nonce
);
```

### Generating Multiple Invites

```solidity
uint256[] memory nonces = new uint256[](3);
nonces[0] = 1;
nonces[1] = 2;
nonces[2] = 3;

bytes[] memory signatures = inviteGenerator.generateInvites(
    creatorPrivateKey,
    communeId,
    nonces
);
```

### Using the Invite to Join a Commune

Once you have a signature, share it with the person you want to invite:

```solidity
// Member receives the signature and nonce
communeOS.joinCommune(communeId, nonce, signature);
```

## Important Notes

### Security Considerations

1. **Private Key Protection**: Never expose your private key. This utility is meant for testing and script usage, not production key management.

2. **Nonce Uniqueness**: Each nonce can only be used once. After a member joins using a nonce, that nonce is marked as used and cannot be reused.

3. **Commune Specificity**: Signatures are bound to a specific commune ID. A signature for commune 1 cannot be used to join commune 2.

4. **Creator Verification**: Only signatures from the commune creator are valid. The system verifies that the signature was created by the commune's original creator.

### Best Practices

1. **Sequential Nonces**: Use sequential nonces (1, 2, 3...) for easier tracking.

2. **Secure Distribution**: Share invites (communeId, nonce, signature) through secure channels.

3. **Batch Generation**: When onboarding multiple members, generate all invites at once using `generateInvites()` for efficiency.

## Helper Functions

### Get Address from Private Key

```solidity
address creatorAddress = inviteGenerator.getAddressFromPrivateKey(creatorPrivateKey);
```

This helps verify which address corresponds to a private key before generating invites.

## Example: Complete Invite Flow

```solidity
// 1. Creator creates a commune
uint256 communeId = communeOS.createCommune("My Commune", true, 1 ether, schedules);

// 2. Creator generates invites for 3 new members
uint256[] memory nonces = new uint256[](3);
nonces[0] = 1;
nonces[1] = 2;
nonces[2] = 3;

bytes[] memory invites = inviteGenerator.generateInvites(
    creatorPrivateKey,
    communeId,
    nonces
);

// 3. Share invite data with each member:
//    - Member 1: communeId, nonces[0], invites[0]
//    - Member 2: communeId, nonces[1], invites[1]
//    - Member 3: communeId, nonces[2], invites[2]

// 4. Each member joins
// (Member 1)
token.approve(address(communeOS.collateralManager()), 1 ether);
communeOS.joinCommune(communeId, nonces[0], invites[0]);
```

## Testing

The utility includes comprehensive tests in `test/InviteGenerator.t.sol`:

```bash
forge test --match-contract InviteGeneratorTest -vv
```

Tests cover:
- Single invite generation
- Batch invite generation
- Invalid signer rejection
- Nonce reuse prevention
- Commune-specific validation
- Address derivation
- Message hash format verification
