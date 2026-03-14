# Claude Code 2.1.74+ 新機能活用ガイド（完全版）

> **概要**: Harness が活用する Claude Code 2.1.74+ の全機能一覧。
> CLAUDE.md の Feature Table の完全版（詳細説明付き）。

## 機能一覧

| 機能 | 活用スキル | 用途 |
|------|-----------|------|
| **Task tool メトリクス** | parallel-workflows | サブエージェントのトークン/ツール/時間を集計 |
| **`/debug` コマンド** | troubleshoot | 複雑なセッション問題の診断 |
| **PDF ページ範囲** | notebookLM, harness-review | 大型ドキュメントの効率的な処理 |
| **Git log フラグ** | harness-review, CI, harness-release | 構造化されたコミット分析 |
| **OAuth 認証** | codex-review | DCR 非対応 MCP サーバーの設定 |
| **68% メモリ最適化** | session-memory, session | `--resume` の積極的活用 |
| **サブエージェント MCP** | task-worker | 並列実行時の MCP ツール共有 |
| **Reduced Motion** | harness-ui | アクセシビリティ設定 |
| **TeammateIdle/TaskCompleted Hook** | breezing | チーム監視の自動化 |
| **Agent Memory (memory frontmatter)** | task-worker, code-reviewer | 永続的学習 |
| **Fast mode (Opus 4.6)** | 全スキル | 高速出力モード |
| **自動メモリ記録** | session-memory | セッション間知識の自動永続化 |
| **スキルバジェットスケーリング** | 全スキル | コンテキスト窓の 2% に自動調整 |
| **Task(agent_type) 制限** | agents/ | サブエージェント種類制限 |
| **Plugin settings.json** | setup | init トークン削減・即時セキュリティ保護 |
| **Worktree isolation** | breezing, parallel-workflows | 同一ファイル並列書き込み安全化 |
| **Background agents** | generate-video | 非同期シーン生成 |
| **ConfigChange hook** | hooks | 設定変更監査 |
| **last_assistant_message** | session-memory | セッション品質評価 |
| **Sonnet 4.6 (1M context)** | 全スキル | 大規模コンテキスト処理 |
| **メモリリーク修正 (v2.1.50〜v2.1.63)** | breezing, work | 長時間チームセッションの安定性向上 |
| **`claude agents` CLI (v2.1.50)** | troubleshoot | エージェント定義の診断・確認 |
| **WorktreeCreate/Remove hook (v2.1.50)** | breezing | Worktree ライフサイクル自動セットアップ・クリーンアップ（実装済み） |
| **`claude remote-control` (v2.1.51)** | 調査済み・将来対応 | 外部ビルドとローカル環境サービング |
| **`/simplify` (v2.1.63)** | work | Phase 3.5 Auto-Refinement: 実装後の自動コード洗練 |
| **`/batch` (v2.1.63)** | breezing | 横展開タスクの並列マイグレーション委任 |
| **`code-simplifier` プラグイン** | work | `--deep-simplify` 時の深いリファクタリング |
| **HTTP hooks (v2.1.63)** | hooks | JSON POST による外部サービス連携フック（実装済み） |
| **Auto-memory worktree 共有 (v2.1.63)** | breezing | worktree エージェント間のメモリ共有 |
| **`/clear` スキルキャッシュリセット (v2.1.63)** | troubleshoot | スキル開発時のキャッシュ問題診断 |
| **`ENABLE_CLAUDEAI_MCP_SERVERS` (v2.1.63)** | setup | claude.ai MCP サーバーの無効化オプション |
| **Effort levels + ultrathink (v2.1.68)** | harness-work | 多要素スコアリングで複雑タスクに ultrathink 自動注入 |
| **Agent hooks (v2.1.68)** | hooks | type: "agent" による LLM エージェントコード品質ガード |
| **Opus 4/4.1 削除（v2.1.68）** | — | first-party API から削除。Opus 4.6 へ自動移行 |
| **`${CLAUDE_SKILL_DIR}` 変数 (v2.1.69)** | 全スキル | スキル内の参照パスを実行環境非依存で解決 |
| **InstructionsLoaded hook (v2.1.69)** | hooks | セッション前の instructions 読み込みイベントを追跡 |
| **`agent_id` / `agent_type` 追加 (v2.1.69)** | hooks, breezing | teammate の識別・ロール判定を安定化 |
| **`{"continue": false}` teammate 応答 (v2.1.69)** | breezing | 全タスク完了時の自動停止を実現 |
| **`/reload-plugins` (v2.1.69)** | 全スキル | スキル・フック編集後の即時反映 |
| **`includeGitInstructions: false` (v2.1.69)** | work, breezing | git 指示が不要な場面のトークン削減 |
| **`git-subdir` plugin source (v2.1.69)** | setup, release | サブディレクトリ管理された plugin source に対応 |
| **Auto Mode rollout prep** | breezing, work | `bypassPermissions` からの移行候補。現行 shipped default は `bypassPermissions`、`--auto-mode` は互換な親セッション向け opt-in marker |
| **Per-agent hooks (v2.1.69+)** | agents-v3/ | エージェント定義の frontmatter に `hooks` フィールドを追加。Worker に PreToolUse ガード、Reviewer に Stop ログを設定 |
| **Agent `isolation: worktree` (v2.1.50+)** | agents-v3/worker | Worker エージェント定義に `isolation: worktree` を追加。並列書き込み時の自動 worktree 分離 |
| **Compaction 画像保持 (v2.1.70)** | notebookLM, harness-review | サマリーリクエストで画像を保持。プロンプトキャッシュ再利用改善 |
| **サブエージェント最終レポート簡潔化 (v2.1.70)** | breezing, harness-work | サブエージェント完了レポートのトークン消費削減 |
| **`--resume` スキルリスト再注入廃止 (v2.1.70)** | session | セッション再開時に ~600 tokens 節約 |
| **Plugin hooks 修正 (v2.1.70)** | hooks | Stop/SessionEnd が /plugin 後に発火、テンプレート衝突解消、WorktreeCreate/Remove 正常動作 |
| **Teammate ネスト防止追加修正 (v2.1.70)** | breezing | v2.1.69 対応に加え、追加のネスト防止修正 |
| **PostToolUseFailure hook (v2.1.70)** | hooks | ツール呼び出し失敗時に発火する新フックイベント |
| **`/loop` + Cron スケジューリング (v2.1.71)** | breezing, harness-work | `/loop 5m <prompt>` で定期実行。タスク進捗の自動監視に活用 |
| **Background Agent 出力パス修正 (v2.1.71)** | breezing, parallel-workflows | 完了通知に出力ファイルパスを含む。圧縮後も結果回収可能 |
| **`--print` チームエージェント hang 修正 (v2.1.71)** | CI 連携 | `--print` モードでのチームエージェント hang を修正 |
| **Plugin インストール並列実行修正 (v2.1.71)** | breezing | 複数インスタンス時のプラグイン状態安定化 |
| **Marketplace 改善 (v2.1.71)** | setup | @ref パーサー修正、update merge conflict 修正、MCP server 重複排除、/plugin uninstall が settings.local.json 使用 |
| **Subagent `background` フィールド (v2.1.71+)** | breezing, parallel-workflows | エージェント定義に `background: true` を追加。常にバックグラウンドタスクとして実行 |
| **Subagent `local` メモリスコープ (v2.1.71+)** | agents-v3/ | `memory: local` で `.claude/agent-memory-local/` に保存。VCS にコミットしない機密性の高い学習を分離 |
| **Agent Teams 実験フラグ (v2.1.71+)** | breezing | `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` 環境変数で Agent Teams を有効化。公式ドキュメント化済み |
| **`/agents` コマンド (v2.1.71+)** | troubleshoot, setup | エージェントの対話的管理UI。作成・編集・削除・一覧を GUI で操作 |
| **Desktop Scheduled Tasks (v2.1.71+)** | harness-work | `~/.claude/scheduled-tasks/<task-name>/SKILL.md` 形式で定期タスクを定義。Desktop アプリから管理 |
| **`CronCreate/CronList/CronDelete` ツール (v2.1.71+)** | breezing, harness-work | `/loop` の内部ツール。セッション内での定期タスク作成・管理 |
| **`CLAUDE_CODE_DISABLE_CRON` 環境変数 (v2.1.71+)** | setup | `=1` で Cron スケジューラを無効化。セキュリティポリシーで定期実行を制限する環境向け |
| **`--agents` CLI フラグ (v2.1.71+)** | breezing, CI | JSON でセッションレベルのエージェント定義を渡す。ディスクに保存されない一時的なエージェント構成 |
| **`ExitWorktree` ツール (v2.1.72)** | breezing, harness-work | プログラム的に worktree セッションを離脱するツール |
| **Effort levels 簡素化 (v2.1.72)** | harness-work | 永続レベルは `low/medium/high`（`○ ◐ ●`）。`max` は Opus 4.6 のセッション専用オプションとして存続。`/effort auto` でデフォルトリセット |
| **Agent tool `model` パラメータ復活 (v2.1.72)** | breezing | per-invocation model override が再度利用可能に |
| **`/plan` description 引数 (v2.1.72)** | harness-plan | `/plan fix the auth bug` のように説明付きでプランモードに入れる |
| **並列ツール呼び出し修正 (v2.1.72)** | breezing, harness-work | Read/WebFetch/Glob 失敗が sibling 呼び出しをキャンセルしなくなった（Bash エラーのみカスケード） |
| **Worktree isolation 修正 (v2.1.72)** | breezing | Task resume 時の cwd 復元、background 通知に worktreePath を含む |
| **`/clear` バックグラウンドエージェント保持 (v2.1.72)** | breezing | `/clear` はフォアグラウンドタスクのみ停止。バックグラウンドエージェントは存続 |
| **Hooks 修正群 (v2.1.72)** | hooks | transcript_path 修正、PostToolUse ダブル表示修正、async hooks stdin 修正、skill hooks 二重発火修正 |
| **HTML コメント非表示 (v2.1.72)** | 全スキル | CLAUDE.md の `<!-- -->` が自動注入時に非表示。Read ツールでは引き続き可視 |
| **Bash auto-approval 追加 (v2.1.72)** | guardrails | `lsof`, `pgrep`, `tput`, `ss`, `fd`, `fdfind` が許可リストに追加 |
| **プロンプトキャッシュ修正 (v2.1.72)** | 全スキル | SDK `query()` のキャッシュ無効化修正。入力トークンコスト最大 12 倍削減 |
| **Output Styles (v2.1.72+)** | 全スキル | `.claude/output-styles/` にカスタム出力スタイルを定義。`harness-ops` で Plan/Work/Review の構造化出力を提供 |
| **`permissionMode` in agent frontmatter (v2.1.72+)** | agents-v3/ | エージェント定義 YAML に `permissionMode` を明示宣言。spawn 時の `mode` 指定が不要に |
| **Agent Teams 公式ベストプラクティス (v2.1.72+)** | breezing | 5-6 tasks/teammate ガイドライン、`teammateMode` 設定、plan approval パターンを team-composition に反映 |
| **Sandboxing (`/sandbox`)** | breezing, harness-work | OS レベルのファイルシステム/ネットワーク隔離。`bypassPermissions` の補完レイヤー |
| **`opusplan` モデルエイリアス** | breezing | Plan 時は Opus、実行時は Sonnet に自動切替。Lead の Plan → Execute フローに最適 |
| **`CLAUDE_CODE_SUBAGENT_MODEL` 環境変数** | breezing, harness-work | サブエージェントのモデルを一括指定。Worker/Reviewer のモデル制御を集約 |
| **`availableModels` 設定** | setup | 利用可能モデルの制限リスト。エンタープライズ運用でのモデルガバナンス |
| **Checkpointing (`/rewind`)** | harness-work | セッション状態の追跡・巻き戻し・要約。安全な探索と実験をサポート |
| **Code Review (managed service)** | harness-review | マルチエージェント PR レビュー + `REVIEW.md`。Teams/Enterprise 向け Research Preview |
| **Status Line (`/statusline`)** | 全スキル | カスタムシェルスクリプトで状態表示バー。コンテキスト使用量・コスト・git 状態を常時モニタリング |
| **1M Context Window (`sonnet[1m]`)** | harness-review, breezing | 大規模コードベース分析に 100 万トークンコンテキスト窓を活用 |
| **1M Context Window (`opus[1m]`) (v2.1.75)** | breezing, harness-review | Opus 4.6 の 1M コンテキスト窓。Max/Team/Enterprise では自動昇格。Lead セッションでの包括的分析に最適 |
| **Memory file timestamps (v2.1.75)** | session-memory, memory | メモリファイルに最終更新タイムスタンプを自動付与。Claude が鮮度を判断し、古い記憶と新しい記憶を区別 |
| **Async hook suppression (v2.1.75)** | breezing, hooks | 非同期フック完了メッセージをデフォルト非表示に。Breezing 並列実行時のノイズ削減。`--verbose` で表示可能 |
| **`/effort max` session-only (v2.1.75+)** | harness-work, harness-plan | Opus 4.6 限定の最深推論モード。`low/medium/high` は永続だが `max` はセッション単位で自動リセット |
| **Token estimation fix (v2.1.75)** | 全スキル | thinking/tool_use ブロックのトークン過大推定を修正。早すぎるコンパクションを防止し、長時間セッションの安定性向上 |
| **Per-model Prompt Caching Control** | 全スキル | `DISABLE_PROMPT_CACHING_*` でモデル別にキャッシュ制御。デバッグ・コスト最適化 |
| **`CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING`** | harness-work | Adaptive Reasoning 無効化で固定 thinking budget に復帰。予測可能なコスト制御 |
| **Chrome Integration (`--chrome`, beta)** | harness-work, harness-review | ブラウザ自動化でUI テスト・フォーム入力・コンソールデバッグ。`/chrome` でセッション内切替 |
| **LSP サーバー統合 (`.lsp.json`)** | setup | Language Server Protocol で型情報・診断・参照検索をリアルタイム提供。`pyright-lsp`, `typescript-lsp`, `rust-lsp` 利用可能 |
| **`SubagentStart`/`SubagentStop` matcher (v2.1.72+)** | breezing, hooks | settings.json レベルで agent type 別にサブエージェントライフサイクルを監視。Worker/Reviewer/Scaffolder/Video Generator を個別トラッキング |
| **Agent Teams: Task Dependencies** | breezing | タスク間依存の自動管理。依存完了で blocked タスクが自動 unblock。ファイルロックで claiming 競合防止 |
| **`--teammate-mode` CLI フラグ (v2.1.72+)** | breezing | セッション単位で `in-process`/`tmux` 表示モードを切替。`claude --teammate-mode in-process` |
| **`CLAUDE_CODE_DISABLE_BACKGROUND_TASKS` (v2.1.72+)** | setup | `=1` で全バックグラウンドタスク機能を無効化。セキュリティポリシーでバックグラウンド実行を制限する環境向け |
| **`CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` (v2.1.72+)** | breezing, harness-work | サブエージェントの auto-compaction しきい値を調整（デフォルト 95%）。`50` で早期圧縮、長時間 Worker の安定性向上 |
| **`cleanupPeriodDays` 設定 (v2.1.72+)** | setup | サブエージェント transcript の自動クリーンアップ期間（デフォルト 30 日） |
| **`/btw` サイドクエスチョン (v2.1.72+)** | 全スキル | 現在のコンテキストを保持したまま短い質問。ツールアクセスなし、履歴に残らない。サブエージェント起動の軽量代替 |
| **Plugin CLI コマンド群 (v2.1.72+)** | setup | `claude plugin install/uninstall/enable/disable/update` + `--scope` フラグ。スクリプトによる自動化対応 |
| **Remote Control 強化 (v2.1.72+)** | 調査済み・将来対応 | `/remote-control` (`/rc`) でセッション内から有効化。`--name`, `--sandbox`, `--verbose` フラグ。`/mobile` で QR コード表示。自動再接続対応 |
| **`skills` フィールド in agent frontmatter (v2.1.72+)** | agents-v3/ | サブエージェントにスキルをプリロード。Worker に `harness-work`+`harness-review`、Reviewer に `harness-review`、Scaffolder に `harness-setup`+`harness-plan` を注入（実装済み） |
| **`modelOverrides` 設定 (v2.1.73)** | setup, breezing | モデルピッカーのエントリを Bedrock ARN 等のカスタムプロバイダモデル ID にマッピング |
| **`/output-style` 非推奨化 (v2.1.73)** | 全スキル | `/config` に移行。出力スタイル選択はコンフィグメニューに統合 |
| **Bedrock/Vertex Opus 4.6 デフォルト化 (v2.1.73)** | breezing | クラウドプロバイダのデフォルト Opus が 4.1 → 4.6 に更新 |
| **`autoMemoryDirectory` 設定 (v2.1.74)** | session-memory, setup | 自動メモリの保存パスをカスタマイズ。プロジェクト固有のメモリ分離に対応 |
| **`CLAUDE_CODE_SESSIONEND_HOOKS_TIMEOUT_MS` (v2.1.74)** | hooks | SessionEnd フックのタイムアウトを設定可能に（従来は 1.5 秒固定で kill） |
| **Full model ID 修正 (v2.1.74)** | agents-v3/, breezing | `claude-opus-4-6` 等の完全モデル ID がエージェント frontmatter・JSON config で認識されるように |
| **Streaming API メモリリーク修正 (v2.1.74)** | breezing, harness-work | ストリーミングレスポンスバッファの無制限 RSS 増大を修正 |
| **`--remote` / Cloud Sessions** | breezing, harness-work | `--remote` でターミナルからクラウドセッションを起動。非同期タスク実行 |
| **`/teleport` (`/tp`)** | session | クラウドセッションをローカルターミナルに取り込み |
| **`CLAUDE_CODE_REMOTE` 環境変数** | hooks, session-env-setup | クラウド vs ローカル実行の検出。フックの条件分岐に活用 |
| **`CLAUDE_ENV_FILE` SessionStart 永続化** | hooks, session-env-setup | SessionStart フックから後続 Bash コマンドへ環境変数を永続化 |
| **Slack Integration (`@Claude`)** | harness-work (将来対応) | Slack チャネルからコーディングタスクをルーティング。HTTP hooks で連携可能 |
| **Server-managed settings (public beta)** | setup | サーバー配信による一括設定管理。Teams/Enterprise 向け |
| **Microsoft Foundry** | setup, breezing | 新クラウドプロバイダとして追加 |
| **`PreCompact` hook** | hooks | コンテキスト圧縮前の状態保存と WIP タスク警告（実装済み） |
| **`Notification` hook event** | hooks | 通知発火時のカスタムハンドラ |

