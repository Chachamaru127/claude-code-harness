import type { HealthMetrics, HealthStatus } from '../../shared/types.ts'

/**
 * Calculate health score from metrics
 * Base score: 100
 *
 * Skills penalties (30 points max):
 * - Token overflow (>10000): -10
 * - Too many unused (>3): -10
 * - No skills: -10
 *
 * Memory penalties (30 points max):
 * - Token overflow (>5000): -10
 * - Duplicates present: -10
 * - No memory: -10
 *
 * Rules penalties (30 points max):
 * - Conflicts present: -20
 * - No rules: -10
 *
 * Hooks penalties (10 points max):
 * - Too many (>10): -10
 */
export function calculateHealthScore(metrics: HealthMetrics): number {
  let score = 100

  // Skills evaluation (30 points)
  if (metrics.skills.totalTokens > 10000) score -= 10
  if (metrics.skills.unusedCount > 3) score -= 10
  if (metrics.skills.count === 0) score -= 10

  // Memory evaluation (30 points) - based on storage size, not initial load
  if (metrics.memory.storageTokens > 30000) score -= 10 // Higher threshold since not initial load
  if (metrics.memory.duplicateCount > 0) score -= 10
  if (metrics.memory.storageTokens === 0) score -= 10

  // Rules evaluation (30 points)
  if (metrics.rules.conflictCount > 0) score -= 20
  if (metrics.rules.count === 0) score -= 10

  // Hooks evaluation (10 points)
  if (metrics.hooks.count > 10) score -= 10

  return Math.max(0, Math.min(100, score))
}

/**
 * Get health status from score
 */
export function getHealthStatus(score: number): HealthStatus {
  if (score >= 80) return 'good'
  if (score >= 60) return 'warning'
  return 'error'
}

/**
 * Generate improvement suggestions based on metrics
 */
export function generateSuggestions(metrics: HealthMetrics): string[] {
  const suggestions: string[] = []

  // Skills suggestions
  if (metrics.skills.totalTokens > 10000) {
    suggestions.push('Skills の合計トークン数が 10,000 を超えています。不要な Skills を整理してください。')
  }
  if (metrics.skills.unusedCount > 3) {
    suggestions.push(`${metrics.skills.unusedCount} 個の未使用 Skills があります。使用していない Skills を削除してください。`)
  }
  if (metrics.skills.count === 0) {
    suggestions.push('Skills が設定されていません。/skill-list で利用可能な Skills を確認してください。')
  }

  // Memory suggestions (storage size, not initial load)
  if (metrics.memory.storageTokens > 30000) {
    suggestions.push('Memory の保存サイズが 30,000 トークンを超えています。session-log のアーカイブを検討してください。')
  }
  if (metrics.memory.duplicateCount > 0) {
    suggestions.push(`Memory に ${metrics.memory.duplicateCount} 件の重複が検出されました。マージを検討してください。`)
  }
  if (metrics.memory.storageTokens === 0) {
    suggestions.push('Memory が空です。decisions.md や patterns.md に学習事項を記録してください。')
  }

  // Rules suggestions
  if (metrics.rules.conflictCount > 0) {
    suggestions.push(`Rules に ${metrics.rules.conflictCount} 件のコンフリクトがあります。矛盾するルールを解消してください。`)
  }
  if (metrics.rules.count === 0) {
    suggestions.push('Rules が設定されていません。プロジェクト固有のルールを .claude/rules/ に追加してください。')
  }

  // Hooks suggestions
  if (metrics.hooks.count > 10) {
    suggestions.push(`Hooks が ${metrics.hooks.count} 個あります。10 個以下に整理することを推奨します。`)
  }

  return suggestions
}
