---
description: プロジェクトセットアップ（環境診断→ファイル生成→SSOT同期→検証まで一括）
description-en: Project setup (environment check → file generation → SSOT sync → validation)
---

# /harness-init - プロジェクトセットアップ

VibeCoder が自然言語だけで開発を始められるよう、プロジェクトをセットアップします。
**環境診断から検証まで一括で実行**し、すぐに開発を始められる状態にします。

## バイブコーダー向け（こう言えばOK）

- 「**新規プロジェクトを最速で立ち上げたい**」→ このコマンド
- 「**Next.js + Supabase で**」のように希望があれば添える（未指定なら質問して決めます）
- 「**まず動くものを作って、後で整えたい**」→ まず動作する土台を作り、Plans.md で次の手を提示します
- 「**既存プロジェクトにハーネスを導入したい**」→ 既存コードを分析してワークフローを追加

## できること（成果物）

- 実プロジェクト生成（例: create-next-app 等）＋初期セットアップ
- `Plans.md` / `AGENTS.md` / `CLAUDE.md` / `.claude/` 等を整備
- **環境診断**（health-check 相当）
- **SSOT 初期化**（decisions.md / patterns.md）
- **最終検証**（validate 相当）
- → **Plan→Work→Review をすぐに回せる状態**にする

---

## このコマンドの特徴

- 🎯 技術選択は設定に基づく（auto/ask/fixed モード）
- 🚀 実際のプロジェクトを生成（create-next-app 等を実行）
- 📋 Plans.md に具体的なタスクを自動追加
- 💡 「次に何を言えばいいか」を常に提示

---

## ⚠️ 最初に確認: 言語選択 & モード選択（Phase 0）

**重要**: プロジェクト分析の前に、必ずこのステップを実行すること。

### Step 0-1: 言語選択 / Language Selection

> 🌐 **Which language? / どの言語で使いますか？**
>
> **🇯🇵 日本語 (JA)**
> - すべてのメッセージ・コマンド説明を日本語で表示
> - VibeCoder 向けの自然な言い回しに対応
>
> **🇺🇸 English (EN)**
> - All messages and command descriptions in English
> - Natural language commands supported
>
> JA / EN ?

**回答を待つ**

選択に応じて `claude-code-harness.config.json` に以下を設定:
```json
{
  "i18n": {
    "language": "ja"  // or "en"
  }
}
```

### Step 0-2: モード選択

> 🤔 **どのモードで開発しますか？ / Which development mode?**
>
> **🅰️ Solo モード / Solo Mode**（Claude Code だけで開発）
> - あなたが直接 Claude Code に話しかけて開発
> - シンプル・すぐ始められる
> - 個人プロジェクト向け
>
> **🅱️ 2-Agent モード / 2-Agent Mode**（Cursor + Claude Code で役割分担）
> - **Cursor (PM)** が計画・レビュー・本番デプロイ
> - **Claude Code (Worker)** が実装・テスト・stagingデプロイ
> - チーム開発・大規模プロジェクト向け
>
> A / B どちらですか？ / Which one?

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
- `permissions.disableBypassPermissionsMode` は **設定しない**（bypassPermissions を許可）
  - セキュリティ要件で bypass を禁止したい場合のみ `"disable"` を設定（例: managed-settings.json）

**⚠️ 重要**: パーミッション設定を生成する際は、必ず正しい構文を使用すること：
- ✅ 正しい: `"Bash(npm run:*)"`, `"Bash(git status:*)"`
- ❌ 間違い: `"Bash(npm run *)"`, `"Bash(git status*)"`
- プレフィックスマッチには `:*` を使用（`*` 単独や ` *` は不可）

**実行**: `generate-claude-settings` スキルを実行して作成/更新すること。

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
   → `generate-claude-settings` を実行
2. 次に `AGENTS.md` / `CLAUDE.md` / `Plans.md` を **既存内容を引き継ぎつつ新フォーマットへ移行**（対話で引き継ぎ項目を確定）
   → `migrate-workflow-files` を実行
   - `Plans.md` はタスク保持マージ（`merge-plans` 方針）
   - `AGENTS.md` / `CLAUDE.md` はテンプレ骨格 + 「移行したプロジェクト固有ルール」を適切な場所に再配置
   - 変更前に `.claude-code-harness/backups/` にバックアップを残す

---

## Phase 3: セットアップ完了処理（共通）

**新規・既存プロジェクト共通で実行する**

