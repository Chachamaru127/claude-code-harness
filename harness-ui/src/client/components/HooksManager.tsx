import { useState, useCallback, useMemo, useRef, useEffect } from 'react'
import { fetchHooks } from '../lib/api.ts'
import { useProject } from '../App.tsx'
import { useProjectResource } from '../hooks/useProjectResource.ts'
import { LoadingState, ErrorState } from './shared/index.ts'
import type { Hook } from '../../shared/types.ts'

// ============================================================
// Hook Metadata - 各フックの説明とカテゴリ
// ============================================================

type HookPurpose = 'security' | 'logging' | 'workflow' | 'session' | 'input'

interface HookMetadata {
  displayName: string
  description: string
  purpose: HookPurpose
}

/**
 * 各フックの詳細情報
 * name (スクリプト名から派生) → メタデータ
 */
const hookMetadataMap: Record<string, HookMetadata> = {
  // Security Guards
  'pretooluse-guard': {
    displayName: 'ツール実行前ガード',
    description: 'Write/Edit/Bash 実行前にセキュリティチェックを行い、危険な操作をブロックします',
    purpose: 'security'
  },
  'permission-request': {
    displayName: '権限リクエスト処理',
    description: 'Bash コマンド実行時の権限確認ダイアログを制御します',
    purpose: 'security'
  },

  // Session Lifecycle
  'session-init': {
    displayName: 'セッション初期化',
    description: 'セッション開始時に環境を初期化し、必要な設定を読み込みます',
    purpose: 'session'
  },
  'session-monitor': {
    displayName: 'セッション監視',
    description: 'セッション中の状態を監視し、異常を検知します',
    purpose: 'session'
  },
  'harness-ui-register': {
    displayName: 'UI 登録',
    description: 'harness-ui ダッシュボードにプロジェクトを登録します',
    purpose: 'session'
  },
  'session-summary': {
    displayName: 'セッション要約',
    description: 'セッション終了時に作業内容の要約を生成します',
    purpose: 'session'
  },
  'collect-cleanup-context': {
    displayName: 'クリーンアップ情報収集',
    description: '終了時にクリーンアップ提案のためのコンテキストを収集します',
    purpose: 'session'
  },

  // Logging & Tracking
  'posttooluse-log-toolname': {
    displayName: 'ツール使用ログ',
    description: '全てのツール呼び出しをログに記録し、デバッグを支援します',
    purpose: 'logging'
  },
  'usage-tracker': {
    displayName: '使用状況トラッキング',
    description: 'スキル・コマンド・エージェントの使用統計を記録します',
    purpose: 'logging'
  },
  'track-changes': {
    displayName: '変更追跡',
    description: 'ファイルの変更履歴を追跡し、セッションログに記録します',
    purpose: 'logging'
  },

  // Workflow Automation
  'auto-cleanup-hook': {
    displayName: '自動クリーンアップ',
    description: 'ファイル編集後に不要なファイルや一時ファイルを自動削除します',
    purpose: 'workflow'
  },
  'auto-test-runner': {
    displayName: '自動テスト実行',
    description: 'コード変更後に関連するテストを自動的に実行します',
    purpose: 'workflow'
  },
  'plans-watcher': {
    displayName: 'Plans.md 監視',
    description: 'タスクファイル更新時に進捗状況を自動で同期します',
    purpose: 'workflow'
  },
  'tdd-order-check': {
    displayName: 'TDD 順序チェック',
    description: 'テスト駆動開発の原則に従っているかをチェックします',
    purpose: 'workflow'
  },

  // User Input Hooks
  'userprompt-inject-policy': {
    displayName: 'プロンプトポリシー注入',
    description: 'ユーザー入力時に品質ガイドラインやポリシーを自動注入します',
    purpose: 'input'
  },

  // Prompt Hooks (Stop type)
  'prompt-hook': {
    displayName: 'プロンプトフック',
    description: 'セッション終了時にAIベースの分析・提案を行います',
    purpose: 'workflow'
  }
}

/**
 * フックタイプの詳細情報
 */
interface HookTypeInfo {
  icon: string
  label: string
  description: string
  timing: string
}

