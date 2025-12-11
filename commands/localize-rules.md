---
name: localize-rules
description: プロジェクト構造に合わせてルールをローカライズ
---

# /localize-rules

プロジェクトの構造を分析し、`.claude/rules/` のルールファイルをプロジェクトに最適化します。

---

## このコマンドの目的

ジェネリックなルールテンプレートを、実際のプロジェクト構造に合わせてカスタマイズします：

- **paths:** を実際のソースディレクトリに合わせる（`src/`, `app/`, `lib/` など）
- 言語固有のルールを追加（TypeScript, Python, React など）
- テストディレクトリを自動検出

---

## 実行手順（必須）

以下のスクリプトを実行してください：

```bash
~/.claude/plugins/marketplaces/cursor-cc-marketplace/scripts/localize-rules.sh
```

または dry-run で確認：

```bash
~/.claude/plugins/marketplaces/cursor-cc-marketplace/scripts/localize-rules.sh --dry-run
```

---

## 検出項目

### 言語・フレームワーク

| 検出ファイル | 言語/フレームワーク |
|-------------|---------------------|
| `package.json` + `tsconfig.json` | TypeScript |
| `package.json` + `react` | React |
| `package.json` + `next` | Next.js |
| `requirements.txt` / `pyproject.toml` | Python |
| `go.mod` | Go |
| `Cargo.toml` | Rust |
| `Gemfile` | Ruby |

### ソースディレクトリ

優先順位で検出：
1. `src/`, `app/`, `lib/`
2. `pages/`, `app/` (Next.js)
3. Python パッケージディレクトリ

### テストディレクトリ

- `tests/`, `test/`, `__tests__/`, `spec/`, `e2e/`
- Colocated tests (`*.test.ts`, `*.spec.js`)

---

## 出力例

### TypeScript + React プロジェクト

```markdown
---
paths: "src/**/*.{ts,tsx,js,jsx}"
---

# Coding Standards

## TypeScript 固有
- `any` は使用禁止
- 戻り値の型は明示する

## React 固有
- 関数コンポーネントを使用
- カスタムフックは `use` プレフィックス
```

### Python プロジェクト

```markdown
---
paths: "mypackage/**/*.py, src/**/*.py"
---

# Coding Standards

## Python 固有
- PEP 8 スタイルガイドに従う
- 型ヒントを使用する
```

---

## 注意事項

- 既存のカスタマイズは上書きされます
- バックアップを取ってから実行することを推奨
- `--dry-run` で事前確認が可能
