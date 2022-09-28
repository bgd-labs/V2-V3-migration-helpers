// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {AaveV2Ethereum} from 'aave-address-book/AaveV2Ethereum.sol';
import {AaveV3Polygon} from 'aave-address-book/AaveV3Polygon.sol';
import {DataTypes} from 'aave-address-book/AaveV2.sol';
import {IPoolAddressesProvider, IPool} from 'aave-address-book/AaveV3.sol';

import {IMigrationHelper, IERC20WithPermit} from '../interfaces/IMigrationHelper.sol';

contract MigrationHelper is IMigrationHelper {
  mapping(address => IERC20WithPermit) internal _aTokens;

  constructor() {
    cacheATokens();
  }

  // @dev public method to optimize the gas costs, to avoid having getReserveData calls on every execution
  function cacheATokens() public {
    DataTypes.ReserveData memory reserveData;
    address[] memory reserves = AaveV2Ethereum.POOL.getReservesList();
    for (uint256 i = 0; i < reserves.length; i++) {
      if (address(_aTokens[reserves[i]]) != address(0)) {
        reserveData = AaveV2Ethereum.POOL.getReserveData(reserves[i]);
        _aTokens[reserves[i]] = IERC20WithPermit(reserveData.aTokenAddress);
      }
    }
  }

  function executeOperation(
    address[] calldata assets,
    uint256[] calldata amounts,
    uint256[] calldata premiums,
    address initiator,
    bytes calldata params
  ) external returns (bool) {
    (
      address[] memory assetsToMigrate,
      RepayInput[] memory positionsToRepay,
      PermitInput[] memory permits
    ) = abi.decode(params, (address[], RepayInput[], PermitInput[]));

    for (uint256 i = 0; i < positionsToRepay.length; i++) {
      uint256 repaidAmount = AaveV2Ethereum.POOL.repay(
        positionsToRepay[i].asset,
        positionsToRepay[i].amount,
        positionsToRepay[i].rateMode,
        initiator
      );
    }

    _migrationNoBorrow(initiator, assetsToMigrate, permits);

    return true;
  }

  function migrationNoBorrow(
    address[] calldata assets,
    PermitInput[] calldata permits
  ) external {
    _migrationNoBorrow(msg.sender, assets, permits);
  }

  function POOL() external pure returns (IPool) {
    return AaveV3Polygon.POOL;
  }

  function ADDRESSES_PROVIDER() external pure returns (IPoolAddressesProvider) {
    return AaveV3Polygon.POOL_ADDRESSES_PROVIDER;
  }

  function _migrationNoBorrow(
    address user,
    address[] memory assets,
    PermitInput[] memory permits
  ) internal {
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
      aToken = _aTokens[asset];
      require(
        asset != address(0) && address(aToken) != address(0),
        'INVALID_OR_NOT_CACHED_ASSET'
      );

      aToken.transferFrom(msg.sender, address(this), aToken.balanceOf(user));
      uint256 withdrawn = AaveV2Ethereum.POOL.withdraw(
        asset,
        type(uint256).max,
        address(this)
      );

      AaveV3Polygon.POOL.supply(asset, withdrawn, user, 0);
    }
  }
}
