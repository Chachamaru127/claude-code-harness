import { useState, useEffect } from 'react'
import { fetchSkills } from '../lib/api.ts'
import type { SkillsResponse, Skill } from '../../shared/types.ts'

/**
 * トークン使用量のステータスを取得
 */
function getTokenStatus(tokens: number): { label: string; color: string; hint: string } {
  if (tokens > 15000) return { label: '過多', color: '#ef4444', hint: 'コンテキストを圧迫する可能性あり' }
  if (tokens > 10000) return { label: '多め', color: '#f59e0b', hint: '整理を検討してください' }
  return { label: '適正', color: '#22c55e', hint: '良好な状態です' }
}

/**
 * スキルをカテゴリ別にグループ化
 */
function groupSkillsByCategory(skills: Skill[]): Record<string, Skill[]> {
  const groups: Record<string, Skill[]> = {}
  for (const skill of skills) {
    // Extract category from path (e.g., "impl/doc" -> "impl")
    const category = skill.name.split('/')[0] || 'その他'
    if (!groups[category]) groups[category] = []
    groups[category].push(skill)
  }
  return groups
}

/**
 * カテゴリ説明
 */
const categoryDescriptions: Record<string, { icon: string; desc: string }> = {
  impl: { icon: '🔨', desc: '実装・機能追加' },
  review: { icon: '🔍', desc: 'コードレビュー' },
  verify: { icon: '✅', desc: 'ビルド検証・テスト' },
  setup: { icon: '⚙️', desc: 'プロジェクト初期化' },
  '2agent': { icon: '👥', desc: '2エージェント設定' },
  memory: { icon: '🧠', desc: 'メモリ管理' },
  principles: { icon: '📖', desc: '開発原則' },
  auth: { icon: '🔐', desc: '認証・決済' },
  deploy: { icon: '🚀', desc: 'デプロイ' },
  ui: { icon: '🎨', desc: 'UI生成' },
  workflow: { icon: '🔄', desc: 'ワークフロー' },
  docs: { icon: '📄', desc: 'ドキュメント' },
  ci: { icon: '🔧', desc: 'CI/CD' },
  maintenance: { icon: '🧹', desc: 'メンテナンス' },
}

export function SkillsManager() {
  const [skills, setSkills] = useState<SkillsResponse | null>(null)
  const [loading, setLoading] = useState(true)
  const [expandedCategories, setExpandedCategories] = useState<Set<string>>(new Set())

  useEffect(() => {
    fetchSkills().then(setSkills).finally(() => setLoading(false))
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
          <span>Skills を読み込み中...</span>
        </div>
      </div>
    )
  }

  if (!skills) {
    return (
      <div className="page-container">
        <div className="health-error">Skills の取得に失敗しました</div>
      </div>
    )
  }

  const tokenStatus = getTokenStatus(skills.totalTokens)
  const groupedSkills = groupSkillsByCategory(skills.skills)
  const categories = Object.keys(groupedSkills).sort()

  return (
    <div className="page-container">
      {/* ページヘッダー */}
      <div className="page-header">
        <h1 className="page-title">Skills</h1>
        <p className="page-subtitle">
          Claude が使用できるスキル一覧。スキルはワークフローのトリガーで自動起動されます。
        </p>
      </div>

      {/* サマリーカード */}
      <div className="summary-card">
        <div className="summary-stats">
          <div className="summary-stat">
            <span className="summary-stat-icon">⚡</span>
            <div className="summary-stat-content">
              <span className="summary-stat-value">{skills.skills.length}</span>
              <span className="summary-stat-label">スキル数</span>
            </div>
          </div>
          <div className="summary-stat">
            <span className="summary-stat-icon">📊</span>
            <div className="summary-stat-content">
              <span className="summary-stat-value">{categories.length}</span>
              <span className="summary-stat-label">カテゴリ</span>
            </div>
          </div>
          <div className="summary-stat">
            <span className="summary-stat-icon">📝</span>
            <div className="summary-stat-content">
              <span className="summary-stat-value" style={{ color: tokenStatus.color }}>
                {skills.totalTokens > 1000
                  ? `${Math.round(skills.totalTokens / 1000)}K`
                  : skills.totalTokens}
              </span>
              <span className="summary-stat-label">トークン（{tokenStatus.label}）</span>
            </div>
          </div>
        </div>
        <div className="summary-hint" style={{ color: tokenStatus.color }}>
          {tokenStatus.hint}
        </div>
      </div>

      {/* 未使用スキル警告 or 追跡ステータス */}
      {skills.usageTrackingAvailable ? (
        skills.unusedSkills.length > 0 && (
          <div className="alert alert-warning">
            <span className="alert-icon">💡</span>
            <div className="alert-content">
              <div className="alert-title">未使用の Skills</div>
              <div className="alert-desc">
                以下のスキルは最近使用されていません。削除を検討してください:
                <span className="font-mono">{skills.unusedSkills.join(', ')}</span>
              </div>
              {skills.usageTrackingMessage && (
                <div className="alert-hint">📊 {skills.usageTrackingMessage}</div>
              )}
            </div>
          </div>
        )
      ) : (
        <div className="alert alert-info">
          <span className="alert-icon">ℹ️</span>
          <div className="alert-content">
            <div className="alert-title">利用履歴追跡</div>
            <div className="alert-desc">
              {skills.usageTrackingMessage || 'session-log がないため、スキル利用履歴を追跡できません。'}
            </div>
          </div>
        </div>
      )}

      {/* カテゴリ別スキル一覧 */}
      <div className="skills-categories">
        {categories.map(category => {
          const categorySkills = groupedSkills[category] || []
          const categoryInfo = categoryDescriptions[category] || { icon: '📁', desc: category }
          const isExpanded = expandedCategories.has(category)
          const categoryTokens = categorySkills.reduce((sum, s) => sum + s.tokenCount, 0)

          return (
            <div key={category} className="skills-category">
              <button
                className="skills-category-header"
                onClick={() => toggleCategory(category)}
              >
                <div className="skills-category-info">
                  <span className="skills-category-icon">{categoryInfo.icon}</span>
                  <span className="skills-category-name">{category}</span>
                  <span className="skills-category-count">{categorySkills.length}</span>
                </div>
                <div className="skills-category-meta">
                  <span className="skills-category-desc">{categoryInfo.desc}</span>
                  <span className="skills-category-tokens">{categoryTokens.toLocaleString()} tokens</span>
                  <span className="skills-category-chevron">{isExpanded ? '▼' : '▶'}</span>
                </div>
              </button>

              {isExpanded && (
                <div className="skills-list">
                  {categorySkills.map(skill => (
                    <div key={skill.path} className="skill-item">
                      <div className="skill-info">
                        <div className="skill-name">{skill.name}</div>
                        <div className="skill-desc">{skill.description || '説明なし'}</div>
                      </div>
                      <div className="skill-meta">
                        <span className="skill-tokens">{skill.tokenCount.toLocaleString()} tokens</span>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>
          )
        })}
      </div>

      {skills.skills.length === 0 && (
        <div className="empty-state">
          <div className="empty-state-icon">⚡</div>
          <h3 className="empty-state-title">Skills がありません</h3>
          <p className="empty-state-desc">
            skills/ ディレクトリに Skill ファイルを追加してください
          </p>
        </div>
      )}
    </div>
  )
}
