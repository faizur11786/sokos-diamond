/* global ethers */
/* eslint prefer-const: "off" */

const { getSelectors, FacetCutAction } = require("../libraries/diamond.js");

async function main() {
    const accounts = await ethers.getSigners();
    const contractOwner = accounts[0];

    // deploy DiamondCutFacet
    const DiamondCutFacet = await ethers.getContractFactory("DiamondCutFacet"); // 0x42A084184Db372a86f857AC9850134Cb55611cd7
    const diamondCutFacet = await DiamondCutFacet.deploy();
    await diamondCutFacet.deployed();
    console.log("DiamondCutFacet deployed:", diamondCutFacet.address);

    // deploy SokosDiamond
    const SokosDiamond = await ethers.getContractFactory("SokosDiamond"); // 0x4F35B8C11062Dcdf7a799e02AC1B75BF0bE8De9d
    const sokosDiamond = await SokosDiamond.deploy(
        contractOwner.address,
        diamondCutFacet.address
    );
    await sokosDiamond.deployed();
    console.log("SokosDiamond deployed:", sokosDiamond.address);

    // deploy DiamondInit
    // DiamondInit provides a function that is called when the diamond is upgraded to initialize state variables
    // Read about how the diamondCut function works here: https://eips.ethereum.org/EIPS/eip-2535#addingreplacingremoving-functions
    const DiamondInit = await ethers.getContractFactory("DiamondInit"); // 0x2dD7415E2aA367F3CF8956F18548714387Bf51F5
    const diamondInit = await DiamondInit.deploy();
    await diamondInit.deployed();
    console.log("DiamondInit deployed:", diamondInit.address);

    // deploy facets
    console.log("");
    console.log("Deploying facets");
    const FacetNames = [
        "DiamondLoupeFacet", // 0xE0cfca5782f50e6EDD1Ce53DfB89ADa410828c6F
        "OwnershipFacet", // 0x6472f8D1b15b47e701F89BF05f1130e967C077A6
        "MarketplaceFacet", // 0x48d2654A38F06260b3916cB43A4b0695cF1C5fc4
        // 'MarketplaceOnlyOwnerFacet', // 0x48d2654A38F06260b3916cB43A4b0695cF1C5fc4
        "MetaTransactionsFacet", // 0x271E865D7d730bCbb80339091aEB6Cd3c806E59a
    ];
    const cut = [];
    for (const FacetName of FacetNames) {
        const Facet = await ethers.getContractFactory(FacetName);
        const facet = await Facet.deploy();
        await facet.deployed();
        console.log(`${FacetName} deployed: ${facet.address}`);
        cut.push({
            facetAddress: facet.address,
            action: FacetCutAction.Add,
            functionSelectors: getSelectors(facet),
        });
    }

    // upgrade diamond with facets
    console.log("");
    console.log("Diamond Cut:", cut);
    const diamondCut = await ethers.getContractAt(
        "IDiamondCut",
        sokosDiamond.address
    );
    let tx;
    let receipt;
    // call to init function
    let functionCall = diamondInit.interface.encodeFunctionData("init");
    tx = await diamondCut.diamondCut(cut, diamondInit.address, functionCall);
    console.log("Diamond cut tx: ", tx.hash);
    receipt = await tx.wait();
    if (!receipt.status) {
        throw Error(`Diamond upgrade failed: ${tx.hash}`);
    }
    console.log("Completed diamond cut");
    return sokosDiamond.address;
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