## 機能詳細

### Task tool メトリクス

サブエージェントが消費したトークン数・ツール呼び出し数・実行時間を集計できる。
`parallel-workflows` スキルでは複数サブエージェントのメトリクスを集約し、コスト分析に使用。

```
metrics: {tokens: 40000, tools: 7, duration: 67s}
```

### `/debug` コマンド

セッション診断用コマンド。複雑なエラーや予期しない挙動の原因調査に使用。
`troubleshoot` スキルが自動的に起動し、問題を体系的に診断。

### PDF ページ範囲指定

大型 PDF を読み込む際にページ範囲を指定可能（例: `pages: "1-5"`）。
`notebookLM` スキルでのドキュメント処理、`harness-review` での大型仕様書参照に活用。

### Git log フラグ

`git log` の構造化オプション（`--format`, `--stat`, `--since` 等）を活用。
リリースノート生成、コミット分析、変更追跡を効率化。

### OAuth 認証

DCR（Dynamic Client Registration）非対応 MCP サーバーへの OAuth 認証設定。
`codex-review` スキルでの Codex CLI 接続に使用。

### 68% メモリ最適化

`--resume` フラグによるセッション再開時のメモリ使用量削減。
長時間作業セッションでのコンテキスト継続に有効。

### サブエージェント MCP

Task tool で起動したサブエージェントが親セッションの MCP ツールを共有できる。
`task-worker` での並列実装時に、各エージェントが同じ MCP ツールセットを使用可能。

### Reduced Motion

アクセシビリティ設定。モーション/アニメーションを削減するオプション。
`harness-ui` スキルで UI 生成時に考慮。

### TeammateIdle/TaskCompleted Hook

Breezing チームのメンバーがアイドル状態になった時、またはタスク完了時に発火するフック。
`scripts/hook-handlers/teammate-idle.sh` と `task-completed.sh` で処理。

