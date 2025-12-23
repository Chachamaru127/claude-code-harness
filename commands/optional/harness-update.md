---
description: ハーネス導入済みプロジェクトを最新版に安全アップデート（バージョン検出→バックアップ→非破壊更新）
description-en: Safely update harness-enabled projects to latest version (version detection → backup → non-destructive update)
---

# /harness-update - ハーネスアップデート

既にハーネスが導入されているプロジェクトを、最新バージョンのハーネスに安全にアップデートします。
**バージョン検出→バックアップ→非破壊更新**の流れで、既存の設定やタスクを保持しながら最新機能を導入できます。

## こんなときに使う

- 「ハーネスを最新版にアップデートしたい」
- 「新機能を既存プロジェクトに追加したい」
- 「設定ファイルのフォーマットを最新版に合わせたい」
- 「間違ったパーミッション構文を修正したい」
- 「テンプレート更新があると通知された」

## できること

- `.claude-code-harness-version` でバージョン検出
- **テンプレート更新の検出とローカライズ判定**
- 更新が必要なファイルの特定
- 自動バックアップ作成
- 非破壊で設定・ワークフローファイルを更新
- **ローカライズなし → 上書き / ローカライズあり → マージ支援**
- アップデート後の検証

---

## 実行フロー

### Phase 1: バージョン検出と確認

#### Step 1: ハーネス導入状況の確認

`.claude-code-harness-version` ファイルを確認：

```bash
if [ -f .claude-code-harness-version ]; then
  CURRENT_VERSION=$(grep "^version:" .claude-code-harness-version | cut -d' ' -f2)
  echo "検出されたバージョン: $CURRENT_VERSION"
else
  echo "⚠️ ハーネス未導入のプロジェクトです"
  echo "→ /harness-init を使用してください"
  exit 1
fi
```

**ハーネス未導入の場合:**
> ⚠️ **このプロジェクトにはハーネスが導入されていません**
>
> `/harness-update` は既にハーネス導入済みのプロジェクト用です。
> 新規導入には `/harness-init` を使用してください。

**導入済みの場合:** → Step 2 へ

#### Step 2: バージョン比較

プラグインの最新バージョンと比較：

```bash
PLUGIN_VERSION=$(cat "$CLAUDE_PLUGIN_ROOT/claude-code-harness/VERSION" 2>/dev/null || echo "unknown")

if [ "$CURRENT_VERSION" = "$PLUGIN_VERSION" ]; then
  echo "✅ 既に最新版です (v$PLUGIN_VERSION)"
else
  echo "📦 アップデート可能: v$CURRENT_VERSION → v$PLUGIN_VERSION"
fi
```

**既に最新版の場合:**
> ✅ **プロジェクトは既に最新版です (v{{VERSION}})**
>
> アップデートの必要はありません。
> 特定のファイルだけ更新したい場合は、以下のスキルを個別に実行できます：
> - `generate-claude-settings` - .claude/settings.json の更新
> - `migrate-workflow-files` - AGENTS.md, CLAUDE.md, Plans.md の更新

**アップデート可能な場合:** → Step 3 へ

#### Step 3: テンプレート更新チェック

`template-tracker.sh status` を実行して、テンプレート更新状況を表示：

```bash
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/plugins/claude-code-harness}"
bash "$PLUGIN_ROOT/scripts/template-tracker.sh" status
```

**出力例:**

```
=== テンプレート追跡状況 ===

プラグインバージョン: 2.5.25
最終チェック時: 2.5.20

ファイル                                  記録版       最新版       状態
--------                                  ------       ------       ----
CLAUDE.md                                 2.5.20       2.5.25       🔄 上書き可
AGENTS.md                                 unknown      2.5.25       ⚠️ 要確認
Plans.md                                  2.5.20       2.5.25       🔧 マージ要
.claude/rules/workflow.md                 2.5.20       2.5.25       ✅ 最新

凡例:
  ✅ 最新     : 更新不要
  🔄 上書き可 : ローカライズなし、上書きで更新可能
  🔧 マージ要 : ローカライズあり、マージが必要
  ⚠️ 要確認   : バージョン不明、確認推奨
```

#### Step 4: 更新範囲の確認

更新対象ファイルを特定してユーザーに確認：

