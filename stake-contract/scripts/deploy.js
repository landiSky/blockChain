// scripts/deploy.js

// 导入 Hardhat 的 ethers 和升级插件，用于合约部署和代理合约支持。
const { ethers, upgrades } = require("hardhat");

async function main() {
  // 获取当前部署账户（默认是 .env 配置的私钥对应账户）。
  const [signer] = await ethers.getSigners();
  // 获取奖励代币合约工厂（MetaNodeToken）。
  const MetaNodeToken = await ethers.getContractFactory("MetaNodeToken");
  // 部署奖励代币合约.
  const metaNodeToken = await MetaNodeToken.deploy();
  // 等待奖励代币合约部署完成。
  await metaNodeToken.waitForDeployment();
  // 获取奖励代币合约的地址。
  const metaNodeTokenAddress = await metaNodeToken.getAddress();

  // 获取质押合约工厂（MetaNodeStake）。
  const MetaNodeStake = await ethers.getContractFactory("MetaNodeStake");

  // 2. 设置初始化参数（根据你的initialize函数）
  // 例如:
  // IERC20 _MetaNode, uint256 _startBlock, uint256 _endBlock, uint256 _MetaNodePerBlock
  // 你需要替换下面的参数为实际的MetaNode代币地址和区块参数
  // const metaNodeTokenAddress = "0x5FbDB2315678afecb367f032d93F642f64180aa3"; // 替换为实际MetaNode代币地址
  const startBlock = 1; // 替换为实际起始区块
  const endBlock = 999999999999; // 替换为实际结束区块
  const metaNodePerBlock = ethers.parseUnits("1", 18); // 每区块奖励1个MetaNode（18位精度）

  // 3. 部署可升级代理合约 ??
  // 部署 MetaNodeStake 合约的代理，并初始化参数。
  const stake = await upgrades.deployProxy(
    MetaNodeStake,
    [metaNodeTokenAddress, startBlock, endBlock, metaNodePerBlock],
    { initializer: "initialize" }
  );
  // 等待质押合约部署完成。
  await stake.waitForDeployment();

  // todo
  // 获取质押合约地址。
  const stakeAddress = await stake.getAddress();
  // 查询部署账户持有的全部奖励代币数量。
  const tokenAmount = await metaNodeToken.balanceOf(signer.address);
  // 将全部奖励代币转入质押合约地址，供后续奖励分配。
  let tx = await metaNodeToken
    .connect(signer)
    .transfer(stakeAddress, tokenAmount);
  // 等待转账交易完成。
  await tx.wait();
  // 输出部署后的合约地址。
  console.log("MetaNodeStake (proxy) deployed to:", await stake.getAddress());
}

// 执行 main 函数，捕获异常并退出进程。
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

/*
部署入口
部署脚本，自动部署奖励代币和质押合约，并完成初始化和资金转入。

部署奖励代币合约（MetaNodeToken）。
部署主质押合约（MetaNodeStake），采用可升级代理模式。
初始化质押合约参数（奖励代币地址、起止区块、每区块奖励数量）。
将全部奖励代币转入质押合约，供后续分配。
输出部署后的合约地址。
*/
