// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {console} from 'forge-std/console.sol';

import {AaveV3Polygon} from 'aave-address-book/AaveV3Polygon.sol';

import {IERC20} from 'solidity-utils/contracts/oz-common/interfaces/IERC20.sol';
import {ICreditDelegationToken} from '../src/interfaces/ICreditDelegationToken.sol';
import {IERC20WithATokenCompatibility} from './helpers/IERC20WithATokenCompatibility.sol';

import {DataTypes, IAaveProtocolDataProvider as IAaveProtocolDataProviderV3} from 'aave-address-book/AaveV3.sol';

import {MigrationHelperV3V3, IMigrationHelperV3V3, IMigrationHelper, IERC20WithPermit} from '../src/contracts/MigrationHelperV3V3.sol';

import {SigUtils} from './helpers/SigUtils.sol';

contract MigrationHelperTest is Test {
  IAaveProtocolDataProviderV3 public v3DataProvider;
  MigrationHelperV3V3 public migrationHelper;
  SigUtils public sigUtils;

  address public constant DAI = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;
  address public constant ETH = 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619;

  address[] public usersSimple;
  address[] public usersWithDebt;
  address[] public v3Reserves;

  mapping(address => uint256) private assetsIndex;

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('polygon'), 47967100);
    migrationHelper = new MigrationHelperV3V3(AaveV3Polygon.POOL, AaveV3Polygon.POOL);

    v3DataProvider = AaveV3Polygon.AAVE_PROTOCOL_DATA_PROVIDER;
    v3Reserves = migrationHelper.V3_SOURCE_POOL().getReservesList();

    sigUtils = new SigUtils();

    // @dev users who has only supplied positions, no borrowings
    usersSimple = new address[](1);
    usersSimple[0] = 0xeE071f4B516F69a1603dA393CdE8e76C40E5Be85;
  }

  function testCacheATokens() public {
    for (uint256 i = 0; i < v3Reserves.length; i++) {
      DataTypes.ReserveData memory reserveData = migrationHelper.V3_SOURCE_POOL().getReserveData(
        v3Reserves[i]
      );
      assertEq(address(migrationHelper.aTokens(v3Reserves[i])), reserveData.aTokenAddress);

      uint256 allowanceToPoolV3 = IERC20(v3Reserves[i]).allowance(
        address(migrationHelper),
        address(migrationHelper.V3_SOURCE_POOL())
      );
      assertEq(allowanceToPoolV3, type(uint256).max);

      uint256 allowanceToPool = IERC20(v3Reserves[i]).allowance(
        address(migrationHelper),
        address(migrationHelper.V3_TARGET_POOL())
      );
      assertEq(allowanceToPool, type(uint256).max);
    }
  }

  function testMigrationNoBorrowNoPermit() public {
    address[] memory suppliedPositions;
    uint256[] memory suppliedBalances;
    MigrationHelperV3V3.RepayInput[] memory borrowedPositions;

    for (uint256 i = 0; i < usersSimple.length; i++) {
      // get positions
      (suppliedPositions, suppliedBalances, borrowedPositions) = _getV3UserPosition(usersSimple[i]);

      require(
        borrowedPositions.length == 0 && suppliedPositions.length != 0,
        'BAD_USER_FOR_THIS_TEST'
      );

      vm.startPrank(usersSimple[i]);
      // approve aTokens to helper
      for (uint256 j = 0; j < suppliedPositions.length; j++) {
        migrationHelper.aTokens(suppliedPositions[j]).approve(
          address(migrationHelper),
          type(uint256).max
        );
      }

      // migrate positions to V3
      migrationHelper.migrate(
        suppliedPositions,
        new MigrationHelperV3V3.RepaySimpleInput[](0),
        new MigrationHelperV3V3.PermitInput[](0),
        new MigrationHelperV3V3.CreditDelegationInput[](0)
      );

      vm.stopPrank();

      // check that positions were migrated successfully
      _checkMigratedSupplies(usersSimple[i], suppliedPositions, suppliedBalances);
    }
  }

  function testMigrationNoBorrowWithPermit() public {
    (address user, uint256 privateKey) = _getUserWithPosition();

    // get positions
    (address[] memory suppliedPositions, uint256[] memory suppliedBalances, ) = _getV3UserPosition(
      user
    );

    // calculate permits
    MigrationHelperV3V3.PermitInput[] memory permits = _getPermits(
      user,
      privateKey,
      suppliedPositions,
      suppliedBalances
    );

    vm.startPrank(user);

    // migrate positions to V3
    migrationHelper.migrate(
      suppliedPositions,
      new MigrationHelperV3V3.RepaySimpleInput[](0),
      permits,
      new MigrationHelperV3V3.CreditDelegationInput[](0)
    );

    vm.stopPrank();

    // check that positions were migrated successfully
    _checkMigratedSupplies(user, suppliedPositions, suppliedBalances);
  }

  function testMigrationWithCreditDelegation() public {
    (address user, uint256 privateKey) = _getUserWithBorrowPosition();
    // get positions
    (
      address[] memory suppliedPositions,
      uint256[] memory suppliedBalances,
      MigrationHelperV3V3.RepayInput[] memory positionsToRepay
    ) = _getV3UserPosition(user);

    MigrationHelperV3V3.RepaySimpleInput[]
      memory positionsToRepaySimple = _getSimplePositionsToRepay(positionsToRepay);

    // calculate permits
    MigrationHelperV3V3.PermitInput[] memory permits = _getPermits(
      user,
      privateKey,
      suppliedPositions,
      suppliedBalances
    );

    // calculate credit
    MigrationHelperV3V3.CreditDelegationInput[] memory creditDelegations = _getCreditDelegations(
      user,
      privateKey,
      positionsToRepay
    );

    // migrate positions to V3
    vm.startPrank(user);

    migrationHelper.migrate(suppliedPositions, positionsToRepaySimple, permits, creditDelegations);

    vm.stopPrank();

    // check that positions were migrated successfully
    _checkMigratedSupplies(user, suppliedPositions, suppliedBalances);

    _checkMigratedBorrowings(user, positionsToRepay);
  }

  function _checkMigratedSupplies(
    address user,
    address[] memory suppliedPositions,
    uint256[] memory suppliedBalances
  ) internal {
    for (uint256 i = 0; i < suppliedPositions.length; i++) {
      (uint256 currentATokenBalance, , , , , , , , ) = v3DataProvider.getUserReserveData(
        suppliedPositions[i],
        user
      );

      assertTrue(currentATokenBalance >= suppliedBalances[i]);
    }
  }

  function _checkMigratedBorrowings(
    address user,
    MigrationHelperV3V3.RepayInput[] memory borrowedPositions
  ) internal {
    for (uint256 i = 0; i < borrowedPositions.length; i++) {
      (, , uint256 currentVariableDebt, , , , , , ) = v3DataProvider.getUserReserveData(
        borrowedPositions[i].asset,
        user
      );

      assertTrue(currentVariableDebt >= borrowedPositions[i].amount);
    }
  }

  function _getV3UserPosition(
    address user
  )
    internal
    view
    returns (address[] memory, uint256[] memory, MigrationHelperV3V3.RepayInput[] memory)
  {
    uint256 numberOfSupplied;
    uint256 numberOfBorrowed;
    address[] memory suppliedPositions = new address[](v3Reserves.length);
    uint256[] memory suppliedBalances = new uint256[](v3Reserves.length);
    MigrationHelperV3V3.RepayInput[]
      memory borrowedPositions = new MigrationHelperV3V3.RepayInput[](v3Reserves.length * 2);
    for (uint256 i = 0; i < v3Reserves.length; i++) {
      (
        uint256 currentATokenBalance,
        uint256 currentStableDebt,
        uint256 currentVariableDebt,
        ,
        ,
        ,
        ,
        ,

      ) = v3DataProvider.getUserReserveData(v3Reserves[i], user);
      if (currentATokenBalance != 0) {
        suppliedPositions[numberOfSupplied] = v3Reserves[i];
        suppliedBalances[numberOfSupplied] = currentATokenBalance;
        numberOfSupplied++;
      }
      if (currentStableDebt != 0) {
        borrowedPositions[numberOfBorrowed] = IMigrationHelper.RepayInput({
          asset: v3Reserves[i],
          amount: currentStableDebt,
          rateMode: 1
        });
        numberOfBorrowed++;
      }
      if (currentVariableDebt != 0) {
        borrowedPositions[numberOfBorrowed] = IMigrationHelper.RepayInput({
          asset: v3Reserves[i],
          amount: currentVariableDebt,
          rateMode: 2
        });
        numberOfBorrowed++;
      }
    }

    // shrink unused elements of the arrays
    assembly {
      mstore(suppliedPositions, numberOfSupplied)
      mstore(suppliedBalances, numberOfSupplied)
      mstore(borrowedPositions, numberOfBorrowed)
    }

    return (suppliedPositions, suppliedBalances, borrowedPositions);
  }

  function _getSimplePositionsToRepay(
    MigrationHelperV3V3.RepayInput[] memory positionsToRepay
  ) internal pure returns (MigrationHelperV3V3.RepaySimpleInput[] memory) {
    MigrationHelperV3V3.RepaySimpleInput[]
      memory positionsToRepaySimple = new MigrationHelperV3V3.RepaySimpleInput[](
        positionsToRepay.length
      );
    for (uint256 i; i < positionsToRepay.length; ++i) {
      positionsToRepaySimple[i] = IMigrationHelper.RepaySimpleInput({
        asset: positionsToRepay[i].asset,
        rateMode: positionsToRepay[i].rateMode
      });
    }

    return positionsToRepaySimple;
  }

  function _getFlashloanParams(
    MigrationHelperV3V3.RepayInput[] memory borrowedPositions
  ) internal returns (address[] memory, uint256[] memory, uint256[] memory) {
    address[] memory borrowedAssets = new address[](borrowedPositions.length);
    uint256[] memory borrowedAmounts = new uint256[](borrowedPositions.length);
    uint256[] memory interestRateModes = new uint256[](borrowedPositions.length);
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

    // shrink unused elements of the arrays
    assembly {
      mstore(borrowedAssets, index)
      mstore(borrowedAmounts, index)
      mstore(interestRateModes, index)
    }

    return (borrowedAssets, borrowedAmounts, interestRateModes);
  }

  function _getUserWithPosition() internal returns (address, uint256) {
    uint256 ownerPrivateKey = 0xA11CEA;

    address owner = vm.addr(ownerPrivateKey);
    deal(DAI, owner, 10000e18);
    deal(ETH, owner, 10e18);

    vm.startPrank(owner);

    IERC20(DAI).approve(address(migrationHelper.V3_SOURCE_POOL()), type(uint256).max);
    IERC20(ETH).approve(address(migrationHelper.V3_SOURCE_POOL()), type(uint256).max);

    migrationHelper.V3_SOURCE_POOL().deposit(DAI, 10000 ether, owner, 0);
    migrationHelper.V3_SOURCE_POOL().deposit(ETH, 10 ether, owner, 0);

    vm.stopPrank();

    return (owner, ownerPrivateKey);
  }

  function _getUserWithBorrowPosition() internal returns (address, uint256) {
    uint256 ownerPrivateKey = 0xA11CEB;

    address owner = vm.addr(ownerPrivateKey);
    deal(DAI, owner, 10000e18);
    deal(ETH, owner, 10e18);

    vm.startPrank(owner);

    IERC20(DAI).approve(address(migrationHelper.V3_SOURCE_POOL()), type(uint256).max);
    IERC20(ETH).approve(address(migrationHelper.V3_SOURCE_POOL()), type(uint256).max);

    migrationHelper.V3_SOURCE_POOL().deposit(DAI, 10000 ether, owner, 0);
    migrationHelper.V3_SOURCE_POOL().deposit(ETH, 10 ether, owner, 0);

    // migrationHelper.V3_SOURCE_POOL().borrow(ETH, 2 ether, 1, 0, owner);
    migrationHelper.V3_SOURCE_POOL().borrow(ETH, 1 ether, 2, 0, owner);

    vm.stopPrank();

    return (owner, ownerPrivateKey);
  }

  function _getPermits(
    address user,
    uint256 privateKey,
    address[] memory suppliedPositions,
    uint256[] memory suppliedBalances
  ) internal view returns (MigrationHelperV3V3.PermitInput[] memory) {
    MigrationHelperV3V3.PermitInput[] memory permits = new MigrationHelperV3V3.PermitInput[](
      suppliedPositions.length
    );

    for (uint256 i = 0; i < suppliedPositions.length; i++) {
      IERC20WithPermit token = migrationHelper.aTokens(suppliedPositions[i]);

      SigUtils.Permit memory permit = SigUtils.Permit({
        owner: user,
        spender: address(migrationHelper),
        value: suppliedBalances[i],
        nonce: IERC20WithATokenCompatibility(address(token))._nonces(user),
        deadline: type(uint256).max
      });

      bytes32 digest = sigUtils.getPermitTypedDataHash(permit, token.DOMAIN_SEPARATOR());

      (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);

      permits[i] = IMigrationHelper.PermitInput({
        aToken: token,
        value: suppliedBalances[i],
        deadline: type(uint256).max,
        v: v,
        r: r,
        s: s
      });
    }

    return permits;
  }

  function _getCreditDelegations(
    address user,
    uint256 privateKey,
    IMigrationHelper.RepayInput[] memory positionsToRepay
  ) internal returns (IMigrationHelper.CreditDelegationInput[] memory) {
    IMigrationHelper.CreditDelegationInput[]
      memory creditDelegations = new IMigrationHelper.CreditDelegationInput[](
        positionsToRepay.length
      );

    // calculate params for v3 credit delegation
    (address[] memory borrowedAssets, uint256[] memory borrowedAmounts, ) = _getFlashloanParams(
      positionsToRepay
    );

    for (uint256 i = 0; i < borrowedAssets.length; i++) {
      // get v3 variable debt token
      DataTypes.ReserveData memory reserveData = migrationHelper.V3_TARGET_POOL().getReserveData(
        borrowedAssets[i]
      );

      IERC20WithPermit token = IERC20WithPermit(reserveData.variableDebtTokenAddress);

      SigUtils.CreditDelegation memory creditDelegation = SigUtils.CreditDelegation({
        delegatee: address(migrationHelper),
        value: borrowedAmounts[i],
        nonce: token.nonces(user),
        deadline: type(uint256).max
      });

      bytes32 digest = sigUtils.getCreditDelegationTypedDataHash(
        creditDelegation,
        token.DOMAIN_SEPARATOR()
      );

      (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);

      creditDelegations[i] = IMigrationHelper.CreditDelegationInput({
        debtToken: ICreditDelegationToken(address(token)),
        value: borrowedAmounts[i],
        deadline: type(uint256).max,
        v: v,
        r: r,
        s: s
      });
    }

    return creditDelegations;
  }
}
