# RentalExchange App Wallet

Smart contract wallet for borrowing NFTs on the NFT Rental Exchange. 

_WARNING: This code has not been comprehensively tested or audited. The author is not responsible for any loss of funds. Meanwhile, please open an issue or a PR if you find any bugs or vulnerabilities._

# Contracts

- `NFTNFTWallet.sol` \
Singleton contract that implements the actual wallet functionality. 
Users can call `execTransaction` method to send transactions, but these transactions will be checked against the  `WalletPolicy` and transactions prohibited by this policy will not be executed. 
- `NFTNFTWalletProxy.sol` \
Proxy contract that routes requests to `NFTNFTWallet` singleton. This contract represents the "App Wallet." A user is issued a  new instance of this contract and they interact with that instance.
- `NFTNFTWalletProxyFactory.sol` \
A factory for the proxy contract (app wallet). It creates and initializes new instances of the proxy contract. This contracts also keeps track of the issued proxies so that external contracts can check if a proxy is legitimately issued by this factory.
- `WalletPolicy.sol` \
A contract that keeps track of whitelisted contracts the app wallet can interact with. Two levels of gating happens in the configuration: `allowed` and `scoped`. If a target is not `allowed`, no transactions can be send to this target. If a target is `allowed` but not `scoped`, any transactions to this target can be sent. If a target is `allowed` and `scoped`, only whitelisted methods can be called. 
# Deployed Contract Addresses
## WalletPolicy
mainnet: \
goerli: [0x852eeE31C2474CA08497b882A53C1317Af2944D9](https://goerli.etherscan.io/address/0x852eee31c2474ca08497b882a53c1317af2944d9)

## NFTNFTWallet
mainnet: \
goerli: [0xE59e8a3050A744538bD0E7Bd99c51366a3F1d534](https://goerli.etherscan.io/address/0xe59e8a3050a744538bd0e7bd99c51366a3f1d534)

## NFTNFTWalletProxyFactory
mainnet: \
goerli: [0xf3B203294eE4EeB6eea4059dE61E1c9206D4d3B9](https://goerli.etherscan.io/address/0xf3b203294ee4eeb6eea4059de61e1c9206d4d3b9)

# Usage

## Install [Foundry](https://github.com/foundry-rs/foundry)
Download `foundryup`:
```
$ curl -L https://foundry.paradigm.xyz | bash
```
Then install Foundry:
```
$ foundryup
```

Clone the repo:
```
$ git clone https://github.com/ian-shim/app-wallet.git
```

## Running tests
Unit tests:
```
$ forge test [-vvvv]
```

Integration tests require forking mode: \
(_integration tests fork and use actual deployed contracts. Make sure the deployed addresses in the tests are correct_)
```
$ forge test --fork-url <NODE_URL> --chain-id <CHAIN_ID> --etherscan-api-key <ETHERSCAN_KEY>
```
