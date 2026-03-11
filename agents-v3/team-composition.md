# Team Composition (v3)

Harness v3 の3エージェント構成。
11エージェント → 3エージェントに統合。

## Team 構成図

```
Lead (Execute スキルの --breezing モード) ─ 指揮のみ
  │
  ├── Worker (claude-code-harness:worker)
  │     実装 + セルフレビュー + ビルド検証 + コミット
  │     ※ --codex 時は codex exec を内部で呼び出す
  │
  ├── [Worker #2] (claude-code-harness:worker)
  │     独立タスクを並列実行
  │
  └── Reviewer (claude-code-harness:reviewer)
        Security / Performance / Quality / Accessibility
        REQUEST_CHANGES → Lead が修正タスクを作成
```

## 旧エージェント → v3 マッピング

| 旧エージェント | v3 エージェント |
|--------------|--------------|
| task-worker | worker |
| codex-implementer | worker（--codex 内包） |
| error-recovery | worker（エラー復旧内包） |
| code-reviewer | reviewer |
| plan-critic | reviewer（plan type） |
| plan-analyst | reviewer（scope type） |
| project-analyzer | scaffolder |
| project-scaffolder | scaffolder |
| project-state-updater | scaffolder |
| ci-cd-fixer | worker（CI 復旧内包） |
| video-scene-generator | extensions/generate-video（別途） |

## ロール定義

### Lead（Execute スキルの内部）

| 項目 | 設定 |
|------|------|
| **Phase A** | 準備・タスク分解 |
| **Phase B** | delegate mode — TaskCreate/TaskUpdate/SendMessage のみ |
| **Phase C** | 完了処理・コミット・Plans.md 更新 |
| **禁止** | Phase B 中の直接 Write/Edit/Bash |

### Worker

| 項目 | 設定 |
|------|------|
| **subagent_type** | `claude-code-harness:worker` |
| **モデル** | sonnet |
| **数** | 1〜3（独立タスク数に基づく） |
| **ツール** | Read, Write, Edit, Bash, Grep, Glob |
| **禁止** | Task（再帰防止） |
| **責務** | 実装 → セルフレビュー → CI検証 → コミット |
| **エラー復旧** | 最大3回。3回失敗でエスカレーション |

### Reviewer

| 項目 | 設定 |
|------|------|
| **subagent_type** | `claude-code-harness:reviewer` |
| **モデル** | sonnet |
| **数** | 1 |
| **ツール** | Read, Grep, Glob（Read-only） |
| **禁止** | Write, Edit, Bash, Task |
| **責務** | コード/プラン/スコープのレビュー |
| **判定** | APPROVE / REQUEST_CHANGES |

### Scaffolder（セットアップ時のみ）

| 項目 | 設定 |
|------|------|
| **subagent_type** | `claude-code-harness:scaffolder` |
| **モデル** | sonnet |
| **数** | 1 |
| **ツール** | Read, Write, Edit, Bash, Grep, Glob |
| **責務** | プロジェクト分析・足場構築・状態更新 |

## 実行フロー

```
Phase A: Lead がタスクを分解
    ↓
Phase B: Worker(s) を並列 spawn
    Worker: 実装 → セルフレビュー → コミット
    ↓（全 Worker 完了後）
Phase B: Reviewer を spawn
    Reviewer: コードレビュー → APPROVE / REQUEST_CHANGES
    ↓（APPROVE の場合）
Phase C: Lead がクリーンアップ・Plans.md 更新
```

**REQUEST_CHANGES の場合**:
```
Reviewer → REQUEST_CHANGES
    ↓
Lead: 修正タスクを TaskCreate
    ↓
Worker: 修正実装 → コミット
    ↓
Reviewer: 再レビュー
```

### Nested Teammate Policy（v2.1.69）

CC 2.1.69 で teammates の多重 spawn（nested teammates）はプラットフォーム側でブロックされる。
Harness 側は冗長な防止文言を最小化し、以下の運用に統一する:

1. Lead のみが teammate を spawn する
2. Worker/Reviewer プロンプトでは「実装/レビュー責務」に集中させる
3. nested 防止は hooks 追加ではなく公式ガードに委ねる（運用を簡素化）

## 権限設定（bypassPermissions / permissionMode）

Teammate は UI なしでバックグラウンド実行されるため、権限モードの明示設定が必要。

### v2.1.72+ 推奨: `permissionMode` in frontmatter

公式ドキュメントで `permissionMode` がエージェント frontmatter の正式フィールドとして文書化された。
spawn 時の `mode` 指定よりも **定義レベルでの宣言が推奨**:

