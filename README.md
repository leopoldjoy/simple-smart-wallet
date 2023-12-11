# BatchedWallet: A Simple ERC-4337-Compliant Smart Wallet Implementation

BatchedWallet is a simple implementation of an ERC-4337-compliant smart wallet, additionally it complies with the [ERC-1271](https://eips.ethereum.org/EIPS/eip-1271) (contract signing) and is also upgradable. For a complete outline of the ERC-4337 spec please read the [EIP here](https://eips.ethereum.org/EIPS/eip-4337).

- [Design Decisions](#design-decisions)
- [Improvements](#improvements)
- [Getting Started](#getting-started)
  - [Requirements](#requirements)
  - [Quickstart](#quickstart)
  - [Testing](#testing)
- [Deploying to an EVM Testnet](#deploying-to-an-evm-testnet)
  - [Setup](#setup)
  - [Deploying](#deploying)
- [Sepolia Deployment Addresses](#sepolia-deployment-addresses)
- [Interacting with the Testnet Deployment](#interacting-with-the-testnet-deployment)
  - [1. Fund the Paymaster's Deposit](#1-Fund-the-Paymasters-Deposit)
  - [2. Mint ERC20Mock Tokens](#2-Mint-ERC20Mock-Tokens)
  - [3. Make a Feeless Transfer of the ERC20 Token Out of the BatchedWallet](#3-Make-a-Feeless-Transfer-of-the-ERC20-Token-Out-of-the-BatchedWallet)
- [Security](#security)
- [Contributing](#contributing)
- [Thank You!](#thank-you)
  - [Resources](#resources)

# Design Decisions

The BatchedWallet design is focused on simplicity while still including the most essential features for an ERC-4337-compliant smart wallet. Here are some of the considerations that were made:

 - The wallet supports both EOA (ECDSA signatures) and smart contract signing (ERC-1271 compliant).
 - For simplicity the wallet currently only supports one owner address (this obviously limits the potential use-cases markedly).
 - The wallet is upgradable, as [recommended by the EIP-4337 spec](https://eips.ethereum.org/EIPS/eip-4337#entry-point-upgrading).
 - The EntryPoint address is hard-coded into the BatchedWallet for gas efficiency, thus for EntryPoint upgrades (if the EntryPoint address changes) redeployment would be required.

# Improvements

There are many areas where the BatchedWallet contracts can be improved. The list below touches on some of these areas:

 - Expand the ownership options to include multiple owner and/or tiers of ownership (a privileges system).
 - Implement a testing setup that uses an alternative mempool (to more closely replicate a production environment).
 - Improve the signature encoding scheme to include additional details such as `chainId` as well as a `sigType` as a part of the encoding.
 - Expand testing of the signature verification scheme.
 - Add checks in the existing testing for event emissions using the Foundry cheatcodes.
 - Add testing related to ERC-1155 and ERC-721 tokens.
 - Further gas optimisation of wallet functions.
 - Abstract out authorization functionalities from the BatchedWallet contract into a seperate Auth-specific contract.
 - Make the scripts adaptable for EVM-based chains other than the Sepolia testnet.
 - Add the option to have custom "validators" for validating different types of operations on the wallet.
 - Enable customization of default fallback functionality by allowing `STATICCALL`s to a custom contract (without allowing state modifications).

# Getting Started

## Requirements

Please install the following:

-   [Make](https://askubuntu.com/questions/161104/how-do-i-install-make)  
-   [Foundry / Foundryup](https://github.com/gakonst/foundry)
-   [Solhint](https://github.com/protofire/solhint) (ensure that you have it installed globally)
-   [Python](https://www.python.org/downloads/) (if you want to use Slither)
-   [Slither](https://github.com/crytic/slither#how-to-install) (optional)

## Quickstart

```sh
git clone https://github.com/leopoldjoy/simple-smart-wallet
cd simple-smart-wallet
make # This installs the project's dependencies.
make test
```

## Testing

```
make test
```

or

```
forge test
```

# Deploying to an EVM Testnet

The repo is currently setup to deploy to the Sepolia Ethereum testnet, we will walk through the setup process below.

## Setup

You'll need to add the following variables to a `.env` file in the root of the repo:
-   `PRIVATE_KEY`: A private key from your wallet. (If you don't have one you can get a private key from a new [Metamask](https://metamask.io/) account.)
-   `SEPOLIA_RPC_URL`: A URL to connect to the blockchain. You can get one for free from [Infura](https://www.infura.io/) account
-   `SEPOLIA_VERIFIER_URL`: The URL of the Etherescan Sepolia endpoint, currently this should be: `https://api-sepolia.etherscan.io/api`
-   `ETHERSCAN_API_KEY`: Your Etherscan API key, you can sign up for a free [account here](https://etherscan.io/apis).

If you prefer, you can also run the following command from the project root to create the `.env` file and then input your values manually:

```
cp .env.example .env
```
Please note that there is an existing default private key included in the `.env.example` file. This key was used to deploy the [Sepolia Deployment Addresses](sepolia-deployment-addresses) in order to streamline testing if you prefer not to run your own deployment (this address is the owner of the deployed Sepolia contracts).

Since we're using the Sepolia testnet, go get some [testnet sepolia ETH](https://sepoliafaucet.com/) if you don't have any already.

## Deploying

We will walk through deploying all of the contracts now, including the mock contracts (for testing purposes). **Please do note however that in a real use-case (e.g. in production) the bundler would gather UserOperations from an alternative mempool**, however for our testing purposes we will be relaying our UserOperations to our mock bundler in the same general mempool of the testnet.

First run the following in order to use the environment variables we set:
```
source .env
```

Deploy the ERC20Mock contract (so we can use it to test ERC-20 transfers):
```
make deploy-sepolia contract=ERC20Mock
```

Deploy the [BundlerMock](./contracts/mock/BundlerMock.sol) contract (which will function as our ERC-4337 bundler for testing purposes):
```
make deploy-sepolia contract=BundlerMock
```

Deploy the [BatchedWalletFactory](./contracts/BatchedWalletFactory.sol) contract:
```
make deploy-sepolia contract=BatchedWalletFactory
```

Now we create a [BatchedWallet](./contracts/BatchedWallet.sol) contract:
```
OWNER_ADDRESS=<your-wallet-address> \
FACTORY_ADDRESS=<the-address-printed-from-the-BatchedWalletFactory-deployment-above> \
SALT=<a-bytes32-message-totaling-66-characters> \
make deploy-sepolia contract=BatchedWallet
```
Please replace the poritions above surrounded by arrows with the relevent values. (Note that these environment variables may also be set via the `.env` file if you prefer, however this is not recommended since modifications would need to be made before each deployment command.) For the `SALT` value, please ensure that is has the correct amount of trailing zeros, totaling 66 characters (for example: `0x7465737400000000000000000000000000000000000000000000000000000000`).

Now we create a [SponsorshipPaymaster](./contracts/SponsorshipPaymaster.sol) contract (which will function for testing out paymaster sponsorship functionality):
```
OWNER_ADDRESS=<your-wallet-address> \
FACTORY_ADDRESS=<the-address-printed-from-the-BatchedWalletFactory-deployment-above> \
make deploy-sepolia contract=SponsorshipPaymaster
```

If you visit the deployment addresses on [Sepolia's Etherscan](https://sepolia.etherscan.io/) you may notice that they are also verified. However if any don't verifiy automatically for any reason, simply run the `forge verify-contract` command (see the [documentation here](https://book.getfoundry.sh/forge/deploying#verifying-a-pre-existing-contract)). Also please note that to verify the BatchedWallet contract in particular, since it's deployed via a proxy, you must click the "Is this a proxy?" button in Etherscan and follow the instructions.

Congratulations! We now have all of the contracts deployed that we need to start testing everything out on the testnet!

# Sepolia Deployment Addresses

An existing deployment of the contracts (11/12/23) has been made at the following addresses:
 - **ERC20Mock**: [0xFbFe85108EdE87fdF9933B619311eeac313E31a3](https://sepolia.etherscan.io/address/0xfbfe85108ede87fdf9933b619311eeac313e31a3)
 - **BundlerMock**: [0x7192ff565893d812b0d76de7101eae6fd12e587a](https://sepolia.etherscan.io/address/0x7192ff565893d812b0d76de7101eae6fd12e587a)
 - **BatchedWalletFactory**: [0xdd4195dae1326a2391714b7fdb67f6d592c21ad6](https://sepolia.etherscan.io/address/0xdd4195dae1326a2391714b7fdb67f6d592c21ad6)
 - **BatchedWallet**: [0x4788037629494dd2ebb0b665e2027091f1109d56](https://sepolia.etherscan.io/address/0x4788037629494dd2ebb0b665e2027091f1109d56)
 - **SponsorshipPaymaster**: [0xc87ebf920b44c8ebf69260b54f2accbe75a9ea81](https://sepolia.etherscan.io/address/0xc87ebf920b44c8ebf69260b54f2accbe75a9ea81)

Also, please note that this is the address of the current EntryPoint deployment on Sepolia: [0x0576a174D229E3cFA37253523E645A78A0C91B57](https://sepolia.etherscan.io/address/0x0576a174D229E3cFA37253523E645A78A0C91B57)

# Interacting with the Testnet Deployment

For the purpose of this walkthrough of the available functionality, we will use the [deployment addresses](#sepolia-deployment-addresses) listed in the section above, however feel free to subsitute the contract addresses with your own (if you've completed the deployment steps listed earlier).

Also, if you are using the [addresses listed above](#sepolia-deployment-addresses), please ensure that you also ran `cp .env.example .env` earlier in the [Setup](#setup) section, since the existing default private key in the `.env.example` file is the owner of the Sepolia contracts above in order to streamline testing (if you prefer not to run your own deployment). Also, in this case please additionally import this private key into your MetaMask wallet (so we can test with it in the following steps).

## 1. Fund the Paymaster's Deposit

In order for our SponsorshipPaymaster contract to cover the cost of UserOperations, we must make a deposit into the EntryPoint on behalf of the paymaster contract's address. Go to the [EntryPoint address](https://sepolia.etherscan.io/address/0x0576a174D229E3cFA37253523E645A78A0C91B57#writeContract), connect your Web3 wallet, and then click the `depositTo()` function. Enter the following values:
 - `payableAmount (ether)`: `0.2` (or whatever amount you want to deposit on behalf of the paymaster)
 - `account: 0xc87ebf920b44c8ebf69260b54f2accbe75a9ea81` (the SponsorshipPaymaster address [from the deployment](#sepolia-deployment-addresses))

Submit the transaction and wait for it to confirm. You can also switch to the read-tab of the contract and call the `deposits()` function with the paymaster's address to confirm the new size of the paymaster's deposit on the EntryPoint.

## 2. Mint ERC20Mock Tokens

Go to the [ERC20Mock contract](https://sepolia.etherscan.io/address/0xfbfe85108ede87fdf9933b619311eeac313e31a3#writeContract) and run the `mint()` function with the following values:
 - `account`: `0x4788037629494dd2ebB0b665E2027091F1109d56` ([the deployed BatchedWallet's address](#sepolia-deployment-addresses))
 - `amount`: `1000000000000000000` (1 token)

Submit and wait for confirmation. The BatchedWallet now has 1 token worth of the ERC20Mock token.

## 3. Make a Feeless Transfer of ERC20 Token Out of the BatchedWallet

First we need to sign the UserOperation that we want to submit to the Bundler. To do this we must run the following script:
```
USEROP_SENDER=0x4788037629494dd2ebB0b665E2027091F1109d56 \
USEROP_NONCE=2 \
USEROP_CALL_DATA_ADDRESS=0xFbFe85108EdE87fdF9933B619311eeac313E31a3 \
USEROP_CALL_DATA_ERC20_TO_ADDRESS=0x227C8be27B6699747b5a33F623E65eA072a6153A \
USEROP_CALL_DATA_ERC20_AMOUNT=1000000000000000000 \
USEROP_PAYMASTER_ADDRESS=0xC87eBf920b44C8eBf69260b54F2AccBE75a9EA81 \
make sign-user-op
```
Note that you will need to replace the nonce (and possibly the other values depending on if you deployed yourself), you can find the full documentation for these environment variables [here](/script/SignUserOpUtil.s.sol). When the command finishes, take note of the resulting signature and all of the returned values. Then [go to the bundler](https://sepolia.etherscan.io/address/0x7192ff565893d812b0d76de7101eae6fd12e587a#writeContract), and run the `post()` function with the following values:
 - `entryPoint`: `0x0576a174D229E3cFA37253523E645A78A0C91B57`
 - `sender`: `0x4788037629494dd2ebB0b665E2027091F1109d56` (the BatchedWallet address)
 - `nonce`: `2` (be sure that this matches the correct value and the same value you used to create the signature above)
 - `initCode`: `0x`
 - `callData`: `<insert-from-the-result-above>`
 - `callGasLimit`: `100000`
 - `verificationGasLimit`: `100000`
 - `preVerificationGas`: `10000`
 - `maxFeePerGas`: `2000000000`
 - `maxPriorityFeePerGas`: `2000000000`
 - `paymasterAndData`: `0xc87ebf920b44c8ebf69260b54f2accbe75a9ea81`
 - `signature`: `<insert-from-the-result-above>`

Please note that it's essential that the values that you used to generate the signature are the same as the values passed above, otherwise the transaction will fail.

Submit the transaction and await confirmation. Once confirmed, you can view the state changes in Etherscan and confirm that everything happened correctly (e.g. the paymaster covered the UserOperation cost and the tokens were transferred). You can see an example of the state changes of [a confirmed transaction here](https://sepolia.etherscan.io/tx/0xb68cac186154b98ba4d2710046f075e3b8572e21c36abf5fef526f526894aedf#statechange).

# Security

To run slither, use:

```
make slither
```

And get your slither output. 

# Contributing

Please be sure to run the linter before pushing:

```
make lint
```

# Thank You!

## Resources

-   [EIP-4337](https://eips.ethereum.org/EIPS/eip-4337)
-   [EIP-1271](https://eips.ethereum.org/EIPS/eip-1271)
