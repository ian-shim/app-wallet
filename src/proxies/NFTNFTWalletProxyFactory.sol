// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

// import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "./NFTNFTWalletProxy.sol";
import "../NFTNFTWallet.sol";
import "./NFTNFTWalletManager.sol";

/// @title Proxy Factory - Allows to create new proxy contact and execute a message call to the new proxy within one transaction.
contract NFTNFTWalletProxyFactory is NFTNFTWalletManager {
    // using EnumerableSet for EnumerableSet.AddressSet;

    event ProxyCreation(address owner, NFTNFTWalletProxy proxy);

    address public singleton;
    address public policy;
    address public approvedOperator;

    constructor(
        address _singleton,
        address _policy,
        address _approvedOperator
    ) {
        singleton = _singleton;
        policy = _policy;
        approvedOperator = _approvedOperator;
    }

    /// @dev Allows to retrieve the runtime code of a deployed Proxy. This can be used to check that the expected Proxy was deployed.
    function proxyRuntimeCode() public pure returns (bytes memory) {
        return type(NFTNFTWalletProxy).runtimeCode;
    }

    /// @dev Allows to retrieve the creation code used for the Proxy deployment. With this it is easily possible to calculate predicted address.
    function proxyCreationCode() public pure returns (bytes memory) {
        return type(NFTNFTWalletProxy).creationCode;
    }

    /// @dev Allows to create new proxy contact using CREATE2 but it doesn't run the initializer.
    ///      This method is only meant as an utility to be called from other methods
    /// @param saltNonce Nonce that will be used to generate the salt to calculate the address of the new proxy contract.
    function deployProxyWithNonce(
        uint256 saltNonce
    ) internal returns (NFTNFTWalletProxy proxy) {
        // If the initializer changes the proxy address should change too. Hashing the initializer data is cheaper than just concatinating it
        bytes32 salt = keccak256(abi.encodePacked(msg.sender, saltNonce));
        bytes memory deploymentData = abi.encodePacked(type(NFTNFTWalletProxy).creationCode, uint256(uint160(singleton)));
        // solhint-disable-next-line no-inline-assembly
        assembly {
            proxy := create2(0x0, add(0x20, deploymentData), mload(deploymentData), salt)
        }
        require(address(proxy) != address(0), "Create2 call failed");
        require(isWalletApproved(address(proxy)) == 0x0, "Same proxy already exists");
        addWallet(address(proxy));

        bytes memory initializer = abi.encodeWithSelector(NFTNFTWallet.initialize.selector, msg.sender, policy, approvedOperator);
        assembly {
            if eq(call(gas(), proxy, 0, add(initializer, 0x20), mload(initializer), 0, 0), 0) {
                revert(0, 0)
            }
        }
    }

    /// @dev Allows to create new proxy contact and execute a message call to the new proxy within one transaction.
    /// @param saltNonce Nonce that will be used to generate the salt to calculate the address of the new proxy contract.
    function createProxyWithNonce(
        uint256 saltNonce
    ) public returns (NFTNFTWalletProxy proxy) {
        proxy = deployProxyWithNonce(saltNonce);
        
        emit ProxyCreation(msg.sender, proxy);
    }
}
