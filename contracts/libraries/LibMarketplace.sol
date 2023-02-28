// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {LibAppStorage, AppStorage, ERC1155Listing, Modifiers, TokenFeed, Bid} from "./LibAppStorage.sol";
import {LibDiamond} from "./LibDiamond.sol";

library LibMarketplace {
    event PaymentOptionAdded(address _paytoken);
    event PaymentOptionRemoved(address _paytoken);
    event ERC1155ListingCancelled(uint256 indexed listingId, uint256 time);
    event ERC1155ListingRemoved(uint256 indexed listingId, uint256 time);
    event UpdateERC1155Listing(uint256 indexed listingId, uint256 quantity, uint256 priceInUsd, uint256 time);
    event BidCancelled(address indexed bidder, address indexed tokenAddress, uint256 tokenId);

    function setTokenFeed(
        address _token,
        address _feed,
        uint8 _decimals
    ) internal {
        AppStorage storage s = LibAppStorage.getStorage();

        s.tokenToFeed[_token] = TokenFeed({feed: _feed, decimals: _decimals});
        emit PaymentOptionAdded(_token);
    }

    function removeTokenFeed(address _token) internal {
        AppStorage storage s = LibAppStorage.getStorage();

        delete s.tokenToFeed[_token];
        emit PaymentOptionRemoved(_token);
    }

    function cancelERC1155Listing(uint256 _listingId, address _owner) internal {
        AppStorage storage s = LibAppStorage.getStorage();
        ERC1155Listing storage listing = s.erc1155Listings[_listingId];
        if (listing.cancelled == true || listing.sold == true) {
            return;
        }
        require(listing.seller == _owner, "Marketplace: owner not seller");
        listing.cancelled = true;
        emit ERC1155ListingCancelled(_listingId, block.timestamp);
        removeERC1155ListingItem(_listingId);
    }

    function removeERC1155ListingItem(uint256 _listingId) internal {
        AppStorage storage s = LibAppStorage.getStorage();
        delete s.erc1155Listings[_listingId];
        emit ERC1155ListingRemoved(_listingId, block.timestamp);
    }

    function updateERC1155Listing(
        address _tokenAddress,
        uint256 _tokenId,
        address _owner
    ) internal {
        AppStorage storage s = LibAppStorage.getStorage();
        uint256 listingId = s.erc1155TokenToListingId[_tokenAddress][_tokenId][_owner];
        if (listingId == 0) {
            return;
        }
        ERC1155Listing storage listing = s.erc1155Listings[listingId];
        if (listing.timeCreated == 0 || listing.cancelled == true || listing.sold == true) {
            return;
        }
        uint256 quantity = listing.quantity;
        if (quantity > 0) {
            quantity = IERC1155(listing.tokenAddress).balanceOf(listing.seller, listing.tokenId);
            if (quantity < listing.quantity) {
                listing.quantity = quantity;
                emit UpdateERC1155Listing(listingId, quantity, listing.priceInUsd, block.timestamp);
            }
        }
        if (quantity == 0) {
            cancelERC1155Listing(listingId, listing.seller);
        }
    }

    function cancelBid(
        address _tokenAddress,
        uint256 _tokenId,
        Bid storage bid
    ) internal {
        AppStorage storage s = LibAppStorage.getStorage();
        IERC20(bid.payToken).transfer(bid.offerer, bid.paidAmount);
        emit BidCancelled(bid.offerer, _tokenAddress, _tokenId);
        delete s.bids[_tokenAddress][_tokenId];
    }
}
