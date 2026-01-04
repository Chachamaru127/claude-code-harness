import { useState, useEffect, useRef, useCallback, useMemo } from 'react'
import { fetchUsage, fetchSkills, fetchCommands } from '../lib/api.ts'
import { useProject } from '../App.tsx'
import { LoadingState } from './shared/index.ts'
import { formatRelativeTime, formatFullDate } from '../lib/dateUtils.ts'
import type { UsageResponse, UsageEntry, Skill, Command } from '../../shared/types.ts'

// ============================================================
// Usage Metadata - タイプ情報
// ============================================================

type UsageType = 'skill' | 'command' | 'agent'

interface TypeMetadata {
  icon: string
  label: string
  description: string
  color: string
  bgColor: string
}

const typeMetadata: Record<UsageType, TypeMetadata> = {
  skill: {
    icon: '⚡',
    label: 'スキル',
    description: 'ワークフロートリガーで自動起動される機能モジュール',
    color: '#2563eb',
    bgColor: '#eff6ff'
  },
  command: {
    icon: '🎯',
    label: 'コマンド',
    description: 'スラッシュコマンドで呼び出す機能',
    color: '#16a34a',
    bgColor: '#f0fdf4'
  },
  agent: {
    icon: '🤖',
    label: 'エージェント',
    description: 'Task tool で起動される自律型サブエージェント',
    color: '#9333ea',
    bgColor: '#faf5ff'
  }
}

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

// ============================================================
// Components
// ============================================================

/**
 * Detail Modal (Hooks format)
 */
interface DetailModalProps {
  isOpen: boolean
  onClose: () => void
  type: UsageType
  name: string
  entry: UsageEntry
  description?: string
}

function DetailModal({ isOpen, onClose, type, name, entry, description }: DetailModalProps) {
  const modalRef = useRef<HTMLDivElement>(null)
  const closeButtonRef = useRef<HTMLButtonElement>(null)
  const previousActiveElement = useRef<HTMLElement | null>(null)
  const metadata = typeMetadata[type]

  useEffect(() => {
    if (!isOpen) return

    previousActiveElement.current = document.activeElement as HTMLElement
    closeButtonRef.current?.focus()

    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        onClose()
        return
      }

      if (e.key === 'Tab' && modalRef.current) {
        const focusableElements = modalRef.current.querySelectorAll<HTMLElement>(
          'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])'
        )
        const firstElement = focusableElements[0]
        const lastElement = focusableElements[focusableElements.length - 1]

        if (e.shiftKey && document.activeElement === firstElement) {
          e.preventDefault()
          lastElement?.focus()
        } else if (!e.shiftKey && document.activeElement === lastElement) {
          e.preventDefault()
          firstElement?.focus()
        }
      }
    }

    document.addEventListener('keydown', handleKeyDown)
    return () => document.removeEventListener('keydown', handleKeyDown)
  }, [isOpen, onClose])

  useEffect(() => {
    if (!isOpen && previousActiveElement.current) {
      previousActiveElement.current.focus()
    }
  }, [isOpen])

  if (!isOpen) return null

  return (
    <div className="modal-overlay" onClick={onClose} role="presentation">
      <div
        ref={modalRef}
        className="modal-content"
        onClick={e => e.stopPropagation()}
        role="dialog"
        aria-modal="true"
        aria-labelledby="usage-modal-title"
      >
        <div className="modal-header">
          <div className="modal-title" id="usage-modal-title">
            <span className="modal-icon" aria-hidden="true">{metadata.icon}</span>
            <span>{name}</span>
          </div>
          <button
            ref={closeButtonRef}
            className="modal-close"
            onClick={onClose}
            aria-label="閉じる"
          >
            ✕
          </button>
        </div>
        <div className="modal-body">
          {/* Type Badge */}
          <div
            className="hook-purpose-badge"
            style={{ backgroundColor: metadata.bgColor, color: metadata.color }}
          >
            <span>{metadata.icon}</span>
            <span>{metadata.label}</span>
          </div>

          {/* Description */}
          <div className="modal-description">
            <h4>説明</h4>
            {description ? (
              <p>{description.replace(/^"|"$/g, '')}</p>
            ) : (
              <p className="modal-no-description">説明がありません</p>
            )}
          </div>

          {/* Type Info Box */}
          <div className="hook-type-info-box">
            <div className="hook-type-info-header">
              <span>{metadata.icon}</span>
              <span>{metadata.label}</span>
            </div>
            <p className="hook-type-info-desc">{metadata.description}</p>
          </div>

          {/* Usage Stats */}
          <div className="modal-description">
            <h4>使用統計</h4>
            <div className="hook-type-info-box" style={{ marginTop: '0.5rem' }}>
              <div className="hook-type-info-timing">
                <span className="hook-timing-label">使用回数:</span>
                <span className="hook-timing-value">{entry.count}回</span>
              </div>
              <div className="hook-type-info-timing">
                <span className="hook-timing-label">最終使用:</span>
                <span className="hook-timing-value">{entry.lastUsed ? formatFullDate(entry.lastUsed) : '未使用'}</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}

