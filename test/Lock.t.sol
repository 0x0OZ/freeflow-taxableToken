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

        assertEq(lock.areTokensLocked(user), false);
        lockTokens(user, amount);
        (uint256 lockedAmount, uint64 unlockTime) = lock.lockedBalances(user);
        assertEq(lockedAmount, amount);
        assertEq(unlockTime, uint64(block.timestamp + 1 days));
        assertEq(lock.areTokensLocked(user), true);


        assertEq(lock.areTokensLocked(anotherUser), false);
        lockTokens(anotherUser, amount);

        (lockedAmount, unlockTime) = lock.lockedBalances(anotherUser);
        assertEq(lockedAmount, amount);
        assertEq(unlockTime, uint64(block.timestamp + 1 days));
        assertEq(lock.areTokensLocked(anotherUser), true);
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
        // prepareLockTokens(user, lockAmount);
        vm.expectRevert(Lock.TokensAlreadyLocked.selector);
        lock.lockTokens(lockAmount, 1 days);
        vm.stopPrank();
    }

    function test_reLockTokens(uint lockAmount) public {
        lockAmount = bound(lockAmount, 1, 1e6);
        prepareLockTokens(user, lockAmount);
        assertEq(lock.areTokensLocked(user), false);
        vm.prank(user);
        lock.lockTokens(lockAmount, 1 days);
        assertEq(lock.areTokensLocked(user), true);
        // unlock first
        skip(1 days);
        assertEq(lock.areTokensLocked(user), false);
        //
        prepareLockTokens(user, lockAmount);
        vm.prank(user);
        lock.reLockTokens(lockAmount, 1 days);
        (uint256 lockedAmount, uint64 unlockTime) = lock.lockedBalances(user);
        assertEq(lockedAmount, lockAmount);
        assertEq(unlockTime, uint64(block.timestamp + 1 days));
        assertEq(lock.areTokensLocked(user), true);
    }

    function test_reLockTokensBeforeUnlockRevert() public {
        uint lockAmount = 1e2;
        console.log("time: ", block.timestamp);
        prepareLockTokens(user, lockAmount);
        vm.prank(user);
        lock.lockTokens(lockAmount, 7 days);

        (uint lockedAmount, uint64 unlockTime) = lock.lockedBalances(user);
        assertEq(lockedAmount, lockAmount);
        assertEq(unlockTime, uint64(block.timestamp + 7 days));

        prepareLockTokens(user, lockAmount);
        console.log("time: ", block.timestamp);
        vm.prank(user);
        vm.expectRevert(Lock.TokensStillLocked.selector);
        lock.reLockTokens(lockAmount, 7 days);
    }

    function test_reLockTokensWithDifferentAmount(uint lockAmount) public {
        lockAmount = bound(lockAmount, 1, 1e3);
        prepareLockTokens(user, lockAmount);
        vm.prank(user);
        lock.lockTokens(lockAmount, 1 days);
        // unlock first
        skip(1 days);
        //
        uint upperLockAmount = lockAmount ^ 2;
        prepareLockTokens(user, upperLockAmount);
        vm.prank(user);
        lock.reLockTokens(upperLockAmount, 1 days);
        (uint256 lockedAmount, uint64 unlockTime) = lock.lockedBalances(user);
        assertEq(lockedAmount, upperLockAmount);
        assertEq(unlockTime, uint64(block.timestamp + 1 days));

        uint lowerLockAmount = lockAmount / 2;
        if (lowerLockAmount == 0) lowerLockAmount = 1;

        skip(1 days);
        prepareLockTokens(user, lowerLockAmount);
        vm.prank(user);
        lock.reLockTokens(lowerLockAmount, 1 days);
    }

    function test_withdrawTokens(uint lockAmount) public {
        lockAmount = bound(lockAmount, 1, 1e3);
        lockTokens(user, lockAmount);
        (uint lockedAmount, uint64 unlockTime) = lock.lockedBalances(user);
        assertEq(unlockTime, uint64(block.timestamp + 1 days));
        assertEq(lockedAmount, lockAmount);

        // unlock first
        skip(1 days);
        //
        vm.prank(user);
        lock.withdraw();
        (lockedAmount, unlockTime) = lock.lockedBalances(user);
        assertEq(lockedAmount, 0);
        assertEq(unlockTime, 0);
    }
}
