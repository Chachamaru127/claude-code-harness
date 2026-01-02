import { useState, useEffect } from 'react'
import { fetchUsage, fetchSkills } from '../lib/api.ts'
import type { UsageResponse, UsageEntry, Skill } from '../../shared/types.ts'

/**
 * Format date to relative time (e.g., "3日前")
 */
function formatRelativeTime(dateStr: string | null): string {
  if (!dateStr) return '未使用'
  const date = new Date(dateStr)
  const now = new Date()
  const diffMs = now.getTime() - date.getTime()
  const diffDays = Math.floor(diffMs / (1000 * 60 * 60 * 24))

  if (diffDays === 0) return '今日'
  if (diffDays === 1) return '昨日'
  if (diffDays < 7) return `${diffDays}日前`
  if (diffDays < 30) return `${Math.floor(diffDays / 7)}週間前`
  return `${Math.floor(diffDays / 30)}ヶ月前`
}

/**
 * Format date to full datetime
 */
function formatFullDate(dateStr: string | null): string {
  if (!dateStr) return '未使用'
  return new Date(dateStr).toLocaleString('ja-JP', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit'
  })
}

/**
 * Detail modal for usage items
 */
interface DetailModalProps {
  isOpen: boolean
  onClose: () => void
  type: 'skill' | 'command' | 'agent'
  name: string
  entry: UsageEntry
  description?: string
  loading?: boolean
}

function DetailModal({ isOpen, onClose, type, name, entry, description, loading }: DetailModalProps) {
  if (!isOpen) return null

  const typeLabels = {
    skill: 'スキル',
    command: 'コマンド',
    agent: 'エージェント'
  }

  const typeIcons = {
    skill: '⚡',
    command: '🎯',
    agent: '🤖'
  }

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal-content" onClick={e => e.stopPropagation()}>
        <div className="modal-header">
          <div className="modal-title">
            <span className="modal-icon">{typeIcons[type]}</span>
            <span>{name}</span>
          </div>
          <button className="modal-close" onClick={onClose}>×</button>
        </div>
        <div className="modal-body">
          <div className="modal-type-badge">{typeLabels[type]}</div>

          <div className="modal-stats">
            <div className="modal-stat">
              <span className="modal-stat-label">使用回数</span>
              <span className="modal-stat-value">{entry.count}回</span>
            </div>
            <div className="modal-stat">
              <span className="modal-stat-label">最終使用</span>
              <span className="modal-stat-value">{formatFullDate(entry.lastUsed)}</span>
            </div>
          </div>

          <div className="modal-description">
            <h4>説明</h4>
            {loading ? (
              <div className="modal-loading">読み込み中...</div>
            ) : description ? (
              <p>{description.replace(/^"|"$/g, '')}</p>
            ) : (
              <p className="modal-no-description">説明がありません</p>
            )}
          </div>
        </div>
      </div>
    </div>
  )
}

/**
 * Usage summary card
 */
function UsageSummaryCard({ title, icon, total, unused, usedRecently }: {
  title: string
  icon: string
  total: number
  unused: number
  usedRecently: number
}) {
  const usageRate = total > 0 ? Math.round(((total - unused) / total) * 100) : 0

  return (
    <div className="usage-summary-card">
      <div className="usage-summary-header">
        <span className="usage-summary-icon">{icon}</span>
        <span className="usage-summary-title">{title}</span>
      </div>
      <div className="usage-summary-stats">
        <div className="usage-stat">
          <span className="usage-stat-value">{total}</span>
          <span className="usage-stat-label">総数</span>
        </div>
        <div className="usage-stat">
          <span className="usage-stat-value" style={{ color: usedRecently > 0 ? '#22c55e' : '#6b7280' }}>
            {usedRecently}
          </span>
          <span className="usage-stat-label">最近使用</span>
        </div>
        <div className="usage-stat">
          <span className="usage-stat-value" style={{ color: unused > 0 ? '#f59e0b' : '#22c55e' }}>
            {unused}
          </span>
          <span className="usage-stat-label">未使用</span>
        </div>
      </div>
      <div className="usage-rate-bar">
        <div
          className="usage-rate-fill"
          style={{
            width: `${usageRate}%`,
            backgroundColor: usageRate > 70 ? '#22c55e' : usageRate > 40 ? '#f59e0b' : '#ef4444'
          }}
        />
      </div>
      <div className="usage-rate-label">利用率 {usageRate}%</div>
    </div>
  )
}

/**
 * Top usage items table
 */
