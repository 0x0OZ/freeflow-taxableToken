// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

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

contract Lock {
    address internal owner;
    IERC20 internal tokenContract;

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
    error InvalidLockAmount();
    error tokensStillLocked();
    error TokensAlreadyLocked();

    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert UnauthorizedAccount();
        }
        _;
    }

    /// @notice Locks tokens for a specified duration
    /// @param amount The amount of tokens to lock
    /// @param lockDuration The duration to lock the tokens for
    /// @dev The lock duration must be between 1 and 31 days
    /// @dev The amount of tokens must be greater than 0
    /// @dev The user must not have any tokens locked already
    /// @dev The user must have approved the contract to transfer the tokens
    function lockTokens(uint256 amount, uint64 lockDuration) external {
        if (amount == 0) revert InvalidLockAmount();

        if (lockDuration < 1 days || lockDuration > 31 days)
            revert lockDurationOutOfRange();

        if (lockedBalances[msg.sender].amount > 0) revert TokensAlreadyLocked();

        // assumed that the tokenContract follows the the EIP specs
        tokenContract.transferFrom(msg.sender, address(this), amount);

        uint64 unlockTime = uint64(block.timestamp) + lockDuration;

        lockedBalances[msg.sender] = LockInfo(amount, unlockTime);
    }

    // do the checks on lock durations that are done on the lock
    /// @notice Locks tokens for a specified duration
    /// @param newLockAmount The amount of tokens to lock
    /// @param newLockDuration The duration to lock the tokens for
    /// @dev The lock duration must be between 1 and 31 days
    /// @dev The amount of tokens must be greater than 0
    /// @dev The user must have tokens locked already
    /// @dev The user must have approved the contract to transfer the tokens
    /// @dev If the new lock amount is greater than the current lock amount, the difference will be transferred from the user to the contract
    /// @dev If the new lock amount is less than the current lock amount, the difference will be transferred from the contract to the user
    function reLockTokens(uint newLockAmount, uint64 newLockDuration) external {
        if (newLockDuration < 1 days || newLockDuration > 31 days)
            revert lockDurationOutOfRange();

        LockInfo memory lockInfo = lockedBalances[msg.sender];

        if (newLockAmount > lockInfo.amount) {
            unchecked {
                uint transferAmount = newLockAmount - lockInfo.amount;
                tokenContract.transferFrom(
                    msg.sender,
                    address(this),
                    transferAmount
                );
            }
        } else if (newLockAmount < lockInfo.amount) {
            unchecked {
                uint transferAmount = lockInfo.amount - newLockAmount;
                tokenContract.transfer(msg.sender, transferAmount);
            }
        }

        lockedBalances[msg.sender] = LockInfo(
            newLockAmount,
            uint64(block.timestamp) + newLockDuration
        );
    }

    /// @notice Withdraws tokens that have been unlocked
    /// @dev The user must have tokens locked already
    /// @dev The unlock time must be less than the current block timestamp
    function withdraw() external {
        LockInfo memory lockInfo = lockedBalances[msg.sender];

        if (block.timestamp < lockInfo.unlockTime) revert tokensStillLocked();

        delete lockedBalances[msg.sender];

        tokenContract.transfer(msg.sender, lockInfo.amount);
    }

    /// @notice Changes the token contract
    /// @param newToken The address of the new token contract
    /// @dev Only the owner can call this function
    function changeToken(address newToken) external onlyOwner {
        tokenContract = IERC20(newToken);
    }

    /// @notice Returns whether or not the user has tokens locked
    /// @param wallet The address of the user
    /// @return true if the user has tokens locked, false otherwise
    function areTokensLocked(address wallet) external view returns (bool) {
        LockInfo storage lockInfo = lockedBalances[wallet];

        return lockInfo.amount != 0 && lockInfo.unlockTime > block.timestamp;
    }

    /// @notice changes the owner address
    /// @param _newOwner The address of the new owner
    /// @dev Only the owner can call this function
    function transferOwnership(address _newOwner) external onlyOwner {
        owner = _newOwner;
    }
}
