// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IERC20WithPermit} from 'solidity-utils/contracts/oz-common/interfaces/IERC20WithPermit.sol';
import {SafeERC20} from 'solidity-utils/contracts/oz-common/SafeERC20.sol';
import {ILendingPool as IV2LendingPool} from 'aave-address-book/AaveV2.sol';
import {IPoolAddressesProvider} from 'aave-address-book/AaveV3.sol';
import {IWstETH} from '../interfaces/IWstETH.sol';
import {MigrationHelper} from './MigrationHelper.sol';

contract MigrationHelperMainnet is MigrationHelper {
  using SafeERC20 for IERC20WithPermit;

  IERC20WithPermit public immutable STETH;
  IWstETH public immutable WSTETH;

  constructor(IPoolAddressesProvider v3AddressesProvider, IV2LendingPool v2Pool)
    MigrationHelper(v3AddressesProvider, v2Pool)
  {
    STETH = IERC20WithPermit(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84); // stETH address
    WSTETH = IWstETH(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0); // wstETH address
  }

  function _getAssetAndAmountToSupply(address asset, uint256 withdrawn)
    internal
    override
    returns (address, uint256)
  {
    if (asset == address(STETH)) {
      STETH.safeApprove(address(this), withdrawn);
      uint256 wrapped = WSTETH.wrap(withdrawn);

      return (address(WSTETH), wrapped);
    }

    return (asset, withdrawn);
  }
}
