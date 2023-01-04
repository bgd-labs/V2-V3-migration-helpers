// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20WithPermit} from 'solidity-utils/contracts/oz-common/interfaces/IERC20WithPermit.sol';
import {ILendingPool as IV2LendingPool} from 'aave-address-book/AaveV2.sol';

import {IFlashLoanReceiver} from './IFlashLoanReceiver.sol';
import {ICreditDelegationToken} from './ICreditDelegationToken.sol';

interface IMigrationHelper is IFlashLoanReceiver {
  struct PermitInput {
    IERC20WithPermit aToken;
    uint256 value;
    uint256 deadline;
    uint8 v;
    bytes32 r;
    bytes32 s;
  }
  struct CreditDelegationInput {
    ICreditDelegationToken debtToken;
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

  struct RepaySimpleInput {
    address asset;
    uint256 rateMode;
  }

  struct EmergencyTransferInput {
    IERC20WithPermit asset;
    uint256 amount;
    address to;
  }

  // @dev Method to do migration of positions which require repayment. Migrating whole amount of specified assets
  // @param assetsToMigrate - list of assets to migrate
  // @param positionsToRepay - list of assets to be repayed
  // @param permits - list of EIP712 permits, can be empty, if approvals provided in advance
  // @param creditDelegationPermits - list of EIP712 signatures (credit delegations) for v3 variable debt token
  // check more details about permit at PermitInput and /solidity-utils/contracts/oz-common/interfaces/draft-IERC20Permit.sol
  function migrate(
    address[] memory assetsToMigrate,
    RepaySimpleInput[] memory positionsToRepay,
    PermitInput[] memory permits,
    CreditDelegationInput[] memory creditDelegationPermits
  ) external;

  // @dev public method to optimize the gas costs, to avoid having getReserveData calls on every execution
  function cacheATokens() external;

  function V2_POOL() external returns (IV2LendingPool);

  // @dev public method for rescue funds in case of a wrong transfer
  // @param emergencyInput - array of parameters to transfer out funds
  function rescueFunds(EmergencyTransferInput[] calldata emergencyInput)
    external;
}
