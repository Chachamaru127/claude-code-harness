---
name: cc-update-review
description: "Quality guardrail for CC update integration. Detects doc-only Feature Table additions and requires implementation proposals. Internal use only."
description-en: "Quality guardrail for CC update integration. Detects doc-only Feature Table additions and requires implementation proposals. Internal use only."
description-ja: "Quality guardrail for CC update integration. Detects doc-only Feature Table additions and requires implementation proposals. Internal use only."
user-invocable: false
allowed-tools: ["Read", "Grep", "Glob"]
---

# CC Update Review ガードレール

Claude Code のアップデート統合時に「Feature Table に書いただけ」を防止する品質ガードレール。
Feature Table への追加が実装を伴っているかを自動分類し、不足があれば実装案を強制出力する。

## Quick Reference

以下の状況でこのスキルがトリガーされる:

- **CC アップデート統合 PR** のレビュー時
- **Feature Table**（`CLAUDE.md` / `docs/CLAUDE-feature-table.md`）に新行が追加された diff を検出した時
- `/harness-review` が CC 統合 PR と判定した場合の内部呼び出し

トリガー **しない** 状況:

- 通常の実装作業（`/work`）
- Feature Table 以外のみの変更
- セットアップ・初期化作業

## 3 カテゴリ分類

Feature Table に追加された各項目を、以下の 3 カテゴリに分類する。

### (A) 実装あり

**定義**: Feature Table の追加に対応する hooks / scripts / agents / skills / core の実装変更が同じ PR に含まれている。

