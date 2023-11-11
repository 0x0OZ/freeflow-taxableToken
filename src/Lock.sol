// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);
}

contract TokenLockContract {
    address internal owner;
    IERC20 internal immutable tokenContract;

    struct LockInfo {
        uint256 amount;
        uint64 unlockTime;
    }

    mapping(address => LockInfo) public lockedBalances;

    constructor(address tokenAddress) {
        owner = msg.sender;
        tokenContract = IERC20(tokenAddress);
    }

    error lockDurationOutOfRange();
    error UnauthorizedAccount();
    error InvalidAmount();
    error tokensStillLocked();
    error noLockedTokens();

    // modifier onlyOwner() {
    //     if (msg.sender != owner) {
    //         revert UnauthorizedAccount();
    //     }
    //     _;
    // }

    function lockTokens(uint256 amount, uint64 lockDuration) external {
        if (amount == 0) revert lockDurationOutOfRange();
        if (lockDuration < 1 days || lockDuration > 31 days)
            revert lockDurationOutOfRange();

        LockInfo storage lockInfo = lockedBalances[msg.sender];

        if (lockInfo.amount > 0) revert lockDurationOutOfRange();

        // assumed that the tokenContract follows the the EIP specs
        tokenContract.transferFrom(msg.sender, address(this), amount);

        uint64 unlockTime = uint64(block.timestamp) + lockDuration;

        lockedBalances[msg.sender] = LockInfo(amount, unlockTime);
    }

    function reLockTokens(uint64 newLockDuration) external {
        if (newLockDuration < 1 days || newLockDuration > 31 days)
            revert lockDurationOutOfRange();

        LockInfo storage lockInfo = lockedBalances[msg.sender];

        if (lockInfo.amount == 0) revert noLockedTokens();

        lockInfo.unlockTime = uint64(block.timestamp) + newLockDuration;
    }

    function withdraw() external {
        LockInfo storage lockInfo = lockedBalances[msg.sender];

        if (block.timestamp < lockInfo.unlockTime) {
            revert tokensStillLocked();
        }

        uint256 amount = lockInfo.amount;
        lockInfo.amount = 0;
        lockInfo.unlockTime = 0;

        tokenContract.transfer(msg.sender, amount);
    }

    function areTokensLocked(address wallet) external view returns (bool) {
        LockInfo storage lockInfo = lockedBalances[wallet];

        return lockInfo.amount != 0 && lockInfo.unlockTime > block.timestamp;
    }

    // function transferOwnership(address _newOwner) external onlyOwner {
    //     owner = _newOwner;
    // }
}


