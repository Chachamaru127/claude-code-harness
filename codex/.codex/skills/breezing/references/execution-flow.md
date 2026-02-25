# Execution Flow

Agent Teams を活用した `/breezing` の実行フロー。Lead は状況に応じてステージ間を柔軟に判断する。

## フロー全体図

```text
/breezing 認証機能からユーザー管理まで完了して
    ↓
Step 0: breezing-active.json 即時書き込み（全 Phase の前に実行）
    ↓
┌─────────────────────────────────────────────────────────────┐
│ Phase 0: Planning Discussion（デフォルト実行）                │
│                                                              │
│  Planner + Critic を spawn → 計画議論 最大 3 ラウンド       │
│  Planner ↔ Critic 直接対話 + Lead 調整                      │
│  → 精査済み計画をユーザーに提示 → Planner/Critic shutdown   │
│                                                              │
│  ※ --no-discuss → Phase 0 スキップ                          │
│  ※ 詳細: planning-discussion.md 参照                        │
└─────────────────────────────────────────────────────────────┘
    ↓
┌─────────────────────────────────────────────────────────────┐
│ Phase A: Pre-delegate（ユーザーのパーミッションモード維持）   │
│                                                              │
│  Step 1: 環境チェック                                        │
│  Step 2: 範囲確認（ユーザー承認）                            │
│  Step 3: Team 初期化 → TaskCreate → Teammates spawn          │
│                                                              │
│  ※ Write/Edit/Bash はこの Phase でのみ Lead が直接使用       │
│  ※ 環境チェック失敗時は breezing-active.json を削除          │
└─────────────────────────────────────────────────────────────┘
    ↓ delegate mode ON
┌─────────────────────────────────────────────────────────────┐
│ Phase B: Delegate（Lead は調整専念、コード編集禁止）          │
│                                                              │
│  ┌─────────────┐   ┌─────────────┐   ┌─────────────┐       │
│  │ 実装         │ ↔ │ レビュー     │ ↔ │ リテイク     │       │
│  │ Implementer  │   │ Reviewer     │   │ Impl↔Rev    │       │
│  │ 自律タスク消化│   │ 部分/全体    │   │ 直接対話可   │       │
│  └─────────────┘   └─────────────┘   └─────────────┘       │
│                                                              │
│  Lead はこのサイクルを監視し、状況に応じて:                   │
│  ・半分完了 → 部分レビューを指示                             │
│  ・軽微な問題 → Reviewer↔Implementer 直接対話で解決          │
│  ・重大な問題 → タスク分解して修正タスク登録                 │
│  ・3回リテイク超過 → ユーザーにエスカレーション              │
│                                                              │
│  Lead 使用可能ツール: TaskCreate/TaskUpdate/TaskList/         │
│                       TaskGet/SendMessage のみ               │
└─────────────────────────────────────────────────────────────┘
    ↓ 全タスク完了 + APPROVE → delegate mode OFF
┌─────────────────────────────────────────────────────────────┐
│ Phase C: Post-delegate（パーミッションモード復元）            │
│                                                              │
│  統合検証 → Plans.md 更新 → git commit → メトリクスレポート  │
│  breezing-active.json 削除 → Team cleanup                    │
│                                                              │
│  ※ Write/Edit/Bash を再び Lead が直接使用                    │
└─────────────────────────────────────────────────────────────┘
```

> **なぜ Phase 分離が必要か**: Claude Code の `delegate` モードはパーミッションモードを
> 実際に変更する（Write/Edit/Bash が制限される）。bypass permissions で起動したセッションで
> delegate に切り替えると、bypass が失われて承認プロンプトが発生する。
> Phase A/C では delegate に入らないことで、ユーザーのパーミッションモードを維持する。

## Step 0: breezing-active.json 即時書き込み（最優先）

**Phase 0・Phase A のいずれよりも前に実行する。** Compaction 対策として、モード情報を永続化する。

```jsonc
// .claude/state/breezing-active.json に即時書き込み
{
  "session_id": "breezing-{timestamp}",
  "started_at": "{ISO8601}",
  "impl_mode": "standard",  // --codex なしの場合。--codex ありなら "codex" にすること！
  "task_range": "{ユーザー指定の範囲}"
  // 残りのフィールド (team_name, plans_md_mapping 等) は Step 3 で追記
}
```

**`impl_mode` フィールド（必須分岐）**:

