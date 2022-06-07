// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./base/CallbackHandler.sol";
import "./libraries/OrderTypes.sol";
import "./interfaces/ISignatureValidator.sol";
import "./interfaces/IWalletPolicy.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract NFTNFTWallet is CallbackHandler, ISignatureValidator {
    // ERC721 interfaceID
    bytes4 public constant INTERFACE_ID_ERC721 = 0x80ac58cd;
    // ERC1155 interfaceID
    bytes4 public constant INTERFACE_ID_ERC1155 = 0xd9b67a26;

    // keccak256(
    //     "EIP712Domain(uint256 chainId,address verifyingContract)"
    // );
    bytes32 private constant DOMAIN_SEPARATOR_TYPEHASH = 0x47e79534a245952e8b16893a336b85a3d9ea9fa8c573f3d803afb92a79469218;

    // keccak256(
    //     "WalletTx(address to,uint256 value,bytes data)"
    // );
    bytes32 private constant TX_TYPEHASH = 0x830f78a1e2c835b3eabbd735c04679d8defebfa5b9a9bbedcf31b0ef2919ff9d;

    event Execution(address indexed to, uint256 value, bytes data);
    event WalletReceived(address indexed sender, uint256 value);

    mapping(bytes32 => uint256) public signedMessages;
    IWalletPolicy public policy;
    address public owner;
    address public approvedOperator;
    bool internal initialized;

    function initialize(address _owner, address _policy, address _approvedOperator) public {
        require(!initialized, "Wallet already initialized");
        owner = _owner;
        policy = IWalletPolicy(_policy);
        approvedOperator = _approvedOperator;
        initialized = true;
    }

    /// @param target Destination address of Safe transaction.
    /// @param value Ether value of Safe transaction.
    /// @param data Data payload of Safe transaction.
    function execTransaction(
        address target,
        uint256 value,
        bytes calldata data
    ) external payable virtual onlyOwner returns (bytes memory) {
        emit Execution(target, value, data);
        if (Address.isContract(target)) {
            require(policy.isMethodAllowed(target, data) == policy.isMethodAllowed.selector, "Prohibited transaction");
            return Address.functionCallWithValue(target, data, value, "Execution failed.");
        } else {
            require(data.length == 0, "Cannot pass data to transactions to EOA");
            Address.sendValue(payable(target), value);
            return "";
        }
    }

    /**
     * Implementation of EIP-1271
     * @param data Hash of the data signed on the behalf of address(msg.sender)
     * @param signature Signature byte array associated with data
     * @return the magic value upon valid or 0 bytes upon invalid signature with corresponding data
     */
    function isValidSignature(bytes32 data, bytes calldata signature) external override view returns (bytes4) {
        bytes32 prefixedData = ECDSA.toEthSignedMessageHash(data);
        bool validSig = SignatureChecker.isValidSignatureNow(owner, data, signature);
        bool validEip191Sig = SignatureChecker.isValidSignatureNow(owner, prefixedData, signature);
        return validSig || validEip191Sig ? EIP1271_MAGIC_VALUE : bytes4(0);
    }

    function returnBorrowedNFT(address collection, uint256 tokenId, address to) external {
        require(msg.sender == approvedOperator, "Caller is not the approved operator");
        require(IERC165(collection).supportsInterface(INTERFACE_ID_ERC721) ||
            IERC165(collection).supportsInterface(INTERFACE_ID_ERC1155), "collection is not ERC721 or ERC1155");
        IERC721(collection).safeTransferFrom(address(this), to, tokenId);
    }

    /// @dev Returns the chain id used by this contract.
    function getChainId() public view returns (uint256) {
        uint256 id;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            id := chainid()
        }
        return id;
    }

    function domainSeparator() public view returns (bytes32) {
        return keccak256(abi.encode(DOMAIN_SEPARATOR_TYPEHASH, getChainId(), this));
    }

    modifier onlyOwner() {
        require(owner == msg.sender, "caller is not the owner");
        _;
    }

    receive() external payable {
        emit WalletReceived(msg.sender, msg.value);
    }
}
