// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/**
 * @title Errors
 * @dev A library of the errors used for the scripts
 */
library Errors {
    error DEPLOY_BATCHED_WALLET_NO_OWNER_DEFINED();
    error DEPLOY_BATCHED_WALLET_NO_FACTORY_ADDRESS_DEFINED();
    error DEPLOY_SPONSORSHIP_PAYMASTER_PRIVATE_KEY_NOT_DEFINED();
    error DEPLOY_SPONSORSHIP_PAYMASTER_NO_OWNER_DEFINED();
    error DEPLOY_SPONSORSHIP_PAYMASTER_NO_FACTORY_ADDRESS_DEFINED();
    error DEPLOY_SPONSORSHIP_PAYMASTER_FACTORY_CONTRACT_NOT_DEPLOYED();
}
