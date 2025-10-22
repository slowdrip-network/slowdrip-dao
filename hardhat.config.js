// hardhat.config.cjs
require("dotenv").config();
require("@nomicfoundation/hardhat-toolbox");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.20",
    settings: { optimizer: { enabled: true, runs: 800 } }
  },
  networks: {
    hardhat: {},
    //sepolia: {
    //  url: process.env.ALCHEMY_SEPOLIA || "",
    //  accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : []
    //},
    //mainnet: {
    //  url: process.env.ALCHEMY_MAINNET || "",
    //  accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : []
    //}
  },
  mocha: { timeout: 120000 }
};
