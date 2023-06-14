// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IERC20WithPermit} from 'solidity-utils/contracts/oz-common/interfaces/IERC20WithPermit.sol';
import {SafeERC20} from 'solidity-utils/contracts/oz-common/SafeERC20.sol';

import {AaveV2EthereumAMM, AaveV2EthereumAMMAssets} from 'aave-address-book/AaveV2EthereumAMM.sol';
import {AaveV3Ethereum} from 'aave-address-book/AaveV3Ethereum.sol';
import {DataTypes, ILendingPool as IV2Pool} from 'aave-address-book/AaveV2.sol';

import {IWstETH} from '../interfaces/IWstETH.sol';
import {MigrationHelper} from './MigrationHelper.sol';

/**
 * @title MigrationHelperMainnet
 * @author BGD Labs
 * @dev Contract to migrate positions from Aave v2 to Aave v3 Ethereum Mainnet pools
 *   wraps stETH to wStETH to make it compatible
 */
contract MigrationHelperAmm is MigrationHelper {
  using SafeERC20 for IERC20WithPermit;
  using SafeERC20 for IWstETH;

  constructor() MigrationHelper(AaveV3Ethereum.POOL, AaveV2EthereumAMM.POOL) {
  }

  function cacheATokens() public virtual override {
    DataTypes.ReserveData memory reserveData;
    address[] memory reserves = new address[](5);
    reserves[0] = AaveV2EthereumAMMAssets.DAI_UNDERLYING;
    reserves[1] = AaveV2EthereumAMMAssets.USDC_UNDERLYING;
    reserves[2] = AaveV2EthereumAMMAssets.USDT_UNDERLYING;
    reserves[3] = AaveV2EthereumAMMAssets.WBTC_UNDERLYING;
    reserves[4] = AaveV2EthereumAMMAssets.WETH_UNDERLYING;
    for (uint256 i = 0; i < reserves.length; i++) {
      if (address(aTokens[reserves[i]]) == address(0)) {
        reserveData = V2_POOL.getReserveData(reserves[i]);
        aTokens[reserves[i]] = IERC20WithPermit(reserveData.aTokenAddress);
        vTokens[reserves[i]] = IERC20WithPermit(reserveData.variableDebtTokenAddress);
        sTokens[reserves[i]] = IERC20WithPermit(reserveData.stableDebtTokenAddress);

        IERC20WithPermit(reserves[i]).safeApprove(address(V2_POOL), type(uint256).max);
        IERC20WithPermit(reserves[i]).safeApprove(address(V3_POOL), type(uint256).max);
      }
    }
  }
}
