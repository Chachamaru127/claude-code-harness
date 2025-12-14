---
description: プロジェクトセットアップ（組み込み init との衝突回避）
---

# /harness-init - プロジェクトセットアップ

VibeCoder が自然言語だけで開発を始められるよう、プロジェクトをセットアップします。
**実際に動くコードまで生成**します。

## バイブコーダー向け（こう言えばOK）

- 「**新規プロジェクトを最速で立ち上げたい**」→ このコマンド
- 「**Next.js + Supabase で**」のように希望があれば添える（未指定なら質問して決めます）
- 「**まず動くものを作って、後で整えたい**」→ まず動作する土台を作り、Plans.md で次の手を提示します

## できること（成果物）

- 実プロジェクト生成（例: create-next-app 等）＋初期セットアップ
- `Plans.md` / `AGENTS.md` / `.claude/` 等を整備して、Plan→Work→Review を回せる状態にする

---

## このコマンドの特徴

- 🎯 技術選択は設定に基づく（auto/ask/fixed モード）
- 🚀 実際のプロジェクトを生成（create-next-app 等を実行）
- 📋 Plans.md に具体的なタスクを自動追加
- 💡 「次に何を言えばいいか」を常に提示

---

## ⚠️ 最初に確認: モード選択（Phase 0）

**重要**: プロジェクト分析の前に、必ずこのステップを実行すること。

> 🤔 **どのモードで開発しますか？**
>
> **🅰️ Solo モード**（Claude Code だけで開発）
> - あなたが直接 Claude Code に話しかけて開発
> - シンプル・すぐ始められる
> - 個人プロジェクト向け
>
> **🅱️ 2-Agent モード**（Cursor + Claude Code で役割分担）
> - **Cursor (PM)** が計画・レビュー・本番デプロイ
> - **Claude Code (Worker)** が実装・テスト・stagingデプロイ
> - チーム開発・大規模プロジェクト向け
>
> A / B どちらですか？

**回答を待つ**

### 🅰️ Solo モード を選択した場合

→ そのまま Phase 1 へ進む

### 🅱️ 2-Agent モード を選択した場合

> ⚠️ **2-Agent モードでは、最初の相談相手は Cursor です。**
>
> ```
> 正しいフロー:
> 1. Cursor で「ブログを作りたい」と相談
> 2. Cursor がタスクを作成 → /handoff-to-claude
> 3. Claude Code で実装 → /handoff-to-cursor
> 4. Cursor でレビュー → 本番デプロイ
> ```
>
> **今すぐセットアップしますか？**
> - 「はい」→ 2-Agent 用のファイルを生成（/setup-cursor 相当）
> - 「いいえ」→ Solo モードで進める

**回答を待つ**

「はい」の場合:
→ `/setup-cursor` のフロー（Phase 2〜5）を実行
→ 完了後、「Cursor で『〇〇を作りたい』と相談してください」と案内

「いいえ」の場合:
→ そのまま Phase 1 へ進む（Solo モード）

---

## 設定の読み込み

実行前に `claude-code-harness.config.json` を確認：

```json
{
  "scaffolding": {
    "tech_choice_mode": "auto | ask | fixed",
    "base_stack": "next-supabase | rails-postgres | express-mongodb | ...",
    "allow_web_search": true
  }
}
```

**tech_choice_mode の動作**:

| モード | 動作 | 使用場面 |
|-------|------|---------|
| `auto` | AI が最適な技術を提案（デフォルト） | VibeCoder 向け |
| `ask` | 必ずユーザーに確認する | 複数選択肢がある場合 |
| `fixed` | base_stack で指定した技術を使用 | 社内標準がある場合 |

**設定がない場合のデフォルト**: `ask`（必ずユーザーに確認）

---

## 実行フロー

### Phase 1: プロジェクト分析

現在のディレクトリを分析：

```bash
ls -la 2>/dev/null | head -10
[ -d .git ] && echo "Git: Yes" || echo "Git: No"
[ -f package.json ] && cat package.json | head -5
[ -f AGENTS.md ] && echo "AGENTS.md: 既存"
```