| 値 | 設定条件 | spawn する Implementer | ランタイムガード |
|---|----------|----------------------|-----------------|
| `"standard"` | `--codex` フラグ**なし** | `claude-code-harness:task-worker` | なし（通常の breezing role guard のみ） |
| `"codex"` | `--codex` フラグ**あり** | `claude-code-harness:codex-implementer` | pretooluse-guard が Write/Edit/Bash を制限 |

> **重要**: `--codex` フラグがある場合は `impl_mode` を必ず `"codex"` に設定すること。
> この値が Step 3 の Implementer subagent_type 選択と、Compaction 復元時のエージェント選択の両方を決定する。

**なぜ最初に書くか**: Compaction が準備ステージ中に発生しても、`impl_mode` が永続化されていれば復元できる。

**早期中断時のクリーンアップ**: Step 0 で書き込んだ breezing-active.json を削除してから停止する。部分的なファイルが残ると「続きやって」で誤復元されるリスクがあるため。

```text
以下のいずれかで中断 → breezing-active.json 削除 → 停止:
  ・環境チェック失敗（Agent Teams 未有効）
  ・ユーザーが範囲確認で拒否/キャンセル
  ・Team 初期化の失敗
```

## Phase 0: Planning Discussion（デフォルト実行）

デフォルトで起動。`--no-discuss` フラグ指定時はスキップ。Step 0 の後、Phase A の前に実行する。

```text
1. Planner (plan-analyst) + Critic (plan-critic) を spawn
   ※ mode: "bypassPermissions" で spawn（Teammate はプロンプト不可のため必須）
2. Round 1: Planner がタスク分析 → Planner ↔ Critic 直接対話で疑問点を解消
3. Round 2: Critic が Red Teaming 検証 → Planner に確認が必要な点を直接質問
4. Round 3: Lead が両者の分析を統合 → ユーザーに提示
5. (必要なら) ユーザーが Plans.md 修正 → 追加ラウンド（合計で最大 3 ラウンドまで）
6. Planner/Critic shutdown → Phase A へ
```

Phase 0 で得られた情報（owns 推定、依存提案等）は Phase A に引き継がれ、
Phase A の V1〜V4 バリデーションの**参考情報**として活用する（ただしスキップはしない。
Phase 0 は戦略/アーキテクチャ評価、V1〜V4 は技術的詳細チェックで役割が異なるため）。

詳細: [planning-discussion.md](planning-discussion.md) 参照

## 準備ステージ（Phase A）

### 1. 環境チェック

```bash
# Agent Teams 有効化チェック
# CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 が必要
```

未設定時のメッセージ:

```text
⚠️ Agent Teams が有効化されていません。

以下を settings.json に追加してください:
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}

Agent Teams なしで実行する場合は `/work all` を使用してください。
```

### 2. 範囲確認（ユーザー承認必須 / `--from-work` 時スキップ）

**`--from-work` フラグがある場合**: `/work` 側でスコープ確認済みのため、このステップをスキップ。
args から scope を解析し、対象タスクを特定して直接 Step 3 へ進む。

**通常時**:

| 指定パターン | 解釈 |
|-------------|------|
| `認証機能からユーザー管理まで` | 「認証」〜「ユーザー管理」を含むタスク |
| `ログイン機能を終わらせて` | 「ログイン」を含む全タスク |
| `Header, Footer, Sidebar` | 列挙されたキーワードを含むタスク |
| `全部やって` | Plans.md の全未完了タスク |
| `続きやって` | breezing-active.json から未完了タスクを復元 |

```text
🏇 Breezing - 範囲を確認させてください

指定: 「認証機能からユーザー管理まで」

対象タスク:
├── 3. ログイン機能の実装 (cc:TODO)
├── 4. 認証ミドルウェアの作成 (cc:TODO)
└── 5. セッション管理 (cc:TODO)

Team 構成:
├── Lead: 調整専念 (Phase B で delegate mode)
├── Implementer: 2 個 (独立タスク数に基づく)
└── Reviewer: 1 個

計 3 タスクを Implementer 2 並列で完走します。

これで合っていますか？
```

### 3. Team 初期化（Phase A 最終ステップ）

> **重要**: Step 3 は Phase A 内で実行する。delegate mode にはまだ入らない。
> breezing-active.json の Write、TaskCreate 登録、Teammates spawn を
> ユーザーのパーミッションモード（bypass 等）を維持したまま完了する。

1. breezing-active.json 更新（メタデータ追記 — タスク状態は Agent Teams TaskList に委譲）
2. **タスク粒度バリデーション**（TaskCreate 前の必須チェック）
   - V1〜V5 の観点で各タスクを検証（詳細: plans-to-tasklist.md 参照）
   - 問題あり → ユーザーに修正提案を表示、承認後に続行
   - V5（依存関係未宣言）は自動修復
