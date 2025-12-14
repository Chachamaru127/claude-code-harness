---
description: Plans.mdのタスクを実行（Solo/2-Agent両対応、状況を自動判断）
---

# /work - 計画の実行

Plans.md の計画を実行し、実際のコードを生成します。
**Solo / 2-Agent 両方に対応**し、Plans.md のマーカーから状況を自動判断します。

## バイブコーダー向け（こう言えばOK）

- 「**Plans.md のタスクを進めて**」→ このコマンド
- 「**まず動くところまで作って**」→ 最小の動作確認までを先に通します
- 「**テストも付けて**」→ 重要箇所からテストを追加していきます
- 「**途中から再開したい**」→ 進行中（cc:WIP）や依頼中（pm:依頼中）を拾って再開

## できること（成果物）

- Plans.md のタスクを順に実装し、動作確認まで到達させる
- 途中で詰まったら原因切り分け→修正→再検証まで回す
- **2-Agent の場合**: pm:依頼中 のタスクを優先的に処理

---

## 自動判断ロジック

Plans.md のマーカーを確認し、適切なモードで動作：

| 検出マーカー | 動作モード |
|-------------|-----------|
| `pm:依頼中` / `cursor:依頼中` あり | 2-Agent（PM からの依頼を優先処理） |
| `cc:TODO` / `cc:WIP` のみ | Solo（自律実行） |

**優先度**: `pm:依頼中` > `cc:WIP`（継続） > `cc:TODO`（新規）

---

## 使用するスキル

このコマンドは以下のスキルを活用します：

- `ccp-work-impl-feature` - 機能実装
- `ccp-work-write-tests` - テスト作成
- `ccp-verify-build` - ビルド検証
- `ccp-error-recovery` - エラー復旧

---

## このコマンドの目的

**Plan → Work → Review** サイクルの「Work」フェーズ。
計画されたタスクを一つずつ実行し、動くコードを生成します。

**💡 長時間タスクの場合**:
実装に時間がかかる場合、`Ctrl+B`でバックグラウンドに送ることで、その間に他の作業を進められます。詳細は[非同期サブエージェントガイド](../docs/ASYNC_SUBAGENTS.md)を参照してください。

---

## 実行フロー

### Step 1: Plans.md の確認

```bash
cat Plans.md
```

現在の `cc:TODO` または `cc:WIP` タスクを特定。

### Step 2: 実行対象の確認

> 🔧 **実行するタスク**
>
> **フェーズ**: {{現在のフェーズ}}
> **タスク**: {{実行するタスク一覧}}
>
> これらを実行しますか？ (y / 特定のタスクを指定 / 全部)

**回答を待つ**（「y」または無言なら続行）

### Step 3: TodoWrite でタスク登録

TodoWrite ツールを使用して、各タスクを登録：

```
例:
- プロジェクト初期化 (in_progress)
- 基本構造の作成 (pending)
- 開発環境セットアップ (pending)
```

### Step 4: タスクの実行

各タスクを順番に実行。**実際のコマンドを実行し、ファイルを生成**。

#### プロジェクト初期化の例:

```bash
# Next.js プロジェクト作成
npx create-next-app@latest {{PROJECT_NAME}} --typescript --tailwind --eslint --app --src-dir --import-alias "@/*"

cd {{PROJECT_NAME}}

# 追加パッケージのインストール
npm install @supabase/supabase-js lucide-react
```

#### ディレクトリ構造の作成例:

```bash
mkdir -p src/components/{ui,layout,features}
mkdir -p src/lib
mkdir -p src/hooks
mkdir -p src/types
```

#### 基本ファイルの生成例:

```typescript
// src/lib/supabase.ts
import { createClient } from '@supabase/supabase-js'

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!
const supabaseKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!

export const supabase = createClient(supabaseUrl, supabaseKey)
```

### Step 5: 各タスク完了時

1. TodoWrite でタスクを `completed` に更新
2. Plans.md のマーカーを更新
3. 次のタスクに進む

```markdown
# Plans.md 更新例
- [x] プロジェクト初期化 `cc:完了`
- [ ] 基本構造の作成 `cc:WIP`
```

### Step 6: フェーズ完了時の報告

