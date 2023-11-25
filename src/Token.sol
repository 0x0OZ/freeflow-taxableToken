// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

// 4% buy/sell tax (half goes to onewallet, half to another)
// max buy/sell of 2% total supply
// ability to change ownership and addresses for tax
// owner address and tax addresses should be excluded from tax

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "src/interfaces/IUniswapV2Factory.sol";
import "src/interfaces/IUniswapV2Router02.sol";

contract TaxableToken is ERC20 {
    struct LockInfo {
        uint256 amount;
        uint64 unlockTime;
    }

    IUniswapV2Router02 internal constant router =
        IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

    // tax will be taken if luqidty pool is involved in the transfer
    address internal immutable liquidityPool;

    // Addresses for the reward and development pools.
    address internal rewardPool;
    address internal developmentPool;

    // Tax percentage on buy/sell transactions.
    uint32 internal taxPercentage;

    // Percentage of tax that goes to reward pool, remaining goes to development pool.
    uint32 internal rewardPoolSharesPercentage;

    // Maximum amount for buy/sell transactions.
    uint256 internal maxTxAmount;

    address internal owner;

    // mapping of addresses that are excluded from tax
    mapping(address => bool) internal isExcludedFromTax;

    event developmentPoolUpdated(address newDevelopmentPool);
    event taxPercentageUpdated(uint256 newTaxPercentage);
    event maxTxAmountUpdated(uint256 newMaxTxAmount);
    event rewardPoolUpdated(address newRewardPool);
    event ExcludeFromTax(address account, bool exclude);
    event TaxTransfer(address indexed from, address indexed to, uint256 amount);

    error TransferAmountExceedsMaxTxAmount();
    error UnauthorizedAccount();

    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert UnauthorizedAccount();
        }
        _;
    }

    modifier changeExcludedFromTax(address oldAddress, address newAddress) {
        isExcludedFromTax[oldAddress] = false;
        isExcludedFromTax[newAddress] = true;
        _;
    }

    /// @notice Initializes the contract with initial supply, reward pool and development pool addresses.
    /// @param _splitPercentage The initial tax split percentage.
    /// @param _taxPercentage The initial tax percentage.
    /// @param _rewardPool The address of the reward pool.
    /// @param _developmentPool The address of the development pool.
    constructor(
        uint32 _taxPercentage,
        uint32 _splitPercentage,
        address _rewardPool,
        address _developmentPool
    ) ERC20("TaxableToken", "TXB") {
        owner = msg.sender;

        taxPercentage = _taxPercentage;
        rewardPoolSharesPercentage = _splitPercentage;

        IUniswapV2Factory factory = IUniswapV2Factory(router.factory());
        address weth = router.WETH();
        address token0 = address(this) < weth ? address(this) : weth;
        address token1 = token0 == address(this) ? weth : address(this);
        liquidityPool = factory.createPair(token0, token1);

        // Minting initial total supply to the contract deployer.
        _mint(msg.sender, 1_000_000 * 10 ** decimals());

        maxTxAmount = (totalSupply() * 2) / 100;

        // Setting reward and development pool addresses.
        rewardPool = _rewardPool;
        developmentPool = _developmentPool;

        // setting excluded addresses
        isExcludedFromTax[_rewardPool] = true;
        isExcludedFromTax[_developmentPool] = true;
        isExcludedFromTax[msg.sender] = true;
        isExcludedFromTax[address(this)] = true;
    }

    /// @notice Changes the tax percentage, only callable by the contract owner.
    /// @param _taxPercentage The new tax percentage.
    function setTaxPercentage(uint32 _taxPercentage) external onlyOwner {
        taxPercentage = _taxPercentage;
        emit taxPercentageUpdated(_taxPercentage);
    }

    /// @notice Changes the maxTxAmount, only callable by the contract owner.
    /// @param maxTxAmountPercentage The new Percentage for Max Buy/Sell of totalSupply.
    function setMaxTxAmount(uint256 maxTxAmountPercentage) external onlyOwner {
        uint256 _maxTxAmount = (totalSupply() * maxTxAmountPercentage) / 100;
        maxTxAmount = _maxTxAmount;
        emit maxTxAmountUpdated(_maxTxAmount);
    }

    /// @notice Changes the split percentage, only callable by the contract owner.
    /// @param _splitPercentage The new split percentage.
    function setRewardPoolSharesPercentage(uint32 _splitPercentage) external onlyOwner {
        rewardPoolSharesPercentage = _splitPercentage;
    }

    /// @notice Changes the rewardPool address, only callable by the contract owner.
    /// @param newRewardPool The new address for the rewardPool.
    function setRewardPool(
        address newRewardPool
    ) external onlyOwner changeExcludedFromTax(rewardPool, newRewardPool) {
        rewardPool = newRewardPool;
        emit rewardPoolUpdated(newRewardPool);
    }

    /// @notice Changes the developmentPool address, only callable by the contract owner.
    /// @param newDevelopmentPool The new address for the developmentPool.
    function setDevelopmentPool(
        address newDevelopmentPool
    )
        external
        onlyOwner
        changeExcludedFromTax(developmentPool, newDevelopmentPool)
    {
        developmentPool = newDevelopmentPool;
        emit developmentPoolUpdated(newDevelopmentPool);
    }

    /// @notice Changes the excluded addresses, only callable by the contract owner.
    /// @param account The address to be excluded.
    /// @param exclude The boolean value indicating whether to exclude or not.
    function excludeFromTax(address account, bool exclude) external onlyOwner {
        isExcludedFromTax[account] = exclude;
        emit ExcludeFromTax(account, exclude);
    }

    /// @notice Changes the owner address, only callable by the contract owner.
    /// @param newOwner The address of the new owner.
    function transferOwnership(
        address newOwner
    ) external onlyOwner changeExcludedFromTax(owner, newOwner) {
        owner = newOwner;
    }

    /// @notice return if a user is excluded from tax.
    /// @param account The address to check if excluded.
    /// @return true of user is excluded from tax, false otherwise.
    function isUserExcludedFromTax(
        address account
    ) external view returns (bool) {
        return isExcludedFromTax[account];
    }

    /// @notice return the max transaction amount
    /// @return the max transaction amount
    function getMaxTxAmount() external view returns (uint256) {
        return maxTxAmount;
    }

    /// @return the addresses of the reward, development and liquidity pools.
    function getAddresses() external view returns (address, address, address) {
        return (rewardPool, developmentPool, liquidityPool);
    }

    /// @return the percentages of tax and reward pool shares.
    function getPercentages() external view returns (uint32, uint32) {
        return (taxPercentage, rewardPoolSharesPercentage);
    }

    /// @notice Overrides the _update function of ERC20 to include tax and maxTxAmount logic.
    /// @param from The address of the sender.
    /// @param to The address of the recipient.
    /// @param amount The amount of tokens to transfer.
    function _update(
        address from,
        address to,
        uint256 amount
    ) internal override {
        if (from != liquidityPool && to != liquidityPool) {
            super._update(from, to, amount);
        } else {
            if (!isExcludedFromTax[from] && !isExcludedFromTax[to]) {
                if (amount > maxTxAmount)
                    revert TransferAmountExceedsMaxTxAmount();

                (uint taxPercentage_, uint splitPercentage_) = (
                    taxPercentage,
                    (rewardPoolSharesPercentage)
                );
                
                uint256 taxAmount = (amount * taxPercentage_) / 100;
                unchecked {

                    uint splitAmount = (taxAmount * splitPercentage_) / 100;
                    uint taxForDevPool = taxAmount - splitAmount;
                    super._update(from, to, amount - taxAmount);
                    super._update(from, rewardPool, splitAmount);
                    super._update(
                        from,
                        developmentPool,
                        taxForDevPool
                    );
                    emit TaxTransfer(from, rewardPool , splitAmount);
                    emit TaxTransfer(from, developmentPool , taxForDevPool);
                }
            } else {
                super._update(from, to, amount);
            }
        }
    }
}