const hookTypeInfo: Record<string, HookTypeInfo> = {
  PreToolUse: {
    icon: '🛡️',
    label: 'ツール実行前ガード',
    description: 'ツールが実行される直前に呼び出され、操作をブロックまたは許可できます',
    timing: 'ツール呼び出し前'
  },
  PostToolUse: {
    icon: '✅',
    label: 'ツール実行後処理',
    description: 'ツール実行完了後に自動的に呼び出され、ログ記録や追加処理を行います',
    timing: 'ツール完了後'
  },
  SessionStart: {
    icon: '🚀',
    label: 'セッション開始',
    description: 'Claude Code セッションの開始時に一度だけ実行されます',
    timing: 'セッション開始時'
  },
  Stop: {
    icon: '🛑',
    label: 'セッション終了',
    description: 'セッションが終了する直前に実行され、クリーンアップや要約を行います',
    timing: 'セッション終了時'
  },
  UserPromptSubmit: {
    icon: '💬',
    label: 'ユーザー入力時',
    description: 'ユーザーがプロンプトを送信するたびに呼び出されます',
    timing: 'プロンプト送信時'
  },
  PermissionRequest: {
    icon: '🔐',
    label: '権限リクエスト',
    description: '許可が必要な操作の実行前に呼び出されます',
    timing: '権限確認時'
  },
  Notification: {
    icon: '🔔',
    label: '通知',
    description: 'システムからの通知イベント時に呼び出されます',
    timing: '通知発生時'
  }
}

/**
 * フック目的のカテゴリ情報
 */
const purposeInfo: Record<HookPurpose, { icon: string; label: string; color: string; bgColor: string }> = {
  security: { icon: '🛡️', label: 'セキュリティ', color: '#dc2626', bgColor: '#fef2f2' },
  logging: { icon: '📊', label: 'ログ・追跡', color: '#2563eb', bgColor: '#eff6ff' },
  workflow: { icon: '⚙️', label: 'ワークフロー', color: '#16a34a', bgColor: '#f0fdf4' },
  session: { icon: '🔄', label: 'セッション', color: '#9333ea', bgColor: '#faf5ff' },
  input: { icon: '💬', label: 'ユーザー入力', color: '#ea580c', bgColor: '#fff7ed' }
}

// ============================================================
// Components
// ============================================================

/**
 * Hook Detail Modal
 */
interface HookDetailModalProps {
  isOpen: boolean
  onClose: () => void
  hook: Hook | null
}

function HookDetailModal({ isOpen, onClose, hook }: HookDetailModalProps) {
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

  if (!isOpen || !hook) return null

  const typeInfo = hookTypeInfo[hook.type] || { icon: '🔗', label: hook.type, description: '', timing: '' }
  const metadata = hookMetadataMap[hook.name]
  const purpose = metadata?.purpose ? purposeInfo[metadata.purpose] : null

  return (
    <div className="modal-overlay" onClick={onClose} role="presentation">
      <div
        ref={modalRef}
        className="modal-content"
        onClick={e => e.stopPropagation()}
        role="dialog"
        aria-modal="true"
        aria-labelledby="hook-modal-title"
      >
        <div className="modal-header">
          <div className="modal-title" id="hook-modal-title">
            <span className="modal-icon" aria-hidden="true">{typeInfo.icon}</span>
            <span>{metadata?.displayName || hook.name}</span>
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
          {/* Purpose Badge */}
          {purpose && (
            <div
              className="hook-purpose-badge"
              style={{ backgroundColor: purpose.bgColor, color: purpose.color }}
            >
              <span>{purpose.icon}</span>
              <span>{purpose.label}</span>
            </div>
          )}

          {/* Description */}
          <div className="modal-description">
            <h4>説明</h4>
            <p>{metadata?.description || 'このフックの説明はありません'}</p>
          </div>

          {/* Hook Type Info */}
          <div className="hook-type-info-box">
            <div className="hook-type-info-header">
              <span>{typeInfo.icon}</span>
              <span>{typeInfo.label}</span>
            </div>
            <p className="hook-type-info-desc">{typeInfo.description}</p>
            <div className="hook-type-info-timing">
              <span className="hook-timing-label">実行タイミング:</span>
              <span className="hook-timing-value">{typeInfo.timing}</span>
            </div>
          </div>

          {/* Matcher */}
          {hook.matcher && (
            <div className="modal-description">
              <h4>マッチャー（トリガー条件）</h4>
              <div className="hook-matcher-detail">
                <code>{hook.matcher}</code>
                <p className="hook-matcher-explain">
                  {hook.matcher === '*' ? 'すべてのツール/イベントに対して発火' :
                   hook.matcher.includes('|') ? `${hook.matcher.split('|').join(', ')} のいずれかで発火` :
                   `${hook.matcher} で発火`}
                </p>
              </div>
            </div>
          )}

          {/* Command Preview */}
          <div className="modal-description">
            <h4>実行コマンド</h4>
            <pre className="hook-command-preview">
              {hook.command.length > 200 ? hook.command.slice(0, 200) + '...' : hook.command}
            </pre>
          </div>
        </div>
      </div>
    </div>
  )
}