function TopUsageTable({ title, items, onItemClick }: {
  title: string
  items: Array<[string, UsageEntry]>
  onItemClick: (name: string, entry: UsageEntry) => void
}) {
  if (items.length === 0) {
    return (
      <div className="usage-table-container">
        <h3 className="usage-table-title">{title}</h3>
        <div className="usage-table-empty">データがありません</div>
      </div>
    )
  }

  return (
    <div className="usage-table-container">
      <h3 className="usage-table-title">{title}</h3>
      <table className="usage-table">
        <thead>
          <tr>
            <th>名前</th>
            <th>使用回数</th>
            <th>最終使用</th>
          </tr>
        </thead>
        <tbody>
          {items.map(([name, entry]) => (
            <tr
              key={name}
              className="usage-table-row-clickable"
              onClick={() => onItemClick(name, entry)}
            >
              <td className="usage-table-name">{name}</td>
              <td className="usage-table-count">{entry.count}</td>
              <td className="usage-table-date">
                {formatRelativeTime(entry.lastUsed)}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}

/**
 * Cleanup suggestions panel
 */
function CleanupSuggestions({ usage }: { usage: UsageResponse }) {
  const cleanup = usage.cleanup
  if (!cleanup) return null

  const hasUnused = cleanup.summary.unusedSkillsCount > 0 ||
    cleanup.summary.unusedCommandsCount > 0 ||
    cleanup.summary.unusedAgentsCount > 0

  if (!hasUnused) {
    return (
      <div className="cleanup-panel cleanup-panel-good">
        <span className="cleanup-icon">✓</span>
        <div className="cleanup-content">
          <div className="cleanup-title">すべてのコンポーネントが活用されています</div>
          <div className="cleanup-desc">未使用または非アクティブなアイテムはありません</div>
        </div>
      </div>
    )
  }

  const suggestions = [
    cleanup.summary.unusedSkillsCount > 0 && `${cleanup.summary.unusedSkillsCount}件の未使用スキル`,
    cleanup.summary.unusedCommandsCount > 0 && `${cleanup.summary.unusedCommandsCount}件の未使用コマンド`,
    cleanup.summary.unusedAgentsCount > 0 && `${cleanup.summary.unusedAgentsCount}件の未使用エージェント`,
  ].filter(Boolean)

  return (
    <div className="cleanup-panel cleanup-panel-warning">
      <span className="cleanup-icon">💡</span>
      <div className="cleanup-content">
        <div className="cleanup-title">クリーンアップ提案</div>
        <div className="cleanup-desc">
          以下のアイテムは30日以上使用されていません:
        </div>
        <ul className="cleanup-list">
          {suggestions.map((s, i) => (
            <li key={i}>{s}</li>
          ))}
        </ul>
        <div className="cleanup-hint">
          不要なアイテムを削除してコンテキスト使用量を最適化しましょう
        </div>
      </div>
    </div>
  )
}

/**
 * Usage Manager Component
 * Displays usage statistics and cleanup suggestions
 */
export function UsageManager() {
  const [usage, setUsage] = useState<UsageResponse | null>(null)
  const [skills, setSkills] = useState<Skill[]>([])
  const [loading, setLoading] = useState(true)
  const [activeTab, setActiveTab] = useState<'skills' | 'commands' | 'agents'>('skills')

  // Modal state
  const [modalOpen, setModalOpen] = useState(false)
  const [modalType, setModalType] = useState<'skill' | 'command' | 'agent'>('skill')
  const [modalName, setModalName] = useState('')
  const [modalEntry, setModalEntry] = useState<UsageEntry>({ count: 0, lastUsed: null })
  const [modalDescription, setModalDescription] = useState<string | undefined>()
  const [modalLoading, setModalLoading] = useState(false)

  useEffect(() => {
    Promise.all([
      fetchUsage(),
      fetchSkills()
    ]).then(([usageData, skillsData]) => {
      setUsage(usageData)
      setSkills(skillsData.skills)
    }).finally(() => setLoading(false))
  }, [])

  const handleItemClick = (type: 'skill' | 'command' | 'agent', name: string, entry: UsageEntry) => {
    setModalType(type)
    setModalName(name)
    setModalEntry(entry)
    setModalOpen(true)
    setModalLoading(true)

    // Find description based on type
    if (type === 'skill') {
      // Look for the SKILL file matching the name (e.g., "impl/SKILL")
      const matchingSkill = skills.find(s =>
        s.name === `${name}/SKILL` ||
        s.name.startsWith(`${name}/`) ||
        s.name === name
      )
      setModalDescription(matchingSkill?.description)
    } else if (type === 'command') {
      // Commands don't have descriptions in the current data
      setModalDescription(`/${name} コマンド`)
    } else {
      // Agents
      const agentDescriptions: Record<string, string> = {
        'Explore': 'コードベースを探索し、ファイルやパターンを検索するエージェント',
        'Plan': 'ソフトウェアアーキテクト。実装計画を設計するエージェント',
        'general-purpose': '複雑なマルチステップタスクを自律的に処理する汎用エージェント',
        'project-analyzer': '新規/既存プロジェクト判定と技術スタック検出',
        'project-scaffolder': '指定スタックでプロジェクトを自動生成',
        'code-reviewer': 'セキュリティ/性能/品質を多角的にレビュー',
        'ci-cd-fixer': 'CI失敗時の診断・修正を安全第一で支援',
        'error-recovery': 'エラー復旧（原因切り分け→安全な修正→再検証）',
        'project-state-updater': 'Plans.md とセッション状態の同期・ハンドオフ支援'
      }
      setModalDescription(agentDescriptions[name] || 'エージェント')
    }
    setModalLoading(false)
  }

  if (loading) {
    return (
      <div className="page-container">
        <div className="flex items-center gap-4">
          <div className="spinner" />
          <span>使用状況を読み込み中...</span>
        </div>
      </div>
    )
  }

  if (!usage || !usage.available) {
    return (
      <div className="page-container">
        <div className="page-header">
          <h1 className="page-title">Usage</h1>
          <p className="page-subtitle">使用状況の追跡と分析</p>
        </div>
        <div className="empty-state">
          <div className="empty-state-icon">📊</div>
          <h3 className="empty-state-title">使用状況データがありません</h3>
          <p className="empty-state-desc">
            {usage?.message || 'Skills/Commands/Agents を使用すると自動的に記録されます。'}
          </p>
        </div>
      </div>
    )
  }

  const data = usage.data!
  const cleanup = usage.cleanup!

  // Calculate summary stats
  const skillsUsedRecently = Object.values(data.skills).filter(s => {
    if (!s.lastUsed) return false
    const daysDiff = (Date.now() - new Date(s.lastUsed).getTime()) / (1000 * 60 * 60 * 24)
    return daysDiff <= 7
  }).length

  const commandsUsedRecently = Object.values(data.commands).filter(c => {
    if (!c.lastUsed) return false
    const daysDiff = (Date.now() - new Date(c.lastUsed).getTime()) / (1000 * 60 * 60 * 24)
    return daysDiff <= 7
  }).length

  const agentsUsedRecently = Object.values(data.agents).filter(a => {
    if (!a.lastUsed) return false
    const daysDiff = (Date.now() - new Date(a.lastUsed).getTime()) / (1000 * 60 * 60 * 24)
    return daysDiff <= 7
  }).length

  return (
    <div className="page-container">
      {/* Page Header */}
      <div className="page-header">
        <h1 className="page-title">Usage</h1>
        <p className="page-subtitle">
          Skills、Commands、Agents の使用状況を追跡し、最適化の提案を表示します。
        </p>
      </div>

      {/* Summary Cards */}
      <div className="usage-summary-grid">
        <UsageSummaryCard
          title="Skills"
          icon="⚡"
          total={cleanup.summary.totalSkills}
          unused={cleanup.summary.unusedSkillsCount}
          usedRecently={skillsUsedRecently}
        />
        <UsageSummaryCard
          title="Commands"
          icon="🎯"
          total={cleanup.summary.totalCommands}
          unused={cleanup.summary.unusedCommandsCount}
          usedRecently={commandsUsedRecently}
        />
        <UsageSummaryCard
          title="Agents"
          icon="🤖"
          total={cleanup.summary.totalAgents}
          unused={cleanup.summary.unusedAgentsCount}
          usedRecently={agentsUsedRecently}
        />
      </div>

      {/* Cleanup Suggestions */}
      <CleanupSuggestions usage={usage} />

      {/* Tab Navigation */}
      <div className="usage-tabs">
        <button
          className={`usage-tab ${activeTab === 'skills' ? 'usage-tab-active' : ''}`}
          onClick={() => setActiveTab('skills')}
        >
          ⚡ Skills ({usage.topSkills.length})
        </button>
        <button
          className={`usage-tab ${activeTab === 'commands' ? 'usage-tab-active' : ''}`}
          onClick={() => setActiveTab('commands')}
        >
          🎯 Commands ({usage.topCommands.length})
        </button>
        <button
          className={`usage-tab ${activeTab === 'agents' ? 'usage-tab-active' : ''}`}
          onClick={() => setActiveTab('agents')}
        >
          🤖 Agents ({usage.topAgents.length})
        </button>
      </div>

      {/* Tab Content */}
      <div className="usage-tab-content">
        {activeTab === 'skills' && (
          <TopUsageTable
            title="Top Skills"
            items={usage.topSkills}
            onItemClick={(name, entry) => handleItemClick('skill', name, entry)}
          />
        )}
        {activeTab === 'commands' && (
          <TopUsageTable
            title="Top Commands"
            items={usage.topCommands}
            onItemClick={(name, entry) => handleItemClick('command', name, entry)}
          />
        )}
        {activeTab === 'agents' && (
          <TopUsageTable
            title="Top Agents"
            items={usage.topAgents}
            onItemClick={(name, entry) => handleItemClick('agent', name, entry)}
          />
        )}
      </div>

      {/* Last Updated */}
      {data.updatedAt && (
        <div className="usage-footer">
          最終更新: {new Date(data.updatedAt).toLocaleString('ja-JP')}
        </div>
      )}

      {/* Detail Modal */}
      <DetailModal
        isOpen={modalOpen}
        onClose={() => setModalOpen(false)}
        type={modalType}
        name={modalName}
        entry={modalEntry}
        description={modalDescription}
        loading={modalLoading}
      />
    </div>
  )
}
