#!/usr/bin/env python3

import os
import sys
import subprocess
import pathlib
import toml
from dotenv import load_dotenv, find_dotenv

load_dotenv(find_dotenv())

ALCHEMY_KEY = os.getenv('ALCHEMY_KEY')
PK = os.getenv('PK')
NETWORK = sys.argv[1] if len(sys.argv) > 1 else "mainnet"
rpc_url = f"https://eth-{NETWORK}.alchemyapi.io/v2/{ALCHEMY_KEY}"
config = toml.load("foundry.toml")

ETHERSCAN_KEY = os.getenv('ETHERSCAN_API_KEY')
CHAIN_IDS = {
    'mainnet': 1,
    'ropsten': 3,
    'rinkeby': 4,
    'goerli': 5
}

network = sys.argv[1] if len(sys.argv) > 1 else "mainnet"
receiptTokenAddr = sys.argv[2]
chain_id = CHAIN_IDS[network]

def parseAddress(str):
    for substr in str.split():
        if substr.startswith("0x"):
            return substr

def parseDeployedAddress(output):
    for line in output.split("\n"):
        if line.startswith("Deployed to:"):
            return parseAddress(line)

# Parses a compiler version from output of `~/.svm/{solc}/solc-{solc} --version`
# ex: `Version: 0.8.13+commit.abaa5c0e.Darwin.appleclang`
#     => 0.8.13+commit.abaa5c0e
def parseCompilerVersion(output):
    output = output.split()[-1]
    beginningOfCommitSha = output.find('commit') + len('commit') + 1
    endOfCommitSha = output.find('.', beginningOfCommitSha)
    return 'v' + output[:endOfCommitSha]

def deploy_contract(contract, *constructor_args):
    address = ""
    args = [
        "forge", "create", "--rpc-url", rpc_url, "--private-key", PK, contract
    ]
    if len(constructor_args) > 0:
        args += ["--constructor-args", *constructor_args]

    contract_name = contract.split(":")[-1]
    print(f"Deploying {contract_name}...")
    with subprocess.Popen(args, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, universal_newlines=True) as process:
        print("Running {}...".format(process.args))
        for line in process.stdout:
            print(line)
            if line.startswith("Deployed to:"):
                address = parseAddress(line)
    
    return address

def deploy_contracts():
    print(ALCHEMY_KEY, PK, NETWORK, receiptTokenAddr)

    policy = deploy_contract("src/WalletPolicy.sol:WalletPolicy")
    singleton = deploy_contract("src/NFTNFTWallet.sol:NFTNFTWallet")
    factory = deploy_contract(
        "src/proxies/NFTNFTWalletProxyFactory.sol:NFTNFTWalletProxyFactory", singleton, policy, receiptTokenAddr)

    return {
        'policy': policy,
        'singleton': singleton,
        'factory': factory
    }

def verify_contract(optimizer_runs, compiler_version, address, contract, encoded_constructor_args=None):
    contract_name = contract.split(":")[-1]
    print(f"Verifying {contract_name}...")
    args = [
        "forge", "verify-contract", "--chain-id", str(chain_id),
        "--num-of-optimizations", str(optimizer_runs),
        "--compiler-version", compiler_version, address, contract
    ]

    if encoded_constructor_args:
        args += ["--constructor-args", encoded_constructor_args]

    guid = ""
    with subprocess.Popen(args, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, universal_newlines=True) as process:
        for line in process.stdout:
            print(line)
            if line.strip().startswith('GUID:'):
                guid = line.split()[-1][1:-1]
    
    return guid

def verify_contracts(addresses):
    solc = config['default']['solc']
    compiler_version = ""
    with subprocess.Popen([f"./.svm/{solc}/solc-{solc}", "--version"],
                        cwd=pathlib.Path.home(), stdout=subprocess.PIPE, stderr=subprocess.STDOUT, universal_newlines=True) as process:
        for line in process.stdout:
            print(line)
            if line.startswith("Version:"):
                compiler_version = parseCompilerVersion(line)

    # optimizer = config['default']['optimizer']
    optimizer_runs = config['default']['optimizer_runs']

    print(f"chain id: {chain_id}, optimizer_runs: {optimizer_runs}, compiler_version: {compiler_version}")
    guids = {}
    guid = verify_contract(optimizer_runs, compiler_version,
                    addresses['policy'], "src/WalletPolicy.sol:WalletPolicy")
    guids['policy'] = guid
    
    guid = verify_contract(optimizer_runs, compiler_version,
                    addresses['singleton'], "src/NFTNFTWallet.sol:NFTNFTWallet")
    guids['singleton'] = guid

    encoded_constructor_args = subprocess.check_output(
        ["cast", "abi-encode", "constructor(address,address,address)", addresses['singleton'], addresses['policy'], receiptTokenAddr])
    guid = verify_contract(optimizer_runs, compiler_version,
                    addresses['factory'], "src/proxies/NFTNFTWalletProxyFactory.sol:NFTNFTWalletProxyFactory", encoded_constructor_args)
    guids['factory'] = guid
    return guids

def check_verfication_status(guids):
    for k, v in guids.items():
        print(f"Verification status for {k}...")
        args = [
            "forge", "verify-check", "--chain-id", str(chain_id), v, ETHERSCAN_KEY
        ]

        with subprocess.Popen(args, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, universal_newlines=True) as process:
            for line in process.stdout:
                print(line)


# addresses = deploy_contracts()
# print("Done")
# print(addresses)
addresses = {'policy': '0x852eee31c2474ca08497b882a53c1317af2944d9',
             'singleton': '0xe59e8a3050a744538bd0e7bd99c51366a3f1d534', 'factory': '0xf3b203294ee4eeb6eea4059de61e1c9206d4d3b9'}
guids = verify_contracts(addresses)
print(guids)
check_verfication_status(guids)

'''
 forge verify-check --chain-id 5 ageh4lqem6xtugdvaj4kniqxxdyynej2xihxmqtbgbsknjwgml U3R9QJTIJ3WZPTYBQY64YPEZDGM532G2RX
 {
    'policy': '0xf07e912af8bf3cbc5c2f5dcf43d50f14cffbdd93',
    'singleton': '0x6402b40afd476df0a94d4514a1b2479087e8b18b',
    'factory': '0x18bef085f6dd4bf6c23af90465c91cf68d5b74cb'
}
'''