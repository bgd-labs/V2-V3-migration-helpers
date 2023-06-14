// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20WithPermit} from 'solidity-utils/contracts/oz-common/interfaces/IERC20WithPermit.sol';
import {IPool as IV3Pool} from 'aave-address-book/AaveV3.sol';

import {ICreditDelegationToken} from './ICreditDelegationToken.sol';
import {IMigrationHelper} from './IMigrationHelper.sol';

/**
 * @title IMigrationHelperV3V3
 * @author BGD Labs
 * @notice Defines the interface for the contract to migrate positions from Aave v3 to another Aave v3 pool
 **/
interface IMigrationHelperV3V3 is IMigrationHelper {
  /// @notice The source pool
  function V3_SOURCE_POOL() external returns (IV3Pool);

  /// @notice The destination pool
  function V3_TARGET_POOL() external returns (IV3Pool);
}
