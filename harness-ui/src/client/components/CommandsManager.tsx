import { useState, useCallback, useMemo, useRef, useEffect } from 'react'
import { fetchCommands } from '../lib/api.ts'
import { useProjectResource } from '../hooks/useProjectResource.ts'
import { LoadingState, ErrorState } from './shared/index.ts'
import type { Command } from '../../shared/types.ts'

// ============================================================
// Command Metadata - カテゴリ情報
// ============================================================

type CommandCategory = 'core' | 'optional'

interface CategoryMetadata {
  icon: string
  label: string
  description: string
  color: string
  bgColor: string
}

const categoryMetadata: Record<CommandCategory, CategoryMetadata> = {
  core: {
    icon: '🎯',
    label: 'コア',
    description: '主要なワークフローコマンド（Plan → Work → Review）',
    color: '#2563eb',
    bgColor: '#eff6ff'
  },
  optional: {
    icon: '🔧',
    label: 'オプション',
    description: 'セットアップや補助的な機能コマンド',
    color: '#16a34a',
    bgColor: '#f0fdf4'
  }
}

// ============================================================
// Components
// ============================================================

/**
 * Command Detail Modal
 */
interface CommandDetailModalProps {
  isOpen: boolean
  onClose: () => void
  command: Command | null
}

function CommandDetailModal({ isOpen, onClose, command }: CommandDetailModalProps) {
  const modalRef = useRef<HTMLDivElement>(null)
  const closeButtonRef = useRef<HTMLButtonElement>(null)
  const previousActiveElement = useRef<HTMLElement | null>(null)

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

  if (!isOpen || !command) return null

  const metadata = categoryMetadata[command.category]

  return (
    <div className="modal-overlay" onClick={onClose} role="presentation">
      <div
        ref={modalRef}
        className="modal-content"
        onClick={e => e.stopPropagation()}
        role="dialog"
        aria-modal="true"
        aria-labelledby="command-modal-title"
      >
        <div className="modal-header">
          <div className="modal-title" id="command-modal-title">
            <span className="modal-icon" aria-hidden="true">{metadata.icon}</span>
            <span>/{command.name}</span>
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
          {/* Category Badge */}
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
            {command.description ? (
              <p>{command.description}</p>
            ) : (
              <p className="modal-no-description">説明がありません</p>
            )}
          </div>

          {/* English Description */}
          {command.descriptionEn && (
            <div className="modal-description">
              <h4>Description (EN)</h4>
              <p>{command.descriptionEn}</p>
            </div>
          )}

          {/* Category Info Box */}
          <div className="hook-type-info-box">
            <div className="hook-type-info-header">
              <span>{metadata.icon}</span>
              <span>{metadata.label}</span>
            </div>
            <p className="hook-type-info-desc">{metadata.description}</p>
            <div className="hook-type-info-timing">
              <span className="hook-timing-label">使い方:</span>
              <span className="hook-timing-value">/{command.name}</span>
            </div>
          </div>

          {/* File Path */}
          <div className="modal-description">
            <h4>ファイルパス</h4>
            <pre className="hook-command-preview">{command.path}</pre>
          </div>
        </div>
      </div>
    </div>
  )
}

/**
 * Category Summary
 */
function CategorySummary({ commands }: { commands: Command[] }) {
  const categoryCounts = useMemo(() => {
    const counts: Record<CommandCategory, number> = {
      core: 0,
      optional: 0
    }
    for (const cmd of commands) {
      counts[cmd.category]++
    }
    return counts
  }, [commands])

  return (
    <div className="hooks-purpose-summary">
      {(Object.entries(categoryMetadata) as [CommandCategory, CategoryMetadata][]).map(([category, info]) => {
        const count = categoryCounts[category]
        if (count === 0) return null
        return (
          <div
            key={category}
            className="hooks-purpose-item"
            style={{ backgroundColor: info.bgColor, borderColor: info.color }}
          >
            <span className="hooks-purpose-icon">{info.icon}</span>
            <span className="hooks-purpose-label">{info.label}</span>
            <span className="hooks-purpose-count" style={{ color: info.color }}>{count}</span>
          </div>
        )
      })}
    </div>
  )
}

/**
 * Command Card
 */
function CommandCard({ command, onClick }: { command: Command; onClick: () => void }) {
  const metadata = categoryMetadata[command.category]

  return (
    <div
      className="hook-card"
      role="listitem"
      tabIndex={0}
      onClick={onClick}
      onKeyDown={(e) => {
        if (e.key === 'Enter' || e.key === ' ') {
          e.preventDefault()
          onClick()
        }
      }}
      aria-label={`/${command.name} の詳細を表示`}
    >
      <div className="hook-card-header">
        <div className="hook-card-title">
          <span className="hook-card-icon">{metadata.icon}</span>
          <span className="hook-card-name">/{command.name}</span>
        </div>
        <span
          className="hook-card-purpose"
          style={{ backgroundColor: metadata.bgColor, color: metadata.color }}
        >
          {metadata.label}
        </span>
      </div>
      <p className="hook-card-desc">
        {command.description || '説明なし'}
      </p>
      <div className="hook-card-footer">
        <span className="hook-card-matcher">
          <span className="hook-card-matcher-label">パス:</span>
          <code>{command.path.split('/').pop()}</code>
        </span>
      </div>
    </div>
  )
}

