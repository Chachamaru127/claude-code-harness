import { useState, useCallback, useMemo, useRef, useEffect } from 'react'
import { fetchRules } from '../lib/api.ts'
import { useProject } from '../App.tsx'
import { useProjectResource } from '../hooks/useProjectResource.ts'
import { LoadingState, ErrorState } from './shared/index.ts'
import { getTokenStatus } from '../lib/tokenStatus.ts'
import type { Rule } from '../../shared/types.ts'

// ============================================================
// Rule Metadata - カテゴリ情報
// ============================================================

type RuleCategory = 'active' | 'cursor' | 'template'

interface CategoryMetadata {
  icon: string
  label: string
  description: string
  color: string
  bgColor: string
  importance: 'high' | 'medium' | 'low'
}

const categoryMetadata: Record<RuleCategory, CategoryMetadata> = {
  active: {
    icon: '✅',
    label: 'アクティブ',
    description: '.claude/rules/ から読み込まれる有効ルール。Claude の動作を制御します。',
    color: '#16a34a',
    bgColor: '#f0fdf4',
    importance: 'high'
  },
  cursor: {
    icon: '🖱️',
    label: 'Cursor',
    description: '.cursor/rules/ のCursor連携ルール。Cursor との統合設定です。',
    color: '#8b5cf6',
    bgColor: '#f5f3ff',
    importance: 'medium'
  },
  template: {
    icon: '📋',
    label: 'テンプレート',
    description: 'templates/rules/ の参照用テンプレート。コピーして使用します。',
    color: '#6b7280',
    bgColor: '#f9fafb',
    importance: 'low'
  }
}

function getRuleCategory(rule: Rule): RuleCategory {
  if (rule.name.startsWith('[テンプレート]')) return 'template'
  if (rule.name.startsWith('[Cursor]')) return 'cursor'
  return 'active'
}

function getDisplayName(rule: Rule): string {
  return rule.name
    .replace('[テンプレート] ', '')
    .replace('[Cursor] ', '')
}

// ============================================================
// Components
// ============================================================

/**
 * Rule Detail Modal
 */
interface RuleDetailModalProps {
  isOpen: boolean
  onClose: () => void
  rule: Rule | null
}

function RuleDetailModal({ isOpen, onClose, rule }: RuleDetailModalProps) {
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

  if (!isOpen || !rule) return null

  const category = getRuleCategory(rule)
  const metadata = categoryMetadata[category]
  const displayName = getDisplayName(rule)

  return (
    <div className="modal-overlay" onClick={onClose} role="presentation">
      <div
        ref={modalRef}
        className="modal-content"
        onClick={e => e.stopPropagation()}
        role="dialog"
        aria-modal="true"
        aria-labelledby="rule-modal-title"
      >
        <div className="modal-header">
          <div className="modal-title" id="rule-modal-title">
            <span className="modal-icon" aria-hidden="true">{metadata.icon}</span>
            <span>{displayName}</span>
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

          {/* Category Info Box */}
          <div className="hook-type-info-box">
            <div className="hook-type-info-header">
              <span>{metadata.icon}</span>
              <span>{metadata.label}</span>
            </div>
            <p className="hook-type-info-desc">{metadata.description}</p>
            <div className="hook-type-info-timing">
              <span className="hook-timing-label">トークン数:</span>
              <span className="hook-timing-value">{rule.tokenCount.toLocaleString()}</span>
            </div>
          </div>

          {/* Rule Content Preview */}
          <div className="modal-description">
            <h4>ルール内容</h4>
            <pre className="hook-command-preview" style={{ maxHeight: '300px', overflow: 'auto' }}>
              {rule.content.length > 1000 ? rule.content.slice(0, 1000) + '...' : rule.content}
            </pre>
          </div>

          {/* File Path */}
          <div className="modal-description">
            <h4>ファイルパス</h4>
            <pre className="hook-command-preview">{rule.path}</pre>
          </div>
        </div>
      </div>
    </div>
  )
}

/**
 * Category Summary
 */
