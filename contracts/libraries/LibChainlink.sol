// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {AppStorage, LibAppStorage} from "./LibAppStorage.sol";

library LibChainlink {
    function getPrice(address _priceFeed) internal view returns (uint256) {
        (, int256 answer, , , ) = AggregatorV3Interface(_priceFeed).latestRoundData();
        return uint256(answer) * (10**(18 - AggregatorV3Interface(_priceFeed).decimals()));
    }
}
