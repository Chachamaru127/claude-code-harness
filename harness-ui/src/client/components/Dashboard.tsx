import { useState } from 'react'
import { useHealth } from '../hooks/useHealth.ts'
import { usePlans } from '../hooks/usePlans.ts'
import type { Task, WorkflowMode, HealthResponse } from '../../shared/types.ts'

/**
 * モード切替スイッチ（コンパクト版）
 */
function ModeSwitch({ mode, onModeChange }: { mode: WorkflowMode; onModeChange: (mode: WorkflowMode) => void }) {
  return (
    <div className="mode-switch-compact">
      <button
        className={`mode-btn-sm ${mode === 'solo' ? 'mode-btn-sm-active' : ''}`}
        onClick={() => onModeChange('solo')}
        title="単独運用モード"
      >
        Solo
      </button>
      <button
        className={`mode-btn-sm ${mode === '2agent' ? 'mode-btn-sm-active' : ''}`}
        onClick={() => onModeChange('2agent')}
        title="2エージェントモード"
      >
        2-Agent
      </button>
    </div>
  )
}

/**
 * Health スコア表示（コンパクト版）
 */
function HealthScore({ health }: { health: HealthResponse }) {
  const getScoreContext = (score: number) => {
    if (score >= 80) return { label: '良好', color: '#22c55e', icon: '✓' }
    if (score >= 60) return { label: '要注意', color: '#f59e0b', icon: '!' }
    return { label: '要改善', color: '#ef4444', icon: '✕' }
  }

  const ctx = getScoreContext(health.score)
  const issueCount = health.suggestions.length

  return (
    <div className="health-score-compact">
      <div className="health-score-ring" style={{ borderColor: ctx.color }}>
        <span className="health-score-value" style={{ color: ctx.color }}>{health.score}</span>
      </div>
      <div className="health-score-info">
        <div className="health-score-label" style={{ color: ctx.color }}>
          {ctx.icon} {ctx.label}
        </div>
        {issueCount > 0 && (
          <div className="health-score-issues">
            ⚠️ {issueCount}件の改善提案
          </div>
        )}
      </div>
    </div>
  )
}

/**
 * WIP タスクフォーカスエリア
 * 「今何をすべきか」を明確に表示
 */
function WIPFocus({ tasks, planCount, reviewCount, mode }: {
  tasks: Task[]
  planCount: number
  reviewCount: number
  mode: WorkflowMode
}) {
  const getNextAction = () => {
    if (tasks.length > 0) {
      return `${tasks.length}件の作業を進めましょう`
    }
    if (mode === '2agent' && reviewCount > 0) {
      return `${reviewCount}件のレビュー待ちがあります`
    }
    if (planCount > 0) {
      return `Plan から${planCount}件のタスクを開始できます`
    }
    return 'すべてのタスクが完了しています'
  }

  return (
    <div className="wip-focus">
      <div className="wip-focus-header">
        <span className="wip-focus-icon">🔥</span>
        <span className="wip-focus-title">作業中</span>
        <span className="wip-focus-count">{tasks.length}</span>
      </div>

      <div className="wip-focus-tasks">
        {tasks.length > 0 ? (
          tasks.slice(0, 4).map((task) => (
            <div key={task.id} className="wip-task">
              <span className="wip-task-bullet">▸</span>
              <span className="wip-task-title">{task.title}</span>
              {task.priority === 'high' && <span className="wip-task-priority">🔴</span>}
            </div>
          ))
        ) : (
          <div className="wip-empty">作業中のタスクはありません</div>
        )}
        {tasks.length > 4 && (
          <div className="wip-more">+{tasks.length - 4} more</div>
        )}
      </div>

      <div className="wip-next-action">
        <span className="wip-next-icon">→</span>
        <span className="wip-next-text">{getNextAction()}</span>
      </div>
    </div>
  )
}

/**
 * コンポーネントサマリーカード
 * クリックで詳細ページへ遷移
 */
function ComponentCard({
  icon,
  label,
  value,
  hint,
  status,
  onClick
}: {
  icon: string
  label: string
  value: string | number
  hint: string
  status: 'good' | 'warning' | 'error'
  onClick: () => void
}) {
  return (
    <button className={`component-card component-card-${status}`} onClick={onClick}>
      <div className="component-card-icon">{icon}</div>
      <div className="component-card-content">
        <div className="component-card-label">{label}</div>
        <div className="component-card-value">{value}</div>
        <div className="component-card-hint">{hint}</div>
      </div>
      <div className="component-card-arrow">›</div>
    </button>
  )
}

/**
 * コンポーネント概要セクション
 */
