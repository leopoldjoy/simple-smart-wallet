// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script, console} from "@forge-std/Script.sol";
import {TestHelpers} from "@testing/helpers/TestHelpers.sol";
import {IEntryPoint} from "@account-abstraction/interfaces/IEntryPoint.sol";
import {UserOperation} from "@account-abstraction/interfaces/UserOperation.sol";

/**
 * @title DeployBatchedWalletFactory
 * @notice The contract deploys a BatchedWalletFactory connected to the Sepolia entry point
 * @dev Since the Sepolia entry point address is hardcoded, this script should only be ran
 * when connected to the Sepolia testnet. Note that in order to run this script the following
 * environment variables must be set:
 *      PRIVATE_KEY: the private key used for deployment
 *      USEROP_SENDER: the sender for the UserOperation
 *      USEROP_NONCE: the nonce for the UserOperation
 * 
 * The following environment variables may OPTIONALLY be set:
 *      USEROP_INIT_CODE: the encoded initCode for the UserOperation
 *      USEROP_CALL_DATA_ADDRESS: the address for the callData of the UserOperation
 *      USEROP_CALL_DATA_VALUE: the value (ETH in wei) for the callData of the UserOperation
 *      USEROP_CALL_DATA_CALL_DATA: the callData for the callData of the UserOperation
 *      USEROP_CALL_GAS_LIMIT: the gasLimit for the UserOperation
 *      USEROP_VERIFICATION_GAS_LIMIT: the verificationGasLimit for the UserOperation
 *      USEROP_PREVERIFICATION_GAS: the preverificationGas for the UserOperation
 *      USEROP_MAX_FEE_PER_GAS: the maxFeePerGas for the UserOperation
 *      USEROP_MAX_PRIORITY_FEE_PER_GAS: the priorityFeePerGas for the UserOperation
 *      USEROP_PAYMASTER_ADDRESS: the paymaster address for inclusion in the paymasterAndData of the UserOperation
 */
contract SignUserOpUtil is Script, TestHelpers {
    // Address of the EntryPoint contract on Sepolia
    address private constant ENTRYPOINT = 0x0576a174D229E3cFA37253523E645A78A0C91B57;

    function getOptionalUint256EnvVar(string memory envVar) private view returns (uint256 result) {
        try vm.envUint(envVar) returns (uint256 _result) {
            result = _result;
        // solhint-disable-next-line no-empty-blocks
        } catch {}
    }

    function getOptionalBytesEnvVar(string memory envVar) private view returns (bytes memory result) {
        try vm.envBytes(envVar) returns (bytes memory _result) {
            result = _result;
        // solhint-disable-next-line no-empty-blocks
        } catch {}
    }

    function getOptionalAddressEnvVar(string memory envVar) private view returns (address result) {
        try vm.envAddress(envVar) returns (address _result) {
            result = _result;
        // solhint-disable-next-line no-empty-blocks
        } catch {}
    }

    function run() external view {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        UserOperation memory userOp;

        {
            address sender = vm.envAddress("USEROP_SENDER");
            uint256 nonce = vm.envUint("USEROP_NONCE");

            bytes memory initCode = getOptionalBytesEnvVar("USEROP_INIT_CODE");

            address callDataToken = getOptionalAddressEnvVar("USEROP_CALL_DATA_ADDRESS");
            uint256 callDataValue = getOptionalUint256EnvVar("USEROP_CALL_DATA_VALUE");
            bytes memory callDataCallData = getOptionalBytesEnvVar("USEROP_CALL_DATA_CALL_DATA");

            bytes memory callData = abi.encodeWithSignature(
                "execute(address,uint256,bytes)", callDataToken, callDataValue, callDataCallData
            );

            uint256 callGasLimit = getOptionalUint256EnvVar("USEROP_CALL_GAS_LIMIT");
            uint256 verificationGasLimit = getOptionalUint256EnvVar("USEROP_VERIFICATION_GAS_LIMIT");
            uint256 preVerificationGas = getOptionalUint256EnvVar("USEROP_PREVERIFICATION_GAS");
            uint256 maxFeePerGas = getOptionalUint256EnvVar("USEROP_MAX_FEE_PER_GAS");
            uint256 maxPriorityFeePerGas = getOptionalUint256EnvVar("USEROP_MAX_PRIORITY_FEE_PER_GAS");

            if (callGasLimit == 0) {
                callGasLimit = 100000;
            }
            if (verificationGasLimit == 0) {
                verificationGasLimit = 100000;
            }
            if (preVerificationGas == 0) {
                preVerificationGas = 10000;
            }
            if (maxFeePerGas == 0) {
                maxFeePerGas = 2 gwei;
            }
            if (maxPriorityFeePerGas == 0) {
                maxPriorityFeePerGas = 2 gwei;
            }

            bytes memory paymasterAndData;
            {
                address paymasterAddress = getOptionalAddressEnvVar("USEROP_PAYMASTER_ADDRESS");
                if (paymasterAddress != address(0)) {
                    paymasterAndData = abi.encodePacked(paymasterAddress);
                }
            }

            bytes memory signature;
            userOp = UserOperation(
                sender,
                nonce,
                initCode,
                callData,
                callGasLimit,
                verificationGasLimit,
                preVerificationGas,
                maxFeePerGas,
                maxPriorityFeePerGas,
                paymasterAndData,
                signature
            );
        }

        /* solhint-disable no-console */
        console.log("SIGNATURE RESULTING FROM USEROP:");
        console.logBytes(signUserOp(IEntryPoint(ENTRYPOINT), userOp, deployerPrivateKey));
        console.log("");
        console.log("USER OP DETAILS:");
        console.log("sender:");
        console.log(userOp.sender);
        console.log("nonce:");
        console.log(userOp.nonce);
        console.log("initCode:");
        console.logBytes(userOp.initCode);
        console.log("callData:");
        console.logBytes(userOp.callData);
        console.log("callGasLimit:");
        console.log(userOp.callGasLimit);
        console.log("verificationGasLimit:");
        console.log(userOp.verificationGasLimit);
        console.log("preVerificationGas:");
        console.log(userOp.preVerificationGas);
        console.log("maxFeePerGas:");
        console.log(userOp.maxFeePerGas);
        console.log("maxPriorityFeePerGas:");
        console.log(userOp.maxPriorityFeePerGas);
        console.log("paymasterAndData:");
        console.logBytes(userOp.paymasterAndData);
        /* solhint-enable no-console */
    }
}
