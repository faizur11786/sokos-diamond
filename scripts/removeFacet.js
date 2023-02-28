/* global ethers */
/* eslint prefer-const: "off" */

const { getSelectors, FacetCutAction } = require('./libraries/diamond.js')

async function main () {
  const accounts = await ethers.getSigners()
  const contractOwner = accounts[0]

  const diamond = {address:"0x428368456ff18ed34be652d98014311A468797E5"}

  // deploy facets
  console.log('')
  console.log('Deploying facets')
  const FacetNames = [
    'MarketplaceFacet'
  ]
  const cut = []
  for (const FacetName of FacetNames) {
    // const Facet = await ethers.getContractFactory(FacetName)
    // const facet = await Facet.deploy()
    // await facet.deployed()
    // console.log(`${FacetName} deployed: ${facet.address}`)
    const facet = await ethers.getContractAt(FacetName, "0x66a68b2db124fa3ef2582b17723012c264c0b96f")
    
    cut.push({
      facetAddress: ethers.constants.AddressZero,
      action: FacetCutAction.Remove,
      functionSelectors: getSelectors(facet).get(["setListingFee(uint256)","setEthPriceFeed(address)","setERC20Feed(address,address,uint8)","removeERC20Feed(address)"])
    })
  }
  // upgrade diamond with facets
  console.log('')
  console.log('Diamond Cut:', cut)
  const diamondCut = await ethers.getContractAt('IDiamondCut', diamond.address)
  let tx
  let receipt
  // call to init function
  const diamondInit = await ethers.getContractAt('DiamondInit', "0x26Ce00D0D5a33bE5EF382363422712a69551E6e9")
  let functionCall = diamondInit.interface.encodeFunctionData('init')
  console.log("functionCall", ethers.constants.AddressZero)
  tx = await diamondCut.diamondCut(cut, diamondInit.address, functionCall)
  console.log('Diamond cut tx: ', tx.hash)
  receipt = await tx.wait()
  if (!receipt.status) {
    throw Error(`Diamond upgrade failed: ${tx.hash}`)
  }
  console.log('Completed diamond cut')
  return diamond.address
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
if (require.main === module) {
  main()
    .then(() => process.exit(0))
    .catch(error => {
      console.error(error)
      process.exit(1)
    })
}

exports.main = main
