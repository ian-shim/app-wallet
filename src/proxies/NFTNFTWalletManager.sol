// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract NFTNFTWalletManager {
    using EnumerableSet for EnumerableSet.AddressSet;

    // bytes4(keccak256("isWalletApproved(address)")
    bytes4 public constant APPROVED_WALLET_MAGIC_VALUE = 0x3657e851;

    EnumerableSet.AddressSet private _approvedWallets;

    function addWallet(address proxy) internal {
        require(proxy != address(0), "Invalid wallet address");
        _approvedWallets.add(proxy);
    }

    function removeWallet(address proxy) internal {
        require(proxy != address(0), "Invalid wallet address");
        _approvedWallets.remove(proxy);
    }

    function isWalletApproved(address proxy) public view returns (bytes4) {
        require(proxy != address(0), "Invalid wallet address");

        if (_approvedWallets.contains(proxy)) {
            return APPROVED_WALLET_MAGIC_VALUE;
        }

        return 0x0;
    }
}