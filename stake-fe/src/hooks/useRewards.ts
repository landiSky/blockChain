import { useCallback, useEffect, useState } from 'react';
import { useAccount } from 'wagmi';
import { formatUnits } from 'viem';
import { useStakeContract } from './useContract';
import { Pid } from '../utils';

export type RewardsData = {
  pendingReward: string;
  stakedAmount: string;
  lastUpdate: number;
};

type UserData = [bigint, bigint, bigint]; // [stAmount, finishedMetaNode, pendingMetaNode]

const useRewards = () => {
  const stakeContract = useStakeContract();
  const { address, isConnected } = useAccount();
  const [rewardsData, setRewardsData] = useState<RewardsData>({
    pendingReward: '0',
    stakedAmount: '0',
    lastUpdate: 0
  });
  const [loading, setLoading] = useState(false);

  const fetchRewardsData = useCallback(async () => {
    if (!stakeContract || !address || !isConnected) return;

    try {
      setLoading(true);
      
      // 获取用户数据
      const userData = await stakeContract.read.user([Pid, address]) as UserData;
      const stakedAmount = await stakeContract.read.stakingBalance([Pid, address]);

      console.log('User data:', userData);
      console.log('Staked amount:', stakedAmount);

      setRewardsData({
        pendingReward: formatUnits(userData[2] || BigInt(0), 18),
        stakedAmount: formatUnits(stakedAmount as bigint || BigInt(0), 18),
        lastUpdate: Date.now()
      });
    } catch (error) {
      console.error('Failed to fetch rewards data:', error);
      // 设置默认值
      setRewardsData({
        pendingReward: '0',
        stakedAmount: '0',
        lastUpdate: Date.now()
      });
    } finally {
      setLoading(false);
    }
  }, [stakeContract, address, isConnected]);

  // 初始加载
  useEffect(() => {
    if (isConnected && address) {
      fetchRewardsData();
    }
  }, [isConnected, address, fetchRewardsData]);

  // 定期刷新数据（每30秒）
  useEffect(() => {
    if (!isConnected || !address) return;

    const interval = setInterval(() => {
      fetchRewardsData();
    }, 30000); // 30秒

    return () => clearInterval(interval);
  }, [isConnected, address, fetchRewardsData]);

  // 手动刷新
  const refresh = useCallback(() => {
    fetchRewardsData();
  }, [fetchRewardsData]);

  return {
    rewardsData,
    loading,
    refresh,
    canClaim: parseFloat(rewardsData.pendingReward) > 0
  };
};

export default useRewards; 