```json
"TeammateIdle": [{"hooks": [{"type": "command", "command": "...teammate-idle", "timeout": 10}]}],
"TaskCompleted": [{"hooks": [{"type": "command", "command": "...task-completed", "timeout": 10}]}]
```

### Agent Memory (memory frontmatter)

エージェント定義 YAML の `memory: project` フィールドで永続メモリを有効化。
`task-worker`, `code-reviewer` が過去の実装パターン・失敗と解決策を跨ぎセッションで学習。

### Fast mode (Opus 4.6)

`/fast` コマンドで切り替える高速出力モード。同じ Opus 4.6 モデルを使用。
全スキルで利用可能。長い実装タスクでの待ち時間短縮に有効。

### 自動メモリ記録

セッション終了時に学習内容を自動的にメモリファイルへ永続化。
`session-memory` スキルが管理。次のセッションで前回の文脈を自動復元。

### スキルバジェットスケーリング

SKILL.md の文字数予算がコンテキスト窓の 2% に自動調整される。
推奨 500 行は目安値。実効上限はモデルのコンテキスト窓サイズに依存。

### Task(agent_type) 制限

Task tool 呼び出し時に `subagent_type` を指定し、サブエージェントの種類を制限。
`agents/` 定義と組み合わせて、意図したエージェントのみを起動することを保証。

### Plugin settings.json

プラグインの `settings.json` で初期化時の設定を事前定義。
init トークン消費を削減し、セキュリティポリシーをセッション開始直後から適用。

### Worktree isolation

`git worktree` を使って同一ファイルへの並列書き込みを安全化。
`breezing` と `parallel-workflows` での複数エージェント並列実装時のコンフリクト防止。

### Background agents

非同期でバックグラウンドエージェントを起動。完了を待たずに他の処理を継続可能。
`generate-video` スキルでの複数シーン並列生成に使用。

### ConfigChange hook

設定ファイル（`settings.json` 等）が変更された時に発火するフック。
`scripts/hook-handlers/config-change.sh` で変更を記録・監査。

### last_assistant_message

セッション終了時の最後のアシスタントメッセージを参照できる機能。
`session-memory` スキルがセッション品質の自己評価に使用。

### Sonnet 4.6 (1M context)

最大 1M トークンのコンテキスト窓を持つ Sonnet 4.6 モデル。
大規模コードベースの分析、長大なドキュメント処理に対応。全スキルで利用可能。

> 補足: 2.1.69 系では旧 Sonnet 4.5 参照は Sonnet 4.6 へ自動マイグレーションされる前提で運用する。

### メモリリーク修正 (v2.1.50〜v2.1.63)

CC 2.1.50 で LSP 診断データ、大型ツール出力、ファイル履歴、シェル実行に関するメモリリークが修正された。
完了タスクのガベージコレクションも実装され、`/breezing` 等の長時間チームセッションの安定性が大幅に改善。
v2.1.63 ではさらに MCP 再接続時のリーク、git root キャッシュ、JSON パースキャッシュ、Teammate メッセージ保持、シェルコマンドプレフィックスキャッシュのリークが追加修正された。
Harness 側は JSONL ローテーション（500→400 行）やアトミック更新で既に独自対策を実施済み。

### `claude agents` CLI (v2.1.50)

`claude agents list` で登録済みエージェントの一覧を表示。
`troubleshoot` スキルでエージェント spawn 失敗時の診断に活用。

```bash
claude agents list   # 登録済みエージェントの一覧
```

### WorktreeCreate/WorktreeRemove hook (v2.1.50)

Worktree の作成・削除時に発火するライフサイクルフック。
`/breezing` 並列ワークフローでの自動セットアップ・クリーンアップに活用。
`scripts/hook-handlers/worktree-create.sh` と `worktree-remove.sh` で実装済み。

### `claude remote-control` (v2.1.51)

外部ビルドシステムとローカル環境のサービングを可能にするサブコマンド。
将来的に Breezing のクロスセッション制御や CI 連携に活用の余地あり。

### `/simplify` (v2.1.63)

CC 2.1.63 で追加された実装後の自動コード洗練コマンド。
`/work` の Phase 3.5 Auto-Refinement として統合され、実装完了後に自動でコードを簡潔化・整理する。
`code-simplifier` プラグインと組み合わせて `--deep-simplify` オプションで深いリファクタリングも可能。

### `/batch` (v2.1.63)

横展開タスク（同じ変更を複数ファイルに適用するマイグレーション等）を並列委任するコマンド。
`/breezing` と組み合わせて、Breezing チームに一括マイグレーションを並列実行させる際に使用。
繰り返し作業の効率化と、人為的ミスの削減に有効。

### `code-simplifier` プラグイン

`/simplify` の深いリファクタリングモードを担う外部プラグイン。
`--deep-simplify` 指定時に起動し、複雑なロジックの分解・不要な抽象化の除去・命名の改善を自動実行。
通常の `/simplify` は軽量、`--deep-simplify` はより踏み込んだリファクタリングを実施。

### HTTP hooks (v2.1.63)

CC 2.1.63 で追加された新しいフック形式。既存の `command` / `prompt` タイプに加え `http` タイプが利用可能になった。
JSON を指定 URL に POST し、外部サービス（Slack、ダッシュボード、メトリクス収集等）と連携できる。
詳細は [.claude/rules/hooks-editing.md](../.claude/rules/hooks-editing.md) の「http Type」セクションを参照。

### Auto-memory worktree 共有 (v2.1.63)

CC 2.1.63 で `isolation: "worktree"` 使用時に Agent Memory が worktree 間で共有されるようになった。
`/breezing` の並列 Implementer が各自 worktree 分離で作業しながら、同一の MEMORY.md を参照・更新可能。
Implementer 間の知識共有と、同一バグへの重複対応を防止する。

### `/clear` スキルキャッシュリセット (v2.1.63)

CC 2.1.63 で追加されたスキルキャッシュのリセットコマンド。
スキルファイルを編集後に古いキャッシュで動作する問題（スキル開発時に頻発）を `/clear` で解消できる。
`troubleshoot` スキルのキャッシュ問題診断ステップに組み込み済み。

### `ENABLE_CLAUDEAI_MCP_SERVERS` (v2.1.63)

CC 2.1.63 で追加された環境変数。`false` を設定すると claude.ai が提供する MCP サーバーを無効化できる。
セキュリティポリシー上、外部 MCP サーバーへの接続を制限したい環境での利用を想定。
`setup` スキルの環境初期化チェックリストに追加済み。

### Agent hooks (v2.1.68)

CC 2.1.68 で追加された `type: "agent"` フック。LLM エージェントがフック判断を行うことで、正規表現では検出困難なコード品質問題を動的に判断できる。
Harness では3箇所に限定採用し、コスト管理のため `model: "haiku"` と `matcher` で対象を絞る:

- **PreToolUse Write|Edit**: シークレット埋め込み・TODO スタブ・セキュリティ脆弱性のガード
- **Stop**: WIP タスク残存ガード（Plans.md の `cc:WIP` タスクが残っていないか確認）
- **PostToolUse Write|Edit**: 非同期コードレビュー（品質・命名・単一責任）

効果不足時は `command` 型にロールバック可能な設計。

### Effort levels + ultrathink (v2.1.68)

CC 2.1.68 で Opus 4.6 が **medium effort** をデフォルトに変更。`ultrathink` キーワードで1ターンのみ high effort（extended thinking）を有効化できる。
`harness-work` スキルが多要素スコアリング（変更ファイル数・対象ディレクトリ・キーワード・失敗履歴・PM 明示指定）でスコアを算出し、閾値 3 以上で Worker spawn prompt 冒頭に `ultrathink` を自動注入する。
詳細は `skills-v3/harness-work/SKILL.md` の「Effort レベル制御」セクション参照。

### Opus 4/4.1 削除（v2.1.68）

CC 2.1.68 で Opus 4 と Opus 4.1 が first-party API から削除された。Harness が対象エージェントで `model: opus` 相当を指定している場合、Opus 4.6 へ自動移行される。
Worker/Reviewer エージェントは `model: sonnet` のため影響なし。Lead（Opus 使用時）のみ medium effort がデフォルトになる変更を受ける。

### `${CLAUDE_SKILL_DIR}` 変数 (v2.1.69)

CC 2.1.69 でスキル実行時の基準パス変数 `${CLAUDE_SKILL_DIR}` が導入された。
Harness では `SKILL.md` から `references/*.md` を参照するリンクを `${CLAUDE_SKILL_DIR}/references/...` へ統一し、ミラー構成（codex/opencode）でも同じ参照を維持する。

### InstructionsLoaded hook (v2.1.69)

CC 2.1.69 で `InstructionsLoaded` イベントが追加された。Harness では
`scripts/hook-handlers/instructions-loaded.sh` を新設し、instructions 読み込み完了時の軽量トラッキングと事前検証に利用する。

### `agent_id` / `agent_type` 追加 (v2.1.69)

Teammate 系イベントに `agent_id` / `agent_type` が追加された。
Harness の guardrail は `session_id` 前提から `agent_id` 優先（fallback: `session_id`）へ拡張し、role ガードを安定化した。

### `{"continue": false}` teammate 応答 (v2.1.69)

`TeammateIdle` / `TaskCompleted` で `{"continue": false, "stopReason": "..."}` を返せるようになった。
Harness では stop リクエスト受信時と全タスク完了時に同レスポンスを返し、breezing の停止判定を明示化した。

### `/reload-plugins` (v2.1.69)

スキル・フック編集後にセッション再起動なしで反映するため、開発フローに `/reload-plugins` を追加。
編集 → `/reload-plugins` → 再実行、を標準手順とする。

### `includeGitInstructions: false` (v2.1.69)

git 指示を常時埋め込む必要がないタスクでは `includeGitInstructions: false` を適用し、トークン消費を抑制できる。
Harness では breezing/work の軽量タスク（ドキュメント更新など）での活用を推奨する。

### `git-subdir` plugin source (v2.1.69)

plugin source を monorepo のサブディレクトリで管理する `git-subdir` 方式がサポートされた。
Harness では現状 `.claude-plugin/plugin.json` に追加フィールドを強制せず、リリース時に `plugin source` を明示して運用する（互換性優先）。

### Compaction 画像保持 (v2.1.70)

