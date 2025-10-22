// test/e2e.settlement.fee-split.test.js
import { expect } from "chai";
import { ethers } from "hardhat";

describe("SlowDrip DAO LLC stack (clean version)", function () {
  it("funds escrow, assigns miner, verifies, settles, and splits fees", async function () {
    const [deployer, governance, client, miner, validatorsPool, reporter, treasuryEOA] = await ethers.getSigners();

    // --- Deploy mocks ---
    const MockERC20 = await ethers.getContractFactory("MockERC20");
    const token = await MockERC20.deploy();
    await token.waitForDeployment();

    // Mint client funds: 1,000 mUSD
    const ONE = ethers.parseUnits("1", 18);
    await token.mint(client.address, ONE * 1000n);

    const MockVerifier = await ethers.getContractFactory("MockVerifier");
    const mockVerifier = await MockVerifier.deploy();
    await mockVerifier.waitForDeployment();

    // --- Deploy core modules ---
    const DaoRegistry = await ethers.getContractFactory("DaoRegistry");
    const dao = await DaoRegistry.deploy(
      "SlowDrip DAO LLC",
      ethers.keccak256(ethers.toUtf8Bytes("constitution-v1")),
      governance.address
    );
    await dao.waitForDeployment();

    const ParameterStore = await ethers.getContractFactory("ParameterStore");
    const params = await ParameterStore.deploy(0, governance.address); // delay=0 for tests
    await params.waitForDeployment();

    const KEY_FEE = ethers.keccak256(ethers.toUtf8Bytes("protocol_fee_bps"));
    await params.connect(governance).setBounds(KEY_FEE, 0, 2000, 1200); // 12%

    const TreasuryVault = await ethers.getContractFactory("TreasuryVault");
    const treasury = await TreasuryVault.deploy(governance.address);
    await treasury.waitForDeployment();

    const FeeRouter = await ethers.getContractFactory("FeeRouter");
    const feeRouter = await FeeRouter.deploy(
      governance.address,
      validatorsPool.address,
      await treasury.getAddress(),
      7000 // θ = 70%
    );
    await feeRouter.waitForDeployment();

    const VerifierRegistry = await ethers.getContractFactory("VerifierRegistry");
    const vreg = await VerifierRegistry.deploy(governance.address, mockVerifier.target);
    await vreg.waitForDeployment();

    const BondingManager = await ethers.getContractFactory("BondingManager");
    const bonding = await BondingManager.deploy(token.target, 0, governance.address);
    await bonding.waitForDeployment();

    const FraudProof = await ethers.getContractFactory("FraudProof");
    const fraud = await FraudProof.deploy(governance.address, bonding.target, 0);
    await fraud.waitForDeployment();

    const SessionEscrow = await ethers.getContractFactory("SessionEscrow");
    const escrow = await SessionEscrow.deploy(
      token.target, vreg.target, feeRouter.target, params.target, governance.address
    );
    await escrow.waitForDeployment();

    // Wire addresses into registry (as governance)
    await dao.connect(governance).setTreasury(treasury.target);
    await dao.connect(governance).setGovernance(governance.address);
    await dao.connect(governance).setVerifier(vreg.target);
    await dao.connect(governance).setFeeRouter(feeRouter.target);
    await dao.connect(governance).setParameterStore(params.target);
    await dao.connect(governance).setBondingManager(bonding.target);
    await dao.connect(governance).setFraudProof(fraud.target);
    await dao.connect(governance).setSessionEscrow(escrow.target);

    // --- Client funds escrow ---
    const sid = ethers.keccak256(ethers.toUtf8Bytes("session-1"));
    await token.connect(client).approve(escrow.target, ONE * 300n);
    await escrow.connect(client).fund(sid, ONE * 300n);

    // Assign miner (governance acts as validator in tests)
    await escrow.connect(governance).assignMiner(sid, miner.address);

    const wValue = ONE * 200n; // work value 200
    const publicInputs = ethers.AbiCoder.defaultAbiCoder().encode(
      ["bytes32", "uint256"], [sid, wValue]
    );

    const beforeMiner = await token.balanceOf(miner.address);
    const beforeValidators = await token.balanceOf(validatorsPool.address);

    await escrow.connect(governance).settle(sid, "0x", publicInputs);

    const fBps = 1200n; // 12%
    const fee = (wValue * fBps) / 10000n; // 24
    const minerNet = wValue - fee;       // 176

    const afterMiner = await token.balanceOf(miner.address);
    expect(afterMiner - beforeMiner).to.equal(minerNet);

    const validatorsShare = (fee * 7000n) / 10000n; // 16.8
    const treasuryBal = await token.balanceOf(await treasury.getAddress());
    const afterValidators = await token.balanceOf(validatorsPool.address);

    expect(afterValidators - beforeValidators).to.equal(validatorsShare);
    expect(treasuryBal).to.equal(fee - validatorsShare);

    const esc = await escrow.escrows(sid);
    expect(esc.amount).to.equal(ONE * 100n);
    expect(esc.settled).to.equal(true);
  });
});
