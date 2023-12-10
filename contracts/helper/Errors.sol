// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/**
 * @title Errors
 * @dev A library of all of the errors used throughout the BatchedWallet protocol.
 */
library Errors {
    error NON_ENTRY_POINT_CALLER();
    error BATCH_EXECUTE_ARRAY_LENGTH_INVALID();
    error SIGNATURE_LENGTH_LESS_THAN_65();
    error SIGNATURE_NOT_SIGNED_BY_CONTRACT_OWNER();
    error HASH_FOR_SIGNATURE_INVALID();
    error EIP1271_VALIDATION_CALL_FAILED();
    error PAYMASTER_ENTRY_POINT_ADDRESS_INVALID();
    error PAYMASTER_GAS_TO_LOW_FOR_POSTOP();
    error PAYMASTER_REQUIRED_PREFUND_TOO_LARGE();
    error PAYMASTER_AND_DATA_LENGTH_INVALID();
    error PAYMASTER_UNKNOWN_WALLET_FACTORY();
}
