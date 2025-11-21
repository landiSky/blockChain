const { ethers } = require("hardhat");

async function main() {
  const MetaNodeStake = await ethers.getContractAt(
    "MetaNodeStake",
    "0x34699C41dDc6319d560e35Eecca9e8257Bfb7B08"
  );

  // 用于本地测试: 本地跑了 npx hardhat node,
  // 接着运行了另一个终端跑了: npx hardhat run scripts/deploy.js --network localhost, 生成了部署在本地的合约0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512
  // const MetaNodeStake = await ethers.getContractAt("MetaNodeStake", "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512");
  const poolLength = await MetaNodeStake.poolLength();
  console.log("当前池数量：", poolLength.toString());
  const erc20Address = "0x8bAd4E5C8A653A11A9135ad10Ad5806e0E692492";
  const pool = await MetaNodeStake.addPool(
    // ethers.ZeroAddress, 第0个池用0地址
    erc20Address,
    500,
    100,
    20,
    true
  );
  console.log(pool);
}

main();

/*
添加资金池脚本，调用合约方法新增质押池（支持原生币或 ERC20）。
*/
