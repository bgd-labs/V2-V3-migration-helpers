// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IERC20WithPermit} from 'solidity-utils/contracts/oz-common/interfaces/IERC20WithPermit.sol';
import {DataTypes, ILendingPool as IV2LendingPool} from 'aave-address-book/AaveV2.sol';
import {IPoolAddressesProvider, IPool} from 'aave-address-book/AaveV3.sol';

import {IMigrationHelper} from '../interfaces/IMigrationHelper.sol';

contract MigrationHelper is IMigrationHelper {
  //@dev the source pool
  IV2LendingPool public immutable V2_POOL;

  //@dev the destination pool
  IPoolAddressesProvider public immutable ADDRESSES_PROVIDER;
  IPool public immutable POOL;

  mapping(address => IERC20WithPermit) public aTokens;
  mapping(address => IERC20WithPermit) public vTokens;
  mapping(address => IERC20WithPermit) public sTokens;

  constructor(
    IPoolAddressesProvider v3AddressesProvider,
    IV2LendingPool v2Pool
  ) {
    ADDRESSES_PROVIDER = v3AddressesProvider;
    POOL = IPool(v3AddressesProvider.getPool());
    V2_POOL = v2Pool;
    cacheATokens();
  }

  //@Iinheritdoc IMigrationHelper
  function cacheATokens() public {
    DataTypes.ReserveData memory reserveData;
    address[] memory reserves = V2_POOL.getReservesList();
    for (uint256 i = 0; i < reserves.length; i++) {
      if (address(aTokens[reserves[i]]) == address(0)) {
        reserveData = V2_POOL.getReserveData(reserves[i]);
        aTokens[reserves[i]] = IERC20WithPermit(reserveData.aTokenAddress);
        vTokens[reserves[i]] = IERC20WithPermit(
          reserveData.variableDebtTokenAddress
        );
        sTokens[reserves[i]] = IERC20WithPermit(
          reserveData.stableDebtTokenAddress
        );
        IERC20WithPermit(reserves[i]).approve(
          address(V2_POOL),
          type(uint256).max
        );
        IERC20WithPermit(reserves[i]).approve(address(POOL), type(uint256).max);
      }
    }
  }

  //@Iinheritdoc IFlashLoanReceiver
  // expected structure of the params:
  // assetsToMigrate - the list of supplied assets to migrate
  // positionsToRepay - the list of borrowed positions, asset address, amount and debt type should be provided
  // permits - the list of a EIP712 like permits, if allowance was not granted in advance
  function executeOperation(
    address[] calldata,
    uint256[] calldata,
    uint256[] calldata,
    address initiator,
    bytes calldata params
  ) external returns (bool) {
    (
      address[] memory assetsToMigrate,
      RepayInput[] memory positionsToRepay,
      PermitInput[] memory permits,
      address beneficiary
    ) = abi.decode(params, (address[], RepayInput[], PermitInput[], address));

    for (uint256 i = 0; i < positionsToRepay.length; i++) {
      V2_POOL.repay(
        positionsToRepay[i].asset,
        positionsToRepay[i].amount,
        positionsToRepay[i].rateMode,
        initiator == address(this) ? beneficiary : initiator // TODO: does it make to much sense?
      );
    }

    migrationNoBorrow(initiator, assetsToMigrate, permits);

    return true;
  }

  //@Iinheritdoc IMigrationHelper
  function migrationNoBorrow(
    address user,
    address[] memory assets,
    PermitInput[] memory permits
  ) public {
    address asset;
    IERC20WithPermit aToken;

    for (uint256 i = 0; i < permits.length; i++) {
      permits[i].aToken.permit(
        user,
        address(this),
        permits[i].value,
        permits[i].deadline,
        permits[i].v,
        permits[i].r,
        permits[i].s
      );
    }

    for (uint256 i = 0; i < assets.length; i++) {
      asset = assets[i];
      aToken = aTokens[asset];
      require(
        asset != address(0) && address(aToken) != address(0),
        'INVALID_OR_NOT_CACHED_ASSET'
      );

      aToken.transferFrom(user, address(this), aToken.balanceOf(user));
      uint256 withdrawn = V2_POOL.withdraw(
        asset,
        type(uint256).max,
        address(this)
      );

      POOL.supply(asset, withdrawn, user, 0);
    }
  }

  function migrateWithFlashBorrow(
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

    for (uint256 i = 0; i < creditDelegationPermits.length; i++) {
      creditDelegationPermits[i].debtToken.delegationWithSig(
        msg.sender,
        address(this),
        permits[i].value,
        permits[i].deadline,
        permits[i].v,
        permits[i].r,
        permits[i].s
      );
    }

    RepayInput[] memory positionsToRepayWithAmounts = new RepayInput[](
      positionsToRepay.length
    );
    uint256 numberOfAssetsToFlash = 0;
    address[] memory assetsToFlash = new address[](positionsToRepay.length);
    uint256[] memory amountsToFlash = new uint256[](positionsToRepay.length);
    uint256[] memory interestRatesToFlash = new uint256[](
      positionsToRepay.length
    );

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

      bool amountIncludedIntoFLash = false;
      for (uint256 j = 0; j < numberOfAssetsToFlash; j++) {
        if (assetsToFlash[j] == positionsToRepay[i].asset) {
          amountsToFlash[j] += positionsToRepayWithAmounts[i].amount;
          amountIncludedIntoFLash = true;
          break;
        }
      }
      if (!amountIncludedIntoFLash) {
        assetsToFlash[++numberOfAssetsToFlash] = positionsToRepayWithAmounts[i]
          .asset;
        amountsToFlash[numberOfAssetsToFlash] = positionsToRepayWithAmounts[i]
          .amount;
        interestRatesToFlash[numberOfAssetsToFlash] = 2; // @dev variable debt
      }
    }

    assembly {
      mstore(assetsToFlash, numberOfAssetsToFlash)
      mstore(amountsToFlash, numberOfAssetsToFlash)
      mstore(interestRatesToFlash, numberOfAssetsToFlash)
    }

    POOL.flashLoan(
      address(this),
      assetsToFlash,
      amountsToFlash,
      interestRatesToFlash,
      msg.sender,
      abi.encode(
        assetsToMigrate,
        positionsToRepayWithAmounts,
        new PermitInput[](0),
        msg.sender
      ),
      0
    );
  }
}
