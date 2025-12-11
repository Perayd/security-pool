// snippet: swap 10 tokenA -> tokenB
const amountIn = ethers.utils.parseUnits("10", 18);
// ensure you approved the pool to pull tokens: tokenA.approve(pool.address, amountIn)
await tokenA.approve(pool.address, amountIn);
// call swap: tokenIn = tokenA.address, amountIn, to = recipient
await pool.swap(tokenA.address, amountIn, recipientAddress);

// add liquidity as a user (transfer both tokens to pool then call mint)
await tokenA.transfer(pool.address, ethers.utils.parseUnits("5", 18));
await tokenB.transfer(pool.address, ethers.utils.parseUnits("5", 18));
await pool.mint(userAddress);