CC 2.1.70 でコンテキスト圧縮（Compaction）時にサマリーリクエストが画像を保持するようになった。
これにより、スクリーンショットや図表を含むセッションで Compaction 後も画像コンテキストが維持される。
プロンプトキャッシュの再利用率も改善され、画像を扱うスキル全般で効率が向上。

### サブエージェント最終レポート簡潔化 (v2.1.70)

サブエージェント完了時の最終レポートが簡潔化され、トークン消費が削減された。
`breezing` や `harness-work` で多数のサブエージェントを起動する場合、累積的なトークン節約効果が大きい。

### `--resume` スキルリスト再注入廃止 (v2.1.70)

`--resume` でセッション再開する際、スキルリストの再注入が廃止された。
これにより約 600 tokens が節約され、`session` スキルでの再開フローが軽量化。

### Plugin hooks 修正 (v2.1.70)

v2.1.70 で複数の Plugin hooks 関連バグが修正された:
- `Stop` / `SessionEnd` フックが `/plugin` コマンド実行後にも正常に発火
- 同一テンプレートを持つフック間の衝突が解消
- `WorktreeCreate` / `WorktreeRemove` フックの正常動作が確認

### Teammate ネスト防止追加修正 (v2.1.70)

v2.1.69 で対応済みの Teammate ネスト防止に追加修正が入った。
エージェントが別のエージェントを無限に spawn するカスケード問題の防止が強化された。

### PostToolUseFailure hook (v2.1.70)

CC 2.1.70 で `PostToolUseFailure` イベントが追加された。ツール呼び出しが失敗した時に発火する新しいフックイベント。
Harness では `hooks` スキルと `error-recovery` で活用し、連続失敗時の自動エスカレーション（3回連続失敗で停止）に使用。

```json
"PostToolUseFailure": [{
  "hooks": [{
    "type": "command",
    "command": "...post-tool-failure.sh",
    "timeout": 10
  }]
}]
```

### `/loop` + Cron スケジューリング (v2.1.71)

CC 2.1.71 で `/loop` コマンドが追加された。`/loop 5m <prompt>` のように間隔とプロンプトを指定すると、定期的にコマンドを実行する Cron 風スケジューリングが可能。
`breezing` では `/loop 5m /sync-status` でタスク進捗の定期チェックに活用。
既存の `TeammateIdle`（受動的・イベント駆動）と異なり、能動的に定期監視を行える。

### Background Agent 出力パス修正 (v2.1.71)

CC 2.1.71 で Background Agent の完了通知に出力ファイルパスが含まれるようになった。
これにより、圧縮後でもバックグラウンドエージェントの結果を安全に回収可能。
`breezing` や `parallel-workflows` での `run_in_background: true` が実用的に。

### `--print` チームエージェント hang 修正 (v2.1.71)

`--print` モードでチームエージェントが hang する問題が修正された。
CI パイプラインでの `claude --print` 実行時のチームエージェント安定性が向上。

### Plugin インストール並列実行修正 (v2.1.71)

複数の Claude Code インスタンスが同時にプラグインをインストールする際の状態競合が修正された。
`breezing` で複数 Teammate が同時に起動する際のプラグイン読み込み安定性が向上。

### Marketplace 改善 (v2.1.71)

CC 2.1.71 で Marketplace 周りに複数の改善が入った:
- `@ref` パーサー修正: `owner/repo@vX.X.X` 形式の参照解決が正確に
- update 時の merge conflict 修正: プラグイン更新がより安定に
- MCP server 重複排除: 同一 MCP サーバーの多重登録を防止
- `/plugin uninstall` が `settings.local.json` を使用: ユーザーローカル設定への正確な反映

### Per-agent hooks (v2.1.69+)

CC 2.1.69 でエージェント定義の frontmatter に `hooks` フィールドが追加された。
グローバル hooks.json とは別に、エージェント固有のフックを定義できる。

Harness での活用:
- **Worker**: `PreToolUse` で Write/Edit 時の `pre-tool.sh` ガードレールを適用
- **Reviewer**: `Stop` でレビューセッション完了をログ出力

エージェント定義内フックはそのエージェントのライフサイクル中のみ有効で、終了時に自動クリーンアップされる。

### Agent `isolation: worktree` (v2.1.50+)

エージェント定義の frontmatter に `isolation: worktree` を追加すると、
そのエージェントが起動時に自動で git worktree を作成し、独立したリポジトリコピーで作業する。
変更がない場合は worktree が自動クリーンアップされる。

Harness では Worker エージェントに `isolation: worktree` を追加。
`memory: project` と組み合わせることで、worktree 間で Agent Memory（MEMORY.md）が共有され、
並列 Worker が同一の学習内容を参照・更新可能。

### Auto Mode rollout ポリシー

Auto Mode は Claude Code の team execution をより安全側に寄せるための移行候補として整理している。
ただし shipped default はまだ `bypassPermissions` であり、project template や frontmatter には公式 docs に載っている permission mode のみを残す。

| レイヤー | 採用値 | 理由 |
|---------|--------|------|
| project template (`permissions.defaultMode`) | `bypassPermissions` | documented permission modes に `autoMode` が含まれないため |
| agent frontmatter (`permissionMode`) | `bypassPermissions` | 宣言的設定は documented 値のみを使うため |
| teammate 実行経路 | `bypassPermissions`（現行） | shipped default と実際の permission 継承を一致させるため |
| `--auto-mode` | opt-in marker | 親セッションが互換な permission mode の場合のみ rollout を試すため |

既定コマンド例:

```bash
/breezing all
/execute --breezing all
```

### Subagent `background` フィールド

エージェント定義の frontmatter に `background: true` を追加すると、そのエージェントは常にバックグラウンドタスクとして実行される。
明示的に `run_in_background: true` を指定しなくても、Agent tool 経由で起動するたびにバックグラウンド実行となる。

```yaml
---
name: long-running-analyzer
background: true
---
```

Harness では `breezing` の Worker spawn 時に検討可能だが、現状は Lead が明示的に `run_in_background` を制御しているため、追加適用は Phase 2 以降で検討する。

### Subagent `local` メモリスコープ

`memory: local` は `.claude/agent-memory-local/<name>/` に保存され、`.gitignore` に追加すべきパス。
`project` との違い:

| スコープ | パス | VCS コミット | ユースケース |
|---------|------|-------------|------------|
| `user` | `~/.claude/agent-memory/<name>/` | 対象外 | 全プロジェクト共通の学習 |
| `project` | `.claude/agent-memory/<name>/` | 共有可能 | チーム共有のプロジェクト知識 |
| `local` | `.claude/agent-memory-local/<name>/` | 非推奨 | 個人固有・機密性の高い学習 |

Harness では Worker/Reviewer ともに `memory: project` を使用中。`local` は個人的なデバッグパターンの記録に適するが、チーム共有を優先するため現行設定を維持。

### Agent Teams 実験フラグ

Agent Teams は実験的機能として `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` 環境変数で有効化される。
settings.json 経由でも設定可能:

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

Harness の `breezing` スキルは Agent Teams 機能を前提としているため、
セットアップ時にこの環境変数が設定されていることを確認する検証ステップを追加。

### Desktop Scheduled Tasks

Desktop アプリの Scheduled Tasks は `~/.claude/scheduled-tasks/<task-name>/SKILL.md` に保存される。
YAML frontmatter で `name` と `description` を定義し、本文にプロンプトを記述する。

スケジュール設定（頻度・時刻・フォルダ）は Desktop アプリの UI から管理。
`/harness-work` や `/harness-review` を定期実行する用途に活用可能。

### `/agents` コマンド

エージェントの対話的管理インターフェース。以下の操作が可能:
- 利用可能な全エージェントの一覧表示（built-in, user, project, plugin）
- ガイド付きまたは Claude 生成によるエージェント作成
- 既存エージェントの設定・ツールアクセス編集
- カスタムエージェントの削除

CLI からの非対話的な一覧表示: `claude agents`

### `--agents` CLI フラグ

セッション起動時に JSON でエージェント定義を渡す。ディスクに保存されない一時的な構成:

```bash
claude --agents '{
  "quick-reviewer": {
    "description": "Quick code review",
    "prompt": "Review for critical issues only",
    "tools": ["Read", "Grep", "Glob"],
    "model": "haiku"
  }
}'
```

CI/CD パイプラインでの一時的なエージェント注入に有用。

### `ExitWorktree` ツール (v2.1.72)

CC 2.1.72 で `ExitWorktree` ツールが追加された。`EnterWorktree` で作成された worktree セッションからプログラム的に離脱できる。
従来は worktree セッション終了時のプロンプトで手動選択するしかなかったが、エージェントが実装完了後に自動で worktree を離脱できるようになった。

Harness での活用:
- `breezing` の Worker が `isolation: worktree` で作業完了後、`ExitWorktree` で明示的に worktree を閉じる
- worktree クリーンアップの確実性が向上（変更がない場合は自動削除される既存動作と組み合わせ可能）

### Effort levels 簡素化 (v2.1.72)

CC 2.1.72 で永続する effort レベルが `low/medium/high` の3段階に簡素化された。表示シンボルが `○ ◐ ●` に統一。`/effort auto` でデフォルト（medium）にリセット可能。`max` はセッション専用オプションとして Opus 4.6 限定で存続（v2.1.75 model-config ドキュメントで確認）。

Harness への影響:
- `ultrathink` キーワードによる high effort 注入は引き続き有効（変更なし）
- harness-work のスコアリングロジックに変更は不要（ultrathink → high effort の対応が維持）
- `max` は永続設定に保存されないため、セッション単位でのみ有効。`/effort max` または `--effort max` で手動指定

### Agent tool `model` パラメータ復活 (v2.1.72)

CC 2.1.72 で Agent tool の `model` パラメータが復活した。per-invocation でモデルを指定してサブエージェントを起動できる。
エージェント定義の `model` フィールドとは別に、spawn 時に一時的なモデル指定が可能。

Harness での活用余地:
- 軽量タスク（ドキュメント更新、フォーマット修正等）には `model: "haiku"` で spawn してコスト削減
- セキュリティレビューやアーキテクチャ変更には `model: "opus"` で spawn して品質最大化
- 現状は Worker/Reviewer とも `model: sonnet` で固定。Lead がタスク特性に応じて動的にモデルを切り替える実装は Phase 2 以降で検討

