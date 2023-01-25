// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';

import {AaveV2Avalanche} from 'aave-address-book/AaveV2Avalanche.sol';
import {AaveV3Avalanche} from 'aave-address-book/AaveV3Avalanche.sol';

import {MigrationHelper} from '../src/contracts/MigrationHelper.sol';

contract Deploy is Script {
  function run() external {
    vm.startBroadcast();
    new MigrationHelper(AaveV3Avalanche.POOL, AaveV2Avalanche.POOL);
    vm.stopBroadcast();
  }
}