### Step 1: 環境診断

必須ツールの存在確認：

```bash
# Git
command -v git >/dev/null 2>&1 && echo "✅ git" || echo "❌ git"

# Node.js / npm（該当する場合）
command -v node >/dev/null 2>&1 && echo "✅ node $(node -v)" || echo "⚠️ node"

# GitHub CLI（オプション）
command -v gh >/dev/null 2>&1 && echo "✅ gh" || echo "⚠️ gh (CI自動修正に必要)"
```

問題があれば警告を表示し、解決方法を提示。

### Step 1.5: LSP 環境確認（オプション）

プロジェクトの言語に対応する Language Server の確認：

```bash
# プロジェクト言語を検出
DETECTED_LANGS=()

[ -f tsconfig.json ] || [ -f package.json ] && DETECTED_LANGS+=("typescript")
[ -f requirements.txt ] || [ -f pyproject.toml ] && DETECTED_LANGS+=("python")
[ -f Cargo.toml ] && DETECTED_LANGS+=("rust")
[ -f go.mod ] && DETECTED_LANGS+=("go")

# 各言語の LSP サーバー確認
for lang in "${DETECTED_LANGS[@]}"; do
  case $lang in
    typescript)
      command -v typescript-language-server >/dev/null 2>&1 \
        && echo "✅ LSP (TypeScript): typescript-language-server" \
        || echo "⚠️ LSP (TypeScript): npm install -g typescript typescript-language-server"
      ;;
    python)
      (command -v pylsp >/dev/null 2>&1 || command -v pyright >/dev/null 2>&1) \
        && echo "✅ LSP (Python): pylsp/pyright" \
        || echo "⚠️ LSP (Python): pip install python-lsp-server"
      ;;
    rust)
      command -v rust-analyzer >/dev/null 2>&1 \
        && echo "✅ LSP (Rust): rust-analyzer" \
        || echo "⚠️ LSP (Rust): rustup component add rust-analyzer"
      ;;
    go)
      command -v gopls >/dev/null 2>&1 \
        && echo "✅ LSP (Go): gopls" \
        || echo "⚠️ LSP (Go): go install golang.org/x/tools/gopls@latest"
      ;;
  esac
done
```

> 💡 **LSP を有効化すると**、Go-to-definition、Find-references、Diagnostics などのコード分析機能が使えます。
>
> 「**LSPを設定して**」または `/lsp-setup` で詳細設定が可能です。
>
> 詳細: [docs/LSP_INTEGRATION.md](../../docs/LSP_INTEGRATION.md)

### Step 2: SSOT 初期化

`.claude/memory/` が存在しない場合、作成：

- `decisions.md` - 意思決定記録（空テンプレート）
- `patterns.md` - 再利用パターン（空テンプレート）

**既存の Serena メモリ（`.serena/memories/`）がある場合**:
→ 重要な決定事項を抽出して SSOT に反映（`/sync-ssot-from-serena` 相当）

### Step 3: 運用ドキュメント同期

`Plans.md` / `AGENTS.md` / `CLAUDE.md` が最新の運用形式（PM↔Impl マーカー等）に沿っているか確認。
古い形式の場合は更新を提案（`/sync-project-specs` 相当）。

### Step 4: ルールのローカライズと品質保護ルールの展開

プロジェクト構造を分析し、`.claude/rules/` のルールファイルをプロジェクトに最適化（`/localize-rules` 相当）。

**検出項目**:
- 言語・フレームワーク（TypeScript, React, Next.js, Python, Go, Rust, Ruby）
- ソースディレクトリ（`src/`, `app/`, `lib/` など）
- テストディレクトリ（`tests/`, `__tests__/`, `spec/` など）

**実行**: `scripts/localize-rules.sh` を実行してルールを最適化。

#### 品質保護ルールの自動展開

