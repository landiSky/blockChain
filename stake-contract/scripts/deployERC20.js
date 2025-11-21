const { ethers } = require("hardhat");

async function main() {
  const MyToken = await ethers.getContractFactory("MyToken");
  // 发行1000000个代币（假设18位小数）
  const token = await MyToken.deploy(
    "MyToken",
    "MTK",
    ethers.parseEther("1000000")
  );
  //   await token.deployed();
  console.log("ERC20合约地址:", token.target); // ethers v6 用 .target，v5 用 .address
}

main();