> 📦 **アップデート: v{{CURRENT}} → v{{LATEST}}**
>
> **更新されるファイル:**
> - `.claude/settings.json` - セキュリティポリシーと最新構文に更新
> - `AGENTS.md` / `CLAUDE.md` / `Plans.md` - 最新フォーマットに更新（既存タスクは保持）
> - `.claude/rules/` - 最新ルールテンプレートに更新
> - `.cursor/commands/` - Cursor コマンド更新（2-Agent モードの場合）
> - `.claude-code-harness-version` - バージョン情報更新
>
> **既存データは保持されます:**
> - ✅ Plans.md の未完了タスク
> - ✅ .claude/settings.json のカスタム設定（hooks, env, model など）
> - ✅ .claude/memory/ の SSOT データ
>
> **バックアップ:**
> - 変更前のファイルは `.claude-code-harness/backups/{{TIMESTAMP}}/` に保存されます
>
> アップデートを実行しますか？ (yes / no / カスタム)
>
> **カスタム**: 特定のファイルだけ更新したい場合は「カスタム」を選択

**回答を待つ**

- **yes** → Phase 1.5 (破壊的変更の確認)
- **no** → 終了
- **カスタム** → Phase 2A (選択的アップデート)

---

## Phase 1.5: 破壊的変更の検出と確認

**重要**: アップデート実行前に、既存設定の問題を検出してユーザーに確認します。

### Step 1: .claude/settings.json の検査

既存の `.claude/settings.json` を読み込み、以下をチェック：

```bash
# settings.json が存在するか確認
if [ ! -f .claude/settings.json ]; then
  echo "ℹ️ .claude/settings.json が存在しません（新規作成されます）"
  # → Phase 2 へ（破壊的変更なし）
fi

# JSON パーサーで読み込み（jq または python）
if command -v jq >/dev/null 2>&1; then
  SETTINGS_CONTENT=$(cat .claude/settings.json)
else
  echo "⚠️ jq が見つかりません。手動確認が必要です"
fi
```

### Step 2: 問題の検出

以下の問題を検出：

#### 🔴 問題1: 間違ったパーミッション構文

```bash
# 間違った構文のパターンを検索
WRONG_PATTERNS=(
  'Bash\([^:)]+\s\*\)'     # "Bash(npm run *)" のようなパターン
  'Bash\([^:)]+\*\)'       # "Bash(git diff*)" のようなパターン（:なし）
  'Bash\(\*[^:][^)]*\*\)'  # "Bash(*credentials*)" のようなパターン
)

FOUND_ISSUES=()

# 各パターンをチェック
if echo "$SETTINGS_CONTENT" | grep -E 'Bash\([^:)]+\s\*\)'; then
  FOUND_ISSUES+=("incorrect_prefix_syntax_with_space")
fi

if echo "$SETTINGS_CONTENT" | grep -E 'Bash\([^:)]+\*\)' | grep -v ':'; then
  FOUND_ISSUES+=("incorrect_prefix_syntax_no_colon")
fi

if echo "$SETTINGS_CONTENT" | grep -E 'Bash\(\*[^:][^)]*\*\)'; then
  FOUND_ISSUES+=("incorrect_substring_syntax")
fi
```

#### 🔴 問題2: 非推奨設定

```bash
# disableBypassPermissionsMode の存在確認
if echo "$SETTINGS_CONTENT" | grep -q '"disableBypassPermissionsMode"'; then
  FOUND_ISSUES+=("deprecated_disable_bypass_permissions")
fi
```

### Step 3: 検出結果の表示

問題が見つかった場合、ユーザーに詳細を表示：

> ⚠️ **既存設定に問題が見つかりました**
>
> **🔴 問題1: 間違ったパーミッション構文 (3件)**
>
> ```diff
> - "Bash(npm run *)"      ❌ 間違い（スペース+アスタリスク）
> + "Bash(npm run:*)"      ✅ 正しい（コロン+アスタリスク）
>
> - "Bash(pnpm *)"         ❌ 間違い
> + "Bash(pnpm:*)"         ✅ 正しい
>
> - "Bash(git diff*)"      ❌ 間違い（コロンなし）
> + "Bash(git diff:*)"     ✅ 正しい
> ```
>
> **影響**: 現在のパーミッション設定が正しく動作していません。
> Claude Code がこれらのコマンドを実行できない可能性があります。
>
> ---
>
> **🔴 問題2: 非推奨設定 (1件)**
>
> ```diff
> - "disableBypassPermissionsMode": "disable"   ❌ 非推奨（v2.5.0以降）
> （この設定を削除）
> ```
>
> **理由**: ハーネスは v2.5.0 以降、bypassPermissions を許可する運用に変更されました。
> 危険な操作のみを `permissions.deny` / `permissions.ask` で制御します。
>
> **影響**: 現在の設定では、Edit/Write の度に確認が出て生産性が低下します。
>
> ---
>
> **これらの問題を自動修正しますか？**
>
> - **yes** - 上記の問題をすべて自動修正してアップデート続行
> - **確認する** - 各問題を個別に確認してから修正
> - **スキップ** - 問題を修正せずにアップデート続行（非推奨）
> - **キャンセル** - アップデートを中止

