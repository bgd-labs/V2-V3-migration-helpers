// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';
import {MigrationHelper} from '../src/contracts/MigrationHelper.sol';

contract Deploy is Script {
  function run() external {
    vm.startBroadcast();
    new MigrationHelper();
    vm.stopBroadcast();
  }
}