```yaml
# agents-v3/worker.md frontmatter
permissionMode: bypassPermissions
```

**利点**: spawn prompt に依存せず、エージェント定義自体に権限モードを組み込む。
Lead の spawn コードが `mode` を渡し忘れても安全。

### 安全層（多層防御）

1. `permissionMode: bypassPermissions` — frontmatter で宣言
2. `disallowedTools` でツールを制限
3. PreToolUse hooks がガードレールを維持
4. Lead が常に監視
5. `Agent(worker, reviewer)` で spawn 可能なエージェント種別を制限

### Auto Mode（Research Preview, staged rollout）

`bypassPermissions` の安全な代替として Anthropic が提供する新しい権限運用。
Claude が権限判断を自動で行い、プロンプトインジェクション対策も内蔵する。

| 観点 | bypassPermissions | Auto Mode |
|------|-------------------|-----------|
| 権限判断 | 全ツール無条件許可 | Claude が自動判断 |
| 安全層 | hooks + disallowedTools | 内蔵対策 + hooks + disallowedTools |
| トークンコスト | 追加なし | 微増 |
| レイテンシ | 追加なし | 微増 |
| Teammate 互換 | 検証済み | 要検証（バックグラウンド実行での動作確認が必要） |

#### 有効化方法

`--auto-mode` フラグを `/breezing` または `/harness-work --breezing` に渡す:

```bash
/breezing --auto-mode all     # Auto Mode で全タスク完走
/execute --breezing --auto-mode all
```

**想定動作**: Worker/Reviewer の frontmatter は `permissionMode: bypassPermissions` のまま維持し、
Auto Mode の有効化は teammate 実行経路側で行う。hooks と disallowedTools はそのまま維持。

#### 移行方針

| フェーズ | 期間 | デフォルト | `--auto-mode` |
|---------|------|-----------|---------------|
| **Phase 0 (pre-RP)** | **RP 開始前** | `bypassPermissions` | 未対応（フラグ無視） |
| **Phase 1 (RP 開始後)** | **2026-03-12〜** | `bypassPermissions` | Auto Mode を検証 |
| Phase 2 (検証完了後) | TBD | TBD | 採用可否を再判定 |

Phase 1 では以下を確認してから Phase 2 への移行を判断する:

1. PreToolUse / PostToolUse hooks が Auto Mode でも従来どおり発火するか
2. Teammate のバックグラウンド spawn で権限プロンプトがブロックされないか
3. Breezing 並列実行でのトークンコスト増の実測

### Agent Teams 公式ドキュメント化

Agent Teams が公式に実験的機能としてドキュメント化された。
有効化には `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` 環境変数が必要:

```json
// settings.json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

**Harness への影響**:
- `breezing` スキルは Agent Teams を前提とする → セットアップ時に環境変数チェックを追加
- 公式ドキュメントで `teammateMode` 設定が明文化（`"in-process"` | `"tmux"` | `"auto"`）
- `TeammateIdle` / `TaskCompleted` の `{"continue": false}` は公式仕様として安定化

## 公式 Agent Teams ベストプラクティス整合（2026-03）

Claude Code 公式ドキュメント `agent-teams.md` に基づくベストプラクティスとの整合状況。

### タスク粒度ガイドライン

公式推奨: **5-6 tasks per teammate**。Harness の Lead はタスク分解時にこの粒度を目安にする。

| 粒度 | 判定 | 例 |
|------|------|-----|
| 小さすぎ | コーディネーション > 実装コスト | 1行修正、コメント追加 |
| 適切 | 明確な成果物を持つ自己完結単位 | 関数実装、テストファイル作成、レビュー |
| 大きすぎ | チェックインなしに長時間動作 | モジュール全体の再設計 |

### `teammateMode` 設定

公式サポートされた表示モード:

| モード | 動作 | 推奨環境 |
|--------|------|----------|
| `"auto"` | tmux セッション内なら split、それ以外は in-process | デフォルト |
| `"in-process"` | 全 teammate を同一ターミナルで管理 | VS Code 統合ターミナル |
| `"tmux"` | 各 teammate に個別ペイン | iTerm2 / tmux ユーザー |

```json
// settings.json
{ "teammateMode": "in-process" }
```

### Plan Approval パターン

公式の「Require plan approval for teammates」パターン:

```
Lead: "Spawn an architect teammate. Require plan approval before changes."
  → Teammate が plan mode で調査・計画を立案
  → Lead に plan_approval_request を送信
  → Lead が APPROVE → Teammate が実装開始
  → Lead が REJECT + feedback → Teammate が plan 修正
