const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Trading Core Integration", function () {
  let clearingHouse, vault, positionToken, usdc;
  let owner, trader1, trader2;
  let marketToken1, marketToken2;

  beforeEach(async function () {
    [owner, trader1, trader2] = await ethers.getSigners();

    // Deploy mock USDC
    const MockERC20 = await ethers.getContractFactory("contracts/mocks/MockERC20.sol:MockERC20");
    usdc = await MockERC20.deploy("USD Coin", "USDC", 6);
    await usdc.waitForDeployment();

    // Deploy contracts in correct order
    const PositionToken = await ethers.getContractFactory("PositionToken");
    const Vault = await ethers.getContractFactory("Vault");
    const ClearingHouse = await ethers.getContractFactory("ClearingHouse");

    // Deploy with placeholder addresses first
    const tempAddress = ethers.ZeroAddress;
    positionToken = await PositionToken.deploy(tempAddress);
    vault = await Vault.deploy(tempAddress, await usdc.getAddress());
    
    // Deploy ClearingHouse with temp addresses
    clearingHouse = await ClearingHouse.deploy(
      await vault.getAddress(),
      await positionToken.getAddress(),
      await usdc.getAddress()
    );

    // Now deploy with correct ClearingHouse address
    positionToken = await PositionToken.deploy(await clearingHouse.getAddress());
    vault = await Vault.deploy(await clearingHouse.getAddress(), await usdc.getAddress());

    // Redeploy ClearingHouse with correct addresses
    clearingHouse = await ClearingHouse.deploy(
      await vault.getAddress(),
      await positionToken.getAddress(),
      await usdc.getAddress()
    );

    // Deploy market tokens
    marketToken1 = await MockERC20.deploy("Gold Token", "GOLD", 18);
    marketToken2 = await MockERC20.deploy("Silver Token", "SILVER", 18);

    // Setup traders with USDC
    await usdc.mint(trader1.address, ethers.parseUnits("100000", 6)); // 100k USDC
    await usdc.mint(trader2.address, ethers.parseUnits("100000", 6));

    // Approve USDC spending
    await usdc.connect(trader1).approve(await clearingHouse.getAddress(), ethers.parseUnits("100000", 6));
    await usdc.connect(trader2).approve(await clearingHouse.getAddress(), ethers.parseUnits("100000", 6));
  });

  describe("Complete Trading Flow", function () {
    beforeEach(async function () {
      // Initialize markets
      await clearingHouse.initializeMarket(
        await marketToken1.getAddress(),
        ethers.parseEther("100000"), // 100k vUSDC
        ethers.parseEther("10000")   // 10k vGOLD (initial price: 10 USDC/GOLD)
      );

      await clearingHouse.initializeMarket(
        await marketToken2.getAddress(),
        ethers.parseEther("50000"),  // 50k vUSDC
        ethers.parseEther("10000")   // 10k vSILVER (initial price: 5 USDC/SILVER)
      );
    });

    it("Should handle complete position lifecycle", async function () {
      const collateral = ethers.parseUnits("1000", 6); // 1000 USDC

      // === 1. Open LONG position ===
      const initialBalance = await usdc.balanceOf(trader1.address);
      
      const tx = await clearingHouse.connect(trader1).openPosition(
        await marketToken1.getAddress(),
        collateral,
        0 // LONG
      );

      const receipt = await tx.wait();
      const openEvent = receipt.logs.find(log => 
        log.topics[0] === clearingHouse.interface.getEvent("PositionOpened").topicHash
      );
      
      expect(openEvent).to.not.be.undefined;
      
      // Check USDC was transferred
      expect(await usdc.balanceOf(trader1.address)).to.equal(initialBalance - collateral);
      
      // Check position was created
      const position = await clearingHouse.getPosition(1);
      expect(position.owner).to.equal(trader1.address);
      expect(position.collateral).to.equal(collateral);
      expect(position.direction).to.equal(0); // LONG
      expect(position.size).to.be.gt(0);

      // Check NFT was minted
      expect(await positionToken.ownerOf(1)).to.equal(trader1.address);
      expect(await positionToken.balanceOf(trader1.address)).to.equal(1);

      // Check vault received funds
      expect(await usdc.balanceOf(await vault.getAddress())).to.equal(collateral);

      // === 2. Check price impact ===
      const newPrice = await clearingHouse.getMarkPrice(await marketToken1.getAddress());
      expect(newPrice).to.be.gt(ethers.parseEther("10")); // Price should increase

      // === 3. Transfer position NFT ===
      await positionToken.connect(trader1).transferFrom(trader1.address, trader2.address, 1);
      expect(await positionToken.ownerOf(1)).to.equal(trader2.address);

      // === 4. Close position (by new owner) ===
      const finalBalance = await usdc.balanceOf(trader2.address);
      
      const closeTx = await clearingHouse.connect(trader2).closePosition(1);
      const closeReceipt = await closeTx.wait();
      const closeEvent = closeReceipt.logs.find(log => 
        log.topics[0] === clearingHouse.interface.getEvent("PositionClosed").topicHash
      );
      
      expect(closeEvent).to.not.be.undefined;

      // Check position was deleted
      await expect(clearingHouse.getPosition(1)).to.be.revertedWith("Position does not exist");

      // Check NFT was burned
      await expect(positionToken.ownerOf(1)).to.be.revertedWithCustomError(positionToken, "ERC721NonexistentToken");

      // Check trader2 received payout
      const newBalance = await usdc.balanceOf(trader2.address);
      expect(newBalance).to.not.equal(finalBalance);
    });

    it("Should handle multiple positions and markets", async function () {
      // Open positions in different markets
      await clearingHouse.connect(trader1).openPosition(
        await marketToken1.getAddress(),
        ethers.parseUnits("1000", 6),
        0 // LONG GOLD
      );

      await clearingHouse.connect(trader1).openPosition(
        await marketToken2.getAddress(),
        ethers.parseUnits("500", 6),
        1 // SHORT SILVER
      );

      await clearingHouse.connect(trader2).openPosition(
        await marketToken1.getAddress(),
        ethers.parseUnits("2000", 6),
        1 // SHORT GOLD
      );

      // Check all positions exist
      const pos1 = await clearingHouse.getPosition(1);
      const pos2 = await clearingHouse.getPosition(2);
      const pos3 = await clearingHouse.getPosition(3);

      expect(pos1.owner).to.equal(trader1.address);
      expect(pos1.marketToken).to.equal(await marketToken1.getAddress());
      expect(pos1.direction).to.equal(0); // LONG

      expect(pos2.owner).to.equal(trader1.address);
      expect(pos2.marketToken).to.equal(await marketToken2.getAddress());
      expect(pos2.direction).to.equal(1); // SHORT

      expect(pos3.owner).to.equal(trader2.address);
      expect(pos3.marketToken).to.equal(await marketToken1.getAddress());
      expect(pos3.direction).to.equal(1); // SHORT

      // Check NFT ownership
      expect(await positionToken.balanceOf(trader1.address)).to.equal(2);
      expect(await positionToken.balanceOf(trader2.address)).to.equal(1);

      // Check vault has all collateral
      const expectedVaultBalance = ethers.parseUnits("3500", 6); // 1000 + 500 + 2000
      expect(await usdc.balanceOf(await vault.getAddress())).to.equal(expectedVaultBalance);
    });

    it("Should handle profit and loss scenarios", async function () {
      const collateral = ethers.parseUnits("1000", 6);

      // Trader1 opens LONG
      await clearingHouse.connect(trader1).openPosition(
        await marketToken1.getAddress(),
        collateral,
        0 // LONG
      );

      // Trader2 opens SHORT (should move price down)
      await clearingHouse.connect(trader2).openPosition(
        await marketToken1.getAddress(),
        ethers.parseUnits("5000", 6), // Large SHORT position
        1 // SHORT
      );

      // Check price moved down
      const newPrice = await clearingHouse.getMarkPrice(await marketToken1.getAddress());
      expect(newPrice).to.be.lt(ethers.parseEther("10")); // Price should decrease

      // Close positions and check payouts
      const trader1InitialBalance = await usdc.balanceOf(trader1.address);
      const trader2InitialBalance = await usdc.balanceOf(trader2.address);

      await clearingHouse.connect(trader1).closePosition(1); // LONG at lower price (loss)
      await clearingHouse.connect(trader2).closePosition(2); // SHORT at lower price (profit)

      const trader1FinalBalance = await usdc.balanceOf(trader1.address);
      const trader2FinalBalance = await usdc.balanceOf(trader2.address);

      // Trader1 (LONG) should receive less than original collateral
      expect(trader1FinalBalance - trader1InitialBalance).to.be.lt(collateral);
      
      // Trader2 (SHORT) should receive more than original collateral
      expect(trader2FinalBalance - trader2InitialBalance).to.be.gt(ethers.parseUnits("5000", 6));
    });

    it("Should prevent operations on frozen markets", async function () {
      // Open position first
      await clearingHouse.connect(trader1).openPosition(
        await marketToken1.getAddress(),
        ethers.parseUnits("1000", 6),
        0 // LONG
      );

      // Freeze market
      await clearingHouse.freezePrice(await marketToken1.getAddress());

      // Should prevent new positions
      await expect(
        clearingHouse.connect(trader2).openPosition(
          await marketToken1.getAddress(),
          ethers.parseUnits("1000", 6),
          0
        )
      ).to.be.revertedWith("ClearingHouse: Market not active");

      // Should still allow closing existing positions
      await clearingHouse.connect(trader1).closePosition(1);
    });
  });

  describe("Stress Tests", function () {
    beforeEach(async function () {
      await clearingHouse.initializeMarket(
        await marketToken1.getAddress(),
        ethers.parseEther("1000000"), // 1M vUSDC
        ethers.parseEther("100000")   // 100k vGOLD
      );
    });

    it("Should handle many small positions", async function () {
      const positions = [];
      
      // Open 20 small positions
      for (let i = 0; i < 20; i++) {
        const tx = await clearingHouse.connect(trader1).openPosition(
          await marketToken1.getAddress(),
          ethers.parseUnits("50", 6), // 50 USDC each
          i % 2 // Alternate LONG/SHORT
        );
        positions.push(i + 1);
      }

      // Check all positions exist
      expect(await positionToken.balanceOf(trader1.address)).to.equal(20);

      // Close all positions
      for (const posId of positions) {
        await clearingHouse.connect(trader1).closePosition(posId);
      }

      expect(await positionToken.balanceOf(trader1.address)).to.equal(0);
    });

    it("Should handle large position size", async function () {
      const largeCollateral = ethers.parseUnits("50000", 6); // 50k USDC

      await clearingHouse.connect(trader1).openPosition(
        await marketToken1.getAddress(),
        largeCollateral,
        0 // LONG
      );

      const position = await clearingHouse.getPosition(1);
      expect(position.collateral).to.equal(largeCollateral);
      expect(position.size).to.be.gt(0);

      // Should be able to close
      await clearingHouse.connect(trader1).closePosition(1);
    });
  });

  describe("Error Handling", function () {
    it("Should handle various error conditions gracefully", async function () {
      // Market not initialized
      const uninitializedMarket = await (await ethers.getContractFactory("contracts/mocks/MockERC20.sol:MockERC20")).deploy("Test", "TEST", 18);
      
      await expect(
        clearingHouse.connect(trader1).openPosition(
          await uninitializedMarket.getAddress(),
          ethers.parseUnits("1000", 6),
          0
        )
      ).to.be.revertedWith("ClearingHouse: Market not active");

      // Initialize market and open position
      await clearingHouse.initializeMarket(
        await marketToken1.getAddress(),
        ethers.parseEther("10000"),
        ethers.parseEther("1000")
      );

      await clearingHouse.connect(trader1).openPosition(
        await marketToken1.getAddress(),
        ethers.parseUnits("1000", 6),
        0
      );

      // Try to close non-existent position
      await expect(
        clearingHouse.connect(trader1).closePosition(999)
      ).to.be.revertedWithCustomError(positionToken, "ERC721NonexistentToken");

      // Try to close someone else's position
      await expect(
        clearingHouse.connect(trader2).closePosition(1)
      ).to.be.revertedWith("ClearingHouse: Caller is not the owner of the position");
    });
  });
}); 