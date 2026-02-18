# デーモン管理

## 起動

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/openclaw-start.sh"
```

- Bun でデーモンプロセスをバックグラウンド起動
- PID を `/tmp/openclaw-daemon.pid` に記録
- 初回起動時は `bun install` を自動実行
- 起動直後に 1 回即時実行し、以降は cron 間隔で定期実行

## 停止

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/openclaw-stop.sh"
```

- SIGTERM で graceful shutdown（最大10秒待機）
- 応答なしの場合は SIGKILL で強制終了
- PID ファイルをクリーンアップ

## 状態確認

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/openclaw-status.sh"
```

表示内容:
- プロセス状態（RUNNING / STOPPED）
- PID
- 稼働時間（uptime）
- 最新ログ（直近5行）

## ログ

### ログファイル

`.claude/logs/openclaw-daemon.log`

### ログフォーマット（NDJSON）

```json
{"ts":"2026-02-18T10:00:00.000Z","level":"info","event":"daemon-started","interval":"*/30 * * * *","services":["gmail","calendar"],"pid":12345}
{"ts":"2026-02-18T10:00:01.000Z","level":"info","event":"cron-tick","runId":"abc-123","interval":"*/30 * * * *"}
{"ts":"2026-02-18T10:02:30.000Z","level":"info","event":"run-complete","runId":"abc-123","subtype":"success","turns":8,"cost":0.42,"duration_ms":149000}
```

### ログイベント

| イベント | レベル | 説明 |
|---------|-------|------|
| `daemon-started` | info | デーモン起動 |
| `daemon-shutdown` | info | デーモン停止 |
| `cron-tick` | info | cron 実行開始 |
| `cron-skip` | warn | 前回実行が未完了のためスキップ |
| `run-complete` | info | 実行完了（コスト・ターン数含む） |
| `run-failed` | error | 実行失敗 |

## セッション管理

### セッションファイル

`.claude/state/openclaw-session.json`

```json
{
  "sessionId": "session_abc123",
  "updatedAt": "2026-02-18T10:02:30.000Z"
}
```

### セッション resume

- デーモンは前回のセッション ID を保持
- 次回実行時に `resume` オプションで前回の文脈を引き継ぐ
- エラー発生時はセッション ID をクリアし、新規セッションで再開

### 文脈の継続性

Agent SDK の auto-compaction により、長時間のセッションでも文脈窓を超えない。
過去のやり取りは自動的に要約され、重要な情報が保持される。

## コスト管理

### 予算上限

`max_budget_usd` で 1 回あたりの上限を設定（デフォルト: $1.00）。
超過時は `error_max_budget_usd` で停止し、次の cron まで待機。

### コスト見積もり

| サービス数 | 平均ターン数 | 推定コスト/回 | 月額推定（30分間隔） |
|-----------|------------|-------------|-------------------|
| 1 | 5-8 | $0.20-0.40 | $300-600 |
| 3 | 10-15 | $0.50-0.80 | $700-1,200 |
| 5 | 15-20 | $0.80-1.00 | $1,200-1,500 |

### コスト最適化

1. 不要なサービスは `enabled: false` に
2. `max_turns` を必要最小限に設定
3. `cron_interval` を `"0 * * * *"`（1時間間隔）に変更
4. model を sonnet に設定（デフォルト）
