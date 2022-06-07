// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/proxies/NFTNFTWalletProxy.sol";
import "../src/proxies/NFTNFTWalletProxyFactory.sol";
import "../src/WalletPolicy.sol";
import "../src/NFTNFTWallet.sol";

contract IncrementContract {
    uint256 public i;
    function increment() external {
        i++;
    }
}

contract NFTNFTWalletProxyFactoryTest is Test {
    NFTNFTWallet singleton;
    NFTNFTWalletProxyFactory factory;
    WalletPolicy policy = new WalletPolicy();
    address approvedOperator = 0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC;

    event ProxyCreation(address owner, NFTNFTWalletProxy proxy);

    function setUp() public {
        singleton = new NFTNFTWallet();
        factory = new NFTNFTWalletProxyFactory(address(singleton), address(policy), approvedOperator);
    }

    function testInvalidAddressApproved() public {
        vm.expectRevert("Invalid wallet address");
        factory.isWalletApproved(address(0));
    }

    function testCreateProxyWithNonceEmitsEvent(address owner) public {
        vm.prank(owner);
        vm.expectEmit(false, false, false, true);
        NFTNFTWalletProxy proxy = factory.createProxyWithNonce(block.timestamp);
        emit ProxyCreation(owner, proxy);
    }

    function testCreateProxyWithNonceApprovesWallet() public {
        NFTNFTWalletProxy proxy = factory.createProxyWithNonce(block.timestamp);
        assertTrue(factory.isWalletApproved(address(proxy)) == factory.isWalletApproved.selector);
    }

    function testCreateProxyWithNonceSetsOwner(address owner) public {
        vm.prank(owner);
        NFTNFTWalletProxy proxy = factory.createProxyWithNonce(block.timestamp);
        assertTrue(NFTNFTWallet(payable(address(proxy))).owner() == owner);
        // assertTrue(keccak256(returnData) == keccak256(abi.encode(owner)));
    }

    function testCreateProxyWithNonceSetsPolicy() public {
        NFTNFTWalletProxy proxy = factory.createProxyWithNonce(block.timestamp);
        assertTrue(NFTNFTWallet(payable(address(proxy))).policy() == policy);
    }

    function testExecTransactionFromProxy() public {
        IncrementContract testContract = new IncrementContract();
        policy.setScope(address(testContract), true, false);
        assertTrue(policy.isMethodAllowed(address(testContract), abi.encodePacked(testContract.increment.selector)) == 0xba6d2984);
        emit log_bytes(abi.encode(policy.isMethodAllowed.selector));
        NFTNFTWalletProxy proxy = factory.createProxyWithNonce(block.timestamp);
        NFTNFTWallet(payable(address(proxy))).execTransaction(
            address(testContract),
            0,
            abi.encodePacked(testContract.increment.selector)
        );
    }
}
