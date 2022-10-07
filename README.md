# V2-V3 Migration helper for AAVE

This repository contains [MigrationHelper](./src/contracts/MigrationHelper.sol) contract, which aim is to migrate positions from AAVE V2 to AAVE v3.
The contract is able to migrate both positions with supplies only and with dept.

1. To migrate positions without debt use the `migrateNoBorow()` method. The user and the list of supplied positions must be passed; if each of the supplied assets is not approved for the MigrationHelper contract in advance, then the list of permits should be passed as well.

2. Migration of the debt is based on the possibility of [AAVE flashloans](https://docs.aave.com/developers/guides/flash-loans) to be taken with variable debt mode. MigrationHelper contract implements [IFlashLoanReceiver](./src/interfaces/IFlashLoanReceiver.sol) interface to repay the the debt on v2 and migrate supplies to v3. Example of the position with the debt [is available in the tests](./tests/MigrationHelper.t.sol#L175).
   The general flow of the migration is:

   - approve supplies for MigrationHelper or calculate permits
   - initiate the flashloan with MigrationHelper as receiver and variable mode for every asset
   - pass supplied positions and ones to repay as params
   - the `executeOperation()` method is called via the flashloan; it repays V2 debt and migrates supplies to V3
   - flashloan debt stays on V3 in variable mode

3. To save the gas `cacheATokens()` method caches mapping of the assets to appropriate aTokens upon MigrationHelper creation. It is also possible to perform a recache anytime if new assets will be added to the market.

# Deployment

[MigrationHelper.s.sol](./scripts/MigrationHelper.s.sol): This script will deploy the MigrationHelper initialized with V2 Pool and V3 Pool Address Provider.

# SetUp

This repo has forge and npm dependencies, so you will need to install foundry then run:

```
forge install
```

and also run:

```
npm i
```

# Tests

To run the tests just run:

```
forge test
```
