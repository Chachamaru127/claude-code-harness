# Claude Code 2.1.72+ 新機能活用ガイド（完全版）

> **概要**: Harness が活用する Claude Code 2.1.72+ の全機能一覧。
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
| **Auto Mode (Research Preview, staged rollout)** | breezing, work | `bypassPermissions` の安全な代替。`--auto-mode` フラグで有効化。RP 開始後に段階検証を予定 (2026-03-12〜) |
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
| **Effort levels 簡素化 (v2.1.72)** | harness-work | `max` 廃止、`low/medium/high` の3段階 + `○ ◐ ●` シンボル。`/effort auto` でデフォルトリセット |
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

### Auto Mode 段階移行計画

Auto Mode は CC Research Preview として 2026-03-12 に開始。
Harness は 3 フェーズで段階的に移行する:

| フェーズ | 期間 | デフォルト | `--auto-mode` |
|---------|------|-----------|---------------|
| Phase 0 | 〜2026-03-12 | `bypassPermissions` | フラグ無視 |
| **Phase 0 (pre-RP)** | **RP 開始前** | `bypassPermissions` | 未対応（フラグ無視） |
| **Phase 1 (RP 開始後)** | **2026-03-12〜** | `bypassPermissions` | Auto Mode を検証 |
| Phase 2 (検証完了後) | TBD | TBD | 採用可否を再判定 |

Phase 1 検証項目:
1. PreToolUse / PostToolUse hooks が Auto Mode でも発火するか
2. Teammate のバックグラウンド spawn で権限プロンプトがブロックされないか
3. トークンコスト増の実測

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

CC 2.1.72 で effort レベルが `low/medium/high` の3段階に簡素化された。`max` レベルが廃止され、表示シンボルが `○ ◐ ●` に統一された。`/effort auto` でデフォルト（medium）にリセット可能。

Harness への影響:
- `ultrathink` キーワードによる high effort 注入は引き続き有効（変更なし）
- harness-work のスコアリングロジックに変更は不要（ultrathink → high effort の対応が維持）
- ドキュメント上の `max` への言及を `high` に統一

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
- Auto Mode 採用可否は teammate 実行経路側で再評価する。frontmatter の `permissionMode` は文書化済み値のみを使う

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

## 関連ドキュメント

- [CLAUDE.md](../CLAUDE.md) - 開発ガイド（Feature Table の要約版）
- [CLAUDE-skill-catalog.md](./CLAUDE-skill-catalog.md) - スキルカタログ
- [CLAUDE-commands.md](./CLAUDE-commands.md) - コマンドリファレンス
- [ARCHITECTURE.md](./ARCHITECTURE.md) - アーキテクチャ概要
