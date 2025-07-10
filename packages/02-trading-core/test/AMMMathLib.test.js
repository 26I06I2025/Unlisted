const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("AMMMathLib", function () {
  let amm;
  
  // Helper function to deploy test contract
  beforeEach(async function () {
    const AMMMathLibTest = await ethers.getContractFactory("AMMMathLibTest");
    amm = await AMMMathLibTest.deploy();
    await amm.waitForDeployment();
  });

  describe("calculateMarkPrice", function () {
    it("Should calculate correct mark price", async function () {
      // reserve_vUSDC = 1000e18, reserve_vTokenX = 100e18
      // Expected price = 1000/100 = 10e18
      const price = await amm.calculateMarkPrice(
        ethers.parseEther("1000"), // 1000 USDC
        ethers.parseEther("100")   // 100 TokenX
      );
      expect(price).to.equal(ethers.parseEther("10"));
    });

    it("Should revert with zero vTokenX reserves", async function () {
      await expect(
        amm.calculateMarkPrice(ethers.parseEther("1000"), 0)
      ).to.be.revertedWith("AMM: No vTokenX liquidity");
    });
  });

  describe("calculateLongOpen", function () {
    it("Should calculate correct LONG open amounts", async function () {
      // Initial: 1000 USDC, 100 TokenX (price = 10)
      // Collateral: 100 USDC
      // Expected: get ~9.09 TokenX (constant product formula)
      const result = await amm.calculateLongOpen(
        ethers.parseEther("100"),  // collateral
        ethers.parseEther("1000"), // reserve_vUSDC
        ethers.parseEther("100")   // reserve_vTokenX
      );

      // Verify reserves update correctly
      expect(result.newReserve_vUSDC).to.equal(ethers.parseEther("1100"));
      expect(result.newReserve_vTokenX).to.be.lt(ethers.parseEther("100"));
      expect(result.vTokenAmount).to.be.gt(0);
      
      // Verify constant product (k = x * y should remain ~constant)
      const k_before = ethers.parseEther("1000") * ethers.parseEther("100");
      const k_after = result.newReserve_vUSDC * result.newReserve_vTokenX;
      expect(k_after).to.be.gte(k_before); // Should be >= due to fees/slippage
    });

    it("Should revert if insufficient vTokenX liquidity", async function () {
      // Try to get more TokenX than available
      await expect(
        amm.calculateLongOpen(
          ethers.parseEther("10000"), // huge collateral
          ethers.parseEther("1000"),
          ethers.parseEther("100")
        )
      ).to.be.revertedWith("AMM: Insufficient vTokenX liquidity");
    });
  });

  describe("calculateShortOpen", function () {
    it("Should calculate correct SHORT open amounts", async function () {
      // Initial: 1000 USDC, 100 TokenX
      // Want to "sell" TokenX to get 100 USDC
      const result = await amm.calculateShortOpen(
        ethers.parseEther("100"),  // collateral
        ethers.parseEther("1000"), // reserve_vUSDC
        ethers.parseEther("100")   // reserve_vTokenX
      );

      // Verify reserves update correctly
      expect(result.newReserve_vUSDC).to.equal(ethers.parseEther("900"));
      expect(result.newReserve_vTokenX).to.be.gt(ethers.parseEther("100"));
      expect(result.vTokenAmount).to.be.gt(0);
    });

    it("Should revert if insufficient vUSDC liquidity", async function () {
      await expect(
        amm.calculateShortOpen(
          ethers.parseEther("1000"), // collateral > reserves
          ethers.parseEther("500"),
          ethers.parseEther("100")
        )
      ).to.be.revertedWith("AMM: Insufficient vTokenX liquidity");
    });
  });

  describe("calculateLongClose", function () {
    it("Should calculate positive PnL for profitable LONG", async function () {
      // Simulate: opened LONG when price was 10, now price is higher
      // Position size: 10 TokenX, Original collateral: 100 USDC
      // Current reserves suggest higher price (less TokenX, more USDC)
      const result = await amm.calculateLongClose(
        ethers.parseEther("10"),   // position size
        ethers.parseEther("100"),  // original collateral
        ethers.parseEther("1200"), // current vUSDC (higher)
        ethers.parseEther("80")    // current vTokenX (lower)
      );

      // Should get more USDC back than original collateral (profit)
      expect(result.pnl).to.be.gt(0);
      expect(result.newReserve_vTokenX).to.equal(ethers.parseEther("90"));
    });

    it("Should calculate negative PnL for losing LONG", async function () {
      // Simulate: opened LONG when price was 10, now price is lower
      const result = await amm.calculateLongClose(
        ethers.parseEther("10"),   // position size
        ethers.parseEther("100"),  // original collateral
        ethers.parseEther("800"),  // current vUSDC (lower)
        ethers.parseEther("120")   // current vTokenX (higher)
      );

      // Should get less USDC back than original collateral (loss)
      expect(result.pnl).to.be.lt(0);
    });
  });

  describe("calculateShortClose", function () {
    it("Should calculate positive PnL for profitable SHORT", async function () {
      // Simulate: opened SHORT when price was 10, now price is lower
      // Need less USDC to buy back the TokenX (profit)
      const result = await amm.calculateShortClose(
        ethers.parseEther("10"),   // position size
        ethers.parseEther("100"),  // original collateral
        ethers.parseEther("800"),  // current vUSDC (lower)
        ethers.parseEther("120")   // current vTokenX (higher)
      );

      // Should need less USDC to buy back (profit)
      expect(result.pnl).to.be.gt(0);
    });

    it("Should calculate negative PnL for losing SHORT", async function () {
      // Simulate: opened SHORT when price was 10, now price is higher
      const result = await amm.calculateShortClose(
        ethers.parseEther("10"),   // position size
        ethers.parseEther("100"),  // original collateral
        ethers.parseEther("1200"), // current vUSDC (higher)
        ethers.parseEther("80")    // current vTokenX (lower)
      );

      // Should need more USDC to buy back (loss)
      expect(result.pnl).to.be.lt(0);
    });
  });

  describe("Edge cases", function () {
    it("Should handle very small amounts", async function () {
      const result = await amm.calculateLongOpen(
        1, // 1 wei
        ethers.parseEther("1000"),
        ethers.parseEther("100")
      );
      expect(result.vTokenAmount).to.be.gt(0);
    });

    it("Should handle very large amounts within bounds", async function () {
      const result = await amm.calculateLongOpen(
        ethers.parseEther("100"),
        ethers.parseEther("1000000"), // 1M USDC
        ethers.parseEther("100000")   // 100K TokenX
      );
      expect(result.vTokenAmount).to.be.gt(0);
    });
  });
}); 