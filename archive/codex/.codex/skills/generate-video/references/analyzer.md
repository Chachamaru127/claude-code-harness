# Video Analyzer - コードベース分析エンジン

プロジェクトを自動分析し、動画生成に必要な情報を抽出します。

---

## 概要

`/generate-video` の Step 1 で実行される分析エンジンです。
コードベースとプロジェクト資産を解析し、最適な動画構成を判定します。

## 分析項目

### 1. フレームワーク検出

| 検出対象 | 判定方法 |
|---------|---------|
| Next.js | `next.config.*` の存在 |
| React | `package.json` の dependencies |
| Vue | `vue.config.*` または `nuxt.config.*` |
| Svelte | `svelte.config.*` |
| Express/Fastify | `package.json` の dependencies |

**実行コマンド**:
```bash
# package.json から依存関係を抽出
cat package.json | jq '.dependencies, .devDependencies'

# 設定ファイルの存在確認
ls -la *.config.* 2>/dev/null
```

### 2. 主要機能検出

| 機能 | 検出パターン |
|------|-------------|
| 認証 | `auth/`, `login/`, `@clerk`, `@auth0`, `supabase` |
| 決済 | `payment/`, `billing/`, `stripe`, `@stripe` |
| ダッシュボード | `dashboard/`, `admin/`, `analytics` |
| API | `api/`, `routes/`, `trpc`, `graphql` |
| DB | `prisma/`, `drizzle/`, `@supabase` |

**実行コマンド**:
```bash
# ディレクトリ構造から機能を推測
find src app -type d -name "auth" -o -name "login" -o -name "dashboard" 2>/dev/null

# パッケージから機能を推測
grep -E "clerk|stripe|supabase|prisma" package.json
```

### 3. UIコンポーネント検出

| 項目 | 検出方法 |
|------|---------|
| ページ数 | `app/**/page.tsx` または `pages/**/*.tsx` のカウント |
| コンポーネント数 | `components/**/*.tsx` のカウント |
| UIライブラリ | `shadcn`, `radix`, `chakra`, `mui` の検出 |

**実行コマンド**:
```bash
# ページ数カウント
find . -name "page.tsx" -o -name "page.jsx" 2>/dev/null | wc -l

# コンポーネント数カウント
find . -path "*/components/*" -name "*.tsx" 2>/dev/null | wc -l
```

### 4. プロジェクト資産解析

| 資産 | 用途 |
|------|------|
| `package.json` | プロジェクト名、description |
| `README.md` | プロジェクト概要、タグライン |
| `Plans.md` | 完了タスク（リリースノート用） |
| `CHANGELOG.md` | 変更点（リリースノート用） |
| `.claude/memory/decisions.md` | 技術的意思決定（アーキテクチャ解説用） |

**実行コマンド**:
```bash
# プロジェクト情報抽出
cat package.json | jq '{name, description, version}'

# README の最初の段落を抽出
head -20 README.md
```

---

## 動画タイプ自動判定

### 判定ロジック

```
分析結果から動画タイプを判定:
    │
    ├─ CHANGELOG が最近更新（7日以内）
    │   └─ → リリースノート動画
    │
    ├─ 大きな構造変更（新ディレクトリ追加等）
    │   └─ → アーキテクチャ解説
    │
    ├─ UI変更が多い（コンポーネント追加/変更）
    │   └─ → プロダクトデモ
    │
    └─ 複数条件に該当
        └─ → 複合動画（ユーザーに確認）
```

### 判定基準

| タイプ | 条件 |
|--------|------|
| **リリースノート** | `git log --since="7 days ago"` に tag/release がある |
| **アーキテクチャ** | 新しい `src/*/` ディレクトリ、大きなリファクタ |
| **プロダクトデモ** | UI コンポーネントの追加/変更 |
| **デフォルト** | プロダクトデモ（最も汎用的） |

---

## 出力フォーマット

分析結果は以下の形式で出力:

```yaml
project:
  name: "MyAwesomeApp"
  description: "タスク管理を簡単に"
  version: "1.2.0"

framework:
  primary: "Next.js"
  ui_library: "shadcn/ui"

features:
  - name: "認証"
    type: "auth"
    path: "src/app/(auth)/"
    provider: "Clerk"
  - name: "ダッシュボード"
    type: "dashboard"
    path: "src/app/dashboard/"
  - name: "API"
    type: "api"
    path: "src/app/api/"

stats:
  pages: 12
  components: 45
  api_routes: 8

recent_changes:
  changelog_updated: true
  last_release: "2026-01-20"
  major_changes:
    - "認証フロー追加"
    - "ダッシュボード改善"

recommended_video_type: "release-notes"
confidence: 0.85
```

---

## 実行例

```
📊 プロジェクト分析中...

✅ 分析完了

| 項目 | 結果 |
|------|------|
| プロジェクト名 | MyAwesomeApp |
| フレームワーク | Next.js 14 |
| UIライブラリ | shadcn/ui |
| ページ数 | 12 |
| コンポーネント数 | 45 |

🔍 検出された機能:
- 認証（Clerk）
- ダッシュボード
- API（8エンドポイント）

📋 最近の変更:
- v1.2.0 リリース（3日前）
- 認証フロー追加
- ダッシュボード改善

🎬 推奨動画タイプ: リリースノート動画
   理由: 最近のリリースがあり、主要な機能追加があります
```

---

## Notes

- 分析は非破壊的（ファイルを変更しない）
- 大規模プロジェクトでも数秒で完了
- 検出できない機能は手動で追加可能（planner.md で）