3. Plans.md タスクを TaskCreate で共有タスクリストに登録
   - owns: アノテーション付与
   - addBlockedBy で依存関係設定（V5 自動修復分を含む）
4. Implementer Teammates spawn (N 個)
   - **`--codex` フラグによるエージェント選択（必須分岐）**:
     - `--codex` **あり** → `subagent_type: "claude-code-harness:codex-implementer"` で spawn
     - `--codex` **なし** → `subagent_type: "claude-code-harness:task-worker"` で spawn
   - **並列 spawn**: N 個の Implementer を**同時に spawn** する（N = max(1, min(独立タスク数, --parallel N, planner_max_parallel, 5))。planner_max_parallel/--parallel 未指定時はデフォルト上限 3）
   - `mode: "bypassPermissions"` を指定（Teammate はプロンプト不可のため必須）
   - エージェント定義の `memory: project` により永続メモリが自動注入
   - spawn prompt でロールマーカーファイル Write を指示
   - **注意**: `impl_mode: "codex"` の場合に `task-worker` を spawn するのは**絶対禁止**。逆も同様。
5. Reviewer Teammate spawn (1 個)
   - `subagent_type: "claude-code-harness:code-reviewer"` で spawn
   - `mode: "bypassPermissions"` を指定（Teammate はプロンプト不可のため必須）
   - エージェント定義の `memory: project` により永続メモリが自動注入
   - spawn prompt でロールマーカーファイル Write を指示
6. (--codex-review) Codex MCP レビュー設定
7. **delegate mode ON** → Phase B へ遷移（ここで初めてモード変更）

詳細: team-composition.md 参照

### breezing-active.json スキーマ (v2)

**ファイル**: `.claude/state/breezing-active.json`

タスク状態は Agent Teams TaskList (`~/.claude/tasks/`) に一元化。
breezing-active.json はメタデータのみを保持。

```json
{
  "session_id": "breezing-20260206-0300",
  "started_at": "2026-02-06T03:00:00Z",
  "impl_mode": "standard",
  "team_name": "breezing-auth-feature",
  "task_range": "認証機能からユーザー管理まで",
  "plans_md_mapping": {
    "task-1": "4.1",
    "task-2": "4.2",
    "task-3": "4.3"
  },
  "options": {
    "codex_review": false,
    "parallel": 2
  },
  "team": {
    "implementer_count": 2,
    "reviewer_count": 1,
    "model": "sonnet"
  },
  "review": {
    "retake_count": 0,
    "max_retakes": 3
  },
  "invoked_from": null
}
```

**`invoked_from` フィールド**（`--from-work` 時のみ設定）:

```json
{
  "invoked_from": {
    "source": "work",
    "strategy_analysis": {
      "recommended": "breezing",
      "confidence": "high",
      "metrics": { "task_count": 5, "independent_ratio": 0.8 }
    },
    "completed_tasks": [],
    "failure_history": []
  }
}
```

- `source: "work"`: Strategy Analyzer による事前提案
- `source: "work-escalation"`: 反復失敗からのエスカレーション（`completed_tasks` が非空）

### Implementer 数の自動決定

```
独立タスク数 = 依存関係なしで並列実行可能なタスク数

Implementer 数 = max(1, min(独立タスク数, --parallel N, planner_max_parallel, 5))

  max(1, ...) : スターブ防止（最低 1 Implementer を保証）
  min(..., 5) : 過剰 spawn 防止（ハード上限）
  planner_max_parallel: Phase 0 Planner が推奨する並列数（未設定時は無視）
  --parallel N: ユーザー指定（未指定時は無視）
  デフォルト上限: 3 (--parallel 未指定かつ planner_max_parallel 未設定時の実効値)
```

#### 計算例

| 独立タスク数 | --parallel | planner_max_parallel | Implementer 数 |
|------------|-----------|---------------------|---------------|
| 5          | 未指定     | 未設定               | min(5, 3) = 3 |
| 5          | 2          | 未設定               | min(5, 2, 3) = 2 |
| 8          | 5          | 4                   | min(8, 5, 4) = 4 |
| 1          | 5          | 未設定               | max(1, min(1, 5, 3)) = 1 |
| 20         | 10         | 未設定               | max(1, min(20, 10, 5)) = 5 |

### TaskCreate 登録ルール

