// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice Simple constant-product AMM pool for two ERC20 tokens.
/// NOT audited. Educational use only.
contract SimplePool is ERC20 {
    IERC20 public token0;
    IERC20 public token1;

    uint112 private reserve0; // uses single-slot storage like Uniswap (not necessary but convenient)
    uint112 private reserve1;
    uint32  private blockTimestampLast;

    uint public constant FEE_NUM = 3; // 0.3% fee
    uint public constant FEE_DEN = 1000;

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(address indexed sender, uint amountIn, uint amountOut, address indexed tokenIn, address indexed tokenOut);
    event Sync(uint112 reserve0, uint112 reserve1);

    constructor(address _token0, address _token1, string memory lpName, string memory lpSymbol) ERC20(lpName, lpSymbol) {
        require(_token0 != _token1, "IDENTICAL_ADDRESSES");
        token0 = IERC20(_token0);
        token1 = IERC20(_token1);
    }

    // --- helpers ---
    function _update(uint balance0, uint balance1) private {
        require(balance0 <= type(uint112).max && balance1 <= type(uint112).max, "OVERFLOW");
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        blockTimestampLast = uint32(block.timestamp % 2**32);
        emit Sync(reserve0, reserve1);
    }

    // view reserves
    function getReserves() public view returns (uint112, uint112, uint32) {
        return (reserve0, reserve1, blockTimestampLast);
    }

    // --- liquidity management ---
    function mint(address to) external returns (uint liquidity) {
        uint balance0 = token0.balanceOf(address(this));
        uint balance1 = token1.balanceOf(address(this));
        uint amount0 = balance0 - reserve0;
        uint amount1 = balance1 - reserve1;

        if (totalSupply() == 0) {
            // initial liquidity: mint sqrt(amount0 * amount1) - MINIMUM
            liquidity = _sqrt(amount0 * amount1);
            // avoid zero liquidity
            require(liquidity > 0, "INSUFFICIENT_LIQUIDITY_MINTED");
            _mint(to, liquidity);
        } else {
            uint supply = totalSupply();
            uint liquidity0 = (amount0 * supply) / reserve0;
            uint liquidity1 = (amount1 * supply) / reserve1;
            liquidity = liquidity0 < liquidity1 ? liquidity0 : liquidity1;
            require(liquidity > 0, "INSUFFICIENT_LIQUIDITY_MINTED");
            _mint(to, liquidity);
        }

        _update(balance0, balance1);
        emit Mint(msg.sender, amount0, amount1);
    }

    function burn(address to) external returns (uint amount0, uint amount1) {
        uint balance0 = token0.balanceOf(address(this));
        uint balance1 = token1.balanceOf(address(this));
        uint liquidity = balanceOf(address(this));

        uint supply = totalSupply();
        require(supply > 0, "NO_LIQUIDITY");
        amount0 = (liquidity * balance0) / supply;
        amount1 = (liquidity * balance1) / supply;
        require(amount0 > 0 && amount1 > 0, "INSUFFICIENT_LIQUIDITY_BURNED");

        _burn(address(this), liquidity);
        // transfer underlying to `to`
        require(token0.transfer(to, amount0), "TRANSFER_FAILED0");
        require(token1.transfer(to, amount1), "TRANSFER_FAILED1");

        balance0 = token0.balanceOf(address(this));
        balance1 = token1.balanceOf(address(this));
        _update(balance0, balance1);

        emit Burn(msg.sender, amount0, amount1, to);
    }

    // --- swaps ---
    /// @notice swap exact input amount of tokenIn for tokenOut
    /// caller must have approved tokenIn to this contract
    function swap(address tokenIn, uint amountIn, address to) external returns (uint amountOut) {
        require(tokenIn == address(token0) || tokenIn == address(token1), "INVALID_TOKEN");
        require(amountIn > 0, "INSUFFICIENT_INPUT_AMOUNT");
        bool isToken0In = tokenIn == address(token0);
        IERC20 inToken = isToken0In ? token0 : token1;
        IERC20 outToken = isToken0In ? token1 : token0;

        // transfer in
        require(inToken.transferFrom(msg.sender, address(this), amountIn), "TRANSFER_IN_FAILED");

        // read balances after transfer
        uint balance0 = token0.balanceOf(address(this));
        uint balance1 = token1.balanceOf(address(this));

        // apply fee: amountInWithFee = amountIn * (FEE_DEN - FEE_NUM) / FEE_DEN
        uint amountInWithFee = (amountIn * (FEE_DEN - FEE_NUM)) / FEE_DEN;

        // reserves before this tx
        uint112 _reserve0 = reserve0;
        uint112 _reserve1 = reserve1;

        uint inReserve = isToken0In ? _reserve0 : _reserve1;
        uint outReserve = isToken0In ? _reserve1 : _reserve0;

        // formula: amountOut = (amountInWithFee * outReserve) / (inReserve + amountInWithFee)
        amountOut = (amountInWithFee * outReserve) / (inReserve + amountInWithFee);
        require(amountOut > 0, "INSUFFICIENT_OUTPUT_AMOUNT");

        // transfer out
        require(outToken.transfer(to, amountOut), "TRANSFER_OUT_FAILED");

        // final balances & update reserves
        uint finalBalance0 = token0.balanceOf(address(this));
        uint finalBalance1 = token1.balanceOf(address(this));
        _update(finalBalance0, finalBalance1);

        emit Swap(msg.sender, amountIn, amountOut, tokenIn, address(outToken));
    }

    // utility sqrt
    function _sqrt(uint y) internal pure returns (uint z) {
        if (y == 0) return 0;
        uint x = y / 2 + 1;
        z = y;
        while (x < z) {
            z = x;
            x = (y / x + x) / 2;
        }
    }

    // convenience: allow contract to receive ERC20s by direct transfers (no-op)
    receive() external payable {
        revert("NO_ETH");
    }
}