/**
 * Category Section Header
 */
function CategorySectionHeader({
  category,
  count,
  isExpanded,
  onToggle
}: {
  category: CommandCategory
  count: number
  isExpanded: boolean
  onToggle: () => void
}) {
  const metadata = categoryMetadata[category]

  return (
    <button
      className="hooks-type-header"
      onClick={onToggle}
      aria-expanded={isExpanded}
    >
      <div className="hooks-type-header-main">
        <span className="hooks-type-icon">{metadata.icon}</span>
        <div className="hooks-type-info">
          <span className="hooks-type-name">{metadata.label}</span>
          <span className="hooks-type-timing">{count} コマンド</span>
        </div>
        <span className="hooks-type-count">{count}</span>
      </div>
      <div className="hooks-type-header-desc">
        {metadata.description}
      </div>
      <span className="hooks-type-chevron" aria-hidden="true">{isExpanded ? '▼' : '▶'}</span>
    </button>
  )
}

// ============================================================
// Main Component
// ============================================================

export function CommandsManager() {
  const [expandedCategories, setExpandedCategories] = useState<Set<string>>(new Set(['core', 'optional']))
  const [selectedCommand, setSelectedCommand] = useState<Command | null>(null)
  const [modalOpen, setModalOpen] = useState(false)

  // Commands don't depend on project path (they're plugin-level)
  const { data: commandsData, loading, hasError } = useProjectResource(
    fetchCommands,
    undefined
  )

  const toggleCategory = useCallback((category: string) => {
    setExpandedCategories(prev => {
      const next = new Set(prev)
      if (next.has(category)) next.delete(category)
      else next.add(category)
      return next
    })
  }, [])

  const handleCommandClick = useCallback((command: Command) => {
    setSelectedCommand(command)
    setModalOpen(true)
  }, [])

  // Group commands by category
  const groupedCommands = useMemo(() => {
    if (!commandsData) return {}
    const groups: Record<string, Command[]> = {}
    for (const cmd of commandsData.commands) {
      const category = cmd.category
      if (!groups[category]) groups[category] = []
      groups[category].push(cmd)
    }
    return groups
  }, [commandsData])

  const categoryOrder: CommandCategory[] = ['core', 'optional']

  const sortedCategories = useMemo(() => {
    const categories = Object.keys(groupedCommands) as CommandCategory[]
    return categories.sort((a, b) => {
      const aIndex = categoryOrder.indexOf(a)
      const bIndex = categoryOrder.indexOf(b)
      if (aIndex === -1 && bIndex === -1) return a.localeCompare(b)
      if (aIndex === -1) return 1
      if (bIndex === -1) return -1
      return aIndex - bIndex
    })
  }, [groupedCommands])

  if (loading) {
    return <LoadingState message="Commands を読み込み中..." />
  }

  if (!commandsData || hasError) {
    return <ErrorState message="Commands の取得に失敗しました" />
  }

  return (
    <div className="page-container">
      {/* Page Header */}
      <div className="page-header">
        <h1 className="page-title">Commands</h1>
        <p className="page-subtitle">
          スラッシュコマンド一覧。チャットで「/コマンド名」と入力して実行します。
        </p>
      </div>

      {/* Summary Card */}
      <div className="summary-card">
        <div className="summary-stats">
          <div className="summary-stat">
            <span className="summary-stat-icon">📋</span>
            <div className="summary-stat-content">
              <span className="summary-stat-value">{commandsData.commands.length}</span>
              <span className="summary-stat-label">コマンド数</span>
            </div>
          </div>
          <div className="summary-stat">
            <span className="summary-stat-icon">📊</span>
            <div className="summary-stat-content">
              <span className="summary-stat-value">{sortedCategories.length}</span>
              <span className="summary-stat-label">カテゴリ</span>
            </div>
          </div>
        </div>

        {/* Category breakdown */}
        <CategorySummary commands={commandsData.commands} />

        <div className="summary-hint">
          コマンドは commands/core/ と commands/optional/ に定義されています。
        </div>
      </div>

      {/* Commands by Category */}
      <div className="hooks-type-sections">
        {sortedCategories.map(category => {
          const categoryCommands = groupedCommands[category] || []
          const isExpanded = expandedCategories.has(category)

          return (
            <div key={category} className="hooks-type-section">
              <CategorySectionHeader
                category={category as CommandCategory}
                count={categoryCommands.length}
                isExpanded={isExpanded}
                onToggle={() => toggleCategory(category)}
              />

              {isExpanded && (
                <div className="hooks-list">
                  {categoryCommands.map((cmd) => (
                    <CommandCard
                      key={cmd.path}
                      command={cmd}
                      onClick={() => handleCommandClick(cmd)}
                    />
                  ))}
                </div>
              )}
            </div>
          )
        })}
      </div>

      {commandsData.commands.length === 0 && (
        <div className="empty-state">
          <div className="empty-state-icon">📋</div>
          <h3 className="empty-state-title">Commands がありません</h3>
          <p className="empty-state-desc">
            commands/ ディレクトリにコマンドファイルを追加してください
          </p>
        </div>
      )}

      {/* Command Detail Modal */}
      <CommandDetailModal
        isOpen={modalOpen}
        onClose={() => setModalOpen(false)}
        command={selectedCommand}
      />
    </div>
  )
}
