# MetaNodeStake 合约深度解析

## **1. 概览**

- 支持 **多池质押**（ETH + ERC20 代币）
- 采用 **可升级合约架构**（UUPS + OpenZeppelin）
- 动态调整 **区块奖励权重**
- 提现 **延迟解锁机制**（防挤兑攻击）

------



## **2. 合约架构**

### **2.1 技术栈**

- **Solidity 0.8.20**（安全数学运算）
- **OpenZeppelin 库**：
  - `UUPSUpgradeable`（可升级代理模式）
  - `AccessControl`（权限管理）
  - `SafeERC20`（安全转账）
  - `Pausable`（紧急暂停功能）

### **2.2 关键角色**

| 角色                 | 权限                   |
| :------------------- | :--------------------- |
| `DEFAULT_ADMIN_ROLE` | 超级管理员             |
| `UPGRADE_ROLE`       | 合约升级权限           |
| `ADMIN_ROLE`         | 日常管理（如修改参数） |

------



## **3. 核心机制解析**

### **3.1 质押挖矿逻辑**

- **奖励计算**：

  ```
  pendingMetaNode = (user.stAmount × pool.accMetaNodePerST) / 1e18 - user.finishedMetaNode
  ```

  - `accMetaNodePerST` 随区块增长累积（按池权重分配）
  - 每次用户操作（存入/提取）触发 `updatePool()` 更新奖励

- **多池权重分配**：

  ```
  MetaNodeForPool = (blocksPassed × MetaNodePerBlock) × (poolWeight / totalPoolWeight)
  ```

### **3.2 延迟提现设计**

- **防挤兑攻击**：
  - 用户发起 `unstake()` 后，需等待 `unstakeLockedBlocks` 才能 `withdraw()`
  - 请求存储在 `UnstakeRequest[]` 数组中，按区块高度分批解锁

### **3.3 ETH 与 ERC20 双模式**

- **ETH 池**（`pid=0`）：
  - `stTokenAddress = address(0)`
  - 通过 `depositETH()` + `msg.value` 存入
- **ERC20 池**：
  - 需先 `approve()` 授权合约转移代币

------



## **4. 安全策略**

### **4.1 防御措施**

| 风险     | 解决方案                                            |
| :------- | :-------------------------------------------------- |
| 重入攻击 | 使用 `SafeERC20` + 先更新状态再转账                 |
| 算术溢出 | Solidity 0.8 默认检查 + `Math` 库的 `tryMul/tryDiv` |
| 恶意升级 | `UUPSUpgradeable` 仅允许 `UPGRADE_ROLE` 操作        |
| 紧急情况 | `Pausable` 暂停关键功能（提现/领取奖励）            |

### **4.2 边界处理**

- **存款下限**：`amount ≥ minDepositAmount`
- **奖励分配**：`block.number ∈ [startBlock, endBlock]`
- **代币不足时**：`_safeMetaNodeTransfer()` 自动调整转账金额

------



## **5. 操作**

### **5.1 用户流程**

1. **存入**：

   ```
   // ETH 池
   contract.depositETH{value: 1 ether}();
   
   // ERC20 池
   token.approve(contract, 1000);
   contract.deposit(pid, 1000);
   ```

2. **领取奖励**：

   ```
   contract.claim(pid);
   ```

3. **提现**：

   ```
   contract.unstake(pid, 500);  // 发起请求
   contract.withdraw(pid);       // 实际提币（需等待解锁）
   ```

### **5.2 管理员操作**

- 调整参数：

  ```
  contract.setMetaNodePerBlock(100);  // 修改区块奖励
  contract.setPoolWeight(1, 200);     // 调整池权重
  ```

- 紧急暂停：

  ```
  contract.pauseWithdraw();  // 暂停提现
  ```

------



## **6. 总结**

### **6.1 适用场景**

- 多代币质押挖矿平台
- 需要灵活升级的 DeFi 协议
- 流动性挖矿（dex协议sushiswap开启，为了吸引流动性提供商，增加池子深度）

### **6.2 改进建议**

- 添加 **时间锁**（TimelockController）管理关键参数变更
- 实现 **动态奖励衰减**（如每 10 万区块减半）
- 前端集成 **预估收益计算器**