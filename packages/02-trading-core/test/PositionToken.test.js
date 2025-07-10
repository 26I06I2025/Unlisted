const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("PositionToken", function () {
  let positionToken, clearingHouse;
  let owner, user1, user2;

  beforeEach(async function () {
    [owner, user1, user2] = await ethers.getSigners();

    // Deploy PositionToken
    const PositionToken = await ethers.getContractFactory("PositionToken");
    positionToken = await PositionToken.deploy(user1.address); // user1 acts as clearingHouse
    await positionToken.waitForDeployment();

    clearingHouse = user1; // For simplicity in tests
  });

  describe("Deployment", function () {
    it("Should set correct name and symbol", async function () {
      expect(await positionToken.name()).to.equal("DeFi Protocol Position");
      expect(await positionToken.symbol()).to.equal("DPP");
    });

    it("Should set correct clearingHouse address", async function () {
      expect(await positionToken.clearingHouse()).to.equal(clearingHouse.address);
    });

    it("Should revert with zero ClearingHouse address", async function () {
      const PositionToken = await ethers.getContractFactory("PositionToken");
      await expect(
        PositionToken.deploy(ethers.ZeroAddress)
      ).to.be.revertedWith("PositionToken: Invalid ClearingHouse address");
    });
  });

  describe("mint", function () {
    it("Should mint NFT successfully when called by ClearingHouse", async function () {
      const tokenId = 1;
      
      await positionToken.connect(clearingHouse).mint(user2.address, tokenId);

      expect(await positionToken.ownerOf(tokenId)).to.equal(user2.address);
      expect(await positionToken.balanceOf(user2.address)).to.equal(1);
    });

    it("Should mint multiple NFTs to same user", async function () {
      await positionToken.connect(clearingHouse).mint(user2.address, 1);
      await positionToken.connect(clearingHouse).mint(user2.address, 2);
      await positionToken.connect(clearingHouse).mint(user2.address, 3);

      expect(await positionToken.balanceOf(user2.address)).to.equal(3);
      expect(await positionToken.ownerOf(1)).to.equal(user2.address);
      expect(await positionToken.ownerOf(2)).to.equal(user2.address);
      expect(await positionToken.ownerOf(3)).to.equal(user2.address);
    });

    it("Should mint NFTs to different users", async function () {
      await positionToken.connect(clearingHouse).mint(user1.address, 1);
      await positionToken.connect(clearingHouse).mint(user2.address, 2);

      expect(await positionToken.ownerOf(1)).to.equal(user1.address);
      expect(await positionToken.ownerOf(2)).to.equal(user2.address);
    });

    it("Should revert if not called by ClearingHouse", async function () {
      await expect(
        positionToken.connect(user2).mint(user2.address, 1)
      ).to.be.revertedWith("PositionToken: Caller is not the ClearingHouse");
    });

    it("Should revert if token already exists", async function () {
      await positionToken.connect(clearingHouse).mint(user2.address, 1);
      
      await expect(
        positionToken.connect(clearingHouse).mint(user1.address, 1)
      ).to.be.revertedWithCustomError(positionToken, "ERC721InvalidSender");
    });

    it("Should revert if minting to zero address", async function () {
      await expect(
        positionToken.connect(clearingHouse).mint(ethers.ZeroAddress, 1)
      ).to.be.revertedWithCustomError(positionToken, "ERC721InvalidReceiver");
    });
  });

  describe("burn", function () {
    beforeEach(async function () {
      // Mint some tokens first
      await positionToken.connect(clearingHouse).mint(user1.address, 1);
      await positionToken.connect(clearingHouse).mint(user2.address, 2);
      await positionToken.connect(clearingHouse).mint(user2.address, 3);
    });

    it("Should burn NFT successfully when called by ClearingHouse", async function () {
      const initialBalance = await positionToken.balanceOf(user2.address);
      
      await positionToken.connect(clearingHouse).burn(2);

      expect(await positionToken.balanceOf(user2.address)).to.equal(initialBalance - 1n);
      
      await expect(
        positionToken.ownerOf(2)
      ).to.be.revertedWithCustomError(positionToken, "ERC721NonexistentToken");
    });

    it("Should burn multiple NFTs", async function () {
      await positionToken.connect(clearingHouse).burn(2);
      await positionToken.connect(clearingHouse).burn(3);

      expect(await positionToken.balanceOf(user2.address)).to.equal(0);
      
      await expect(positionToken.ownerOf(2)).to.be.revertedWithCustomError(positionToken, "ERC721NonexistentToken");
      await expect(positionToken.ownerOf(3)).to.be.revertedWithCustomError(positionToken, "ERC721NonexistentToken");
      
      // user1's token should still exist
      expect(await positionToken.ownerOf(1)).to.equal(user1.address);
    });

    it("Should revert if not called by ClearingHouse", async function () {
      await expect(
        positionToken.connect(user2).burn(2)
      ).to.be.revertedWith("PositionToken: Caller is not the ClearingHouse");
    });

    it("Should revert if token doesn't exist", async function () {
      await expect(
        positionToken.connect(clearingHouse).burn(999)
      ).to.be.revertedWithCustomError(positionToken, "ERC721NonexistentToken");
    });

    it("Should revert if token already burned", async function () {
      await positionToken.connect(clearingHouse).burn(2);
      
      await expect(
        positionToken.connect(clearingHouse).burn(2)
      ).to.be.revertedWithCustomError(positionToken, "ERC721NonexistentToken");
    });
  });

  describe("Standard ERC721 functionality", function () {
    beforeEach(async function () {
      await positionToken.connect(clearingHouse).mint(user1.address, 1);
      await positionToken.connect(clearingHouse).mint(user2.address, 2);
    });

    it("Should allow transfers", async function () {
      await positionToken.connect(user1).transferFrom(user1.address, user2.address, 1);
      
      expect(await positionToken.ownerOf(1)).to.equal(user2.address);
      expect(await positionToken.balanceOf(user1.address)).to.equal(0);
      expect(await positionToken.balanceOf(user2.address)).to.equal(2);
    });

    it("Should allow approvals", async function () {
      await positionToken.connect(user1).approve(user2.address, 1);
      
      expect(await positionToken.getApproved(1)).to.equal(user2.address);
      
      // user2 can now transfer the token
      await positionToken.connect(user2).transferFrom(user1.address, user2.address, 1);
      expect(await positionToken.ownerOf(1)).to.equal(user2.address);
    });

    it("Should allow setting approval for all", async function () {
      await positionToken.connect(user1).setApprovalForAll(user2.address, true);
      
      expect(await positionToken.isApprovedForAll(user1.address, user2.address)).to.be.true;
      
      // user2 can transfer any token owned by user1
      await positionToken.connect(user2).transferFrom(user1.address, user2.address, 1);
      expect(await positionToken.ownerOf(1)).to.equal(user2.address);
    });

    it("Should support ERC721 interface", async function () {
      // ERC721 interface ID
      const ERC721_INTERFACE_ID = "0x80ac58cd";
      expect(await positionToken.supportsInterface(ERC721_INTERFACE_ID)).to.be.true;
    });
  });

  describe("Edge cases", function () {
    it("Should handle tokenId 0", async function () {
      await positionToken.connect(clearingHouse).mint(user1.address, 0);
      expect(await positionToken.ownerOf(0)).to.equal(user1.address);
    });

    it("Should handle very large tokenId", async function () {
      const largeTokenId = ethers.MaxUint256;
      await positionToken.connect(clearingHouse).mint(user1.address, largeTokenId);
      expect(await positionToken.ownerOf(largeTokenId)).to.equal(user1.address);
    });

    it("Should maintain correct state after mint and burn cycle", async function () {
      // Mint
      await positionToken.connect(clearingHouse).mint(user1.address, 1);
      expect(await positionToken.balanceOf(user1.address)).to.equal(1);
      
      // Burn
      await positionToken.connect(clearingHouse).burn(1);
      expect(await positionToken.balanceOf(user1.address)).to.equal(0);
      
      // Mint same tokenId again
      await positionToken.connect(clearingHouse).mint(user2.address, 1);
      expect(await positionToken.ownerOf(1)).to.equal(user2.address);
      expect(await positionToken.balanceOf(user2.address)).to.equal(1);
    });

    it("Should handle rapid mint/burn operations", async function () {
      for (let i = 1; i <= 10; i++) {
        await positionToken.connect(clearingHouse).mint(user1.address, i);
        await positionToken.connect(clearingHouse).burn(i);
      }
      
      expect(await positionToken.balanceOf(user1.address)).to.equal(0);
    });
  });
}); 