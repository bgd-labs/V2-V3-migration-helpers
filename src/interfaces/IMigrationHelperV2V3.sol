// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20WithPermit} from 'solidity-utils/contracts/oz-common/interfaces/IERC20WithPermit.sol';
import {ILendingPool as IV2Pool} from 'aave-address-book/AaveV2.sol';
import {IPool as IV3Pool} from 'aave-address-book/AaveV3.sol';

import {ICreditDelegationToken} from './ICreditDelegationToken.sol';
import {IMigrationHelper} from './IMigrationHelper.sol';

/**
 * @title IMigrationHelper
 * @author BGD Labs
 * @notice Defines the interface for the contract to migrate positions from Aave v2 to Aave v3 pool
 **/
interface IMigrationHelperV2V3 is IMigrationHelper {
  /// @notice The source pool
  function V2_POOL() external returns (IV2Pool);

  /// @notice The destination pool
  function V3_POOL() external returns (IV3Pool);
}
