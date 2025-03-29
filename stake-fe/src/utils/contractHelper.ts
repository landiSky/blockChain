import { Abi, Address, GetContractReturnType, PublicClient, WalletClient, getContract as viemGetContract, } from "viem"
import { defaultChainId } from './wagmi'
import { viemClients } from "./viem"

export const getContract = <TAbi extends Abi | readonly unknown[], TWalletClient extends WalletClient>({
  abi,
  address,
  chainId = defaultChainId,
  signer,
}: {
  abi: TAbi | readonly unknown[]
  address: Address
  chainId?: number
  signer?: TWalletClient
}) => {
  const c = viemGetContract({
    abi,
    address,
    client: {
      public: viemClients(chainId),
      wallet: signer,
    },
  }) as unknown as GetContractReturnType<TAbi, PublicClient, Address>

  return {
    ...c,
    account: signer?.account,
    chain: signer?.chain,
  }
}