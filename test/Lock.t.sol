// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Lock} from "../src/Lock.sol";
import "../src/Token.sol";
import "forge-std/Test.sol";

import "src/interfaces/IUniswapV2Pair.sol";
import "src/interfaces/weth.sol";

contract LockScript is Test {
    TaxableToken token;
    Lock lock;

    address internal constant router =
        address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    address rewardPool = address(1337);
    address developmentPool = address(6666);

    address deployer = address(7);
    address user = address(8);
    address anotherUser = address(9);

    error InvalidLockAmount();
    error TokensAlreadyLocked();

    function setUp() public {
        vm.startPrank(deployer);
        token = new TaxableToken(4, 1e6, rewardPool, developmentPool);
        lock = new Lock(address(token));
        vm.stopPrank();
    }

    function prepareLockTokens(address wallet, uint amount) internal {
        vm.prank(deployer);
        token.transfer(wallet, amount);
        vm.prank(wallet);
        token.approve(address(lock), amount);
    }

    function lockTokens(address wallet, uint amount) internal {
        vm.prank(deployer);
        token.transfer(wallet, amount);
        vm.startPrank(wallet);
        token.approve(address(lock), amount);
        lock.lockTokens(amount, 1 days);
        vm.stopPrank();
    }

    function test_lockTokens(uint amount) public {
        amount = bound(amount, 1, 1e6);
        lockTokens(user, amount);
        lockTokens(anotherUser, amount);
        (uint256 lockedAmount, uint64 unlockTime) = lock.lockedBalances(user);
        assertEq(lockedAmount, amount);
        assertEq(unlockTime, uint64(block.timestamp + 1 days));
        (lockedAmount, unlockTime) = lock.lockedBalances(anotherUser);
        assertEq(lockedAmount, amount);
        assertEq(unlockTime, uint64(block.timestamp + 1 days));
    }

    function test_lockZeroTokensRevert() public {
        vm.startPrank(user);
        token.approve(address(lock), 0);
        vm.expectRevert(Lock.InvalidLockAmount.selector);
        lock.lockTokens(0, 1 days);
        vm.stopPrank();
    }

    function test_lockTokensTwiceRevert(uint lockAmount) public {
        lockAmount = bound(lockAmount, 1, 1e3);
        prepareLockTokens(user, lockAmount);
        vm.startPrank(user);
        lock.lockTokens(lockAmount, 1 days);
        vm.expectRevert(Lock.TokensAlreadyLocked.selector);
        lock.lockTokens(lockAmount, 1 days);
        vm.stopPrank();
    }

    function test_lockTokensTwice(uint lockAmount) public {
        lockAmount = bound(lockAmount, 1, 1e3);
        prepareLockTokens(user, lockAmount);
        lock.lockTokens(lockAmount, 1 days);
        lock.lockTokens(lockAmount, 1 days);
        (uint256 lockedAmount, uint64 unlockTime) = lock.lockedBalances(user);
        assertEq(lockedAmount, lockAmount * 2);
        assertEq(unlockTime, uint64(block.timestamp + 1 days));
    }
}