Plans.md のタスクを Agent Teams の共有タスクリスト (TaskCreate) に変換する際:

1. **タスク粒度**: Plans.md の 1 タスク = 1 TaskCreate エントリ
2. **owns: アノテーション**: 各タスクが触るファイルを description に記載
3. **依存関係**: 同一ファイルを触るタスクは `addBlockedBy` で順次化
4. **activeForm**: 進捗表示用の present continuous 形式

詳細: plans-to-tasklist.md 参照

## 実装・レビューサイクル

### Lead の運用ガイドライン

Lead はサイクル内で以下を**自律的に判断**する:

| 状況 | Lead の判断 |
|------|------------|
| 全タスク未着手 | 実装を開始させる |
| 半数のタスクが完了 | 部分レビューを Reviewer に指示可能 |
| 全タスク完了 | 全体レビューを Reviewer に指示 |
| Reviewer から軽微な質問 | Reviewer↔Implementer 直接対話を許可 |
| REQUEST CHANGES | findings を修正タスクに分解、Implementer に指示 |
| 3回リテイク超過 | ユーザーにエスカレーション |

**重要**: Lead は「この順番で進めなければならない」という制約はない。
状況を見て最適な判断をすること。

### シグナルベースの動的判断

Lead は Phase B 中に `.claude/state/breezing-signals.jsonl` を定期チェックし、
Hook が生成したシグナルに基づいて自律的に判断する:

| シグナル | 意味 | Lead のアクション |
|---|---|---|
| `partial_review_recommended` | タスクの 50% が完了 | Reviewer に部分レビューを指示（推奨） |
| `next_batch_recommended` | 現バッチの 60% が完了 | 次バッチの TaskCreate 登録（Progressive Batch 時） |

> **注**: シグナルは推奨であり、Lead は状況に応じて無視できる。
> 例: 残りタスクが 1 個なら部分レビューは不要。

**シグナルのセッションスコープ**:
- 各シグナルには `session_id` が付与される（breezing-active.json の session_id と一致）
- dedup はセッション単位で行われるため、前回セッションのシグナルが今回のセッションを抑制しない
- **50% シグナルの最小バッチサイズ**: バッチサイズ 1-2 では部分レビューは不発（全体レビューで十分なため）

**シグナルファイルのライフサイクル**:
- セッション開始時: breezing-active.json 書き込み時に `breezing-signals.jsonl` はリセットしない（セッション ID で分離）
- セッション終了時: Phase C の cleanup で `breezing-signals.jsonl` を削除

### Implementer の自律ループ

各 Implementer は以下を独立して繰り返す:

```
1. TaskList で pending かつ blockedBy が空のタスクを検索
2. 最も ID が小さいタスクを self-claim (TaskUpdate → in_progress)
3. task-worker フロー実行:
   - 実装 → セルフレビュー4観点 → ビルド → テスト
4. 成功 → TaskUpdate(completed)
5. 失敗 (3回) → Lead にエスカレーション (SendMessage)
6. 残りタスクあり → Step 1 へ
7. 残りタスクなし → Lead に完了報告 (SendMessage)
```

### ファイル競合回避

```
Lead が準備ステージで検出:
  タスク A: src/auth/login.ts を編集
  タスク B: src/auth/login.ts を編集
  → B に addBlockedBy: [A] を設定

結果: A が完了するまで B は pending のまま
```

### レビューのタイミング

Lead は以下のタイミングで Reviewer にレビューを指示できる:

```
パターン A: 全完了後レビュー（デフォルト）
  全 Implementer 完了 → Reviewer に全体レビュー指示

パターン B: 部分レビュー
  独立タスクグループ A が完了 → Reviewer にグループ A のレビュー指示
  並行してグループ B の実装を継続

パターン C: 即時レビュー
  重要度の高いタスクが完了 → すぐにレビュー指示
```

### エスカレーション処理

```
Implementer → SendMessage → Lead:
  "タスク X が 3回失敗。原因: 型エラー解消不能"

Lead の判断:
  1. 別 Implementer に再割当て
  2. タスク分割して再登録
  3. ユーザーにエスカレーション (重大問題時)
```

### リテイクループ

詳細: review-retake-loop.md 参照

## 完了ステージ（Phase C: Post-delegate）

### 前提

- 全タスクが completed
- Reviewer の最終判定が APPROVE

### Phase 遷移: delegate → Post-delegate

**全タスク完了 + APPROVE 確定後、delegate mode を解除してから完了処理を行う。**

