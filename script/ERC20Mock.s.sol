// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

/**
 * @title DeployERC20Mock
 * @notice The contract deploys a ERC20Mock contract
 * @dev Note that in order to run this script the following environment variables
 * must be set:
 *      PRIVATE_KEY: the private key used for deployment
 */
contract DeployERC20Mock is Script {

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        new ERC20Mock();
        vm.stopBroadcast();
    }
}