```

Harness では Reviewer の `REQUEST_CHANGES` → Worker 修正ループと補完的に使用可能。
複雑なアーキテクチャ変更時は Worker spawn に plan approval を要求することを推奨。

### Quality Gate Hooks

公式フックイベントとの整合:

| Hook | Harness 実装 | 公式ドキュメント |
|------|-------------|--------------|
| `TeammateIdle` | `teammate-idle.sh` (実装済み) | exit 2 で feedback + 継続指示 |
| `TaskCompleted` | `task-completed.sh` (実装済み) | exit 2 で完了拒否 + feedback |
| `SubagentStart` | 未実装 | settings.json で matcher 指定可能 |
| `SubagentStop` | agent frontmatter Stop hook で実装 | settings.json でも追加設定可能 |

### チームサイズガイドライン

公式推奨: **3-5 teammates**。これは Harness の現行構成（Worker 1-3 + Reviewer 1）と整合する。

> 「Three focused teammates often outperform five scattered ones.」— 公式ドキュメントより

## Codex CLI Environment

Codex CLI 環境では Agent Teams（Task/SendMessage/spawn）が利用できない。
以下の制約と代替パターンを理解した上で運用すること。

### 主要な制約

| Claude Code 機能 | Codex CLI 対応 |
|----------------|--------------|
| Agent Teams（並列 spawn） | 非対応 |
| `mode: "bypassPermissions"` | `approval_policy: never` で代替 |
| Task ツール | 非対応（Plans.md で代替） |
| SendMessage | 非対応（stdout で代替） |
| PreToolUse hooks | config.toml の sandbox で代替 |

### 代替パターン: codex exec 逐次実行

Agent Teams の代わりに `codex exec` を逐次呼び出す:

```bash
# Worker 相当（実装タスク）
echo "タスク内容" | codex exec - -a never -s workspace-write

# Reviewer 相当（Read-only レビュー）
echo "レビュー内容" | codex exec - -a never -s read-only
```

### 並列実行（Bash レベル）

```bash
echo "タスク A" | codex exec - -a never -s workspace-write > /tmp/out-a.txt 2>>/tmp/harness-codex-$$.log &
echo "タスク B" | codex exec - -a never -s workspace-write > /tmp/out-b.txt 2>>/tmp/harness-codex-$$.log &
wait
```

依存のないタスクは Bash の `&` + `wait` で並列化可能。
ただし同一ファイルへの並列書き込みは避けること。

### Thread Forking 活用可能性（調査: 2026-03）

Codex 0.110+ は `codex fork` / `/fork` でスレッドを分岐できるが、
**TUI 専用**であり `codex exec` からの非対話的 fork は未実装。

- [GitHub Issue #11750](https://github.com/openai/codex/issues/11750) で `codex exec fork` が提案段階
- 現状ワークアラウンド: PTY 経由で fork → `codex exec resume <id>` だが脆弱で ~6s のオーバーヘッド
- **結論**: breezing ワーカーの fork-thread 方式への移行は**時期尚早**。
  `codex exec fork` が安定リリースされるまでは現行の独立プロセス方式を維持する。

### codex exec フラグ正式名称

| Harness 旧記法 | 正式フラグ | 値 |
|---|---|---|
| `--approval-policy never` | `--ask-for-approval never` (`-a never`) | `untrusted` / `on-request` / `never` |
| `--sandbox workspace-write` | `--sandbox workspace-write` (`-s`) | `read-only` / `workspace-write` / `danger-full-access` |

> **注意**: `--approval-policy` は非公式エイリアス。公式ドキュメントでは `--ask-for-approval` (`-a`)。

### プロンプト渡し方式

- `--input-file` オプションは**存在しない**
- stdin 渡し: `cat file.md | codex exec -` が公式サポート
- 現行の `codex exec "$(cat file)"` はシェル引数上限（ARG_MAX）に注意。大きなプロンプトは stdin 方式が安全

### 設定可能メモリ — memory: project の Codex 側マッピング（調査: 2026-03）

Claude Code の `memory: project`（エージェントメモリ）に相当する Codex 側の仕組み:

| Claude Code | Codex CLI | 備考 |
|---|---|---|
| `memory: project` MEMORY.md | `AGENTS.md` 階層（global → project → subdir） | 永続的な指示・学習を記述 |
| agent-memory ディレクトリ | `agents.<name>.config_file` | エージェント別の設定ファイル |
| spawn prompt | `AGENTS.override.md` | 一時的なオーバーライド |
| セッション履歴 | `history.persistence: save-all` | `history.jsonl` に保存 |
| コンテキスト圧縮 | `model_auto_compact_token_limit` | 自動コンパクション |

**config.toml のメモリ関連キー** (0.110.0+):

```toml
# メモリ・履歴
history.persistence = "save-all"   # "save-all" | "none"
# history.max_bytes = 1048576      # 履歴ファイル上限（省略時: 無制限）

