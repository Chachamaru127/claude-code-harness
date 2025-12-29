# Command File Editing Rules

コマンドファイル（`commands/core/` および `commands/optional/`）を編集する際の SSOT（Single Source of Truth）ルール。

## SSOT 原則

### 1. YAML Frontmatter フォーマット（必須）

**すべてのコマンドファイルは統一された YAML frontmatter を使用する**：

```yaml
---
description: 日本語での簡潔な説明
description-en: English brief description
---
```

**禁止事項**：
- ❌ `name:` フィールドの追加（ファイル名から自動決定される）
- ❌ 独自のカスタムフィールドの追加（description と description-en のみ）
- ❌ frontmatter の省略

**例外**：
- `harness-mem.md` のみ歴史的理由で frontmatter なし（将来的に統一予定）

### 2. ファイル命名規則

**コアコマンド** (`commands/core/`):
- `harness-` プレフィックスを推奨（例: `harness-init.md`, `harness-review.md`）
- プラグイン固有機能を示す命名

**オプショナルコマンド** (`commands/optional/`):
- **ハーネス統合系**: `harness-` プレフィックス（例: `harness-mem.md`, `harness-update.md`）
- **機能セットアップ系**: `{機能}-setup` パターン（例: `ci-setup.md`, `lsp-setup.md`）
- **操作系**: `{動作}-{対象}` パターン（例: `sync-status.md`, `sync-ssot-from-memory.md`）

### 3. 完全修飾名の生成

プラグインシステムは以下の形式で完全修飾名を生成：

```
{plugin-name}:{category}:{command-name}
```

**例**：
- `commands/core/harness-init.md` → `claude-code-harness:core:harness-init`
- `commands/optional/cursor-mem.md` → `claude-code-harness:optional:cursor-mem`
- `commands/optional/ci-setup.md` → `claude-code-harness:optional:ci-setup`

## コマンドファイル構造テンプレート

### 標準テンプレート

```markdown
---
description: 日本語での説明（1行、簡潔に）
description-en: English description (one line, concise)
---

# {Command Name}

コマンドの概要説明。

## こう言えばOK（オプション）

- 「{キーワード1}」→ このコマンド
- 「{キーワード2}」→ このコマンド

## できること（成果物）

- 成果物1の説明
- 成果物2の説明

## 使用方法

### 基本的な使い方

```bash
/{command-name}
```

### オプション付き実行

```bash
/{command-name} --option1
/{command-name} --option2
```

## オプション

| オプション | 説明 | デフォルト |
|-----------|------|-----------|
| `--option1` | オプション1の説明 | デフォルト値 |

## 実行内容

このコマンドは以下を実行します：

1. ステップ1
2. ステップ2
3. ステップ3

## 関連コマンド

- `/related-command1` - 関連コマンドの説明
- `/related-command2` - 関連コマンドの説明
```

## 編集チェックリスト

コマンドファイルを新規作成・編集する際のチェックリスト：

- [ ] YAML frontmatter が標準フォーマット（`description` + `description-en`）
- [ ] `name:` フィールドがない
- [ ] ファイル名が命名規則に準拠
- [ ] 完全修飾名が正しく生成される（`{plugin}:{category}:{name}`）
- [ ] 既存のコマンドと一貫性がある
- [ ] CHANGELOG.md にエントリを追加（新規コマンドの場合）
- [ ] VERSION をバンプ（自動または手動）

## 既知の例外

### harness-mem.md

**現状**：
```markdown
# /harness-mem - Claude-mem 統合セットアップ

Claude-mem をハーネス仕様にカスタマイズし...

---
```

**理由**：歴史的理由で frontmatter なし

**今後の対応**：将来的に標準フォーマットに統一予定

## 関連ドキュメント

- [CLAUDE.md](../../CLAUDE.md) - プロジェクト開発ガイド
- [.claude/memory/decisions.md](../memory/decisions.md) - アーキテクチャ決定記録
- [.claude/memory/patterns.md](../memory/patterns.md) - 再利用パターン
