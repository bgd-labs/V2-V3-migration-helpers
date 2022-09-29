// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {AaveV2Ethereum} from 'aave-address-book/AaveV2Ethereum.sol';
import {DataTypes} from 'aave-address-book/AaveV2.sol';

import {MigrationHelper} from '../src/contracts/MigrationHelper.sol';

contract MigrationHelperTest is Test {
  MigrationHelper public migrationHelper;

  function setUp() public {
    migrationHelper = new MigrationHelper();
  }

  function testCacheATokens() public {
    address[] memory reserves = AaveV2Ethereum.POOL.getReservesList();
    for (uint256 i = 0; i < reserves.length; i++) {
      DataTypes.ReserveData memory reserveData = AaveV2Ethereum
        .POOL
        .getReserveData(reserves[i]);
      assertEq(
        address(migrationHelper.aTokens(reserves[i])),
        reserveData.aTokenAddress
      );
    }
  }
}
