// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ILendingPool as IV2LendingPool} from 'aave-address-book/AaveV2.sol';

import {IFlashLoanReceiver} from './IFlashLoanReceiver.sol';
import {IERC20WithPermit} from '../interfaces/IERC20WithPermit.sol';

interface IMigrationHelper is IFlashLoanReceiver {
  struct PermitInput {
    IERC20WithPermit aToken;
    uint256 value;
    uint256 deadline;
    uint8 v;
    bytes32 r;
    bytes32 s;
  }

  struct RepayInput {
    address asset;
    uint256 amount;
    uint256 rateMode;
  }

  // @dev Method to do migration of positions which are not requiring repayment. Migrating whole amount of specified assets
  // @param user - user to migrate positions
  // @param assets - list of assets to migrate
  // @param permits - list of EIP712 permits, can be empty, if approvals provided in advance
  // check more details about permit at PermitInput and /solidity-utils/contracts/oz-common/interfaces/draft-IERC20Permit.sol
  function migrationNoBorrow(
    address user,
    address[] calldata assets,
    PermitInput[] calldata permits
  ) external;

  // @dev public method to optimize the gas costs, to avoid having getReserveData calls on every execution
  function cacheATokens() external;

  function V2_POOL() external returns (IV2LendingPool);
}
