// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

// 4% buy/sell tax (half goes to onewallet, half to another)
// max buy/sell of 2% total supply
// ability to change ownership and addresses for tax
// owner address and tax addresses should be excluded from tax

// Importing required contracts from OpenZeppelin library.
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TaxableToken is ERC20, Ownable {
    // Addresses for the reward and development pools.
    address public rewardPool;
    address public developmentPool;

    // Tax percentage on buy/sell transactions.
    uint256 public taxPercentage = 4;

    // Maximum amount for buy/sell transactions.
    uint256 public maxTxAmount;

    // tax will be taken if luqidty pool is involved in the transfer
    address public liquidityPool = address(0xdeadbeef);

    // mapping of addresses that are excluded from tax
    mapping(address => bool) public isExcludedFromTax;

    event taxPercentageUpdated(uint256 newTaxPercentage);
    event maxTxAmountUpdated(uint256 newMaxTxAmount);
    event rewardPoolUpdated(address newRewardPool);
    event developmentPoolUpdated(address newDevelopmentPool);
    event liquidityPoolUpdated(address newLiquidityPool);
    event ExcludeFromTax(address account, bool exclude);

    error TransferAmountExceedsMaxTxAmount();

    /// @notice Initializes the contract with initial supply, reward pool and development pool addresses.
    /// @param supply The initial total supply.
    /// @param _rewardPool The address of the reward pool.
    /// @param _developmentPool The address of the development pool.
    constructor(uint256 supply, address _rewardPool, address _developmentPool)
        ERC20("TaxableToken", "TXT")
        Ownable(msg.sender)
    {
        // Minting initial total supply to the contract deployer.
        _mint(msg.sender, supply * 10 ** decimals());

        maxTxAmount = totalSupply() * 2 / 100;

        // Setting reward and development pool addresses.
        rewardPool = _rewardPool;
        developmentPool = _developmentPool;

        // setting excluded addresses
        isExcludedFromTax[_rewardPool] = true;
        isExcludedFromTax[_developmentPool] = true;
        isExcludedFromTax[msg.sender] = true;
    }

    /// @notice Overrides the _update function of ERC20 to include tax and maxTxAmount logic.
    /// @param from The address of the sender.
    /// @param to The address of the recipient.
    /// @param amount The amount of tokens to transfer.
    function _update(address from, address to, uint256 amount) internal override {
        if (from != liquidityPool && to != liquidityPool) {
            super._update(from, to, amount);
        } else {
            if (!isExcludedFromTax[from]) {
                if (amount > maxTxAmount) revert TransferAmountExceedsMaxTxAmount();
                uint256 taxAmount = calculateTax(amount);
                unchecked {
                uint256 sendAmount = amount - taxAmount;
                super._update(from, to, sendAmount);
                }
                super._update(from, rewardPool, taxAmount / 2);
                super._update(from, developmentPool, taxAmount / 2);
            } else {
                super._update(from, to, amount);
            }
        }
    }

    /// @notice Calculates the tax amount based on the tax percentage.
    /// @param _amount The amount to calculate tax on.
    /// @return The tax amount.
    function calculateTax(uint256 _amount) internal view returns (uint256) {
        return (_amount * taxPercentage) / 100;
    }

    /// @notice Changes the tax percentage, only callable by the contract owner.
    /// @param _taxPercentage The new tax percentage.
    function setTaxPercentage(uint256 _taxPercentage) external onlyOwner {
        taxPercentage = _taxPercentage;
        emit taxPercentageUpdated(_taxPercentage);
    }

    /// @notice Changes the maxTxAmount, only callable by the contract owner.
    /// @param maxTxAmountPercentage The new Percentage for Max Buy/Sell of totalSupply.
    function setMaxTxAmount(uint256 maxTxAmountPercentage) external onlyOwner {
        uint256 _maxTxAmount = totalSupply() * maxTxAmountPercentage / 100;
        maxTxAmount = _maxTxAmount;
        emit maxTxAmountUpdated(_maxTxAmount);
    }

    /// @notice Changes the rewardPool address, only callable by the contract owner.
    /// @param newRewardPool The new address for the rewardPool.
    function setRewardPool(address newRewardPool) external onlyOwner {
        isExcludedFromTax[rewardPool] = false;
        isExcludedFromTax[newRewardPool] = true;
        rewardPool = newRewardPool;
        emit rewardPoolUpdated(newRewardPool);
    }

    /// @notice Changes the developmentPool address, only callable by the contract owner.
    /// @param newDevelopmentPool The new address for the developmentPool.
    function setDevelopmentPool(address newDevelopmentPool) external onlyOwner {
        isExcludedFromTax[developmentPool] = false;
        isExcludedFromTax[newDevelopmentPool] = true;
        developmentPool = newDevelopmentPool;
        emit developmentPoolUpdated(newDevelopmentPool);
    }

    /// @notice Changes the liquidityPool address, only callable by the contract owner.
    /// @param newLiquidityPool The new address for the liquidityPool.
    function setLiquidityPool(address newLiquidityPool) external onlyOwner {
        liquidityPool = newLiquidityPool;
        emit liquidityPoolUpdated(newLiquidityPool);
    }

    /// @notice Changes the excluded addresses, only callable by the contract owner.
    /// @param account The address to be excluded.
    /// @param exclude The boolean value indicating whether to exclude or not.
    function excludeFromTax(address account, bool exclude) external onlyOwner {
        isExcludedFromTax[account] = exclude;
        emit ExcludeFromTax(account, exclude);
    }

    /// @notice Overrides the transferOwnership function of Owned to include tax addresses.
    /// @param newOwner The address of the new owner.
    function transferOwnership(address newOwner) public override {
        isExcludedFromTax[owner()] = false;
        isExcludedFromTax[newOwner] = true;
        super.transferOwnership(newOwner);
    }
}