/**
 * Usage summary card (horizontal layout)
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
 * Top usage cards (card format for all types)
 */
function TopUsageCards({ title, items, onItemClick, descriptions, type }: {
  title: string
  items: Array<[string, UsageEntry]>
  onItemClick: (name: string, entry: UsageEntry) => void
  descriptions?: Map<string, string>
  type: UsageType
}) {
  const metadata = typeMetadata[type]

  if (items.length === 0) {
    return (
      <div className="usage-cards-container">
        <h3 className="usage-cards-title">{title}</h3>
        <div className="usage-cards-empty">データがありません</div>
      </div>
    )
  }

  return (
    <div className="usage-cards-container">
      <h3 className="usage-cards-title">{title}</h3>
      <div className="usage-cards-grid" role="list">
        {items.map(([name, entry]) => {
          const description = descriptions?.get(name.toLowerCase())
          return (
            <div
              key={name}
              className="hook-card"
              onClick={() => onItemClick(name, entry)}
              onKeyDown={(e) => {
                if (e.key === 'Enter' || e.key === ' ') {
                  e.preventDefault()
                  onItemClick(name, entry)
                }
              }}
              role="listitem"
              tabIndex={0}
              aria-label={`${name} の詳細を表示`}
            >
              <div className="hook-card-header">
                <div className="hook-card-title">
                  <span className="hook-card-icon">{metadata.icon}</span>
                  <span className="hook-card-name">{name}</span>
                </div>
                <span
                  className="hook-card-purpose"
                  style={{ backgroundColor: metadata.bgColor, color: metadata.color }}
                >
                  {entry.count}回
                </span>
              </div>
              <p className="hook-card-desc">
                {description || '説明なし'}
              </p>
              <div className="hook-card-footer">
                <span className="hook-card-matcher">
                  <span className="hook-card-matcher-label">最終:</span>
                  <code>{entry.lastUsed ? formatRelativeTime(entry.lastUsed) : '未使用'}</code>
                </span>
              </div>
            </div>
          )
        })}
      </div>
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
      <div className="alert alert-success">
        <span className="alert-icon">✓</span>
        <div className="alert-content">
          <div className="alert-title">すべてのコンポーネントが活用されています</div>
          <div className="alert-desc">未使用または非アクティブなアイテムはありません</div>
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
    <div className="alert alert-warning">
      <span className="alert-icon">💡</span>
      <div className="alert-content">
        <div className="alert-title">クリーンアップ提案</div>
        <div className="alert-desc">
          以下のアイテムは30日以上使用されていません: {suggestions.join(', ')}
        </div>
      </div>
    </div>
  )
}

// ============================================================
// Main Component
// ============================================================