**回答を待つ**

#### 選択肢の処理

- **yes** → 全ての問題を自動修正 → Phase 2 へ
- **確認する** → Step 4 (個別確認) へ
- **スキップ** → Phase 2 へ（問題を修正せずに続行、警告表示）
- **キャンセル** → アップデート中止

### Step 4: 個別確認（「確認する」選択時）

各問題について個別に確認：

> **問題1/2: 間違ったパーミッション構文**
>
> 以下の3件を修正しますか？
> - `"Bash(npm run *)"` → `"Bash(npm run:*)"`
> - `"Bash(pnpm *)"` → `"Bash(pnpm:*)"`
> - `"Bash(git diff*)"` → `"Bash(git diff:*)"`
>
> (yes / no)

**回答を待つ** → yes なら修正リストに追加

> **問題2/2: 非推奨設定**
>
> `disableBypassPermissionsMode` を削除しますか？
>
> (yes / no)

**回答を待つ** → yes なら削除リストに追加

すべての確認が完了したら → Phase 2 へ

---

## Phase 2: バックアップと更新

### Step 1: バックアップディレクトリ作成

```bash
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR=".claude-code-harness/backups/$TIMESTAMP"
mkdir -p "$BACKUP_DIR"

# バックアップ対象ファイルをコピー
[ -f .claude/settings.json ] && cp .claude/settings.json "$BACKUP_DIR/"
[ -f AGENTS.md ] && cp AGENTS.md "$BACKUP_DIR/"
[ -f CLAUDE.md ] && cp CLAUDE.md "$BACKUP_DIR/"
[ -f Plans.md ] && cp Plans.md "$BACKUP_DIR/"
[ -d .claude/rules ] && cp -r .claude/rules "$BACKUP_DIR/"
[ -d .cursor/commands ] && cp -r .cursor/commands "$BACKUP_DIR/"

echo "✅ バックアップ作成: $BACKUP_DIR"
```

### Step 2: 設定ファイルの更新

**`.claude/settings.json` の更新**

Phase 1.5 で検出した問題を修正してから、`generate-claude-settings` スキルを実行します。

#### Step 2.1: 破壊的変更の適用（Phase 1.5 で承認された場合）

ユーザーが承認した修正を適用：

```bash
# settings.json を読み込み
SETTINGS_FILE=".claude/settings.json"

# 問題1: パーミッション構文の修正
if [ -f "$SETTINGS_FILE" ]; then
  # スペース+アスタリスクをコロン+アスタリスクに置換
  # 例: "Bash(npm run *)" → "Bash(npm run:*)"
  sed -i.bak 's/Bash(\([^:)]*\) \*)/Bash(\1:*)/g' "$SETTINGS_FILE"

  # コロンなしアスタリスクをコロン+アスタリスクに置換
  # 例: "Bash(git diff*)" → "Bash(git diff:*)"
  # （ただし既に : がある場合はスキップ）
  sed -i.bak 's/Bash(\([^:)]*\)\*)/Bash(\1:*)/g' "$SETTINGS_FILE"

  # 部分文字列マッチの修正
  # 例: "Bash(*credentials*)" → "Bash(:*credentials:*)"
  sed -i.bak 's/Bash(\*\([^:][^)]*\)\*)/Bash(:*\1:*)/g' "$SETTINGS_FILE"

  echo "✅ パーミッション構文を修正しました"
fi

# 問題2: 非推奨設定の削除
if [ -f "$SETTINGS_FILE" ]; then
  # disableBypassPermissionsMode を削除（jq を使用）
  if command -v jq >/dev/null 2>&1; then
    jq 'del(.permissions.disableBypassPermissionsMode)' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp"
    mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
    echo "✅ disableBypassPermissionsMode を削除しました"
  else
    # jq がない場合は Python で削除
    python3 -c "
import json
with open('$SETTINGS_FILE', 'r') as f:
    data = json.load(f)
if 'permissions' in data and 'disableBypassPermissionsMode' in data['permissions']:
    del data['permissions']['disableBypassPermissionsMode']
with open('$SETTINGS_FILE', 'w') as f:
    json.dump(data, f, indent=2)
" && echo "✅ disableBypassPermissionsMode を削除しました"
  fi
fi
```

