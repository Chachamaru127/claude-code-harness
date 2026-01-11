---
description: Codex MCP を使ったセカンドオピニオンレビュー
description-en: Second-opinion code review using Codex MCP
---

# /codex-review - Codex セカンドオピニオンレビュー

OpenAI Codex を使って、コードのセカンドオピニオンレビューを取得します。

---

## 🎯 こう言えばOK

- 「`/codex-review`」→ Codex にレビューを依頼
- 「Codex にも見てもらって」→ このコマンド
- 「別の AI の意見がほしい」→ このコマンド

---

## できること

- Claude のレビューに加えて、Codex からセカンドオピニオンを取得
- 複数 AI モデルの得意分野を活用（論理推論 vs 実装パターン知識）
- レビュー結果を統合して表示

---

## 🔧 自動呼び出しスキル（必須）

**このコマンドは以下のスキルを Skill ツールで明示的に呼び出すこと**：

| スキル | 用途 | 呼び出しタイミング |
|-------|------|------------------|
| `codex-review` | Codex 統合（親スキル） | コマンド開始時 |

**呼び出し方法**:
```
Skill ツールを使用:
  skill: "claude-code-harness:codex-review"
```

---

## 前提条件

### 1. Codex CLI がインストール済み

```bash
which codex  # パスが表示されること
```

### 2. Codex にログイン済み

```bash
codex login status  # 認証済みであること
```

### 3. MCP サーバーとして登録済み

```bash
claude mcp list  # codex が表示されること
```

**未設定の場合**:
```bash
claude mcp add --scope user codex -- codex mcp-server
```

---

## 実行フロー

### Step 1: Codex 環境確認 & バージョンチェック

```bash
# Codex が利用可能か確認
which codex && codex login status

# バージョン確認
codex --version
npm show @openai/codex version  # 最新バージョン
```

**未設定の場合**:
```markdown
⚠️ Codex が設定されていません

セットアップ方法:
1. Codex CLI をインストール
2. `codex login` で認証
3. `claude mcp add --scope user codex -- codex mcp-server` で登録

詳細: `skills/codex-review/references/codex-mcp-setup.md`
```

**バージョンが古い場合**:
```markdown
⚠️ Codex CLI が古いバージョンです

インストール済み: X.X.X
最新バージョン: Y.Y.Y

アップデートしますか？ (y/n)

→ 承認された場合:
npm update -g @openai/codex
```

### Step 2: 変更ファイルの特定

```bash
git diff --name-only HEAD~1 2>/dev/null || git status --short
```

### Step 3: Codex レビュー実行

MCP 経由で Codex にレビューを依頼:

```
📊 Codex レビュー開始...

モデル: gpt-5.2-codex（設定ファイルで変更可能）
対象ファイル: {changed_files}
プロンプト: 日本語でコードレビューを行い、問題点と改善提案を出力してください
```

**モデル設定**:
```yaml
# .claude-code-harness.config.yaml
review:
  codex:
    model: gpt-5.2-codex  # 推奨（最上位モデル）
    # model: gpt-5.1-codex
    # model: gpt-5-codex-mini  # 低コスト版
```

### Step 4: Claude による検証

**Codex の指摘を Claude が検証し、修正が必要かどうかを判断します。**

```markdown
## 🤖 Codex レビュー結果（Claude 検証済み）

### 問題点

| ファイル | 行 | 重要度 | 内容 | Claude 検証 |
|---------|-----|--------|------|------------|
| src/api/users.ts | 45 | 高 | SQL インジェクションの可能性 | ✅ 妥当 |
| src/utils/calc.ts | 12 | 中 | 計算精度の問題 | ⚠️ 要確認 |

### 改善提案（検証済み）

1. パラメータ化クエリの使用を推奨 → **修正推奨**
2. 入力バリデーションの追加 → **修正推奨**
```

### Step 5: 修正提案と承認

```markdown
## 🔧 修正が必要な項目

以下の修正を Plans.md に追加して `/work` で実行しますか？

| # | 修正内容 | ファイル | 優先度 |
|---|---------|----------|--------|
| 1 | SQL インジェクション対策 | src/api/users.ts:45 | 高 |
| 2 | 入力バリデーション追加 | src/api/users.ts | 中 |

**選択肢:**
1. すべて承認 → Plans.md に追加して `/work` 実行
2. 選択して承認 → 番号を指定（例: 1）
3. 今は修正しない → レポートのみ
```

### Step 6: Plans.md 反映と実行（承認時）

```
ユーザー承認
    ↓
Plans.md に修正タスクを追加:
  - [ ] [bugfix] SQL インジェクション対策（src/api/users.ts:45）
  - [ ] [feature] 入力バリデーション追加
    ↓
/work を実行（または実行を提案）
    ↓
修正完了
```

---

## オプション

```
/codex-review              # 全変更ファイルをレビュー
/codex-review src/         # 特定ディレクトリのみ
/codex-review --security   # セキュリティ観点に特化
```

---

## /harness-review との違い

| コマンド | 内容 |
|---------|------|
| `/harness-review` | Claude によるフルレビュー（+ Codex オプション） |
| `/codex-review` | Codex 単独のレビュー |

**推奨**: 通常は `/harness-review` を使用し、追加でセカンドオピニオンが必要な場合に `/codex-review` を使用

---

## 関連コマンド

- `/harness-review` - フルレビュー（Claude + オプションで Codex）
- `/harness-init` - プロジェクト初期化（Codex 設定含む）
