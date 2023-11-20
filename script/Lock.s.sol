// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {Lock} from "../src/Lock.sol";
import "../src/Token.sol";
import "forge-std/Script.sol";

// import "./interfaces/IUniswapV2Router02.sol";
// import "./interfaces/IUniswapV2Factory.sol";
import "src/interfaces/IUniswapV2Pair.sol";
import "src/interfaces/weth.sol";

contract LockScript is Script {
    TaxableToken token;
    Lock lock;

    address internal constant router =
        address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    address rewardPool = address(1337);
    address developmentPool = address(6666);

    address deployer = address(7);
    address user = address(8);
    address anotherUser = address(9);

    function setUp() public {
        vm.startBroadcast(deployer);
        token = new TaxableToken(4, 50, rewardPool, developmentPool);
        lock = new Lock(address(token));
        vm.stopBroadcast();
    }

    function lockTokens(address wallet, uint amount) internal {
        vm.broadcast(deployer);
        token.transfer(wallet, amount);
        vm.startBroadcast(wallet);
        token.approve(address(lock), amount);
        lock.lockTokens(amount, 1 days);
        vm.stopBroadcast();
    }

    function run() public {
        lockTokens(user, 1000);
        lockTokens(anotherUser, 1000);
    }
}
