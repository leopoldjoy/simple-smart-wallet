// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import {BundlerMock} from "@source/mock/BundlerMock.sol";

/**
 * @title DeployBundlerMock
 * @notice The contract deploys a BundlerMock contract
 * @dev Note that in order to run this script the following environment variables
 * must be set:
 *      PRIVATE_KEY: the private key used for deployment
 */
contract DeployBundlerMock is Script {

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        new BundlerMock();
        vm.stopBroadcast();
    }
}
