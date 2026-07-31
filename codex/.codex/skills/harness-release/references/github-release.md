# GitHub Release Notes Rules

Formatting rules applied when creating GitHub Release notes.

## Required Format

### Structure

```markdown
## What's Changed

**One-line description of the change's value**

### Before / After

| Before | After |
|--------|-------|
| Previous state | New state |
| ... | ... |

---

## Added

- **Feature name**: Description
  - Detail 1
  - Detail 2

## Changed

- **Change**: Description

## Fixed

- **Fix**: Description

## Requirements (if applicable)

- **Claude Code vX.X.X+** (recommended)
- Link: [Documentation](URL)

---

Generated with [Claude Code](https://claude.com/claude-code)
```

### Required Elements

| Element | Required | Description |
|---------|----------|-------------|
| `## What's Changed` | Yes | Section heading |
| **Bold summary** | Yes | One-line value description |
| `Before / After` table | Yes | User-facing changes |
| `Added/Changed/Fixed` | When applicable | Detailed changes |
| Footer | Yes | `Generated with [Claude Code](...)` |

### Language

- **GitHub Release**: English required（公開リポジトリのため）
- **CHANGELOG.md**: **日本語**で詳細な Before/After 形式（後述）
- Keep descriptions user-focused

## CHANGELOG フォーマット（日本語・詳細 Before/After）

CHANGELOG は各機能を「今まで → 今後」形式で具体的に記述する:

```markdown
## [X.Y.Z] - YYYY-MM-DD

### テーマ: [変更全体を一言で]

**[ユーザーにとっての価値を1〜2文で]**

---

#### 1. [機能名]

**今まで**: [旧動作。ユーザーが体験していた不便を具体的に描写]

**今後**: [新動作。何が解決するか + 具体例]

```出力例やコマンド例```

#### 2. [次の機能名]

**今まで**: ...
**今後**: ...
```

**書き方ルール**:
- 各機能を `#### N. 機能名` で独立セクションにする
- 「今まで」は**課題描写**（「〜する必要がありました」形式）
- 「今後」は**解決の具体像**（コマンド例・出力例を含める）
- 長くてOK。読みやすさが最優先
- テクニカル詳細（ファイル名、ステップ番号）は「今後」の補足として最小限に

## Prohibited

- No skipping the Before / After (CHANGELOG) or Before / After table (GitHub Release)
- No skipping the footer (GitHub Release)
- No technical-only descriptions (user perspective required)
- No bare change lists without value explanation

## Good Example (GitHub Release — English)

```markdown
## What's Changed

**`/work --full` now automates implement -> self-review -> improve -> commit in parallel**

### Before / After

| Before | After |
|--------|-------|
| `/work` executes tasks one at a time | `/work --full --parallel 3` runs in parallel |
| Reviews required separate manual step | Each task-worker self-reviews autonomously |
```

## Good Example (CHANGELOG — Japanese)

```markdown
#### 1. 失敗タスクの自動再チケット化

**今まで**: テスト/CI が失敗すると3回リトライして止まるだけでした。
止まった後は「何が原因だったか」を自分で調べ、Plans.md に手動で修正タスクを追加する必要がありました。

**今後**: 3回失敗で止まるとき、Harness が失敗原因を分類し、修正タスク案を自動生成します。
承認すると Plans.md に `.fix` タスクとして自動追加されます。
```

## Bad Example

```markdown
## What's New

### Added
- Added task-worker.md
- Added --full option
```

-> Doesn't communicate user value

## マージ方式（merge commit 固定 / squash 不採用）

release PR および main へ取り込む PR は **merge commit** (`gh pr merge --merge` /
`git merge --no-ff`) を使う。squash / rebase は不採用（Phase 114 preamble 裁定 2026-07-14）。

