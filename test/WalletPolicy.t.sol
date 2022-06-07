// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/WalletPolicy.sol";

contract WalletPolicyTest is Test {
    WalletPolicy policy;
    
    event SetScope(address target, bool allowed, bool scoped);
    event SetAllowedMethods(address indexed target, bytes4 method, bool allowed);
    
    function setUp() public {
        policy = new WalletPolicy();
    }

    function testAllowTarget(address target) public {
        assertFalse(policy.isMethodAllowed(target, "") == policy.isMethodAllowed.selector);
        vm.expectEmit(false, false, false, true);
        emit SetScope(target, true, false);
        policy.setScope(target, true, false);
        assertTrue(policy.isMethodAllowed(target, "") == policy.isMethodAllowed.selector);
    }

    function testAllowTargetMethod(address target, bytes4 method, bytes4 wrongMethod) public {
        vm.assume(method != wrongMethod);
        bytes memory data = abi.encodePacked(method);
        assertFalse(policy.isMethodAllowed(target, data) == policy.isMethodAllowed.selector);
        vm.expectEmit(false, false, false, true);
        emit SetScope(target, true, true);
        policy.setScope(target, true, true);

        vm.expectEmit(true, false, false, true);
        emit SetAllowedMethods(target, method, true);
        policy.setAllowedMethod(target, method, true);
        assertTrue(policy.isMethodAllowed(target, data) == policy.isMethodAllowed.selector);
        bytes memory wrongData = abi.encodePacked(wrongMethod);
        assertFalse(policy.isMethodAllowed(target, wrongData) == policy.isMethodAllowed.selector);
    }

    function testCantAllowTargetMethodUnlessScoped(address target, bytes4 method) public {
        vm.expectRevert("The contract needs to be allowed and scoped");
        policy.setAllowedMethod(target, method, true);

        policy.setScope(target, true, false);
        vm.expectRevert("The contract needs to be allowed and scoped");
        policy.setAllowedMethod(target, method, true);

        policy.setScope(target, true, true);
        policy.setAllowedMethod(target, method, true);
    }

    function testCantScopeTargetUnlessAllowed(address target) public {
        vm.expectRevert("Can't be scoped without being allowed");
        policy.setScope(target, false, true);
    }

    function testNothingToUpdate(address target) public {
        vm.expectRevert("Nothing to update");
        policy.setScope(target, false, false);

        policy.setScope(target, true, false);
        vm.expectRevert("Nothing to update");
        policy.setScope(target, true, false);

        policy.setScope(target, true, true);
        vm.expectRevert("Nothing to update");
        policy.setScope(target, true, true);
    }

    function testNothingToUpdateScoped(address target, bytes4 method, bytes4 method2) public {
        vm.assume(method != method2);
        
        policy.setScope(target, true, true);
        policy.setAllowedMethod(target, method, true);

        vm.expectRevert("Nothing to update");
        policy.setAllowedMethod(target, method, true);

        policy.setAllowedMethod(target, method2, true);
    }
}