### `/plan` description 引数 (v2.1.72)

CC 2.1.72 で `/plan` コマンドがオプションの description 引数を受け付けるようになった。
`/plan fix the auth bug` のように、説明付きで即座にプランモードに入れる。

Harness での活用:
- `harness-plan` スキルの `create` サブコマンドと補完的に使用可能
- ユーザーが簡易にプランモードに入りたい場合のショートカットとして案内

### 並列ツール呼び出し修正 (v2.1.72)

CC 2.1.72 で並列ツール呼び出し時の重要なバグが修正された。
以前は Read, WebFetch, Glob のいずれかが失敗すると、並列実行中の sibling 呼び出しもキャンセルされていた。
修正後は Bash エラーのみがカスケードし、他のツールの失敗は独立して処理される。

Harness への影響:
- `breezing` や `harness-work` でファイル読み込みと Web 検索を並列実行する際の安定性が向上
- 存在しないファイルの Read が他の正常な Read をキャンセルする問題が解消
- Worker エージェントの探索フェーズでの信頼性改善

### Worktree isolation 修正 (v2.1.72)

CC 2.1.72 で worktree isolation に関する2つのバグが修正された:

1. **Task resume の cwd 復元**: `resume` パラメータで再開したタスクが worktree の作業ディレクトリを正しく復元するようになった
2. **Background 通知の worktreePath**: バックグラウンドタスクの完了通知に `worktreePath` フィールドが含まれるようになった

Harness への影響:
- `breezing` の Worker が `isolation: worktree` で作業し、Lead が結果を回収する際の信頼性が向上
- `run_in_background: true` で spawn した Worker の完了通知から worktree パスを取得可能に

### `/clear` バックグラウンドエージェント保持 (v2.1.72)

CC 2.1.72 で `/clear` の動作が変更された。フォアグラウンドのタスクのみ停止し、バックグラウンドで実行中のエージェントや Bash タスクは影響を受けなくなった。

Harness への影響:
- `breezing` のチーム実行中にユーザーが `/clear` してもバックグラウンド Worker が存続
- Lead が `/clear` でコンテキストを整理しても、実行中のタスクが中断されないため安全性向上

### Hooks 修正群 (v2.1.72)

CC 2.1.72 で複数のフック関連バグが修正された:

1. **transcript_path**: `--resume` / `--fork` セッションでの `transcript_path` が正しく設定されるようになった
2. **PostToolUse ブロック理由の二重表示**: PostToolUse フックがブロックした際の理由メッセージが2回表示される問題が修正
3. **async hooks の stdin**: 非同期フックが stdin を正しく受信するようになった
4. **skill hooks 二重発火**: スキルフックが1イベントにつき2回発火する問題が修正

Harness への影響:
- `pre-tool.sh` / `post-tool.sh` ガードレールフックの発火が正確に1回になり、ログの信頼性が向上
- `session-memory` の transcript 参照が `--resume` セッションでも正常動作

### HTML コメント非表示 (v2.1.72)

CC 2.1.72 で CLAUDE.md ファイル内の HTML コメント（`<!-- ... -->`）が自動注入時に非表示になった。
Read ツールで直接ファイルを読んだ場合は引き続き可視。

Harness への影響:
- claude-mem が使用する `<!-- This section is auto-generated by claude-mem. -->` マーカーが自動注入時に非表示になる
- **実害なし**: マーカーは情報コメントであり、activity log テーブル本体はコメント外に存在するため表示に影響なし
- 重要な指示や設定を HTML コメント内に記述することは今後避けるべき

### Bash auto-approval 追加 (v2.1.72)

CC 2.1.72 で以下のコマンドが Bash auto-approval 許可リストに追加された:
`lsof`, `pgrep`, `tput`, `ss`, `fd`, `fdfind`

Harness への影響:
- Worker がプロセス確認（`pgrep`）やファイル検索（`fd`）を権限プロンプトなしで実行可能に
- guardrails の `pre-tool.sh` は引き続きこれらのコマンドを通過させる（ブロック対象外）

### プロンプトキャッシュ修正 (v2.1.72)

CC 2.1.72 で SDK の `query()` 呼び出し時のプロンプトキャッシュ無効化バグが修正された。
入力トークンコストが最大 12 倍削減される。

Harness への影響:
- `breezing` や `harness-work` で多数のサブエージェント spawn を行う際のコスト大幅削減
- 特に同一セッション内での反復的な API 呼び出しパターンで効果大

### Output Styles (v2.1.72+)

CC の Output Styles 機能により、システムプロンプト自体をカスタマイズできる。
CLAUDE.md（ユーザーメッセージとして追加）や Skills（特定タスク用）とは異なるレイヤー。

Harness では `.claude/output-styles/harness-ops.md` を提供:
- `keep-coding-instructions: true` — コーディング指示を維持しつつ運用フローを最適化
- 構造化された進捗報告フォーマット（実施/現在地/次アクション）
- Quality Gate の表形式出力
- Review 判定の構造化フォーマット
- エスカレーション（3回ルール）の標準出力形式

```bash
# 有効化
/output-style harness-ops
```

### `permissionMode` in agent frontmatter (v2.1.72+)

公式ドキュメントで `permissionMode` がエージェント frontmatter の正式フィールドとして文書化された。

Harness への反映:
- Worker/Reviewer/Scaffolder の3エージェント全てに `permissionMode: bypassPermissions` を追加
- spawn 時の `mode` 指定に依存しない宣言的権限管理を実現
- Auto Mode は rollout 候補として整理し、現行 shipped default は `bypassPermissions` のまま維持する

```yaml
# agents-v3/worker.md frontmatter
permissionMode: bypassPermissions  # 追加
```

### Agent Teams 公式ベストプラクティス (v2.1.72+)

Claude Code 公式に `agent-teams.md` が独立ドキュメントとして整備された。
Harness の `agents-v3/team-composition.md` に以下を反映:

1. **タスク粒度ガイドライン**: 5-6 tasks/teammate の推奨値
2. **`teammateMode` 設定**: `"auto"` / `"in-process"` / `"tmux"` の公式サポート
3. **Plan Approval パターン**: Worker に plan mode を要求する公式パターン
4. **Quality Gate Hooks**: `TeammateIdle`/`TaskCompleted` のexit 2 フィードバックパターン
5. **チームサイズ**: 3-5 teammates の推奨値（Harness の Worker 1-3 + Reviewer 1 と整合）

### Sandboxing (`/sandbox`)

Claude Code にネイティブ統合された OS レベルのサンドボックス機能。macOS は Seatbelt、Linux は bubblewrap を使用し、Bash コマンドのファイルシステム/ネットワークアクセスを制限する。

**2つのモード**:
- **Auto-allow mode**: サンドボックス内のコマンドは自動承認。制約外のアクセスは通常の権限フローへフォールバック
- **Regular permissions mode**: サンドボックス内でも全コマンドに承認が必要

**Harness での活用戦略**:
- `bypassPermissions` の **補完レイヤー** として位置づける（置換ではない）
- Worker エージェントの Bash コマンドに OS レベルの安全境界を追加
- `sandbox.filesystem.allowWrite` で Worker が書き込める範囲を明示制限
- `sandbox.network` で外部アクセスを信頼済みドメインに制限（エクスフィルトレーション防止）

**段階導入計画**:

| フェーズ | Worker 権限 | Sandbox |
|---------|-----------|---------|
| 現行 | `bypassPermissions` + hooks ガード | 未適用 |
| 検証フェーズ | `bypassPermissions` + hooks + sandbox auto-allow | Worker の Bash に適用 |
| 安定後 | sandbox auto-allow のみ（`bypassPermissions` 廃止検討） | 全 Bash に適用 |

```json
// settings.json (検証フェーズ用)
{
  "sandbox": {
    "enabled": true,
    "filesystem": {
      "allowWrite": ["~/.claude", "//tmp"]
    }
  }
}
```

> `@anthropic-ai/sandbox-runtime` が OSS として公開されており、MCP サーバーのサンドボックス化にも利用可能。

### `opusplan` モデルエイリアス

Plan mode では Opus、実行モードでは Sonnet に自動切替するハイブリッドエイリアス。

**Harness での活用**:
- Breezing の Lead セッションに最適: Plan フェーズ（タスク分解・アーキテクチャ決定）は Opus の推論力を活用し、Worker spawn 後の実行コーディネーションは Sonnet でコスト効率化
- `claude --model opusplan` または `/model opusplan` で有効化

**環境変数による制御**:
```bash
# opusplan の内部マッピングをカスタマイズ
ANTHROPIC_DEFAULT_OPUS_MODEL=claude-opus-4-6    # Plan 時
ANTHROPIC_DEFAULT_SONNET_MODEL=claude-sonnet-4-6  # 実行時
```

### `CLAUDE_CODE_SUBAGENT_MODEL` 環境変数

サブエージェント（Worker/Reviewer）のモデルを一括で指定する環境変数。

**Harness での活用**:
- 現状: Worker/Reviewer は `model: sonnet` をエージェント定義で固定
- 本環境変数を使うと、エージェント定義を変更せずにモデルを切り替え可能
- CI 環境でのコスト制御（`CLAUDE_CODE_SUBAGENT_MODEL=haiku` でテスト実行）に有用

```bash
# 全サブエージェントを haiku で実行（CI コスト削減）
export CLAUDE_CODE_SUBAGENT_MODEL=claude-haiku-4-5-20251001
```

### `availableModels` 設定

ユーザーが選択可能なモデルを制限する設定。managed/policy settings で設定すると、`/model`、`--model`、`ANTHROPIC_MODEL` のいずれでも制限が適用される。

**Harness での活用**:
- エンタープライズ環境でのモデルガバナンス: Worker/Reviewer が意図しないモデルを使用することを防止
- `availableModels` + `model` の組み合わせで全ユーザーのモデル体験を統制可能

```json
// managed settings
{
  "model": "sonnet",
  "availableModels": ["sonnet", "haiku", "opusplan"]
}
```

### Checkpointing (`/rewind`)

セッション中のファイル編集を自動追跡し、任意のポイントに巻き戻し可能にする機能。
各ユーザープロンプトでチェックポイントが自動作成される。

**操作方法**:
- `Esc + Esc` または `/rewind` でリワインドメニューを開く
- 選択肢: コード復元 / 会話復元 / 両方復元 / ここから要約