**判定**:
- ファイルがほぼない → **新規プロジェクト** → Phase 2A
- コードが存在 → **既存プロジェクト** → Phase 2B

---

## Phase 2A: 新規プロジェクト（VibeCoder向け）

### Step 1: やりたいことをヒアリング

> 🎯 **どんなものを作りたいですか？**
>
> ざっくりで大丈夫です！例えば：
> - 「ブログ」「ポートフォリオ」「ECサイト」
> - 「タスク管理アプリ」「チャットアプリ」
> - 「社内ツール」「ダッシュボード」
>
> 思いついたまま教えてください 👇

**回答を待つ**

### Step 2: 2-3問で解像度を上げる

> 📋 **もう少し教えてください：**
>
> 1. **誰が使いますか？**（自分だけ / チーム / 一般公開）
> 2. **似てるサービスはありますか？**（例: Notion, Zenn, メルカリ）

**回答を待つ**

### Step 3: 技術スタックの決定（設定に基づく）

**tech_choice_mode に応じて動作が変わる**:

#### モード: `fixed`（社内標準がある場合）

```
claude-code-harness.config.json の base_stack を使用:
  - "next-supabase" → Next.js + Supabase + Tailwind
  - "rails-postgres" → Ruby on Rails + PostgreSQL
  - "express-mongodb" → Express.js + MongoDB
  - "django-postgres" → Django + PostgreSQL
  - "laravel-mysql" → Laravel + MySQL

ユーザーには確認せず、指定されたスタックで作成を進める。
```

#### モード: `ask`（デフォルト・推奨）

> 💡 **「{{やりたいこと}}」なら、こんな構成がおすすめです：**
>
> **🅰️ シンプル構成**（すぐ動かしたい）
> - Next.js + Tailwind CSS + Supabase
> - デプロイ: Vercel（無料）
> - 開発時間目安: 1-2日で基本形
>
> **🅱️ フル構成**（将来の拡張重視）
> - Next.js + FastAPI + PostgreSQL
> - より柔軟だが、設定が少し多い
>
> **🅲️ その他**（指定がある場合）
> - 「Rails で作りたい」「Python がいい」など
>
> どちらにしますか？（A / B / C / おまかせ）

**回答を待つ**

#### モード: `auto`（VibeCoder向け）

```
allow_web_search = true の場合:
  WebSearch で調査：
  "{{プロジェクトタイプ}} tech stack 2025 beginner friendly"
  "{{類似サービス}} architecture simple"

allow_web_search = false の場合:
  デフォルトのシンプル構成（Next.js + Supabase）を提案

ユーザーには「この構成で進めますね」と報告のみ。
```

### Step 4: 最低限の確認

> 📝 **最後に2つだけ：**
>
> 1. **プロジェクト名** は？（例: `my-blog`, `task-app`）
> 2. **日本語** / **英語** どちらメイン？

**回答を待つ**

### Step 5: プロジェクト生成（実際に実行）

**Task tool で project-scaffolder エージェントを呼び出し、実際にプロジェクトを生成**

```bash
# 例: Next.js の場合
npx create-next-app@latest {{PROJECT_NAME}} --typescript --tailwind --eslint --app --src-dir

cd {{PROJECT_NAME}}
npm install @supabase/supabase-js lucide-react
```

### Step 6: セーフティ設定（.claude/settings.json）生成/更新

**目的**: 破壊的操作や機密情報露出の事故を減らすため、プロジェクトの `.claude/settings.json` を整備します。

- 既存 `.claude/settings.json` がある場合は **非破壊でマージ**（既存の hooks/env 等は保持）
- `permissions.allow|ask|deny` は **追記 + 重複排除**
- `permissions.disableBypassPermissionsMode` は **必ず `"disable"`** にする（`--dangerously-skip-permissions` 抑止）

**実行**: `ccp-generate-claude-settings` スキルを実行して作成/更新すること。

### Step 7: ワークフローファイル生成

