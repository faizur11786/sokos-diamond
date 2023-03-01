/* global ethers */
/* eslint prefer-const: "off" */

const { getSelectors, FacetCutAction } = require("./libraries/diamond.js");

async function main() {
    const accounts = await ethers.getSigners();
    const contractOwner = accounts[0];

    const diamond = { address: "0xD43040F9562c7Fd9be370986960CAa6b91EFD084" };

    // deploy facets
    console.log("");
    console.log("Running...");
    const FacetName = "MarketplaceFacet";
    const facet = await ethers.getContractAt(FacetName, diamond.address);
    const listings = await facet.getERC1155Listings2();

    console.log("facet", listings);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
if (require.main === module) {
    main()
        .then(() => process.exit(0))
        .catch((error) => {
            console.error(error);
            process.exit(1);
        });
}

exports.main = main;
