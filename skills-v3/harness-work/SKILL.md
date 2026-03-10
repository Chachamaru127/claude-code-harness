---
name: harness-work
description: "Unified execution skill for Harness v3. Implements Plans.md tasks from single task to full parallel team runs. Use when user mentions: implement, execute, /harness-work, /work, do everything, build features, run tasks, breezing, team run, --codex, --parallel. Do NOT load for: planning, code review, release, or setup."
description-ja: "Harness v3 統合実行スキル。Plans.md タスクを1件から全並列チーム実行まで担当。以下で起動: 実装して、実行して、/harness-work、/work、全部やって、breezing、チーム実行、--codex、--parallel。プランニング・レビュー・リリース・セットアップには使わない。"
allowed-tools: ["Read", "Write", "Edit", "Grep", "Glob", "Bash", "Task"]
argument-hint: "[all] [task-number|range] [--codex] [--parallel N] [--no-commit] [--resume id] [--breezing]"
---

# Harness Work (v3)

Harness v3 の統合実行スキル。
以下の旧スキルを統合:

- `work` — Plans.md タスクの実装（スコープ自動判断）
- `impl` — 機能実装（タスクベース）
- `breezing` — チームフル自動実行（Agent Teams）
- `parallel-workflows` — 並列ワークフロー最適化
- `ci` — CI 失敗時の復旧

## Quick Reference

| ユーザー入力 | モード | 動作 |
|------------|--------|------|
| `/execute` | **auto** | タスク数で自動判定（下記参照） |
| `/execute all` | **auto** | 全未完了タスクを自動モードで実行 |
| `/execute 3` | solo | タスク3だけ即実行 |
| `/execute --parallel 5` | parallel | 5ワーカーで並列実行（強制） |
| `/execute --codex` | codex | Codex CLI に委託（明示時のみ） |
| `/execute --breezing` | breezing | Agent Teams でチーム実行（強制） |

## Auto Mode Detection（フラグなし時の自動判定）

明示的なモードフラグ（`--parallel`, `--breezing`, `--codex`）がない場合、
対象タスク数に応じて最適なモードを自動選択する:

| 対象タスク数 | 自動選択モード | 理由 |
|-------------|---------------|------|
| **1 件** | Solo | オーバーヘッド最小。直接実装が最速 |
| **2〜3 件** | Parallel（Task tool） | Worker 分離のメリットが出始める閾値 |
| **4 件以上** | Breezing（Agent Teams） | Lead 調整 + Worker 並列 + Reviewer 独立の三者分離が効果的 |

### ルール

1. **明示フラグは常にオートモードを上書き**する
   - `--parallel N` → Parallel モード（タスク数に関係なく）
   - `--breezing` → Breezing モード（タスク数に関係なく）
   - `--codex` → Codex モード（タスク数に関係なく）
2. **`--codex` は明示時のみ発動**。Codex CLI が未インストールの環境があるため、自動選択しない
3. `--codex` は他モードと組み合わせ可能: `--codex --breezing` → Codex + Breezing

## オプション

| オプション | 説明 | デフォルト |
|----------|------|----------|
| `all` | 全未完了タスクを対象 | - |
| `N` or `N-M` | タスク番号/範囲指定 | - |
| `--parallel N` | 並列ワーカー数 | auto |
| `--sequential` | 直列実行強制 | - |
| `--codex` | Codex CLI で実装委託（明示時のみ、自動選択しない） | false |
| `--no-commit` | 自動コミット抑制 | false |
| `--resume <id\|latest>` | 前回セッション再開 | - |
| `--breezing` | Agent Teams でチーム実行 | false |
| `--no-tdd` | TDD フェーズスキップ | false |
| `--no-simplify` | Auto-Refinement スキップ | false |
| `--auto-mode` | Auto Mode で権限判断（Breezing 時のみ有効） | false |

> **Token Optimization (v2.1.69+)**: git 操作を伴わない軽量タスクでは
> plugin settings の `includeGitInstructions: false` を有効にして
> プロンプトトークンを削減できる。

## スコープダイアログ（引数なし時）

```
/execute
どこまでやりますか?
1) 次のタスク: Plans.md の次の未完了タスク → Solo で実行
2) 全部（推奨）: 残りのタスクをすべて完了 → タスク数で自動モード選択
3) 番号指定: タスク番号を入力（例: 3, 5-7）→ 件数で自動モード選択
```

引数ありなら即実行（対話スキップ）:
- `/execute all` → 全タスク、自動モード選択
- `/execute 3-6` → 4件なので Breezing 自動選択

## Effort レベル制御（v2.1.68+, v2.1.72 簡素化）

Claude Code v2.1.68 で Opus 4.6 は **medium effort** (`◐`) がデフォルト。
v2.1.72 で `max` レベルが廃止され、3段階 `low(○)/medium(◐)/high(●)` に簡素化。
`/effort auto` でデフォルトにリセット可能。
複雑なタスクには `ultrathink` キーワードで high effort (`●`) を有効化する。

### 多要素スコアリング

タスク着手時に以下のスコアを合算し、**閾値 3 以上**で ultrathink を注入:

| 要素 | 条件 | スコア |
|------|------|--------|
| ファイル数 | 変更対象 4 ファイル以上 | +1 |
| ディレクトリ | core/, guardrails/, security/ を含む | +1 |
| キーワード | architecture, security, design, migration を含む | +1 |
| 失敗履歴 | agent memory に同タスクの失敗記録あり | +2 |
| 明示指定 | PM テンプレートに ultrathink 記載あり | +3（自動採用） |

### 注入方法

