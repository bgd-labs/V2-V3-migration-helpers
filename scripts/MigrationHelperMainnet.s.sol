// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';

import {MigrationHelperAmm} from '../src/contracts/MigrationHelperAmm.sol';
import {MigrationHelperMainnet} from '../src/contracts/MigrationHelperMainnet.sol';

import {MigrationHelper} from '../src/contracts/MigrationHelper.sol';
contract Deploy is Script {
  function run() external {
    vm.startBroadcast();
    new MigrationHelperMainnet();
    vm.stopBroadcast();
  }
}

contract DeployAmm is Script {
  function run() external {
    vm.startBroadcast();
    new MigrationHelperAmm();
    vm.stopBroadcast();
  }
}
