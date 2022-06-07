// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./interfaces/IWalletPolicy.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// TODO: needs to add a check for parameters to the call
//       if the parameters don't match with the signature
//       it may trigger the fallback function even if there's
//       a matching function selector
contract WalletPolicy is Ownable, IWalletPolicy {
    // bytes4(keccak256("isMethodAllowed(address,bytes)")
    bytes4 constant internal POLICY_MAGIC_VALUE = 0xba6d2984;

    event SetScope(address target, bool allowed, bool scoped);
    event SetAllowedMethods(address indexed target, bytes4 method, bool allowed);

    struct Scope {
        bool allowed;
        bool scoped;
        mapping(bytes4 => bool) allowedMethods;
    }
    
    mapping(address => Scope) public allowedContracts;

    constructor() {}

    function isMethodAllowed(
        address target,
        bytes calldata data
    ) external view override returns (bytes4) {
        Scope storage scope = allowedContracts[target];
        if (!scope.allowed) {
            return 0;
        }

        if (!scope.scoped) {
            return POLICY_MAGIC_VALUE;
        }

        if (data.length >= 4) {
           if (scope.allowedMethods[bytes4(data)] == true) {
               return POLICY_MAGIC_VALUE;
           }
        } else {
          // Don't allow fallback methods
          // return data.length == 0; // fallback method
        }

        return 0;
    }

    function setScope(
        address target,
        bool allowed,
        bool scoped
    ) external onlyOwner {
        Scope storage scope = allowedContracts[target];
        require(scope.allowed != allowed || scope.scoped != scoped, "Nothing to update");
        if (scoped) {
            require(allowed, "Can't be scoped without being allowed");
        }
        allowedContracts[target].allowed = allowed;
        allowedContracts[target].scoped = scoped;
        emit SetScope(target, allowed, scoped);
    }

    function setAllowedMethod(
        address target,
        bytes4 method,
        bool allowed
    ) external onlyOwner {
        Scope storage scope = allowedContracts[target];
        require(scope.allowed && scope.scoped, "The contract needs to be allowed and scoped");
        require(scope.allowedMethods[method] != allowed, "Nothing to update");
        scope.allowedMethods[method] = allowed;
        emit SetAllowedMethods(target, method, allowed);
    }
}