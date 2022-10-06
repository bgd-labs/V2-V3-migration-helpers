// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20WithPermit} from 'solidity-utils/contracts/oz-common/interfaces/IERC20WithPermit.sol';

interface IERC20WithATokenCompatibility is IERC20WithPermit {
  /**
   * @dev Returns the current nonce for `owner`. This value must be
   * included whenever a signature is generated for {permit}.
   *
   * Added for compatibility with V2 ATokens
   */
  function _nonces(address owner) external view returns (uint256);
}
