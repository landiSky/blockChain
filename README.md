
# Digital-Node-Staking 项目说明

## 项目简介

Digital-Node-Staking 是一个基于以太坊的多池质押（Staking）平台，支持用户质押原生币（如 ETH）或任意 ERC20 代币，获得奖励代币。项目适用于 DeFi、社区激励等场景，支持合约升级、权限管理和多种安全控制。

## 目录结构

```
Digital-Node-Staking/
├── stake-contract/        # Solidity 智能合约与 Hardhat 工程
│   ├── contracts/        # NodeStake、NodeToken 等核心合约
│   ├── scripts/          # 部署与交互脚本
│   ├── test/             # 合约测试
│   ├── artifacts/        # 编译产物
│   ├── hardhat.config.js # Hardhat 配置
│   └── ...
├── README.md             # 项目说明（当前文件）
├── 需求文档与核心业务逻辑.md
└── ...
```

## 合约说明

- **NodeStake.sol**：多池质押主合约，支持多币种、奖励分配、权限与升级。
- **Node.sol**：奖励代币 NodeToken，标准 ERC20。
- **MyToken.sol**：可自定义名称、符号和初始供应的 ERC20 代币。

## 快速开始

### 1. 克隆仓库

```bash
git clone <本项目地址>
cd Digital-Node-Staking/stake-contract
```

### 2. 安装依赖

```bash
npm install
```

### 3. 编译合约

```bash
npx hardhat compile
```

> ⚠️ 注意：Hardhat ignition 编译出的 JS 文件名固定为 `Rcc.js`，需手动重命名为 `Node.js`，或直接用 Remix 部署。

### 4. 部署 NodeToken

```bash
npx hardhat ignition deploy ./ignition/modules/Node.js
```
部署后记录合约地址（如 `0x264e...`）。

### 5. 部署 NodeStake 合约

将上一步 NodeToken 地址作为参数，设置到 NodeStake 初始化脚本中：

```js
const NodeToken = "<NodeToken 地址>";
```

然后部署：

```bash
npx hardhat run scripts/NodeStake.js --network sepolia
```

### 6. 添加资金池

```bash
npx hardhat run scripts/addPool.js --network sepolia
```

## 常见问题

- Hardhat ignition 生成的 JS 文件需手动重命名。
- 推荐使用 Remix 进行合约部署和调试。
- 如需自定义奖励币种，可修改 `MyToken.sol`。

## 参考文档

- `NodeStake合约解析.md`、`Stake需求文档.md`、`系统架构.md` 等文档详见项目根目录。

---
如有问题欢迎提 Issue 或联系开发者。


