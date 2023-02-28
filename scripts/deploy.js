/* global ethers */
/* eslint prefer-const: "off" */

const { getSelectors, FacetCutAction } = require('./libraries/diamond.js')

async function main () {
  const accounts = await ethers.getSigners()
  const contractOwner = accounts[0]

  // deploy MarketplaceFacet
  const MarketplaceFacet = await ethers.getContractFactory('MarketplaceOnlyOwnerFacet')
  const marketplaceFacet = await MarketplaceFacet.deploy()
  await marketplaceFacet.deployed()
  console.log("marketplaceFacet",marketplaceFacet)
  console.log('MarketplaceFacet deployed:', marketplaceFacet.address)

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