テスト改ざん防止の3層防御戦略（[D9](.claude/memory/decisions.md#d9-テスト改ざん防止の3層防御戦略)）に基づき、以下のルールを自動展開：

| ルール | 内容 |
|--------|------|
| `test-quality.md` | テスト改ざん禁止（skip化、アサーション削除、lint設定緩和） |
| `implementation-quality.md` | 形骸化実装禁止（ハードコード、スタブ、テスト期待値のコピペ） |

```bash
PLUGIN_PATH="${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/plugins/claude-code-harness}"
PLUGIN_VERSION=$(cat "$PLUGIN_PATH/VERSION" 2>/dev/null || echo "unknown")
mkdir -p .claude/rules

# 品質保護ルールを展開
for template in test-quality implementation-quality; do
  if [ -f "$PLUGIN_PATH/templates/rules/${template}.md.template" ]; then
    cp "$PLUGIN_PATH/templates/rules/${template}.md.template" ".claude/rules/${template}.md"
    # {{VERSION}} をプラグインバージョンに置換
    sed -i '' "s/{{VERSION}}/$PLUGIN_VERSION/g" ".claude/rules/${template}.md" 2>/dev/null || \
    sed -i "s/{{VERSION}}/$PLUGIN_VERSION/g" ".claude/rules/${template}.md"
    echo "✅ 作成: .claude/rules/${template}.md"
  fi
done
```

#### Skills Gate Rules の条件付き追加

Skills Gate が有効な場合のみ、`skills-gate.md` ルールを追加します。

```bash
SKILLS_CONFIG=".claude/state/skills-config.json"

# Skills Gate が有効かチェック
SKILLS_GATE_ENABLED="false"
if [ -f "$SKILLS_CONFIG" ]; then
  if command -v jq >/dev/null 2>&1; then
    SKILLS_GATE_ENABLED=$(jq -r '.enabled // false' "$SKILLS_CONFIG")
  fi
fi

# Skills Gate が有効なら skills-gate.md を追加
if [ "$SKILLS_GATE_ENABLED" = "true" ]; then
  if [ -f "$PLUGIN_PATH/templates/rules/skills-gate.md.template" ]; then
    cp "$PLUGIN_PATH/templates/rules/skills-gate.md.template" ".claude/rules/skills-gate.md"
    sed -i '' "s/{{VERSION}}/$PLUGIN_VERSION/g" ".claude/rules/skills-gate.md" 2>/dev/null || \
    sed -i "s/{{VERSION}}/$PLUGIN_VERSION/g" ".claude/rules/skills-gate.md"
    echo "✅ 作成: .claude/rules/skills-gate.md（Skills Gate 有効）"
  fi
else
  echo "ℹ️ Skills Gate 無効: skills-gate.md はスキップ"
fi
```

> 💡 **品質保護ルールとは？**
>
> Coding Agent がテスト失敗時に「テストを改ざん」したり、「形骸化した実装」を書いたりすることを防ぐルールです。
> - **test-quality.md**: テスト/lint/CI設定の改ざんを禁止
> - **implementation-quality.md**: ハードコードや空実装を禁止し、正しい実装を促す
>
> 詳細: [びーぐる氏「Claude Codeにテストで楽をさせない技術」](https://speakerdeck.com/)

### Step 4.5: Skills Policy の設定

プロジェクト構造を分析し、Skills/LSP ゲートの除外パスを設定。

#### デフォルト除外パス

以下のパスはデフォルトで除外（スキル宣言なしで編集可能）：

```json
{
  "skills_gate": {
    "exclude_paths": [
      ".claude/memory/",
      ".claude/state/",
      "docs/",
      "templates/",
      "*.md"
    ],
    "exclude_extensions": [".md", ".txt", ".json"]
  }
}
```

#### プロジェクト固有の除外パス検出

プロジェクト構造を分析し、追加の除外候補を検出：

```bash
# ドキュメント系ディレクトリの検出
EXTRA_EXCLUDE=()
[ -d "documentation" ] && EXTRA_EXCLUDE+=("documentation/")
[ -d "notes" ] && EXTRA_EXCLUDE+=("notes/")
[ -d "wiki" ] && EXTRA_EXCLUDE+=("wiki/")
[ -d ".github" ] && EXTRA_EXCLUDE+=(".github/")
[ -d "examples" ] && EXTRA_EXCLUDE+=("examples/")

# 検出結果を表示
if [ ${#EXTRA_EXCLUDE[@]} -gt 0 ]; then
  echo "追加の除外候補を検出しました："
  for path in "${EXTRA_EXCLUDE[@]}"; do
    echo "  - $path"
  done
  echo ""
  echo "これらを Skills ゲートの除外パスに追加しますか？ (yes/no)"
fi
```

#### 設定ファイルの生成

`templates/state/skills-policy.json.template` をベースに、プロジェクト固有の設定を生成：

```bash
mkdir -p .claude/state
cp "$PLUGIN_PATH/templates/state/skills-policy.json.template" .claude/state/skills-policy.json

# 追加の除外パスがあれば追加
if [ ${#EXTRA_EXCLUDE[@]} -gt 0 ]; then
  # jq で exclude_paths に追加
  for path in "${EXTRA_EXCLUDE[@]}"; do
    jq ".skills_gate.exclude_paths += [\"$path\"]" .claude/state/skills-policy.json > tmp.json
    mv tmp.json .claude/state/skills-policy.json
  done
fi
```

> 💡 **Skills Policy とは？**
>
> コード変更前に適切なスキルを評価・使用することを促すポリシーです。
> ただし、ドキュメントや設定ファイルなど、スキルが不要な編集は除外されます。
>
> 設定は `.claude/state/skills-policy.json` で管理され、後から変更可能です。


#### Skills Gate の設定（skills-config.json）

プロジェクトで利用するスキルを設定し、Skills Gate を有効化します。

##### Step 4.5.1: プロジェクトタイプの自動判定

```bash
# プロジェクトタイプに基づいてデフォルトスキルを決定
DEFAULT_SKILLS='["impl", "review"]'
PROJECT_TYPE="一般"

# フロントエンドプロジェクトの場合
if [ -f "package.json" ]; then
  if grep -q "react\|vue\|angular\|svelte" package.json 2>/dev/null; then
    DEFAULT_SKILLS='["impl", "review", "ui"]'
    PROJECT_TYPE="フロントエンド"
  fi
fi

# バックエンドプロジェクトの場合（CI/deploy が有用）
if [ -f "Dockerfile" ] || [ -d ".github/workflows" ]; then
  DEFAULT_SKILLS='["impl", "review", "ci", "deploy"]'
  PROJECT_TYPE="バックエンド/CI"
fi

echo "📊 検出されたプロジェクトタイプ: $PROJECT_TYPE"
echo "📦 推奨スキル: $DEFAULT_SKILLS"
```

##### Step 4.5.2: ユーザーへの確認

自動判定結果をユーザーに確認し、必要に応じて調整：

> 📦 **Skills Gate 設定**
>
> プロジェクトタイプ: **{{PROJECT_TYPE}}**
>
> 推奨スキル:
> {{DEFAULT_SKILLS のリスト}}
>
> **利用可能な全スキル:**
>
> | スキル | 用途 | 推奨 |
> |--------|------|------|
> | `impl` | 実装、機能追加 | ✅ |
> | `review` | コードレビュー | ✅ |
> | `ui` | UI コンポーネント | {{フロントエンドなら ✅}} |
> | `auth` | 認証・決済 | |
> | `deploy` | デプロイ | {{CI があれば ✅}} |
> | `ci` | CI/CD | {{CI があれば ✅}} |
> | `verify` | ビルド検証 | |
> | `docs` | ドキュメント生成 | |
>
> **選択してください:**
> - **yes** - 推奨スキルでセットアップ
> - **追加** - スキルを追加（例: `auth, docs`）
> - **カスタム** - 一から選択

**回答を待つ**

- **yes** → 推奨スキルで設定
- **追加** → 推奨 + 指定スキルで設定
- **カスタム** → ユーザーが選択したスキルのみ

##### Step 4.5.3: skills-config.json を生成

```bash
# ユーザーの選択に基づいて FINAL_SKILLS を決定
# (yes の場合は DEFAULT_SKILLS をそのまま使用)

mkdir -p .claude/state
cat > .claude/state/skills-config.json << SKILLSEOF
{
  "version": "1.0",
  "enabled": true,
  "skills": $FINAL_SKILLS,
  "updated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
SKILLSEOF

echo "✅ Skills Gate 設定完了: $FINAL_SKILLS"
```

> 💡 **Skills Gate とは？**
>
> コード編集前に Skill ツールの使用を促すゲートです。
> セッション開始時にリセットされ、1回でもスキルを使えば以降は通過します。
>
> スキルの追加/削除は `/skills-update` コマンドで行えます。

### Step 5: 最終検証

プラグイン/プロジェクト構造の検証：

```bash
# プラグインリポジトリの場合
[ -f tests/validate-plugin.sh ] && bash tests/validate-plugin.sh

# 一般プロジェクトの場合
[ -f package.json ] && npm run lint --if-present
```

---

## Phase 4: セットアップ検証と再試行

**重要**: セットアップ完了前に、必須ファイルがすべて生成されているか確認します。

### Step 1: 選択モードの記録確認

ユーザーが選択したモードを確認（Phase 0-2 で記録済み）：

```bash
# 設定ファイルから読み取り
if [ -f .claude-code-harness-version ]; then
  SETUP_MODE=$(grep "^setup_mode:" .claude-code-harness-version | cut -d' ' -f2)
else
  echo "⚠️ セットアップモードが記録されていません"
  SETUP_MODE="solo"  # デフォルト
fi
```

### Step 2: 必須ファイルのチェックリスト検証

選択モードに応じて、必須ファイルをチェック：

#### Solo モードのチェックリスト

```bash
REQUIRED_FILES=(
  "AGENTS.md"
  "CLAUDE.md"
  "Plans.md"
  ".claude/settings.json"
  ".claude/memory/decisions.md"
  ".claude/memory/patterns.md"
  ".claude/rules/test-quality.md"
  ".claude/rules/implementation-quality.md"
  ".claude-code-harness-version"
)

MISSING_FILES=()

for file in "${REQUIRED_FILES[@]}"; do
  if [ ! -f "$file" ]; then
    MISSING_FILES+=("$file")
  fi
done
```

#### 2-Agent モードのチェックリスト

```bash
REQUIRED_FILES=(
  # Solo モードの必須ファイル
  "AGENTS.md"
  "CLAUDE.md"
  "Plans.md"
  ".claude/settings.json"
  ".claude/memory/decisions.md"
  ".claude/memory/patterns.md"
  ".claude/rules/test-quality.md"
  ".claude/rules/implementation-quality.md"
  ".claude-code-harness-version"
  # 2-Agent モード追加ファイル
  ".cursor/commands/start-session.md"
  ".cursor/commands/project-overview.md"
  ".cursor/commands/plan-with-cc.md"
  ".cursor/commands/handoff-to-claude.md"
  ".cursor/commands/review-cc-work.md"
  ".claude/rules/workflow.md"
)

MISSING_FILES=()

for file in "${REQUIRED_FILES[@]}"; do
  if [ ! -f "$file" ]; then
    MISSING_FILES+=("$file")
  fi
done
```

### Step 3: チェック結果の表示

#### すべてのファイルが存在する場合

```
✅ セットアップ検証: 完了

【チェックリスト】
✅ AGENTS.md
✅ CLAUDE.md
✅ Plans.md
✅ .claude/settings.json
✅ .claude/memory/decisions.md
✅ .claude/memory/patterns.md
✅ .claude-code-harness-version
✅ .cursor/commands/ (5ファイル)  ← 2-Agent モードのみ
✅ .claude/rules/workflow.md      ← 2-Agent モードのみ

→ Step 4 へ
```

#### ファイルが不足している場合

```
⚠️ セットアップ検証: 不足ファイルあり

【チェックリスト】
✅ AGENTS.md
✅ CLAUDE.md
✅ Plans.md
✅ .claude/settings.json
✅ .claude/memory/decisions.md
✅ .claude/memory/patterns.md
✅ .claude-code-harness-version
❌ .cursor/commands/start-session.md
❌ .cursor/commands/project-overview.md
❌ .cursor/commands/plan-with-cc.md
❌ .cursor/commands/handoff-to-claude.md
❌ .cursor/commands/review-cc-work.md
❌ .claude/rules/workflow.md

🔴 不足ファイル (6件):
- .cursor/commands/start-session.md
- .cursor/commands/project-overview.md
- .cursor/commands/plan-with-cc.md
- .cursor/commands/handoff-to-claude.md
- .cursor/commands/review-cc-work.md
- .claude/rules/workflow.md

これらのファイルは 2-Agent モードで必須です。
自動生成しますか？

- yes - 不足ファイルを自動生成
- 手動確認 - 何が問題か確認してから再試行
- スキップ - このまま完了（非推奨）
```

**回答を待つ**

### Step 4: 不足ファイルの自動生成（yes 選択時）

不足しているファイルを特定のスキルで生成：

```bash
# Cursor コマンドファイルが不足している場合
if [[ " ${MISSING_FILES[@]} " =~ ".cursor/commands/" ]]; then
  echo "📁 Cursor コマンドファイルを生成中..."

  PLUGIN_PATH="${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/plugins/claude-code-harness}"
  mkdir -p .cursor/commands

  for cmd in "$PLUGIN_PATH/templates/cursor/commands"/*.md; do
    if [ -f "$cmd" ]; then
      cp "$cmd" .cursor/commands/
      echo "✅ 作成: $(basename $cmd)"
    fi
  done
fi

# ルールファイルが不足している場合
if [[ " ${MISSING_FILES[@]} " =~ ".claude/rules/" ]]; then
  echo "📁 ルールファイルを生成中..."

  mkdir -p .claude/rules

  for template in "$PLUGIN_PATH/templates/rules"/*.template; do
    if [ -f "$template" ]; then
      rule_name=$(basename "$template" .template)
      cp "$template" ".claude/rules/$rule_name"
      echo "✅ 作成: $rule_name"
    fi
  done
fi

# ワークフローファイルが不足している場合
WORKFLOW_FILES=("AGENTS.md" "CLAUDE.md" "Plans.md")
for wf_file in "${WORKFLOW_FILES[@]}"; do
  if [[ " ${MISSING_FILES[@]} " =~ "$wf_file" ]]; then
    echo "📁 $wf_file を生成中..."
    # generate-workflow-files スキルを実行
  fi
done

# settings.json が不足している場合
if [[ " ${MISSING_FILES[@]} " =~ ".claude/settings.json" ]]; then
  echo "📁 .claude/settings.json を生成中..."
  # generate-claude-settings スキルを実行
fi

# メモリファイルが不足している場合
MEMORY_FILES=("decisions.md" "patterns.md")
for mem_file in "${MEMORY_FILES[@]}"; do
  if [[ " ${MISSING_FILES[@]} " =~ ".claude/memory/$mem_file" ]]; then
    mkdir -p .claude/memory
    cp "$PLUGIN_PATH/templates/memory/$mem_file.template" ".claude/memory/$mem_file"
    echo "✅ 作成: .claude/memory/$mem_file"
  fi
done
```

### Step 5: 再検証

不足ファイルを生成した後、再度チェックリストを実行：

```bash
# もう一度チェック
MISSING_FILES=()
for file in "${REQUIRED_FILES[@]}"; do
  if [ ! -f "$file" ]; then
    MISSING_FILES+=("$file")
  fi
done

if [ ${#MISSING_FILES[@]} -eq 0 ]; then
  echo "✅ すべての必須ファイルが生成されました！"
else
  echo "⚠️ まだ不足しているファイルがあります:"
  printf '%s\n' "${MISSING_FILES[@]}"
  echo ""
  echo "手動で生成するか、セットアップを最初からやり直してください。"
  exit 1
fi
```

### Step 6: セットアップ完了レポート

> ✅ **セットアップが完了しました！**
>
> **環境診断**: ✅ OK
> **ワークフローファイル**: ✅ 作成済み
> **SSOT**: ✅ 初期化済み
> **必須ファイル検証**: ✅ OK（{{モード}}モード: {{ファイル数}}件）
> **検証**: ✅ OK
>
> **セットアップモード**: {{Solo / 2-Agent}}
>
> **生成されたファイル:**
> - AGENTS.md, CLAUDE.md, Plans.md
> - .claude/settings.json
> - .claude/memory/ (decisions.md, patterns.md)
> - {{2-Agent の場合}} .cursor/commands/ (5ファイル)
> - {{2-Agent の場合}} .claude/rules/
>
> **次にやること：**
> - {{Solo モード}} 「`/plan-with-agent` 〇〇を作りたい」→ プランを作成
> - {{2-Agent モード}} Cursor で「〇〇を作りたい」と相談 → `/handoff-to-claude` でタスク依頼
> - 「`/work`」→ Plans.md のタスクを実行
> - 「`/sync-status`」→ 現在の状態を確認

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

---

## ⚠️ 開発用 vs リポジトリ用のファイル

**このコマンドで生成されるファイルの分類:**

| ファイル | 用途 | コミット |
|---------|------|---------|
| `AGENTS.md`, `CLAUDE.md`, `Plans.md` | 開発ワークフロー | プロジェクトによる |
| `.claude/settings.json` | 開発時セーフティ | 開発用（.gitignore） |
| `.claude/memory/*` | セッション記憶 | 開発用（.gitignore） |

**判断基準:**

| 質問 | Yes → | No → |
|------|-------|------|
| このプロジェクトの機能に影響するか？ | リポジトリにコミット | 開発用 |
| エンドユーザーや他の開発者に必要か？ | リポジトリにコミット | 開発用 |

**例: プラグイン開発でこのコマンドを実行した場合**
- プラグインの機能には関係ないため、生成されたワークフローファイルは開発用
- `.gitignore` にすでに追加されていることを確認
