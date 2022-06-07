// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract ISignatureValidatorConstants {
    // bytes4(keccak256("isValidSignature(bytes32,bytes)")
    bytes4 internal constant EIP1271_MAGIC_VALUE = 0x1626ba7e;
}

abstract contract ISignatureValidator is ISignatureValidatorConstants {
    function isValidSignature(bytes32 _data, bytes memory _signature) external view virtual returns (bytes4);
}
