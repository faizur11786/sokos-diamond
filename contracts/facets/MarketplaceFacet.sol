// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC2981} from "@openzeppelin/contracts/interfaces/IERC2981.sol";

import {LibDiamond} from "../libraries/LibDiamond.sol";
import {AppStorage, ERC1155Listing, Modifiers, TokenFeed, Bid} from "../libraries/LibAppStorage.sol";
import {LibMeta} from "../libraries/LibMeta.sol";
import {LibMarketplace} from "../libraries/LibMarketplace.sol";
import {LibUtils} from "../libraries/LibUtils.sol";
import {LibERC20} from "../libraries/LibERC20.sol";
import {LibChainlink} from "../libraries/LibChainlink.sol";

contract MarketplaceFacet is Modifiers {
    bytes4 private constant _INTERFACE_ID_ERC2981 = 0x2a55205a;

    event RoyaltiesPaid(address tokenAddress, uint256 tokenId, uint256 royaltyAmount);
    event PaymentOptionAdded(address _paytoken);
    event PaymentOptionRemoved(address _paytoken);
    event ChangedListingFee(uint256 listingFeeInWei);
    event ERC1155ListingAdd(
        uint256 indexed listingId,
        address indexed seller,
        address indexed tokenAddress,
        uint256 tokenId,
        uint256 quantity,
        uint256 priceInUsd,
        uint256 time
    );
    event ERC1155ExecutedListing(
        uint256 indexed listingId,
        address indexed seller,
        address buyer,
        address erc1155TokenAddress,
        uint256 erc1155TypeId,
        uint256 _quantity,
        uint256 priceInUsd,
        uint256 time
    );
    event ERC1155ExecutedToRecipient(uint256 indexed listingId, address indexed buyer, address indexed recipient);
    event UpdateERC1155Listing(uint256 indexed listingId, address indexed tokenAddress, uint256 quantity, uint256 priceInUsd, uint256 time);

    event BidCreated(address indexed bidder, address indexed tokenAddress, uint256 tokenId, address payToken, uint256 bid, uint256 expiresAt);

    /// @notice To Get sokos listing fee
    /// @return NFTs listing fee in uint256
    function getListingFee() external view returns (uint256) {
        return s.listingFeeInWei;
    }

    /// @notice To Get Eth value in USD
    /// @param _eth Eth amount in wei
    /// @return Eth value in USD
    function getEthRate(uint256 _eth) public view returns (uint256) {
        uint256 ethPrice = LibChainlink.getPrice(s.ethPriceFeed);
        uint256 ethInUsd = (ethPrice * _eth) / 1e18;
        return ethInUsd;
    }

    /// @notice To Get ERC20 token value in USD
    /// @param _token ERC20 token address
    /// @param _cost Number of tokens
    /// @return Token value in USD
    function getTokenRate(address _token, uint256 _cost) public view returns (uint256) {
        TokenFeed storage tokenFeed = s.tokenToFeed[_token];
        require(tokenFeed.feed != address(0), "ERC1155Marketplace: ERC20 not acceptable");
        uint256 tokenPrice = LibChainlink.getPrice(tokenFeed.feed);
        uint256 priceInUSD = (tokenPrice * _cost) / 1e18;
        return priceInUSD;
    }

    /// @notice To Get ERC20's price feed address
    /// @param _token ERC20 token address
    /// @return tokenFeed struct of ERC20 token's price feed address and decimal
    function getTokenFeed(address _token) external view returns (TokenFeed memory) {
        return s.tokenToFeed[_token];
    }

    /// @notice To Get ERC20's price feed address
    /// @return address for eth price feed
    function getEthFeed() external view returns (address) {
        return s.ethPriceFeed;
    }

    /// @notice Method for listing NFT
    /// @param _tokenAddress Address of NFT contract
    /// @param _tokenId Token ID of NFT
    /// @param _quantity The amount of NFTs to be listed
    /// @param _priceInUsd The cost price of the NFT
    function createERC1155Listing(
        address _tokenAddress,
        uint256 _tokenId,
        uint256 _quantity,
        uint256 _priceInUsd
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
                boughtQuantity: 0,
                priceInUsd: _priceInUsd,
                timeCreated: block.timestamp,
                timeLastPurchased: 0,
                sourceListingId: 0,
                sold: false,
                cancelled: false
            });

            emit ERC1155ListingAdd(listId, seller, _tokenAddress, _tokenId, _quantity, _priceInUsd, block.timestamp);
        } else {
            ERC1155Listing storage listing = s.erc1155Listings[listingId];
            listing.quantity = _quantity;
            listing.priceInUsd = _priceInUsd;
            emit UpdateERC1155Listing(listingId, _tokenAddress, _quantity, _priceInUsd, block.timestamp);
        }
    }

    ///@notice Allow an ERC1155 owner to cancel his NFT listing through the listingID
    ///@param _listingId The identifier of the listing to be cancelled
    function cancelERC1155Listing(uint256 _listingId) external {
        LibMarketplace.cancelERC1155Listing(_listingId, LibMeta.msgSender());
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
            emit LibMarketplace.ERC1155ListingCancelled(listingId, block.number);
            LibMarketplace.removeERC1155ListingItem(listingId);
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
        LibMarketplace.updateERC1155Listing(_tokenAddress, _erc1155TypeId, _owner);
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
            LibMarketplace.updateERC1155Listing(_tokenAddress, _tokenIds[i], _owner);
        }
    }

    function safePlaceBid(
        uint256 _listingId,
        address _tokenAddress,
        uint256 _tokenId,
        uint256 _priceInUsd,
        address _payToken,
        uint256 _expiresAt
    ) external {
        ERC1155Listing storage listing = s.erc1155Listings[_listingId];
        require(listing.quantity == 1 && !listing.sold, "ERC1155Marketplace: bidding for allowed");
        require(_priceInUsd > listing.priceInUsd, "ERC1155Marketplace: bid should be greater than reserve price");

        Bid storage bid = s.bids[_tokenAddress][_tokenId];

        TokenFeed storage tokenFeed = s.tokenToFeed[_payToken];

        require(tokenFeed.feed != address(0), "ERC1155Marketplace: ERC20 not acceptable");

        address bidder = LibMeta.msgSender();

        if (bid.offerer != address(0)) {
            if (bid.expiresAt >= block.timestamp) {
                require(_priceInUsd > bid.price, "ERC1155Marketplace: bid price should be higher than last bid");
            }
            require(bid.offerer != bidder, "ERC1155Marketplace: Can't bid unless someone else has bid");
            LibMarketplace.cancelBid(_tokenAddress, _tokenId, bid);
        }
        IERC20 token = IERC20(_payToken);
        require(
            getTokenRate(tokenFeed.feed, token.allowance(bidder, address(this))) >= _priceInUsd,
            "ERC1155Marketplace: tokens spend approved not enough"
        );

        token.transferFrom(bidder, address(this), _priceInUsd);

        s.bids[_tokenAddress][_tokenId] = Bid(bidder, _payToken, listing.quantity, _priceInUsd, _expiresAt, _priceInUsd);
        emit BidCreated(bidder, _tokenAddress, _tokenId, _payToken, _priceInUsd, _expiresAt);
    }

    ///@notice Allow a buyer to execcute an open listing i.e buy the NFT on behalf of the recipient. Also checks to ensure the item details match the listing.
    ///@dev Will throw if the NFT has been sold or if the listing has been cancelled already
    ///@param _listingId The identifier of the listing to execute
    ///@param _tokenAddress The token contract address
    ///@param _tokenId the erc1155 token id
    ///@param _quantity The amount of ERC1155 NFTs execute/buy
    ///@param _payToken The ERC20 token address
    ///@param _priceInUsd the cost price of the ERC1155 NFTs individually
    ///@param _recipient the recipient of the item
    function executeERC1155ListingWithERC20(
        uint256 _listingId,
        address _tokenAddress,
        uint256 _tokenId,
        uint256 _quantity,
        address _payToken,
        uint256 _priceInUsd,
        address _recipient
    ) external {
        ERC1155Listing storage listing = s.erc1155Listings[_listingId];
        require(listing.timeCreated != 0, "ERC1155Marketplace: listing not found");
        require(listing.sold == false, "ERC1155Marketplace: listing is sold out");
        require(listing.cancelled == false, "ERC1155Marketplace: listing is cancelled");
        require(listing.priceInUsd == _priceInUsd, "ERC1155Marketplace: wrong price or price changed");
        require(listing.tokenAddress == _tokenAddress, "ERC1155Marketplace: Incorrect token address");
        require(listing.tokenId == _tokenId, "ERC1155Marketplace: Incorrect token id");
        require(_quantity > 0, "ERC1155Marketplace: _quantity can't be zero");
        require(_quantity <= listing.quantity, "ERC1155Marketplace: quantity is greater than listing");
        address buyer = LibMeta.msgSender();
        address seller = listing.seller;
        require(seller != buyer, "ERC1155Marketplace: buyer can't be seller");
        TokenFeed memory tokenFeed = s.tokenToFeed[_payToken];
        require(tokenFeed.feed != address(0), "ERC1155Marketplace: ERC20 not acceptable");
        uint256 costInWei = _quantity * (_priceInUsd * (10**(tokenFeed.decimals - s.sokosDecimals)));

        require(
            IERC20(_payToken).balanceOf(buyer) >= costInWei,
            string(abi.encodePacked("ERC1155Markrtplace: not enough", LibUtils.toAsciiString(_payToken)))
        );
        require(IERC20(_payToken).allowance(buyer, address(this)) >= costInWei, "ERC1155Marketplace: tokens spend approved not enough");

        {
            if (IERC2981(_tokenAddress).supportsInterface(_INTERFACE_ID_ERC2981)) {
                (address royaltiesReceiver, uint256 royaltiesAmount) = IERC2981(_tokenAddress).royaltyInfo(_tokenId, costInWei);
                if (royaltiesAmount > 0) {
                    LibERC20.transferFrom(_payToken, buyer, royaltiesReceiver, royaltiesAmount);
                    costInWei -= royaltiesAmount;
                    emit RoyaltiesPaid(_tokenAddress, _tokenId, royaltiesAmount);
                }
                uint256 fee = s.sokosFee;
                uint256 netCost = costInWei - fee;

                LibERC20.transferFrom(_payToken, buyer, s.feeReceipient, fee);

                LibERC20.transferFrom(_payToken, buyer, seller, netCost);
            }

            listing.quantity -= _quantity;
            listing.boughtQuantity += _quantity;
            listing.timeLastPurchased = block.timestamp;
            if (listing.quantity == 0) {
                listing.sold = true;
                LibMarketplace.removeERC1155ListingItem(_listingId);
            }
        }
        IERC1155(listing.tokenAddress).safeTransferFrom(seller, _recipient, listing.tokenId, _quantity, new bytes(0));

        emit ERC1155ExecutedListing(
            _listingId,
            seller,
            _recipient,
            listing.tokenAddress,
            listing.tokenId,
            _quantity,
            listing.priceInUsd,
            block.timestamp
        );

        //Only emit if buyer is not recipient
        if (buyer != _recipient) {
            emit ERC1155ExecutedToRecipient(_listingId, buyer, _recipient);
        }
    }

    ///@notice Allow a buyer to execcute an open listing i.e buy the NFT on behalf of the recipient. Also checks to ensure the item details match the listing.
    ///@dev Will throw if the NFT has been sold or if the listing has been cancelled already
    ///@param _listingId The identifier of the listing to execute
    ///@param _tokenAddress The token contract address
    ///@param _tokenId the erc1155 token id
    ///@param _quantity The amount of ERC1155 NFTs execute/buy
    ///@param _priceInUsd the cost price of the ERC1155 NFTs individually
    ///@param _recipient the recipient of the item
    function executeERC1155ListingWithEth(
        uint256 _listingId,
        address _tokenAddress,
        uint256 _tokenId,
        uint256 _quantity,
        uint256 _priceInUsd,
        address _recipient
    ) external {
        ERC1155Listing storage listing = s.erc1155Listings[_listingId];
        require(listing.timeCreated != 0, "ERC1155Marketplace: listing not found");
        require(listing.sold == false, "ERC1155Marketplace: listing is sold out");
        require(listing.cancelled == false, "ERC1155Marketplace: listing is cancelled");
        require(_priceInUsd == listing.priceInUsd, "ERC1155Marketplace: wrong price or price changed");
        require(listing.tokenAddress == _tokenAddress, "ERC1155Marketplace: Incorrect token address");
        require(listing.tokenId == _tokenId, "ERC1155Marketplace: Incorrect token id");
        require(_quantity > 0, "ERC1155Marketplace: _quantity can't be zero");
        require(_quantity <= listing.quantity, "ERC1155Marketplace: quantity is greater than listing");
        address buyer = LibMeta.msgSender();
        address seller = listing.seller;
        require(seller != buyer, "ERC1155Marketplace: buyer can't be seller");

        // uint256 cost = _quantity * _priceInUsd;

        // {
        //     if (IERC2981(_tokenAddress).supportsInterface(_INTERFACE_ID_ERC2981)) {
        //         (address royaltiesReceiver, uint256 royaltiesAmount) = IERC2981(_tokenAddress).royaltyInfo(_tokenId, cost);
        //         if (royaltiesAmount > 0) {
        //             LibERC20.transferFrom(_payToken, buyer, royaltiesReceiver, royaltiesAmount);
        //             cost -= royaltiesAmount;
        //             emit RoyaltiesPaid(_tokenAddress, _tokenId, royaltiesAmount);
        //         }
        //         uint256 netCost = cost - s.sokosFee;

        //         LibERC20.transferFrom(_payToken, buyer, s.feeReceipient, s.sokosFee);

        //         LibERC20.transferFrom(_payToken, buyer, seller, netCost);
        //     }

        //     listing.quantity -= _quantity;
        //     listing.boughtQuantity += _quantity;
        //     listing.timeLastPurchased = block.timestamp;
        //     if (listing.quantity == 0) {
        //         listing.sold = true;
        //         LibMarketplace.removeERC1155ListingItem(_listingId);
        //     }
        // }
        IERC1155(listing.tokenAddress).safeTransferFrom(seller, _recipient, listing.tokenId, _quantity, new bytes(0));

        emit ERC1155ExecutedListing(
            _listingId,
            seller,
            _recipient,
            listing.tokenAddress,
            listing.tokenId,
            _quantity,
            listing.priceInUsd,
            block.timestamp
        );

        //Only emit if buyer is not recipient
        if (buyer != _recipient) {
            emit ERC1155ExecutedToRecipient(_listingId, buyer, _recipient);
        }
    }
}
