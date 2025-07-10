const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Vault", function () {
  let vault, usdc, clearingHouse;
  let owner, user1, user2;

  beforeEach(async function () {
    [owner, user1, user2] = await ethers.getSigners();

    // Deploy mock USDC
    const MockERC20 = await ethers.getContractFactory("MockERC20");
    usdc = await MockERC20.deploy("USD Coin", "USDC", 6);
    await usdc.waitForDeployment();

    // Deploy Vault with temporary address (will be updated)
    const Vault = await ethers.getContractFactory("Vault");
    vault = await Vault.deploy(user1.address, await usdc.getAddress()); // user1 acts as clearingHouse
    await vault.waitForDeployment();

    clearingHouse = user1; // For simplicity in tests
  });

  describe("Deployment", function () {
    it("Should set correct immutable addresses", async function () {
      expect(await vault.clearingHouse()).to.equal(clearingHouse.address);
      expect(await vault.usdc()).to.equal(await usdc.getAddress());
    });

    it("Should revert with zero ClearingHouse address", async function () {
      const Vault = await ethers.getContractFactory("Vault");
      await expect(
        Vault.deploy(ethers.ZeroAddress, await usdc.getAddress())
      ).to.be.revertedWith("Vault: Invalid ClearingHouse address");
    });

    it("Should revert with zero USDC address", async function () {
      const Vault = await ethers.getContractFactory("Vault");
      await expect(
        Vault.deploy(user1.address, ethers.ZeroAddress)
      ).to.be.revertedWith("Vault: Invalid USDC address");
    });
  });

  describe("deposit", function () {
    beforeEach(async function () {
      // Mint USDC to clearingHouse and approve vault
      await usdc.mint(clearingHouse.address, ethers.parseUnits("10000", 6));
      await usdc.connect(clearingHouse).approve(await vault.getAddress(), ethers.parseUnits("10000", 6));
    });

    it("Should deposit USDC successfully", async function () {
      const depositAmount = ethers.parseUnits("1000", 6);
      const initialVaultBalance = await usdc.balanceOf(await vault.getAddress());
      const initialClearingBalance = await usdc.balanceOf(clearingHouse.address);

      await vault.connect(clearingHouse).deposit(depositAmount);

      const finalVaultBalance = await usdc.balanceOf(await vault.getAddress());
      const finalClearingBalance = await usdc.balanceOf(clearingHouse.address);

      expect(finalVaultBalance).to.equal(initialVaultBalance + depositAmount);
      expect(finalClearingBalance).to.equal(initialClearingBalance - depositAmount);
    });

    it("Should revert if not called by ClearingHouse", async function () {
      const depositAmount = ethers.parseUnits("1000", 6);

      await expect(
        vault.connect(user2).deposit(depositAmount)
      ).to.be.revertedWith("Vault: Caller is not the ClearingHouse");
    });

    it("Should revert if insufficient allowance", async function () {
      const depositAmount = ethers.parseUnits("1000", 6);
      
      // Reset approval
      await usdc.connect(clearingHouse).approve(await vault.getAddress(), 0);

      await expect(
        vault.connect(clearingHouse).deposit(depositAmount)
      ).to.be.revertedWithCustomError(usdc, "ERC20InsufficientAllowance");
    });

    it("Should revert if insufficient balance", async function () {
      const depositAmount = ethers.parseUnits("20000", 6); // More than minted

      await expect(
        vault.connect(clearingHouse).deposit(depositAmount)
      ).to.be.revertedWithCustomError(usdc, "ERC20InsufficientBalance");
    });
  });

  describe("withdraw", function () {
    beforeEach(async function () {
      // Setup vault with some USDC
      await usdc.mint(clearingHouse.address, ethers.parseUnits("10000", 6));
      await usdc.connect(clearingHouse).approve(await vault.getAddress(), ethers.parseUnits("10000", 6));
      await vault.connect(clearingHouse).deposit(ethers.parseUnits("5000", 6));
    });

    it("Should withdraw USDC successfully", async function () {
      const withdrawAmount = ethers.parseUnits("1000", 6);
      const initialVaultBalance = await usdc.balanceOf(await vault.getAddress());
      const initialUserBalance = await usdc.balanceOf(user2.address);

      await vault.connect(clearingHouse).withdraw(user2.address, withdrawAmount);

      const finalVaultBalance = await usdc.balanceOf(await vault.getAddress());
      const finalUserBalance = await usdc.balanceOf(user2.address);

      expect(finalVaultBalance).to.equal(initialVaultBalance - withdrawAmount);
      expect(finalUserBalance).to.equal(initialUserBalance + withdrawAmount);
    });

    it("Should revert if not called by ClearingHouse", async function () {
      const withdrawAmount = ethers.parseUnits("1000", 6);

      await expect(
        vault.connect(user2).withdraw(user2.address, withdrawAmount)
      ).to.be.revertedWith("Vault: Caller is not the ClearingHouse");
    });

    it("Should revert if insufficient vault balance", async function () {
      const withdrawAmount = ethers.parseUnits("10000", 6); // More than vault has

      await expect(
        vault.connect(clearingHouse).withdraw(user2.address, withdrawAmount)
      ).to.be.revertedWithCustomError(usdc, "ERC20InsufficientBalance");
    });

    it("Should allow withdrawal to zero address (burning tokens)", async function () {
      const withdrawAmount = ethers.parseUnits("1000", 6);
      const initialVaultBalance = await usdc.balanceOf(await vault.getAddress());

      // This should work - tokens get "burned" to zero address
      await vault.connect(clearingHouse).withdraw(ethers.ZeroAddress, withdrawAmount);

      const finalVaultBalance = await usdc.balanceOf(await vault.getAddress());
      expect(finalVaultBalance).to.equal(initialVaultBalance - withdrawAmount);
    });
  });

  describe("Edge cases", function () {
    beforeEach(async function () {
      await usdc.mint(clearingHouse.address, ethers.parseUnits("10000", 6));
      await usdc.connect(clearingHouse).approve(await vault.getAddress(), ethers.parseUnits("10000", 6));
    });

    it("Should handle zero amount deposit", async function () {
      const initialBalance = await usdc.balanceOf(await vault.getAddress());
      
      await vault.connect(clearingHouse).deposit(0);
      
      const finalBalance = await usdc.balanceOf(await vault.getAddress());
      expect(finalBalance).to.equal(initialBalance);
    });

    it("Should handle zero amount withdrawal", async function () {
      // First deposit some amount
      await vault.connect(clearingHouse).deposit(ethers.parseUnits("1000", 6));
      
      const initialBalance = await usdc.balanceOf(await vault.getAddress());
      
      await vault.connect(clearingHouse).withdraw(user2.address, 0);
      
      const finalBalance = await usdc.balanceOf(await vault.getAddress());
      expect(finalBalance).to.equal(initialBalance);
    });

    it("Should handle multiple deposits and withdrawals", async function () {
      // Multiple deposits
      await vault.connect(clearingHouse).deposit(ethers.parseUnits("1000", 6));
      await vault.connect(clearingHouse).deposit(ethers.parseUnits("2000", 6));
      
      expect(await usdc.balanceOf(await vault.getAddress())).to.equal(ethers.parseUnits("3000", 6));

      // Multiple withdrawals
      await vault.connect(clearingHouse).withdraw(user1.address, ethers.parseUnits("500", 6));
      await vault.connect(clearingHouse).withdraw(user2.address, ethers.parseUnits("1000", 6));
      
      expect(await usdc.balanceOf(await vault.getAddress())).to.equal(ethers.parseUnits("1500", 6));
    });

    it("Should handle very small amounts (1 wei)", async function () {
      await vault.connect(clearingHouse).deposit(1);
      expect(await usdc.balanceOf(await vault.getAddress())).to.equal(1);

      await vault.connect(clearingHouse).withdraw(user2.address, 1);
      expect(await usdc.balanceOf(await vault.getAddress())).to.equal(0);
    });
  });
}); 