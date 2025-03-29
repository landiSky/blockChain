import { Box, Grid, TextField, Typography } from "@mui/material";
import { NextPage } from "next";
import { useStakeContract } from "../../hooks/useContract";
import { useCallback, useEffect, useMemo, useState } from "react";
import { Pid } from "../../utils";
import { useAccount, useWalletClient } from "wagmi";
import { formatUnits, parseUnits, zeroAddress } from "viem";
import { ConnectButton } from "@rainbow-me/rainbowkit";
import { LoadingButton } from "@mui/lab";
import { waitForTransactionReceipt } from "viem/actions";
import { toast } from "react-toastify";
import Header from "../../components/Header";


export type UserStakeData = {
  staked: string,
  withdrawPending: string,
  withdrawable: string
}

const InitData = {
  staked: '0',
  withdrawable: '0',
  withdrawPending: '0'
}

const Withdraw: NextPage = () => {
  const stakeContract = useStakeContract()
  const { address, isConnected } = useAccount()
  const [amount, setAmount] = useState('0')
  const [unstakeLoading, setUnstakeLoading] = useState(false)
  const [withdrawLoading, setWithdrawLoading] = useState(false)
  const { data } = useWalletClient()
  const [userData, setUserData] = useState<UserStakeData>(InitData)

  const isWithdrawable = useMemo(() => {
    return Number(userData.withdrawable) > 0 && isConnected
  }, [userData, isConnected])

  const getUserData = async () => {
    if (!stakeContract || !address) return;
    const staked = await stakeContract?.read.stakingBalance([Pid, address])
    //@ts-ignore
    const [requestAmount, pendingWithdrawAmount] = await stakeContract.read.withdrawAmount([Pid, address]);
    const ava = Number(formatUnits(pendingWithdrawAmount, 18))
    const p = Number(formatUnits(requestAmount, 18))
    console.log({ p, ava })
    setUserData({
      staked: formatUnits(staked as bigint, 18),
      withdrawPending: (p - ava).toFixed(4),
      withdrawable: ava.toString()
    })
  }

  useEffect(() => {
    if (stakeContract && address) {
      getUserData()
    }
  }, [address, stakeContract])
  const handleUnStake = async () => {
    if (!stakeContract || !data) return;
    try {
      setUnstakeLoading(true)
      const tx = await stakeContract.write.unstake([Pid, parseUnits(amount, 18)])
      const res = await waitForTransactionReceipt(data, { hash: tx })
      toast.success('Transaction receipt !')
      setUnstakeLoading(false)
      getUserData()
    } catch (error) {
      setUnstakeLoading(false)
      console.log(error, 'stake-error')
    }
  }
  const handleWithdraw = async () => {
    if (!stakeContract || !data) return;
    try {
      setWithdrawLoading(true)
      const tx = await stakeContract.write.withdraw([Pid])
      const res = await waitForTransactionReceipt(data, { hash: tx })
      console.log(res, 'withdraw-res')
      toast.success('Transaction receipt !')
      setWithdrawLoading(false)
      getUserData()
    } catch (error) {
      setWithdrawLoading(false)
      console.log(error, 'stake-error')
    }
  }

  return (
    <>
      <Box display={'flex'} flexDirection={'column'} alignItems={'center'} width={'100%'}>
        <Typography sx={{ fontSize: '30px', fontWeight: 'bold' }}>MetaNode  Stake</Typography>
        <Typography sx={{}}>Stake ETH to earn tokens.</Typography>
        <Box sx={{ border: '1px solid #eee', borderRadius: '12px', p: '20px', width: '600px', mt: '30px' }}>
          <Grid container sx={{
            mb: '60px',
            '& .title': {
              fontSize: '15px',
              mb: '5px'
            },
            '& .val': {
              fontSize: '18px',
              fontWeight: 'bold'
            }
          }}>
            <Grid item xs={4}>
              <Box display={'flex'} alignItems={'center'} flexDirection={'column'}>
                <Box className='title'>Staked Amount: </Box>
                <Box className='val'>{userData.staked} ETH</Box>
              </Box>
            </Grid>
            <Grid item xs={4}>
              <Box display={'flex'} alignItems={'center'} flexDirection={'column'}>
                <Box className='title'>Available to withdraw </Box>
                <Box className='val'>{userData.withdrawable} ETH</Box>
              </Box>
            </Grid><Grid item xs={4}>
              <Box display={'flex'} alignItems={'center'} flexDirection={'column'}>
                <Box className='title'>Pending Withdraw: </Box>
                <Box className='val'>{userData.withdrawPending} ETH</Box>
              </Box>
            </Grid>
          </Grid>
          <Box sx={{ fontSize: '20px', mb: '10px' }}>Unstake</Box>
          <TextField onChange={(e) => {
            setAmount(e.target.value)
          }} sx={{ minWidth: '300px' }} label="Amount" variant="outlined" />
          <Box mt='20px'>
            {
              !isConnected ? <ConnectButton /> : <LoadingButton variant='contained' loading={unstakeLoading} onClick={handleUnStake}>UnStake</LoadingButton>
            }
          </Box>
          <Box sx={{ fontSize: '20px', mb: '10px', mt: '40px' }}>Withdraw</Box>
          <Box> Ready Amount: {userData.withdrawable} </Box>
          <Typography fontSize={'14px'} color={'#888'}>After unstaking, you need to wait 20 minutes to withdraw.</Typography>
          <LoadingButton sx={{ mt: '20px' }} disabled={!isWithdrawable} variant='contained' loading={withdrawLoading} onClick={handleWithdraw}>Withdraw</LoadingButton>
        </Box>
      </Box>
    </>

  )
}

export default Withdraw