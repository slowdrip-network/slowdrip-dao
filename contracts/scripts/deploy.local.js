const { ethers } = require("hardhat");

async function main() {
  const [deployer, governance] = await ethers.getSigners();
  console.log("Deployer:", deployer.address);

  // You can replicate the test flow here to deploy to Sepolia if you want.
  // For brevity, we’ll just print the network.
  console.log("Network:", (await ethers.provider.getNetwork()).name);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
