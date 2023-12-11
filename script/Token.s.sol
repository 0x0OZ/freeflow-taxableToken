// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "../src/Token.sol";
import "forge-std/Script.sol";

// import "./interfaces/IUniswapV2Router02.sol";
// import "./interfaces/IUniswapV2Factory.sol";
import "src/interfaces/IUniswapV2Pair.sol";
import "src/interfaces/weth.sol";

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
        token = new TaxableToken(rewardPool, developmentPool);
        factory = IUniswapV2Factory(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);
        router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        weth = router.WETH();
        WETH = WETH9(payable(weth));
    }

    function print() public view {
        console.log("balance of owner", token.balanceOf(owner));
        console.log("balance of user ", token.balanceOf(user));
        // console.log("balance of rewardPool", token.balanceOf(rewardPool));
        // console.log(
        //     "balance of developmentPool",
        //     token.balanceOf(developmentPool)
        // );
        console.log(
            "token bal of token addr   ",
            token.balanceOf(address(token))
        );

        console.log("native balance of token  ", address(token).balance);
        console.log("native balance of rewpool", address(rewardPool).balance);
        console.log(
            "native balance of devpool",
            address(developmentPool).balance
        );

        console.log("total supply", token.totalSupply());
        console.log("collected taxes: ", token.balanceOf(address(token)));
        //console.log("tax percentage", token.getTaxPercentage());
        //console.log("max tx amount", token.getMaxTxAmount());
        console.log(
            "==========================================================\n"
        );
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
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amountIn,
            amountOutMin,
            path,
            to,
            deadline
        );
        (uint256 reserveA, uint256 reserveB, ) = pair.getReserves();
        console.log("reserves: ", reserveA, reserveB);
    }

    function addLiquidity(uint amountIn) public {
        vm.deal(owner, amountIn);
        WETH.deposit{value: amountIn}();
        WETH.approve(address(router), 1e64);
        token.approve(address(router), 1e64);
        uint256 amountADesired = amountIn;
        uint256 amountBDesired = amountIn;
        uint256 deadline = block.timestamp + 100000000000;
        (uint256 reserveA, uint256 reserveB, ) = pair.getReserves();
        console.log("reserves: ", reserveA, reserveB);
        router.addLiquidity(
            address(token),
            weth,
            amountADesired,
            amountBDesired,
            amountADesired, // min A
            amountBDesired, // min B
            owner,
            deadline
        );
        (reserveA, reserveB, ) = pair.getReserves();
        console.log("reserves: ", reserveA, reserveB);
        console.log("liquidity added");
    }

    function run() public {
        console.log(
            "is owner excludedfrom tax?: ",
            token.isUserExcludedFromTax(owner)
        );
        print();
        pair = IUniswapV2Pair(factory.getPair(address(token), weth));
        console.log("created liquidity pool: ", address(pair));
        uint bal = token.balanceOf(owner);
        uint amountIn = 1e3 * 1e18;

        vm.startPrank(owner);
        addLiquidity(bal);
        vm.stopPrank();

        vm.startPrank(user);
        // buy
        vm.deal(user, 1e9 * 1e18);
        WETH.deposit{value: 1e9 * 1e18}();
        amountIn = 1 * 1e18;
        WETH.approve(address(router), amountIn);
        uint256 amountOutMin = 0;
        address[] memory path = new address[](2);
        path[0] = weth;
        path[1] = address(token);
        address to = user;
        uint deadline = block.timestamp + 10000000;
        console.log("SWAPPING");
        console.log("router address: %s", address(router));
        console.log("weth address: %s", weth);
        console.log("token address: %s", address(token));
        console.log("router address: %s", address(router));
        console.log("swapTokensAtAmount: %s", token.swapTokensAtAmount());

        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amountIn / 2,
            amountOutMin,
            path,
            to,
            deadline
        );
        console.log("SWAPPED");
        (uint reserveA, uint reserveB, ) = pair.getReserves();
        console.log("reserves: ", reserveA, reserveB);
        amountIn = (10 / 2) * 1e18;
        token.approve(address(router), amountIn);
        amountOutMin = 0;
        path[0] = address(token);
        path[1] = weth;
        to = user;
        deadline = block.timestamp + 10000000;
        // router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
        //     amountIn,
        //     amountOutMin,
        //     path,
        //     to,
        //     deadline
        // );
        // // router.swapSin

        // buyToken(to, amountIn * 1e3);
        // buyToken(to, amountIn * 1e6);
        buyToken(to, 1e18 * 1e3);
        buyToken(to, 1e18 * 1e4);
        buyToken(to, 1e18 * 1e4);
        token.transfer(owner, 1e18 * 1e3);
        // buyToken(to, 1e18 * 1e6);
        // buyToken(to, 1e18 * 1e9);
        vm.stopPrank();
        (reserveA, reserveB, ) = pair.getReserves();
        console.log("reserves: ", reserveA, reserveB);

        print();
    }
}
