export interface RateLimiterOptions {
  maxTokens: number;       // bucket capacity
  refillRate: number;      // number of tokens refilled per second
  refillInterval?: number; // refill interval (ms), default 1000
}

export interface RateLimiter {
  tryConsume(tokens?: number): boolean;
  getAvailableTokens(): number;
  reset(): void;
}
