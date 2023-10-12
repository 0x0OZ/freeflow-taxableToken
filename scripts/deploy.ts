import { ethers } from "hardhat";
async function main() {
  const [deployer] = await ethers.getSigners();
  const totalSupply = 1000000000;
  const rewardPoolAddress = deployer.getAddress();
  const developmentPoolAddress = deployer.getAddress();

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
