# V2-V3 Migration helper for AAVE

This repository contains [MigrationHelper](./src/contracts/MigrationHelper.sol) contract, which aim is to migrate positions from AAVE V2 to AAVE v3.
The contract is able to migrate both positions with supplies only and with dept.

1. To migrate positions without debt use the `migrateNoBorow()` method. The user and the list of supplied positions must be passed; if each of the supplied assets is not approved for the MigrationHelper contract in advance, then the list of permits should be passed as well.

2. Migration of the debt is based on the possibility of [AAVE flashloans](https://docs.aave.com/developers/guides/flash-loans) to be taken with variable debt mode. MigrationHelper contract implements `executeOperation` method of [IFlashLoanSimpleReceiver](https://github.com/aave/aave-v3-core/blob/master/contracts/flashloan/interfaces/IFlashLoanSimpleReceiver.sol) interface to repay the debt on v2 and migrate supplies to v3. Example of the position with the debt [is available in the tests](./tests/MigrationHelper.t.sol#L175).
   The general flow of the migration is:

   - approve supplies for MigrationHelper or calculate permits
   - initiate the flashloan with MigrationHelper as receiver and variable mode for every asset
   - pass supplied positions and ones to repay as params
   - the `executeOperation()` method is called via the flashloan; it repays V2 debt and migrates supplies to V3
   - flashloan debt stays on V3 in variable mode

3. To save the gas `cacheATokens()` method caches mapping of the assets to appropriate aTokens upon MigrationHelper creation. It is also possible to perform a recache anytime if new assets will be added to the market.

# Deployment

[MigrationHelperPolygon.s.sol](./scripts/MigrationHelperPolygon.s.sol): This script will deploy the MigrationHelper initialized with V3 Pool and V2 Pool on Polygon network.
[MigrationHelperAvalanche.s.sol](./scripts/MigrationHelperAvalanche.s.sol): This script will deploy the MigrationHelper initialized with V3 Pool and V2 Pool on Avalanche network.
[MigrationHelperMainnet.s.sol](./scripts/MigrationHelperMainnet.s.sol): This script will deploy the MigrationHelper initialized with V3 Pool and V2 Pool on Ethereum Mainnet network.

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