export function UsageManager() {
  const [usage, setUsage] = useState<UsageResponse | null>(null)
  const [skills, setSkills] = useState<Skill[]>([])
  const [commands, setCommands] = useState<Command[]>([])
  const [loading, setLoading] = useState(true)
  const [activeTab, setActiveTab] = useState<UsageType>('skill')
  const { activeProject } = useProject()
  const projectPath = activeProject?.path

  // Modal state
  const [modalOpen, setModalOpen] = useState(false)
  const [modalType, setModalType] = useState<UsageType>('skill')
  const [modalName, setModalName] = useState('')
  const [modalEntry, setModalEntry] = useState<UsageEntry>({ count: 0, lastUsed: null })
  const [modalDescription, setModalDescription] = useState<string | undefined>()

  // Race Condition 対策
  const requestIdRef = useRef(0)

  useEffect(() => {
    const currentRequestId = ++requestIdRef.current
    setLoading(true)

    Promise.all([
      fetchUsage(projectPath),
      fetchSkills(projectPath),
      fetchCommands().catch(() => ({ commands: [] }))
    ]).then(([usageData, skillsData, commandsData]) => {
      if (currentRequestId !== requestIdRef.current) return

      setUsage(usageData)
      setSkills(skillsData.skills)
      setCommands(commandsData.commands ?? [])
    }).finally(() => {
      if (currentRequestId === requestIdRef.current) {
        setLoading(false)
      }
    })
  }, [projectPath])

  // Build description maps
  const skillDescriptions = useMemo(() => {
    const map = new Map<string, string>()
    for (const skill of skills) {
      if (skill.description) {
        map.set(skill.name.toLowerCase(), skill.description)
        const parts = skill.name.split('/')
        const firstPart = parts[0]
        if (firstPart) {
          map.set(firstPart.toLowerCase(), skill.description)
        }
      }
    }
    for (const cmd of commands) {
      if (cmd.description) {
        map.set(cmd.name.toLowerCase(), cmd.description)
      }
    }
    return map
  }, [skills, commands])

  const commandDescriptions = useMemo(() => {
    const map = new Map<string, string>()
    for (const cmd of commands) {
      if (cmd.description) {
        map.set(cmd.name.toLowerCase(), cmd.description)
      }
    }
    return map
  }, [commands])

  const agentDescriptionsMap = useMemo(() => {
    const map = new Map<string, string>()
    for (const [name, desc] of Object.entries(agentDescriptions)) {
      map.set(name.toLowerCase(), desc)
    }
    return map
  }, [])

  const handleItemClick = useCallback((type: UsageType, name: string, entry: UsageEntry) => {
    setModalType(type)
    setModalName(name)
    setModalEntry(entry)
    setModalOpen(true)

    if (type === 'skill') {
      setModalDescription(skillDescriptions.get(name.toLowerCase()))
    } else if (type === 'command') {
      setModalDescription(commandDescriptions.get(name.toLowerCase()) || `/${name} コマンド`)
    } else {
      setModalDescription(agentDescriptions[name] || 'エージェント')
    }
  }, [skillDescriptions, commandDescriptions])

  // タブキーボードナビゲーション
  const handleTabKeyDown = useCallback((e: React.KeyboardEvent<HTMLDivElement>) => {
    const tabs: UsageType[] = ['skill', 'command', 'agent']
    const currentIndex = tabs.indexOf(activeTab)

    if (e.key === 'ArrowRight' || e.key === 'ArrowDown') {
      e.preventDefault()
      const nextIndex = (currentIndex + 1) % tabs.length
      const nextTab = tabs[nextIndex]
      if (nextTab) {
        setActiveTab(nextTab)
        document.getElementById(`tab-${nextTab}`)?.focus()
      }
    } else if (e.key === 'ArrowLeft' || e.key === 'ArrowUp') {
      e.preventDefault()
      const prevIndex = (currentIndex - 1 + tabs.length) % tabs.length
      const prevTab = tabs[prevIndex]
      if (prevTab) {
        setActiveTab(prevTab)
        document.getElementById(`tab-${prevTab}`)?.focus()
      }
    }
  }, [activeTab])

  // Calculate recently used stats
  const recentlyUsedStats = useMemo(() => {
    if (!usage?.data) {
      return { skillsUsedRecently: 0, commandsUsedRecently: 0, agentsUsedRecently: 0 }
    }
    const data = usage.data

    const calcRecent = (entries: Record<string, UsageEntry>) => {
      return Object.values(entries).filter(e => {
        if (!e.lastUsed) return false
        const daysDiff = (Date.now() - new Date(e.lastUsed).getTime()) / (1000 * 60 * 60 * 24)
        return daysDiff <= 7
      }).length
    }

    return {
      skillsUsedRecently: calcRecent(data.skills),
      commandsUsedRecently: calcRecent(data.commands),
      agentsUsedRecently: calcRecent(data.agents)
    }
  }, [usage?.data])

  if (loading) {
    return <LoadingState message="使用状況を読み込み中..." />
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

  return (
    <div className="page-container">
      {/* Page Header */}
      <div className="page-header">
        <h1 className="page-title">Usage</h1>
        <p className="page-subtitle">
          Skills、Commands、Agents の使用状況を追跡し、最適化の提案を表示します。
        </p>
      </div>

      {/* Summary Cards (horizontal grid) */}
      <div className="usage-summary-grid">
        <UsageSummaryCard
          title="Skills"
          icon="⚡"
          total={skills.length}
          unused={Math.max(0, skills.length - Object.keys(usage.data?.skills || {}).length)}
          usedRecently={recentlyUsedStats.skillsUsedRecently}
        />
        <UsageSummaryCard
          title="Commands"
          icon="🎯"
          total={commands.length}
          unused={Math.max(0, commands.length - Object.keys(usage.data?.commands || {}).length)}
          usedRecently={recentlyUsedStats.commandsUsedRecently}
        />
        <UsageSummaryCard
          title="Agents"
          icon="🤖"
          total={6}
          unused={Math.max(0, 6 - Object.keys(usage.data?.agents || {}).length)}
          usedRecently={recentlyUsedStats.agentsUsedRecently}
        />
      </div>

      {/* Cleanup Suggestions */}
      <CleanupSuggestions usage={usage} />

      {/* Tab Navigation (horizontal) */}
      <div
        className="usage-tabs"
        role="tablist"
        aria-label="使用状況カテゴリ"
        onKeyDown={handleTabKeyDown}
      >
        <button
          className={`usage-tab ${activeTab === 'skill' ? 'usage-tab-active' : ''}`}
          onClick={() => setActiveTab('skill')}
          role="tab"
          id="tab-skill"
          aria-selected={activeTab === 'skill'}
          aria-controls="tabpanel-skill"
          tabIndex={activeTab === 'skill' ? 0 : -1}
        >
          <span aria-hidden="true">⚡</span> Skills ({usage.topSkills.length})
        </button>
        <button
          className={`usage-tab ${activeTab === 'command' ? 'usage-tab-active' : ''}`}
          onClick={() => setActiveTab('command')}
          role="tab"
          id="tab-command"
          aria-selected={activeTab === 'command'}
          aria-controls="tabpanel-command"
          tabIndex={activeTab === 'command' ? 0 : -1}
        >
          <span aria-hidden="true">🎯</span> Commands ({usage.topCommands.length})
        </button>
        <button
          className={`usage-tab ${activeTab === 'agent' ? 'usage-tab-active' : ''}`}
          onClick={() => setActiveTab('agent')}
          role="tab"
          id="tab-agent"
          aria-selected={activeTab === 'agent'}
          aria-controls="tabpanel-agent"
          tabIndex={activeTab === 'agent' ? 0 : -1}
        >
          <span aria-hidden="true">🤖</span> Agents ({usage.topAgents.length})
        </button>
      </div>

      {/* Tab Content */}
      <div className="usage-tab-content">
        {activeTab === 'skill' && (
          <div role="tabpanel" id="tabpanel-skill" aria-labelledby="tab-skill">
            <TopUsageCards
              title="Top Skills"
              items={usage.topSkills}
              onItemClick={(name, entry) => handleItemClick('skill', name, entry)}
              descriptions={skillDescriptions}
              type="skill"
            />
          </div>
        )}
        {activeTab === 'command' && (
          <div role="tabpanel" id="tabpanel-command" aria-labelledby="tab-command">
            <TopUsageCards
              title="Top Commands"
              items={usage.topCommands}
              onItemClick={(name, entry) => handleItemClick('command', name, entry)}
              descriptions={commandDescriptions}
              type="command"
            />
          </div>
        )}
        {activeTab === 'agent' && (
          <div role="tabpanel" id="tabpanel-agent" aria-labelledby="tab-agent">
            <TopUsageCards
              title="Top Agents"
              items={usage.topAgents}
              onItemClick={(name, entry) => handleItemClick('agent', name, entry)}
              descriptions={agentDescriptionsMap}
              type="agent"
            />
          </div>
        )}
      </div>

      {/* Last Updated */}
      {usage.data?.updatedAt && (
        <div className="usage-footer">
          最終更新: {new Date(usage.data.updatedAt).toLocaleString('ja-JP')}
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
      />
    </div>
  )
}
