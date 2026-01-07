---
description: プロジェクトセットアップ（環境診断→ファイル生成→SSOT同期→検証まで一括）
description-en: Project setup (environment check → file generation → SSOT sync → validation)
---

# /harness-init - プロジェクトセットアップ

VibeCoder が自然言語だけで開発を始められるよう、プロジェクトをセットアップします。
**最小1回の質問で完了**し、すぐに開発を始められる状態にします。

## バイブコーダー向け（こう言えばOK）

- 「**新規プロジェクトを最速で立ち上げたい**」→ このコマンド
- 「**おまかせで**」「**さくっと**」→ 質問なしでデフォルト設定で進行
- 「**Next.js + Supabase で**」→ 技術指定も可能
- 「**既存プロジェクトにハーネスを導入**」→ 既存コードを分析してワークフロー追加

## できること（成果物）

- 実プロジェクト生成（例: create-next-app 等）＋初期セットアップ
- `Plans.md` / `AGENTS.md` / `CLAUDE.md` / `.claude/` 等を整備
- **環境診断** → **SSOT 初期化** → **最終検証** まで一括
- → **Plan→Work→Review をすぐに回せる状態**にする

---

## 🚀 効率化されたフロー

**Before**: 最大11回の対話ラウンド
**After**: 最小1回、最大2回の対話ラウンド

```
Step 1: 統合質問（1回）
  ├─ 何を作る？
  ├─ 誰が使う？
  └─ おまかせ or 詳細設定？

Step 2: 確認（おまかせなら省略）
  └─ 技術スタック + プロジェクト名

→ セットアップ実行（バックグラウンド分析含む）

Step 3: 完了報告
```

---

## 実行フロー

### Step 0: 引数チェックとファストトラック判定

**引数またはトリガーワードで判定**:

| 入力 | 動作 |
|------|------|
| `おまかせ` `さくっと` `全部デフォルト` | → ファストトラック（Step 1 スキップ） |
| `/harness-init ブログ --mode=solo` | → 引数解析、指定項目は質問スキップ |
| 引数なし | → Step 1 へ |

**ファストトラック時のデフォルト**:
- 言語: ja
- モード: Solo（.cursor/ なければ）、2-Agent（.cursor/ あれば）
- 技術: auto（next-supabase ベース）
- Skills Gate: プロジェクトタイプから自動判定

### Step 1: 統合質問（1回で完了）

**バックグラウンドでプロジェクト分析を開始**しながら、質問を表示:

```bash
# バックグラウンド分析（並列実行）
CODE_COUNT=$(find . -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.py" \) \
  ! -path "*/node_modules/*" ! -path "*/.venv/*" 2>/dev/null | wc -l | tr -d ' ')
HAS_CURSOR=$([ -d .cursor ] && echo "true" || echo "false")
HAS_PACKAGE=$([ -f package.json ] && echo "true" || echo "false")
```

**AskUserQuestion で3つの質問を同時に提示**:

```json
{
  "questions": [
    {
      "question": "何を作りますか？（既存プロジェクトなら「既存に導入」を選択）",
      "header": "プロジェクト",
      "options": [
        {"label": "Webアプリ（ブログ、ECなど）", "description": "Next.js + Supabase で構築"},
        {"label": "API / バックエンド", "description": "Express / FastAPI で構築"},
        {"label": "既存プロジェクトに導入", "description": "ワークフローファイルのみ追加"},
        {"label": "その他", "description": "自由に指定"}
      ],
      "multiSelect": false
    },
    {
      "question": "誰が使いますか？",
      "header": "対象ユーザー",
      "options": [
        {"label": "自分だけ", "description": "個人プロジェクト"},
        {"label": "チーム", "description": "社内ツール・共同開発"},
        {"label": "一般公開", "description": "公開サービス"}
      ],
      "multiSelect": false
    },
    {
      "question": "セットアップ方法を選んでください",
      "header": "モード",
      "options": [
        {"label": "おまかせ（推奨）", "description": "最適なデフォルトで自動設定"},
        {"label": "詳細設定", "description": "技術スタックやプロジェクト名を指定"}
      ],
      "multiSelect": false
    }
  ]
}
```

**回答を待つ**（1回のみ）

### Step 2: 追加質問（詳細設定の場合のみ）

