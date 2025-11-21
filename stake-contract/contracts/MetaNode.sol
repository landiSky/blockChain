// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MetaNodeToken is ERC20{
    constructor() ERC20("MetaNodeToken", "MetaNode"){
        // 初始供应量可以在这里定义，或者留空以便之后通过 mint 函数铸造
         _mint(msg.sender, 10000000*1_000_000_000_000_000_000);
    }
}

/*
奖励代币合约，实现标准 ERC20 代币，用于发放质押奖励。
*/