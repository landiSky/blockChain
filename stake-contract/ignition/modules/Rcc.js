const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");
const { ethers, upgrades } = require("hardhat");

module.exports = buildModule("MetaNodeTokenModule", (m) => {
  // 部署 MetaNodeToken 合约，传入初始持有者地址作为参数
  const MetaNodeToken = m.contract("MetaNodeToken");
  return { MetaNodeToken };
});
