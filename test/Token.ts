import { expect } from 'chai';
import { ethers, hardhatArguments } from 'hardhat';
import hardhat from 'hardhat';
import { IUniswapV2Router02, TaxableToken, WETH9 } from '../typechain-types';

describe('Token', function () {
  let owner: any;
  let liquidityPool: any;
  let rewardPoolAddress: any;
  let developmentPoolAddress: any;
  let rewardPool: any;
  let developmentPool: any;
  let user1: any;
  let user2: any;
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
    console.log('weth: ', wethAddress);
    console.log('pair: ', pairAddress);
    return pairAddress;
  }
  async function addLiquidity(transferAmount: any) {
    // let transferAmount : any = ethers.parseEther('1')
    await weth.deposit({ value: transferAmount });
    await weth.approve(await router.getAddress(), transferAmount);
    await token.approve(await router.getAddress(), transferAmount);
    let timestamp = await ethers.provider
      .getBlock('latest')
      .then((b) => b?.timestamp);
    timestamp = timestamp === undefined ? 0 : timestamp;
    await router.addLiquidity(
      tokenAddress,
      wethAddress,
      transferAmount,
      transferAmount,
      transferAmount,
      transferAmount,
      owner,
      timestamp + 100000000
    );
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
    console.log('token: ', tokenAddress);
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
      let liquidityPool = await createPair();
      await token.setLiquidityPool(liquidityPool);
      let valueToTransfer = 10n * 10n ** 18n;
      console.log('transfering');
      await token.transfer(user1Address, valueToTransfer);
      await weth.deposit({ value: valueToTransfer });
      await weth.transfer(user1Address, valueToTransfer);
      console.log('approving router');
      await token
        .connect(user1)
        .approve(await router.getAddress(), valueToTransfer);
      await weth
        .connect(user1)
        .approve(await router.getAddress(), valueToTransfer);
      console.log('adding liquidity');
      let timestamp = await ethers.provider
        .getBlock('latest')
        .then((b) => b?.timestamp);
      timestamp = timestamp === undefined ? 0 : timestamp;
      await addLiquidity(valueToTransfer);
      valueToTransfer = ethers.parseEther('1');
      token.transfer(user1Address, valueToTransfer);
      await token.connect(user1).approve(await router.getAddress(), valueToTransfer);
      await weth.connect(user1).approve(await router.getAddress(), valueToTransfer);
      await weth.connect(user1).deposit({ value: valueToTransfer });
      await router.connect(user1).swapExactTokensForTokens(
        valueToTransfer,
        0,
        [wethAddress, tokenAddress],
        user1Address,
        timestamp + 100000000
      );      

      console.log('router: ', await router.getAddress());
      console.log('token: ', await token.getAddress());
      console.log('weth: ', await weth.getAddress());
      console.log('pair: ', liquidityPool);
      console.log('user1: ', user1Address);
      console.log('timestamp: ', timestamp);
      console.log('user token balance:', await token.balanceOf(user1Address));
      console.log('user weth balance :', await weth.balanceOf(user1Address));
      console.log('pair token balance:', await token.balanceOf(liquidityPool));
      console.log('pair weth balance :', await weth.balanceOf(liquidityPool));

      console.log('pair token balance:', await token.balanceOf(liquidityPool));
      console.log('pair weth balance :', await weth.balanceOf(liquidityPool));
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
