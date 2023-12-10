// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "account-abstraction/core/BasePaymaster.sol";
import "account-abstraction/interfaces/UserOperation.sol";
import "account-abstraction/interfaces/IEntryPoint.sol";
import {Errors} from "./helper/Errors.sol";

/**
 * @title SponsorshipPaymaster
 * @notice A mock paymaster that simply freely covers the cost of all operations associated with BatchedWallets.
 * @dev Note that this paymaster only sponsors operations from BatchedWallets that were generated from the
 * BatchedWalletFactory address that is passed into the constructor. This contract inherits functionality from
 * BasePaymaster. This paymaster should NOT be used in production as it can be easily drained and abused.
 */
contract SponsorshipPaymaster is BasePaymaster {
    using UserOperationLib for UserOperation;

    // The cost of the postOp
    uint256 public constant COST_OF_POST = 40000;
    
    // This constant is used for the threshold check (of the maximum sponsorship amount) in the validation of
    // wallet construction operations. It prevents a malicious user from draining the paymaster's deposit in a
    // single user operation.
    uint256 public constant MAX_ALLOWED_SPONSOR_AMOUNT = 0.1 ether;

    address public immutable walletFactory;

    /**
     * @dev Emitted when the costs of a UserOperation has been sponsored
     */
    event UserOperationSponsored(address indexed user, uint256 actualGasCost);

    /**
     * @dev Constructs the SponsorshipPaymaster contract
     * @param entryPoint The address of the entryPoint to be associated with this paymaster
     * @param owner The owner of this SponsorshipPaymaster contract
     * @param walletFactoryAddr The address of the BatchedWalletFactory to be associated with this
     * paymaster. Note that ONLY BatchedWallets created via this factory will be able to be sponsored.
     */
    constructor(address entryPoint, address owner, address walletFactoryAddr) BasePaymaster(IEntryPoint(entryPoint), owner) {
        if (address(walletFactoryAddr) == address(0)) {
            revert Errors.PAYMASTER_ENTRY_POINT_ADDRESS_INVALID();
        }
        walletFactory = walletFactoryAddr;
    }

    /**
     * @notice Validates that a provided UserOperation is valid to have its fees sponsored by this paymaster
     * @dev Checks that the gas consumption requirements of the UserOperation are within a resonable range
     * (to help avoid this paymaster getting quickly drained).
     * @param userOp The UserOperation to be validated
     * @param maxCost The amount of prefunded ETH (in wei) required for the operation
     * @return context Bytes encoded address of the UserOperation sender
     * @return validationResult An integer representing the outcome of the validation (0 represents success)
     */
    function _validatePaymasterUserOp(UserOperation calldata userOp, bytes32, uint256 maxCost) internal view override returns (bytes memory context, uint256 validationResult) {
        // This checks ensures that enough gas has been provided for the postOp function call
        if (userOp.verificationGasLimit <= 30000) {
            revert Errors.PAYMASTER_GAS_TO_LOW_FOR_POSTOP();
        }

        // The length check below prevents the user from add excessive calldata, which could drain
        // the paymaster's entrypoint deposit
        if (userOp.paymasterAndData.length != 20) { // paymasterAndData: [paymaster]
            revert Errors.PAYMASTER_AND_DATA_LENGTH_INVALID();
        }

        if (userOp.initCode.length != 0) {
            // This check prevents a malicious user from draining the Paymaster's deposit in a single wallet
            // creation UserOperation. However, a user could still send many wallet creation UserOperations
            // to drain the Paymaster's deposit. This check simply adds overhead for the attacker.
            if (maxCost >= MAX_ALLOWED_SPONSOR_AMOUNT) {
                revert Errors.PAYMASTER_REQUIRED_PREFUND_TOO_LARGE();
            }
            if (address(bytes20(userOp.initCode)) != walletFactory) {
                revert Errors.PAYMASTER_UNKNOWN_WALLET_FACTORY();
            }
        }

        return (abi.encode(userOp.getSender()), 0);
    }

    /**
     * @notice Executes this paymaster's postOp operations
     * @dev Currently does nothing except emit an event, since no post-operation accounting state
     * changes are needed for the current mock use-case of the SponsorshipPaymaster contract.
     * @param mode An enum representing if the UserOperation succeeded, reverted, or postOp reverted
     * @param context Bytes encoded address of the UserOperation sender
     * @param actualGasCost The actual amount of gas used so far (prior to this postOp call)
     */
    function _postOp(PostOpMode mode, bytes calldata context, uint256 actualGasCost) internal override {
        if (mode == PostOpMode.postOpReverted) {
            return; // Do nothing in this case (do NOT revert the whole bundle and harm reputation)
        }
        (address sender) = abi.decode(context, (address));
        emit UserOperationSponsored(sender, actualGasCost);
    }
}
