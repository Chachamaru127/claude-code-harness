import { useState, useEffect, useCallback, useMemo } from 'react'
import { useProject } from '../App.tsx'
import { formatRelativeTime } from '../lib/dateUtils.ts'
import type { Insight } from '../../shared/types.ts'

// Note: AI Insights uses Claude Agent SDK which calls Claude CLI
// This runs on user's subscription - NO additional API cost

const STORAGE_KEY = 'harness-ui-insights'

interface CachedInsights {
  insights: Insight[]
  generatedAt: string
}

/**
 * Impact の色とラベルを取得
 */
function getImpactInfo(impact: Insight['impact']): { color: string; label: string; bg: string } {
  switch (impact) {
    case 'high': return { color: '#ef4444', label: '高', bg: 'rgba(239, 68, 68, 0.1)' }
    case 'medium': return { color: '#f59e0b', label: '中', bg: 'rgba(245, 158, 11, 0.1)' }
    case 'low': return { color: '#22c55e', label: '低', bg: 'rgba(34, 197, 94, 0.1)' }
  }
}

/**
 * Insight タイプのアイコンと説明
 */
function getTypeInfo(type: Insight['type']): { icon: string; label: string } {
  switch (type) {
    case 'optimization': return { icon: '⚡', label: '最適化' }
    case 'warning': return { icon: '⚠️', label: '警告' }
    case 'suggestion': return { icon: '💡', label: '提案' }
  }
}