#### Step 2.2: generate-claude-settings スキルの実行

- 既存の `hooks`, `env`, `model`, `enabledPlugins` は保持
- `permissions.allow|ask|deny` は最新ポリシーとマージ + 重複排除
- Phase 1.5 で修正済みの正しい構文を保持
- 新しい推奨設定を追加

### Step 3: ワークフローファイルの更新（テンプレート追跡対応）

**テンプレート追跡状況に応じた更新処理**:

各ファイルの状態に応じて処理を分岐：

```bash
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/plugins/claude-code-harness}"

# テンプレート追跡のチェック結果を取得
CHECK_RESULT=$(bash "$PLUGIN_ROOT/scripts/template-tracker.sh" check 2>/dev/null)

# jq で更新が必要なファイルを処理
if command -v jq >/dev/null 2>&1; then
  echo "$CHECK_RESULT" | jq -r '.updates[]? | "\(.path)|\(.localized)"' | while IFS='|' read -r path localized; do
    if [ "$localized" = "false" ]; then
      # ローカライズなし → 上書き
      echo "🔄 上書き: $path"
      # テンプレートから生成して上書き
      # → generate-* スキルを実行
    else
      # ローカライズあり → マージ支援
      echo "🔧 マージ支援: $path"
      # 差分を表示してユーザーに確認
    fi
  done
fi
```

**ローカライズなし（🔄 上書き可）の場合:**

自動で最新テンプレートに置き換え：
- `AGENTS.md` / `CLAUDE.md`: 最新テンプレートで上書き
- `.claude/rules/*.md`: 最新ルールテンプレートで上書き

**ローカライズあり（🔧 マージ要）の場合:**

> 🔧 **`Plans.md` はローカライズされています**
>
> このファイルにはプロジェクト固有の変更が含まれています。
>
> **オプション:**
> 1. **差分を表示** - テンプレートとの差分を確認
> 2. **マージ支援** - Claude がマージを提案
> 3. **スキップ** - このファイルはスキップ
>
> 選択してください:

**回答を待つ**

マージ支援を選択した場合:
- 最新テンプレートの構造を維持
- ユーザーのカスタム部分（タスク、設定）を適切な位置に再配置
- 差分を表示して最終確認

**更新後の記録:**

```bash
# 更新したファイルを generated-files.json に記録
bash "$PLUGIN_ROOT/scripts/template-tracker.sh" record "$path"
```

### Step 4: ルールファイルの更新

`.claude/rules/` の更新:

```bash
PLUGIN_PATH="${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/plugins/claude-code-harness}"

# 最新のルールテンプレートをコピー
for template in "$PLUGIN_PATH/templates/rules"/*.template; do
  if [ -f "$template" ]; then
    rule_name=$(basename "$template" .template)
    cp "$template" ".claude/rules/$rule_name"
    echo "✅ 更新: .claude/rules/$rule_name"
  fi
done
```



### Step 4.5: Skills Gate 設定の更新

既存の skills-config.json が無い場合は新規作成、ある場合はマージ：

```bash
SKILLS_CONFIG=".claude/state/skills-config.json"
mkdir -p .claude/state

if [ -f "$SKILLS_CONFIG" ]; then
  # 既存設定を保持しつつ、バージョンを更新
  if command -v jq >/dev/null 2>&1; then
    jq '.version = "1.0" | .updated_at = "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"' "$SKILLS_CONFIG" > tmp.json
    mv tmp.json "$SKILLS_CONFIG"
    echo "✅ skills-config.json: 更新"
  fi
else
  # 新規作成
  cat > "$SKILLS_CONFIG" << SKILLSEOF
{
  "version": "1.0",
  "enabled": true,
  "skills": ["impl", "review"],
  "updated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
SKILLSEOF
  echo "✅ skills-config.json: 新規作成"
fi
```