スコア ≥ 3 の場合、Worker spawn prompt の冒頭に `ultrathink` を追加。
breezing モードでも同じロジックが適用される（harness-work が一本化して管理）。

## 実行モード詳細

### Solo モード（1 件時の自動選択）

1. Plans.md を読み込み、対象タスクを特定
   - Plans.md が存在しない場合: `Plans.md が見つかりません。/harness-plan create で作成してください。` → **停止**
   - ヘッダーに DoD / Depends カラムがない場合: `Plans.md が旧フォーマットです。/harness-plan create で再生成してください。` → **停止**
1.5. **タスク背景確認**（30 秒）:
   - タスクの「内容」と「DoD」から **目的**（このタスクが解く課題）を 1 行で推論表示
   - `git grep` / `Glob` で **影響範囲**（変更が及ぶファイル/モジュール）を推論表示
   - 推論に自信がある場合: そのまま実装に進む（フロー遅延なし）
   - 推論に自信がない場合: ユーザーに 1 問だけ確認（「この理解で合っていますか？」）
2. タスクを `cc:WIP` に更新
3. **TDD フェーズ**（`[skip:tdd]` なし & テストFW存在時）:
   a. テストファイルを先に作成（Red）
   b. 失敗を確認
4. コードを実装（Green）（Read/Write/Edit/Bash）
5. `/simplify` で Auto-Refinement（`--no-simplify` で省略可）
6. `git commit` で自動コミット（`--no-commit` で省略可）
7. タスクを `cc:完了` に更新（commit hash 付与）
   - `git log --oneline -1` で直近の commit hash（短縮形 7 文字）を取得
   - Plans.md の Status を `cc:完了 [a1b2c3d]` 形式で更新
   - commit がない場合（`--no-commit` 時）は hash なしで `cc:完了` のみ
8. **失敗時の自動再計画**（テスト/CI 失敗時のみ）:
   - テスト実行結果を確認
   - 失敗した場合: 修正タスク案を state に保存し、承認コマンド経由で Plans.md に追加（「失敗タスクの自動再チケット化」参照）
   - 成功した場合: 次タスクへ進む

### Parallel モード（2〜3 件時の自動選択 / `--parallel N` で強制）

`[P]` マーク付きタスクを N ワーカーで並列実行。
`--parallel N` で明示指定した場合は、タスク数に関係なくこのモードを使用。
同一ファイルへの書き込みが競合する場合は git worktree で分離。

### Codex モード（`--codex` 明示時のみ）

```bash
TIMEOUT=$(command -v timeout || command -v gtimeout || echo "")
CODEX_PROMPT=$(mktemp /tmp/codex-prompt-XXXXXX.md)
# タスク内容を一意なテンポラリファイルに書き出し
# stdin 経由で渡す（"-" は公式 stdin 指定。ARG_MAX 超過を回避）
cat "$CODEX_PROMPT" | $TIMEOUT 120 codex exec - -a never -s workspace-write 2>>/tmp/harness-codex-$$.log
rm -f "$CODEX_PROMPT"
```

タスク内容を一意なテンポラリファイルに書き出し、stdin 経由で Codex CLI に委託。
並列実行時もパスが衝突せず、大きなプロンプトも ARG_MAX に制約されない。
結果を検証し、品質基準を満たさない場合は自力で修正。

### Breezing モード（4 件以上で自動選択 / `--breezing` で強制）

Agent Teams（Worker + Reviewer）でチーム実行。

> **CC v2.1.69+**: nested teammates はプラットフォーム側で禁止されるため、
> Worker/Reviewer プロンプトには冗長な nested 防止文言を追加しない。

```
Lead (this agent)
├── Worker (task-worker agent) — 実装担当
└── Reviewer (code-reviewer agent) — レビュー担当
```

**フロー**:
1. Lead: タスク割り当て（TaskCreate/TaskUpdate）
2. Worker: 実装 → `cc:完了 [hash]`（直近 commit hash 付与）
3. Reviewer: コードレビュー → APPROVE / REQUEST_CHANGES
4. REQUEST_CHANGES の場合: 修正タスクを作成 → 再実装

## CI 失敗時の対応

CI が失敗した場合:

1. ログを確認してエラーを特定
2. 修正を実施
3. 同一原因で 3 回失敗したら自動修正ループを停止
4. 失敗ログ・試みた修正・残る論点をまとめてエスカレーション

## 失敗タスクの自動再チケット化

タスク完了後にテスト/CI が失敗した場合、修正タスク案を自動生成し、承認後に Plans.md へ反映する:

### トリガー条件

| 条件 | アクション |
|------|----------|
| `cc:完了` 後にテスト失敗 | 修正タスク案を state に保存し、承認を待つ |
| CI 失敗（3回未満） | 修正を実施し、失敗カウントをインクリメント |
| CI 失敗（3回目） | 修正タスク案を提示 + エスカレーション |

### 修正タスクの自動生成

1. 失敗原因を分類（syntax_error / import_error / type_error / assertion_error / timeout / runtime_error）
2. `.claude/state/pending-fix-proposals.jsonl` に修正タスク案を保存:
   - 番号: 元タスク番号 + `.fix` サフィックス（例: `26.1.fix`）
   - 内容: `fix: [元タスク名] - [失敗原因カテゴリ]`
   - DoD: テスト/CI が通ること
   - Depends: 元タスク番号
3. ユーザーが `approve fix <task_id>` を送ると Plans.md に `cc:TODO` で追加
4. `reject fix <task_id>` で提案を破棄。pending が1件だけのときは `yes` / `no` でも応答可能

## 関連スキル

- `plan` — 実行するタスクを計画する
- `review` — 実装のレビュー
- `release` — バージョンバンプ・リリース