**Harness での活用**:
- `harness-work` のセルフレビューフェーズで問題発見時、実装前の状態に巻き戻し
- 「ここから要約」で冗長なデバッグセッションのコンテキスト窓を回収
- `/compact` との違い: チェックポイントは選択的に圧縮範囲を指定できる

**制限事項**:
- Bash コマンドによるファイル変更は追跡されない（`rm`, `mv`, `cp` 等）
- 外部の手動変更は追跡されない
- Git の代替ではなく、セッションレベルの「ローカル Undo」

### Code Review (managed service)

Anthropic インフラ上で動作するマルチエージェント PR レビューサービス。Teams/Enterprise 向け Research Preview。

**動作概要**:
1. PR 作成/更新時に自動起動
2. 複数の専門エージェントが並列で差分とコードベースを分析
3. 検証ステップで偽陽性をフィルタ
4. 重複排除・重要度ランク付け後にインラインコメントとして投稿

**重要度レベル**:
| マーカー | レベル | 意味 |
|---------|--------|------|
| 🔴 | Normal | マージ前に修正すべきバグ |
| 🟡 | Nit | 軽微な問題（ブロッキングではない） |
| 🟣 | Pre-existing | この PR 以前から存在するバグ |

**`REVIEW.md`**: リポジトリルートに配置するレビュー専用ガイダンスファイル。`CLAUDE.md` とは別に、レビュー時のみ適用されるルールを定義。

**Harness での活用**:
- `harness-review` スキルの Code Review 対応として `REVIEW.md` テンプレート生成を検討
- Harness の Worker セルフレビューと managed Code Review は補完的（ローカル + リモートの二重検査）
- 平均コスト $15-25/レビュー。`on-push` トリガーは push 回数分のコストが発生するため注意

### Status Line (`/statusline`)

Claude Code のターミナル下部に表示されるカスタマイズ可能な状態バー。シェルスクリプトに JSON セッションデータを渡し、出力テキストを表示。

**利用可能データ**:
- `model.id`, `model.display_name` — 現在のモデル
- `context_window.used_percentage` — コンテキスト使用率
- `cost.total_cost_usd` — セッションコスト
- `cost.total_duration_ms` — 経過時間
- `worktree.*` — ワークツリー情報
- `agent.name` — エージェント名
- `output_style.name` — 出力スタイル名

**Harness での活用**:
- `scripts/statusline-harness.sh` で Harness 専用ステータスライン提供
- モデル名・コンテキスト使用率・セッションコスト・git ブランチ・Harness バージョンを常時表示
- ANSI カラーでコンテキスト使用率のしきい値表示（70% 黄色、90% 赤）

### 1M Context Window (`sonnet[1m]`)

Opus 4.6 と Sonnet 4.6 で利用可能な 100 万トークンコンテキスト窓。200K トークンを超えると long-context pricing が適用される。

**Harness での活用**:
- `harness-review` の大規模コードベース分析に有用
- `breezing` で多数のファイルを同時に扱うセッション
- `/model sonnet[1m]` で有効化。`CLAUDE_CODE_DISABLE_1M_CONTEXT=1` で無効化可能

### Per-model Prompt Caching Control

モデル別にプロンプトキャッシュを制御する環境変数群。

| 環境変数 | 用途 |
|---------|------|
| `DISABLE_PROMPT_CACHING` | 全モデルのキャッシュ無効化 |
| `DISABLE_PROMPT_CACHING_HAIKU` | Haiku のみ無効化 |
| `DISABLE_PROMPT_CACHING_SONNET` | Sonnet のみ無効化 |
| `DISABLE_PROMPT_CACHING_OPUS` | Opus のみ無効化 |

**Harness での活用**:
- デバッグ時に特定モデルのキャッシュを無効化して挙動を確認
- クラウドプロバイダ（Bedrock/Vertex）でキャッシュ実装が異なる場合の選択的制御

### `CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING`

Opus 4.6 / Sonnet 4.6 の Adaptive Reasoning を無効化し、`MAX_THINKING_TOKENS` で制御される固定 thinking budget に復帰する環境変数。

**Harness での活用**:
- トークンコストの予測可能性が必要な CI 環境で有用
- `harness-work` の effort スコアリングと排他的ではない（両方使用可能だが、通常は adaptive thinking を有効にしたまま ultrathink で制御する方が効果的）

### Chrome Integration (`--chrome`)

Claude Code の Chrome 拡張機能と連携し、ブラウザ自動化をターミナルから実行する beta 機能。
`--chrome` フラグでセッション起動、または `/chrome` でセッション内から有効化。

**主要機能**:
- ライブデバッグ: コンソールエラーを読み取り、原因コードを即座に修正
- UI テスト: フォーム検証、ビジュアルリグレッション確認、ユーザーフロー検証
- データ抽出: Web ページから構造化データを抽出しローカル保存
- GIF 記録: ブラウザ操作シーケンスを GIF として記録

**Harness での活用**:
- `harness-work` での UI コンポーネント実装後の自動検証
- `harness-review` での Web アプリケーションのビジュアルレビュー
- `/chrome` 有効化で Worker がブラウザテストを実行可能に

**制約**: Google Chrome / Microsoft Edge のみ。Brave, Arc 等は未対応。WSL 非対応。

### LSP サーバー統合 (`.lsp.json`)

Language Server Protocol サーバーを Plugin 経由で統合し、リアルタイムコード診断を提供。

**利用可能な LSP プラグイン**:
| プラグイン | Language Server | インストール |
|-----------|----------------|------------|
| `pyright-lsp` | Pyright (Python) | `pip install pyright` |
| `typescript-lsp` | TypeScript Language Server | `npm install -g typescript-language-server typescript` |
| `rust-lsp` | rust-analyzer | rust-analyzer 公式ガイド参照 |

**提供される機能**:
- 即座の診断: 編集後すぐにエラー/警告を表示
- コードナビゲーション: 定義ジャンプ、参照検索、ホバー情報
- 型情報: シンボルの型とドキュメント表示

**設定例** (`.lsp.json`):
```json
{
  "typescript": {
    "command": "typescript-language-server",
    "args": ["--stdio"],
    "extensionToLanguage": {
      ".ts": "typescript",
      ".tsx": "typescriptreact"
    }
  }
}
```

### `SubagentStart`/`SubagentStop` matcher

settings.json レベルでサブエージェントのライフサイクルを agent type 別に監視するフック。
公式ドキュメントで matcher にエージェント名を指定するパターンが文書化された。

**Harness の実装**:
- `SubagentStart`: Worker/Reviewer/Scaffolder/Video Generator の起動を個別にトラッキング
- `SubagentStop`: 各エージェントの完了を個別に記録
- 既存の `subagent-tracker` Node.js スクリプトに matcher を追加

```json
"SubagentStart": [
  { "matcher": "worker", "hooks": [{ "type": "command", "command": "...subagent-tracker start" }] },
  { "matcher": "reviewer", "hooks": [{ "type": "command", "command": "...subagent-tracker start" }] }
]
```

### Agent Teams: Task Dependencies

Agent Teams のタスクに依存関係を設定可能。依存タスク完了で blocked タスクが自動 unblock。

**動作**:
- タスクは `pending`, `in_progress`, `completed` の3状態
- 未解決の依存がある pending タスクは claimed 不可
- 依存完了時に自動 unblock（手動介入不要）
- ファイルロックで複数 teammate の同時 claim を防止

**Harness での活用**:
- Breezing の Lead がタスク分解時に依存関係を明示指定
- 例: 「API エンドポイント実装」→「テスト作成」→「ドキュメント更新」の順序保証

### `--teammate-mode` CLI フラグ

セッション単位で Agent Teams の表示モードを指定するフラグ。

```bash
claude --teammate-mode in-process  # 全 teammate を同一ターミナル
claude --teammate-mode tmux        # 各 teammate に個別ペイン
```

settings.json の `teammateMode` 設定を上書き。VS Code 統合ターミナルでは `in-process` が推奨。

### `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS`

`=1` で全バックグラウンドタスク機能を無効化する環境変数。

**Harness での活用**:
- セキュリティポリシーでバックグラウンド実行を制限する環境向け
- Breezing のバックグラウンド Worker spawn も無効化されるため、使用時は要注意

### `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE`

サブエージェントの auto-compaction しきい値を調整する環境変数（デフォルト 95%）。

**Harness での活用**:
- `50` に設定で早期圧縮を有効化。長時間 Worker の安定性向上
- Breezing の Worker が大量のファイルを読み込む場合にコンテキスト溢れを防止

### `cleanupPeriodDays` 設定

サブエージェント transcript の自動クリーンアップ期間を制御する設定（デフォルト 30 日）。
transcript は `~/.claude/projects/{project}/{sessionId}/subagents/agent-{agentId}.jsonl` に保存。

### `/btw` サイドクエスチョン

現在のコンテキストを保持したまま短い質問を行うコマンド。
回答後にメインの会話履歴に残らないため、コンテキスト窓を消費しない。

**サブエージェントとの使い分け**:
- `/btw`: 現在のコンテキストで即答可能な質問（ツールアクセスなし）
- サブエージェント: 独立した調査・実装タスク（ツールアクセスあり）

### Plugin CLI コマンド群

プラグインの非対話的管理コマンド。スクリプトによる自動化に対応。

```bash
claude plugin install <plugin> [--scope user|project|local]
claude plugin uninstall <plugin> [--scope user|project|local]
claude plugin enable <plugin> [--scope user|project|local]
claude plugin disable <plugin> [--scope user|project|local]
claude plugin update <plugin> [--scope user|project|local|managed]
```

### Remote Control 強化

`/remote-control` (`/rc`) でセッション内から Remote Control を有効化可能に。

**新機能**:
- `--name "My Project"`: セッション名の指定
- `--sandbox` / `--no-sandbox`: サンドボックスの有効化/無効化
- `--verbose`: 詳細ログ表示
- `/mobile`: QR コード表示で iOS/Android アプリに素早く接続
- 自動再接続: ネットワーク断からの自動復帰（10 分以内）
- `/config` → "Enable Remote Control for all sessions" で常時有効化

### `skills` フィールド in agent frontmatter

