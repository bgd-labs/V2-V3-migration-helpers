// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';

import {AaveV2Ethereum} from 'aave-address-book/AaveV2Ethereum.sol';
import {IPoolAddressesProvider} from 'aave-address-book/AaveV3.sol';

import {MigrationHelperMainnet} from '../src/contracts/MigrationHelperMainnet.sol';

contract Deploy is Script {
  function run() external {
    vm.startBroadcast();
    new MigrationHelperMainnet(
      IPoolAddressesProvider(0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e),
      AaveV2Ethereum.POOL
    );
    vm.stopBroadcast();
  }
}
