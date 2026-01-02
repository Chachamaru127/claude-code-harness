import { useState, useEffect } from 'react'
import { fetchRules } from '../lib/api.ts'
import type { RulesResponse, Rule } from '../../shared/types.ts'

/**
 * トークン使用量のステータスを取得
 */
function getTokenStatus(tokens: number): { label: string; color: string; hint: string } {
  if (tokens > 10000) return { label: '過多', color: '#ef4444', hint: 'コンテキストを圧迫する可能性あり' }
  if (tokens > 5000) return { label: '多め', color: '#f59e0b', hint: '整理を検討してください' }
  return { label: '適正', color: '#22c55e', hint: '良好な状態です' }
}

/**
 * ルールをカテゴリ別にグループ化
 */
interface GroupedRules {
  active: Rule[]
  cursor: Rule[]
  template: Rule[]
}

function groupRulesByCategory(rules: Rule[]): GroupedRules {
  const groups: GroupedRules = {
    active: [],
    cursor: [],
    template: []
  }
  for (const rule of rules) {
    // カテゴリはnameのプレフィックスから判定
    if (rule.name.startsWith('[テンプレート]')) {
      groups.template.push(rule)
    } else if (rule.name.startsWith('[Cursor]')) {
      groups.cursor.push(rule)
    } else {
      groups.active.push(rule)
    }
  }
  return groups
}

type RuleCategory = 'active' | 'cursor' | 'template'

interface CategoryInfoItem {
  icon: string
  title: string
  desc: string
  importance: 'high' | 'medium' | 'low'
}

/**
 * カテゴリ情報
 */
const categoryInfo: Record<RuleCategory, CategoryInfoItem> = {
  active: { icon: '✅', title: 'アクティブ', desc: '.claude/rules/ から読み込まれる有効ルール', importance: 'high' },
  cursor: { icon: '🖱️', title: 'Cursor', desc: '.cursor/rules/ のCursor連携ルール', importance: 'medium' },
  template: { icon: '📋', title: 'テンプレート', desc: 'templates/rules/ の参照用テンプレート', importance: 'low' }
}