サブエージェントの frontmatter に `skills` フィールドを追加し、起動時にスキルの全コンテンツをプリロード。
親会話のスキルは継承されないため、明示的にリストする必要がある。

**Harness の実装状況**:
- Worker: `skills: [harness-work, harness-review]` — 実装とセルフレビューのスキルをプリロード
- Reviewer: `skills: [harness-review]` — レビュースキルをプリロード
- Scaffolder: `skills: [harness-setup, harness-plan]` — セットアップと計画スキルをプリロード

> `skills` in skill (`context: fork`) の逆パターン。skill が agent を制御するのではなく、agent が skill を読み込む。

### `modelOverrides` 設定 (v2.1.73)

CC 2.1.73 で追加された設定。モデルピッカー（`/model` メニュー）のエントリを、カスタムプロバイダのモデル ID にマッピングできる。
Bedrock ARN や Vertex AI のモデル ID など、プロバイダ固有の識別子を指定可能。

**Harness での活用**:
- エンタープライズ環境で Bedrock/Vertex 経由の Anthropic モデルを使用する場合、`modelOverrides` でモデルピッカーの表示名と実際のプロバイダモデル ID を対応付け
- Worker/Reviewer の `model: sonnet` がプロバイダ固有の ARN に自動解決される
- `availableModels` と組み合わせて、チーム全体のモデル体験を統制可能

```json
// settings.json
{
  "modelOverrides": {
    "sonnet": "arn:aws:bedrock:us-east-1::foundation-model/anthropic.claude-sonnet-4-6-20250514-v1:0",
    "opus": "arn:aws:bedrock:us-east-1::foundation-model/anthropic.claude-opus-4-6-20250610-v1:0"
  }
}
```

### `/output-style` 非推奨化 (v2.1.73)

CC 2.1.73 で `/output-style` コマンドが非推奨となり、出力スタイルの選択は `/config` メニューに統合された。
既存の `/output-style harness-ops` 等は引き続き動作するが、公式には `/config` 経由の選択が推奨される。

**Harness への影響**:
- ドキュメント上の `/output-style harness-ops` への言及を `/config` 経由に更新推奨
- `.claude/output-styles/harness-ops.md` 自体は引き続き有効（設定ファイルの配置場所に変更なし）
- スキル内で `/output-style` を実行している箇所があれば `/config` に切り替え検討

### Bedrock/Vertex Opus 4.6 デフォルト化 (v2.1.73)

CC 2.1.73 でクラウドプロバイダ（Amazon Bedrock / Google Vertex AI）上のデフォルト Opus モデルが 4.1 から 4.6 に更新された。
first-party API では v2.1.68 時点で Opus 4.6 がデフォルトだったが、クラウドプロバイダ経由でも統一された。

**Harness への影響**:
- Bedrock/Vertex 環境でも Lead（Opus 使用時）が medium effort デフォルトで動作
- `opusplan` エイリアスが Bedrock/Vertex 環境でも Opus 4.6 を参照
- `ANTHROPIC_DEFAULT_OPUS_MODEL` 環境変数による上書きは引き続き有効

### `autoMemoryDirectory` 設定 (v2.1.74)

CC 2.1.74 で追加された設定。自動メモリ（auto-memory）の保存ディレクトリをカスタマイズ可能。
デフォルトの `~/.claude/` 配下からプロジェクト固有のパスに変更できる。

**Harness での活用**:
- 複数プロジェクトで Harness を使用する場合、プロジェクトごとに自動メモリを分離
- CI 環境で一時ディレクトリにメモリを保存し、セッション終了時にクリーンアップ
- Agent Memory（`memory: project`）とは異なるレイヤー（自動メモリはユーザーレベルの学習）

```json
// settings.json (プロジェクトレベル)
{
  "autoMemoryDirectory": ".claude/auto-memory"
}
```

### `CLAUDE_CODE_SESSIONEND_HOOKS_TIMEOUT_MS` (v2.1.74)

CC 2.1.74 で追加された環境変数。`SessionEnd` フックのタイムアウトをミリ秒単位で指定可能。
従来は固定 1.5 秒で kill されていたため、重いクリーンアップ処理が完了前に中断される問題があった。

**Harness での活用**:
- `SessionEnd` フックで `harness-mem` のセッション記録や JSONL ローテーションを実行する場合、十分なタイムアウトを確保
- 推奨値: `5000`（5秒）。複雑なクリーンアップが必要な場合は `10000`（10秒）まで

```bash
export CLAUDE_CODE_SESSIONEND_HOOKS_TIMEOUT_MS=5000
```

### Full model ID 修正 (v2.1.74)

CC 2.1.74 で `claude-opus-4-6`、`claude-sonnet-4-6` 等の完全なモデル ID（ハイフン区切り形式）がエージェント frontmatter および JSON config で正しく認識されるようになった。
従来はエイリアス（`opus`, `sonnet`）のみが安定して動作していた。

**Harness への影響**:
- エージェント定義の `model` フィールドに完全モデル ID を指定可能に（例: `model: claude-sonnet-4-6`）
- `--agents` CLI フラグの JSON 内でも完全モデル ID が使用可能
- 現状 Harness はエイリアス（`sonnet`, `opus`）を使用しており即時影響なし。Bedrock/Vertex 環境でフル ID 指定が必要な場合に有用

```yaml
# agents-v3/worker.md frontmatter（完全モデル ID 使用例）
model: claude-sonnet-4-6
```

### Streaming API メモリリーク修正 (v2.1.74)

CC 2.1.74 でストリーミング API レスポンスバッファの無制限 RSS（Resident Set Size）増大が修正された。
長時間のストリーミングセッションで Node.js プロセスのメモリ使用量が際限なく増加する問題が解消。

**Harness への影響**:
- `breezing` の長時間チームセッションでの安定性が向上
- `harness-work` で大量のファイル読み書きを含む長時間 Worker セッションのメモリ消費が安定化
- v2.1.50〜v2.1.63 のメモリリーク修正シリーズ（LSP 診断、ツール出力、ファイル履歴等）に続く追加修正
- Harness 側の JSONL ローテーション対策（独自のメモリ管理）と組み合わせて、二重の安定性確保

### `--remote` / Cloud Sessions

CC の `--remote` フラグでターミナルからクラウドセッションを起動できる。タスクは Anthropic 管理の隔離 VM 上で実行され、完了後に PR 作成が可能。

**Harness での活用**:
- `breezing` の大規模タスクをクラウドに委任し、ローカルリソースを節約
- `--remote` で複数タスクを並列起動（各タスクが独立したクラウドセッション）
- `/teleport` でクラウドの成果物をローカルに取り込み、後続の `/harness-review` に接続

```bash
# クラウドでタスク実行
claude --remote "Fix the authentication bug in src/auth/login.ts"

# 完了後にローカルに取り込み
/teleport
```

### `/teleport` (`/tp`)

クラウドセッションをローカルターミナルに取り込むコマンド。`/teleport` または `/tp` で対話的にセッションを選択、`claude --teleport <session-id>` で直接指定も可能。

**前提条件**:
- ローカルの git working directory がクリーンであること
- 同一リポジトリから実行すること
- 同一 Claude.ai アカウントで認証されていること

### `CLAUDE_CODE_REMOTE` 環境変数

クラウドセッション内では `CLAUDE_CODE_REMOTE=true` が設定される。Harness の `session-env-setup.sh` はこの値を `HARNESS_IS_REMOTE` として永続化し、他のフックハンドラがローカル専用処理をスキップする判定に使用可能。

```bash
# フックスクリプト内でのクラウド検出例
if [ "$HARNESS_IS_REMOTE" = "true" ]; then
  # クラウド環境ではローカル専用処理をスキップ
  exit 0
fi
```

### `CLAUDE_ENV_FILE` SessionStart 永続化

CC の `SessionStart` フックは `CLAUDE_ENV_FILE` 環境変数が指すファイルに `KEY=VALUE` を書き込むことで、後続の Bash コマンドにも環境変数を永続化できる。

Harness の `session-env-setup.sh` はこの機構を活用し、`HARNESS_VERSION`、`HARNESS_AGENT_TYPE`、`HARNESS_IS_REMOTE` 等をセッション全体で利用可能にしている。

### Slack Integration (`@Claude`)

Slack チャネルで `@Claude` にコーディングタスクをメンションすると、自動的にクラウドセッションが作成される。GitHub リポジトリとの連携が前提。

**Harness との関係**:
- Harness の HTTP hooks（`type: "http"`）を Slack Webhook URL に設定することで、タスク完了時の Slack 通知が可能
- クラウドセッション内でも `.claude/settings.json` のフックが動作するため、Harness のガードレールは Slack 経由のタスクにも適用される

### Server-managed settings (public beta)

Claude.ai の管理画面からチーム全体の Claude Code 設定をサーバー配信する機能。Teams/Enterprise 向け。

**Harness での活用**:
- チーム全体の `permissions.deny` ルールを一括管理
- Harness のフック設定をサーバー経由で配信（ただしフック設定はセキュリティ確認ダイアログが表示される）
- `availableModels` + `model` の組み合わせでチームのモデル体験を統制

### Microsoft Foundry

Azure ベースの新クラウドプロバイダ。Bedrock / Vertex に続く第3のサードパーティプロバイダとして追加。
`modelOverrides` 設定で Foundry のモデル ID にマッピング可能。

### `PreCompact` hook

コンテキスト圧縮が実行される直前に発火するフックイベント。Harness では以下の2層で実装済み:

1. **`pre-compact-save.js`**: セッション状態（進捗、メトリクス）を永続化
2. **agent hook**: `cc:WIP` タスクが残っていないかチェックし、警告メッセージを注入

```json
"PreCompact": [
  { "hooks": [
    { "type": "command", "command": "...pre-compact-save.js" },
    { "type": "agent", "prompt": "Check Plans.md for WIP tasks...", "model": "haiku" }
  ]}
]
```

### `Notification` hook event

Claude Code が通知を発行する際に発火するフックイベント。プラグインリファレンスに記載。
外部監視ツールやダッシュボードへの通知転送に活用可能。

### `--plugin-dir` 仕様変更 (v2.1.76, breaking)

**変更内容**: `--plugin-dir` が1つのパスのみを受け付けるように変更。複数ディレクトリは繰り返し指定。

```bash
# 旧（非対応に）
claude --plugin-dir path1,path2

# 新
claude --plugin-dir path1 --plugin-dir path2
```

