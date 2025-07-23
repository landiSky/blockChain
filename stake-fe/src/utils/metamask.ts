// 添加token到MetaMask
export async function addTokenToMetaMask(tokenData: {
  address: string;
  symbol: string;
  decimals: number;
  image?: string;
}) {
  try {
    // 检查是否在浏览器环境且有ethereum对象
    if (typeof window === 'undefined' || !window.ethereum) {
      throw new Error('MetaMask未安装或未连接');
    }

    // 请求添加token
    const wasAdded = await window.ethereum.request({
      method: 'wallet_watchAsset',
      params: {
        type: 'ERC20',
        options: {
          address: tokenData.address,
          symbol: tokenData.symbol,
          decimals: tokenData.decimals,
          image: tokenData.image || ''
        },
      },
    });

    if (wasAdded) {
      console.log(`${tokenData.symbol} 添加成功!`);
      return true;
    } else {
      console.log('用户取消了添加');
      return false;
    }
  } catch (error) {
    console.error('添加token失败:', error);
    throw error;
  }
}

// 添加MetaNode代币到MetaMask
export async function addMetaNodeToMetaMask(metaNodeAddress: string) {
  return addTokenToMetaMask({
    address: metaNodeAddress,
    symbol: 'MetaNode',
    decimals: 18,
    image: '' // 可以添加MetaNode代币的logo URL
  });
} 