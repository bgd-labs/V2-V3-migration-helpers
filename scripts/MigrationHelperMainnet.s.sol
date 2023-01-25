// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';

import {MigrationHelperMainnet} from '../src/contracts/MigrationHelperMainnet.sol';

contract Deploy is Script {
  function run() external {
    vm.startBroadcast();
    new MigrationHelperMainnet();
    vm.stopBroadcast();
  }
}
