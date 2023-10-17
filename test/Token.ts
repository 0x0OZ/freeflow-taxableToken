import { expect } from 'chai';
import { ethers, hardhatArguments } from 'hardhat';
import hardhat from 'hardhat';
import { IUniswapV2Router02, TaxableToken, WETH9 } from '../typechain-types';
import { HardhatEthersSigner } from '@nomicfoundation/hardhat-ethers/signers';

describe('Token', function () {
  let owner: any;
  let liquidityPool: any;
  let rewardPoolAddress: any;
  let developmentPoolAddress: any;
  let rewardPool: HardhatEthersSigner;
  let developmentPool: HardhatEthersSigner;
  let user1: HardhatEthersSigner;
  let user2: HardhatEthersSigner;
  let user1Address: string;
  let user2Address: string;
  const initSupply = 1000000;
  let token: TaxableToken;
  let tokenAddress: string;
  let wethAddress: string;
  let weth: WETH9;
  let router: IUniswapV2Router02;
  async function createPair() {
    const factory = await ethers.getContractAt(
      'IUniswapV2Factory',
      '0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f'
    );
    router = await ethers.getContractAt(
      'IUniswapV2Router02',
      '0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D'
    );
    wethAddress = await router.WETH();
    weth = await ethers.getContractAt('WETH9', wethAddress);

    let pairAddress = await factory.getPair(tokenAddress, wethAddress);
    if (pairAddress === ethers.ZeroAddress) {
      const tx = await factory.createPair(tokenAddress, wethAddress);
      await tx.wait();
      pairAddress = await factory.getPair(tokenAddress, wethAddress);
    }

    return pairAddress;
  }
  async function addLiquidity(wethAmount: any) {
    console.log("Adding liquidity : ", wethAmount)
    await printDetails();
    // let transferAmount : any = ethers.parseEther('1')
    let tokenAmount = await token.balanceOf(owner);
    await weth.deposit({ value: wethAmount });
    await weth.approve(await router.getAddress(), wethAmount);
    await token.approve(await router.getAddress(), tokenAmount);
    let timestamp = await ethers.provider
      .getBlock('latest')
      .then((b) => b?.timestamp);
    timestamp = timestamp === undefined ? 0 : timestamp;
    await router.addLiquidity(
      tokenAddress,
      wethAddress,
      tokenAmount,
      wethAmount,
      tokenAmount,
      wethAmount,
      owner,
      timestamp + 100000000
    );
    await printReserves();
  }
  async function printReserves() {
    const pair = await ethers.getContractAt('IUniswapV2Pair', liquidityPool);
    let reserves = await pair.getReserves();
    console.log('Reserves : ', reserves);
  }
  async function printDetails() {
    console.log("user1 token balance : ", await token.balanceOf(user1Address))
    console.log("user2 token balance : ", await token.balanceOf(user2Address))
    console.log("liquidity pool token balance : ", await token.balanceOf(liquidityPool))
    console.log("reward pool token balance : ", await token.balanceOf(rewardPoolAddress))
    console.log("development pool token balance : ", await token.balanceOf(developmentPoolAddress))
    console.log("owner token balance : ", await token.balanceOf(owner))
    console.log("user1 weth balance : ", await weth.balanceOf(user1Address))
    console.log("user2 weth balance : ", await weth.balanceOf(user2Address))
    console.log("liquidity pool weth balance : ", await weth.balanceOf(liquidityPool))
    console.log("reward pool weth balance : ", await weth.balanceOf(rewardPoolAddress))
    console.log("development pool weth balance : ", await weth.balanceOf(developmentPoolAddress))
    console.log("owner weth balance : ", await weth.balanceOf(owner))
    await printReserves();
    console.log("======================================================")
  }
  async function buyToken(user: HardhatEthersSigner, transferAmount: any) {
    // await token.excludeFromTax(await liquidityPool, true);
    console.log("Buying token : ", transferAmount)
    await printDetails();

    let userAddress = await user.getAddress();

    await weth.connect(user).deposit({ value: transferAmount });
    await weth.connect(user).approve(await router.getAddress(), transferAmount);
    await token.connect(user).approve(await router.getAddress(), transferAmount);

    console.log("transferAMount : ", transferAmount)
    let timestamp = await ethers.provider
      .getBlock('latest')
      .then((b) => b?.timestamp);
    timestamp = timestamp === undefined ? 0 : timestamp;
    let tx = await router.connect(user).swapExactTokensForTokensSupportingFeeOnTransferTokens(
      transferAmount,
      0,
      [wethAddress, tokenAddress],
      userAddress,
      timestamp + 100000000
    );
    await tx.wait();

    await printDetails();
  }
  beforeEach(async function () {
    [owner, liquidityPool, rewardPool, developmentPool, user1, user2] =
      await ethers.getSigners();
    rewardPoolAddress = rewardPool.address;
    developmentPoolAddress = developmentPool.address;
    user1Address = user1.address;
    user2Address = user2.address;
    const Token = await ethers.getContractFactory('TaxableToken');
    token = await Token.deploy(
      initSupply,
      rewardPoolAddress,
      developmentPoolAddress
    );
    await token.waitForDeployment();
    tokenAddress = await token.getAddress();
    liquidityPool = await createPair();
    return { token };
  });
  describe('Deployment', function () {
    it('Should set the right owner', async function () {
      expect(await token.owner()).to.equal(owner.address);
      expect(await token.rewardPool()).to.equal(rewardPoolAddress);
      expect(await token.developmentPool()).to.equal(developmentPoolAddress);
    });
  });
  describe('Transfer', function () {
    it('Normal transfers should take no tax', async function () {
      let valueToTransfer = ethers.parseEther('100');
      await token.transfer(user1Address, valueToTransfer);
      expect(await token.balanceOf(user1Address)).to.equal(valueToTransfer);

      await token.connect(user1).transfer(user2Address, valueToTransfer);

      expect(await token.balanceOf(user1Address)).to.equal(0);
      expect(await token.balanceOf(user2Address)).to.equal(valueToTransfer);
      expect(await token.balanceOf(rewardPoolAddress)).to.equal(0);
      expect(await token.balanceOf(developmentPoolAddress)).to.equal(0);

      let ownerExpectedBal =
        BigInt(initSupply) * 10n ** 18n - BigInt(valueToTransfer);
      expect(await token.balanceOf(owner)).to.equal(ownerExpectedBal);
    });

    it('Buy/Sell should take tax of 4% vessalius', async function () {
      await token.setLiquidityPool(liquidityPool);
      let valueToTransfer = 10n * 10n ** 18n;
      // token.excludeFromTax(await router.getAddress(), true);
      await addLiquidity(valueToTransfer);
      valueToTransfer = ethers.parseEther('1');
      await buyToken(user1, valueToTransfer);
      let expectedValueWithTax =
        valueToTransfer - (valueToTransfer * 4n) / 100n;
      console.log("user2Address balance : ", await token.balanceOf(user2Address))

      expect(await token.balanceOf(user2Address)).to.equal(expectedValueWithTax);
      let tax = (valueToTransfer * 2n) / 100n;
      expect(await token.balanceOf(rewardPoolAddress)).to.equal(tax);
      expect(await token.balanceOf(developmentPoolAddress)).to.equal(tax);
    });


    it('Users can buy/sell 2% of total supply at max', async function () {
      await token.setLiquidityPool(liquidityPool);
      let totalSupply = BigInt(initSupply) * 10n ** 18n;
      let valueToTransfer = (totalSupply * 3n) / 100n;
      await expect(
        token.connect(user1).transfer(liquidityPool, valueToTransfer)
      ).to.be.reverted;
      valueToTransfer = (totalSupply * 2n) / 100n;
      // should not revert
      await expect(
        token.connect(user1).transfer(liquidityPool, valueToTransfer)
      ).to.be.not.reverted;
    });
    it('Owner and tax address should be excluded from tax', async function () {
      await token.setLiquidityPool(liquidityPool);
      let totalSupply = BigInt(initSupply) * 10n ** 18n;
      let valueToTransfer = (totalSupply * 2n) / 100n;
      await token.transfer(rewardPoolAddress, valueToTransfer);
      await token.transfer(developmentPoolAddress, valueToTransfer);

      await token.connect(rewardPool).transfer(liquidityPool, valueToTransfer);
      await token
        .connect(developmentPool)
        .transfer(liquidityPool, valueToTransfer);
      expect(await token.balanceOf(liquidityPool)).to.equal(
        valueToTransfer * 2n
      );
      expect(await token.balanceOf(rewardPoolAddress)).to.equal(0);
      expect(await token.balanceOf(developmentPoolAddress)).to.equal(0);
      expect(await token.balanceOf(owner)).to.equal(
        BigInt(initSupply) * 10n ** 18n - valueToTransfer * 2n
      );
    });
  });
  describe('TransferFrom', function () {
    it('Normal transfers should take no tax', async function () {
      let valueToTransfer = 100n * 10n ** 18n;
      await token.transfer(user1Address, valueToTransfer);
      expect(await token.balanceOf(user1Address)).to.equal(valueToTransfer);

      await token.connect(user1).approve(user2Address, valueToTransfer);
      await token
        .connect(user2)
        .transferFrom(user1Address, user2Address, valueToTransfer);

      expect(await token.balanceOf(user1Address)).to.equal(0);
      expect(await token.balanceOf(user2Address)).to.equal(valueToTransfer);
      expect(await token.balanceOf(rewardPoolAddress)).to.equal(0);
      expect(await token.balanceOf(developmentPoolAddress)).to.equal(0);

      let ownerExpectedBal =
        BigInt(initSupply) * 10n ** 18n - BigInt(valueToTransfer);
      expect(await token.balanceOf(owner)).to.equal(ownerExpectedBal);
    });

    it('Buy/Sell should take tax of 4%', async function () {
      await token.setLiquidityPool(liquidityPool);
      let valueToTransfer = 100n * 10n ** 18n;
      await token.transfer(user1Address, valueToTransfer);
      await token.connect(user1).approve(user2Address, valueToTransfer);
      await token
        .connect(user2)
        .transferFrom(user1Address, liquidityPool, valueToTransfer);
      let expectedValueWithTax =
        valueToTransfer - (valueToTransfer * 4n) / 100n;
      expect(await token.balanceOf(liquidityPool)).to.equal(
        expectedValueWithTax
      );
      expect(await token.balanceOf(user1Address)).to.equal(0);
      let tax = (valueToTransfer * 2n) / 100n;
      expect(await token.balanceOf(rewardPoolAddress)).to.equal(tax);
      expect(await token.balanceOf(developmentPoolAddress)).to.equal(tax);
    });

    it('Users can buy/sell 2% of total supply at max', async function () {
      await token.setLiquidityPool(liquidityPool);
      let totalSupply = BigInt(initSupply) * 10n ** 18n;
      let valueToTransfer = (totalSupply * 3n) / 100n;
      await token.transfer(user1Address, valueToTransfer);
      await token.connect(user1).approve(user2Address, valueToTransfer);
      await expect(
        token
          .connect(user2)
          .transferFrom(user1Address, liquidityPool, valueToTransfer)
      ).to.be.reverted;
      valueToTransfer = (totalSupply * 2n) / 100n;
      // should not revert
      await expect(
        token
          .connect(user2)
          .transferFrom(user1Address, liquidityPool, valueToTransfer)
      ).to.be.not.reverted;
    });

    it('Owner and tax address should be excluded from tax', async function () {
      await token.setLiquidityPool(liquidityPool);
      let totalSupply = BigInt(initSupply) * 10n ** 18n;
      let valueToTransfer = (totalSupply * 2n) / 100n;
      await token.transfer(rewardPoolAddress, valueToTransfer);
      await token.transfer(developmentPoolAddress, valueToTransfer);

      await token.connect(rewardPool).approve(user1Address, valueToTransfer);
      await token
        .connect(user1)
        .transferFrom(rewardPoolAddress, liquidityPool, valueToTransfer);
      await token
        .connect(developmentPool)
        .approve(user2Address, valueToTransfer);
      await token
        .connect(user2)
        .transferFrom(developmentPoolAddress, liquidityPool, valueToTransfer);
      expect(await token.balanceOf(liquidityPool)).to.equal(
        valueToTransfer * 2n
      );
      expect(await token.balanceOf(rewardPoolAddress)).to.equal(0);
      expect(await token.balanceOf(developmentPoolAddress)).to.equal(0);
      expect(await token.balanceOf(owner)).to.equal(
        BigInt(initSupply) * 10n ** 18n - valueToTransfer * 2n
      );
    });
  });
  describe('Tax', function () {
    it('Tax should be 4%', async function () {
      await token.setLiquidityPool(liquidityPool);
      let valueToTransfer = 100n * 10n ** 18n;
      await token.transfer(user1Address, valueToTransfer);
      await token.connect(user1).transfer(liquidityPool, valueToTransfer);
      let expectedValueWithTax =
        valueToTransfer - (valueToTransfer * 4n) / 100n;
      expect(await token.balanceOf(liquidityPool)).to.equal(
        expectedValueWithTax
      );
      expect(await token.balanceOf(user1Address)).to.equal(0);
      let tax = (valueToTransfer * 2n) / 100n;
      expect(await token.balanceOf(rewardPoolAddress)).to.equal(tax);
      expect(await token.balanceOf(developmentPoolAddress)).to.equal(tax);
    });

    it('Should Update tax percentage correctly', async function () {
      await token.setLiquidityPool(liquidityPool);
      await token.setTaxPercentage(8);
      let valueToTransfer = 100n * 10n ** 18n;
      await token.transfer(user1Address, valueToTransfer);
      await token.connect(user1).transfer(liquidityPool, valueToTransfer);
      let expectedValueWithTax =
        valueToTransfer - (valueToTransfer * 8n) / 100n;
      expect(await token.balanceOf(liquidityPool)).to.equal(
        expectedValueWithTax
      );
      expect(await token.balanceOf(user1Address)).to.equal(0);
      let tax = (valueToTransfer * 4n) / 100n;
      expect(await token.balanceOf(rewardPoolAddress)).to.equal(tax);
      expect(await token.balanceOf(developmentPoolAddress)).to.equal(tax);
    });
    it('Should Update tax address correctly', async function () {
      let liquidityPool = user2Address;
      await token.setDevelopmentPool(developmentPoolAddress);
      await token.setRewardPool(rewardPoolAddress);
      await token.setLiquidityPool(user2Address);
      let valueToTransfer = 100n * 10n ** 18n;
      await token.transfer(user1Address, valueToTransfer);
      await token.connect(user1).transfer(user2Address, valueToTransfer);
      let expectedValueWithTax =
        valueToTransfer - (valueToTransfer * 4n) / 100n;
      expect(await token.balanceOf(user2Address)).to.equal(
        expectedValueWithTax
      );
      expect(await token.balanceOf(user1Address)).to.equal(0);
      let tax = (valueToTransfer * 2n) / 100n;
      expect(await token.balanceOf(rewardPoolAddress)).to.equal(tax);
      expect(await token.balanceOf(developmentPoolAddress)).to.equal(tax);

      liquidityPool = user1Address;
      await token.setLiquidityPool(liquidityPool);
      valueToTransfer = 100n * 10n ** 18n;
      await token.transfer(user2Address, valueToTransfer);
      await token.connect(user2).transfer(liquidityPool, valueToTransfer);
      expectedValueWithTax = valueToTransfer - (valueToTransfer * 4n) / 100n;
      expect(await token.balanceOf(liquidityPool)).to.equal(
        expectedValueWithTax
      );
      expect(await token.balanceOf(user2Address)).to.equal(
        expectedValueWithTax
      );
      tax += (valueToTransfer * 2n) / 100n;
      expect(await token.balanceOf(rewardPoolAddress)).to.equal(tax);
      expect(await token.balanceOf(developmentPoolAddress)).to.equal(tax);
    });
  });
  describe('Ownership', function () {
    it('OnlyOwner can transfer ownership', async function () {
      await expect(token.connect(user1).transferOwnership(user2Address)).to.be
        .reverted;
      await token.transferOwnership(user2Address);
      expect(await token.owner()).to.equal(user2Address);
    });
  });
});