「おまかせ」選択時は**このステップをスキップ**。

「詳細設定」選択時のみ:

```json
{
  "questions": [
    {
      "question": "技術スタックはどれにしますか？",
      "header": "技術",
      "options": [
        {"label": "Next.js + Supabase（推奨）", "description": "フルスタック、無料で始められる"},
        {"label": "Next.js + FastAPI", "description": "より柔軟なバックエンド"},
        {"label": "その他", "description": "Rails, Django など指定"}
      ],
      "multiSelect": false
    },
    {
      "question": "プロジェクト名を入力してください",
      "header": "名前",
      "options": [
        {"label": "自動生成", "description": "my-app-XXXXXX 形式で生成"},
        {"label": "指定する", "description": "好きな名前を入力"}
      ],
      "multiSelect": false
    }
  ]
}
```

**回答を待つ**

---

## スマートデフォルト

質問を減らすために、以下の項目は自動判定またはデフォルト値を使用:

| 項目 | デフォルト | 自動判定条件 |
|------|-----------|------------|
| 言語 | ja | 設定ファイルで変更可 |
| モード | Solo | .cursor/ があれば 2-Agent |
| 技術スタック | next-supabase | auto モード時 |
| Skills Gate | 自動設定 | 後から `/skills-update` で調整 |

**設定で上書き可能**（`claude-code-harness.config.json`）:
```json
{
  "i18n": { "language": "en" },
  "scaffolding": {
    "tech_choice_mode": "fixed",
    "base_stack": "rails-postgres"
  }
}
```

---

## Phase 2: プロジェクト分析と分岐

### プロジェクト判定（3値）

```
Step 1 の回答 + バックグラウンド分析結果を統合

「既存に導入」選択 → project_type: "existing"
「Webアプリ」「API」選択 → ディレクトリ分析:
  ├── 空 or .git のみ → project_type: "new"
  ├── コード 10+ → project_type: "existing"（警告表示）
  └── コード 1-9 → project_type: "ambiguous"
```

**曖昧ケースの確認**（ambiguous のみ）:

> ⚠️ ディレクトリにファイルが存在します（{{CODE_COUNT}}件）
>
> 🅰️ **新規として続ける**（既存ファイルを保持しつつセットアップ）
> 🅱️ **既存として扱う**（ワークフローファイルのみ追加）

---

## Phase 3: セットアップ実行

### 新規プロジェクト（project_type: "new"）

1. **プロジェクト生成**（Task ツールで並列可能）
   ```bash
   npx create-next-app@latest {{PROJECT_NAME}} --typescript --tailwind --eslint --app --src-dir
   cd {{PROJECT_NAME}}
   npm install @supabase/supabase-js lucide-react
   ```

2. **ワークフローファイル生成**
   - AGENTS.md, CLAUDE.md, Plans.md
   - .claude/settings.json（非破壊マージ）
   - .claude/memory/（decisions.md, patterns.md）

3. **品質保護ルール展開**
   - .claude/rules/test-quality.md
   - .claude/rules/implementation-quality.md

### 既存プロジェクト（project_type: "existing"）

1. **既存ファイル確認**
   ```bash
   [ -f AGENTS.md ] && echo "AGENTS.md: あり" || echo "なし"
   [ -f CLAUDE.md ] && echo "CLAUDE.md: あり" || echo "なし"
   [ -f Plans.md ] && echo "Plans.md: あり" || echo "なし"
   ```

2. **不足ファイルのみ追加**（既存は触らない）

3. **.claude/settings.json は非破壊マージ**

---

## Phase 4: 環境診断（自動実行）

```bash
# Git
command -v git >/dev/null 2>&1 && echo "✅ git" || echo "❌ git"

# Node.js（該当する場合）
command -v node >/dev/null 2>&1 && echo "✅ node $(node -v)" || echo "⚠️ node"

# GitHub CLI（オプション）
command -v gh >/dev/null 2>&1 && echo "✅ gh" || echo "⚠️ gh"
```

問題があれば警告表示。**質問はしない**（情報提供のみ）。

---

## Phase 5: 完了報告（詳細サマリー）

作業完了後、**自動で決定された内容を明示**して透明性を確保:

