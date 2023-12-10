// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import {BatchedWallet} from "@source/BatchedWallet.sol";
import {BatchedWalletFactory} from "@source/BatchedWalletFactory.sol";
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
import {EntryPoint} from "account-abstraction/core/EntryPoint.sol";
import {UserOperation} from "account-abstraction/interfaces/UserOperation.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {Bundler} from "./Bundler.sol";
import {TestHelpers} from "@testing/helpers/TestHelpers.sol";

/**
 * @title BatchedWalletReceiveEtherTest
 * @notice The contract tests that the BatchedWallet can effectively receive Ether
 */
contract BatchedWalletReceiveEtherTest is Test, TestHelpers {
    using MessageHashUtils for bytes32;

    BatchedWallet public bw;
    BatchedWalletFactory public bwFactory;
    IEntryPoint entryPoint;
    Bundler public bundler;
    address user = address(12345);
    bytes32 salt = bytes32(0);

    function setUp() public {
        entryPoint = new EntryPoint();
        bwFactory = new BatchedWalletFactory(address(entryPoint));
        bundler = new Bundler();
    }

    function deploy(string memory addrKeyString) private returns (address payable sender, address walletOwner, uint256 walletOwnerPrivateKey) {
        (walletOwner, walletOwnerPrivateKey) = makeAddrAndKey(addrKeyString);

        bytes memory initCode;
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

        vm.deal(userOperation.sender, 1 ether);
        bundler.post(entryPoint, userOperation);
        assertEq(sender.code.length > 0, true, "A2:sender.code.length == 0");
        assertEq(BatchedWallet(sender).owner(), walletOwner);

        return (sender, walletOwner, walletOwnerPrivateKey);
    }

    function populateTransferUserOp(
        address payable sender,
        uint256 walletOwnerPrivateKey,
        uint256 nonce,
        bytes memory callData
    ) internal view returns (UserOperation memory userOperation) {
        bytes memory initCode;
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

    function test_DeployByFactory() public {
        (address payable sender1, , uint256 walletOwnerPrivateKey1) = deploy("walletOwner1");
        (address sender2, , ) = deploy("walletOwner2");

        uint256 balBefore1 = address(sender1).balance;
        uint256 balBefore2 = address(sender2).balance;

        // function executeBatch(address[] calldata dest, uint256[] calldata value, bytes[] calldata data)
        {
            vm.deal(sender1, 8 ether);
            bytes memory data;
            UserOperation memory userOperation = populateTransferUserOp(
                sender1,
                walletOwnerPrivateKey1,
                1,
                abi.encodeWithSignature(
                    "execute(address,uint256,bytes)", address(sender2), 3 ether, data
                )
            );
            bundler.post(entryPoint, userOperation);

            uint256 balChange1 = address(sender1).balance - balBefore1;
            uint256 balChange2 = address(sender2).balance - balBefore2;

            assertEq((balChange1 / 1 ether), 4, "Incorrect ETH balance remaining in contract #1!");
            assertEq(balChange2, 3 ether, "Incorrect ETH balance in contract #2!");
        }
    }
}
