// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import {BatchedWalletFactory} from "@source/BatchedWalletFactory.sol";

/**
 * @title DeployBatchedWalletFactory
 * @notice The contract deploys a BatchedWalletFactory connected to the Sepolia entry point
 * @dev Since the Sepolia entry point address is hardcoded, this script should only be ran
 * when connected to the Sepolia testnet. Note that in order to run this script the following
 * environment variables must be set:
 *      PRIVATE_KEY: the private key used for deployment
 */
contract DeployBatchedWalletFactory is Script {
    // Address of the EntryPoint contract on Sepolia
    address constant ENTRYPOINT = 0x0576a174D229E3cFA37253523E645A78A0C91B57;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        new BatchedWalletFactory(ENTRYPOINT);
        vm.stopBroadcast();
    }
}