> ✅ **セットアップが完了しました！**
>
> ---
>
> ### 📋 自動決定された設定
>
> | 項目 | 値 | 変更方法 |
> |------|-----|---------|
> | 言語 | **ja** | `claude-code-harness.config.json` で変更 |
> | モード | **{{Solo / 2-Agent}}** | {{.cursor/ 検出結果}} |
> | 技術スタック | **{{next-supabase など}}** | 再実行時に「詳細設定」を選択 |
> | Skills Gate | **{{impl, review など}}** | `/skills-update` で調整 |
> | プロジェクト名 | **{{my-app-XXXXXX}}** | `package.json` を編集 |
>
> ---
>
> ### 📁 生成されたファイル
>
> **ワークフロー**:
> | ファイル | 用途 | サイズ |
> |---------|------|--------|
> | `AGENTS.md` | 開発フロー概要 | {{XX行}} |
> | `CLAUDE.md` | Claude Code 設定 | {{XX行}} |
> | `Plans.md` | タスク管理 | {{XX行}} |
>
> **設定**:
> | ファイル | 用途 |
> |---------|------|
> | `.claude/settings.json` | 権限・安全設定 |
> | `.claude/memory/decisions.md` | 意思決定記録 |
> | `.claude/memory/patterns.md` | 再利用パターン |
>
> **品質保護ルール**:
> | ファイル | 内容 |
> |---------|------|
> | `.claude/rules/test-quality.md` | テスト改ざん禁止 |
> | `.claude/rules/implementation-quality.md` | 形骸化実装禁止 |
>
> {{2-Agent モードの場合}}
> **Cursor コマンド**:
> | ファイル | 用途 |
> |---------|------|
> | `.cursor/commands/start-session.md` | セッション開始 |
> | `.cursor/commands/plan-with-cc.md` | 計画作成 |
> | `.cursor/commands/handoff-to-claude.md` | タスク依頼 |
> | `.cursor/commands/review-cc-work.md` | 実装レビュー |
>
> ---
>
> ### ⚙️ 後から変更するには
>
> | 変更したいこと | コマンド/方法 |
> |--------------|--------------|
> | Skills Gate のスキル追加/削除 | `/skills-update` |
> | 2-Agent モードに切り替え | `/setup-cursor` |
> | 技術スタック変更 | 手動でファイル編集 or プロジェクト再作成 |
> | 言語設定変更 | `claude-code-harness.config.json` を編集 |
>
> ---
>
> ### 🚀 次にやること
>
> - 「`/plan-with-agent` 〇〇を作りたい」→ 計画を作成
> - 「`/work`」→ Plans.md のタスクを実行
> - 「`npm run dev`」→ 開発サーバー起動（該当する場合）
>
> 💡 **困ったら**「どうすればいい？」と聞いてください

---

## モード別の追加設定

### Solo モード

追加設定なし。そのまま完了。

### 2-Agent モード（.cursor/ 検出時）

自動で以下を追加:
- .cursor/commands/ (5ファイル)
- .claude/rules/workflow.md

> 💡 **2-Agent の使い方**:
> 1. Cursor で「〇〇を作りたい」と相談
> 2. `/handoff-to-claude` で Claude Code にタスク依頼
> 3. Claude Code で実装 → `/handoff-to-cursor` で報告

---

## 引数サポート

```bash
# フル指定（質問なし）
/harness-init "ブログ" --mode=solo --stack=next-supabase --name=my-blog

# 一部指定（不足分のみ質問）
/harness-init --stack=rails-postgres

# ヘルプ
/harness-init --help
```

| 引数 | 説明 | 例 |
|------|------|-----|
| `[プロジェクト説明]` | 何を作るか | `"ECサイト"` |
| `--mode` | solo / 2agent | `--mode=solo` |
| `--stack` | 技術スタック | `--stack=next-supabase` |
| `--name` | プロジェクト名 | `--name=my-app` |
| `--lang` | 言語 | `--lang=en` |

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

- **質問は最小限**: おまかせなら1回、詳細設定でも2回で完了
- **技術選択は自動提案**: VibeCoder が迷わないようにデフォルト推奨
- **既存ファイルは保護**: 上書きせず非破壊マージ
- **Skills Gate は後から調整可能**: 初期負担を軽減
