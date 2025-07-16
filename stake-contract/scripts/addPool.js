const { ethers } = require("hardhat");

async function main() {
  const MetaNodeStake = await ethers.getContractAt("MetaNodeStake", "0x62b7C03E5A42fedE09D1b862Cb7936B26fDc5c1e");
  const pool = await MetaNodeStake.addPool(ethers.ZeroAddress, 500, 100, 20, false);
  console.log(pool);
}

main();