> ✅ **フェーズ1 完了！**
>
> **完了したタスク:**
> - ✅ プロジェクト初期化
> - ✅ 基本構造の作成
> - ✅ 開発環境セットアップ
>
> **生成されたファイル:**
> - `src/lib/supabase.ts`
> - `src/components/layout/Header.tsx`
> - ...
>
> **次にやること:**
> 「フェーズ2を始めて」または「動作確認して」と言ってください。

---

## 実行パターン集

### パターン1: Next.js プロジェクト

```bash
npx create-next-app@latest {{name}} --typescript --tailwind --eslint --app
cd {{name}}
npm install @supabase/supabase-js lucide-react date-fns
```

### パターン2: Vite + React

```bash
npm create vite@latest {{name}} -- --template react-ts
cd {{name}}
npm install
npm install -D tailwindcss postcss autoprefixer
npx tailwindcss init -p
```

### パターン3: FastAPI バックエンド

```bash
mkdir {{name}} && cd {{name}}
python -m venv .venv
source .venv/bin/activate
pip install fastapi uvicorn sqlalchemy alembic
```

---

## 重要な原則

### 1. 実際にコードを生成する

❌ 悪い例: 「ファイルを作成してください」
✅ 良い例: 実際に `Write` ツールでファイルを作成

### 2. 動作確認を含める

各フェーズ終了時:
```bash
npm run dev  # 開発サーバー起動
npm run build  # ビルド確認
```

### 3. コミットを作成

意味のある単位でコミット:
```bash
git add -A
git commit -m "feat: フェーズ1完了 - プロジェクト基盤構築"
```

### 4. エラー時の対応

エラーが発生したら:
1. エラー内容を分析
2. 修正を試行（最大3回）
3. 解決しない場合は状況を報告

---

## VibeCoder 向けヒント

セッション中いつでも使えるフレーズ:

| 言いたいこと | 言い方 |
|-------------|--------|
| 進捗を知りたい | 「今どこまで進んだ？」 |
| 動作確認したい | 「動かしてみて」 |
| 次に進みたい | 「次のタスク」 |
| 全部任せたい | 「全部やって」 |
| 困った | 「どうすればいい？」 |

---

## ⚡ 並列実行の判断ポイント

Plans.md に複数のタスクがある場合、**並列実行するかどうか**を以下の基準で判断します。

### 並列実行すべき場合 ✅

| 条件 | 理由 |
|------|------|
| 独立したコンポーネント作成（3つ以上） | 互いに依存しない |
| 複数ページの作成 | ページ間の依存が少ない |
| テスト + Lint + 型チェック | 並列実行で時間短縮 |

**例: 並列実行可能なタスク**
```markdown
## フェーズ2: UI実装 `cc:WIP`
- [ ] Header コンポーネント作成 `cc:TODO` ← 独立
- [ ] Footer コンポーネント作成 `cc:TODO` ← 独立
- [ ] Sidebar コンポーネント作成 `cc:TODO` ← 独立

→ 3タスクとも独立 → 並列実行で時間短縮 ✅
```

### 直列実行すべき場合 ⚠️

| 条件 | 理由 |
|------|------|
| 依存関係がある（A の出力が B の入力） | 順序が重要 |
| 同じファイルを編集 | コンフリクト回避 |
| 確認しながら進めたい | 対話的な作業 |

**例: 直列実行が必要なタスク**
```markdown
## フェーズ1: 基盤構築 `cc:WIP`
- [ ] Supabase クライアント設定 `cc:TODO` ← まず必要
- [ ] 認証コンポーネント作成 `cc:TODO` ← Supabase に依存
- [ ] ユーザーページ作成 `cc:TODO` ← 認証に依存

→ 依存関係あり → 直列実行 ⚠️
```

### 自動判断ロジック

```
Plans.md から cc:TODO タスクを抽出
↓
依存関係を分析（import/ファイル参照）
↓
独立タスク >= 3 かつ 依存関係なし → 並列実行提案
依存関係あり または タスク < 3 → 直列実行
```

### 並列実行の明示的な指示

```
「Header, Footer, Sidebar を並列で作って」
→ 並列実行を明示的に指示

「順番に一つずつ作って」
→ 直列実行を明示的に指示
```
