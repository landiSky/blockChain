// 重试函数
export async function retryWithDelay<T>(
  fn: () => Promise<T>,
  maxRetries: number = 3,
  delay: number = 1000
): Promise<T> {
  let lastError: Error;

  for (let i = 0; i < maxRetries; i++) {
    try {
      return await fn();
    } catch (error) {
      lastError = error as Error;
      
      // 如果是429错误，增加延迟时间
      if (error instanceof Error && error.message.includes('429')) {
        const backoffDelay = delay * Math.pow(2, i); // 指数退避
        console.log(`请求被限流，等待 ${backoffDelay}ms 后重试...`);
        await new Promise(resolve => setTimeout(resolve, backoffDelay));
      } else if (i < maxRetries - 1) {
        // 其他错误，短暂延迟后重试
        await new Promise(resolve => setTimeout(resolve, delay));
      }
    }
  }

  throw lastError!;
} 