import { ethers } from "hardhat";
async function main() {
  const [deployer] = await ethers.getSigners();
  const totalSupply = ethers.parseEther("1000000000");
  const rewardPoolAddress = await (await ethers.provider.getSigner(2)).getAddress();
  const developmentPoolAddress = (await (await ethers.provider.getSigner(3))).getAddress();

  const token = await ethers.deployContract("TaxableToken", [totalSupply, rewardPoolAddress, developmentPoolAddress]);

  await token.waitForDeployment();

  console.log("Token deployed to:", await token.getAddress());
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
