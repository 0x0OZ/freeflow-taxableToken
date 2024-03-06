// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "../src/Token.sol";
import "forge-std/Test.sol";

// import "./interfaces/IUniswapV2Router02.sol";
// import "./interfaces/IUniswapV2Factory.sol";
import "src/interfaces/IUniswapV2Pair.sol";
import "src/interfaces/weth.sol";

contract TokenTest is Test {
    TaxableToken token;
    address public rewardPool;
    address public developmentPool;
    address owner = address(0x1111111111);
    address user = address(0x77777777777);
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
        router = IUniswapV2Router02(0x98994a9A7a2570367554589189dC9772241650f6);
        factory = IUniswapV2Factory(0xb4A7D971D0ADea1c73198C97d7ab3f9CE4aaFA13);
        weth = router.WETH();
        WETH = WETH9(payable(weth));

        pair = IUniswapV2Pair(factory.getPair(address(token), weth));

        vm.stopPrank();
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        address path0,
        address path1,
        address to
    ) public {
        address[] memory path = new address[](2);
        path[0] = path0;
        path[1] = path1;
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amountIn,
            0,
            path,
            to,
            block.timestamp
        );
    }

    function buyToken(address to, uint256 amountIn) internal {
        vm.deal(to, amountIn);
        WETH.deposit{value: amountIn}();
        WETH.approve(address(router), amountIn);
        swapExactTokensForTokens(amountIn, weth, address(token), to);
    }

    function sellTokens(address to, uint256 amountIn) internal {
        token.approve(address(router), amountIn);
        console.log("selling");
        console.log("amountIn: ", amountIn);
        console.log("approve: ", token.allowance(to, address(router)));
        console.log("to: ", to);
        console.log("balance of to: ", token.balanceOf(to));
        swapExactTokensForTokens(amountIn, address(token), weth, to);
    }

    function addLiquidity(uint amountInA, uint amountInB) internal {
        vm.deal(owner, amountInB);
        WETH.deposit{value: amountInB}();
        WETH.approve(address(router), type(uint).max);
        token.approve(address(router), type(uint).max);

        router.addLiquidity(
            address(token),
            weth,
            amountInA,
            amountInB,
            amountInA, // min A
            amountInB, // min B
            owner,
            block.timestamp
        );
    }

    function addLiquidity() internal {
        uint amountInA = token.balanceOf(owner);
        uint amountInB = amountInA;
        addLiquidity(amountInA, amountInB);
    }

    function buyTokens(uint amountIn) internal {
        buyToken(user, amountIn);
    }

    function test_addLiquidity(uint amountA, uint amountB) public {
        uint ownerBalance = token.balanceOf(owner);
        amountA = bound(amountA, 1001, ownerBalance);
        amountB = bound(amountB, 1001, type(uint120).max / 1e4);
        console.log("amountA: ", amountA);
        console.log("amountB: ", amountB);
        vm.startPrank(owner);
        addLiquidity(amountA, amountB);
        vm.stopPrank();

        (uint256 reserveA, uint256 reserveB, ) = pair.getReserves();

        assertEq(token.balanceOf(owner), ownerBalance - amountA);
        assertEq(token.balanceOf(address(this)), 0);
        assertEq(token.balanceOf(address(pair)), amountA);
        assertEq(token.balanceOf(address(token)), 0);
        assertEq(token.balanceOf(address(rewardPool)), 0);
        assertEq(token.balanceOf(address(developmentPool)), 0);
        assertEq(reserveA, amountA);
        assertEq(reserveB, amountB);
    }

    function test_buyTokens(uint amountIn) public {
        vm.startPrank(owner);
        addLiquidity();
        vm.stopPrank();

        amountIn = bound(amountIn, 1000, token.balanceOf(address(pair)) / 50);

        (uint256 reserveA, uint256 reserveB, ) = pair.getReserves();

        vm.startPrank(user);
        buyToken(user, amountIn);
        vm.stopPrank();

        uint expectedAmountOut = router.getAmountOut(
            amountIn,
            reserveA,
            reserveB
        );
        // there is also a fee of 5% on the amountOut
        expectedAmountOut = expectedAmountOut - (expectedAmountOut * 5) / 100;
        assertEq(token.balanceOf(user), expectedAmountOut);
    }

    function test_sellTokens(uint amountIn) public {
        vm.startPrank(owner);
        addLiquidity();
        vm.stopPrank();

        amountIn = bound(amountIn, 1000, token.balanceOf(address(pair)) / 50);

        vm.startPrank(user);
        buyToken(user, amountIn);
        vm.stopPrank();

        amountIn = token.balanceOf(user);

        (uint256 reserveA, uint256 reserveB, ) = pair.getReserves();
        uint expectedAmountOut = router.getAmountOut(
            amountIn,
            reserveA,
            reserveB
        );
        // there is also a fee of 5% on the amountOut
        expectedAmountOut = (expectedAmountOut) - (expectedAmountOut * 5) / 100;

        vm.startPrank(user);
        sellTokens(user, amountIn);
        vm.stopPrank();

        uint userBal = WETH.balanceOf(user);
        assertEq(token.balanceOf(user), 0);

        // check that the user got the expected amount of WETH with a 0.02% margin of error
        uint margin = (expectedAmountOut / 10) * 10;
        assertEq(
            userBal >= expectedAmountOut - margin &&
                userBal <= expectedAmountOut + margin,
            true
        );
    }

    function test_taxCollected(uint amountIn) public {
        vm.startPrank(owner);
        addLiquidity();
        vm.stopPrank();

        uint amountInMin = 11_000 * 1e18;

        amountIn = bound(
            amountIn,
            amountInMin,
            token.balanceOf(address(pair)) / 50
        );

        vm.startPrank(user);
        buyToken(user, amountIn);
        token.transfer(owner, amountIn / 2);
        vm.stopPrank();

        uint rewPoolBal = address(rewardPool).balance;
        uint devPoolBal = address(developmentPool).balance;

        uint total = rewPoolBal + devPoolBal;
        // 60% of the tax should go to the reward pool
        uint rewPoolPercentage = 60;
        uint expectedRewPoolBal = (rewPoolBal * 100) / total;
        assertEq(
            rewPoolPercentage >= expectedRewPoolBal - 1 &&
                rewPoolPercentage <= expectedRewPoolBal + 1,
            true
        );
        // and 40% to the development pool
        uint devPoolPercentage = 40;
        uint expectedDevPoolBal = (devPoolBal * 100) / total;
        assertEq(
            devPoolPercentage >= expectedDevPoolBal - 1 &&
                devPoolPercentage <= expectedDevPoolBal + 1,
            true
        );
    }
}
