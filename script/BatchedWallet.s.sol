// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import {BatchedWalletFactory} from "@source/BatchedWalletFactory.sol";

/**
 * @title DeployBatchedWallet
 * @notice The contract deploys a BatchedWallet via an existing BatchedWalletFactory
 * @dev Note that in order to run this script the following environment variables
 * must be set:
 *      PRIVATE_KEY: the private key used for deployment
 *      OWNER_ADDRESS: the address to pass as the initial owner of the new BatchedWallet
 *      FACTORY_ADDRESS: the address of the BatchedWalletFactory that is used to deploy the BatchedWallet
 *      SALT: a bytes32 salt hash that is used to generate the new BatchedWallet address
 */
contract DeployBatchedWallet is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address owner = vm.envAddress("OWNER_ADDRESS");
        require(owner != address(0), "no owner defined");
        address bwFactoryAddr = vm.envAddress("FACTORY_ADDRESS");
        require(bwFactoryAddr != address(0), "no factory address defined");
        bytes32 salt = vm.envBytes32("SALT");
        vm.startBroadcast(deployerPrivateKey);

        BatchedWalletFactory(bwFactoryAddr).createWallet(owner, salt);

        vm.stopBroadcast();
    }
}
