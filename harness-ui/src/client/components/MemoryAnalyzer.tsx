import { fetchMemory } from '../lib/api.ts'
import { useProject } from '../App.tsx'
import { useProjectResource } from '../hooks/useProjectResource.ts'
import { LoadingState, ErrorState } from './shared/index.ts'
import { getMemoryTokenStatus } from '../lib/tokenStatus.ts'

/**
 * ファイルタイプの説明
 */
const fileTypeInfo: Record<string, { icon: string; desc: string; importance: 'high' | 'medium' | 'low' }> = {
  'decisions.md': { icon: '⚖️', desc: 'アーキテクチャ決定記録（Why）', importance: 'high' },
  'patterns.md': { icon: '🔄', desc: '再利用パターン集（How）', importance: 'high' },
  'session-log.md': { icon: '📝', desc: 'セッション作業ログ', importance: 'medium' },
  'changelog-rules.md': { icon: '📋', desc: 'CHANGELOG 規約', importance: 'medium' },
}

/**
 * ファイルの重要度に基づくスタイル
 */
function getImportanceStyle(importance: 'high' | 'medium' | 'low'): string {
  switch (importance) {
    case 'high': return 'memory-file-high'
    case 'medium': return 'memory-file-medium'
    default: return 'memory-file-low'
  }
}

export function MemoryAnalyzer() {
  const { activeProject } = useProject()
  const projectPath = activeProject?.path

  // Race Condition 対策済みのフック
  const { data: memory, loading, hasError } = useProjectResource(
    fetchMemory,
    projectPath
  )

  if (loading) {
    return <LoadingState message="Memory を分析中..." />
  }

  if (!memory || hasError) {
    return <ErrorState message="Memory の取得に失敗しました" />
  }

  const storageStatus = getMemoryTokenStatus(memory.totalTokens)

  // Sort files by importance and then by token count
  const sortedFiles = [...memory.files].sort((a, b) => {
    const aInfo = fileTypeInfo[a.name]
    const bInfo = fileTypeInfo[b.name]
    const importanceOrder = { high: 0, medium: 1, low: 2 }
    const aOrder = aInfo ? importanceOrder[aInfo.importance] : 2
    const bOrder = bInfo ? importanceOrder[bInfo.importance] : 2
    if (aOrder !== bOrder) return aOrder - bOrder
    return b.tokenCount - a.tokenCount
  })

  return (
    <div className="page-container">
      {/* ページヘッダー */}
      <div className="page-header">
        <h1 className="page-title">Memory</h1>
        <p className="page-subtitle">
          SSOT（Single Source of Truth）ファイル。decisions.md（Why）と patterns.md（How）が核心です。
        </p>
      </div>

      {/* SSOT 説明カード */}
      <div className="info-card">
        <div className="info-card-header">
          <span className="info-card-icon">🧠</span>
          <span className="info-card-title">SSOT とは</span>
        </div>
        <div className="info-card-content">
          <p>
            <strong>decisions.md</strong> — 「なぜそうしたか」の判断記録。次回セッションで同じ質問に悩まない。
          </p>
          <p>
            <strong>patterns.md</strong> — 「どうやるか」の再利用パターン。成功した方法を蓄積。
          </p>
          <p style={{ color: 'var(--muted-foreground)', fontSize: '0.8rem', marginTop: '0.5rem' }}>
            💡 Memory はセッション開始時に読み込まれず、スキルが参照した時のみロードされます。
          </p>
        </div>
      </div>

      {/* サマリーカード */}
      <div className="summary-card">
        <div className="summary-stats">
          <div className="summary-stat">
            <span className="summary-stat-icon">📁</span>
            <div className="summary-stat-content">
              <span className="summary-stat-value">{memory.files.length}</span>
              <span className="summary-stat-label">ファイル数</span>
            </div>
          </div>
          <div className="summary-stat">
            <span className="summary-stat-icon">💾</span>
            <div className="summary-stat-content">
              <span className="summary-stat-value" style={{ color: storageStatus.color }}>
                {memory.totalTokens > 1000
                  ? `${Math.round(memory.totalTokens / 1000)}K`
                  : memory.totalTokens}
              </span>
              <span className="summary-stat-label">保存サイズ（{storageStatus.label}）</span>
            </div>
          </div>
          {memory.duplicates.length > 0 && (
            <div className="summary-stat">
              <span className="summary-stat-icon">⚠️</span>
              <div className="summary-stat-content">
                <span className="summary-stat-value" style={{ color: '#f59e0b' }}>
                  {memory.duplicates.length}
                </span>
                <span className="summary-stat-label">重複候補</span>
              </div>
            </div>
          )}
        </div>
        <div className="summary-hint" style={{ color: storageStatus.color }}>
          {storageStatus.hint}
        </div>
      </div>

      {/* 重複警告 */}
      {memory.duplicates.length > 0 && (
        <div className="alert alert-warning">
          <span className="alert-icon">🔄</span>
          <div className="alert-content">
            <div className="alert-title">重複コンテンツ検出</div>
            <div className="alert-desc">
              {memory.duplicates.length} 件の重複が見つかりました。
              <code>/harness-mem merge</code> でマージを検討してください。
            </div>
          </div>
        </div>
      )}

      {/* ファイル一覧 */}
      <div className="memory-files" role="list" aria-label="メモリファイル一覧">
        {sortedFiles.map((file) => {
          const info = fileTypeInfo[file.name] || { icon: '📄', desc: 'メモリファイル', importance: 'low' as const }
          return (
            <div
              key={file.path}
              className={`memory-file ${getImportanceStyle(info.importance)}`}
              role="listitem"
              tabIndex={0}
              aria-label={`${file.name}: ${file.tokenCount.toLocaleString()} トークン`}
            >
              <div className="memory-file-header">
                <span className="memory-file-icon" aria-hidden="true">{info.icon}</span>
                <div className="memory-file-info">
                  <span className="memory-file-name">{file.name}</span>
                  <span className="memory-file-desc">{info.desc}</span>
                </div>
              </div>
              <div className="memory-file-meta">
                <span className="memory-file-tokens">{file.tokenCount.toLocaleString()} tokens</span>
                <span className="memory-file-date">
                  {new Date(file.lastModified).toLocaleDateString('ja-JP')}
                </span>
              </div>
            </div>
          )
        })}
      </div>

      {memory.files.length === 0 && (
        <div className="empty-state">
          <div className="empty-state-icon">🧠</div>
          <h3 className="empty-state-title">Memory がありません</h3>
          <p className="empty-state-desc">
            .claude/memory/ に decisions.md や patterns.md を追加して SSOT を構築しましょう
          </p>
        </div>
      )}
    </div>
  )
}
