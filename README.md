# CommuneOS Smart Contracts

Smart contracts for managing communal living arrangements on Gnosis Chain.

## Overview

CommuneOS provides on-chain infrastructure for communes (shared living spaces) to manage:
- **Invite-based membership** with optional collateral requirements
- **Rotating chore schedules** with automatic assignment
- **Expense tracking** with direct assignment and dispute resolution
- **Transparent voting** with 2/3 majority auto-resolution

## Architecture

CommuneOS uses a modular architecture with 7 contracts:

- **CommuneOS** - Main orchestrator contract
- **CommuneRegistry** - Commune creation and invite validation
- **MemberRegistry** - Member tracking and batch operations
- **ChoreScheduler** - Period-based chore scheduling with rotation
- **ExpenseManager** - Expense lifecycle and disputes
- **VotingModule** - 2/3 majority voting for disputes
- **CollateralManager** - Collateral deposits (ETH or ERC20)

## Documentation

- **[SPEC.md](./SPEC.md)** - Complete technical specification
- **[QUICKSTART.md](./QUICKSTART.md)** - Quick start guide
- **Contracts** - All contracts have comprehensive NatSpec documentation

## Development

Built with [Foundry](https://book.getfoundry.sh/).

### Build

```bash
forge build
```

### Test

```bash
forge test
```

### Format

```bash
forge fmt
```

### Deploy

```bash
# Set environment variables
export PRIVATE_KEY=<your_private_key>
export COLLATERAL_TOKEN=<token_address_or_0x0_for_ETH>

# Deploy to testnet
forge script script/Deploy.s.sol:DeployScript \
  --rpc-url <rpc_url> \
  --broadcast
```

## Deployment

### Testnet (Holesky)
Automated deployment via GitHub Actions on PR and push to main.

### Production (Gnosis Chain)
Automated deployment via GitHub Actions on push to main.

See [.github/workflows](./.github/workflows) for CI/CD configuration.

## License

MIT
