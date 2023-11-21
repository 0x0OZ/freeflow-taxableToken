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

    function checkAsserts(
        address wallet,
        uint amount,
        uint lockDuration,
        bool isLocked
    ) internal {
        checkAsserts(wallet, amount, lockDuration, isLocked, block.timestamp);
    }

    function checkAsserts(
        address wallet,
        uint amount,
        uint lockDuration,
        bool isLocked,
        uint timestamp
    ) internal {
        (uint256 lockedAmount, uint64 unlockTime) = lock.lockedBalances(wallet);
        assertEq(lockedAmount, amount);
        if (lockDuration == 0) assertEq(unlockTime, 0);
        else
            assertEq(
                unlockTime,
                convertToGMT0(uint64(timestamp + lockDuration))
            );
        assertEq(lock.areTokensLocked(wallet), isLocked);
    }

    function lockTokens(
        address wallet,
        uint amount,
        uint64 lockDuration
    ) internal {
        vm.prank(deployer);
        token.transfer(wallet, amount);
        vm.startPrank(wallet);
        token.approve(address(lock), amount);
        lock.lockTokens(amount, lockDuration);
        vm.stopPrank();
    }

    function reLockTokens(
        address wallet,
        uint amount,
        uint64 lockDuration
    ) internal {
        vm.prank(deployer);
        token.transfer(wallet, amount);
        vm.startPrank(wallet);
        token.approve(address(lock), amount);
        lock.reLockTokens(amount, lockDuration);
        vm.stopPrank();
    }

    function test_lockTokens(uint amount, uint64 lockDuration) public {
        amount = bound(amount, 1, 1e6);
        lockDuration = uint64(bound(lockDuration, 1 days, 31 days));

        checkAsserts(user, 0, 0, false);
        lockTokens(user, amount, lockDuration);
        checkAsserts(user, amount, lockDuration, true);
    }

    function test_lockZeroTokensRevert() public {
        vm.startPrank(user);
        vm.expectRevert(Lock.InvalidLockAmount.selector);
        lock.lockTokens(0, 1 days);
        vm.stopPrank();
    }

    function test_lockTokensTwiceRevert(
        uint lockAmount,
        uint64 lockDuration
    ) public {
        lockAmount = bound(lockAmount, 1, 1e3);
        lockDuration = uint64(bound(lockDuration, 1 days, 31 days));
        prepareLockTokens(user, lockAmount);
        vm.prank(user);
        lock.lockTokens(lockAmount, lockDuration);

        checkAsserts(user, lockAmount, lockDuration, true);

        prepareLockTokens(user, lockAmount);
        vm.prank(user);
        vm.expectRevert(Lock.TokensAlreadyLocked.selector);
        lock.lockTokens(lockAmount, lockDuration);
    }

    function test_reLockTokens(uint lockAmount, uint64 lockDuration) public {
        lockAmount = bound(lockAmount, 1, 1e6);
        lockDuration = uint64(bound(lockDuration, 1 days, 31 days));
        uint timestamp = block.timestamp;
        prepareLockTokens(user, lockAmount);
        checkAsserts(user, 0, 0, false);

        vm.prank(user);
        lock.lockTokens(lockAmount, lockDuration);
        checkAsserts(user, lockAmount, lockDuration, true);
        // unlock first
        skip(lockDuration);

        checkAsserts(user, lockAmount, lockDuration, false, timestamp);

        //
        prepareLockTokens(user, lockAmount);
        vm.prank(user);
        lock.reLockTokens(lockAmount, lockDuration);
        checkAsserts(user, lockAmount, lockDuration, true);
    }

    function test_reLockTokensBeforeUnlockRevert(uint64 lockDuration) public {
        uint lockAmount = 1e2;
        lockDuration = uint64(bound(lockDuration, 1 days, 31 days));

        lockTokens(user, lockAmount, lockDuration);
        checkAsserts(user, lockAmount, lockDuration, true);

        prepareLockTokens(user, lockAmount);
        vm.prank(user);
        vm.expectRevert(Lock.TokensStillLocked.selector);
        lock.reLockTokens(lockAmount, 7 days);
    }

    function test_reLockTokensWithDifferentAmount(
        uint lockAmount,
        uint64 lockDuration
    ) public {
        lockAmount = bound(lockAmount, 1, 1e3);
        lockDuration = uint64(bound(lockDuration, 1 days, 31 days));
        checkAsserts(user, 0, 0, false);

        lockTokens(user, lockAmount, lockDuration);
        checkAsserts(user, lockAmount, lockDuration, true);

        uint timestamp = block.timestamp;
        skip(lockDuration);
        checkAsserts(user, lockAmount, lockDuration, false, timestamp);

        reLockTokens(user, lockAmount * 2, lockDuration);
        checkAsserts(user, lockAmount * 2, lockDuration, true);

        timestamp = block.timestamp;
        skip(lockDuration);
        checkAsserts(user, lockAmount * 2, lockDuration, false, timestamp);

        uint lowerAmount = lockAmount / 2;
        if (lowerAmount == 0) lowerAmount = 1;
        reLockTokens(user, lowerAmount, lockDuration);
        checkAsserts(user, lowerAmount, lockDuration, true);
    }

    function test_withdrawTokens(uint lockAmount, uint64 lockDuration) public {
        lockAmount = bound(lockAmount, 1, 1e3);
        lockDuration = uint64(bound(lockDuration, 1 days, 31 days));
        lockTokens(user, lockAmount, lockDuration);
        (uint lockedAmount, uint64 unlockTime) = lock.lockedBalances(user);
        checkAsserts(user, lockAmount, lockDuration, true);

        // unlock first
        skip(lockDuration);
        //
        vm.prank(user);
        lock.withdraw();
        (lockedAmount, unlockTime) = lock.lockedBalances(user);
        checkAsserts(user, 0, 0, false);
    }

    function test_changeToken() public {
        address newToken = address(1);
        vm.prank(deployer);
        lock.changeToken(newToken);
    }
    function test_changeTokenRevert() public {
        address newToken = address(1);
        vm.prank(user);
        vm.expectRevert(Lock.UnauthorizedAccount.selector);
        lock.changeToken(newToken);
    }

    function test_transferOwnership() public {
        address newOwner = address(1);
        vm.prank(deployer);
        lock.transferOwnership(newOwner);
    }

    function test_transferOwnershipRevert() public {
        address newOwner = address(1);
        vm.prank(user);
        vm.expectRevert(Lock.UnauthorizedAccount.selector);
        lock.transferOwnership(newOwner);
    }

    function convertToGMT0(uint64 timestamp) internal pure returns (uint64) {
        unchecked {
            return timestamp - (timestamp % 1 days);
        }
    }
}
