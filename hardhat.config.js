
/* global ethers task */
// require('@nomiclabs/hardhat-waffle')
require("@openzeppelin/hardhat-upgrades");
require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task('accounts', 'Prints the list of accounts', async () => {
  const accounts = await ethers.getSigners()

  for (const account of accounts) {
    console.log(account.address)
  }
})

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: {
    version: "0.8.9",
    settings: {
        optimizer: {
            enabled: true,
            runs: 1,
        },
    },
  },
  networks: {
      mumbai: {
          url: "https://nd-462-884-459.p2pify.com/70eaca77551eac07163154a14c5e9432",
          accounts: [`${process.env.PRIV_KEY}`],
          chainId: 80001,
      },
      goerli: {
          url: "https://nd-719-675-074.p2pify.com/633210afb47eeb316abfc98e05db1dba",
          accounts: [`${process.env.PRIV_KEY}`],
          chainId: 5,
      },
  },
  etherscan: {
      apiKey: {
          goerli: process.env.GORELI_API_KEY,
          polygonMumbai: process.env.ETHERSCAN_API_KEY,
      },
  },
}