**Harness への影響**: Harness プラグインのみを使用する一般的な構成では影響なし。
複数プラグインを同時使用する場合のみ構文変更が必要。

---

## Claude Code 2.1.76 新機能

### MCP Elicitation サポート

**動作概要**: MCP サーバーがタスク実行中にユーザーへ構造化された入力を要求できるプロトコル。フォームフィールドまたはブラウザ URL を通じてインタラクティブなダイアログを表示する。

**Harness での活用**:
- Breezing のバックグラウンド Worker/Reviewer は UI 対話不能なため、`Elicitation` フックで自動スキップを実装
- 通常セッションではそのまま通過（ユーザーが対話で応答）
- `elicitation-handler.sh` がイベントをログ記録

**制約事項**:
- バックグラウンドエージェントでは elicitation に応答不能（フックによる自動処理が必須）
- MCP サーバー側が elicitation をサポートしている必要がある

### `Elicitation`/`ElicitationResult` フック

**動作概要**: MCP Elicitation の前後でインターセプト可能な2つの新フックイベント。`Elicitation` はレスポンスが MCP サーバーに返される前に、`ElicitationResult` は返された後に発火する。

**Harness での活用**:
- `Elicitation`: Breezing セッション中の自動スキップ判定 + ログ記録
- `ElicitationResult`: 結果のログ記録（`.claude/state/elicitation-events.jsonl`）
- hooks.json に両イベントのハンドラを登録

**制約事項**:
- `Elicitation` フックでブロック（deny）するとMCPサーバーへの入力が届かない
- 推奨 timeout: Elicitation 10s / ElicitationResult 5s

### `PostCompact` フック

**動作概要**: コンテキストコンパクション完了後に発火する新フックイベント。`PreCompact` フック（既存）と対になる。

**Harness での活用**:
- コンパクション後のコンテキスト再注入（WIP タスク状態の復元）
- `.claude/state/compaction-events.jsonl` にイベント記録
- 長時間セッションでの状態継続性向上
- PreCompact（状態保存）→ PostCompact（状態復元）の対称構造

**制約事項**:
- 推奨 timeout: 15s
- コンパクション失敗時（circuit breaker 発動時）は PostCompact が発火しない可能性あり

### `-n`/`--name` CLI フラグ

**動作概要**: セッション起動時に表示名を設定する CLI フラグ。`claude -n "auth-refactor"` のように使用し、セッション一覧での識別に活用する。

**Harness での活用**:
- Breezing セッションに `breezing-{timestamp}` 形式の名前を自動設定
- セッション一覧でのフィルタリング・追跡に活用
- ログ分析時のセッション特定が容易に

**コード例**:
```bash
claude -n "breezing-$(date +%Y%m%d-%H%M%S)"
```

### `worktree.sparsePaths` 設定

**動作概要**: 大規模モノレポで `claude --worktree` 使用時に、git sparse-checkout を通じて必要なディレクトリのみをチェックアウトする設定。ワークツリー作成のパフォーマンスを大幅に改善する。

**Harness での活用**:
- Breezing の並列 Worker 起動時間を短縮（大規模リポジトリ）
- `.claude/settings.json` で設定:
```json
{
  "worktree": {
    "sparsePaths": ["src/", "tests/", "package.json"]
  }
}
```

**制約事項**:
- sparse-checkout されていないパスのファイルは Worker からアクセス不可
- 依存関係のあるディレクトリはすべて sparsePaths に含める必要がある

### `/effort` スラッシュコマンド

**動作概要**: セッション中に effort レベル（low/medium/high）を切り替えるスラッシュコマンド。`/effort auto` でデフォルトにリセット。

**Harness での活用**:
- harness-work の多要素スコアリングと連携し、タスク複雑度に応じた effort 制御が可能
- 複雑なタスクでは `/effort high`（ultrathink 有効化）を手動で設定可能
- 簡易タスクでは `/effort low` でトークン消費を抑制

### `--worktree` 起動高速化

**動作概要**: git refs の直接読み取りと、リモートブランチが利用可能な場合の冗長な `git fetch` スキップにより、`--worktree` の起動時間を短縮。

**Harness での活用**:
- Breezing の Worker 起動オーバーヘッドが自動的に削減
- 特に多数の Worker を同時起動する場合に恩恵が大きい

### バックグラウンドエージェント部分結果保持

**動作概要**: バックグラウンドエージェントが kill された場合にも、部分的な結果が会話コンテキストに保存される。

**Harness での活用**:
- Breezing の Worker がタイムアウトや手動停止で中断された場合、作業の一部が Lead に伝達される
- Worker の途中成果物を活用した再割り当てが可能に
- 「やり直し」の無駄が削減

### stale worktree 自動クリーンアップ

**動作概要**: 中断された並列実行で残った stale ワークツリーが自動的にクリーンアップされる。

**Harness での活用**:
- `worktree-remove.sh` による手動クリーンアップの補完
- Breezing セッションのクラッシュ後も自動回復
- ディスク容量の無駄な消費を防止

### 自動コンパクション circuit breaker

**動作概要**: 自動コンパクションが連続して失敗した場合、3回で停止するサーキットブレーカーが導入された。無限リトライによるトークン浪費を防止する。

**Harness での活用**:
- Harness の「3回ルール」（CI失敗時の3回制限）と一致する設計思想
- 長時間 Breezing セッションでの予期せぬコスト増加を防止
- circuit breaker 発動時は PostToolUseFailure フックと連携してエスカレーション

### Deferred Tools スキーマ修正

**動作概要**: `ToolSearch` で読み込んだツールがコンパクション後に入力スキーマを失い、配列・数値パラメータが型エラーで拒否される問題を修正。

**Harness での活用**:
- 長時間セッションでの ToolSearch 経由ツールの安定性が向上
- Breezing のコンパクション後もMCPツールが正常に動作

## Claude Code 2.1.75 新機能

### 1M Context Window (`opus[1m]`)

**動作概要**: Opus 4.6 で 1M トークンコンテキスト窓が利用可能に。Max / Team / Enterprise プランでは Opus が自動的に 1M コンテキストに昇格（追加設定不要）。Pro プランでは extra usage 経由でアクセス。`/model opus[1m]` で明示的に有効化も可能。

**Harness での活用**:
- Breezing の Lead セッションに `opus[1m]` を使用し、大規模コードベースの Plan フェーズで包括的な分析を実行
- `harness-review` で 1M コンテキストの Opus を使用し、多数のファイルにまたがるレビューを一度に完了
- `opusplan` との使い分け: `opusplan` は Plan/Execute の自動切替、`opus[1m]` は Plan フェーズに Opus を維持しつつ 1M コンテキスト

**コード例**:
```bash
# 明示的に 1M Opus を指定
claude --model opus[1m]

# セッション内で切替
/model opus[1m]

# 環境変数でデフォルト設定（1M 付き）
export ANTHROPIC_DEFAULT_OPUS_MODEL='claude-opus-4-6[1m]'
```

**プラン別の利用可否**:
| プラン | Opus 1M | Sonnet 1M |
|--------|---------|-----------|
| Max / Team / Enterprise | サブスクリプション含む | Extra usage |
| Pro | Extra usage | Extra usage |
| API / Pay-as-you-go | フルアクセス | フルアクセス |

### Memory file timestamps

**動作概要**: CC 2.1.75 でメモリファイルに最終更新タイムスタンプが自動付与されるようになった。Claude がメモリを読む際に「この情報はいつ記録されたか」を判断でき、古い記憶と新しい記憶を区別できる。

**Harness での活用**:
- `session-memory` スキルがメモリの鮮度を判断し、古い情報を優先的にアーカイブ
- Agent Memory（`.claude/agent-memory/`）の MEMORY.md でも鮮度判断が向上
- 「3ヶ月前に記録されたビルド手順」と「昨日記録されたビルド手順」を自動的に後者優先

### Async hook suppression

**動作概要**: CC 2.1.75 で非同期フック（`async: true`）の完了メッセージがデフォルトで非表示になった。`--verbose` モードまたはトランスクリプトモードで表示可能。

**Harness での活用**:
- Breezing のチーム実行中に非同期フック（OTel メトリクス送信、Slack 通知等）の完了メッセージが Lead のコンテキストを汚さなくなった
- hooks.json の `"async": true` 設定のフックが、ノイズなしにバックグラウンドで動作
- デバッグ時は `--verbose` でフック完了を確認可能

### `/effort max` session-only (Opus 4.6)

**動作概要**: `low/medium/high` の3段階は永続設定だが、`max` は Opus 4.6 限定のセッション専用オプションとして存続している。`max` はトークン支出に制約なく最深推論を行うため、レスポンスは遅くコストも高い。セッション終了で自動リセットされる。

**Harness での活用**:
- 複雑なアーキテクチャ決定やセキュリティレビューで `/effort max` を手動指定
- `harness-plan` で Plan フェーズの初期分析に一時的に `max` を適用し、タスク分解の精度を最大化
- `harness-work` の ultrathink スコアリング（閾値 3 以上で high 注入）とは別レイヤー: ultrathink は自動、`/effort max` は手動
- 永続しないためセッション終了後にコスト影響なし

**注意**: `max` は永続設定 (`settings.json`, `effortLevel`) には保存されない。`/effort max` または `--effort max` でセッション単位のみ有効。

### Token estimation fix

**動作概要**: CC 2.1.75 で thinking ブロックと `tool_use` ブロックのトークン数が過大に推定されていた問題が修正された。この過大推定により、実際にはコンテキスト窓に余裕があるにもかかわらず早期にコンパクションが発火していた。

**Harness への影響**:
- 長時間セッション（特に Breezing の Lead）でのコンパクション頻度が低下
- Worker エージェントがより多くのファイルを読み込んだ後もコンテキスト窓内で作業を継続可能
- `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` 設定との組み合わせで、より精密なコンパクション制御が可能に

## 関連ドキュメント

- [CLAUDE.md](../CLAUDE.md) - 開発ガイド（Feature Table の要約版）
- [CLAUDE-skill-catalog.md](./CLAUDE-skill-catalog.md) - スキルカタログ
- [CLAUDE-commands.md](./CLAUDE-commands.md) - コマンドリファレンス
- [ARCHITECTURE.md](./ARCHITECTURE.md) - アーキテクチャ概要