以下を生成（templates/ を使用）：

1. **AGENTS.md** - 開発フロー概要
2. **CLAUDE.md** - Claude Code 設定
3. **Plans.md** - タスク管理（**具体的なタスク付き**）

**Plans.md の例**:
```markdown
## 🔴 フェーズ1: 基盤構築 `cc:WIP`

- [x] プロジェクト初期化 `cc:完了`
- [ ] 環境変数の設定 `cc:TODO`
- [ ] 基本レイアウト作成 `cc:TODO`

## 🟡 フェーズ2: コア機能 `cc:TODO`

- [ ] ホームページ作成
- [ ] {{機能1}}
- [ ] {{機能2}}
```

### Step 8: 次のアクションを案内

> ✅ **プロジェクトを作成しました！**
>
> 📁 `{{PROJECT_NAME}}/` が生成されました
>
> **次にやること（言い方の例）：**
> - 「動かして」→ 開発サーバーを起動して確認
> - 「フェーズ1を続けて」→ 残りのタスクを実行
> - 「ホームページを作って」→ 具体的な機能を実装
>
> 💡 困ったら「どうすればいい？」と聞いてください

---

## Phase 2B: 既存プロジェクト

### Step 1: 構造分析

```bash
find . -name "*.ts" -o -name "*.tsx" -o -name "*.py" | head -20
cat package.json 2>/dev/null | head -10
```

### Step 2: 確認

> 🔍 **既存プロジェクトを検出しました**
>
> - 言語: {{検出された言語}}
> - フレームワーク: {{検出されたフレームワーク}}
>
> **Cursor-CC ワークフローを追加しますか？**
>
> **重要**: 既存プロジェクトでは、すでに `AGENTS.md` / `CLAUDE.md` / `Plans.md` が存在する場合があります。  
> その場合は「残す/入れ替える」ではなく、**既存内容を精査して、対話で引き継ぐ情報を決めた上で、新フォーマットへアップデート（マージ移行）**できます。
>
> どちらにしますか？
>
> - **A**: 追加のみ（不足ファイルだけ作成。既存ファイルは触らない）
> - **B**: 新フォーマットへ移行（既存内容を引き継ぎつつアップデート。バックアップ付き・対話あり）【推奨】

**回答を待つ**

### Step 3A: 追加のみ（A を選択）

- AGENTS.md（なければ作成）
- CLAUDE.md（なければ作成）
- Plans.md（なければ作成）
- `.claude/settings.json`（**作成/更新**。既存があれば非破壊マージ）

### Step 3B: 新フォーマットへ移行（B を選択・推奨）

1. まず `.claude/settings.json` を **安全ポリシー込みで作成/更新**（既存は非破壊マージ）  
   → `ccp-generate-claude-settings` を実行
2. 次に `AGENTS.md` / `CLAUDE.md` / `Plans.md` を **既存内容を引き継ぎつつ新フォーマットへ移行**（対話で引き継ぎ項目を確定）  
   → `ccp-migrate-workflow-files` を実行
   - `Plans.md` はタスク保持マージ（`ccp-merge-plans` 方針）
   - `AGENTS.md` / `CLAUDE.md` はテンプレ骨格 + 「移行したプロジェクト固有ルール」を適切な場所に再配置
   - 変更前に `.claude-code-harness/backups/` にバックアップを残す

---

## VibeCoder 向けヒント

セットアップ後、いつでも使えるフレーズ：

| やりたいこと | 言い方 |
|-------------|--------|
| 続きをやる | 「続けて」「次」 |
| 動作確認 | 「動かして」「見せて」 |
| 機能追加 | 「〇〇を追加して」 |
| 困った | 「どうすればいい？」 |
| 全部任せる | 「全部やって」 |

---

## 注意事項

- **技術選択はユーザーに聞かない**: Claude Code が調査して提案
- **実際にコードを生成**: ファイル構造だけでなく動くコード
- **具体的なタスクを Plans.md に追加**: 空の計画にしない
- **次のアクションを常に提示**: VibeCoder が迷わないように
