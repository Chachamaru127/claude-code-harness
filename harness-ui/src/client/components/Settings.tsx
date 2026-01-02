import { useState, useEffect } from 'react'
import { fetchClaudeMemStatus, fetchHooks } from '../lib/api.ts'
import type { HooksResponse } from '../../shared/types.ts'

export function Settings() {
  const [claudeMemAvailable, setClaudeMemAvailable] = useState<boolean | null>(null)
  const [hooks, setHooks] = useState<HooksResponse | null>(null)

  useEffect(() => {
    fetchClaudeMemStatus().then(data => setClaudeMemAvailable(data.available))
    fetchHooks().then(setHooks)
  }, [])

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold">Settings</h1>

      <div className="card">
        <h2 className="text-xl font-semibold mb-4">システムステータス</h2>

        <div className="space-y-4">
          <div className="flex items-center justify-between p-3 bg-background rounded">
            <div>
              <div className="font-medium">Harness UI Server</div>
              <div className="text-sm text-muted-foreground">localhost:37778</div>
            </div>
            <span className="text-green-400">● 稼働中</span>
          </div>

          <div className="flex items-center justify-between p-3 bg-background rounded">
            <div>
              <div className="font-medium">claude-mem</div>
              <div className="text-sm text-muted-foreground">localhost:37777</div>
            </div>
            {claudeMemAvailable === null ? (
              <span className="text-muted-foreground">● 確認中...</span>
            ) : claudeMemAvailable ? (
              <span className="text-green-400">● 稼働中</span>
            ) : (
              <span className="text-yellow-400">● 未起動</span>
            )}
          </div>
        </div>
      </div>

      <div className="card">
        <h2 className="text-xl font-semibold mb-4">Hooks ({hooks?.count ?? 0})</h2>

        {hooks?.hooks && hooks.hooks.length > 0 ? (
          <div className="space-y-2">
            {hooks.hooks.map((hook, i) => (
              <div key={i} className="p-3 bg-background rounded">
                <div className="flex items-center gap-2">
                  <span className="text-xs px-2 py-0.5 bg-primary/20 text-primary rounded">
                    {hook.type}
                  </span>
                  <span className="font-medium">{hook.name}</span>
                </div>
                {hook.matcher && (
                  <div className="text-xs text-muted-foreground mt-1 font-mono">
                    Matcher: {hook.matcher}
                  </div>
                )}
              </div>
            ))}
          </div>
        ) : (
          <p className="text-muted-foreground text-sm">Hooks は設定されていません</p>
        )}
      </div>

      <div className="card">
        <h2 className="text-xl font-semibold mb-4">バージョン情報</h2>

        <div className="space-y-2 text-sm">
          <div className="flex justify-between">
            <span className="text-muted-foreground">Harness UI</span>
            <span>v1.0.0</span>
          </div>
          <div className="flex justify-between">
            <span className="text-muted-foreground">ポート</span>
            <span>37778</span>
          </div>
          <div className="flex justify-between">
            <span className="text-muted-foreground">技術スタック</span>
            <span>Bun + Hono + React 19</span>
          </div>
        </div>
      </div>

      <div className="card">
        <h2 className="text-xl font-semibold mb-4">リソース</h2>

        <div className="space-y-2">
          <a
            href="https://github.com/thedotmack/claude-mem"
            target="_blank"
            rel="noopener noreferrer"
            className="block p-3 bg-background rounded hover:bg-accent transition-colors"
          >
            <div className="font-medium">claude-mem</div>
            <div className="text-sm text-muted-foreground">
              メモリ管理プラグイン
            </div>
          </a>

          <a
            href="https://docs.anthropic.com/en/docs/claude-code"
            target="_blank"
            rel="noopener noreferrer"
            className="block p-3 bg-background rounded hover:bg-accent transition-colors"
          >
            <div className="font-medium">Claude Code ドキュメント</div>
            <div className="text-sm text-muted-foreground">
              公式ドキュメント
            </div>
          </a>
        </div>
      </div>
    </div>
  )
}