function ComponentsSummary({
  health,
  onNavigate
}: {
  health: HealthResponse
  onNavigate: (page: string) => void
}) {
  const getStatus = (s: string): 'good' | 'warning' | 'error' => {
    if (s === 'good') return 'good'
    if (s === 'warning') return 'warning'
    return 'error'
  }

  const formatTokens = (tokens: number) => {
    if (tokens > 1000) return `${Math.round(tokens / 1000)}K`
    return tokens.toString()
  }

  const components = [
    {
      icon: '⚡',
      label: 'Skills',
      value: health.breakdown.skills.count,
      hint: health.breakdown.skills.count > 50 ? '多め' : '適正',
      status: getStatus(health.breakdown.skills.status),
      page: 'skills'
    },
    {
      icon: '🧠',
      label: 'Memory',
      value: formatTokens(health.breakdown.memory.storageTokens),
      hint: health.breakdown.memory.storageTokens > 30000 ? '整理推奨' : '適正',
      status: getStatus(health.breakdown.memory.status),
      page: 'memory'
    },
    {
      icon: '📜',
      label: 'Rules',
      value: health.breakdown.rules.count,
      hint: health.breakdown.rules.count === 0 ? '未設定' : `${health.breakdown.rules.count}個`,
      status: getStatus(health.breakdown.rules.status),
      page: 'rules'
    },
    {
      icon: '🔗',
      label: 'Hooks',
      value: health.breakdown.hooks.count,
      hint: health.breakdown.hooks.count > 10 ? '多め' : '適正',
      status: getStatus(health.breakdown.hooks.status),
      page: 'insights' // Hooks don't have their own page yet, go to insights
    }
  ]

  return (
    <div className="components-summary">
      {components.map((c) => (
        <ComponentCard
          key={c.label}
          icon={c.icon}
          label={c.label}
          value={c.value}
          hint={c.hint}
          status={c.status}
          onClick={() => onNavigate(c.page)}
        />
      ))}
    </div>
  )
}

/**
 * タスクサマリーバー
 * 折りたたみ時に表示するコンパクトな進捗表示
 */
function TaskSummaryBar({ plans, mode }: {
  plans: { plan: Task[]; work: Task[]; review: Task[]; done: Task[] }
  mode: WorkflowMode
}) {
  const total = plans.plan.length + plans.work.length + plans.review.length + plans.done.length
  if (total === 0) return null

  const columns = mode === 'solo'
    ? [
        { name: 'Plan', count: plans.plan.length, color: '#3b82f6' },
        { name: 'Work', count: plans.work.length, color: '#F97316' },
        { name: 'Done', count: plans.done.length, color: '#22c55e' }
      ]
    : [
        { name: 'Plan', count: plans.plan.length, color: '#3b82f6' },
        { name: 'Work', count: plans.work.length, color: '#F97316' },
        { name: 'Review', count: plans.review.length, color: '#8b5cf6' },
        { name: 'Done', count: plans.done.length, color: '#22c55e' }
      ]

  return (
    <div className="task-summary-bar">
      {columns.map((col) => (
        <div key={col.name} className="task-summary-item">
          <div className="task-summary-label">{col.name}</div>
          <div className="task-summary-count" style={{ color: col.color }}>{col.count}</div>
          <div
            className="task-summary-bar-fill"
            style={{
              backgroundColor: col.color,
              width: `${total > 0 ? (col.count / total) * 100 : 0}%`
            }}
          />
        </div>
      ))}
    </div>
  )
}

/**
 * カンバンカラム
 */
function KanbanColumn({ title, tasks, color }: {
  title: string
  tasks: Task[]
  color: string
}) {
  return (
    <div className="kanban-column">
      <div className="kanban-column-header">
        <span className="kanban-dot" style={{ backgroundColor: color }} />
        <span className="kanban-title-text">{title}</span>
        <span className="kanban-count">{tasks.length}</span>
      </div>
      <div className="kanban-tasks">
        {tasks.length > 0 ? (
          tasks.slice(0, 6).map((task) => (
            <div key={task.id} className="kanban-task">
              <div className="kanban-task-title">{task.title}</div>
              {task.priority && (
                <span className={`kanban-task-priority priority-${task.priority}`}>
                  {task.priority === 'high' ? '🔴' : task.priority === 'medium' ? '🟡' : '🟢'}
                </span>
              )}
            </div>
          ))
        ) : (
          <div className="kanban-empty-mini">—</div>
        )}
        {tasks.length > 6 && (
          <div className="kanban-more">+{tasks.length - 6}</div>
        )}
      </div>
    </div>
  )
}

/**
 * 折りたたみ可能なカンバンボード
 */