**なぜ**: Plans.md は task の Status 列に commit hash を台帳として埋めている
（例: 113.1 `cc:done [fa2b9c37]`）。squash はこれらの hash を main の ancestry から
外し、台帳と履歴の突合（`scripts/ci/check-branch-alignment-ledger.sh`、AR-16）を
破壊する。squash は技術的には可能（3 方式許可 + binary は `-buildvcs=false` で
SHA 非依存）だが、hash 台帳が Plans.md に存在する限り採用しない。

- 機械 gate: merge 前に `bash scripts/ci/check-branch-alignment-ledger.sh` exit 0 を確認する
- 先例: v5.0.0 の #235 / #236 も merge commit
- 見直し条件: Plans.md が hash 台帳方式をやめた時のみ再検討する

## Release evidence の保存（v5.1.0 監査指摘の codify）

upgrade smoke（旧 version → 新 version の実測）や release gate の実行ログは、
宣言だけでなく **artifact として `.claude/state/release-evidence/<version>/` に保存**する。
Plans.md の cc:done マーカーが「実測した」と主張する項目には、対応するログファイルか
コマンド出力の記録が存在しなければならない（SA-13 completeness 監査 2026-07-16 の指摘）。

## Release Creation Command

```bash
gh release create vX.X.X \
  --title "vX.X.X - Title" \
  --notes "$(cat <<'EOF'
## What's Changed
...
EOF
)"
```

## Editing Past Releases

```bash
gh release edit vX.X.X --notes "$(cat <<'EOF'
...
EOF
)"
```

## CC バージョン統合時の CHANGELOG パターン

Claude Code の新バージョン統合を含むリリースでは、通常の「今まで / 今後」形式ではなく、
**「CC のアプデ → Harness での活用」形式**を使用する。
上流（CC）の変更理由から説明することで、読者が「なぜこの変更が自分に関係あるか」を文脈から理解できる。

### 判定条件

以下のいずれかに該当する場合、このパターンを適用する:

- Feature Table のバージョン表記が更新されている
- hooks.json に CC 由来の新イベントが追加されている
- skills に CC 新機能の活用ガイドが追記されている

### 構造

```markdown
#### N. Claude Code X.Y.Z 統合

（1 行で全体概要）

##### N-1. 機能名

**CC のアプデ**: Claude Code で何が変わったか。ユーザー視点で、その機能が何をするものか分かるように説明。

**Harness での活用**: その変更を Harness がどう活かしているか。具体的な仕組み（スクリプト名、フロー）を含める。

##### N-2. 次の機能名

**CC のアプデ**: ...
**Harness での活用**: ...
```

### 書き方ルール

- 機能ごとに `##### N-X.` で独立セクションにする
- 「CC のアプデ」はファイル変更ではなく**ユーザー体験の変化**を書く
- 「Harness での活用」は**具体的な仕組み**（何が動くか、何が防がれるか）を書く
- ファイル名の羅列は避ける。「hooks.json を更新」ではなく「Worker のフリーズを防止」のように書く
- ドキュメントのみの変更（Feature Table 更新、詳細セクション追加）は個別エントリにせず、冒頭の概要 1 行に含める

### Good Example

```markdown
##### 5-1. MCP Elicitation への自動対応

**CC のアプデ**: MCP サーバーが、タスク実行中にユーザーへ「質問」できるようになった（Elicitation）。
例えば「どのリポジトリに push しますか？」のようなフォーム入力を求められる。

**Harness での活用**: Breezing の Worker はバックグラウンド実行のため質問フォームに応答できない。
放置すると Worker がフリーズする。elicitation-handler.sh を新規作成し、
Breezing セッション中は自動スキップ、通常セッションではそのまま通過してユーザーが回答する仕組みを実装。
```

### Bad Example

```markdown
#### CC 2.1.76 統合

- hooks.json に Elicitation を追加
- elicitation-handler.sh を作成
- CLAUDE.md を更新
```

→ ファイル変更の羅列で、なぜその変更が必要だったか、ユーザーにとって何が変わるかが伝わらない

## Reference

- Good examples: v2.8.0, v2.8.2, v2.9.1, v3.10.3 (CC統合パターン)
- Keep consistent with CHANGELOG
