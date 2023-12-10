// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";
import {BatchedWallet} from "@source/BatchedWallet.sol";

/**
 * @title BatchedWalletFactory
 * @notice Manages the creation / deployment and address generation of BatchedWallet contracts
 * @dev Complies with the ERC-1967 standard for the proxy storage location
 */
contract BatchedWalletFactory{
    BatchedWallet public immutable bwImplementation;

    /**
     * @dev Constructs the BatchedWalletFactory contract
     * @param entryPoint The address of the entryPoint to be associated with this BatchedWalletFactory
     */
    constructor(address entryPoint) {
        bwImplementation = new BatchedWallet(entryPoint);
    }

    /**
     * @dev Emitted when a BatchedWallet is created
     */
    event BatchedWalletCreation(address indexed proxy);

    /**
     * @notice Creates a BatchedWallet and returns it
     * @dev The address is returned even if the wallet is deployed already, this is so that the entryPoint.getSenderAddress()
     * function would work even after the wallet has been created.
     * @param owner The address that should be the initial owner of the new BatchedWallet
     * @param salt A bytes32 salt hash used to generate the new (or existing) wallet address
     * @return bw The newly created BatchWallet (or the existing one if it already exists)
     */
    function createWallet(address owner, bytes32 salt) public returns (BatchedWallet bw) {
        address walletAddress = getAddress(owner, salt);
        if (walletAddress.code.length > 0) {
            return BatchedWallet(payable(walletAddress));
        }
        bw = BatchedWallet(payable(new ERC1967Proxy{salt: salt}(
            address(bwImplementation),
            abi.encodeCall(BatchedWallet.initialize, (owner))
        )));
        emit BatchedWalletCreation(address(bw));
    }

    /**
     * @notice Returns the address of a BatchedWallet (existing or future)
     * @dev The owner address and salt hash are used to compute the counterfactual (existing or future)
     *  address of a BatchedWallet contract, as it would be returned by the createWallet() function above.
     * @param owner The address that should be the initial owner of the new BatchedWallet
     * @param salt A bytes32 salt hash used to generate the new (or existing) wallet address
     * @return bw The address of the BatchWallet (regardless of whether it already exists)
     */
    function getAddress(address owner, bytes32 salt) public view returns (address bw) {
        bw = Create2.computeAddress(salt, keccak256(abi.encodePacked(
            type(ERC1967Proxy).creationCode,
            abi.encode(
                address(bwImplementation),
                abi.encodeCall(BatchedWallet.initialize, (owner))
            )
        )));
    }

}
