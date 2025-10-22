// scripts/deploy.drip.cjs
// Hardhat 2.x, CommonJS
const { ethers } = require("hardhat");

async function main() {
  const [deployer, governance] = await ethers.getSigners();
  console.log("Deployer:", deployer.address);
  console.log("Governance:", governance.address);

  // -------- 0) PRE-EXISTING MODULE ADDRESSES (if already deployed) --------
  // If you already deployed these earlier, paste their addresses here.
  // Otherwise, deploy them in this script before using them.
  const vregAddr    = process.env.VERIFIER_REGISTRY || "0xVerifierRegistryAddress";
  const feeRouterAddr = process.env.FEE_ROUTER || "0xFeeRouterAddress";
  const paramsAddr  = process.env.PARAM_STORE || "0xParameterStoreAddress";

  // -------- 1) DEPLOY DRIP (fixed supply with allocations) --------
  const DRIP = await ethers.getContractFactory("DRIP");

  // Replace with your real multisigs/wallets
  const INVESTORS    = process.env.ADDR_INVESTORS    || "0xInvestorsMultisig";
  const DEV_RESERVE  = process.env.ADDR_DEV_RESERVE  || "0xDevReserveMultisig";
  const TREASURY_LLC = process.env.ADDR_TREASURY     || "0xTreasuryVaultOrEOA";
  const ECOSYSTEM    = process.env.ADDR_ECOSYSTEM    || "0xEcosystemGrants";
  const LIQUIDITY    = process.env.ADDR_LIQUIDITY    || "0xLiquidityMgr";

  const recipients = [INVESTORS, DEV_RESERVE, TREASURY_LLC, ECOSYSTEM, LIQUIDITY];
  const amounts = [
    "70720000", // Investors — 32%
    "48620000", // Developer Reserve — 22%
    "44200000", // Treasury — 20%
    "39780000", // Ecosystem — 18%
    "17680000"  // Liquidity — 8%
  ].map(x => ethers.parseUnits(x, 18));

  const drip = await DRIP.deploy(recipients, amounts);
  await drip.waitForDeployment();
  const dripAddr = await drip.getAddress();
  console.log("DRIP deployed at:", dripAddr);

  // -------- 2) BONDING/STAKING USES DRIP --------
  const BondingManager = await ethers.getContractFactory("BondingManager");
  // unbondDelay = e.g., 7 days (in seconds). Using 0 for demo.
  const bonding = await BondingManager.deploy(dripAddr, 0, governance.address);
  await bonding.waitForDeployment();
  console.log("BondingManager:", await bonding.getAddress());

  const { writeManifest } = require("./utils/writeManifest.cjs");

  // -------- 3) SESSION ESCROW (if you want payments in DRIP) --------
  // If you prefer USDC (or a stable), deploy/use that token address instead of `dripAddr`.
  const SessionEscrow = await ethers.getContractFactory("SessionEscrow");
  const escrow = await SessionEscrow.deploy(
    dripAddr,        // token used for payments (swap to USDC addr if desired)
    vregAddr,        // VerifierRegistry
    feeRouterAddr,   // FeeRouter
    paramsAddr,      // ParameterStore
    governance.address
  );
  await escrow.waitForDeployment();
  console.log("SessionEscrow:", await escrow.getAddress());

  // -------- 4) (OPTIONAL) REGISTER IN DAO REGISTRY --------
  // If you have DaoRegistry deployed, wire the new addresses:
  if (process.env.DAO_REGISTRY) {
    const dao = await ethers.getContractAt("DaoRegistry", process.env.DAO_REGISTRY);
    await (await dao.connect(governance).setBondingManager(await bonding.getAddress())).wait();
    await (await dao.connect(governance).setSessionEscrow(await escrow.getAddress())).wait();
    console.log("DaoRegistry updated.");
  }
  writeManifest(
    "declared-contracts.manifest.test.json",
    {
      chain: "optimism-sepolia",
      chainId: 11155420,
      canonical: false,
      contracts: [
        { name: "DRIP_L2", address: dripL2Addr, verified: true },
        { name: "ParameterStore", address: paramsAddr, verified: true, params: { protocol_fee_bps: 1200 } },
        // ...
      ]
    }
  );
  

  console.log("Done.");
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