export function InsightsPanel() {
  const [insights, setInsights] = useState<Insight[]>([])
  const [generatedAt, setGeneratedAt] = useState<string | null>(null)
  const [generating, setGenerating] = useState(false)
  const [copied, setCopied] = useState<string | null>(null)
  const { activeProject } = useProject()
  const projectPath = activeProject?.path

  // プロジェクトが変わったらキャッシュをクリア
  useEffect(() => {
    setInsights([])
    setGeneratedAt(null)
  }, [projectPath])

  // 初回マウント時にキャッシュから読み込み
  useEffect(() => {
    try {
      const cacheKey = projectPath ? `${STORAGE_KEY}-${projectPath}` : STORAGE_KEY
      const cached = localStorage.getItem(cacheKey)
      if (cached) {
        const data: CachedInsights = JSON.parse(cached)
        setInsights(data.insights)
        setGeneratedAt(data.generatedAt)
      }
    } catch (e) {
      console.error('Failed to load cached insights:', e)
    }
  }, [projectPath])

  const generateInsights = async () => {
    setGenerating(true)
    try {
      const url = projectPath
        ? `/api/insights?project=${encodeURIComponent(projectPath)}`
        : '/api/insights'
      const response = await fetch(url, { method: 'POST' })
      if (!response.ok) {
        throw new Error(`HTTP error: ${response.status}`)
      }
      const data = await response.json()
      const newInsights = data.insights ?? []
      const timestamp = new Date().toISOString()

      setInsights(newInsights)
      setGeneratedAt(timestamp)

      // localStorage に保存（プロジェクト固有のキー）
      const cacheKey = projectPath ? `${STORAGE_KEY}-${projectPath}` : STORAGE_KEY
      const cacheData: CachedInsights = {
        insights: newInsights,
        generatedAt: timestamp
      }
      localStorage.setItem(cacheKey, JSON.stringify(cacheData))
    } catch (error) {
      console.error('Failed to generate insights:', error)
    } finally {
      setGenerating(false)
    }
  }

  const clearInsights = useCallback(() => {
    setInsights([])
    setGeneratedAt(null)
    const cacheKey = projectPath ? `${STORAGE_KEY}-${projectPath}` : STORAGE_KEY
    localStorage.removeItem(cacheKey)
  }, [projectPath])

  const copyCommand = useCallback((command: string) => {
    navigator.clipboard.writeText(command)
    setCopied(command)
    setTimeout(() => setCopied(null), 2000)
  }, [])

  // インサイトを Impact 順にソート（メモ化）
  const sortedInsights = useMemo(() => {
    return [...insights].sort((a, b) => {
      const order = { high: 0, medium: 1, low: 2 }
      return order[a.impact] - order[b.impact]
    })
  }, [insights])

  // 統計情報（メモ化）
  const stats = useMemo(() => ({
    total: insights.length,
    high: insights.filter(i => i.impact === 'high').length,
    medium: insights.filter(i => i.impact === 'medium').length,
    low: insights.filter(i => i.impact === 'low').length
  }), [insights])

  return (
    <div className="page-container">
      {/* ページヘッダー */}
      <div className="page-header">
        <h1 className="page-title">AI Insights</h1>
        <p className="page-subtitle">
          Claude がプロジェクトを分析し、最適化提案を生成します。
        </p>
      </div>

      {/* Viewer パターン説明カード */}
      <div className="info-card info-card-highlight">
        <div className="info-card-header">
          <span className="info-card-icon">👁️</span>
          <span className="info-card-title">Viewer パターン</span>
        </div>
        <div className="info-card-content">
          <p>
            <strong>安全設計</strong> — AI Insights はCLIコマンドを生成するのみ。実行は手動で行います。
          </p>
          <p>
            <strong>コスト</strong> — Claude CLI を使用するため、ユーザーのサブスクリプション内で動作。追加コストなし。
          </p>
        </div>
      </div>

      {/* 生成ボタン */}
      <div className="insights-action">
        <button
          onClick={generateInsights}
          disabled={generating}
          className="insights-generate-btn"
        >
          {generating ? (
            <>
              <span className="spinner" />
              <span>AI が分析中...</span>
            </>
          ) : (
            <>
              <span>🔍</span>
              <span>{insights.length > 0 ? '再分析' : '最適化提案を生成'}</span>
            </>
          )}
        </button>
        {insights.length > 0 && (
          <button
            onClick={clearInsights}
            className="insights-clear-btn"
          >
            クリア
          </button>
        )}
      </div>

      {/* 統計サマリー（インサイトがある場合のみ） */}
      {insights.length > 0 && (
        <div className="summary-card">
          <div className="summary-stats">
            <div className="summary-stat">
              <span className="summary-stat-icon">💡</span>
              <div className="summary-stat-content">
                <span className="summary-stat-value">{stats.total}</span>
                <span className="summary-stat-label">提案数</span>
              </div>
            </div>
            {stats.high > 0 && (
              <div className="summary-stat">
                <span className="summary-stat-icon">🔴</span>
                <div className="summary-stat-content">
                  <span className="summary-stat-value" style={{ color: '#ef4444' }}>{stats.high}</span>
                  <span className="summary-stat-label">高優先度</span>
                </div>
              </div>
            )}
            {stats.medium > 0 && (
              <div className="summary-stat">
                <span className="summary-stat-icon">🟡</span>
                <div className="summary-stat-content">
                  <span className="summary-stat-value" style={{ color: '#f59e0b' }}>{stats.medium}</span>
                  <span className="summary-stat-label">中優先度</span>
                </div>
              </div>
            )}
            {stats.low > 0 && (
              <div className="summary-stat">
                <span className="summary-stat-icon">🟢</span>
                <div className="summary-stat-content">
                  <span className="summary-stat-value" style={{ color: '#22c55e' }}>{stats.low}</span>
                  <span className="summary-stat-label">低優先度</span>
                </div>
              </div>
            )}
          </div>
          {generatedAt && (
            <div className="summary-hint" style={{ color: 'var(--muted-foreground)' }}>
              生成日時: {formatRelativeTime(generatedAt)}
            </div>
          )}
        </div>
      )}

      {/* 空状態 */}
      {insights.length === 0 && !generating && (
        <div className="empty-state">
          <div className="empty-state-icon">💡</div>
          <h3 className="empty-state-title">Insights がありません</h3>
          <p className="empty-state-desc">
            「最適化提案を生成」をクリックして AI に分析させてください
          </p>
        </div>
      )}

      {/* インサイト一覧 */}
      {sortedInsights.length > 0 && (
        <div className="insights-list" role="list" aria-label="最適化提案一覧">
          {sortedInsights.map((insight, i) => {
            const impactInfo = getImpactInfo(insight.impact)
            const typeInfo = getTypeInfo(insight.type)

            return (
              <article
                key={i}
                className="insight-card"
                style={{ borderLeftColor: impactInfo.color }}
                role="listitem"
                aria-label={`${typeInfo.label}: ${insight.title}`}
              >
                <div className="insight-header">
                  <div className="insight-type">
                    <span className="insight-type-icon" aria-hidden="true">{typeInfo.icon}</span>
                    <span className="insight-type-label">{typeInfo.label}</span>
                  </div>
                  <div className="insight-meta">
                    <span
                      className="insight-impact"
                      style={{ backgroundColor: impactInfo.bg, color: impactInfo.color }}
                    >
                      Impact: {impactInfo.label}
                    </span>
                    <span className="insight-effort">
                      Effort: {insight.effort}
                    </span>
                  </div>
                </div>

                <div className="insight-content">
                  <h3 className="insight-title">{insight.title}</h3>
                  <p className="insight-desc">{insight.description}</p>
                </div>

                <div className="insight-command">
                  <code className="insight-command-text">$ {insight.cliCommand}</code>
                  <button
                    onClick={() => copyCommand(insight.cliCommand)}
                    className="insight-copy-btn"
                    aria-label={`コマンドをコピー: ${insight.cliCommand}`}
                  >
                    {copied === insight.cliCommand ? '✓ コピー済み' : '📋 コピー'}
                  </button>
                </div>
              </article>
            )
          })}
        </div>
      )}
    </div>
  )
}
