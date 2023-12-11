// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "@forge-std/Test.sol";
import {BatchedWallet} from "@source/BatchedWallet.sol";
import {BatchedWalletFactory} from "@source/BatchedWalletFactory.sol";
import {IEntryPoint} from "@account-abstraction/interfaces/IEntryPoint.sol";
import {EntryPoint} from "@account-abstraction/core/EntryPoint.sol";
import {UserOperation} from "@account-abstraction/interfaces/UserOperation.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {Bundler} from "./Bundler.sol";
import {TestHelpers} from "@testing/helpers/TestHelpers.sol";

/**
 * @title BatchedWalletDeployTest
 * @notice The contract tests the deployment of the BatchedWallet
 */
contract BatchedWalletDeployTest is Test, TestHelpers {
    using MessageHashUtils for bytes32;

    BatchedWallet public bw;
    BatchedWalletFactory public bwFactory;
    IEntryPoint public entryPoint;
    Bundler public bundler;
    address public user = address(12345);
    bytes32 public salt = bytes32(0);

    function setUp() public {
        entryPoint = new EntryPoint();
        bwFactory = new BatchedWalletFactory(address(entryPoint));
        bundler = new Bundler();
    }
    
    function testBatchedWalletDeployment() public{
        vm.prank(user);
        BatchedWallet batchedWallet = bwFactory.createWallet(user, salt);
        assertEq(address(batchedWallet), bwFactory.getAddress(user, salt));
    }

    function testBatchedWalletOwner() public{
        vm.prank(user);
        BatchedWallet batchedWallet = bwFactory.createWallet(user, salt);
        assertEq(batchedWallet.owner(), user);
    }

    function testBatchedWalletEntryPoint() public{
        vm.prank(user);
        BatchedWallet batchedWallet = bwFactory.createWallet(user, salt);
        assertEq(address(batchedWallet.entryPoint()), address(entryPoint));
    }

    function testDeployByFactory() public {
        address payable sender;
        bytes memory initCode;

        (address walletOwner, uint256 walletOwnerPrivateKey) = makeAddrAndKey("walletOwner");
        {
            sender = payable(bwFactory.getAddress(walletOwner, salt));

            bytes memory bwFactoryCall =
                abi.encodeWithSignature("createWallet(address,bytes32)", walletOwner, salt);
            initCode = abi.encodePacked(address(bwFactory), bwFactoryCall);
        }

        bytes memory callData;
        bytes memory paymasterAndData;
        bytes memory signature;
        UserOperation memory userOperation = populateUserOp(
            sender,
            0,
            initCode,
            callData,
            paymasterAndData,
            signature
        );

        userOperation.signature = signUserOp(entryPoint, userOperation, walletOwnerPrivateKey);
        
        vm.expectRevert(abi.encodeWithSelector(IEntryPoint.FailedOp.selector, 0, "AA21 didn't pay prefund"));
        bundler.post(entryPoint, userOperation);
        assertEq(sender.code.length, 0, "A1:sender.code.length != 0");

        vm.deal(userOperation.sender, 10 ether);
        bundler.post(entryPoint, userOperation);
        assertEq(sender.code.length > 0, true, "A2:sender.code.length == 0");
        assertEq(BatchedWallet(sender).owner(), walletOwner);
    }

    function populateSignMessageUserOp(
        address payable sender,
        bytes32 hashToSign,
        uint256 walletOwnerPrivateKey,
        uint256 nonce
    ) internal view returns (UserOperation memory userOperation) {
        bytes memory initCode;
        bytes memory callData = abi.encodeWithSignature(
            "signMessage(bytes32)", hashToSign
        );
        bytes memory paymasterAndData;
        bytes memory signature;
        userOperation = populateUserOp(
            sender,
            nonce,
            initCode,
            callData,
            paymasterAndData,
            signature
        );

        userOperation.signature = signUserOp(entryPoint, userOperation, walletOwnerPrivateKey);
    }

    function testDeployByFactoryWithContractAsOwner() public {
        address payable sender;
        bytes memory initCode;

        (address walletOwner, uint256 walletOwnerPrivateKey) = makeAddrAndKey("walletOwner");
        {
            sender = payable(bwFactory.getAddress(walletOwner, salt));

            bytes memory bwFactoryCall =
                abi.encodeWithSignature("createWallet(address,bytes32)", walletOwner, salt);
            initCode = abi.encodePacked(address(bwFactory), bwFactoryCall);
        }

        bytes memory callData;
        bytes memory paymasterAndData;
        bytes memory signature;
        UserOperation memory userOperation = populateUserOp(
            sender,
            0,
            initCode,
            callData,
            paymasterAndData,
            signature
        );

        userOperation.signature = signUserOp(entryPoint, userOperation, walletOwnerPrivateKey);

        vm.deal(userOperation.sender, 10 ether);
        bundler.post(entryPoint, userOperation);
        assertEq(sender.code.length > 0, true, "A2:sender.code.length == 0");
        assertEq(BatchedWallet(sender).owner(), walletOwner);

        // Now we test creating another new BatchedWallet that is owned by the 
        // one above (a BatchedWallet with another BatchedWallet as its owner)

        address payable newSender;
        bytes memory newInitCode;

        {
            newSender = payable(bwFactory.getAddress(sender, salt));

            bytes memory bwFactoryCall =
                abi.encodeWithSignature("createWallet(address,bytes32)", sender, salt);
            newInitCode = abi.encodePacked(address(bwFactory), bwFactoryCall);
        }

        UserOperation memory newUserOperation = populateUserOp(
            newSender,
            0,
            newInitCode,
            callData,
            paymasterAndData,
            signature
        );

        bytes32 hashToSign = getUserOpHash(entryPoint, newUserOperation);
        UserOperation memory signContractMessageUserOp
            = populateSignMessageUserOp(sender, hashToSign, walletOwnerPrivateKey, 1);

        bundler.post(entryPoint, signContractMessageUserOp);
        assertEq(BatchedWallet(sender).signedMessages(hashToSign), true, "hash should already be signed");
        
        vm.expectRevert(abi.encodeWithSelector(IEntryPoint.FailedOp.selector, 0, "AA21 didn't pay prefund"));
        bundler.post(entryPoint, newUserOperation);
        assertEq(newSender.code.length, 0, "A1:newSender.code.length != 0");

        vm.deal(newUserOperation.sender, 10 ether);
        bundler.post(entryPoint, newUserOperation);
        assertEq(newSender.code.length > 0, true, "A2:newSender.code.length == 0");
        assertEq(BatchedWallet(newSender).owner(), sender);
    }
}
