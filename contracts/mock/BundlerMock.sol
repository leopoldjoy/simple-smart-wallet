// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

// import "forge-std/Test.sol";
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
import {EntryPoint} from "account-abstraction/core/EntryPoint.sol";
import {UserOperation} from "account-abstraction/interfaces/UserOperation.sol";
// import "@source/libraries/DecodeCalldata.sol";
import {DecodeCalldata} from "@soulwallet/contracts/libraries/DecodeCalldata.sol";

contract BundlerMock {
    using DecodeCalldata for bytes;
    /* 
        address sender;
        uint256 nonce;
        bytes initCode;
        bytes callData;
        uint256 callGasLimit;
        uint256 verificationGasLimit;
        uint256 preVerificationGas;
        uint256 maxFeePerGas;
        uint256 maxPriorityFeePerGas;
        bytes paymasterAndData;
        bytes signature;
     */
    function post(IEntryPoint entryPoint, UserOperation calldata userOp) external {
        // staticcall: function simulateValidation(UserOperation calldata userOp) external

        {
            (bool success, bytes memory data) = address(entryPoint).call( /* can not use staticcall */
                abi.encodeWithSignature(
                    "simulateValidation((address,uint256,bytes,bytes,uint256,uint256,uint256,uint256,uint256,bytes,bytes))",
                    userOp
                )
            );

            if (!success) {
                bytes4 methodId = data.decodeMethodId();
                if (methodId == IEntryPoint.ValidationResult.selector) {
                    // error ValidationResult(ReturnInfo returnInfo, StakeInfo senderInfo, StakeInfo factoryInfo, StakeInfo paymasterInfo);
                } else {
                    assembly {
                        revert(add(data, 0x20), mload(data))
                    }
                }
            } else {
                revert("failed");
            }
        }

        UserOperation[] memory userOperations = new UserOperation[](1);
        userOperations[0] = userOp;
        address payable beneficiary = payable(address(0x111));
        entryPoint.handleOps(userOperations, beneficiary);
    }
}