export function RulesEditor() {
  const [rules, setRules] = useState<RulesResponse | null>(null)
  const [loading, setLoading] = useState(true)
  const [expandedCategories, setExpandedCategories] = useState<Set<string>>(new Set(['active']))

  useEffect(() => {
    fetchRules().then(setRules).finally(() => setLoading(false))
  }, [])

  const toggleCategory = (category: string) => {
    setExpandedCategories(prev => {
      const next = new Set(prev)
      if (next.has(category)) next.delete(category)
      else next.add(category)
      return next
    })
  }

  if (loading) {
    return (
      <div className="page-container">
        <div className="flex items-center gap-4">
          <div className="spinner" />
          <span>Rules を読み込み中...</span>
        </div>
      </div>
    )
  }

  if (!rules) {
    return (
      <div className="page-container">
        <div className="health-error">Rules の取得に失敗しました</div>
      </div>
    )
  }

  const groupedRules = groupRulesByCategory(rules.rules)

  // ユーザー関連ルールのみカウント（テンプレート除外）
  const userRules = [...groupedRules.active, ...groupedRules.cursor]
  const userTokens = userRules.reduce((sum, r) => sum + r.tokenCount, 0)
  const tokenStatus = getTokenStatus(userTokens)
  const activeCount = groupedRules.active.length
  const cursorCount = groupedRules.cursor.length

  return (
    <div className="page-container">
      {/* ページヘッダー */}
      <div className="page-header">
        <h1 className="page-title">Rules</h1>
        <p className="page-subtitle">
          プロジェクト固有のルール。Claude の動作を制御するガードレールです。
        </p>
      </div>

      {/* ルール説明カード */}
      <div className="info-card">
        <div className="info-card-header">
          <span className="info-card-icon">📜</span>
          <span className="info-card-title">Rules とは</span>
        </div>
        <div className="info-card-content">
          <p>
            <strong>.claude/rules/</strong> に配置されたルールファイル。Claude のセッションで自動適用され、動作を制御します。
          </p>
        </div>
      </div>

      {/* サマリーカード */}
      <div className="summary-card">
        <div className="summary-stats">
          <div className="summary-stat">
            <span className="summary-stat-icon">✅</span>
            <div className="summary-stat-content">
              <span className="summary-stat-value">{activeCount}</span>
              <span className="summary-stat-label">アクティブ</span>
            </div>
          </div>
          {cursorCount > 0 && (
            <div className="summary-stat">
              <span className="summary-stat-icon">🖱️</span>
              <div className="summary-stat-content">
                <span className="summary-stat-value">{cursorCount}</span>
                <span className="summary-stat-label">Cursor</span>
              </div>
            </div>
          )}
          <div className="summary-stat">
            <span className="summary-stat-icon">📝</span>
            <div className="summary-stat-content">
              <span className="summary-stat-value" style={{ color: tokenStatus.color }}>
                {userTokens > 1000
                  ? `${Math.round(userTokens / 1000)}K`
                  : userTokens}
              </span>
              <span className="summary-stat-label">トークン（{tokenStatus.label}）</span>
            </div>
          </div>
        </div>
        <div className="summary-hint" style={{ color: tokenStatus.color }}>
          {tokenStatus.hint}
        </div>
      </div>

      {/* コンフリクト警告 */}
      {rules.conflicts.length > 0 && (
        <div className="alert alert-error">
          <span className="alert-icon">⚠️</span>
          <div className="alert-content">
            <div className="alert-title">コンフリクト検出</div>
            <div className="alert-desc">
              {rules.conflicts.length} 件のルールコンフリクトが見つかりました。確認してください。
            </div>
          </div>
        </div>
      )}

      {/* カテゴリ別ルール一覧（テンプレートは内部用のため非表示） */}
      <div className="rules-categories">
        {(['active', 'cursor'] as const).map((category: RuleCategory) => {
          const categoryRules: Rule[] = groupedRules[category]
          if (categoryRules.length === 0) return null

          const info: CategoryInfoItem = categoryInfo[category]
          const isExpanded = expandedCategories.has(category)
          const categoryTokens = categoryRules.reduce((sum, r) => sum + r.tokenCount, 0)

          return (
            <div key={category} className={`rules-category rules-category-${info.importance}`}>
              <button
                className="rules-category-header"
                onClick={() => toggleCategory(category)}
              >
                <div className="rules-category-info">
                  <span className="rules-category-icon">{info.icon}</span>
                  <span className="rules-category-name">{info.title}</span>
                  <span className="rules-category-count">{categoryRules.length}</span>
                </div>
                <div className="rules-category-meta">
                  <span className="rules-category-desc">{info.desc}</span>
                  <span className="rules-category-tokens">{categoryTokens.toLocaleString()} tokens</span>
                  <span className="rules-category-chevron">{isExpanded ? '▼' : '▶'}</span>
                </div>
              </button>

              {isExpanded && (
                <div className="rules-list">
                  {categoryRules.map(rule => {
                    // プレフィックスを除去した名前
                    const displayName = rule.name
                      .replace('[テンプレート] ', '')
                      .replace('[Cursor] ', '')

                    return (
                      <div key={rule.path} className="rule-item">
                        <div className="rule-header">
                          <span className="rule-name">{displayName}</span>
                          <span className="rule-tokens">{rule.tokenCount.toLocaleString()} tokens</span>
                        </div>
                        <pre className="rule-preview">
                          {rule.content.slice(0, 300)}
                          {rule.content.length > 300 && '...'}
                        </pre>
                      </div>
                    )
                  })}
                </div>
              )}
            </div>
          )
        })}
      </div>

      {userRules.length === 0 && (
        <div className="empty-state">
          <div className="empty-state-icon">📜</div>
          <h3 className="empty-state-title">Rules がありません</h3>
          <p className="empty-state-desc">
            .claude/rules/ にプロジェクト固有のルールを追加してください
          </p>
        </div>
      )}
    </div>
  )
}
