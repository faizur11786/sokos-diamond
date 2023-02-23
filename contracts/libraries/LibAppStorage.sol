// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISokosRegistry} from "../interfaces/ISokosRegistry.sol";
import {LibDiamond} from "./LibDiamond.sol";
import {LibMeta} from "./LibMeta.sol";

/// @notice Structure for listed items
struct Listing {
    uint256 quantity;
    uint256 price;
    uint256 startingTime;
    uint256 expiresAt;
    bool isERC1155;
}

/// @notice Structure for Bid offer
struct Offer {
    address offerer;
    IERC20 payToken;
    uint256 quantity;
    uint256 price;
    uint256 expiresAt;
    uint256 paidTokens;
}

struct AppStorage {
    mapping(address => uint256) metaNonces;
    bytes32 domainSeparator;
    /// @notice Platform fee
    uint16 platformFee;
    /// @notice Platform mint fee
    uint256 mintFee;
    /// @notice Platform fee receipient
    address payable feeReceipient;
    ISokosRegistry sokosAddressRegistry;
    /// @notice NftAddress -> Token ID -> Owner -> Listing item
    mapping(address => mapping(uint256 => mapping(address => Listing))) listings;
    /// @notice NftAddress -> Token ID -> Offer
    mapping(address => mapping(uint256 => Offer)) offers;
    /// @notice Platform acceptable token ( Token address to Feed)
    mapping(address => address) tokenToFeed;
    mapping(address => bool) itemManagers;
}

library LibAppStorage {
    bytes32 constant APP_STORAGE_POSITION = keccak256("diamond.standard.app.storage");

    function getStorage() internal pure returns (AppStorage storage ds) {
        bytes32 position = APP_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }
}

contract Modifiers {
    AppStorage internal s;

    modifier onlyOwner() {
        LibDiamond.enforceIsContractOwner();
        _;
    }

    modifier onlyItemManager() {
        address sender = LibMeta.msgSender();
        require(s.itemManagers[sender] == true, "LibAppStorage: only an ItemManager can call this function");
        _;
    }
    modifier onlyOwnerOrItemManager() {
        address sender = LibMeta.msgSender();
        require(
            sender == LibDiamond.contractOwner() || s.itemManagers[sender] == true,
            "LibAppStorage: only an Owner or ItemManager can call this function"
        );
        _;
    }
}