**判定条件**:
- Feature Table の行で言及されている機能に関連するファイルが変更されている
- hooks.json、スキル SKILL.md、エージェント .md、scripts/*.sh、core/src/*.ts のいずれかに diff がある

**例**:

| Feature Table 追加 | 対応する実装変更 | 判定 |
|-------------------|----------------|------|
| `PostCompact フック` | `hooks/post-compact-handler.sh` 新規作成 | A |
| `MCP Elicitation 対応` | `hooks.json` に Elicitation イベント追加 + `elicitation-handler.sh` 作成 | A |
| `Worker maxTurns 制限` | `agents-v3/worker.md` に maxTurns フィールド追加 | A |

**結果**: OK。追加のアクション不要。

---

### (B) 書いただけ

**定義**: Feature Table にのみ行が追加され、Harness 側の実装変更が一切含まれていない。かつ、CC 自動継承（カテゴリ C）にも該当しない。

**判定条件**:
- Feature Table に新行がある
- 同じ PR 内で hooks / scripts / agents / skills / core に関連する変更がない
- Harness が独自の付加価値を提供すべき機能である（設定、ワークフロー統合、ガードレール等）

**例**:

| Feature Table 追加 | 対応する実装変更 | 判定 |
|-------------------|----------------|------|
| `PreCompact フック` | なし（Feature Table のみ） | B |
| `Agent Teams` | なし（Feature Table のみ） | B |
| `Desktop Scheduled Tasks` | なし（Feature Table のみ） | B |

**結果**: NG。PR をブロックし、実装案の提示を要求する。出力フォーマットは後述。

---

### (C) CC 自動継承

**定義**: Claude Code 本体のパフォーマンス改善・バグ修正・内部最適化等で、Harness 側の変更が不要な項目。

**判定条件**:
- CC 本体の修正であり、Harness がラップ・拡張する余地がない
- パフォーマンス改善、メモリリーク修正、UI 改善等
- Harness のワークフローに影響を与えない内部変更

**例**:

| Feature Table 追加 | 理由 | 判定 |
|-------------------|------|------|
| `Streaming API memory leak fix` | CC 内部のメモリリーク修正。Harness 側の対応不要 | C |
| `Compaction image retention` | CC がコンパクション時に画像を保持。Harness の変更不要 | C |
| `Parallel tool call fix` | CC 内部の並列実行修正。自動的に恩恵を受ける | C |

**結果**: OK。ただし Feature Table のカラムに「CC 自動継承」と明記すること。

## CC アップデート PR チェックリスト

PR レビュー時に以下を順番に確認する:

```
## CC アップデート統合チェックリスト

### 1. Feature Table 差分の抽出
- [ ] `CLAUDE.md` または `docs/CLAUDE-feature-table.md` の diff から追加行を列挙

### 2. 各項目の分類
- [ ] 追加された各行について A / B / C を判定
- [ ] カテゴリ B の項目が 0 件であることを確認

### 3. カテゴリ別の確認
- [ ] (A) 実装あり: 対応する実装ファイルが正しくリンクされているか
- [ ] (B) 書いただけ: 実装案が提示されているか（0 件でなければ PR ブロック）
- [ ] (C) CC 自動継承: Feature Table に「CC 自動継承」の明記があるか

### 4. CHANGELOG 確認
- [ ] カテゴリ A の項目が CHANGELOG に「今まで / 今後」形式で記載されているか
- [ ] カテゴリ C の項目が CHANGELOG で CC 自動継承として記載されているか

### 分類結果

| # | Feature Table 項目 | カテゴリ | 対応ファイル / 備考 |
|---|-------------------|---------|-------------------|
| 1 | （項目名） | A / B / C | （ファイルパスまたは備考） |
| 2 | （項目名） | A / B / C | （ファイルパスまたは備考） |
```

## カテゴリ B 検出時の出力フォーマット

カテゴリ B が 1 件以上検出された場合、以下のフォーマットで実装案を出力する。
**このフォーマットの出力は必須であり、省略は許可されない。**

```
## カテゴリ B 検出: 実装案

### B-{番号}. {Feature Table の項目名}

**現状**: Feature Table に記載のみ。Harness 側の実装なし。

**Harness ならではの付加価値**:
{この機能を Harness がどう活用すべきかの具体的な説明}

**実装案**:

| 対象ファイル | 変更内容 |
|------------|---------|
| `{ファイルパス}` | {具体的な変更内容} |
| `{ファイルパス}` | {具体的な変更内容} |

**ユーザー体験の改善**:
- 今まで: {現在のユーザー体験}
- 今後: {実装後のユーザー体験}

**実装の優先度**: {高 / 中 / 低}
**推定工数**: {小 / 中 / 大}
```

### 出力例

```
## カテゴリ B 検出: 実装案

### B-1. Desktop Scheduled Tasks

**現状**: Feature Table に記載のみ。Harness 側の実装なし。

**Harness ならではの付加価値**:
Scheduled Tasks を Harness のワークフローと統合し、定期的な品質チェック・
ステータス同期・メモリ整理を自動化できる。

**実装案**:

| 対象ファイル | 変更内容 |
|------------|---------|
| `skills/harness-work/references/scheduled-tasks.md` | スケジュールタスクのテンプレートとガイド |
| `scripts/setup-scheduled-tasks.sh` | 初期セットアップスクリプト |
| `hooks/hooks.json` | Cron トリガーの登録 |

**ユーザー体験の改善**:
- 今まで: ユーザーが手動で定期タスクを実行する必要があった
- 今後: Harness が自動的に定期品質チェックを実行し、結果を通知する

**実装の優先度**: 中
**推定工数**: 中
```

## 「付加価値」列の推奨

Feature Table に以下のカラムを追加することを推奨する:

| Feature | Skill | Purpose | 付加価値 |
|---------|-------|---------|---------|
| PostCompact フック | hooks | コンテキスト再注入 | A: 実装あり |
| Streaming leak fix | all | メモリリーク修正 | C: CC 自動継承 |

この列により、各項目の分類が一目で確認でき、カテゴリ B の残存を防止できる。

## 関連スキル

- `harness-review` - コードレビュー（CC 統合 PR 判定時にこのスキルを内部呼び出し）
- `harness-work` - 実装作業（カテゴリ B の実装案に基づく作業時）
- `memory` - SSOT 管理（分類基準の決定記録）
