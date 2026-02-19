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

## Heartbeat

### 概要

`HEARTBEAT.md` は OpenClaw の「やることリスト」。ユーザーがタスクを書き込むと、次回の cron 実行時に AI が自動で処理する。

### 空振り判定

- `HEARTBEAT.md` が存在しない → API スキップ
- 内容がヘッダー・区切り線・空チェックボックスのみ → API スキップ
- タスクが1つ以上ある → 通常実行

### タスクの書き方

```markdown
## タスク

- [ ] GitHub PR を確認して承認待ちのものを教えて
- [ ] 明日の会議の議題をまとめて
- 未読メールの中で緊急のものを対応して
```

チェックボックス形式（`- [ ]`）でも通常のリスト（`-`）でも認識される。

### 管理コマンド

```bash
/openclaw heartbeat
```

## Memory（実行履歴）

### 概要

過去の実行結果を次回プロンプトに自動注入し、文脈の継続性を実現する。

### 保存先

`.claude/state/openclaw-runs.jsonl`

### 保存内容

```json
{
  "runId": "uuid",
  "timestamp": "ISO8601",
  "service": "gmail",
  "costUsd": 0.35,
  "turns": 8,
  "durationMs": 120000,
  "status": "success",
  "context": {
    "service": "gmail",
    "timestamp": "ISO8601",
    "summary": "3通の未読メールを処理。1通返信、2通サマリー作成。",
    "key_facts": ["田中さんから会議変更の連絡", "経理から請求書の確認依頼"],
    "actions_taken": ["田中さんへ了解の返信を送信", "請求書確認を pending_human_review に記録"]
  }
}
```

### ローテーション

- 最大 500 件保持
- 超過時は古い 100 件を削除（400 件に縮小）

### 次回実行への注入

直近 3 回分の `context_snapshot` が次回プロンプトに自動挿入される:

```
## 前回の実行コンテキスト

### [2026-02-19T10:00:00Z] gmail
- サマリー: 3通の未読メールを処理
- 重要事実: 田中さんから会議変更の連絡
- 実行アクション: 田中さんへ了解の返信を送信
```

## 配信 (Delivery)

### 概要

処理結果をユーザーが設定した配信チャンネル（LINE / Slack / Discord / Gmail）に自動 push する。

### 設定

```yaml
openclaw:
  delivery:
    enabled: true
    channel: "line"           # 配信先: line / slack / discord / gmail
    only_when_actions: true   # アクションがある時のみ配信
```

### 配信先と MCP ツール

| チャンネル | MCP ツール |
|-----------|-----------|
| LINE | `mcp__line-bot__push_text_message` |
| Slack | `mcp__slack__slack_post_message` |
| Discord | `mcp__discord__discord_send` |
| Gmail | `mcp__google-workspace__gmail_send` |

### 配信条件

- `only_when_actions: true`: `actions_taken` または `pending_human_review` が1件以上ある場合のみ
- `only_when_actions: false`: 毎回配信（空レポートも含む）

## Isolated Session

### 概要

v2 では各サービスを **独立した query() セッション** で実行する（resume なし）。

### v1 との違い

| 項目 | v1 (旧) | v2 (新) |
|------|---------|---------|
| セッション | 全サービスで共有 (resume) | サービス別に独立 (毎回新規) |
| 文脈汚染 | あり（Gmail の内容が LINE に漏れる可能性） | なし |
| Memory | なし | context_snapshot で前回の要約を注入 |
| モデル | 全サービス共通 | サービス別に設定可能 |
| 予算 | 全体で $1.00 | サービス別 + 全体上限 |

## ログ

### ログファイル

`.claude/logs/openclaw-daemon.log`

### ログローテーション

- 5 MB 超過時に自動ローテーション
- 最大 3 世代保持（`.log.1`, `.log.2`, `.log.3`）

### ログフォーマット（NDJSON）

```json
{"ts":"2026-02-19T10:00:00.000Z","level":"info","event":"daemon-started","interval":"*/30 * * * *","services":["gmail","calendar"],"pid":12345}
{"ts":"2026-02-19T10:00:00.100Z","level":"info","event":"heartbeat-check","hasWork":true,"tasks":["GitHub PR確認"]}
{"ts":"2026-02-19T10:00:01.000Z","level":"info","event":"service-start","service":"gmail","model":"sonnet"}
{"ts":"2026-02-19T10:02:30.000Z","level":"info","event":"service-complete","service":"gmail","turns":8,"cost":0.35,"duration_ms":149000}
{"ts":"2026-02-19T10:02:31.000Z","level":"info","event":"delivery-sent","channel":"line","actions":3}
```

### ログイベント

| イベント | レベル | 説明 |
|---------|-------|------|
| `daemon-started` | info | デーモン起動 |
| `daemon-shutdown` | info | デーモン停止 |
| `heartbeat-check` | info | Heartbeat チェック結果 |
| `heartbeat-skip` | info | Heartbeat が空のため API スキップ |
| `service-start` | info | サービス別実行開始 |
| `service-complete` | info | サービス別実行完了 |
| `service-error` | error | サービス別実行失敗 |
| `service-parse-error` | warn | サービス出力の JSON パース失敗 |
| `service-validation-error` | warn | サービス出力の Zod バリデーション失敗 |
| `mcp-env-missing` | warn | MCP サーバーの環境変数未設定 |
| `delivery-sent` | info | 配信完了 |
| `delivery-error` | error | 配信失敗 |
| `delivery-skip` | info | 配信スキップ（条件未達） |
| `cron-tick` | info | cron 実行開始 |
| `cron-skip` | warn | 前回実行が未完了のためスキップ |
| `run-complete` | info | 全体実行完了 |
| `run-failed` | error | 全体実行失敗 |
| `budget-exceeded` | warn | 予算上限超過 |

## セッション管理（レガシー）

> **Note**: v2 では `session-manager.ts` の resume 機能は非推奨。
> Memory（run-history.ts）が文脈の継続性を担う。

### セッションファイル

`.claude/state/openclaw-session.json` — レガシー互換のため残存。

## コスト管理

### 予算上限

- **全体上限**: `max_budget_usd` で 1 回の cron 実行あたりの上限を設定（デフォルト: $1.00）
- **サービス別上限**: `services.<name>.max_budget_usd` でサービスごとの上限

### コスト見積もり (v2)

| サービス | モデル | 平均ターン数 | 推定コスト/回 |
|---------|-------|------------|-------------|
| Gmail | sonnet | 8-10 | $0.30-0.40 |
| Calendar | haiku | 3-5 | $0.05-0.10 |
| LINE | sonnet | 4-6 | $0.10-0.15 |
| Slack | sonnet | 5-8 | $0.10-0.15 |
| Discord | haiku | 3-4 | $0.05-0.10 |

### コスト最適化

1. **Heartbeat**: タスクがなければ API を呼ばない（$0.00）
2. 不要なサービスは `enabled: false` に
3. 低優先度サービスは `model: haiku` に設定
4. `max_turns` を必要最小限に設定
5. `cron_interval` を `"0 * * * *"`（1時間間隔）に変更
6. 当日の累計コストを `openclaw-runs.jsonl` で追跡
