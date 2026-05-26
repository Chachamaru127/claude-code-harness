# sync サブコマンド — 進捗同期フロー

実装状況と Plans.md を照合し、差分を検出・更新する。

## Step 0: Plans.md 検証

Plans.md の存在とフォーマットを確認する。問題がある場合は即座に案内して停止する。

| 状態 | 案内 |
|------|------|
| Plans.md が存在しない | `Plans.md が見つかりません。/harness-plan create で作成してください。` → **停止** |
| ヘッダーに DoD / Depends カラムがない（v1 形式） | `Plans.md が旧フォーマット（3カラム）です。/harness-plan create で v2（5カラム）に再生成してください。既存タスクは自動的に引き継がれます。` → **停止** |
| v2 形式（5カラム） | そのまま Step 1 に進む |

## Step 1: 現状収集（並列）

```bash
# Plans.md の状態
cat Plans.md

# Git 変更状態
git status
git diff --stat HEAD~3

# 直近コミット履歴
git log --oneline -10

# エージェントトレース（直近の編集ファイル）
tail -20 .claude/state/agent-trace.jsonl 2>/dev/null | jq -r '.files[].path' | sort -u
```

## Step 1.5: Agent Trace 分析

Agent Trace から直近の編集履歴を取得し、Plans.md のタスクと照合する:

```bash
# 直近の編集ファイル一覧
RECENT_FILES=$(tail -20 .claude/state/agent-trace.jsonl 2>/dev/null | \
  jq -r '.files[].path' | sort -u)

# プロジェクト情報
PROJECT=$(tail -1 .claude/state/agent-trace.jsonl 2>/dev/null | \
  jq -r '.metadata.project')
```

**照合ポイント**:

| チェック項目 | 検出方法 |
|------------|----------|
| Plans.md にないファイル編集 | Agent Trace vs タスク記述 |
| タスク記述と異なるファイル | 想定ファイル vs 実際の編集 |
| 長時間編集がないタスク | Agent Trace 時系列 vs WIP 期間 |

## Step 2: 差分検出

| チェック項目 | 検出方法 |
|------------|----------|
| 完了済みなのに `cc:WIP` | コミット履歴 vs マーカー |
| 着手済みなのに `cc:TODO` | 変更ファイル vs マーカー |
| `cc:完了` なのに未コミット | git status vs マーカー |

### Artifact Hash 後方互換

`cc:完了 [a1b2c3d]` 形式（commit hash 付き）と `cc:完了`（hash なし）の両方を認識する。

**マッチングルール**:
- `cc:完了` → hash なし完了として扱う
- `cc:完了 [xxxxxxx]` → hash 付き完了として扱う。7 文字の短縮 hash を保持
- hash 付きの場合、`git log --oneline` と照合してコミットの存在を確認可能

> **後方互換**: hash なし形式も引き続き有効。既存の Plans.md を破壊しない。

## Step 3: Plans.md 更新提案

差分が検出された場合、提案して実行する:

```
Plans.md 更新が必要です

| Task | 現在 | 変更後 | 理由 |
|------|------|--------|------|
| XX   | cc:WIP | cc:完了 | コミット済み |
| YY   | cc:TODO | cc:WIP | ファイル編集済み |

更新しますか？ (yes / no)
```

## Step 4: 進捗サマリー出力

```markdown
## 進捗サマリー

**プロジェクト**: {{project_name}}

| ステータス | 件数 |
|----------|------|
| 未着手 (cc:TODO) | {{count}} |
| 作業中 (cc:WIP) | {{count}} |
| 完了 (cc:完了) | {{count}} |
| PM確認済 (pm:確認済) | {{count}} |

**進捗率**: {{percent}}%

### 直近の編集ファイル (Agent Trace)
- {{file1}}
- {{file2}}
```

## Step 5: 次のアクション提案

```
次にやること

**優先 1**: {{タスク}}
- 理由: {{依頼中 / アンブロック待ち}}

**推奨**: harness-work, harness-review
```

## 異常検知

| 状況 | 警告 |
|------|------|
| 複数の `cc:WIP` | 複数タスクが同時進行中 |
| `pm:依頼中` が未処理 | PM の依頼を先に処理する |
| 大きな乖離 | タスク管理が追いついていない |
| WIP が 3日以上更新なし | ブロックされていないか確認 |

## Step 6: レトロスペクティブ（デフォルト ON）

`sync` 実行時、`cc:完了` タスクが 1 件以上あれば自動的に振り返りを実行する。
`--no-retro` で明示的にスキップ可能。

### Step R1: 完了タスク収集

```bash
# Plans.md から cc:完了 / pm:確認済 のタスクを抽出
grep -E 'cc:完了|pm:確認済' Plans.md

# 直近の完了コミット履歴
git log --oneline --since="7 days ago"

# 変更規模
git diff --stat HEAD~10
```

### Step R2: 振り返り 4 項目

| 項目 | 分析方法 |
|------|---------|
| **見積もり精度** | Plans.md のタスク記述から想定ファイル数を推論 → `git diff --stat` の実変更ファイル数と比較 |
| **ブロック原因** | `blocked` マーカーが付いたタスクの理由パターンを集計（技術的/外部依存/仕様不明確） |
| **品質マーカー的中率** | `[feature:security]` 等を付けたタスクで実際に関連問題が出たか |
| **スコープ変動** | Plans.md の初回コミット時のタスク数 vs 現在のタスク数（追加/削除件数） |

### Step R3: 振り返りサマリー出力

```markdown
## 振り返りサマリー

**期間**: {{start_date}} 〜 {{end_date}}

| 指標 | 値 |
|------|-----|
| 完了タスク | {{count}} 件 |
| ブロック発生 | {{blocked_count}} 件 |
| スコープ変動 | +{{added}} / -{{removed}} 件 |
| 見積もり精度 | 想定 {{est}} ファイル → 実際 {{actual}} ファイル |

### 学び
- {{1-2 行の学び}}

### 次に活かすこと
- {{1-2 行の改善アクション}}
```

### Step R4: harness-mem への記録

振り返り結果を harness-mem に記録し、次回の `create` 時に参照できるようにする。
記録先: `.claude/agent-memory/` 配下の該当エージェントメモリ。
