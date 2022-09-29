// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';

import {AaveV2Polygon} from 'aave-address-book/AaveV2Polygon.sol';
import {AaveV3Polygon} from 'aave-address-book/AaveV3Polygon.sol';

import {DataTypes, IAaveProtocolDataProvider} from 'aave-address-book/AaveV2.sol';

import {MigrationHelper, IMigrationHelper, IERC20WithPermit} from '../src/contracts/MigrationHelper.sol';

contract MigrationHelperTest is Test {
  IAaveProtocolDataProvider public v2DataProvider;
  MigrationHelper public migrationHelper;

  address[] public usersSimple;
  address[] public v2Reserves;

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('polygon'));
    migrationHelper = new MigrationHelper(
      AaveV3Polygon.POOL_ADDRESSES_PROVIDER,
      AaveV2Polygon.POOL
    );

    v2DataProvider = AaveV2Polygon.AAVE_PROTOCOL_DATA_PROVIDER;
    v2Reserves = migrationHelper.V2_POOL().getReservesList();

    usersSimple = new address[](4);
    usersSimple[0] = 0x5FFAcBDaA5754224105879c03392ef9FE6ae0c17;
    usersSimple[1] = 0x5d3f81Ad171616571BF3119a3120E392B914Fd7C;
    usersSimple[2] = 0x07F294e84a9574f657A473f94A242F1FdFAFB823;
    usersSimple[3] = 0x7734280A4337F37Fbf4651073Db7c28C80B339e9;
  }

  function testCacheATokens() public {
    for (uint256 i = 0; i < v2Reserves.length; i++) {
      DataTypes.ReserveData memory reserveData = migrationHelper
        .V2_POOL()
        .getReserveData(v2Reserves[i]);
      assertEq(
        address(migrationHelper.aTokens(v2Reserves[i])),
        reserveData.aTokenAddress
      );
    }
  }

  function testMigrationNoBorrowNoPermit() public {
    address[] memory suppliedPositions;
    IMigrationHelper.RepayInput[] memory borrowedPositions;

    for (uint256 i = 0; i < usersSimple.length; i++) {
      // get positions
      (suppliedPositions, borrowedPositions) = _getV2UserPosition(
        usersSimple[i]
      );
      require(
        borrowedPositions.length == 0 && suppliedPositions.length != 0,
        'BAD_USER_FOR_THIS_TEST'
      );

      vm.startPrank(usersSimple[i]);
      // TODO: add test with permit
      // approve aTokens to helper
      for (uint256 j = 0; j < suppliedPositions.length; j++) {
        migrationHelper.aTokens(suppliedPositions[j]).approve(
          address(migrationHelper),
          type(uint256).max
        );
      }
      vm.stopPrank();

      migrationHelper.migrationNoBorrow(
        usersSimple[i],
        suppliedPositions,
        new IMigrationHelper.PermitInput[](0)
      );
    }
  }

  function _getV2UserPosition(address user)
    internal
    view
    returns (address[] memory, IMigrationHelper.RepayInput[] memory)
  {
    uint256 numberOfSupplied;
    uint256 numberOfBorrowed;
    address[] memory suppliedPositions = new address[](v2Reserves.length);
    IMigrationHelper.RepayInput[]
      memory borrowedPositions = new IMigrationHelper.RepayInput[](
        v2Reserves.length * 2
      );
    for (uint256 i = 0; i < v2Reserves.length; i++) {
      (
        uint256 currentATokenBalance,
        uint256 currentStableDebt,
        uint256 currentVariableDebt,
        ,
        ,
        ,
        ,
        ,

      ) = v2DataProvider.getUserReserveData(v2Reserves[i], user);
      if (currentATokenBalance != 0) {
        suppliedPositions[numberOfSupplied] = v2Reserves[i];
        numberOfSupplied++;
      }
      if (currentStableDebt != 0) {
        borrowedPositions[numberOfBorrowed] = IMigrationHelper.RepayInput({
          asset: v2Reserves[i],
          amount: currentStableDebt,
          rateMode: 1
        });
        numberOfBorrowed++;
      }
      if (currentVariableDebt != 0) {
        borrowedPositions[numberOfBorrowed] = IMigrationHelper.RepayInput({
          asset: v2Reserves[i],
          amount: currentVariableDebt,
          rateMode: 2
        });
        numberOfBorrowed++;
      }
    }
    assembly {
      mstore(suppliedPositions, numberOfSupplied)
      mstore(borrowedPositions, numberOfBorrowed)
    }

    return (suppliedPositions, borrowedPositions);
  }
}
