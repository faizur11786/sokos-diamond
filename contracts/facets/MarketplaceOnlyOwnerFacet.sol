// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Modifiers} from "../libraries/LibAppStorage.sol";
import {LibMarketplace} from "../libraries/LibMarketplace.sol";

contract MarketplaceOnlyOwnerFacet is Modifiers {
    event ChangedListingFee(uint256 listingFeeInWei);

    ///@notice Allow the sokos owner to set Sokos Decimals (recommended: 6)
    ///@param _decimals The decimals number
    function setSokosDecimals(uint8 _decimals) external onlyOwner {
        s.sokosDecimals = _decimals;
    }

    ///@notice Allow the sokos owner to set the default listing fee
    ///@param _listingFeeInWei The new listing fee in wei
    function setListingFee(uint256 _listingFeeInWei) external onlyOwner {
        s.listingFeeInWei = _listingFeeInWei;
        emit ChangedListingFee(s.listingFeeInWei);
    }

    ///@notice Allow the sokos owner to set the Eth Price Feed
    ///@param _ethFeed Chainlink price feed address
    function setEthPriceFeed(address _ethFeed) external onlyOwner {
        s.ethPriceFeed = _ethFeed;
    }

    /// @notice To Set ERC20 token price feed address
    /// @param _token ERC20 token address
    /// @param _feed Address of ERC20 token price feed
    function setTokenFeed(
        address _token,
        address _feed,
        uint8 _decimals
    ) external onlyOwner {
        LibMarketplace.setTokenFeed(_token, _feed, _decimals);
    }

    /// @notice To remove ERC20 token price feed address
    /// @param _token ERC20 token address
    function removeTokenFeed(address _token) external onlyOwner {
        require(
            s.tokenToFeed[_token].feed != address(0),
            "ERC1155Marketplace: token feed does not exist"
        );
        LibMarketplace.removeTokenFeed(_token);
    }
}
