// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "../src/Token.sol";
import "forge-std/Script.sol";

// import "./interfaces/IUniswapV2Router02.sol";
// import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/weth.sol";

contract TokenScript is Script {
    TaxableToken token;
    address public rewardPool;
    address public developmentPool;
    address owner = address(0x3425523340);
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
        vm.prank(owner);
        token = new TaxableToken(100_000_0000, rewardPool, developmentPool);
        factory = IUniswapV2Factory(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);
        router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        weth = router.WETH();
        WETH = WETH9(payable(weth));
    }

    function print() public view {
        console.log("balance of owner", token.balanceOf(owner));
        console.log("balance of user", token.balanceOf(user));
        console.log("balance of rewardPool", token.balanceOf(rewardPool));
        console.log("balance of developmentPool", token.balanceOf(developmentPool));
        console.log("total supply", token.totalSupply());
        console.log("tax percentage", token.getTaxPercentage());
        console.log("max tx amount", token.getMaxTxAmount());
        console.log("==========================================================\n");
    }

    function buyToken(address to, uint256 amountIn) public {
        vm.deal(to, amountIn);
        WETH.deposit{value: amountIn}();
        WETH.approve(address(router), amountIn);
        uint256 amountOutMin = 0;
        address[] memory path = new address[](2);
        path[0] = weth;
        path[1] = address(token);
        uint256 deadline = block.timestamp + 10000000;
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(amountIn, amountOutMin, path, to, deadline);
        (uint256 reserveA, uint256 reserveB,) = pair.getReserves();
        console.log("reserves: ", reserveA, reserveB);
    }

    function run() public {
        console.log("is owner excludedfrom tax?: ", token.isUserExcludedFromTax(owner));
        print();
        vm.startPrank(owner);
        pair = IUniswapV2Pair(factory.getPair(address(token), weth));
        console.log("created liquidity pool: ", address(pair));

        vm.deal(owner, 1e9 * 1e18);
        WETH.deposit{value: 1e9 * 1e18}();
        WETH.approve(address(router), 1e64);
        token.approve(address(router), 1e64);
        uint256 amountADesired = 1e6 * 1e18;
        uint256 amountBDesired = 1e6 * 1e18;
        uint256 amountAMin = 1e6 * 1e18;
        uint256 amountBMin = 1e6 * 1e18;
        address to = owner;
        uint256 deadline = block.timestamp + 100000000000;
        (uint256 reserveA, uint256 reserveB,) = pair.getReserves();
        console.log("reserves: ", reserveA, reserveB);
        router.addLiquidity(address(token), weth, amountADesired, amountBDesired, amountAMin, amountBMin, to, deadline);
        (reserveA, reserveB,) = pair.getReserves();
        console.log("reserves: ", reserveA, reserveB);

        // token.setLiquidityPool(address(pair));
        token.transfer(user, 100000 * 10e18);
        WETH.transfer(user, 100000 * 10e18);
        vm.stopPrank();

        vm.startPrank(user);
        // buy
        uint256 amountIn = 100000 * 1e18;
        WETH.approve(address(router), amountIn);
        uint256 amountOutMin = 0;
        address[] memory path = new address[](2);
        path[0] = weth;
        path[1] = address(token);
        to = user;
        deadline = block.timestamp + 10000000;
        console.log("SWAPPING");
        console.log("router address: %s", address(router));

        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(amountIn, amountOutMin, path, to, deadline);
        console.log("SWAPPED");
        (reserveA, reserveB,) = pair.getReserves();
        console.log("reserves: ", reserveA, reserveB);
        amountIn = (100000 / 2) * 1e18;
        token.approve(address(router), amountIn);
        amountOutMin = 0;
        path[0] = address(token);
        path[1] = weth;
        to = user;
        deadline = block.timestamp + 10000000;
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(amountIn, amountOutMin, path, to, deadline);
        // router.swapSin
        vm.stopPrank();
        (reserveA, reserveB,) = pair.getReserves();
        console.log("reserves: ", reserveA, reserveB);
        print();
    }
}
