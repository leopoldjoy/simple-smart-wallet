// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
import {EntryPoint} from "account-abstraction/core/EntryPoint.sol";
import {UserOperation} from "account-abstraction/interfaces/UserOperation.sol";
import {DecodeCalldata} from "@soulwallet/contracts/libraries/DecodeCalldata.sol";

/**
 * @title Bundler
 * @notice A simple Bundler mock contract for testing
 * @dev Obviously in a production environment the bundler would collect
 * UserOperations from an alternate mempool.
 */
contract Bundler is Test {
    using DecodeCalldata for bytes;

    /**
     * @dev Posts a UserOperation to the mock bundler
     * @param entryPoint The address of the entryPoint that the bundler should call handleOps() on
     * @param userOp The UserOperation that the bundler should send to the entryPoint
     */
    function post(IEntryPoint entryPoint, UserOperation calldata userOp) external {
        {
            uint256 snapshotId = vm.snapshot();

            (bool success, bytes memory data) = address(entryPoint).call( // Note that staticcall cannot be used
                abi.encodeWithSignature(
                    "simulateValidation((address,uint256,bytes,bytes,uint256,uint256,uint256,uint256,uint256,bytes,bytes))",
                    userOp
                )
            );

            vm.revertTo(snapshotId);

            if (!success) {
                bytes4 methodId = data.decodeMethodId();
                if (methodId == IEntryPoint.ValidationResult.selector) {
                    // Success case
                } else {
                    if (methodId == IEntryPoint.FailedOp.selector) {
                        // Error: FailedOp(uint256 opIndex, string reason);
                        bytes memory innerData = data.decodeMethodCalldata();
                        (uint256 opIndex, string memory reason) = abi.decode(innerData, (uint256, string));
                        console.log("FailedOp:", opIndex, reason);
                    }
                    assembly {
                        revert(add(data, 0x20), mload(data))
                    }
                }
            } else {
                revert("The simulateValidation() call failed!");
            }
        }

        UserOperation[] memory userOperations = new UserOperation[](1);
        userOperations[0] = userOp;
        address payable beneficiary = payable(address(0x111));
        uint256 gas_before = gasleft();
        entryPoint.handleOps(userOperations, beneficiary);
        uint256 gas_after = gasleft();
        console.log("entryPoint.handleOps => gas:", gas_before - gas_after);
    }
}
