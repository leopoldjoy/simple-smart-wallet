// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import {Bundler} from "@testing/batchedwallet/Bundler.sol";
import {EntryPoint} from "account-abstraction/core/EntryPoint.sol";
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
import {UserOperation} from "account-abstraction/interfaces/UserOperation.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {EtherReceiverMock} from "@openzeppelin/contracts/mocks/EtherReceiverMock.sol";
import {IBatchedWallet} from "@source/interface/IBatchedWallet.sol";
import {BatchedWallet} from "@source/BatchedWallet.sol";
import {BatchedWalletFactory} from "@source/BatchedWalletFactory.sol";
import {Errors} from "@source/helper/Errors.sol";
import {TestHelpers} from "@testing/helpers/TestHelpers.sol";
import {SponsorshipPaymaster} from "@source/SponsorshipPaymaster.sol";

/**
 * @title BatchedWalletWithSponsorshipPaymasterTest
 * @notice The contract tests the functionalites of the BatchedWallet when using a
 * SponsorshipPaymaster to cover the fee costs.
 */
contract BatchedWalletWithSponsorshipPaymasterTest is Test, TestHelpers {
    Bundler public bundler;
    EntryPoint entryPoint;
    BatchedWalletFactory bwFactory;
    bytes32 salt = bytes32(0);

    function setUp() public {
        entryPoint = new EntryPoint();
        bwFactory = new BatchedWalletFactory(address(entryPoint));
        bundler = new Bundler();
    }

    function test_DeployUsingSponsorshipPaymaster() public {
        address paymasterOwner = makeAddr("paymasterOwner");
        SponsorshipPaymaster paymaster = new SponsorshipPaymaster(address(entryPoint), paymasterOwner, address(bwFactory));

        (address walletOwner, uint256 walletOwnerPrivateKey) = makeAddrAndKey("walletOwner");

        bytes memory initCode;
        address payable sender;
        {
            sender = payable(bwFactory.getAddress(walletOwner, salt));

            bytes memory bwFactoryCall = abi.encodeWithSignature("createWallet(address,bytes32)", walletOwner, salt);
            initCode = abi.encodePacked(address(bwFactory), bwFactoryCall);
        }

        bytes memory callData;
        bytes memory paymasterAndData = abi.encodePacked(address(paymaster));
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

        // UserOperation should fail since the sender has no ETH and the paymaster hasn't
        // deposited ETH into the entry point yet
        vm.expectRevert(abi.encodeWithSelector(IEntryPoint.FailedOp.selector, 0, "AA31 paymaster deposit too low"));
        bundler.post(entryPoint, userOperation);
        assertEq(sender.code.length, 0, "A1:sender.code.length != 0");

        // Deposit Ether into the entry point
        vm.deal(paymasterOwner, 1 ether);
        vm.prank(paymasterOwner);
        entryPoint.depositTo{value: 0.5 ether}(address(paymaster));
        assertEq(entryPoint.balanceOf(address(paymaster)), 0.5 ether, "deposit on the entryPoint should be 0.5 ether!");

        // The UserOperation should now work and get paid for by the paymaster
        assertEq(address(userOperation.sender).balance, 0, "userOp sender balance should be zero!");
        bundler.post(entryPoint, userOperation);
        assertEq(sender.code.length > 0, true, "A2:sender.code.length == 0");
        assertEq(BatchedWallet(sender).owner(), walletOwner);
    }

    function populateTransferUserOp(
        address payable sender,
        uint256 walletOwnerPrivateKey,
        uint256 nonce,
        bytes memory callData,
        bytes memory paymasterAndData
    ) internal view returns (UserOperation memory userOperation) {
        bytes memory initCode;
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

    function test_TransferERC20UsingSponsorshipPaymaster() public {
        address paymasterOwner = makeAddr("paymasterOwner");
        SponsorshipPaymaster paymaster = new SponsorshipPaymaster(address(entryPoint), paymasterOwner, address(bwFactory));

        (address walletOwner, uint256 walletOwnerPrivateKey) = makeAddrAndKey("walletOwner");

        bytes memory initCode;
        address payable sender;
        {
            sender = payable(bwFactory.getAddress(walletOwner, salt));

            bytes memory bwFactoryCall = abi.encodeWithSignature("createWallet(address,bytes32)", walletOwner, salt);
            initCode = abi.encodePacked(address(bwFactory), bwFactoryCall);
        }

        bytes memory callData;
        bytes memory paymasterAndData = abi.encodePacked(address(paymaster));
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

        // Deposit Ether into the entry point
        vm.deal(paymasterOwner, 1 ether);
        vm.prank(paymasterOwner);
        entryPoint.depositTo{value: 0.5 ether}(address(paymaster));

        // The UserOperation should now work and get paid for by the paymaster
        assertEq(address(userOperation.sender).balance, 0, "userOp sender balance should be zero!");
        bundler.post(entryPoint, userOperation);
        assertEq(sender.code.length > 0, true, "A2:sender.code.length == 0");
        assertEq(BatchedWallet(sender).owner(), walletOwner);

        ERC20Mock tokenERC20 = new ERC20Mock();
        tokenERC20.mint(sender, 10 ether);

        bytes memory tokenCallData = abi.encodeWithSelector(tokenERC20.transfer.selector, address(0x111), 0.6 ether);

        UserOperation memory newUserOperation = populateTransferUserOp(
            sender,
            walletOwnerPrivateKey,
            1,
            abi.encodeWithSignature(
                "execute(address,uint256,bytes)", address(tokenERC20), 0, tokenCallData
            ),
            paymasterAndData
        );

        assertEq(address(userOperation.sender).balance, 0, "userOp sender balance should be zero!");
        bundler.post(entryPoint, newUserOperation);
        assertEq(ERC20Mock(tokenERC20).balanceOf(address(0x111)), 0.6 ether, "Transfer of token amount failed!");
    }
}
