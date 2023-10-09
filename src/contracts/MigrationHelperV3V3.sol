// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.10;

import {IERC20WithPermit} from 'solidity-utils/contracts/oz-common/interfaces/IERC20WithPermit.sol';
import {SafeERC20} from 'solidity-utils/contracts/oz-common/SafeERC20.sol';
import {IPool as IV3Pool, DataTypes} from 'aave-address-book/AaveV3.sol';
import {Ownable} from 'solidity-utils/contracts/oz-common/Ownable.sol';

import {IMigrationHelperV3V3, IMigrationHelper} from '../interfaces/IMigrationHelperV3V3.sol';

/**
 * @title MigrationHelperV3V3
 * @author BGD Labs
 * @dev Contract to migrate positions from Aave v3 to another Aave v3 pool
 */
contract MigrationHelperV3V3 is Ownable, IMigrationHelperV3V3 {
  using SafeERC20 for IERC20WithPermit;

  /// @inheritdoc IMigrationHelperV3V3
  IV3Pool public immutable V3_SOURCE_POOL;

  /// @inheritdoc IMigrationHelperV3V3
  IV3Pool public immutable V3_TARGET_POOL;

  mapping(address => IERC20WithPermit) public aTokens;
  mapping(address => IERC20WithPermit) public vTokens;
  mapping(address => IERC20WithPermit) public sTokens;

  /**
   * @notice Constructor.
   * @param v3SourcePool The v3 source pool
   * @param v3TargetPool The v3 target pool
   */
  constructor(IV3Pool v3SourcePool, IV3Pool v3TargetPool) {
    V3_SOURCE_POOL = v3SourcePool;
    V3_TARGET_POOL = v3TargetPool;
    cacheATokens();
  }

  /// @inheritdoc IMigrationHelper
  function cacheATokens() public {
    DataTypes.ReserveData memory reserveData;
    address[] memory reserves = _getV3Reserves();
    for (uint256 i = 0; i < reserves.length; i++) {
      if (address(aTokens[reserves[i]]) == address(0)) {
        reserveData = V3_SOURCE_POOL.getReserveData(reserves[i]);
        aTokens[reserves[i]] = IERC20WithPermit(reserveData.aTokenAddress);
        vTokens[reserves[i]] = IERC20WithPermit(reserveData.variableDebtTokenAddress);
        sTokens[reserves[i]] = IERC20WithPermit(reserveData.stableDebtTokenAddress);

        IERC20WithPermit(reserves[i]).safeApprove(address(V3_SOURCE_POOL), type(uint256).max);
        IERC20WithPermit(reserves[i]).safeApprove(address(V3_TARGET_POOL), type(uint256).max);
      }
    }
  }

  /// @inheritdoc IMigrationHelper
  function migrate(
    address[] memory assetsToMigrate,
    RepaySimpleInput[] memory positionsToRepay,
    PermitInput[] memory permits,
    CreditDelegationInput[] memory creditDelegationPermits
  ) external {
    for (uint256 i = 0; i < permits.length; i++) {
      permits[i].aToken.permit(
        msg.sender,
        address(this),
        permits[i].value,
        permits[i].deadline,
        permits[i].v,
        permits[i].r,
        permits[i].s
      );
    }

    if (positionsToRepay.length == 0) {
      _migrationNoBorrow(msg.sender, assetsToMigrate);
    } else {
      for (uint256 i = 0; i < creditDelegationPermits.length; i++) {
        creditDelegationPermits[i].debtToken.delegationWithSig(
          msg.sender,
          address(this),
          creditDelegationPermits[i].value,
          creditDelegationPermits[i].deadline,
          creditDelegationPermits[i].v,
          creditDelegationPermits[i].r,
          creditDelegationPermits[i].s
        );
      }

      (
        RepayInput[] memory positionsToRepayWithAmounts,
        address[] memory assetsToFlash,
        uint256[] memory amountsToFlash,
        uint256[] memory interestRatesToFlash
      ) = _getFlashloanParams(positionsToRepay);

      V3_TARGET_POOL.flashLoan(
        address(this),
        assetsToFlash,
        amountsToFlash,
        interestRatesToFlash,
        msg.sender,
        abi.encode(assetsToMigrate, positionsToRepayWithAmounts, msg.sender),
        6671
      );
    }
  }

  /**
   * @dev expected structure of the params:
   *    assetsToMigrate - the list of supplied assets to migrate
   *    positionsToRepay - the list of borrowed positions, asset address, amount and debt type should be provided
   *    beneficiary - the user who requested the migration
    @inheritdoc IMigrationHelper
   */
  function executeOperation(
    address[] calldata,
    uint256[] calldata,
    uint256[] calldata,
    address initiator,
    bytes calldata params
  ) external returns (bool) {
    require(msg.sender == address(V3_TARGET_POOL), 'ONLY_V3_POOL_ALLOWED');
    require(initiator == address(this), 'ONLY_INITIATED_BY_MIGRATION_HELPER');

    (address[] memory assetsToMigrate, RepayInput[] memory positionsToRepay, address user) = abi
      .decode(params, (address[], RepayInput[], address));

    for (uint256 i = 0; i < positionsToRepay.length; i++) {
      V3_SOURCE_POOL.repay(
        positionsToRepay[i].asset,
        positionsToRepay[i].amount,
        positionsToRepay[i].rateMode,
        user
      );
    }

    _migrationNoBorrow(user, assetsToMigrate);

    return true;
  }

  /// @inheritdoc IMigrationHelper
  function getMigrationSupply(
    address asset,
    uint256 amount
  ) external view virtual returns (address, uint256) {
    return (asset, amount);
  }

  // helper method to get v3 reserves addresses for migration
  // mostly needed to make overrides simpler on specific markets with many available reserves, but few valid
  function _getV3Reserves() internal virtual returns (address[] memory) {
    return V3_SOURCE_POOL.getReservesList();
  }

  function _migrationNoBorrow(address user, address[] memory assets) internal {
    address asset;
    IERC20WithPermit aToken;
    uint256 aTokenAmountToMigrate;
    uint256 aTokenBalanceAfterReceiving;

    for (uint256 i = 0; i < assets.length; i++) {
      asset = assets[i];
      aToken = aTokens[asset];

      require(asset != address(0) && address(aToken) != address(0), 'INVALID_OR_NOT_CACHED_ASSET');

      aTokenAmountToMigrate = aToken.balanceOf(user);
      aToken.safeTransferFrom(user, address(this), aTokenAmountToMigrate);

      // this part of logic needed because of the possible 1-3 wei imprecision after aToken transfer, for example on stETH
      aTokenBalanceAfterReceiving = aToken.balanceOf(address(this));
      if (
        aTokenAmountToMigrate != aTokenBalanceAfterReceiving &&
        aTokenBalanceAfterReceiving <= aTokenAmountToMigrate + 2
      ) {
        aTokenAmountToMigrate = aTokenBalanceAfterReceiving;
      }

      uint256 withdrawn = V3_SOURCE_POOL.withdraw(asset, aTokenAmountToMigrate, address(this));

      // there are cases when we transform asset before supplying it to v3
      (address assetToSupply, uint256 amountToSupply) = _preSupply(asset, withdrawn);

      V3_TARGET_POOL.supply(assetToSupply, amountToSupply, user, 6671);
    }
  }

  function _preSupply(address asset, uint256 amount) internal virtual returns (address, uint256) {
    return (asset, amount);
  }

  function _getFlashloanParams(
    RepaySimpleInput[] memory positionsToRepay
  )
    internal
    view
    returns (RepayInput[] memory, address[] memory, uint256[] memory, uint256[] memory)
  {
    RepayInput[] memory positionsToRepayWithAmounts = new RepayInput[](positionsToRepay.length);

    uint256 numberOfAssetsToFlash;
    address[] memory assetsToFlash = new address[](positionsToRepay.length);
    uint256[] memory amountsToFlash = new uint256[](positionsToRepay.length);
    uint256[] memory interestRatesToFlash = new uint256[](positionsToRepay.length);

    for (uint256 i = 0; i < positionsToRepay.length; i++) {
      IERC20WithPermit debtToken = positionsToRepay[i].rateMode == 2
        ? vTokens[positionsToRepay[i].asset]
        : sTokens[positionsToRepay[i].asset];
      require(address(debtToken) != address(0), 'THIS_TYPE_OF_DEBT_NOT_SET');

      positionsToRepayWithAmounts[i] = RepayInput({
        asset: positionsToRepay[i].asset,
        amount: debtToken.balanceOf(msg.sender),
        rateMode: positionsToRepay[i].rateMode
      });

      bool amountIncludedIntoFlash;

      // if asset was also borrowed in another mode - add values
      for (uint256 j = 0; j < numberOfAssetsToFlash; j++) {
        if (assetsToFlash[j] == positionsToRepay[i].asset) {
          amountsToFlash[j] += positionsToRepayWithAmounts[i].amount;
          amountIncludedIntoFlash = true;
          break;
        }
      }

      // if this is the first ocurance of the asset add it
      if (!amountIncludedIntoFlash) {
        assetsToFlash[numberOfAssetsToFlash] = positionsToRepayWithAmounts[i].asset;
        amountsToFlash[numberOfAssetsToFlash] = positionsToRepayWithAmounts[i].amount;
        interestRatesToFlash[numberOfAssetsToFlash] = 2; // @dev variable debt

        ++numberOfAssetsToFlash;
      }
    }

    // we do not know the length in advance, so we init arrays with the maximum possible length
    // and then squeeze the array using mstore
    assembly {
      mstore(assetsToFlash, numberOfAssetsToFlash)
      mstore(amountsToFlash, numberOfAssetsToFlash)
      mstore(interestRatesToFlash, numberOfAssetsToFlash)
    }

    return (positionsToRepayWithAmounts, assetsToFlash, amountsToFlash, interestRatesToFlash);
  }

  /// @inheritdoc IMigrationHelper
  function rescueFunds(EmergencyTransferInput[] calldata emergencyInput) external onlyOwner {
    for (uint256 i = 0; i < emergencyInput.length; i++) {
      emergencyInput[i].asset.safeTransfer(emergencyInput[i].to, emergencyInput[i].amount);
    }
  }
}