> 💡 既存のスキル設定は保持されます。
> スキルの追加/削除は `/skills-update` コマンドで行えます。

### Step 5: Cursor コマンドの更新（2-Agent モードの場合）

`.cursor/commands/` が存在する場合のみ更新:

```bash
if [ -d .cursor/commands ]; then
  PLUGIN_PATH="${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/plugins/claude-code-harness}"

  # 最新のコマンドテンプレートをコピー
  for cmd in "$PLUGIN_PATH/templates/cursor/commands"/*.md; do
    if [ -f "$cmd" ]; then
      cp "$cmd" .cursor/commands/
      echo "✅ 更新: $(basename $cmd)"
    fi
  done
fi
```

### Step 6: バージョンファイルの更新

`.claude-code-harness-version` を最新版に更新:

```bash
cat > .claude-code-harness-version <<EOF
# claude-code-harness version tracking
# This file is auto-generated by /harness-update
# DO NOT manually edit - used for update detection

version: $PLUGIN_VERSION
installed_at: $(grep "^installed_at:" .claude-code-harness-version | cut -d' ' -f2)
updated_at: $(date +%Y-%m-%d)
last_setup_command: harness-update
EOF

echo "✅ バージョン更新: v$CURRENT_VERSION → v$PLUGIN_VERSION"
```

---

## Phase 2A: 選択的アップデート（カスタム選択時）

> 📋 **どのファイルを更新しますか？**
>
> 1. `.claude/settings.json` - セキュリティポリシーとパーミッション構文
> 2. `AGENTS.md` / `CLAUDE.md` / `Plans.md` - ワークフローファイル
> 3. `.claude/rules/` - ルールテンプレート
> 4. `.cursor/commands/` - Cursor コマンド（2-Agent モード）
> 5. すべて
>
> 番号で選択してください（複数可、カンマ区切り）:

**回答を待つ**

選択されたファイルのみ Phase 2 の該当 Step を実行。

---

## Phase 3: 検証と完了

### Step 1: 更新後の検証

```bash
# settings.json の構文チェック
if command -v jq >/dev/null 2>&1; then
  jq empty .claude/settings.json 2>/dev/null && echo "✅ settings.json: 有効" || echo "⚠️ settings.json: 構文エラー"
fi

# バージョンファイルの確認
[ -f .claude-code-harness-version ] && echo "✅ version file: 存在" || echo "⚠️ version file: なし"
```

### Step 2: アップデート完了レポート

> ✅ **アップデートが完了しました！**
>
> **更新内容:**
> - バージョン: v{{CURRENT}} → v{{LATEST}}
> - 更新ファイル: {{更新されたファイルリスト}}
> - バックアップ: `.claude-code-harness/backups/{{TIMESTAMP}}/`
>
> **次のステップ:**
> - 「`/sync-status`」→ 現在の状態を確認
> - 「`/plan-with-agent` 〇〇を作りたい」→ 新しいタスクを追加
> - 「`/work`」→ Plans.md のタスクを実行
>
> **問題が発生した場合:**
> ```bash
> # バックアップから復元
> cp -r .claude-code-harness/backups/{{TIMESTAMP}}/* .
> ```

---

## Phase 2B: 選択的アップデート（カスタム選択時）

ユーザーが選択したファイルのみ更新します。

---

## 注意事項

- **バックアップは必須**: 更新前に必ずバックアップを作成
- **既存データは保持**: Plans.md のタスク、settings.json のカスタム設定は保持
- **非破壊マージ**: 既存ファイルは上書きせず、マージして更新
- **検証を忘れずに**: アップデート後は `/sync-status` で状態確認

---

## トラブルシューティング

### Q: アップデート後に設定が消えた

A: バックアップから復元してください：
```bash
cp -r .claude-code-harness/backups/{{TIMESTAMP}}/* .
```

### Q: パーミッション構文エラーが出る

A: `.claude/settings.json` を手動で修正するか、再度 `/harness-update` を実行してください。
正しい構文: `"Bash(npm run:*)"` / 間違い: `"Bash(npm run *)"`

### Q: 特定のファイルだけ更新したい

A: 「カスタム」を選択して、必要なファイルだけ選択してください。

---

## 関連コマンド

- `/harness-init` - 新規プロジェクトのセットアップ
- `/sync-status` - 現在のプロジェクト状態確認
- `/validate` - プロジェクト構造の検証
