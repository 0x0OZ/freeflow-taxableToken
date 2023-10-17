import { ethers } from "hardhat";
async function main() {
    const [deployer, user1] = await ethers.getSigners();
    const totalSupply = 1000000;
    const rewardPoolAddress = deployer.getAddress();
    const developmentPoolAddress = deployer.getAddress();

    let token = await ethers.deployContract("TaxableToken", [totalSupply, rewardPoolAddress, developmentPoolAddress]);

    await token.waitForDeployment();
    let factory = await ethers.getContractAt("IUniswapV2Factory", "0x5c69bee701ef814a2b6a3edd4b1652cb9cc5aa6f");
    await factory.createPair(await token.getAddress(), "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2");
    let router = await ethers.getContractAt("IUniswapV2Router02", "0x7a250d5630b4cf539739df2c5dacb4c659f2488d");
    let transferAmount = ethers.parseEther("10");
    console.log("transfer amount: ", transferAmount);
    await token.approve(await router.getAddress(), transferAmount);
    let wethAddress = await router.WETH();
    let weth = await ethers.getContractAt("WETH9", wethAddress);
    console.log("owner weth balance before: ", await weth.balanceOf(await deployer.getAddress()));
    await weth.deposit({ value: transferAmount });
    await weth.approve(await router.getAddress(), transferAmount);
    let timestamp = await ethers.provider
        .getBlock('latest')
        .then((b) => b?.timestamp);
    timestamp = timestamp === undefined ? 0 : timestamp;
    timestamp = timestamp + 1000000;
    console.log("owner token balance: ", await token.balanceOf(await deployer.getAddress()));
    console.log("owner weth balance: ", await weth.balanceOf(await deployer.getAddress()));
    await router.addLiquidity(await token.getAddress(), wethAddress, transferAmount, transferAmount, transferAmount, transferAmount, await deployer.getAddress(), timestamp);
    transferAmount = ethers.parseEther("1");
    await token.transfer(user1.getAddress(), transferAmount);
    await weth.deposit({ value: transferAmount });
    await weth.transfer(user1.getAddress(), transferAmount);
    await token.connect(user1).approve(await router.getAddress(), transferAmount);
    await weth.connect(user1).approve(await router.getAddress(), transferAmount);
    console.log("liquidity token balance: ", await token.balanceOf(await deployer.getAddress()));
    console.log("liquidity weth balance: ", await weth.balanceOf(await deployer.getAddress()));
    console.log(`user1 balance: ${await token.balanceOf(user1.getAddress())}`)
    console.log(`user1 weth balance: ${await weth.balanceOf(user1.getAddress())}`)
    await router.connect(user1).swapExactTokensForTokens(transferAmount, 0, [wethAddress,await token.getAddress()], user1.getAddress(), timestamp);
    console.log(`user1 balance: ${await token.balanceOf(user1.getAddress())}`)
    console.log(`user1 weth balance: ${await weth.balanceOf(user1.getAddress())}`)
    console.log("liquidity token balance: ", await token.balanceOf(await deployer.getAddress()));
    console.log("liquidity weth balance: ", await weth.balanceOf(await deployer.getAddress()));

    console.log("Token deployed to:", await token.getAddress());
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});

