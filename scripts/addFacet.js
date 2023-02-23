/* global ethers */
/* eslint prefer-const: "off" */

const { getSelectors, FacetCutAction } = require('./libraries/diamond.js')

async function main () {
  const accounts = await ethers.getSigners()
  const contractOwner = accounts[0]

  const diamond = {address:"0x6255E92B3548B165F1fc6d5A06C4B760b9456907"}

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
    const facet = await ethers.getContractAt(FacetName, "0x3E4119644E7800c0d44d406D28f3e673313598fd")
    cut.push({
      facetAddress: facet.address,
      action: FacetCutAction.Add,
      functionSelectors: getSelectors(facet)
    })
  }
  // upgrade diamond with facets
  console.log('')
  console.log('Diamond Cut:', cut)
  const diamondCut = await ethers.getContractAt('IDiamondCut', diamond.address)
  let tx
  let receipt
  // call to init function
  const diamondInit = await ethers.getContractAt('DiamondInit', "0x71f924f9be65c293eaE06c800D336e1e06767733")
  let functionCall = diamondInit.interface.encodeFunctionData('init')
  console.log("functionCall", functionCall)
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
