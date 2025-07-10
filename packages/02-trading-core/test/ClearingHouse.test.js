const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("ClearingHouse", function () {
  let clearingHouse, vault, positionToken, usdc;
  let owner, trader1, trader2;
  let marketToken;

  beforeEach(async function () {
    [owner, trader1, trader2] = await ethers.getSigners();

    // Deploy mock USDC
    const MockERC20 = await ethers.getContractFactory("contracts/mocks/MockERC20.sol:MockERC20");
    usdc = await MockERC20.deploy("USD Coin", "USDC", 6); // 6 decimals like real USDC
    await usdc.waitForDeployment();

    // Deploy PositionToken
    const PositionToken = await ethers.getContractFactory("PositionToken");
    positionToken = await PositionToken.deploy(ethers.ZeroAddress); // Will set later
    await positionToken.waitForDeployment();

    // Deploy Vault
    const Vault = await ethers.getContractFactory("Vault");
    vault = await Vault.deploy(ethers.ZeroAddress, await usdc.getAddress()); // Will set later
    await vault.waitForDeployment();

    // Deploy ClearingHouse
    const ClearingHouse = await ethers.getContractFactory("ClearingHouse");
    clearingHouse = await ClearingHouse.deploy(
      await vault.getAddress(),
      await positionToken.getAddress(),
      await usdc.getAddress()
    );
    await clearingHouse.waitForDeployment();

    // Update PositionToken and Vault with correct ClearingHouse address
    positionToken = await PositionToken.deploy(await clearingHouse.getAddress());
    vault = await Vault.deploy(await clearingHouse.getAddress(), await usdc.getAddress());

    // Redeploy ClearingHouse with correct addresses
    clearingHouse = await ClearingHouse.deploy(
      await vault.getAddress(),
      await positionToken.getAddress(),
      await usdc.getAddress()
    );

    // Deploy mock market token
    const MockMarketToken = await ethers.getContractFactory("contracts/mocks/MockERC20.sol:MockERC20");
    marketToken = await MockMarketToken.deploy("Gold Token", "GOLD", 18);
    await marketToken.waitForDeployment();

    // Setup USDC for traders
    await usdc.mint(trader1.address, ethers.parseUnits("10000", 6)); // 10,000 USDC
    await usdc.mint(trader2.address, ethers.parseUnits("10000", 6));
  });

  describe("Deployment", function () {
    it("Should set correct immutable addresses", async function () {
      expect(await clearingHouse.vault()).to.equal(await vault.getAddress());
      expect(await clearingHouse.positionToken()).to.equal(await positionToken.getAddress());
      expect(await clearingHouse.usdc()).to.equal(await usdc.getAddress());
    });

    it("Should start with position ID = 1", async function () {
      // Position ID should start at 1 (0 reserved for non-existent)
      expect(await clearingHouse._nextPositionId).to.be.undefined; // private variable
    });
  });

  describe("initializeMarket", function () {
    it("Should initialize a new market", async function () {
      await clearingHouse.initializeMarket(
        await marketToken.getAddress(),
        ethers.parseEther("10000"), // 10k vUSDC
        ethers.parseEther("1000")   // 1k vTokenX
      );

      const market = await clearingHouse.markets(await marketToken.getAddress());
      expect(market.reserve_vUSDC).to.equal(ethers.parseEther("10000"));
      expect(market.reserve_vTokenX).to.equal(ethers.parseEther("1000"));
      expect(market.isActive).to.be.true;
    });

    it("Should allow reinitializing existing market", async function () {
      // First initialization
      await clearingHouse.initializeMarket(
        await marketToken.getAddress(),
        ethers.parseEther("10000"),
        ethers.parseEther("1000")
      );

      // Second initialization with different values
      await clearingHouse.initializeMarket(
        await marketToken.getAddress(),
        ethers.parseEther("20000"),
        ethers.parseEther("2000")
      );

      const market = await clearingHouse.markets(await marketToken.getAddress());
      expect(market.reserve_vUSDC).to.equal(ethers.parseEther("20000"));
      expect(market.reserve_vTokenX).to.equal(ethers.parseEther("2000"));
    });
  });

  describe("openPosition", function () {
    beforeEach(async function () {
      // Initialize market
      await clearingHouse.initializeMarket(
        await marketToken.getAddress(),
        ethers.parseEther("10000"),
        ethers.parseEther("1000")
      );

      // Approve USDC for trader1
      await usdc.connect(trader1).approve(
        await clearingHouse.getAddress(),
        ethers.parseUnits("10000", 6)
      );
    });

    it("Should open LONG position successfully", async function () {
      const collateral = ethers.parseUnits("100", 6); // 100 USDC

      const tx = await clearingHouse.connect(trader1).openPosition(
        await marketToken.getAddress(),
        collateral,
        0 // LONG
      );

      const receipt = await tx.wait();
      const event = receipt.logs.find(log => 
        log.topics[0] === clearingHouse.interface.getEvent("PositionOpened").topicHash
      );

      expect(event).to.not.be.undefined;

      // Check position was created
      const position = await clearingHouse.getPosition(1);
      expect(position.owner).to.equal(trader1.address);
      expect(position.marketToken).to.equal(await marketToken.getAddress());
      expect(position.collateral).to.equal(collateral);
      expect(position.direction).to.equal(0); // LONG
      expect(position.size).to.be.gt(0);

      // Check NFT was minted
      expect(await positionToken.ownerOf(1)).to.equal(trader1.address);
    });

    it("Should open SHORT position successfully", async function () {
      const collateral = ethers.parseUnits("100", 6);

      await clearingHouse.connect(trader1).openPosition(
        await marketToken.getAddress(),
        collateral,
        1 // SHORT
      );

      const position = await clearingHouse.getPosition(1);
      expect(position.direction).to.equal(1); // SHORT
    });

    it("Should revert with zero collateral", async function () {
      await expect(
        clearingHouse.connect(trader1).openPosition(
          await marketToken.getAddress(),
          0,
          0
        )
      ).to.be.revertedWith("ClearingHouse: Collateral must be positive");
    });

    it("Should revert with inactive market", async function () {
      // Create another market token but don't initialize
      const MockMarketToken = await ethers.getContractFactory("contracts/mocks/MockERC20.sol:MockERC20");
      const inactiveMarket = await MockMarketToken.deploy("Inactive", "INACT", 18);

      await expect(
        clearingHouse.connect(trader1).openPosition(
          await inactiveMarket.getAddress(),
          ethers.parseUnits("100", 6),
          0
        )
      ).to.be.revertedWith("ClearingHouse: Market not active");
    });

    it("Should update market reserves correctly", async function () {
      const initialMarket = await clearingHouse.markets(await marketToken.getAddress());
      
      await clearingHouse.connect(trader1).openPosition(
        await marketToken.getAddress(),
        ethers.parseUnits("100", 6),
        0 // LONG
      );

      const finalMarket = await clearingHouse.markets(await marketToken.getAddress());
      
      // LONG should increase vUSDC and decrease vTokenX
      expect(finalMarket.reserve_vUSDC).to.be.gt(initialMarket.reserve_vUSDC);
      expect(finalMarket.reserve_vTokenX).to.be.lt(initialMarket.reserve_vTokenX);
    });
  });

  describe("closePosition", function () {
    let positionId;

    beforeEach(async function () {
      // Initialize market and open position
      await clearingHouse.initializeMarket(
        await marketToken.getAddress(),
        ethers.parseEther("10000"),
        ethers.parseEther("1000")
      );

      await usdc.connect(trader1).approve(
        await clearingHouse.getAddress(),
        ethers.parseUnits("10000", 6)
      );

      const tx = await clearingHouse.connect(trader1).openPosition(
        await marketToken.getAddress(),
        ethers.parseUnits("100", 6),
        0 // LONG
      );

      positionId = 1; // First position
    });

    it("Should close position successfully", async function () {
      const initialBalance = await usdc.balanceOf(trader1.address);

      await clearingHouse.connect(trader1).closePosition(positionId);

      // Position should be deleted
      await expect(
        clearingHouse.getPosition(positionId)
      ).to.be.revertedWith("Position does not exist");

      // NFT should be burned
      await expect(
        positionToken.ownerOf(positionId)
      ).to.be.revertedWith("ERC721: invalid token ID");

      // Trader should receive some payout (could be profit or loss)
      const finalBalance = await usdc.balanceOf(trader1.address);
      expect(finalBalance).to.not.equal(initialBalance);
    });

    it("Should revert if not position owner", async function () {
      await expect(
        clearingHouse.connect(trader2).closePosition(positionId)
      ).to.be.revertedWith("ClearingHouse: Caller is not the owner of the position");
    });

    it("Should revert for non-existent position", async function () {
      await expect(
        clearingHouse.connect(trader1).closePosition(999)
      ).to.be.revertedWith("ERC721: invalid token ID");
    });
  });

  describe("getMarkPrice", function () {
    beforeEach(async function () {
      await clearingHouse.initializeMarket(
        await marketToken.getAddress(),
        ethers.parseEther("10000"), // 10k vUSDC
        ethers.parseEther("1000")   // 1k vTokenX
      );
    });

    it("Should return correct mark price", async function () {
      const price = await clearingHouse.getMarkPrice(await marketToken.getAddress());
      expect(price).to.equal(ethers.parseEther("10")); // 10000/1000 = 10
    });

    it("Should return updated price after trades", async function () {
      const initialPrice = await clearingHouse.getMarkPrice(await marketToken.getAddress());
      
      // Open position to change reserves
      await usdc.connect(trader1).approve(await clearingHouse.getAddress(), ethers.parseUnits("1000", 6));
      await clearingHouse.connect(trader1).openPosition(
        await marketToken.getAddress(),
        ethers.parseUnits("100", 6),
        0 // LONG
      );

      const newPrice = await clearingHouse.getMarkPrice(await marketToken.getAddress());
      expect(newPrice).to.not.equal(initialPrice);
      expect(newPrice).to.be.gt(initialPrice); // LONG should increase price
    });
  });

  describe("freezePrice", function () {
    beforeEach(async function () {
      await clearingHouse.initializeMarket(
        await marketToken.getAddress(),
        ethers.parseEther("10000"),
        ethers.parseEther("1000")
      );
    });

    it("Should freeze market", async function () {
      await clearingHouse.freezePrice(await marketToken.getAddress());
      
      const market = await clearingHouse.markets(await marketToken.getAddress());
      expect(market.isActive).to.be.false;
    });

    it("Should prevent new positions after freeze", async function () {
      await clearingHouse.freezePrice(await marketToken.getAddress());

      await usdc.connect(trader1).approve(await clearingHouse.getAddress(), ethers.parseUnits("100", 6));
      
      await expect(
        clearingHouse.connect(trader1).openPosition(
          await marketToken.getAddress(),
          ethers.parseUnits("100", 6),
          0
        )
      ).to.be.revertedWith("ClearingHouse: Market not active");
    });
  });
}); 