// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IWalletPolicy {
    function isMethodAllowed(address target, bytes calldata data) external view returns (bytes4);
}