```text
Phase B (delegate) 終了条件:
  ・全タスクが completed
  ・Reviewer の最終判定が APPROVE
    ↓
delegate mode OFF → Phase C (Post-delegate) へ遷移
  ・Lead が Write/Edit/Bash を再び使用可能
  ・ユーザーの元のパーミッションモード（bypass 等）が復元される
```

### APPROVE ファストパス（Phase C 冒頭で実行）

delegate mode 解除直後に `.claude/state/review-result.json` を確認し、
条件を満たす場合は統合検証フェーズへ即座にスキップする。

```bash
# review-result.json が存在する場合のみチェック
REVIEW_RESULT=".claude/state/review-result.json"
if [ -f "$REVIEW_RESULT" ]; then
  VERDICT=$(jq -r '.verdict // ""' "$REVIEW_RESULT")
  RESULT_HASH=$(jq -r '.commit_hash // ""' "$REVIEW_RESULT")
  HEAD_HASH=$(git rev-parse HEAD 2>/dev/null || echo "")

  if [ "$VERDICT" = "APPROVE" ] && [ -n "$RESULT_HASH" ] && [ "$RESULT_HASH" = "$HEAD_HASH" ]; then
    # ファストパス: 手動確認スキップ → 統合検証へ直行
    echo "APPROVE ファストパス: review-result.json を確認 (hash: $HEAD_HASH)"
    goto 統合ビルド・テスト最終確認
  fi
fi
# ハッシュ不一致または review-result.json 未存在 → 通常フロー継続
```

**ファストパス条件**:
1. `.claude/state/review-result.json` が存在する
2. `verdict` フィールドが `"APPROVE"`
3. `commit_hash` が現在の `HEAD` と一致（レビュー後に追加コミットがないことを確認）

**フォールバック**: 条件未達の場合は通常の手動確認フローを維持する。

### 処理

1. **delegate mode 解除**（Phase C 開始）
2. **APPROVE ファストパスチェック**（上記参照）
3. 統合ビルド・テスト最終確認
4. Plans.md 更新 (cc:TODO → cc:done)
5. git commit (Conventional Commits 形式)
6. breezing-active.json 削除
7. review-result.json 削除（`rm -f .claude/state/review-result.json`）
8. Team クリーンアップ
9. メトリクスレポート生成

### 検証実行規則

Phase 4 の統合検証は ultrawork と同一:

| 順位 | 対象 | コマンド |
|------|------|---------|
| 1 | `./tests/validate-plugin.sh` | `bash ./tests/validate-plugin.sh` |
| 2 | `./scripts/ci/check-consistency.sh` | `bash ./scripts/ci/check-consistency.sh` |
| 3 | `package.json` の `test` script | `{pkg_mgr} test` |
| 4 | `package.json` の `lint` script | `{pkg_mgr} run lint` |
| 5 | `pytest.ini` / `pyproject.toml` | `pytest` |
| 6 | `Cargo.toml` | `cargo test` |
| 7 | `go.mod` | `go test ./...` |

> **注**: 該当ファイルが存在する場合は必ず実行し、**失敗した時点で即停止**する。

### 完了レポート

```markdown
🏇 Breezing Complete!

## Summary
- 対象: 認証機能からユーザー管理まで (3 タスク)
- 所要時間: 15 分
- Implementer: 2 並列
- リテイク: 1 回

## Tasks
✅ 3. ログイン機能の実装
✅ 4. 認証ミドルウェアの作成
✅ 5. セッション管理

## Team Activity (TaskCompleted/TeammateIdle Hook - 実装済み)
| Teammate | 完了タスク | 完了時刻 |
|----------|-----------|---------|
| Implementer #1 | #1, #3 | 14:32, 14:45 |
| Implementer #2 | #2 | 14:38 |
| Reviewer | (レビュー完了) | 14:50 |

## Review
- 判定: APPROVE (Grade: A)
- Codex Review: N/A

## Build & Test
- ビルド: ✅ 成功
- テスト: ✅ 12/12 通過

## Commit
- abc1234: feat: implement auth flow (login, middleware, session)

楽勝でした 🐎💨
```

> **メトリクスの制限**: PostToolUse Hook は Teammate に継承されないため、Teammate 別のトークン数・ツール使用数は取得不可。
> TaskCompleted/TeammateIdle Hook（Lead 側で発火、実装済み）により「誰がどのタスクをいつ完了したか」のタイムラインは `.claude/state/breezing-timeline.jsonl` に記録される。
> Lead 自身の agent-trace.jsonl は正常に記録される。全体コストは `/cost` コマンドで確認可能。
