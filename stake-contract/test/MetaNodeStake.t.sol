// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {Test, console2} from "forge-std/Test.sol";

import {MetaNodeStake} from "../contracts/MetaNodeStake.sol";
// MetaNode is ERC20 contract
import {MetaNode} from "../contracts/shared/MockMetaNode.sol";

contract MetaNodeStakeTest is Test {
    MetaNodeStake MetaNodeStake;
    MetaNode MetaNode;

    fallback() external payable {
    }

    receive() external payable {
    }

    function setUp() public {
        MetaNode = new MetaNode();
        MetaNodeStake = new MetaNodeStake();
        MetaNodeStake.initialize
        (
            MetaNode,
            100,
            100000000,
            3000000000000000000
        );
    }

    function test_AddPool() public {
        // Add nativeCurrency pool
        address _stTokenAddress = address(0x0);
        uint256 _poolWeight = 100;
        uint256 _minDepositAmount = 100;
        uint256 _withdrawLockedBlocks = 100;
        bool _withUpdate = true;

        MetaNodeStake.addPool(_stTokenAddress, _poolWeight, _minDepositAmount, _withdrawLockedBlocks, _withUpdate);

        (
          address stTokenAddress, 
          uint256 poolWeight, 
          uint256 lastRewardBlock,
          uint256 accMetaNodePerShare,
          uint256 stTokenAmount,
          uint256 minDepositAmount, 
          uint256 withdrawLockedBlocks
        )  = MetaNodeStake.pool(0);
        assertEq(stTokenAddress, _stTokenAddress);
        assertEq(poolWeight, _poolWeight);
        assertEq(minDepositAmount, _minDepositAmount);
        assertEq(withdrawLockedBlocks, _withdrawLockedBlocks);
        assertEq(stTokenAmount, 0);
        assertEq(lastRewardBlock, 100);
        assertEq(accMetaNodePerShare, 0);
    }

    function test_massUpdatePools() public {
        test_AddPool();
        MetaNodeStake.massUpdatePools();
        (
          address stTokenAddress, 
          uint256 poolWeight, 
          uint256 lastRewardBlock,
          uint256 accMetaNodePerShare,
          uint256 stTokenAmount,
          uint256 minDepositAmount, 
          uint256 withdrawLockedBlocks
        )  = MetaNodeStake.pool(0);
        assertEq(minDepositAmount, 100);
        assertEq(withdrawLockedBlocks, 100);
        assertEq(lastRewardBlock, 100);

        vm.roll(1000);
        MetaNodeStake.massUpdatePools();
        (
          stTokenAddress, 
          poolWeight, 
          lastRewardBlock,
          accMetaNodePerShare,
          stTokenAmount,
          minDepositAmount, 
          withdrawLockedBlocks
        )  = MetaNodeStake.pool(0);
        assertEq(minDepositAmount, 100);
        assertEq(withdrawLockedBlocks, 100);
        assertEq(lastRewardBlock, 1000);
    }

    function test_SetPoolWeight() public {
        test_AddPool();
        uint256 preTotalPoolWeight = MetaNodeStake.totalPoolWeight();
        
        
        MetaNodeStake.setPoolWeight(0, 200, false);
        (
          address stTokenAddress, 
          uint256 poolWeight, 
          uint256 lastRewardBlock,
          uint256 accMetaNodePerShare,
          uint256 stTokenAmount,
          uint256 minDepositAmount, 
          uint256 withdrawLockedBlocks
        )  = MetaNodeStake.pool(0);
        uint256 totalPoolWeight = MetaNodeStake.totalPoolWeight();
        uint256 expectedTotalPoolWeight = preTotalPoolWeight - 100 + 200;
        assertEq(poolWeight, 200);
        assertEq(totalPoolWeight, expectedTotalPoolWeight);
    }

    function test_DepositnativeCurrency() public {
        test_AddPool();
        (
          address stTokenAddress, 
          uint256 poolWeight, 
          uint256 lastRewardBlock,
          uint256 accMetaNodePerShare,
          uint256 stTokenAmount,
          uint256 minDepositAmount, 
          uint256 withdrawLockedBlocks
        ) = MetaNodeStake.pool(0);
        uint256 prePoolStTokenAmount = stTokenAmount;

        (
          uint256 stAmount,
          uint256 finishedMetaNode,
          uint256 pendingMetaNode
        ) = MetaNodeStake.user(0, address(this));
        uint256 preStAmount = stAmount;
        uint256 preFinishedMetaNode = finishedMetaNode;
        uint256 prePendingMetaNode = pendingMetaNode;

        // First deposit
        address(MetaNodeStake).call{value: 100}(
          abi.encodeWithSignature("depositnativeCurrency()")
        );
        (
          stTokenAddress, 
          poolWeight, 
          lastRewardBlock,
          accMetaNodePerShare,
          stTokenAmount,
          minDepositAmount, 
          withdrawLockedBlocks
        )  = MetaNodeStake.pool(0);

        (
          stAmount,
          finishedMetaNode,
          pendingMetaNode
        ) = MetaNodeStake.user(0, address(this));

        uint256 expectedStAmount = preStAmount + 100;
        uint256 expectedFinishedMetaNode = preFinishedMetaNode;
        uint256 expectedTotoalStTokenAmount = prePoolStTokenAmount + 100;

        assertEq(stAmount, expectedStAmount);
        assertEq(finishedMetaNode, expectedFinishedMetaNode);
        assertEq(stTokenAmount, expectedTotoalStTokenAmount);

        // more deposit
        address(MetaNodeStake).call{value: 200 ether}(
          abi.encodeWithSignature("depositnativeCurrency()")
        );

        vm.roll(2000000);
        MetaNodeStake.unstake(0, 100);
        address(MetaNodeStake).call{value: 300 ether}(
          abi.encodeWithSignature("depositnativeCurrency()")
        );

        vm.roll(3000000);
        MetaNodeStake.unstake(0, 100);
        address(MetaNodeStake).call{value: 400 ether}(
          abi.encodeWithSignature("depositnativeCurrency()")
        );

        vm.roll(4000000);
        MetaNodeStake.unstake(0, 100);
        address(MetaNodeStake).call{value: 500 ether}(
          abi.encodeWithSignature("depositnativeCurrency()")
        );

        vm.roll(5000000);
        MetaNodeStake.unstake(0, 100);
        address(MetaNodeStake).call{value: 600 ether}(
          abi.encodeWithSignature("depositnativeCurrency()")
        );

        vm.roll(6000000);
        MetaNodeStake.unstake(0, 100);
        address(MetaNodeStake).call{value: 700 ether}(
          abi.encodeWithSignature("depositnativeCurrency()")
        );

        MetaNodeStake.withdraw(0);
    }

    function test_Unstake() public {
        test_DepositnativeCurrency();
        
        vm.roll(1000);
        MetaNodeStake.unstake(0, 100);

        (
          uint256 stAmount,
          uint256 finishedMetaNode,
          uint256 pendingMetaNode
        ) = MetaNodeStake.user(0, address(this));
        assertEq(stAmount, 0);
        assertEq(finishedMetaNode, 0);
        assertGt(pendingMetaNode, 0);

        (
          address stTokenAddress, 
          uint256 poolWeight, 
          uint256 lastRewardBlock,
          uint256 accMetaNodePerShare,
          uint256 stTokenAmount,
          uint256 minDepositAmount, 
          uint256 withdrawLockedBlocks
        ) = MetaNodeStake.pool(0);

        uint256 expectStTokenAmount = 0;
        assertEq(stTokenAmount, expectStTokenAmount);
    }

    function test_Withdraw() public {
        test_Unstake();
        uint256 preContractBalance = address(MetaNodeStake).balance;
        uint256 preUserBalance = address(this).balance;
      
        vm.roll(10000);
        MetaNodeStake.withdraw(0);

        uint256 postContractBalance = address(MetaNodeStake).balance;
        uint256 postUserBalance = address(this).balance;
        assertLt(postContractBalance, preContractBalance);
        assertGt(postUserBalance, preUserBalance);
    }

    function test_ClaimAfterDeposit() public {
        test_DepositnativeCurrency();
        MetaNode.transfer(address(MetaNodeStake), 100000000000);
        uint256 preUserMetaNodeBalance = MetaNode.balanceOf(address(this));

        vm.roll(10000);
        MetaNodeStake.claim(0);

        uint256 postUserMetaNodeBalance = MetaNode.balanceOf(address(this));
        assertGt(postUserMetaNodeBalance, preUserMetaNodeBalance);
    }

    function test_ClaimAfterUnstake() public {
        test_Unstake();
        MetaNode.transfer(address(MetaNodeStake), 100000000000);
        uint256 preUserMetaNodeBalance = MetaNode.balanceOf(address(this));

        vm.roll(10000);
        MetaNodeStake.claim(0);

        uint256 postUserMetaNodeBalance = MetaNode.balanceOf(address(this));
        assertGt(postUserMetaNodeBalance, preUserMetaNodeBalance);
    }

    function test_ClaimAfterWithdraw() public {
        test_Withdraw();
        MetaNode.transfer(address(MetaNodeStake), 100000000000);
        uint256 preUserMetaNodeBalance = MetaNode.balanceOf(address(this));

        vm.roll(10000);
        MetaNodeStake.claim(0);

        uint256 postUserMetaNodeBalance = MetaNode.balanceOf(address(this));
        assertGt(postUserMetaNodeBalance, preUserMetaNodeBalance);
    }

    function addPool(uint256 index, address stTokenAddress) public {
        address _stTokenAddress = stTokenAddress;
        uint256 _poolWeight = 100;
        uint256 _minDepositAmount = 100;
        uint256 _withdrawLockedBlocks = 100;
        bool _withUpdate = true;

        MetaNodeStake.addPool(_stTokenAddress, _poolWeight, _minDepositAmount, _withdrawLockedBlocks, _withUpdate);
    }
}