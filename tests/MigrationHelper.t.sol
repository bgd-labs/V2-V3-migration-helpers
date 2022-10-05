// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';

import {AaveV2Polygon} from 'aave-address-book/AaveV2Polygon.sol';
import {AaveV3Polygon} from 'aave-address-book/AaveV3Polygon.sol';

import {IERC20} from 'solidity-utils/contracts/oz-common/interfaces/IERC20.sol';
import {DataTypes, IAaveProtocolDataProvider} from 'aave-address-book/AaveV2.sol';
import {IAaveProtocolDataProvider as IAaveProtocolDataProviderV3} from 'aave-address-book/AaveV3.sol';

import {MigrationHelper, IMigrationHelper, IERC20WithPermit} from '../src/contracts/MigrationHelper.sol';

contract MigrationHelperTest is Test {
  IAaveProtocolDataProvider public v2DataProvider;
  IAaveProtocolDataProviderV3 public v3DataProvider;
  MigrationHelper public migrationHelper;

  address[] public usersSimple;
  address[] public usersWithDebt;
  address[] public v2Reserves;

  mapping(address => uint256) private assetsIndex;

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('polygon'), 33920075);
    migrationHelper = new MigrationHelper(
      AaveV3Polygon.POOL_ADDRESSES_PROVIDER,
      AaveV2Polygon.POOL
    );

    v2DataProvider = AaveV2Polygon.AAVE_PROTOCOL_DATA_PROVIDER;
    v3DataProvider = AaveV3Polygon.AAVE_PROTOCOL_DATA_PROVIDER;
    v2Reserves = migrationHelper.V2_POOL().getReservesList();

    usersSimple = new address[](17);
    usersSimple[0] = 0x5FFAcBDaA5754224105879c03392ef9FE6ae0c17;
    usersSimple[1] = 0x5d3f81Ad171616571BF3119a3120E392B914Fd7C;
    usersSimple[2] = 0x07F294e84a9574f657A473f94A242F1FdFAFB823;
    usersSimple[3] = 0x7734280A4337F37Fbf4651073Db7c28C80B339e9;
    usersSimple[4] = 0x000000003853FCeDcd0355feC98cA3192833F00b;
    usersSimple[5] = 0xbeC1101FF3f3474A3789Bb18A88117C169178d9F;
    usersSimple[6] = 0xc2132D05D31c914a87C6611C10748AEb04B58e8F;
    usersSimple[7] = 0x004C572659319871bE9D4ab337fB3Df6237979D7;
    usersSimple[8] = 0x0134af0F5cf7C32128231deA65B52Bb892780bae;
    usersSimple[9] = 0x0040a8fbD83A82c0742923C6802C3d9a22128d1c;
    usersSimple[10] = 0x00F63722233F5e19010e5daF208472A8F27D304B;
    usersSimple[11] = 0x114558d984bb24FDDa0CD279Ffd5F073F2d44F49;
    usersSimple[12] = 0x17B23Be942458E6EfC17F000976A490EC428f49A;
    usersSimple[13] = 0x7c0714297f15599E7430332FE45e45887d7Da341;
    usersSimple[14] = 0x1776Fd7CCf75C889d62Cd03B5116342EB13268Bc;
    usersSimple[15] = 0x53498839353845a30745b56a22524Df934F746dE;
    usersSimple[16] = 0x3126ffE1334d892e0c53d8e2Fc83a605DcDCf037;

    usersWithDebt = new address[](7);
    usersWithDebt[0] = 0x0044DB9F44991AB259c1800c723d3980150F58BB;
    usersWithDebt[1] = 0x07c9fac7a77f98c9cf28D84733e28912C44Cb467;
    usersWithDebt[2] = 0x02ccbf14d05Af1bBA1C85C0E4EBe34450B4BC3A1;
    usersWithDebt[3] = 0x022cF8fCF32A0Af972cb723D82E0120b43c79af0;
    usersWithDebt[4] = 0xe8A4160978d875AD2B9E8A5829693baC89F6f985;
    usersWithDebt[5] = 0x4303Ddc9943D862f2B205aF468a4A786c5137E76;
    usersWithDebt[6] = 0x01746f0a55811602F0EEA0DeF665C7086fc5eB3D;
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

      uint256 allowanceToPoolV2 = IERC20(v2Reserves[i]).allowance(
        address(migrationHelper),
        address(migrationHelper.V2_POOL())
      );
      assertEq(allowanceToPoolV2, type(uint256).max);

      uint256 allowanceToPool = IERC20(v2Reserves[i]).allowance(
        address(migrationHelper),
        address(migrationHelper.POOL())
      );
      assertEq(allowanceToPool, type(uint256).max);
    }
  }

  function testMigrationNoBorrowNoPermit() public {
    address[] memory suppliedPositions;
    uint256[] memory suppliedBalances;
    IMigrationHelper.RepayInput[] memory borrowedPositions;

    for (uint256 i = 0; i < usersSimple.length; i++) {
      // get positions
      (
        suppliedPositions,
        suppliedBalances,
        borrowedPositions
      ) = _getV2UserPosition(usersSimple[i]);

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

      _checkMigratedSupplies(
        usersSimple[i],
        suppliedPositions,
        suppliedBalances
      );
    }
  }

  function testMigrationBorrowNoPermit() public {
    address[] memory suppliedPositions;
    uint256[] memory suppliedBalances;
    IMigrationHelper.RepayInput[] memory borrowedPositions;
    address[] memory borrowedAssets;
    uint256[] memory borrowedAmounts;
    uint256[] memory interestRateModes;
    IMigrationHelper.PermitInput[] memory permits;

    for (uint256 i = 0; i < usersWithDebt.length; i++) {
      //     // get positions
      (
        suppliedPositions,
        suppliedBalances,
        borrowedPositions
      ) = _getV2UserPosition(usersWithDebt[i]);

      require(
        borrowedPositions.length != 0 && suppliedPositions.length != 0,
        'BAD_USER_FOR_THIS_TEST'
      );

      (
        borrowedAssets,
        borrowedAmounts,
        interestRateModes
      ) = _getFlashloanParams(borrowedPositions);

      vm.startPrank(usersWithDebt[i]);

      // approve aTokens to helper
      for (uint256 j = 0; j < suppliedPositions.length; j++) {
        migrationHelper.aTokens(suppliedPositions[j]).approve(
          address(migrationHelper),
          type(uint256).max
        );
      }

      migrationHelper.POOL().flashLoan(
        address(migrationHelper),
        borrowedAssets,
        borrowedAmounts,
        interestRateModes,
        usersWithDebt[i],
        abi.encode(suppliedPositions, borrowedPositions, permits),
        0
      );

      vm.stopPrank();

      _checkMigratedSupplies(
        usersWithDebt[i],
        suppliedPositions,
        suppliedBalances
      );

      _checkMigratedBorrowings(usersWithDebt[i], borrowedPositions);
    }
  }

  function _checkMigratedSupplies(
    address user,
    address[] memory supliedPositions,
    uint256[] memory suppliedBalances
  ) internal {
    for (uint256 i = 0; i < supliedPositions.length; i++) {
      (uint256 currentATokenBalance, , , , , , , , ) = v3DataProvider
        .getUserReserveData(supliedPositions[i], user);

      assertTrue(currentATokenBalance >= suppliedBalances[i]);
    }
  }

  function _checkMigratedBorrowings(
    address user,
    IMigrationHelper.RepayInput[] memory borrowedPositions
  ) internal {
    for (uint256 i = 0; i < borrowedPositions.length; i++) {
      (, , uint256 currentVariableDebt, , , , , , ) = v3DataProvider
        .getUserReserveData(borrowedPositions[i].asset, user);

      assertTrue(currentVariableDebt >= borrowedPositions[i].amount);
    }
  }

  function _getV2UserPosition(address user)
    internal
    view
    returns (
      address[] memory,
      uint256[] memory,
      IMigrationHelper.RepayInput[] memory
    )
  {
    uint256 numberOfSupplied;
    uint256 numberOfBorrowed;
    address[] memory suppliedPositions = new address[](v2Reserves.length);
    uint256[] memory suppliedBalances = new uint256[](v2Reserves.length);
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
        suppliedBalances[numberOfSupplied] = currentATokenBalance;
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
      mstore(suppliedBalances, numberOfSupplied)
      mstore(borrowedPositions, numberOfBorrowed)
    }

    return (suppliedPositions, suppliedBalances, borrowedPositions);
  }

  function _getFlashloanParams(
    IMigrationHelper.RepayInput[] memory borrowedPositions
  )
    internal
    returns (
      address[] memory,
      uint256[] memory,
      uint256[] memory
    )
  {
    address[] memory borrowedAssets = new address[](borrowedPositions.length);
    uint256[] memory borrowedAmounts = new uint256[](borrowedPositions.length);
    uint256[] memory interestRateModes = new uint256[](
      borrowedPositions.length
    );
    uint256 index = 0;

    for (uint256 i = 0; i < borrowedPositions.length; i++) {
      address asset = borrowedPositions[i].asset;
      uint256 amount = borrowedPositions[i].amount;

      uint256 existingIndex = assetsIndex[asset];

      if (existingIndex > 0) {
        borrowedAmounts[existingIndex - 1] += amount;
      } else {
        assetsIndex[asset] = index + 1;
        borrowedAssets[index] = asset;
        borrowedAmounts[index] = amount;
        interestRateModes[index] = 2;
        index++;
      }
    }

    // clean mapping
    for (uint256 i = 0; i < borrowedAssets.length; i++) {
      delete assetsIndex[borrowedAssets[i]];
    }

    assembly {
      mstore(borrowedAssets, index)
      mstore(borrowedAmounts, index)
      mstore(interestRateModes, index)
    }

    return (borrowedAssets, borrowedAmounts, interestRateModes);
  }
}
