// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "../src/Token.sol";

import "forge-std/Script.sol";
import "./interfaces/IUniswapV2Router02.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/weth.sol";

contract TokenScript is Script {
    TaxableToken token;
    address public rewardPool;
    address public developmentPool;
    address owner = address(0xCBB379347e5ABbfd2dAdB1C20A95d58275805C91);
    address user = address(0x3425523345);
    IUniswapV2Factory factory;
    IUniswapV2Router02 router;
    IUniswapV2Pair pair;
    address weth;
    WETH9 WETH;

    function setUp() public {
        rewardPool = address(0x555555555);
        developmentPool = address(0x11111111111);
        user = address(0x222222222222);
        console.log("token address: ");
        // token = TaxableToken(0x291fbB539e3C1f2aE264eC9A91A9d5d44515Fe80);
        vm.prank(owner);
        token = new TaxableToken(1_000_000_000 , rewardPool, developmentPool);
        owner = token.owner();
        factory = IUniswapV2Factory(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);
        router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // mainnet
        weth = 0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6; // goerli
        WETH = WETH9(payable(weth));
        WETH = WETH9(payable(router.WETH()));
    }

    function print() public view {
        console.log("balance of owner", token.balanceOf(owner));
        console.log("balance of user", token.balanceOf(user));
        console.log("balance of rewardPool", token.balanceOf(rewardPool));
        console.log("balance of developmentPool", token.balanceOf(developmentPool));
        console.log("total supply  :", token.totalSupply());
        console.log("tax percentage: ", token.taxPercentage());
        console.log("max tx amount", token.maxTxAmount());
        console.log("liquidity pool", token.liquidityPool());
        console.log("==========================================================\n");
    }

    function addLiquidity() public {
        // vm.startPrank(owner);
        uint256 wethAmount = 1e2 * 1e18;
        uint256 amountTokenDesired = token.balanceOf(owner);
        pair = IUniswapV2Pair(factory.createPair(address(token), weth));
        console.log("pair address: ", address(pair));
        console.log("token address: ", address(token));
        console.log("weth address: ", weth);
        vm.deal(owner, wethAmount);
        WETH.deposit{value: wethAmount}();
        WETH.approve(address(router), type(uint256).max);
        token.approve(address(router), type(uint256).max);
        uint256 amountADesired = amountTokenDesired;
        uint256 amountBDesired = wethAmount;
        uint256 amountAMin = 0;
        uint256 amountBMin = 0;
        address to = owner;
        uint256 deadline = block.timestamp + 100000000000;
        (uint256 reserveA, uint256 reserveB,) = pair.getReserves();
        console.log("reserves: ", reserveA, reserveB);
        router.addLiquidity(address(token), weth, amountADesired, amountBDesired, amountAMin, amountBMin, to, deadline);
        // pair = IUniswapV2Pair(factory.getPair(address(token), weth));
        (reserveA, reserveB,) = pair.getReserves();
        console.log("reserves: ", reserveA, reserveB);

        // pair = IUniswapV2Pair(factory.createPair(address(token), 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2));
        // token.setLiquidityPool(address(pair));

        // vm.stopPrank();
    }

    function run() public {
        console.log("is owner excludedfrom tax?: ", token.isExcludedFromTax(owner));
        console.log("owner : ", owner);
        print();
        vm.startPrank(owner);
        token.setLiquidityPool(address(0xCFfEEfeFeFFeeFEFFEefeFFEEFeFFeEFeFeeFfCc));
        addLiquidity();
        // token.transfer(user, 100000 * 10e18);
        // WETH.transfer(user, 100000 * 10e18);
        vm.stopPrank();

        // vm.startPrank(user);
        // // buy
        // uint256 amountIn = 100000 * 1e18;
        // WETH.approve(address(router), amountIn);
        // uint256 amountOutMin = 0;
        // address[] memory path = new address[](2);
        // path[0] = weth;
        // path[1] = address(token);
        // address to = user;
        // uint deadline = block.timestamp + 10000000;
        // router.swapExactTokensForTokens(amountIn, amountOutMin, path, to, deadline);
        // (uint reserveA, uint reserveB,) = pair.getReserves();
        // console.log("reserves: ", reserveA, reserveB);
        // // Sell will take fees
        // amountIn = (100000 / 2) * 1e18;
        // token.approve(address(router), amountIn);
        // amountOutMin = 0;
        // // address[] memory path = new address[](2);
        // path[0] = address(token);
        // path[1] = weth;
        // to = user;
        // deadline = block.timestamp + 10000000;
        // router.swapExactTokensForTokens(amountIn, amountOutMin, path, to, deadline);
        // // router.swapSin
        // vm.stopPrank();
        // (reserveA, reserveB,) = pair.getReserves();
        // console.log("reserves: ", reserveA, reserveB);
        // print();
    }
}
