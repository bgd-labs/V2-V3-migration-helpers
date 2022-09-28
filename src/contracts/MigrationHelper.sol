// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import {AaveV2Ethereum} from 'aave-address-book/AaveV2Ethereum.sol';
import {AaveV3Polygon} from 'aave-address-book/AaveV3Polygon.sol';
import {DataTypes} from 'aave-address-book/AaveV2.sol';

import {IERC20} from '../../lib/aave-v3-core/contracts/dependencies/openzeppelin/contracts/IERC20.sol';
import {IAToken} from '../../lib/aave-v3-core/contracts/interfaces/IAToken.sol';
import {IPoolAddressesProvider, IPool} from '../../lib/aave-v3-core/contracts/flashloan/interfaces/IFlashLoanReceiver.sol';
import {IMigrationHelper} from "../interfaces/IMigrationHelper.sol";

contract MigrationHelper is IMigrationHelper {
  struct PermitInput {
    IAToken aToken;
    uint256 value;
    uint256 deadline;
    uint8 v;
    bytes32 r;
    bytes32 s;
  }
  mapping(address => IAToken) internal _aTokens;

  constructor() {
    cacheATokens();
  }

  // @dev public method to optimize the gas costs of all operations
  function cacheATokens() public {
    DataTypes.ReserveData memory reserveData;
    address[] memory reserves = AaveV2Ethereum.POOL.getReservesList();
    for (uint256 i = 0; i < reserves.length; i++) {
      if (address(_aTokens[reserves[i]]) != address(0)) {
        reserveData = AaveV2Ethereum.POOL.getReserveData(reserves[i]);
        _aTokens[reserves[i]] = IAToken(reserveData.aTokenAddress);
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
      bool depositLeftovers,
      address[] memory assetsToMigrate,
      PermitInput[] memory permits
    ) = abi.decode(params, (bool, address[], PermitInput[]));

    for (uint256 i = 0; i < assets.length; i++) {
      uint256 repaidAmount = AaveV2Ethereum.POOL.repay(
        assets[i],
        amounts[i],
        1,
        initiator
      );

      uint256 leftovers = amounts[i] - repaidAmount;
      if (depositLeftovers && leftovers != 0) {
        AaveV3Polygon.POOL.deposit(assets[i], leftovers, initiator, 0);
      }
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
    return IPool(address(AaveV3Polygon.POOL));
  }

  function ADDRESSES_PROVIDER() external pure returns (IPoolAddressesProvider) {
    return
      IPoolAddressesProvider(address(AaveV3Polygon.POOL_ADDRESSES_PROVIDER));
  }

  function _migrationNoBorrow(
    address user,
    address[] memory assets,
    PermitInput[] memory permits
  ) internal {
    address asset;
    IAToken aToken;

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
        'INVALID_ASSET'
      );

      aToken.transferFrom(msg.sender, address(this), aToken.balanceOf(user));
      AaveV2Ethereum.POOL.withdraw(asset, type(uint256).max, address(this));

      AaveV3Polygon.POOL.supply(
        asset,
        IERC20(asset).balanceOf(address(this)),
        user,
        0
      );
    }
  }
}
