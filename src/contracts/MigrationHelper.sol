// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {DataTypes, ILendingPool as IV2LendingPool} from 'aave-address-book/AaveV2.sol';
import {IPoolAddressesProvider, IPool} from 'aave-address-book/AaveV3.sol';

import {IMigrationHelper, IERC20WithPermit} from '../interfaces/IMigrationHelper.sol';

contract MigrationHelper is IMigrationHelper {
  //@dev the source pool
  IV2LendingPool public immutable V2_POOL;

  //@dev the destination pool
  IPoolAddressesProvider public immutable ADDRESSES_PROVIDER;
  IPool public immutable POOL;

  mapping(address => IERC20WithPermit) public aTokens;

  constructor(IPoolAddressesProvider v3AddressesProvider, IV2LendingPool v2Pool)
  {
    ADDRESSES_PROVIDER = v3AddressesProvider;
    POOL = IPool(v3AddressesProvider.getPool());
    V2_POOL = v2Pool;
    cacheATokens();
  }

  //@Iinheritdoc IMigrationHelper
  function cacheATokens() public {
    DataTypes.ReserveData memory reserveData;
    address[] memory reserves = V2_POOL.getReservesList();
    for (uint256 i = 0; i < reserves.length; i++) {
      if (address(aTokens[reserves[i]]) == address(0)) {
        reserveData = V2_POOL.getReserveData(reserves[i]);
        aTokens[reserves[i]] = IERC20WithPermit(reserveData.aTokenAddress);
        IERC20WithPermit(reserves[i]).approve(address(POOL), type(uint256).max);
      }
    }
  }

  //@Iinheritdoc IFlashLoanReceiver
  // expected structure of the params:
  // assetsToMigrate - the list of supplied assets to migrate
  // positionsToRepay - the list of borrowed positions, asset address, amount and debt type should be provided
  // permits - the list of a EIP712 like permits, if allowance was not granted in advance
  function executeOperation(
    address[] calldata,
    uint256[] calldata,
    uint256[] calldata,
    address initiator,
    bytes calldata params
  ) external returns (bool) {
    (
      address[] memory assetsToMigrate,
      RepayInput[] memory positionsToRepay,
      PermitInput[] memory permits
    ) = abi.decode(params, (address[], RepayInput[], PermitInput[]));

    for (uint256 i = 0; i < positionsToRepay.length; i++) {
      V2_POOL.repay(
        positionsToRepay[i].asset,
        positionsToRepay[i].amount,
        positionsToRepay[i].rateMode,
        initiator
      );
    }

    migrationNoBorrow(initiator, assetsToMigrate, permits);

    return true;
  }

  //@Iinheritdoc IMigrationHelper
  function migrationNoBorrow(
    address user,
    address[] memory assets,
    PermitInput[] memory permits
  ) public {
    address asset;
    IERC20WithPermit aToken;

    for (uint256 i = 0; i < permits.length; i++) {
      permits[i].aToken.permit(
        user,
        address(this),
        permits[i].value,
        permits[i].deadline,
        permits[i].v,
        permits[i].r,
        permits[i].s
      );
    }

    for (uint256 i = 0; i < assets.length; i++) {
      asset = assets[i];
      aToken = aTokens[asset];
      require(
        asset != address(0) && address(aToken) != address(0),
        'INVALID_OR_NOT_CACHED_ASSET'
      );

      aToken.transferFrom(user, address(this), aToken.balanceOf(user));
      uint256 withdrawn = V2_POOL.withdraw(
        asset,
        type(uint256).max,
        address(this)
      );

      POOL.supply(asset, withdrawn, user, 0);
    }
  }
}
