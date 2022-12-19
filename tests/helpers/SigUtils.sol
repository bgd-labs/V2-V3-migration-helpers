// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

contract SigUtils {
  // keccak256('Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)');
  bytes32 private constant PERMIT_TYPEHASH =
    0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;

  // keccak256('DelegationWithSig(address delegatee,uint256 value,uint256 nonce,uint256 deadline)');
  bytes32 private constant CREDIT_DELEGATION_TYPEHASH =
    0x323db0410fecc107e39e2af5908671f4c8d106123b35a51501bb805c5fa36aa0;

  struct Permit {
    address owner;
    address spender;
    uint256 value;
    uint256 nonce;
    uint256 deadline;
  }

  struct CreditDelegation {
    address delegatee;
    uint256 value;
    uint256 nonce;
    uint256 deadline;
  }

  // computes the hash of the fully encoded EIP-712 message for the domain, which can be used to recover the signer
  function getPermitTypedDataHash(
    Permit memory _permit,
    bytes32 domainSeparator
  ) public pure returns (bytes32) {
    return
      keccak256(
        abi.encodePacked(
          '\x19\x01',
          domainSeparator,
          keccak256(
            abi.encode(
              PERMIT_TYPEHASH,
              _permit.owner,
              _permit.spender,
              _permit.value,
              _permit.nonce,
              _permit.deadline
            )
          )
        )
      );
  }

  function getCreditDelegationTypedDataHash(
    CreditDelegation memory _creditDelegation,
    bytes32 domainSeparator
  ) public pure returns (bytes32) {
    return
      keccak256(
        abi.encodePacked(
          '\x19\x01',
          domainSeparator,
          keccak256(
            abi.encode(
              CREDIT_DELEGATION_TYPEHASH,
              _creditDelegation.delegatee,
              _creditDelegation.value,
              _creditDelegation.nonce,
              _creditDelegation.deadline
            )
          )
        )
      );
  }
}
