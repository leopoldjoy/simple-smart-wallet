// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {IEntryPoint} from "@account-abstraction/interfaces/IEntryPoint.sol";
import {BaseAccount} from "@account-abstraction/core/BaseAccount.sol";
import {UserOperation} from "@account-abstraction/interfaces/UserOperation.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {TokenCallbackHandler} from "@account-abstraction/samples/callback/TokenCallbackHandler.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IERC1271} from "@openzeppelin/contracts/interfaces/IERC1271.sol";
import {IBatchedWallet} from "@source/interface/IBatchedWallet.sol";
import {Errors} from "@source/helper/Errors.sol";

/**
 * @title BatchedWallet
 * @notice Manages all smart wallet functionality, including execution, validation and signing
 * @dev Inherits functionality from IBatchedWallet, OwnableUpgradeable, BaseAccount, UUPSUpgradeable
 * and TokenCallbackHandler
 */
contract BatchedWallet is
    IBatchedWallet,
    OwnableUpgradeable,
    BaseAccount,
    UUPSUpgradeable,
    TokenCallbackHandler
{
    using MessageHashUtils for bytes32;
    using ECDSA for bytes32;

    IEntryPoint private immutable ENTRY_POINT;

    // Mapping keeping track of all message hashes that have been approved ("signed")
    mapping(bytes32 => bool) public signedMessages;

    // Magic value indicating a valid signature (for ERC-1271 contracts)
    // bytes4(keccak256("isValidSignature(bytes32,bytes)")
    bytes4 internal constant EIP1271_SELECTOR = 0x1626ba7e;
    // Constant indicating invalid state (for ERC-1271 contracts)
    bytes4 internal constant EIP1271_INVALID_ID = 0xffffffff;

    modifier onlyEntryPoint() {
        if (msg.sender != address(ENTRY_POINT)) {
            revert Errors.NON_ENTRY_POINT_CALLER();
        }
        _;
    }

    /**
     * @dev Constructs the BatchedWallet contract
     * @param bwEntryPoint The address of the entryPoint to be associated with this BatchedWallet
     */
    constructor(address bwEntryPoint) {
        ENTRY_POINT = IEntryPoint(bwEntryPoint);
        _disableInitializers();
    }

    // solhint-disable-next-line no-empty-blocks
    receive() external payable {}

    /**
     * @dev To reduce gas cost, the ENTRY_POINT member is immutable. To upgrade the ENTRY_POINT,
     * a new implementation of BatchedWallet must be deployed with the new ENTRY_POINT, then the
     * implementation may be upgraded by calling `upgradeToAndCall()`.
     * @param walletOwner Initial owner of this BatchedWallet
     */
    function initialize(address walletOwner) public initializer {
        __Ownable_init(walletOwner);
        emit BatchedWalletInitialized(ENTRY_POINT, owner());
    }

    /**
     * @notice Marks a message (`hash`) as signed.
     * @dev Verification via the EIP-1271 validation method is possible by passing the pre-image of the
     * message hash and empty bytes as the signature.
     * @param hash Hash of the data to be marked as signed on the behalf of this BatchedWallet
     */
    function signMessage(bytes32 hash) external override onlyEntryPoint {
        signedMessages[hash] = true;
        emit BatchedWalletMessageSigned(hash);
    }

    /**
     * @notice Executes an operation received from the entry point.
     * @param dest The destination address for this execution
     * @param value The value (Ether) to be included with this execution
     * @param data The encoded call-data for this execution
     */
    function execute(address dest, uint256 value, bytes calldata data) external override onlyEntryPoint {
        _call(dest, value, data);
    }

    /**
     * @notice Executes a batch of operations (without ETH value) received from the entry point.
     * @param dest The array of destination addresses for each execution
     * @param data The array of encoded call-data bytes for each execution
     */
    function executeBatch(address[] calldata dest, bytes[] calldata data) external override onlyEntryPoint {
        _executeBatch(dest, new uint256[](0), data);
    }

    /**
     * @notice Executes a batch of operations (with ETH value) received from the entry point.
     * @param dest The array of destination addresses for each execution
     * @param value The array of value (ETH amounts) to be included with each execution
     * @param data The array of encoded call-data bytes for each execution
     */
    function executeBatch(address[] calldata dest, uint256[] calldata value, bytes[] calldata data)
        external
        override
        onlyEntryPoint
    {
        _executeBatch(dest, value, data);
    }

    /**
     * @notice Private function to execute a batch of arbitrary function calls on this contract.
     * @param dest The array of destination addresses for each execution
     * @param value The array of value (ETH amounts) to be included with each execution
     * @param data The array of encoded call-data bytes for each execution
     */
    function _executeBatch(address[] calldata dest, uint256[] memory value, bytes[] calldata data) private {
        if (dest.length != data.length || (value.length != 0 && value.length != data.length)) {
            revert Errors.BATCH_EXECUTE_ARRAY_LENGTH_INVALID();
        }
        uint256 i = 0;
        if (value.length == 0) {
            for (; i < dest.length;) {
                _call(dest[i], 0, data[i]);
                unchecked { // Since this will never overflow, we can optimise gas
                    i++;
                }
            }
        } else {
            for (; i < dest.length;) {
                _call(dest[i], value[i], data[i]);
                unchecked { // Since this will never overflow, we can optimise gas
                    i++;
                }
            }
        }
    }

    /**
     * @notice Private function to execute arbitrary function calls on this contract.
     * @param dest The destination address for the execution
     * @param value The value (ETH amount) to be included with the execution
     * @param data The encoded call-data for the execution
     */
    function _call(address dest, uint256 value, bytes memory data) private {
        // solhint-disable-next-line no-inline-assembly
        assembly ("memory-safe") { // Gas savings by switching to assembly
            let result := call(gas(), dest, value, add(data, 0x20), mload(data), 0, 0)
            if iszero(result) {
                let ptr := mload(0x40)
                returndatacopy(ptr, 0, returndatasize())
                revert(ptr, returndatasize())
            }
        }
    }

    /**
     * @notice Entry point getter function.
     * @return _entryPoint The IEntryPoint representing the entry point associaated with this BatchedWallet contract
     */
    function entryPoint() public view override returns (IEntryPoint _entryPoint) {
        _entryPoint = ENTRY_POINT;
    }

    /**
     * @notice Internal function that verifies if a UserOperation has been legitimately signed
     * @dev This function is called by the (EIP-4337 compliant) validateUserOp() function
     * located in the (parent) BaseAccount contract.
     * @param userOp The UserOperation struct to be validated
     * @param userOpHash The hash of the UserOperation to be validated
     * @return validationData An integer with a value of 0 for valid signatures and 1 for signature
     * failure (returned via the SIG_VALIDATION_FAILED constant defined in the BaseAccount contract),
     * see the BaseAccount documentation for additional details
     */
    function _validateSignature(UserOperation calldata userOp, bytes32 userOpHash)
        internal
        override
        virtual
        returns (uint256 validationData)
    {
        try this.checkSignature(
            userOpHash,
            userOp
        ){
            return 0;
        } catch {
            return SIG_VALIDATION_FAILED;
        }
    }

    /**
     * @notice Verifies if a signature is legitimate
     * @dev This function is required to make BatchedWallet compliant with EIP-1271.
     * @param hash The hash of the UserOpeation data (used to validate the signature)
     * @param signature The signature resulting from signing the hash (to be validated), it can
     * be a packed ECDSA signature or a contract signature (EIP-1271) (in this case the hash is approved
     * and the signature should be empty)
     * @return magicValue A bytes4 value of EIP1271_SELECTOR for valid signatures and EIP1271_INVALID_ID for invalid
     * signatures (these constants are defined above and are in compliance with the EIP-1271 spec),
     * see the EIP-1271 spec for more details: https://eips.ethereum.org/EIPS/eip-1271
     */
    function isValidSignature(bytes32 hash, bytes calldata signature)
        external
        view
        override
        returns (bytes4 magicValue)
    {
        if (signature.length == 0) {
            if(signedMessages[hash.toEthSignedMessageHash()]) {
                return EIP1271_SELECTOR;
            }
        } else {
            try this.checkSignature(
                hash,
                signature
            ){
                return EIP1271_SELECTOR;
            // solhint-disable-next-line no-empty-blocks
            } catch {}
        }
        return EIP1271_INVALID_ID;
    }

    /**
     * @notice Verifies if the provided signature is valid for the provided data hash
     * @dev This function reverts when the check fails, and it is external to enable the option
     * of calling it (from other functions in this contract) using a try-catch block. It's
     * externality is not required by any inherited interfaces or other contracts (however there
     * is no danger if it is called from an external contract).
     * @param hash The hash of the UserOpeation data (used to validate the signature)
     * @param signature The signature resulting from signing the hash (to be validated), it must
     * be a packed ECDSA signature
     */
    function checkSignature(bytes32 hash, bytes memory signature) external view {
        if (signature.length < 65) {
            revert Errors.SIGNATURE_LENGTH_LESS_THAN_65();
        }

        address currentOwner = hash.toEthSignedMessageHash().recover(signature);
        if (currentOwner != owner()) {
            revert Errors.SIGNATURE_NOT_SIGNED_BY_CONTRACT_OWNER();
        }
    }

    /**
     * @notice Verifies if the provided UserOperation is legitimately signed based on the provided hash
     * @dev This function reverts when the check fails, and it is external to enable the option
     * of calling it (from other functions in this contract) using a try-catch block. It's
     * externality is not required by any inherited interfaces or other contracts (however there
     * is no danger if it is called from an external contract).
     * @param hash The hash of the UserOpeation data (used to validate the signature)
     * @param userOp The UserOperation struct to be validated, in the case that it is a contract
     * signature (EIP-1271) then the signature field should be empty (and the hash approved)
     */
    function checkSignature(bytes32 hash, UserOperation calldata userOp) external view {
        bytes memory signature = userOp.signature;
        if (signature.length == 0) {
            // Contract signature (EIP-1271)
            if (getUserOpHash(userOp) != hash.toEthSignedMessageHash()) {
                revert Errors.HASH_FOR_SIGNATURE_INVALID();
            }
            if (IERC1271(owner()).isValidSignature(hash, signature) != EIP1271_SELECTOR) {
                revert Errors.EIP1271_VALIDATION_CALL_FAILED();
            }
        } else {
            // Packed ECDSA signature 
            this.checkSignature(hash, signature);
        }
    }

    /**
     * @notice Private helper to get the hash of a UserOperation
     * @param userOp The UserOperation struct to generate the hash from (the signature field is ignored)
     * @return hash The resulting bytes32 hash of the combined UserOperation fields
     */
    function getUserOpHash(UserOperation memory userOp) private view returns (bytes32 hash) {
        hash = ENTRY_POINT.getUserOpHash(userOp).toEthSignedMessageHash();
    }

    /**
     * @notice Verifies if msg.sender is authorized to upgrade this contract
     * @dev See the UUPSUpgradeable contract for more details on this.
     */
    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address) internal view override onlyOwner {}
}
