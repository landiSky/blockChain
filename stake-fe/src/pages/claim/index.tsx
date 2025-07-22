'use client'
import { motion } from 'framer-motion';
import { useStakeContract } from "../../hooks/useContract";
import useRewards from "../../hooks/useRewards";
import { useCallback, useState } from "react";
import { Pid } from "../../utils";
import { useAccount, useWalletClient } from "wagmi";
import { ConnectButton } from "@rainbow-me/rainbowkit";
import { waitForTransactionReceipt } from "viem/actions";
import { toast } from "react-toastify";
import { FiGift, FiInfo, FiTrendingUp, FiClock, FiZap } from 'react-icons/fi';
import { cn } from '../../utils/cn';
import { Button } from '../../components/ui/Button';
import { Card } from '../../components/ui/Card';

const Claim = () => {
  const stakeContract = useStakeContract();
  const { address, isConnected } = useAccount();
  const { rewardsData, canClaim, refresh } = useRewards();
  const [claimLoading, setClaimLoading] = useState(false);
  const { data } = useWalletClient();

  const handleClaim = useCallback(async () => {
    if (!stakeContract || !data) return;
    
    try {
      setClaimLoading(true);
      const tx = await stakeContract.write.claim([Pid]);
      console.log(tx, '===tx===');
      
      const res = await waitForTransactionReceipt(data, { hash: tx });
      
      if (res.status === 'success') {
        toast.success('Claim successful!');
        setClaimLoading(false);
        refresh(); // 刷新数据
        return;
      }
      toast.error('Claim failed!');
    } catch (error) {
      setClaimLoading(false);
      toast.error('Transaction failed. Please try again.');
      console.log(error, 'claim-error');
    }
  }, [stakeContract, data, refresh]);



  return (
    <div className="w-full max-w-6xl mx-auto px-4 sm:px-6 lg:px-8">
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.5 }}
        className="text-center mb-12"
      >
        <div className="inline-block mb-4">
          <motion.div
            animate={{ scale: [1, 1.1, 1] }}
            transition={{ duration: 2, repeat: Infinity }}
            className="w-20 h-20 rounded-full border-2 border-green-500/20 flex items-center justify-center shadow-xl"
            style={{ boxShadow: '0 0 40px 0 rgba(34,197,94,0.15)' }}
          >
            <FiGift className="w-10 h-10 text-green-500" />
          </motion.div>
        </div>
        <h1 className="text-4xl font-bold bg-gradient-to-r from-green-400 to-green-600 bg-clip-text text-transparent mb-4">
          Claim Rewards
        </h1>
        <p className="text-gray-400 text-xl">
          Claim your MetaNode rewards
        </p>
      </motion.div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
        {/* Reward Stats Card */}
        <Card className="p-6 sm:p-8 bg-gradient-to-br from-gray-800/80 to-gray-900/80 shadow-2xl border-green-500/20 border-[1.5px] rounded-2xl">
          <div className="space-y-6">
            <h2 className="text-2xl font-bold text-green-400 mb-6">Reward Statistics</h2>
            
            {/* Pending Rewards */}
            <div className="bg-green-500/10 border border-green-500/20 rounded-xl p-6">
              <div className="flex items-center justify-between">
                <div className="flex items-center space-x-3">
                  <FiGift className="w-6 h-6 text-green-400" />
                  <span className="text-gray-300 font-medium">Pending Rewards</span>
                </div>
                <span className="text-2xl font-bold text-green-400">
                  {parseFloat(rewardsData.pendingReward).toFixed(4)} MetaNode
                </span>
              </div>
            </div>

            {/* Staked Amount */}
            <div className="bg-blue-500/10 border border-blue-500/20 rounded-xl p-6">
              <div className="flex items-center justify-between">
                <div className="flex items-center space-x-3">
                  <FiTrendingUp className="w-6 h-6 text-blue-400" />
                  <span className="text-gray-300 font-medium">Staked Amount</span>
                </div>
                <span className="text-2xl font-bold text-blue-400">
                  {parseFloat(rewardsData.stakedAmount).toFixed(4)} ETH
                </span>
              </div>
            </div>

            {/* Last Update */}
            <div className="bg-purple-500/10 border border-purple-500/20 rounded-xl p-6">
              <div className="flex items-center justify-between">
                <div className="flex items-center space-x-3">
                  <FiClock className="w-6 h-6 text-purple-400" />
                  <span className="text-gray-300 font-medium">Last Update</span>
                </div>
                <span className="text-sm font-medium text-purple-400">
                  {rewardsData.lastUpdate > 0 ? new Date(rewardsData.lastUpdate).toLocaleTimeString() : 'Never'}
                </span>
              </div>
            </div>
          </div>
        </Card>

        {/* Claim Action Card */}
        <Card className="p-6 sm:p-8 bg-gradient-to-br from-gray-800/80 to-gray-900/80 shadow-2xl border-green-500/20 border-[1.5px] rounded-2xl">
          <div className="space-y-6">
            <h2 className="text-2xl font-bold text-green-400 mb-6">Claim Rewards</h2>
            
            {/* Info Section */}
            <div className="bg-blue-500/10 border border-blue-500/20 rounded-xl p-6">
              <div className="flex items-start space-x-3">
                <FiInfo className="w-5 h-5 text-blue-400 mt-0.5 flex-shrink-0" />
                <div className="text-sm text-blue-300">
                  <p className="font-medium mb-2">How claiming works:</p>
                  <ul className="space-y-1 text-xs">
                    <li>• Rewards accumulate continuously while you stake</li>
                    <li>• You can claim rewards anytime</li>
                    <li>• Claimed rewards are sent to your wallet</li>
                    <li>• No minimum claim amount required</li>
                  </ul>
                </div>
              </div>
            </div>

            {/* Claim Status */}
            <div className={cn(
              "rounded-xl p-6 border",
              canClaim 
                ? "bg-green-500/10 border-green-500/20" 
                : "bg-gray-500/10 border-gray-500/20"
            )}>
              <div className="flex items-center justify-between">
                <div className="flex items-center space-x-3">
                  <FiZap className={cn(
                    "w-5 h-5",
                    canClaim ? "text-green-400" : "text-gray-400"
                  )} />
                  <span className={cn(
                    "font-medium",
                    canClaim ? "text-green-400" : "text-gray-400"
                  )}>
                    {canClaim ? "Ready to Claim" : "No Rewards Available"}
                  </span>
                </div>
                <div className={cn(
                  "w-3 h-3 rounded-full",
                  canClaim ? "bg-green-400" : "bg-gray-400"
                )} />
              </div>
            </div>

            {/* Claim Button */}
            <div className="pt-4">
              {!isConnected ? (
                <div className="flex justify-center">
                  <div className="glow">
                    <ConnectButton />
                  </div>
                </div>
              ) : (
                <Button
                  onClick={handleClaim}
                  disabled={claimLoading || !canClaim}
                  loading={claimLoading}
                  fullWidth
                  className="py-4 text-lg bg-gradient-to-r from-green-500 to-green-600 hover:from-green-600 hover:to-green-700"
                >
                  <FiGift className="w-6 h-6" />
                  <span>
                    {claimLoading ? 'Processing...' : canClaim ? 'Claim Rewards' : 'No Rewards'}
                  </span>
                </Button>
              )}
            </div>

            {/* Additional Info */}
            {!canClaim && isConnected && (
              <div className="text-center text-gray-400 text-sm">
                <p>Start staking ETH to earn MetaNode rewards!</p>
              </div>
            )}
          </div>
        </Card>
      </div>

      {/* Reward History Section */}
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.5, delay: 0.3 }}
        className="mt-12"
      >
        <Card className="p-6 sm:p-8 bg-gradient-to-br from-gray-800/80 to-gray-900/80 shadow-2xl border-gray-500/20 border-[1.5px] rounded-2xl">
          <h2 className="text-2xl font-bold text-gray-300 mb-6">Reward History</h2>
          <div className="text-center text-gray-400 py-8">
            <FiClock className="w-12 h-12 mx-auto mb-4 text-gray-500" />
            <p>Reward history will be displayed here</p>
            <p className="text-sm mt-2">Track your past claims and rewards</p>
          </div>
        </Card>
      </motion.div>
    </div>
  );
};

export default Claim; 