# メモリ設定 (0.110.0 リネーム: phase_1_model → extract_model, phase_2_model → consolidation_model)
[memories]
# extract_model = "gpt-5-mini"              # スレッド要約モデル（旧 phase_1_model）
# consolidation_model = "gpt-5"             # メモリ統合モデル（旧 phase_2_model）
# max_raw_memories_for_consolidation = 256  # 統合対象の最大メモリ数（旧 max_raw_memories_for_global）
no_memories_if_mcp_or_web_search = false    # MCP/Web検索使用時にメモリ汚染マーク（0.110.0 新機能）

# プロジェクトドキュメント
project_doc_max_bytes = 32768      # AGENTS.md の読み込み上限（デフォルト: 32KiB）
# project_doc_fallback_filenames = ["TEAM_GUIDE.md", ".agents.md"]

# エージェント
# agents.worker.config_file = ".codex/agents/worker.toml"
# agents.worker.description = "Implementation agent"
# agents.max_depth = 1
# agents.max_threads = 3
```

> **0.110.0 Polluted Memories**: `no_memories_if_mcp_or_web_search = true` にすると、
> Web 検索や MCP ツール呼び出しを含むスレッドが `memory_mode = "polluted"` としてマークされ、
> そのスレッドからメモリが生成されなくなる。Harness ワーカーは MCP を限定的に使用するため
> `false`（デフォルト）を推奨。

> **0.110.0 Workspace-scoped Memory Writes**: `workspace-write` sandbox で
> `~/.codex/memories/` が自動的に writable roots に含まれるようになった。
> `codex exec -s workspace-write` でメモリメンテナンスが追加承認なしで動作する。

**Harness での活用方針**:
- `.codex/AGENTS.md` にプロジェクト固有の学習・規約を集約
- `codex-learnings.md` の内容を定期的に AGENTS.md に昇格（SSOT 維持）
- `agents.<name>.config_file` でワーカー・レビュアーの個別設定を分離（将来対応）

## v2.1.68/v2.1.72 Effort レベル変更の影響

### 変更点
- Opus 4.6 が **medium effort** デフォルトに変更（v2.1.68）
- `ultrathink` キーワードで high effort を有効化（1ターン限定）
- Opus 4 / 4.1 が first-party API から削除（Opus 4.6 に自動移行）
- **v2.1.72**: `max` レベル廃止。3段階 `low(○)/medium(◐)/high(●)` に簡素化。`/effort auto` でリセット

### チームへの影響
- Worker（`model: sonnet`）: Sonnet は effort レベルの影響を受けない。変更なし
- Reviewer（`model: sonnet`）: 同上。変更なし
- Lead（Opus 使用時）: medium effort がデフォルト。複雑なタスク調整時は ultrathink を使用
- Codex Worker: effort 制御は Claude Code 固有。Codex CLI では適用外

### Effort 注入パターン
Lead が Worker/Reviewer を spawn する際、タスクの複雑度スコアに基づいて spawn prompt の冒頭に `ultrathink` を追加する。詳細は `skills-v3/harness-work/SKILL.md` の「Effort レベル制御」セクションを参照。

### v2.1.72 Agent tool `model` パラメータ復活
Agent tool の per-invocation `model` パラメータが復活した。エージェント定義の `model` とは別に、spawn 時に一時的なモデル指定が可能。
- **現状**: Worker/Reviewer とも `model: sonnet` 固定で運用
- **Phase 2 検討**: タスク特性に応じた動的モデル選択（軽量→haiku, 高品質→opus）

### v2.1.72 `/clear` バックグラウンドエージェント保持
`/clear` がフォアグラウンドタスクのみ停止するようになった。breezing チーム実行中に Lead が `/clear` してもバックグラウンド Worker は存続する。

### v2.1.72 並列ツール呼び出し修正
Read/WebFetch/Glob の失敗が sibling 呼び出しをキャンセルしなくなった。Worker の並列ファイル読み込みの信頼性が向上。
