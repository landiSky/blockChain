# MetaNode Stake DApp 需求文档与核心业务逻辑

## 一、项目简介

MetaNode Stake 是一个基于以太坊的去中心化质押平台，用户可以通过连接钱包，将 ETH 进行质押，获得平台代币奖励，并支持随时提现。项目注 UI 设计和良好的用户体验，适合 DApp 新手和开发者学习。

## 二、主要功能需求

1. **钱包连接**：支持用户通过 RainbowKit 连接主流以太坊钱包（如 MetaMask）。
2. **ETH 质押**：用户输入质押金额，确认后将 ETH 存入合约。
3. **质押信息展示**：实时显示用户已质押金额、可提现金额、待处理金额等。
4. **提现功能**：用户可将已解锁的 ETH 提现回钱包。
5. **交互反馈**：所有操作均有 toast 提示，包含成功、失败、警告等。
6. **响应式设计**：适配桌面端和移动端。

## 三、主要页面与交互

- **首页（Stake）**：
  - 显示平台简介、用户质押信息、质押表单。
  - 支持钱包连接、输入金额、发起质押。
- **提现页（Withdrawal）**：
  - 展示用户可提现、待处理、已质押金额。
  - 支持发起提现、解锁操作。
- **Header**：
  - 平台 Logo、导航、钱包连接按钮，移动端自适应。
- **全局 Toast 提示**：
  - 操作结果实时反馈。

## 四、技术选型

- **前端框架**：Next.js (React 18)
- **UI 框架**：TailwindCSS
- **动画库**：Framer Motion
- **组件库**：RainbowKit（钱包连接）、自定义 UI 组件
- **以太坊交互**：wagmi、viem
- **数据管理**：@tanstack/react-query
- **通知反馈**：react-toastify

## 五、核心业务逻辑说明

### 1. 钱包连接

- 使用 RainbowKit + wagmi 实现钱包连接，自动检测钱包状态，支持断开与切换。

### 2. 质押 ETH

- 用户输入质押金额，前端校验余额。
- 调用合约 `depositETH` 方法，传入金额。
- 监听交易回执，toast 提示结果。
- 质押成功后自动刷新质押信息。

### 3. 查询质押信息

- 通过合约方法读取用户质押余额、可提现金额、待处理金额。
- 页面自动刷新展示。

### 4. 提现

- 用户点击提现，调用合约 `withdraw` 方法。
- 监听交易回执，toast 提示。
- 提现后自动刷新数据。

### 5. 响应式 ui

- 使用 TailwindCSS + 自定义 CSS，配合 Framer Motion 动画。
- 适配移动端，保证交互友好。

## 六、合约对接说明

- 已质押金额：stakingBalance
- 质押：depositETH
- 进入 withdraw 相关数据：withdrawAmount=>[requestAmount,pendingWithdrawAmount]
- requestAmount: 用户进入 withdraw 流程的总金额
- pendingWithdrawAmount： 可以提取到钱包的金额

## 七、设计亮点

- 极简且科技感强的 UI 设计，蓝色渐变、发光、毛玻璃等效果
- 组件高度复用，代码结构清晰
- 交互流畅，toast 提示风格统一
- 适合 DApp 新手和开发者学习
