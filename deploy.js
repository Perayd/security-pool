async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying with", deployer.address);

  const SimpleToken = await ethers.getContractFactory("SimpleToken");
  const tokenA = await SimpleToken.deploy("TokenA", "TKA", ethers.utils.parseUnits("1000000", 18));
  await tokenA.deployed();
  const tokenB = await SimpleToken.deploy("TokenB", "TKB", ethers.utils.parseUnits("1000000", 18));
  await tokenB.deployed();

  console.log("TokenA:", tokenA.address);
  console.log("TokenB:", tokenB.address);

  const SimplePool = await ethers.getContractFactory("SimplePool");
  const pool = await SimplePool.deploy(tokenA.address, tokenB.address, "LP Token", "LPT");
  await pool.deployed();

  console.log("Pool deployed at:", pool.address);

  // optional: seed tokens to deployer and approve pool
  // (already minted to deployer in SimpleToken constructor)
  const amountA = ethers.utils.parseUnits("1000", 18);
  const amountB = ethers.utils.parseUnits("1000", 18);

  // approve pool to pull tokens for mint
  await tokenA.approve(pool.address, amountA);
  await tokenB.approve(pool.address, amountB);

  // transfer tokens into pool contract (simulate user providing liquidity)
  await tokenA.transfer(pool.address, amountA);
  await tokenB.transfer(pool.address, amountB);

  // call mint to mint LP tokens to deployer
  await pool.mint(deployer.address);

  console.log("Initial liquidity added");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
