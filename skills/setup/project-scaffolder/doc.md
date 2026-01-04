---
name: project-scaffolder
description: "プロジェクトの初期構造を生成するスキル。新規プロジェクトの初期構造を生成する場合に使用します。"
allowed-tools: ["Write", "Bash"]
metadata:
  skillport:
    category: core
    tags: [scaffold, project, init, structure]
    alwaysApply: false
---

# Project Scaffolder

プロジェクトの初期構造（ディレクトリ、設定ファイル、基本ファイル）を生成するスキル。

---

## 目的

ヒアリング結果と技術スタック提案に基づいて、プロジェクトの基本構造を自動生成する。

---

## 入力

| 項目 | 説明 |
|------|------|
| `project_type` | プロジェクトの種類（web, api, fullstack, etc.） |
| `tech_stack` | 選択された技術スタック |
| `project_name` | プロジェクト名 |
| `requirements` | ヒアリングで得られた要件 |

---

## 出力

| 項目 | 説明 |
|------|------|
| `created_files` | 生成されたファイルのリスト |
| `project_structure` | ディレクトリ構造の概要 |

---

## 生成するファイル

### 共通

- `package.json` または `pyproject.toml`（言語に応じて）
- `.gitignore`
- `README.md`

### Web フロントエンド

```
src/
├── components/
├── pages/ または app/
├── styles/
└── lib/
```

### API バックエンド

```
app/
├── api/
├── models/
├── services/
└── utils/
```

---

## 実行手順

1. **技術スタックに基づくテンプレート選択**
   - Next.js, React, Vue, Svelte などフレームワーク判定
   - Python, Node.js, Go など言語判定

2. **ディレクトリ構造の生成**
   - 必要なディレクトリを作成
   - プレースホルダーファイルを配置

3. **設定ファイルの生成**
   - package.json / pyproject.toml
   - tsconfig.json / eslint.config.js など
   - .env.example

4. **初期ファイルの生成**
   - エントリーポイント（index.ts, main.py など）
   - 基本コンポーネント

---

## 注意事項

- 既存ファイルがある場合は上書きしない（確認を求める）
- 生成後は `npm install` や `pip install` を自動実行しない（ユーザー確認後）
- 生成されたファイルの一覧をユーザーに提示する
