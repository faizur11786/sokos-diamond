// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {LibDiamond} from "../libraries/LibDiamond.sol";
import {AppStorage, Modifiers} from "../libraries/LibAppStorage.sol";

contract MarketplaceFacet is Modifiers {
    AppStorage internal s;
}