/**
 * Purpose Summary Card
 */
function PurposeSummary({ hooks }: { hooks: Hook[] }) {
  const purposeCounts = useMemo(() => {
    const counts: Record<HookPurpose, number> = {
      security: 0,
      logging: 0,
      workflow: 0,
      session: 0,
      input: 0
    }
    for (const hook of hooks) {
      const metadata = hookMetadataMap[hook.name]
      if (metadata?.purpose) {
        counts[metadata.purpose]++
      }
    }
    return counts
  }, [hooks])

  return (
    <div className="hooks-purpose-summary">
      {(Object.entries(purposeInfo) as [HookPurpose, typeof purposeInfo[HookPurpose]][]).map(([purpose, info]) => {
        const count = purposeCounts[purpose]
        if (count === 0) return null
        return (
          <div
            key={purpose}
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
 * Hook Card
 */
function HookCard({ hook, onClick }: { hook: Hook; onClick: () => void }) {
  const typeInfo = hookTypeInfo[hook.type] || { icon: '🔗', label: hook.type }
  const metadata = hookMetadataMap[hook.name]
  const purpose = metadata?.purpose ? purposeInfo[metadata.purpose] : null

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
      aria-label={`${metadata?.displayName || hook.name} の詳細を表示`}
    >
      <div className="hook-card-header">
        <div className="hook-card-title">
          <span className="hook-card-icon">{typeInfo.icon}</span>
          <span className="hook-card-name">{metadata?.displayName || hook.name}</span>
        </div>
        {purpose && (
          <span
            className="hook-card-purpose"
            style={{ backgroundColor: purpose.bgColor, color: purpose.color }}
          >
            {purpose.label}
          </span>
        )}
      </div>
      <p className="hook-card-desc">
        {metadata?.description || `マッチャー: ${hook.matcher || '*'}`}
      </p>
      <div className="hook-card-footer">
        {hook.matcher && hook.matcher !== '*' && (
          <span className="hook-card-matcher">
            <span className="hook-card-matcher-label">対象:</span>
            <code>{hook.matcher}</code>
          </span>
        )}
      </div>
    </div>
  )
}

/**
 * Type Section Header
 */
function TypeSectionHeader({
  type,
  count,
  isExpanded,
  onToggle
}: {
  type: string
  count: number
  isExpanded: boolean
  onToggle: () => void
}) {
  const info = hookTypeInfo[type] || { icon: '🔗', label: type, description: '', timing: '' }

  return (
    <button
      className="hooks-type-header"
      onClick={onToggle}
      aria-expanded={isExpanded}
    >
      <div className="hooks-type-header-main">
        <span className="hooks-type-icon">{info.icon}</span>
        <div className="hooks-type-info">
          <span className="hooks-type-name">{info.label}</span>
          <span className="hooks-type-timing">{info.timing}</span>
        </div>
        <span className="hooks-type-count">{count}</span>
      </div>
      <div className="hooks-type-header-desc">
        {info.description}
      </div>
      <span className="hooks-type-chevron" aria-hidden="true">{isExpanded ? '▼' : '▶'}</span>
    </button>
  )
}

// ============================================================
// Main Component
// ============================================================

export function HooksManager() {
  const [expandedTypes, setExpandedTypes] = useState<Set<string>>(new Set(['PreToolUse', 'PostToolUse']))
  const [selectedHook, setSelectedHook] = useState<Hook | null>(null)
  const [modalOpen, setModalOpen] = useState(false)
  const { activeProject } = useProject()
  const projectPath = activeProject?.path

  const { data: hooksData, loading, hasError } = useProjectResource(
    fetchHooks,
    projectPath
  )

  const toggleType = useCallback((type: string) => {
    setExpandedTypes(prev => {
      const next = new Set(prev)
      if (next.has(type)) next.delete(type)
      else next.add(type)
      return next
    })
  }, [])

  const handleHookClick = useCallback((hook: Hook) => {
    setSelectedHook(hook)
    setModalOpen(true)
  }, [])

  // Group hooks by type with custom order
  const typeOrder = ['PreToolUse', 'PostToolUse', 'SessionStart', 'Stop', 'UserPromptSubmit', 'PermissionRequest', 'Notification']

  const groupedHooks = useMemo(() => {
    if (!hooksData) return {}
    const groups: Record<string, Hook[]> = {}
    for (const hook of hooksData.hooks) {
      const type = hook.type || 'その他'
      if (!groups[type]) groups[type] = []
      groups[type].push(hook)
    }
    return groups
  }, [hooksData])

  const sortedTypes = useMemo(() => {
    const types = Object.keys(groupedHooks)
    return types.sort((a, b) => {
      const aIndex = typeOrder.indexOf(a)
      const bIndex = typeOrder.indexOf(b)
      if (aIndex === -1 && bIndex === -1) return a.localeCompare(b)
      if (aIndex === -1) return 1
      if (bIndex === -1) return -1
      return aIndex - bIndex
    })
  }, [groupedHooks])

  if (loading) {
    return <LoadingState message="Hooks を読み込み中..." />
  }

  if (!hooksData || hasError) {
    return <ErrorState message="Hooks の取得に失敗しました" />
  }

  return (
    <div className="page-container">
      {/* Page Header */}
      <div className="page-header">
        <h1 className="page-title">Hooks</h1>
        <p className="page-subtitle">
          Claude Code のライフサイクルフック。セッション開始・終了、ツール実行の前後で自動的に処理を実行します。
        </p>
      </div>

      {/* Summary Card */}
      <div className="summary-card">
        <div className="summary-stats">
          <div className="summary-stat">
            <span className="summary-stat-icon">🔗</span>
            <div className="summary-stat-content">
              <span className="summary-stat-value">{hooksData.count}</span>
              <span className="summary-stat-label">フック数</span>
            </div>
          </div>
          <div className="summary-stat">
            <span className="summary-stat-icon">📊</span>
            <div className="summary-stat-content">
              <span className="summary-stat-value">{sortedTypes.length}</span>
              <span className="summary-stat-label">タイプ</span>
            </div>
          </div>
        </div>

        {/* Purpose breakdown */}
        <PurposeSummary hooks={hooksData.hooks} />

        <div className="summary-hint">
          フックは hooks/hooks.json で定義されています。クリックして詳細を確認できます。
        </div>
      </div>

      {/* Hooks by Type */}
      <div className="hooks-type-sections">
        {sortedTypes.map(type => {
          const typeHooks = groupedHooks[type] || []
          const isExpanded = expandedTypes.has(type)

          return (
            <div key={type} className="hooks-type-section">
              <TypeSectionHeader
                type={type}
                count={typeHooks.length}
                isExpanded={isExpanded}
                onToggle={() => toggleType(type)}
              />

              {isExpanded && (
                <div className="hooks-list">
                  {typeHooks.map((hook, idx) => (
                    <HookCard
                      key={`${hook.name}-${idx}`}
                      hook={hook}
                      onClick={() => handleHookClick(hook)}
                    />
                  ))}
                </div>
              )}
            </div>
          )
        })}
      </div>

      {hooksData.count === 0 && (
        <div className="empty-state">
          <div className="empty-state-icon">🔗</div>
          <h3 className="empty-state-title">Hooks がありません</h3>
          <p className="empty-state-desc">
            hooks/hooks.json でフックを定義してください
          </p>
        </div>
      )}

      {/* Hook Detail Modal */}
      <HookDetailModal
        isOpen={modalOpen}
        onClose={() => setModalOpen(false)}
        hook={selectedHook}
      />
    </div>
  )
}
