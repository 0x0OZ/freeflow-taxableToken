// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "../src/Token.sol";
import "forge-std/Script.sol";

contract TokenScript is Script {
    TaxableToken token;
    address public rewardPool;
    address public developmentPool;
    address owner;
    address user;

    function setUp() public {
        rewardPool = address(0x555555555);
        developmentPool = address(0x7593020593);
        user = address(0x3425523341);
        vm.prank(owner);
        token = new TaxableToken(100000000, rewardPool, developmentPool);
    }

    function print() public view {
        console.log("balance of owner", token.balanceOf(owner));
        console.log("balance of user", token.balanceOf(user));
        console.log("balance of rewardPool", token.balanceOf(rewardPool));
        console.log("balance of developmentPool", token.balanceOf(developmentPool));
        console.log("total supply", token.totalSupply());
        console.log("tax percentage", token.taxPercentage());
        console.log("max tx amount", token.maxTxAmount());
        console.log("liquidity pool", token.liquidityPool());
        console.log("==========================================================");
    }

    function run() public {
        console.log("owner excluded?: ", token.excludedFromTax(owner));
        print();
        // vm.startPrank(owner);
        vm.prank(owner);
        token.setLiquidityPool(address(0x3425523345));
        vm.prank(owner);
        token.transfer(user, 100000);
        vm.prank(user);
        token.transfer(address(0x3425523340), 10000);
        vm.prank(owner);
        token.transfer(address(0x3425523345), 10000);
        print();

        // user should have 100000 - 10000 = 90000
        // reward and dev pools should have 0
        // owner should have (100000000 * 10 ^ 18) - (100000 + 10000) = 99999999999999999999890000

        vm.prank(user);
        token.transfer(address(0x3425523345), 10000);
        print();
    }
}
