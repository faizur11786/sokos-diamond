/* global ethers */
/* eslint prefer-const: "off" */

const { getSelectors, FacetCutAction } = require("./libraries/diamond.js");

async function main() {
    const accounts = await ethers.getSigners();
    const contractOwner = accounts[0];
    const diamond = { address: "0xD43040F9562c7Fd9be370986960CAa6b91EFD084" };

    const FacetNames = ["MarketplaceFacet"];
    const cut = [];

    for (const FacetName of FacetNames) {
        const facet = await ethers.getContractAt(
            FacetName,
            "0xAB5229B46F8854aCF167681f26Fb30c9BF8A3eD9"
        );
        cut.push({
            facetAddress: facet.address,
            action: FacetCutAction.Add,
            functionSelectors: getSelectors(facet).get(["getOwner()"]),
        });
    }
    // upgrade diamond with facets
    console.log("");
    console.log("Diamond Cut:", cut);
    const diamondCut = await ethers.getContractAt(
        "IDiamondCut",
        diamond.address
    );
    let tx;
    let receipt;
    // call to init function
    const diamondInit = await ethers.getContractAt(
        "DiamondInit",
        "0x98a1C75d6E80Ffe8182040dD1EbF27C2Ab6Bcb10"
    );
    let functionCall = diamondInit.interface.encodeFunctionData("init");
    tx = await diamondCut.diamondCut(cut, diamondInit.address, functionCall);
    console.log("Diamond cut tx: ", tx.hash);
    receipt = await tx.wait();
    if (!receipt.status) {
        throw Error(`Diamond upgrade failed: ${tx.hash}`);
    }
    console.log("Completed diamond cut");
    return diamond.address;
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