function CategorySummary({ rules }: { rules: Rule[] }) {
  const categoryCounts = useMemo(() => {
    const counts: Record<RuleCategory, number> = { active: 0, cursor: 0, template: 0 }
    for (const rule of rules) {
      const category = getRuleCategory(rule)
      counts[category]++
    }
    return counts
  }, [rules])

  return (
    <div className="hooks-purpose-summary">
      {(Object.entries(categoryMetadata) as [RuleCategory, CategoryMetadata][]).map(([category, info]) => {
        const count = categoryCounts[category]
        // テンプレートは内部用なので表示しない
        if (count === 0 || category === 'template') return null
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
 * Rule Card
 */
function RuleCard({ rule, onClick }: { rule: Rule; onClick: () => void }) {
  const category = getRuleCategory(rule)
  const metadata = categoryMetadata[category]
  const displayName = getDisplayName(rule)

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
      aria-label={`${displayName} の詳細を表示`}
    >
      <div className="hook-card-header">
        <div className="hook-card-title">
          <span className="hook-card-icon">{metadata.icon}</span>
          <span className="hook-card-name">{displayName}</span>
        </div>
        <span
          className="hook-card-purpose"
          style={{ backgroundColor: metadata.bgColor, color: metadata.color }}
        >
          {metadata.label}
        </span>
      </div>
      <p className="hook-card-desc">
        {rule.content.slice(0, 100).replace(/\n/g, ' ')}
        {rule.content.length > 100 && '...'}
      </p>
      <div className="hook-card-footer">
        <span className="hook-card-matcher">
          <span className="hook-card-matcher-label">トークン:</span>
          <code>{rule.tokenCount.toLocaleString()}</code>
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
  tokens,
  isExpanded,
  onToggle
}: {
  category: RuleCategory
  count: number
  tokens: number
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
          <span className="hooks-type-timing">{tokens.toLocaleString()} tokens</span>
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

export function RulesEditor() {
  const [expandedCategories, setExpandedCategories] = useState<Set<string>>(new Set(['active']))
  const [selectedRule, setSelectedRule] = useState<Rule | null>(null)
  const [modalOpen, setModalOpen] = useState(false)
  const { activeProject } = useProject()
  const projectPath = activeProject?.path

  const { data: rules, loading, hasError } = useProjectResource(
    fetchRules,
    projectPath
  )

  const toggleCategory = useCallback((category: string) => {
    setExpandedCategories(prev => {
      const next = new Set(prev)
      if (next.has(category)) next.delete(category)
      else next.add(category)
      return next
    })
  }, [])

  const handleRuleClick = useCallback((rule: Rule) => {
    setSelectedRule(rule)
    setModalOpen(true)
  }, [])

  // Memoized calculations (before conditional returns)
  const groupedRules = useMemo(() => {
    if (!rules) return { active: [], cursor: [], template: [] }
    const groups: Record<RuleCategory, Rule[]> = { active: [], cursor: [], template: [] }
    for (const rule of rules.rules) {
      const category = getRuleCategory(rule)
      groups[category].push(rule)
    }
    return groups
  }, [rules])

  // ユーザー関連ルールのみカウント（テンプレート除外）
  const { userRules, userTokens, tokenStatus } = useMemo(() => {
    const userRules = [...groupedRules.active, ...groupedRules.cursor]
    const userTokens = userRules.reduce((sum, r) => sum + r.tokenCount, 0)
    return {
      userRules,
      userTokens,
      tokenStatus: getTokenStatus(userTokens)
    }
  }, [groupedRules])

  const categoryOrder: RuleCategory[] = ['active', 'cursor']

  if (loading) {
    return <LoadingState message="Rules を読み込み中..." />
  }

  if (!rules || hasError) {
    return <ErrorState message="Rules の取得に失敗しました" />
  }

  return (
    <div className="page-container">
      {/* Page Header */}
      <div className="page-header">
        <h1 className="page-title">Rules</h1>
        <p className="page-subtitle">
          プロジェクト固有のルール。Claude の動作を制御するガードレールです。
        </p>
      </div>

      {/* Summary Card */}
      <div className="summary-card">
        <div className="summary-stats">
          <div className="summary-stat">
            <span className="summary-stat-icon">📜</span>
            <div className="summary-stat-content">
              <span className="summary-stat-value">{userRules.length}</span>
              <span className="summary-stat-label">ルール数</span>
            </div>
          </div>
          <div className="summary-stat">
            <span className="summary-stat-icon">✅</span>
            <div className="summary-stat-content">
              <span className="summary-stat-value">{groupedRules.active.length}</span>
              <span className="summary-stat-label">アクティブ</span>
            </div>
          </div>
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

        {/* Category breakdown */}
        <CategorySummary rules={rules.rules} />

        <div className="summary-hint" style={{ color: tokenStatus.color }}>
          {tokenStatus.hint}
        </div>
      </div>

      {/* Conflict Warning */}
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

      {/* Rules by Category */}
      <div className="hooks-type-sections">
        {categoryOrder.map(category => {
          const categoryRules = groupedRules[category]
          if (categoryRules.length === 0) return null

          const isExpanded = expandedCategories.has(category)
          const categoryTokens = categoryRules.reduce((sum, r) => sum + r.tokenCount, 0)

          return (
            <div key={category} className="hooks-type-section">
              <CategorySectionHeader
                category={category}
                count={categoryRules.length}
                tokens={categoryTokens}
                isExpanded={isExpanded}
                onToggle={() => toggleCategory(category)}
              />

              {isExpanded && (
                <div className="hooks-list">
                  {categoryRules.map((rule) => (
                    <RuleCard
                      key={rule.path}
                      rule={rule}
                      onClick={() => handleRuleClick(rule)}
                    />
                  ))}
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

      {/* Rule Detail Modal */}
      <RuleDetailModal
        isOpen={modalOpen}
        onClose={() => setModalOpen(false)}
        rule={selectedRule}
      />
    </div>
  )
}
