// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface ISokosRegistry {
    function sokosMaticPriceFeed() external view returns (address);

    function sokosPriceFeed() external view returns (address);

    function isSokosNFT(address _nft) external view returns (bool);

    function createCollection(
        string memory _name,
        string memory _symbol,
        bool _isPublic
    ) external returns (address);

    function marketplace() external view returns (address);

    function owner() external view returns (address);
}
