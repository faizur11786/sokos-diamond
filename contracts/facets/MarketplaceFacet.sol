// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";
import {AppStorage, ERC1155Listing, Modifiers} from "../libraries/LibAppStorage.sol";
import {LibMeta} from "../libraries/LibMeta.sol";
import {LibSharedMarketplace} from "../libraries/LibSharedMarketplace.sol";

contract MarketplaceFacet is Modifiers, ReentrancyGuard {
    event PaymentOptionAdded(address _paytoken);
    event PaymentOptionRemoved(address _paytoken);
    event ChangedListingFee(uint256 listingFeeInWei);
    event ERC1155ListingAdd(
        uint256 indexed listingId,
        address indexed seller,
        address indexed tokenAddress,
        uint256 tokenId,
        uint256 quantity,
        uint256 priceInWei,
        uint256 time
    );
    event UpdateERC1155Listing(uint256 indexed listingId, address indexed tokenAddress, uint256 quantity, uint256 priceInWei, uint256 time);

    ///@notice Allow the sokos owner to set the default listing fee
    ///@param _listingFeeInWei The new listing fee in wei
    function setListingFee(uint256 _listingFeeInWei) external onlyOwner {
        s.listingFeeInWei = _listingFeeInWei;
        emit ChangedListingFee(s.listingFeeInWei);
    }

    /// @notice To Get ERC20's price feed address
    /// @param _token ERC20 token address
    /// @return Address of ERC20 token's price feed
    function getERC20feed(address _token) internal view returns (address) {
        return s.erc20ToFeed[_token];
    }

    /// @notice To Set ERC20 token price feed address
    /// @param _token ERC20 token address
    /// @param _feed Address of ERC20 token price feed
    function setERC20Feed(address _token, address _feed) internal onlyOwner {
        s.erc20ToFeed[_token] = _feed;
        emit PaymentOptionAdded(_token);
    }

    /// @notice To remove ERC20 token price feed address
    /// @param _token ERC20 token address
    function removeERC20Feed(address _token) internal onlyOwner {
        delete s.erc20ToFeed[_token];
        emit PaymentOptionRemoved(_token);
    }

    /// @notice Method for listing NFT
    /// @param _tokenAddress Address of NFT contract
    /// @param _tokenId Token ID of NFT
    /// @param _quantity The amount of NFTs to be listed
    /// @param _priceInWei The cost price of the NFT
    function createERC1155Listing(
        address _tokenAddress,
        uint256 _tokenId,
        uint256 _quantity,
        uint256 _priceInWei
    ) external {
        address seller = LibMeta.msgSender();
        IERC1155 erc1155Token = IERC1155(_tokenAddress);

        require(erc1155Token.balanceOf(seller, _tokenId) >= _quantity, "ERC1155Marketplace: Not enough ERC1155 token");
        require(erc1155Token.isApprovedForAll(seller, address(this)), "ERC1155Marketplace: Not approved for transfer");

        uint256 listingId = s.erc1155TokenToListingId[_tokenAddress][_tokenId][seller];

        if (listingId == 0) {
            uint256 listId = s.nextListingId++;

            s.erc1155TokenToListingId[_tokenAddress][_tokenId][seller] = listId;
            s.erc1155Listings[listId] = ERC1155Listing({
                listingId: listId,
                seller: seller,
                tokenAddress: _tokenAddress,
                tokenId: _tokenId,
                quantity: _quantity,
                priceInWei: _priceInWei,
                timeCreated: block.timestamp,
                timeLastPurchased: 0,
                sourceListingId: 0,
                sold: false,
                cancelled: false
            });

            emit ERC1155ListingAdd(listId, seller, _tokenAddress, _tokenId, _quantity, _priceInWei, block.timestamp);
        } else {
            ERC1155Listing storage listing = s.erc1155Listings[listingId];
            listing.quantity = _quantity;
            listing.priceInWei = _priceInWei;
            emit UpdateERC1155Listing(listingId, _tokenAddress, _quantity, _priceInWei, block.timestamp);
        }
    }

    ///@notice Allow an ERC1155 owner to cancel his NFT listing through the listingID
    ///@param _listingId The identifier of the listing to be cancelled
    function cancelERC1155Listing(uint256 _listingId) external {
        LibSharedMarketplace.cancelERC1155Listing(_listingId, LibMeta.msgSender());
    }

    ///@notice Allow an ERC1155 owner to cancel his NFT listings through the listingIDs
    ///@param _listingIds An array containing the identifiers of the listings to be cancelled
    function cancelERC1155Listings(uint256[] calldata _listingIds) external onlyOwner {
        for (uint256 i; i < _listingIds.length; i++) {
            uint256 listingId = _listingIds[i];

            ERC1155Listing storage listing = s.erc1155Listings[listingId];
            if (listing.cancelled == true || listing.sold == true) {
                return;
            }
            listing.cancelled = true;
            emit LibSharedMarketplace.ERC1155ListingCancelled(listingId, block.number);
            LibSharedMarketplace.removeERC1155ListingItem(listingId);
        }
    }

    ///@notice Update the ERC1155 listing of an address
    ///@param _tokenAddress Contract address of the ERC1155 token
    ///@param _erc1155TypeId Identifier of the ERC1155 token
    ///@param _owner Owner of the ERC1155 token
    function updateERC1155Listing(
        address _tokenAddress,
        uint256 _erc1155TypeId,
        address _owner
    ) external {
        LibSharedMarketplace.updateERC1155Listing(_tokenAddress, _erc1155TypeId, _owner);
    }

    ///@notice Update the ERC1155 listings of an address
    ///@param _tokenAddress Contract address of the ERC1155 token
    ///@param _tokenIds An array containing the identifiers of the ERC1155 tokens to update
    ///@param _owner Owner of the ERC1155 tokens
    function updateBatchERC1155Listing(
        address _tokenAddress,
        uint256[] calldata _tokenIds,
        address _owner
    ) external {
        for (uint256 i; i < _tokenIds.length; i++) {
            LibSharedMarketplace.updateERC1155Listing(_tokenAddress, _tokenIds[i], _owner);
        }
    }
}
