// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import {Bundler} from "./Bundler.sol";
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

/**
 * @title BatchedWalletExecutionTest
 * @notice The contract tests all of the execution functions of the BatchedWallet.
 */
contract BatchedWalletExecutionTest is Test, TestHelpers {
    Bundler public bundler;
    EntryPoint entryPoint;
    BatchedWalletFactory bwFactory;
    bytes32 salt = bytes32(0);

    function setUp() public {
        entryPoint = new EntryPoint();
        bwFactory = new BatchedWalletFactory(address(entryPoint));
        bundler = new Bundler();
    }

    function deploy() public returns (address payable sender, address walletOwner, uint256 walletOwnerPrivateKey) {
        (walletOwner, walletOwnerPrivateKey) = makeAddrAndKey("walletOwner");

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

        vm.deal(userOperation.sender, 10 ether);
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

    function test_Execute() public {
        (address payable sender, address walletOwner, uint256 walletOwnerPrivateKey) = deploy();

        ERC20Mock tokenERC20 = new ERC20Mock();
        ERC20Mock tokenERC20A = new ERC20Mock();

        tokenERC20.mint(sender, 10 ether);
        tokenERC20A.mint(sender, 10 ether);

        IBatchedWallet bw = IBatchedWallet(sender);

        {
            address tokenCallAddress = address(tokenERC20);
            uint256 tokenCallValue = 0;
            bytes memory tokenCallData = abi.encodeWithSelector(tokenERC20.transfer.selector, address(0x111), 0.6 ether);

            {
                vm.prank(address(0x111));
                vm.expectRevert(Errors.NON_ENTRY_POINT_CALLER.selector);
                bw.execute(
                    tokenCallAddress,
                    tokenCallValue,
                    tokenCallData
                );
            }
            {
                vm.expectRevert(Errors.NON_ENTRY_POINT_CALLER.selector);
                vm.prank(sender);
                bw.execute(
                    tokenCallAddress,
                    tokenCallValue,
                    tokenCallData
                );
            }
            {
                vm.prank(walletOwner);
                vm.expectRevert(Errors.NON_ENTRY_POINT_CALLER.selector);
                bw.execute(
                    tokenCallAddress,
                    tokenCallValue,
                    tokenCallData
                );
            }
            {
                UserOperation memory userOperation = populateTransferUserOp(
                    sender,
                    walletOwnerPrivateKey,
                    1,
                    abi.encodeWithSignature(
                        "execute(address,uint256,bytes)", tokenCallAddress, tokenCallValue, tokenCallData
                    )
                );

                bundler.post(entryPoint, userOperation);
                assertEq(ERC20Mock(tokenERC20).balanceOf(address(0x111)), 0.6 ether, "Transfer of token amount failed!");
            }
        }
    }

    function test_ExecuteBatchWithoutValue() public {
        (address payable sender, , uint256 walletOwnerPrivateKey) = deploy();

        ERC20Mock tokenERC20 = new ERC20Mock();
        ERC20Mock tokenERC20A = new ERC20Mock();

        tokenERC20.mint(sender, 10 ether);
        tokenERC20A.mint(sender, 10 ether);

        IBatchedWallet bw = IBatchedWallet(sender);

        // function executeBatch(address[] calldata dest, bytes[] calldata data)
        {
            address[] memory dest = new address[](2);
            dest[0] = address(tokenERC20);
            dest[1] = address(tokenERC20A);

            bytes[] memory data = new bytes[](2);
            data[0] = abi.encodeWithSelector(tokenERC20.transfer.selector, address(0x111), 0.6 ether);
            data[1] = abi.encodeWithSelector(tokenERC20A.transfer.selector, address(0x112), 0.7 ether);
            {
                vm.prank(address(0x111));
                vm.expectRevert(Errors.NON_ENTRY_POINT_CALLER.selector);
                bw.executeBatch(dest, data);
            }
            {
                UserOperation memory userOperation = populateTransferUserOp(
                    sender,
                    walletOwnerPrivateKey,
                    1,
                    abi.encodeWithSignature(
                        "executeBatch(address[],bytes[])", dest, data
                    )
                );

                bundler.post(entryPoint, userOperation);
                assertEq(ERC20Mock(tokenERC20).balanceOf(address(0x111)), 0.6 ether, "Transfer of token amount to address #1 failed!");
                assertEq(ERC20Mock(tokenERC20A).balanceOf(address(0x112)), 0.7 ether, "Transfer of token amount to address #2 failed!");
            }
        }
    }

    function test_ExecuteBatchWithZeroValuesSet() public {
        (address payable sender, , uint256 walletOwnerPrivateKey) = deploy();

        ERC20Mock tokenERC20 = new ERC20Mock();
        ERC20Mock tokenERC20A = new ERC20Mock();

        tokenERC20.mint(sender, 10 ether);
        tokenERC20A.mint(sender, 10 ether);

        IBatchedWallet bw = IBatchedWallet(sender);

        // function executeBatch(address[] calldata dest, uint256[] calldata value, bytes[] calldata data)
        {
            address[] memory dest = new address[](2);
            dest[0] = address(tokenERC20);
            dest[1] = address(tokenERC20A);

            uint256[] memory value = new uint256[](2);
            value[0] = 3 ether;
            value[1] = 4 ether;

            bytes[] memory data = new bytes[](2);
            data[0] = abi.encodeWithSelector(tokenERC20.transfer.selector, address(0x111), 3 ether);
            data[1] = abi.encodeWithSelector(tokenERC20A.transfer.selector, address(0x112), 4 ether);
            {
                vm.prank(address(0x111));
                vm.expectRevert(Errors.NON_ENTRY_POINT_CALLER.selector);
                bw.executeBatch(dest, data);
            }
            {
                UserOperation memory userOperation = populateTransferUserOp(
                    sender,
                    walletOwnerPrivateKey,
                    1,
                    abi.encodeWithSignature(
                        "executeBatch(address[],bytes[])", dest, data
                    )
                );
                bundler.post(entryPoint, userOperation);

                assertEq(ERC20Mock(tokenERC20).balanceOf(address(0x111)), 3 ether, "Transfer of token amount to address #1 failed!");
                assertEq(ERC20Mock(tokenERC20A).balanceOf(address(0x112)), 4 ether, "Transfer of token amount to address #2 failed!");
            }
        }
    }

    function test_ExecuteBatchWithValuesSet() public {
        (address payable sender, , uint256 walletOwnerPrivateKey) = deploy();

        EtherReceiverMock ethReceiverMock1 = new EtherReceiverMock();
        ethReceiverMock1.setAcceptEther(true);
        EtherReceiverMock ethReceiverMock2 = new EtherReceiverMock();
        ethReceiverMock2.setAcceptEther(true);

        // function executeBatch(address[] calldata dest, uint256[] calldata value, bytes[] calldata data)
        {
            address[] memory dest = new address[](2);
            dest[0] = address(ethReceiverMock1);
            dest[1] = address(ethReceiverMock2);

            uint256[] memory value = new uint256[](2);
            value[0] = 3 ether;
            value[1] = 4 ether;

            bytes[] memory data = new bytes[](2);

            vm.deal(sender, 8 ether);

            UserOperation memory userOperation = populateTransferUserOp(
                sender,
                walletOwnerPrivateKey,
                1,
                abi.encodeWithSignature(
                    "executeBatch(address[],uint256[],bytes[])", dest, value, data
                )
            );
            bundler.post(entryPoint, userOperation);

            assertEq(address(ethReceiverMock1).balance, 3 ether, "Transfer of ETH to contract #1 failed!");
            assertEq(address(ethReceiverMock2).balance, 4 ether, "Transfer of ETH to contract #2 failed!");
        }
    }
}
