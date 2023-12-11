// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "@forge-std/Script.sol";
import {SponsorshipPaymaster} from "@source/SponsorshipPaymaster.sol";
import {Errors} from "./Errors.sol";

/**
 * @title DeploySponsorshipPaymaster
 * @notice The contract deploys a SponsorshipPaymaster connected to the Sepolia entry point
 * @dev Since the Sepolia entry point address is hardcoded, this script should only be ran
 * when connected to the Sepolia testnet. Note that in order to run this script the following
 * environment variables must be set:
 *      PRIVATE_KEY: the private key used for deployment
 *      OWNER_ADDRESS: the address to pass as the initial owner of the new SponsorshipPaymaster
 *      WALLET_FACTORY_ADDRESS: the address of the BatchedWalletFactory who's BatchedWallets should
 *                              have the costs of their fees sponsored by this paymaster
 */
contract DeploySponsorshipPaymaster is Script {
    // Address of the EntryPoint contract on Sepolia
    address private constant ENTRYPOINT = 0x0576a174D229E3cFA37253523E645A78A0C91B57;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        if (deployerPrivateKey == 0) {
            revert Errors.DEPLOY_SPONSORSHIP_PAYMASTER_PRIVATE_KEY_NOT_DEFINED();
        }
        address owner = vm.envAddress("OWNER_ADDRESS");
        if (owner == address(0)) {
            revert Errors.DEPLOY_SPONSORSHIP_PAYMASTER_NO_OWNER_DEFINED();
        }
        address walletFactory = vm.envAddress("FACTORY_ADDRESS");
        if (walletFactory == address(0)) {
            revert Errors.DEPLOY_SPONSORSHIP_PAYMASTER_NO_FACTORY_ADDRESS_DEFINED();
        }
        if (walletFactory.code.length == 0) {
            revert Errors.DEPLOY_SPONSORSHIP_PAYMASTER_FACTORY_CONTRACT_NOT_DEPLOYED();
        }
        vm.startBroadcast(deployerPrivateKey);
        new SponsorshipPaymaster(ENTRYPOINT, owner, walletFactory);
        vm.stopBroadcast();
    }
}
