// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {IEntryPoint} from "@account-abstraction/interfaces/IEntryPoint.sol";
import {IAccount} from "@account-abstraction/interfaces/IAccount.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/interfaces/IERC721Receiver.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/interfaces/IERC1155Receiver.sol";
import {IERC1822Proxiable} from "@openzeppelin/contracts/interfaces/draft-IERC1822.sol";
import {IERC1271} from "@openzeppelin/contracts/interfaces/IERC1271.sol";

/**
 * @title IBatchedWallet
 * @dev Inherits functionality from IAccount, IERC721Receiver, IERC1155Receiver, IERC1822Proxiable and IERC1271
 */
interface IBatchedWallet is
    IAccount,
    IERC721Receiver,
    IERC1155Receiver,
    IERC1822Proxiable,
    IERC1271
{
    /**
     * @dev Emitted when the BatchedWallet is initialized
     */
    event BatchedWalletInitialized(IEntryPoint indexed entryPoint, address owners);

    /**
     * @dev Emitted when wallet signs a message
     */
    event BatchedWalletMessageSigned(bytes32 hash);

    /**
     * @notice Marks a message (`hash`) as signed.
     * @dev Verification via the EIP-1271 validation method is possible by passing the pre-image of the
     * message hash and empty bytes as the signature.
     * @param hash Hash of the data to be marked as signed on the behalf of this BatchedWallet
     */
    function signMessage(bytes32 hash) external;

    /**
     * @notice Executes an operation received from the entry point.
     * @param dest The destination address for this execution
     * @param value The value (Ether) to be included with this execution
     * @param data The encoded call-data for this execution
     */
    function execute(address dest, uint256 value, bytes calldata data) external;

    /**
     * @notice Executes a batch of operations (without ETH value) received from the entry point.
     * @param dest The array of destination addresses for each execution
     * @param data The array of encoded call-data bytes for each execution
     */
    function executeBatch(address[] calldata dest, bytes[] calldata data) external;

    /**
     * @notice Executes a batch of operations (with ETH value) received from the entry point.
     * @param dest The array of destination addresses for each execution
     * @param value The array of value (ETH amounts) to be included with each execution
     * @param data The array of encoded call-data bytes for each execution
     */
    function executeBatch(address[] calldata dest, uint256[] calldata value, bytes[] calldata data) external;
}
