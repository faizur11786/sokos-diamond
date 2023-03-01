/* global ethers */
/* eslint prefer-const: "off" */

const { getSelectors, FacetCutAction } = require("./libraries/diamond.js");

async function main() {
    const accounts = await ethers.getSigners();
    const contractOwner = accounts[0];

    const diamond = { address: "0xD43040F9562c7Fd9be370986960CAa6b91EFD084" };
    console.log("Caller Address...", contractOwner.address);
    // deploy facets
    console.log("");
    console.log("Running...");
    const FacetName = "MarketplaceFacet";
    const facet = await ethers.getContractAt(FacetName, diamond.address);

    const gasPrice = ethers.utils.parseUnits("226.9", "gwei");

    // console.log(
    //     "facet",
    //     await facet.estimateGas.executeERC1155ListingWithERC20(
    //         "1",
    //         "0xcc6d6f15c3fffc3e4825bc528afdc5514c84ad52",
    //         "1",
    //         "2",
    //         "0xfa22C55711a4aED74E46ACfe4B171e02386444bf",
    //         contractOwner.address
    //     )
    // );
    const tx = await facet.executeERC1155ListingWithERC20(
        "4",
        "0xcc6d6f15c3fffc3e4825bc528afdc5514c84ad52",
        "3",
        "9",
        "0xfa22C55711a4aED74E46ACfe4B171e02386444bf",
        contractOwner.address
    );
    console.log("facet", tx);
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
