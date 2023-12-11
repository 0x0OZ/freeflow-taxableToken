// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

// 4% buy/sell tax (half goes to onewallet, half to another)
// max buy/sell of 2% total supply
// ability to change ownership and addresses for tax
// owner address and tax addresses should be excluded from tax

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "src/interfaces/IUniswapV2Factory.sol";
import "src/interfaces/IUniswapV2Router02.sol";

contract TaxableToken is ERC20, Ownable {
    struct LockInfo {
        uint256 amount;
        uint64 unlockTime;
    }
    // Tax percentage on buy/sell transactions.
    uint32 public constant taxPercentage = 5;

    // Percentage of tax that goes to reward pool, remaining goes to development pool.
    // 3% to reward pool, 2% to development pool
    uint32 public constant rewardPoolSharesPercentage = 3;

    IUniswapV2Router02 internal constant uniswapRouter =
        IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

    // tax will be taken if luqidty pool is involved in the transfer
    address public immutable liquidityPool;

    // Addresses for the reward and development pools.
    address public immutable rewardPool;
    address public immutable developmentPool;

    // Maximum amount for buy/sell transactions, 2% of total supply.
    uint256 public immutable maxTxAmount;

    // conditions to swap taxed tokens for ETH
    uint public immutable swapTokensAtAmount;
    bool internal swapping = true;

    address internal immutable weth;
    // mapping of addresses that are excluded from tax
    mapping(address => bool) internal isExcludedFromTax;

    event TaxTransfer(address indexed from, address indexed to, uint256 amount);
    event SwapBack(uint256 amount);

    error TransferAmountExceedsMaxTxAmount();
    error TransferTaxToPoolFailed();

    /// @notice Initializes the contract with initial supply, reward pool and development pool addresses.
    /// @param _rewardPool The address of the reward pool.
    /// @param _developmentPool The address of the development pool.
    constructor(
        address _rewardPool,
        address _developmentPool
    ) ERC20("TaxableToken", "TXB") Ownable(msg.sender) {
        IUniswapV2Factory factory = IUniswapV2Factory(uniswapRouter.factory());
        weth = uniswapRouter.WETH();
        address token0 = address(this) < weth ? address(this) : weth;
        address token1 = token0 == address(this) ? weth : address(this);
        liquidityPool = factory.createPair(token0, token1);

        _approve(address(this), address(uniswapRouter), type(uint256).max);

        uint totalSupply_ = 1_000_000 * 10 ** decimals();
        // Minting initial total supply to the contract deployer.
        _mint(msg.sender, totalSupply_);

        maxTxAmount = (totalSupply_ * 2) / 100;

        // Setting reward and development pool addresses.
        rewardPool = _rewardPool;
        developmentPool = _developmentPool;

        // setting excluded addresses
        isExcludedFromTax[_rewardPool] = true;
        isExcludedFromTax[_developmentPool] = true;
        isExcludedFromTax[msg.sender] = true;
        isExcludedFromTax[address(this)] = true;

        swapTokensAtAmount = (totalSupply_ * 5) / 10000;
        swapping = false;
    }

    // to receive ETH from uniswapV2Router when swapping
    receive() external payable {}

    /// @notice return if a user is excluded from tax.
    /// @param account The address to check if excluded.
    /// @return true of user is excluded from tax, false otherwise.
    function isUserExcludedFromTax(
        address account
    ) external view returns (bool) {
        return isExcludedFromTax[account];
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
        if ((from != liquidityPool && to != liquidityPool)) {
            super._update(from, to, amount);

            if (balanceOf(address(this)) >= swapTokensAtAmount && !swapping) {
                swapping = true;
                emit SwapBack(balanceOf(address(this)));
                swapBack();
                swapping = false;
            }
        } else {
            if (!isExcludedFromTax[from] && !isExcludedFromTax[to]) {
                if (amount > maxTxAmount)
                    revert TransferAmountExceedsMaxTxAmount();

                uint256 taxAmount = (amount * taxPercentage) / 100;
                unchecked {
                    super._update(from, to, amount - taxAmount);
                    super._update(from, address(this), taxAmount);

                    uint taxForRewardPool = getTokensForRewPool(taxAmount);
                    emit TaxTransfer(from, rewardPool, taxForRewardPool);
                    emit TaxTransfer(
                        from,
                        developmentPool,
                        taxAmount - taxForRewardPool
                    );
                }
            } else {
                super._update(from, to, amount);
            }
        }
    }

    /// @notice Swaps tokens for ETH and sends them to reward and development pools.
    /// @dev This function is called when the contract balance >= swapTokensAtAmount.
    function swapBack() internal {
        uint tokensToSwap = balanceOf(address(this));
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapRouter.WETH();

        uniswapRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokensToSwap,
            0,
            path,
            address(this),
            block.timestamp
        );

        unchecked {
            uint tokensForRewPool = getTokensForRewPool(tokensToSwap);

            // we don't confirm the call to avoid reverting

            (bool ok, ) = payable(rewardPool).call{value: tokensForRewPool}("");
            if (ok) {
                (ok, ) = payable(developmentPool).call{
                    value: tokensToSwap - tokensForRewPool
                }("");
            }
            if (!ok) revert TransferTaxToPoolFailed();
        }
    }

    function getTokensForRewPool(
        uint256 taxAmount
    ) public pure returns (uint256) {
        return (taxAmount * rewardPoolSharesPercentage) / 5;
    }
}
