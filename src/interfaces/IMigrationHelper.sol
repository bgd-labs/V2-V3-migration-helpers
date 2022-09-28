// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

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
}