function CollapsibleKanban({ plans, mode }: {
  plans: { plan: Task[]; work: Task[]; review: Task[]; done: Task[] }
  mode: WorkflowMode
}) {
  const [expanded, setExpanded] = useState(false)

  const columns = mode === 'solo'
    ? [
        { title: 'Plan', tasks: plans.plan, color: '#3b82f6' },
        { title: 'Work', tasks: plans.work, color: '#F97316' },
        { title: 'Done', tasks: plans.done, color: '#22c55e' }
      ]
    : [
        { title: 'Plan', tasks: plans.plan, color: '#3b82f6' },
        { title: 'Work', tasks: plans.work, color: '#F97316' },
        { title: 'Review', tasks: plans.review, color: '#8b5cf6' },
        { title: 'Done', tasks: plans.done, color: '#22c55e' }
      ]

  const total = plans.plan.length + plans.work.length + plans.review.length + plans.done.length

  return (
    <div className="kanban-section">
      <button className="kanban-toggle" onClick={() => setExpanded(!expanded)}>
        <div className="kanban-toggle-left">
          <span className="kanban-toggle-icon">{expanded ? '▼' : '▶'}</span>
          <span className="kanban-toggle-title">タスクボード</span>
          <span className="kanban-toggle-count">{total}件</span>
        </div>
        <span className="kanban-toggle-hint">
          {expanded ? 'クリックで折りたたむ' : 'クリックで展開'}
        </span>
      </button>

      {!expanded && <TaskSummaryBar plans={plans} mode={mode} />}

      {expanded && (
        <div className={`kanban-board ${mode === 'solo' ? 'kanban-board-3col' : ''}`}>
          {columns.map((col) => (
            <KanbanColumn key={col.title} {...col} />
          ))}
        </div>
      )}
    </div>
  )
}

/**
 * 改善提案（コンパクト版）
 */
function SuggestionsCompact({ suggestions, onNavigate }: {
  suggestions: string[]
  onNavigate: (page: string) => void
}) {
  if (suggestions.length === 0) return null

  return (
    <div className="suggestions-compact">
      <div className="suggestions-compact-header">
        <span className="suggestions-compact-icon">💡</span>
        <span className="suggestions-compact-title">改善提案</span>
        <button className="suggestions-compact-link" onClick={() => onNavigate('insights')}>
          詳細を見る →
        </button>
      </div>
      <div className="suggestions-compact-list">
        {suggestions.slice(0, 2).map((s, i) => (
          <div key={i} className="suggestions-compact-item">{s}</div>
        ))}
        {suggestions.length > 2 && (
          <div className="suggestions-compact-more">
            +{suggestions.length - 2}件の提案
          </div>
        )}
      </div>
    </div>
  )
}

/**
 * ローディング状態
 */
function LoadingState() {
  return (
    <div className="dashboard-loading">
      <div className="spinner" />
      <span>プロジェクトを分析中...</span>
    </div>
  )
}

/**
 * エラー状態
 */
function ErrorState({ message }: { message: string }) {
  return (
    <div className="dashboard-error">
      <span className="dashboard-error-icon">⚠️</span>
      <span>{message}</span>
    </div>
  )
}

/**
 * ダッシュボード
 * 情報階層: WIP/Health → Components → Kanban → Suggestions
 */
export function Dashboard({ onNavigate }: { onNavigate?: (page: string) => void }) {
  const [mode, setMode] = useState<WorkflowMode>('solo')
  const { health, loading: healthLoading } = useHealth()
  const { plans, loading: plansLoading } = usePlans(mode)

  const navigate = onNavigate ?? (() => {})

  // Loading state
  if (healthLoading || plansLoading) {
    return (
      <div className="dashboard">
        <LoadingState />
      </div>
    )
  }

  // Error states
  if (!health) {
    return (
      <div className="dashboard">
        <ErrorState message="プロジェクト分析に失敗しました" />
      </div>
    )
  }

  const plansData = plans ?? { plan: [], work: [], review: [], done: [], error: 'Plans.md not found' }

  return (
    <div className="dashboard">
      {/* Header with mode switch */}
      <div className="dashboard-header-new">
        <div className="dashboard-header-left">
          <h1 className="dashboard-title-new">プロジェクト概要</h1>
        </div>
        <ModeSwitch mode={mode} onModeChange={setMode} />
      </div>

      {/* Hero Section: Health + WIP */}
      <div className="dashboard-hero">
        <HealthScore health={health} />
        <WIPFocus
          tasks={plansData.work}
          planCount={plansData.plan.length}
          reviewCount={plansData.review.length}
          mode={mode}
        />
      </div>

      {/* Components Summary */}
      <ComponentsSummary health={health} onNavigate={navigate} />

      {/* Collapsible Kanban */}
      {!plansData.error && (
        <CollapsibleKanban plans={plansData} mode={mode} />
      )}

      {plansData.error && (
        <div className="plans-error">
          <span className="plans-error-icon">📋</span>
          <span>{plansData.error}</span>
          <span className="plans-error-hint">Plans.md を作成してタスク管理を始めましょう</span>
        </div>
      )}

      {/* Suggestions */}
      <SuggestionsCompact suggestions={health.suggestions} onNavigate={navigate} />
    </div>
  )
}
