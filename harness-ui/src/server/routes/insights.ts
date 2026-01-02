import { Hono } from 'hono'
import type { Insight } from '../../shared/types.ts'
import { analyzeHealth, analyzeSkills, analyzeMemory, analyzeRules } from '../services/analyzer.ts'

const app = new Hono()

/**
 * プロジェクトを分析して最適化提案を生成
 *
 * AI Insights は Claude CLI を内部で呼び出すことを想定していますが、
 * 現在の実装では静的分析に基づく提案を生成します。
 */
async function generateProjectInsights(): Promise<Insight[]> {
  const insights: Insight[] = []

  // プロジェクトルートを取得（harness-ui の親ディレクトリ = claude-code-harness）
  const projectRoot = process.cwd().replace(/\/harness-ui$/, '')

  try {
    // 各コンポーネントを分析
    const [health, skills, memory, rules] = await Promise.all([
      analyzeHealth(projectRoot).catch(() => null),
      analyzeSkills(projectRoot).catch(() => null),
      analyzeMemory(projectRoot).catch(() => null),
      analyzeRules(projectRoot).catch(() => null)
    ])

    // Memory 分析に基づく提案（保存サイズ。初期読み込みではない）
    if (memory) {
      const storageTokens = memory.totalTokens

      if (storageTokens > 50000) {
        insights.push({
          type: 'warning',
          title: 'Memory 保存サイズが過多です',
          description: `保存サイズ ${storageTokens.toLocaleString()} トークン。session-log.md のアーカイブを検討してください。（※Memory は参照時のみ読み込まれ、初期コンテキストには含まれません）`,
          impact: 'medium',
          effort: 'low',
          cliCommand: '/harness-mem cleanup'
        })
      } else if (storageTokens > 30000) {
        insights.push({
          type: 'suggestion',
          title: 'Memory の定期整理を推奨',
          description: `保存サイズ ${storageTokens.toLocaleString()} トークン。古い session-log エントリの整理を検討してください。`,
          impact: 'low',
          effort: 'low',
          cliCommand: '/harness-mem status'
        })
      }

      if (memory.duplicates.length > 0) {
        insights.push({
          type: 'optimization',
          title: '重複コンテンツをマージ可能',
          description: `${memory.duplicates.length} 件の重複コンテンツが検出されました。マージすることでトークン数を削減できます。`,
          impact: 'medium',
          effort: 'medium',
          cliCommand: '/harness-mem merge'
        })
      }
    }

    // Skills 分析に基づく提案
    if (skills) {
      if (skills.unusedSkills.length > 3) {
        insights.push({
          type: 'suggestion',
          title: '未使用 Skills の削除を検討',
          description: `${skills.unusedSkills.length} 件のスキルが最近使用されていません: ${skills.unusedSkills.slice(0, 3).join(', ')}${skills.unusedSkills.length > 3 ? '...' : ''}`,
          impact: 'low',
          effort: 'low',
          cliCommand: '/skills-update remove'
        })
      }

      if (skills.totalTokens > 20000) {
        insights.push({
          type: 'warning',
          title: 'Skills トークン数が多い',
          description: `Skills 合計 ${skills.totalTokens.toLocaleString()} トークンです。不要なスキルを削除するか、スキルを圧縮してください。`,
          impact: 'medium',
          effort: 'medium',
          cliCommand: '/skills-update list'
        })
      }
    }

    // Rules 分析に基づく提案（初期読み込みトークン）
    if (rules) {
      if (rules.conflicts.length > 0) {
        insights.push({
          type: 'warning',
          title: 'Rules コンフリクトを解消',
          description: `${rules.conflicts.length} 件のルールコンフリクトがあります。矛盾するルールを確認してください。`,
          impact: 'high',
          effort: 'medium',
          cliCommand: 'claude "rules のコンフリクトを確認して"'
        })
      }

      if (rules.initialLoadTokens > 5000) {
        insights.push({
          type: 'suggestion',
          title: 'Rules の最適化を検討',
          description: `Rules 初期読み込み ${rules.initialLoadTokens.toLocaleString()} トークン。冗長な記述を簡潔にすることを検討してください。`,
          impact: 'medium',
          effort: 'high',
          cliCommand: 'claude "rules を簡潔に最適化して"'
        })
      }
    }

    // Health スコアに基づく提案
    if (health) {
      if (health.score < 60) {
        insights.push({
          type: 'warning',
          title: 'プロジェクト健全性を改善',
          description: `健全性スコア ${health.score} は改善の余地があります。SSOT ファイルの整備を検討してください。`,
          impact: 'high',
          effort: 'high',
          cliCommand: '/harness-init'
        })
      }

      // 具体的な改善提案を追加
      for (const suggestion of health.suggestions.slice(0, 2)) {
        insights.push({
          type: 'suggestion',
          title: suggestion,
          description: '健全性分析からの提案です。',
          impact: 'medium',
          effort: 'low',
          cliCommand: '/sync-status'
        })
      }
    }

    // 提案がない場合のデフォルトメッセージ
    if (insights.length === 0) {
      insights.push({
        type: 'suggestion',
        title: 'プロジェクトは良好な状態です',
        description: '現時点で重要な最適化提案はありません。定期的に /sync-status で状態を確認してください。',
        impact: 'low',
        effort: 'low',
        cliCommand: '/sync-status'
      })
    }

  } catch (error) {
    console.error('Failed to generate insights:', error)
    insights.push({
      type: 'warning',
      title: '分析中にエラーが発生しました',
      description: 'プロジェクトの一部を分析できませんでした。詳細はコンソールを確認してください。',
      impact: 'medium',
      effort: 'low',
      cliCommand: '/validate'
    })
  }

  return insights
}

// POST /api/insights - 最適化提案を生成
app.post('/', async (c) => {
  const insights = await generateProjectInsights()
  return c.json({ insights })
})

// GET /api/insights - 現在の提案を取得（キャッシュなし、毎回生成）
app.get('/', async (c) => {
  const insights = await generateProjectInsights()
  return c.json({ insights })
})

export default app
