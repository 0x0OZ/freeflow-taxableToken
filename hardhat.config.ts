import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-foundry";
import "hardhat-preprocessor";
import "hardhat-gas-reporter"
import "@nomicfoundation/hardhat-verify";
import fs from "fs";
import dotenv from 'dotenv'
dotenv.config()

let coinmarketcap = process.env.COINMARKETCAP_API;
let sepolia_rpc = process.env.SEPOLIA_RPC_URL;
let private_key = process.env.PRIVATE_KEY || '';
let etherscan_apikey = process.env.ETHERSCAN_API_KEY || '';
let goerli_rpc = process.env.GOERLI_RPC_URL || '';
function getRemappings() {
  return fs
    .readFileSync("remappings.txt", "utf8")
    .split("\n")
    .filter(Boolean) // remove empty lines
    .map((line) => line.trim().split("="));
}

const config: HardhatUserConfig = {
  solidity: "0.8.21",
  networks: {
    sepolia: {
      url: sepolia_rpc,
      accounts: [private_key]
    },
    goerli: {
      url: goerli_rpc,
      accounts: [private_key]
    },
  },
  etherscan: {
    apiKey: {
      sepolia: etherscan_apikey,
      goerli: etherscan_apikey,
    }
  },
  preprocess: {
    eachLine: (hre) => ({
      transform: (line: string) => {
        if (line.match(/^\s*import /i)) {
          for (const [from, to] of getRemappings()) {
            if (line.includes(from)) {
              line = line.replace(from, to);
              break;
            }
          }
        }
        return line;
      },
    }),
  },
  paths: {
    sources: "./src",
    cache: "./cache_hardhat",
    tests: "./test",
  },
  gasReporter: {
    currency: 'USD',
    token: 'ETH',
    // gasPrice: 7,
    gasPriceApi: 'etherscan',
    enabled: true,
    coinmarketcap: coinmarketcap,
  },
};

export default config;
