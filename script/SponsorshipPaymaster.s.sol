// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import {SponsorshipPaymaster} from "@source/SponsorshipPaymaster.sol";

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
    address constant ENTRYPOINT = 0x0576a174D229E3cFA37253523E645A78A0C91B57;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        require(deployerPrivateKey > 0, "PRIVATE_KEY env var not defined");
        address owner = vm.envAddress("OWNER_ADDRESS");
        require(owner != address(0), "no owner defined");
        address walletFactory = vm.envAddress("WALLET_FACTORY_ADDRESS");
        require(walletFactory != address(0), "walletFactory not provided");
        require(walletFactory.code.length > 0, "walletFactory must be deployed");
        vm.startBroadcast(deployerPrivateKey);
        new SponsorshipPaymaster(ENTRYPOINT, owner, walletFactory);
        vm.stopBroadcast();
    }
}
