// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';

import {AaveV2Polygon} from 'aave-address-book/AaveV2Polygon.sol';
import {AaveV3Polygon} from 'aave-address-book/AaveV3Polygon.sol';

import {MigrationHelper} from '../src/contracts/MigrationHelper.sol';

contract Deploy is Script {
  function run() external {
    vm.startBroadcast();
    new MigrationHelper(AaveV3Polygon.POOL, AaveV2Polygon.POOL);
    vm.stopBroadcast();
  }
}
