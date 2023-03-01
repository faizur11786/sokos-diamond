/* global ethers */
/* eslint prefer-const: "off" */

const { getSelectors, FacetCutAction } = require("./libraries/diamond.js");

async function main() {
    const accounts = await ethers.getSigners();
    const contractOwner = accounts[0];

    const diamond = { address: "0xD43040F9562c7Fd9be370986960CAa6b91EFD084" };

    // deploy facets
    console.log("");
    console.log("Deploying facets");
    const FacetNames = ["MarketplaceFacet"];
    const cut = [];
    for (const FacetName of FacetNames) {
        // const Facet = await ethers.getContractFactory(FacetName)
        // const facet = await Facet.deploy()
        // await facet.deployed()
        // console.log(`${FacetName} deployed: ${facet.address}`)
        const facet = await ethers.getContractAt(
            FacetName,
            "0x7740ad7150ff9ccfc833606d3ac5b180ac6776e9"
        );

        cut.push({
            facetAddress: ethers.constants.AddressZero,
            action: FacetCutAction.Remove,
            functionSelectors: getSelectors(facet).get([
                "getERC1155Listings()",
                "getERC1155Listings2()",
            ]),
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
    console.log("functionCall", ethers.constants.AddressZero);
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
