import {
    time,
    loadFixture,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";

describe("Token", async function () {
    const owner = await (await ethers.provider.getSigner(0)).getAddress();
    const liquidityPool = await (await ethers.provider.getSigner(1)).getAddress();
    // exluded from tax
    const rewardPoolAddress = await (await ethers.provider.getSigner(2)).getAddress();
    const developmentPoolAddress = await (await ethers.provider.getSigner(3)).getAddress();
    const rewardPool = await (await ethers.provider.getSigner(2));
    const developmentPool = await (await ethers.provider.getSigner(3));

    const user1 = await (await ethers.provider.getSigner(5));
    const user2 = await (await ethers.provider.getSigner(4));
    const user1Address = await (await ethers.provider.getSigner(5)).getAddress();
    const user2Address = await (await ethers.provider.getSigner(4)).getAddress();
    const initSupply = 1000000;
    async function deployTokenFixture() {
        const Token = await ethers.getContractFactory("TaxableToken");
        const token = await Token.deploy(initSupply, rewardPoolAddress, developmentPoolAddress);
        await token.waitForDeployment();
        return { token };
    }
    describe("Deployment", function () {
        it("Should set the right owner", async function () {
            const { token } = await loadFixture(deployTokenFixture);
            expect(await token.owner()).to.equal(owner);
            expect(await token.rewardPool()).to.equal(rewardPoolAddress);
            expect(await token.developmentPool()).to.equal(developmentPoolAddress);

        });
    });
    describe("Transfer", function () {
        it("Normal transfers should take no tax", async function () {
            const { token } = await loadFixture(deployTokenFixture);
            let valueToTransfer = 100n * 10n ** 18n;
            await token.transfer(user1Address, valueToTransfer);
            expect(await token.balanceOf(user1Address)).to.equal(valueToTransfer);

            await token.connect(user1).transfer(user2Address, valueToTransfer);

            expect(await token.balanceOf(user1Address)).to.equal(0);
            expect(await token.balanceOf(user2Address)).to.equal(valueToTransfer);
            expect(await token.balanceOf(rewardPoolAddress)).to.equal(0);
            expect(await token.balanceOf(developmentPoolAddress)).to.equal(0);

            let ownerExpectedBal = (BigInt(initSupply) * 10n ** 18n) - BigInt(valueToTransfer);
            expect(await token.balanceOf(owner)).to.equal(ownerExpectedBal);
        });

        it("Buy/Sell should take tax of 4%", async function () {
            const { token } = await loadFixture(deployTokenFixture);
            await token.setLiquidityPool(liquidityPool);
            let valueToTransfer = 100n * 10n ** 18n;
            await token.transfer(user1Address, valueToTransfer)
            await token.connect(user1).transfer(liquidityPool, valueToTransfer);
            let expectedValueWithTax = valueToTransfer - (valueToTransfer * 4n / 100n);
            expect(await token.balanceOf(liquidityPool)).to.equal(expectedValueWithTax);
            expect(await token.balanceOf(user1Address)).to.equal(0);
            let tax = valueToTransfer * 2n / 100n;
            expect(await token.balanceOf(rewardPoolAddress)).to.equal(tax);
            expect(await token.balanceOf(developmentPoolAddress)).to.equal(tax);

        });
        it("Users can buy/sell 2% of total supply at max", async function () {
            const { token } = await loadFixture(deployTokenFixture);
            await token.setLiquidityPool(liquidityPool);
            let totalSupply = BigInt(initSupply) * 10n ** 18n;
            let valueToTransfer = totalSupply * 3n / 100n;
            await token.transfer(user1Address, valueToTransfer)
            await expect(token.connect(user1).transfer(liquidityPool, valueToTransfer)).to.be.reverted;
            valueToTransfer = totalSupply * 2n / 100n;
            // should not revert
            await expect(token.connect(user1).transfer(liquidityPool, valueToTransfer)).to.be.not.reverted;

        });
        it("Owner and tax address should be excluded from tax", async function () {
            const { token } = await loadFixture(deployTokenFixture);
            await token.setLiquidityPool(liquidityPool);
            let totalSupply = BigInt(initSupply) * 10n ** 18n;
            let valueToTransfer = totalSupply * 2n / 100n;
            await token.transfer(rewardPoolAddress, valueToTransfer)
            await token.transfer(developmentPoolAddress, valueToTransfer)

            await token.connect(rewardPool).transfer(liquidityPool, valueToTransfer);
            await token.connect(developmentPool).transfer(liquidityPool, valueToTransfer);
            expect(await token.balanceOf(liquidityPool)).to.equal(valueToTransfer * 2n);
            expect(await token.balanceOf(rewardPoolAddress)).to.equal(0);
            expect(await token.balanceOf(developmentPoolAddress)).to.equal(0);
            expect(await token.balanceOf(owner)).to.equal(BigInt(initSupply) * 10n ** 18n - valueToTransfer * 2n);

        })

    });
    describe("TransferFrom", function () {
        it("Normal transfers should take no tax", async function () {
            const { token } = await loadFixture(deployTokenFixture);
            let valueToTransfer = 100n * 10n ** 18n;
            await token.transfer(user1Address, valueToTransfer);
            expect(await token.balanceOf(user1Address)).to.equal(valueToTransfer);

            await token.connect(user1).approve(user2Address, valueToTransfer);
            await token.connect(user2).transferFrom(user1Address, user2Address, valueToTransfer);

            expect(await token.balanceOf(user1Address)).to.equal(0);
            expect(await token.balanceOf(user2Address)).to.equal(valueToTransfer);
            expect(await token.balanceOf(rewardPoolAddress)).to.equal(0);
            expect(await token.balanceOf(developmentPoolAddress)).to.equal(0);

            let ownerExpectedBal = (BigInt(initSupply) * 10n ** 18n) - BigInt(valueToTransfer);
            expect(await token.balanceOf(owner)).to.equal(ownerExpectedBal);
        });

        it("Buy/Sell should take tax of 4%", async function () {
            const { token } = await loadFixture(deployTokenFixture);
            await token.setLiquidityPool(liquidityPool);
            let valueToTransfer = 100n * 10n ** 18n;
            await token.transfer(user1Address, valueToTransfer)
            await token.connect(user1).approve(user2Address, valueToTransfer);
            await token.connect(user2).transferFrom(user1Address, liquidityPool, valueToTransfer);
            let expectedValueWithTax = valueToTransfer - (valueToTransfer * 4n / 100n);
            expect(await token.balanceOf(liquidityPool)).to.equal(expectedValueWithTax);
            expect(await token.balanceOf(user1Address)).to.equal(0);
            let tax = valueToTransfer * 2n / 100n;
            expect(await token.balanceOf(rewardPoolAddress)).to.equal(tax);
            expect(await token.balanceOf(developmentPoolAddress)).to.equal(tax);

        })

        it("Users can buy/sell 2% of total supply at max", async function () {
            const { token } = await loadFixture(deployTokenFixture);
            await token.setLiquidityPool(liquidityPool);
            let totalSupply = BigInt(initSupply) * 10n ** 18n;
            let valueToTransfer = totalSupply * 3n / 100n;
            await token.transfer(user1Address, valueToTransfer)
            await token.connect(user1).approve(user2Address, valueToTransfer);
            await expect(token.connect(user2).transferFrom(user1Address, liquidityPool, valueToTransfer)).to.be.reverted;
            valueToTransfer = totalSupply * 2n / 100n;
            // should not revert
            await expect(token.connect(user2).transferFrom(user1Address, liquidityPool, valueToTransfer)).to.be.not.reverted;

        })

        it("Owner and tax address should be excluded from tax", async function () {
            const { token } = await loadFixture(deployTokenFixture);
            await token.setLiquidityPool(liquidityPool);
            let totalSupply = BigInt(initSupply) * 10n ** 18n;
            let valueToTransfer = totalSupply * 2n / 100n;
            await token.transfer(rewardPoolAddress, valueToTransfer)
            await token.transfer(developmentPoolAddress, valueToTransfer)

            await token.connect(rewardPool).approve(user1Address, valueToTransfer);
            await token.connect(user1).transferFrom(rewardPoolAddress, liquidityPool, valueToTransfer);
            await token.connect(developmentPool).approve(user2Address, valueToTransfer);
            await token.connect(user2).transferFrom(developmentPoolAddress, liquidityPool, valueToTransfer);
            expect(await token.balanceOf(liquidityPool)).to.equal(valueToTransfer * 2n);
            expect(await token.balanceOf(rewardPoolAddress)).to.equal(0);
            expect(await token.balanceOf(developmentPoolAddress)).to.equal(0);
            expect(await token.balanceOf(owner)).to.equal(BigInt(initSupply) * 10n ** 18n - valueToTransfer * 2n);

        })
    });
    describe("Tax", function () {
        it("Tax should be 4%", async function () {
            const { token } = await loadFixture(deployTokenFixture);
            await token.setLiquidityPool(liquidityPool);
            let valueToTransfer = 100n * 10n ** 18n;
            await token.transfer(user1Address, valueToTransfer)
            await token.connect(user1).transfer(liquidityPool, valueToTransfer);
            let expectedValueWithTax = valueToTransfer - (valueToTransfer * 4n / 100n);
            expect(await token.balanceOf(liquidityPool)).to.equal(expectedValueWithTax);
            expect(await token.balanceOf(user1Address)).to.equal(0);
            let tax = valueToTransfer * 2n / 100n;
            expect(await token.balanceOf(rewardPoolAddress)).to.equal(tax);
            expect(await token.balanceOf(developmentPoolAddress)).to.equal(tax);

        })

        it("Should Update tax percentage correctly", async function () {
            const { token } = await loadFixture(deployTokenFixture);
            await token.setLiquidityPool(liquidityPool);
            await token.setTaxPercentage(8);
            let valueToTransfer = 100n * 10n ** 18n;
            await token.transfer(user1Address, valueToTransfer)
            await token.connect(user1).transfer(liquidityPool, valueToTransfer);
            let expectedValueWithTax = valueToTransfer - (valueToTransfer * 8n / 100n);
            expect(await token.balanceOf(liquidityPool)).to.equal(expectedValueWithTax);
            expect(await token.balanceOf(user1Address)).to.equal(0);
            let tax = valueToTransfer * 4n / 100n;
            expect(await token.balanceOf(rewardPoolAddress)).to.equal(tax);
            expect(await token.balanceOf(developmentPoolAddress)).to.equal(tax);
        });
        it("Should Update tax address correctly", async function () {
            const { token } = await loadFixture(deployTokenFixture);
            let liquidityPool = user2Address
            await token.setDevelopmentPool(developmentPoolAddress)
            await token.setRewardPool(rewardPoolAddress)
            await token.setLiquidityPool(user2Address);
            let valueToTransfer = 100n * 10n ** 18n;
            await token.transfer(user1Address, valueToTransfer)
            await token.connect(user1).transfer(user2Address, valueToTransfer);
            let expectedValueWithTax = valueToTransfer - (valueToTransfer * 4n / 100n);
            expect(await token.balanceOf(user2Address)).to.equal(expectedValueWithTax);
            expect(await token.balanceOf(user1Address)).to.equal(0);
            let tax = valueToTransfer * 2n / 100n;
            expect(await token.balanceOf(rewardPoolAddress)).to.equal(tax);
            expect(await token.balanceOf(developmentPoolAddress)).to.equal(tax);

            liquidityPool = user1Address;
            await token.setLiquidityPool(liquidityPool);
            valueToTransfer = 100n * 10n ** 18n;
            await token.transfer(user2Address, valueToTransfer)
            await token.connect(user2).transfer(liquidityPool, valueToTransfer);
            expectedValueWithTax = valueToTransfer - (valueToTransfer * 4n / 100n);
            expect(await token.balanceOf(liquidityPool)).to.equal(expectedValueWithTax);
            expect(await token.balanceOf(user2Address)).to.equal(expectedValueWithTax);
            tax += valueToTransfer * 2n / 100n;
            expect(await token.balanceOf(rewardPoolAddress)).to.equal(tax);
            expect(await token.balanceOf(developmentPoolAddress)).to.equal(tax);

        })
    })
    describe("Ownership", function () {
        it("OnlyOwner can transfer ownership", async function () {
            const { token } = await loadFixture(deployTokenFixture);
            await expect(token.connect(user1).transferOwnership(user2Address)).to.be.reverted;
            await token.transferOwnership(user2Address);
            expect(await token.owner()).to.equal(user2Address);
        });
    })

})