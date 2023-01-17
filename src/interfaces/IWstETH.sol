// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IWstETH {
  function wrap(uint256 _stETHAmount) external returns (uint256);
}
