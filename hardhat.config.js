// hardhat.config.cjs
require("dotenv").config();
require("@nomicfoundation/hardhat-toolbox");

const {
  SEPOLIA_RPC,
  OP_SEPOLIA_RPC,
  BASE_SEPOLIA_RPC,
  ARB_SEPOLIA_RPC,
  ALCHEMY_MAINNET,        // optional
  PRIVATE_KEY
} = process.env;

// validate PRIVATE_KEY: must be 0x + 64 hex chars
const isHex32 = typeof PRIVATE_KEY === "string" && /^0x[0-9a-fA-F]{64}$/.test(PRIVATE_KEY);
const accounts = isHex32 ? [PRIVATE_KEY] : []; // if bad/missing, no accounts are set

// Build networks object only when RPC URL is provided.
// This avoids Hardhat complaining about "undefined url".
const networks = { hardhat: {} };

if (SEPOLIA_RPC) {
  networks.sepolia = { url: SEPOLIA_RPC, accounts };
}
if (OP_SEPOLIA_RPC) {
  networks.optimismSepolia = { url: OP_SEPOLIA_RPC, accounts };
}
if (BASE_SEPOLIA_RPC) {
  networks.baseSepolia = { url: BASE_SEPOLIA_RPC, accounts };
}
if (ARB_SEPOLIA_RPC) {
  networks.arbitrumSepolia = { url: ARB_SEPOLIA_RPC, accounts };
}
// optional mainnet (only if you set it)
if (ALCHEMY_MAINNET) {
  networks.mainnet = { url: ALCHEMY_MAINNET, accounts };
}

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.20",
    settings: { optimizer: { enabled: true, runs: 800 } }
  },
  networks,
  mocha: { timeout: 120000 }
};
