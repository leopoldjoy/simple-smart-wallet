// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "@forge-std/Test.sol";
import {Bundler} from "./Bundler.sol";
import {EntryPoint} from "@account-abstraction/core/EntryPoint.sol";
import {UserOperation} from "@account-abstraction/interfaces/UserOperation.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {BatchedWallet} from "@source/BatchedWallet.sol";
import {BatchedWalletFactory} from "@source/BatchedWalletFactory.sol";
import {TestHelpers} from "@testing/helpers/TestHelpers.sol";
import {IERC1271} from "@openzeppelin/contracts/interfaces/IERC1271.sol";

/**
 * @title BatchedWalletIsValidateSingatureTest
 * @notice The contract tests the correct operation of the BatchedWallet's EIP-1271 compliant
 * isValidateSingature() function implementation.
 */
contract BatchedWalletIsValidateSingatureTest is Test, TestHelpers {
    using MessageHashUtils for bytes32;

    Bundler public bundler;
    EntryPoint public entryPoint;
    BatchedWalletFactory public bwFactory;
    address public walletOwner;
    uint256 public ownerPrivateKey;
    address payable public sender;
    bytes4 internal constant MAGICVALUE = 0x1626ba7e;
    bytes4 internal constant INVALID_ID = 0xffffffff;

    function setUp() public {
        (walletOwner, ownerPrivateKey) = makeAddrAndKey("owner1");
        bytes32 salt = bytes32(0);
        
        entryPoint = new EntryPoint();
        bwFactory = new BatchedWalletFactory(address(entryPoint));
        bundler = new Bundler();

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

        userOperation.signature = signUserOp(entryPoint, userOperation, ownerPrivateKey);

        vm.deal(userOperation.sender, 10 ether);
        bundler.post(entryPoint, userOperation);
        assertEq(sender.code.length > 0, true, "A2:sender.code.length == 0");
        assertEq(BatchedWallet(sender).owner(), walletOwner);
    }

    function testIsValidateSignauture() public {
        bytes32 hash = keccak256(abi.encodePacked("hello world"));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, hash.toEthSignedMessageHash());
        bytes memory sig = abi.encodePacked(r, s, v);
        assertEq(sig.length, 65);

        bytes4 validResult = IERC1271(sender).isValidSignature(hash, sig);
        assertEq(validResult, MAGICVALUE);
    }

    function testIsValidateSignautureInvalidCase() public {
        bytes32 hash = keccak256(abi.encodePacked("hello world"));
        bytes32 otherHash = keccak256(abi.encodePacked("hello world other"));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, hash.toEthSignedMessageHash());
        bytes memory sig = abi.encodePacked(r, s, v);
        assertEq(sig.length, 65);

        bytes4 validResult = IERC1271(sender).isValidSignature(otherHash, sig);
        assertEq(validResult, INVALID_ID);
    }
}
