/**
 * トークン使用量のステータスユーティリティ
 * 複数コンポーネントで共通利用される
 */

export interface TokenStatus {
  label: string
  color: string
  hint: string
}

export interface TokenThresholds {
  high: number
  medium: number
}

const DEFAULT_THRESHOLDS: TokenThresholds = {
  high: 10000,
  medium: 5000
}

/**
 * トークン使用量のステータスを取得
 * @param tokens - トークン数
 * @param thresholds - カスタム閾値（オプション）
 * @returns ステータス情報
 */
export function getTokenStatus(
  tokens: number,
  thresholds: TokenThresholds = DEFAULT_THRESHOLDS
): TokenStatus {
  if (tokens > thresholds.high) {
    return {
      label: '過多',
      color: '#ef4444',
      hint: 'コンテキストを圧迫する可能性あり'
    }
  }
  if (tokens > thresholds.medium) {
    return {
      label: '多め',
      color: '#f59e0b',
      hint: '整理を検討してください'
    }
  }
  return {
    label: '適正',
    color: '#22c55e',
    hint: '良好な状態です'
  }
}

/**
 * Skills 用のトークンステータス（閾値が異なる）
 */
export function getSkillsTokenStatus(tokens: number): TokenStatus {
  return getTokenStatus(tokens, { high: 15000, medium: 10000 })
}

/**
 * Memory 用のトークンステータス（閾値が異なる）
 */
export function getMemoryTokenStatus(tokens: number): TokenStatus {
  if (tokens > 50000) {
    return {
      label: '過多',
      color: '#ef4444',
      hint: 'session-log のアーカイブを推奨'
    }
  }
  if (tokens > 30000) {
    return {
      label: '多め',
      color: '#f59e0b',
      hint: '定期的な整理を検討'
    }
  }
  return {
    label: '適正',
    color: '#22c55e',
    hint: 'SSOT として良好な状態'
  }
}
