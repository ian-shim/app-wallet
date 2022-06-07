// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/WalletPolicy.sol";
import "../src/NFTNFTWallet.sol";
import "./MockNFT.sol";

contract TestContract {
    function pass() public pure returns (bool) {
        return true;
    }
    
    function fail() public pure {
        require(false, "always revert");
    }
}

contract SmartWallet is ISignatureValidator {
    mapping(bytes32 => bool) signedHashes;

    function sign(bytes32 data) external returns (bytes memory) {
        signedHashes[data] = true;
        return abi.encodePacked(data, address(this));
    }

    function isValidSignature(bytes32 data, bytes calldata) external override view returns (bytes4) {
        return signedHashes[data] ? EIP1271_MAGIC_VALUE : bytes4(0);
    }
}

contract NFTNFTWalletTest is Test {
    NFTNFTWallet wallet;
    MockNFT mockNFT = new MockNFT();
    WalletPolicy policy = new WalletPolicy();
    address approvedOperator = 0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC;

    TestContract testContract = new TestContract();
    
    event Execution(address indexed to, uint256 value, bytes data);
    event WalletReceived(address indexed sender, uint256 value);
    
    function setUp() public {
        wallet = new NFTNFTWallet();
    }

    function testInitialize(address owner, address newOwner) public {
        vm.assume(owner != address(0));
        vm.assume(owner != newOwner);

        wallet.initialize(owner, address(policy), approvedOperator);

        assertEq(wallet.owner(), owner);
        assertEq(address(wallet.policy()), address(policy));

        vm.expectRevert("Wallet already initialized");
        wallet.initialize(newOwner, address(policy), approvedOperator);
    }

    function testExecTransactionOnlyOwner(address owner, address nonOwner) public {
        vm.assume(owner != nonOwner);
        policy.setScope(address(testContract), true, false);
        bytes4 method = testContract.pass.selector;

        wallet.initialize(owner, address(policy), approvedOperator);
        vm.prank(owner);
        wallet.execTransaction(address(testContract), 0, abi.encode(method));

        vm.prank(nonOwner);
        vm.expectRevert("caller is not the owner");
        wallet.execTransaction(address(testContract), 0, "");
    }

    function testExecTransactionFailure(address owner) public {
        policy.setScope(address(testContract), true, false);

        wallet.initialize(owner, address(policy), approvedOperator);
        vm.prank(owner);
        bytes4 selector = bytes4(keccak256("fail()"));
        vm.expectRevert("always revert");
        vm.expectEmit(true, false, false, true);
        emit Execution(address(testContract), 0, abi.encode(selector));
        wallet.execTransaction(address(testContract), 0, abi.encode(selector));
    }

    function testExecTransactionAgainstPolicy(address owner) public {
        wallet.initialize(owner, address(policy), approvedOperator);
        vm.prank(owner);
        vm.expectRevert("Prohibited transaction");
        wallet.execTransaction(address(testContract), 0, "");
    }

    function testExecTransactionAgainstPolicyMethod(address owner) public {
        bytes4 method = testContract.pass.selector;
        policy.setScope(address(testContract), true, true);
        wallet.initialize(owner, address(policy), approvedOperator);
        vm.prank(owner);
        vm.expectRevert("Prohibited transaction");
        wallet.execTransaction(address(testContract), 0, "");

        vm.prank(owner);
        vm.expectRevert("Prohibited transaction");
        wallet.execTransaction(address(testContract), 0, abi.encode(method));

        policy.setAllowedMethod(address(testContract), method, true);
        vm.prank(owner);
        bytes memory output = wallet.execTransaction(address(testContract), 0, abi.encode(method));
        assertEq(bytes32(output), bytes32(abi.encode(true)));
    }

    function testIsValidSignatureFromContract(bytes32 data) public {
        SmartWallet owner = new SmartWallet();
        wallet.initialize(address(owner), address(policy), approvedOperator);

        bytes memory sig = owner.sign(data);
        assertTrue(owner.isValidSignature(data, sig) == owner.isValidSignature.selector);
        assertTrue(wallet.isValidSignature(data, sig) == wallet.isValidSignature.selector);
    }

    function testIsValidSignatureFromEOA() public {
        address owner = 0x891e3465fCD6A67D13762487D2E326e0bF55De2F;
        wallet.initialize(owner, address(policy), approvedOperator);
        bytes32 data = hex"592fa743889fc7f92ac2a37bb1f5ba1daf2a5c84741ca0e0061d243a2e6707ba";

        // signed with eth_sign JSON-RPC method
        bytes memory sig = hex"502e2ff7a3fc796b3fd8834a90345c01234b57b84c92db5df6bd40d18c9d1c98242d2caaa9a13e805fd8ce457e53b2ea9221111703e8d50ee4855d49671307f91c";

        assertTrue(wallet.isValidSignature(data, sig) == wallet.isValidSignature.selector);
    }

    function testIsValidSignatureForTypedData() public {
        address owner = 0x891e3465fCD6A67D13762487D2E326e0bF55De2F;
        wallet.initialize(owner, address(policy), approvedOperator);

        // keccak256(abi.encode(0x47e79534a245952e8b16893a336b85a3d9ea9fa8c573f3d803afb92a79469218, 1, 0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC));
        bytes32 domainSeparator = 0xaacfa53e40b6cf4731969904a1d33ebb37884de6fd02a022d1f1ed02e1334e1f;

        bytes32 structHash = keccak256(abi.encode(
            keccak256("TypedData(string msg)"),
            keccak256("Hello World")
        ));
        bytes32 data = ECDSA.toTypedDataHash(domainSeparator, structHash);

        // signed with eth_signTypedData JSON-RPC method
        bytes memory sig = hex"96f9117a1d90af4cc375da33a88e9088a6753baca879478bc0fd64484a6161ee19b270257c2caac1e95ed31f16d9c5b441e5c2ff67e6016e384b11ea6bfa0de81b";

        assertTrue(wallet.isValidSignature(data, sig) == wallet.isValidSignature.selector);
    }

    function testReturnBorrowedNFT() public {
        address owner = 0x891e3465fCD6A67D13762487D2E326e0bF55De2F;
        wallet.initialize(owner, address(policy), approvedOperator);
        uint256 tokenId = mockNFT.mintTo(address(wallet));
        address newOwner = 0xDeaDbeefdEAdbeefdEadbEEFdeadbeEFdEaDbeeF;
        
        vm.prank(newOwner);
        vm.expectRevert("Caller is not the approved operator");
        wallet.returnBorrowedNFT(address(mockNFT), tokenId, newOwner);

        vm.prank(approvedOperator);
        wallet.returnBorrowedNFT(address(mockNFT), tokenId, newOwner);
        assertEq(mockNFT.ownerOf(tokenId), newOwner);
    }
}
