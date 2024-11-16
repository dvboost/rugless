import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import hre, { ethers } from "hardhat";

describe("RuglessLiquidityPool", function () {
  async function deployRuglessLiquidityPoolFixture() {
    const swapFeePercentage = 2;
    const unstakeFeePercentage = 5;
    const maxStakePercentageA = 50;

    const [owner, otherAccount] = await hre.ethers.getSigners();

    const RuglessLiquidityPool = await hre.ethers.getContractFactory(
      "RuglessLiquidityPool"
    );
    const Token = await hre.ethers.getContractFactory("Token");

    const tokenA = await Token.deploy(
      "TKA",
      "TKA",
      ethers.parseUnits("100000")
    );
    const tokenB = await Token.deploy(
      "TKB",
      "TKB",
      ethers.parseUnits("100000")
    );

    const tokenAddressA = await tokenA.getAddress();
    const tokenAddressB = await tokenB.getAddress();

    const liquidityPool = await RuglessLiquidityPool.deploy(
      tokenAddressA,
      tokenAddressB,
      swapFeePercentage,
      unstakeFeePercentage,
      maxStakePercentageA
    );

    const liquidityPoolAddress = await liquidityPool.getAddress();
    const stakingPoolAddress = await liquidityPool.stakingPool();

    const stakingPool = await hre.ethers.getContractAt(
      "RuglessStakingPool",
      stakingPoolAddress
    );

    const treasuryAddress = await stakingPool.feeRecipient();

    const treasury = await hre.ethers.getContractAt(
      "RuglessTreasury",
      treasuryAddress
    );

    await tokenA
      .connect(owner)
      .approve(liquidityPoolAddress, ethers.parseUnits("10000"));
    await tokenA
      .connect(owner)
      .approve(stakingPoolAddress, ethers.parseUnits("10000"));
    await tokenB
      .connect(owner)
      .approve(liquidityPoolAddress, ethers.parseUnits("10000"));
    await tokenB
      .connect(owner)
      .approve(stakingPoolAddress, ethers.parseUnits("10000"));

    await tokenA
      .connect(owner)
      .transfer(otherAccount.address, ethers.parseUnits("100"));
    await tokenB
      .connect(owner)
      .transfer(otherAccount.address, ethers.parseUnits("100"));

    await liquidityPool
      .connect(owner)
      .addLiquidity(ethers.parseUnits("1500"), ethers.parseUnits("1000"));

    return {
      liquidityPool,
      owner,
      otherAccount,
      tokenA,
      tokenB,
      tokenAddressA,
      tokenAddressB,
      liquidityPoolAddress,
      stakingPoolAddress,
      stakingPool,
      treasuryAddress,
      treasury,
    };
  }

  describe("Deployment", function () {
    it("Should set the correct token addresses", async function () {
      const { liquidityPool, tokenAddressA, tokenAddressB } = await loadFixture(
        deployRuglessLiquidityPoolFixture
      );
      expect(await liquidityPool.tokenA()).to.equal(tokenAddressA);
      expect(await liquidityPool.tokenB()).to.equal(tokenAddressB);
    });
  });

  describe("Swapping Tokens", function () {
    it("Should swap Token B for Token A without staking successfully", async function () {
      const { liquidityPool, liquidityPoolAddress, tokenB, otherAccount } =
        await loadFixture(deployRuglessLiquidityPoolFixture);

      const swapAmount = ethers.parseEther("10");
      const minAmountA = ethers.parseEther("5");

      await tokenB
        .connect(otherAccount)
        .approve(liquidityPoolAddress, swapAmount);

      await expect(
        liquidityPool
          .connect(otherAccount)
          .swapBForA(swapAmount, minAmountA, false)
      )
        .to.emit(liquidityPool, "SwapBForA")
        .withArgs(otherAccount.address, swapAmount, anyValue, anyValue);

      expect(await liquidityPool.reserveB()).to.equal(
        ethers.parseEther("1010")
      );
    });

    it("Should swap Token B for Token A with staking successfully", async function () {
      const {
        liquidityPool,
        stakingPoolAddress,
        stakingPool,
        tokenA,
        tokenB,
        otherAccount,
        treasury,
      } = await loadFixture(deployRuglessLiquidityPoolFixture);

      const swapAmountA = ethers.parseEther("15");
      const swapAmountB = ethers.parseEther("10");
      const minAmountA = ethers.parseEther("5");

      await tokenA
        .connect(otherAccount)
        .approve(stakingPoolAddress, swapAmountA);

      await tokenB
        .connect(otherAccount)
        .approve(stakingPoolAddress, swapAmountB);

      await liquidityPool
        .connect(otherAccount)
        .swapBForA(swapAmountB, minAmountA, true);

      expect(
        (await stakingPool.getStakedBalance(otherAccount.address)).amountB
      ).to.equal(ethers.parseEther("10"));
      expect(await tokenB.balanceOf(otherAccount)).to.equal(
        ethers.parseEther("90")
      );
      expect(await tokenB.balanceOf(stakingPool)).to.equal(
        ethers.parseEther("10")
      );
      expect(await liquidityPool.totalReserveB()).to.equal(
        ethers.parseEther("1010")
      );
      expect(await liquidityPool.reserveB()).to.equal(
        ethers.parseEther("1000")
      );

      await stakingPool.connect(otherAccount).unstake();

      const treasuryBalance = await tokenA.balanceOf(treasury);
      console.log(
        "Treasury balance of token A after unstake:",
        ethers.formatUnits(treasuryBalance)
      );
      expect(await tokenA.balanceOf(treasury)).to.be.greaterThan(0);
      expect(await tokenB.balanceOf(treasury)).to.equal(0);
    });
  });
});
