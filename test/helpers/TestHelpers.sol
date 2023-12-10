// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
import {UserOperation} from "account-abstraction/interfaces/UserOperation.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/**
 * @title TestHelpers
 * @notice A collection of helper functions to be inherited by test contracts
 */
abstract contract TestHelpers is Test {
    using MessageHashUtils for bytes32;

    /**
     * @notice Generates the bytes32 hash representing the provided UserOperation
     * @param entryPoint The EntryPoint to use for the generation
     * @param userOp The UserOperation from which to generate the hash
     * @return hash Resulting bytes32 hash
     */
    function getUserOpHash(IEntryPoint entryPoint, UserOperation memory userOp) public view returns (bytes32 hash) {
        hash = entryPoint.getUserOpHash(userOp).toEthSignedMessageHash();
    }

    /**
     * @notice Signs a UserOperation using the provided private key to generate a signature
     * @param entryPoint The EntryPoint to use for the generation
     * @param userOp The UserOperation from which to generate the hash
     * @param privateKey The private key to use for signing
     * @return signature The resulting bytes signature
     */
    function signUserOp(IEntryPoint entryPoint, UserOperation memory userOp, uint256 privateKey) public view returns (bytes memory signature) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, getUserOpHash(entryPoint, userOp));
        bytes memory signatureData = abi.encodePacked(r, s, v);
        signature = signatureData;
    }

    /**
     * @notice Populates a UserOperation using the input fields
     * @param sender The sender for the new UserOperation
     * @param nonce The nonce for the new UserOperation
     * @param initCode The initCode for the new UserOperation
     * @param callData The callData for the new UserOperation
     * @param paymasterAndData The paymasterAndData for the new UserOperation
     * @param signature The signature for the new UserOperation
     * @return userOperation The resulting UserOperation
     */
    function populateUserOp(
        address payable sender,
        uint256 nonce,
        bytes memory initCode,
        bytes memory callData,
        bytes memory paymasterAndData,
        bytes memory signature
    ) public pure returns (UserOperation memory userOperation) {
        uint256 callGasLimit = 1000000;
        uint256 verificationGasLimit = 1000000;
        uint256 preVerificationGas = 100000;
        uint256 maxFeePerGas = 10 gwei;
        uint256 maxPriorityFeePerGas = 10 gwei;
        userOperation = UserOperation(
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
}
