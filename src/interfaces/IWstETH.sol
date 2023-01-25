// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IERC20WithPermit} from 'solidity-utils/contracts/oz-common/interfaces/IERC20WithPermit.sol';

interface IWstETH is IERC20WithPermit {
  function wrap(uint256 stETHAmount) external returns (uint256);

  function getWstETHByStETH(uint256 stETHAmount) external view returns (uint256);
}
