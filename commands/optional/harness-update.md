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
- **Skills 差分検出** - 新しいスキルの自動検出・追加提案
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

#### 🔴 問題3: 古いフック設定（ハーネス由来のもののみ）

```bash
# コマンドパスに "claude-code-harness" を含むフックのみを検出
# ユーザー独自のカスタムフック（パスが異なる）は対象外
PLUGIN_EVENTS=("PreToolUse" "SessionStart" "UserPromptSubmit" "PermissionRequest")
OLD_HARNESS_EVENTS=()

if command -v jq >/dev/null 2>&1; then
  for event in "${PLUGIN_EVENTS[@]}"; do
    if jq -e ".hooks.${event}" "$SETTINGS_FILE" >/dev/null 2>&1; then
      # コマンドパスを抽出して "claude-code-harness" を含むかチェック
      COMMANDS=$(jq -r ".hooks.${event}[]?.hooks[]?.command // .hooks.${event}[]?.command // empty" "$SETTINGS_FILE" 2>/dev/null)
      if echo "$COMMANDS" | grep -q "claude-code-harness"; then
        OLD_HARNESS_EVENTS+=("$event")
      fi
    fi
  done

  if [ ${#OLD_HARNESS_EVENTS[@]} -gt 0 ]; then
    FOUND_ISSUES+=("legacy_hooks_in_settings")
    echo "古いハーネスフック設定: ${OLD_HARNESS_EVENTS[*]}"
  fi
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
> **🔴 問題3: 古いフック設定 (N件)**
>
> ```diff
> - "hooks": { ... }   ❌ プラグイン側 hooks.json と重複
> （この設定を削除）
> ```
>
> **理由**: claude-code-harness プラグインは `hooks/hooks.json` でフックを管理します。
> プロジェクト側の `.claude/settings.json` に `hooks` があると、意図しない重複動作が発生する可能性があります。
>
> **推奨**: プロジェクト側の `hooks` セクションを削除し、プラグイン側のフックのみを使用してください。
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

# 問題3: ハーネス由来のフック設定のみ削除（パスで判別）
# ユーザー独自のカスタムフックは保持
if [ -f "$SETTINGS_FILE" ]; then
  PLUGIN_EVENTS=("PreToolUse" "SessionStart" "UserPromptSubmit" "PermissionRequest")
  DELETED_EVENTS=()

  if command -v jq >/dev/null 2>&1; then
    for event in "${PLUGIN_EVENTS[@]}"; do
      if jq -e ".hooks.${event}" "$SETTINGS_FILE" >/dev/null 2>&1; then
        # コマンドパスに "claude-code-harness" が含まれる場合のみ削除
        COMMANDS=$(jq -r ".hooks.${event}[]?.hooks[]?.command // .hooks.${event}[]?.command // empty" "$SETTINGS_FILE" 2>/dev/null)
        if echo "$COMMANDS" | grep -q "claude-code-harness"; then
          jq "del(.hooks.${event})" "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp"
          mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
          DELETED_EVENTS+=("$event")
        fi
      fi
    done

    # .hooks が空になった場合は .hooks 自体を削除
    if jq -e '.hooks | length == 0' "$SETTINGS_FILE" >/dev/null 2>&1; then
      jq 'del(.hooks)' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp"
      mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
    fi

    if [ ${#DELETED_EVENTS[@]} -gt 0 ]; then
      echo "✅ 古いハーネスフック設定を削除: ${DELETED_EVENTS[*]}（プラグイン側 hooks.json を使用）"
    fi
  else
    # jq がない場合は Python で削除
    python3 -c "
import json
with open('$SETTINGS_FILE', 'r') as f:
    data = json.load(f)
if 'hooks' in data:
    plugin_events = ['PreToolUse', 'SessionStart', 'UserPromptSubmit', 'PermissionRequest']
    deleted = []
    for event in plugin_events:
        if event in data['hooks']:
            # コマンドパスに 'claude-code-harness' が含まれるかチェック
            hooks_list = data['hooks'][event]
            is_harness = any('claude-code-harness' in str(h) for h in hooks_list)
            if is_harness:
                del data['hooks'][event]
                deleted.append(event)
    if not data['hooks']:
        del data['hooks']
    if deleted:
        print(f'✅ 古いハーネスフック設定を削除: {\" \".join(deleted)}')
with open('$SETTINGS_FILE', 'w') as f:
    json.dump(data, f, indent=2)
"
  fi
fi
```

#### Step 2.2: generate-claude-settings スキルの実行

- `env`, `model`, `enabledPlugins` は保持（`hooks` は削除済み）
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

**マーカー + ハッシュ方式でローカライズ検出を行い、安全に更新します。**

```bash
PLUGIN_PATH="${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/plugins/claude-code-harness}"
PLUGIN_VERSION=$(cat "$PLUGIN_PATH/VERSION" 2>/dev/null || echo "unknown")
SKILLS_CONFIG=".claude/state/skills-config.json"

# Skills Gate の状態を確認
SKILLS_GATE_ENABLED="false"
if [ -f "$SKILLS_CONFIG" ]; then
  if command -v jq >/dev/null 2>&1; then
    SKILLS_GATE_ENABLED=$(jq -r '.enabled // false' "$SKILLS_CONFIG")
  fi
fi

# 各ルールテンプレートを処理
for template in "$PLUGIN_PATH/templates/rules"/*.template; do
  [ -f "$template" ] || continue

  rule_name=$(basename "$template" .template)
  output_file=".claude/rules/$rule_name"

  # 条件付きテンプレートのチェック（template-registry.json から condition を取得）
  TEMPLATE_KEY="rules/$(basename "$template")"
  CONDITION=""
  if command -v jq >/dev/null 2>&1; then
    CONDITION=$(jq -r ".templates[\"$TEMPLATE_KEY\"].condition // \"\"" "$PLUGIN_PATH/templates/template-registry.json" 2>/dev/null)
  fi

  # 条件付きテンプレートの評価
  if [ -n "$CONDITION" ]; then
    case "$CONDITION" in
      "skills_gate.enabled")
        if [ "$SKILLS_GATE_ENABLED" != "true" ]; then
          # 条件を満たさない場合
          if [ -f "$output_file" ]; then
            echo "🗑️ 削除提案: $output_file（Skills Gate 無効）"
          else
            echo "⏭️ スキップ: $rule_name（Skills Gate 無効）"
          fi
          continue
        fi
        ;;
    esac
  fi

  # ファイルが存在しない場合は新規作成
  if [ ! -f "$output_file" ]; then
    cp "$template" "$output_file"
    sed -i '' "s/{{VERSION}}/$PLUGIN_VERSION/g" "$output_file" 2>/dev/null || \
    sed -i "s/{{VERSION}}/$PLUGIN_VERSION/g" "$output_file"
    echo "🆕 作成: $output_file"
    continue
  fi

  # マーカーをチェック（ハーネス由来かどうか）
  if grep -q "^_harness_template:" "$output_file" 2>/dev/null; then
    # ハーネス由来 → ローカライズ検出して更新
    # フロントマター以降の内容のハッシュを比較
    INSTALLED_VERSION=$(grep "^_harness_version:" "$output_file" | sed 's/_harness_version: "//;s/"//')

    if [ "$INSTALLED_VERSION" != "$PLUGIN_VERSION" ]; then
      # バージョンが異なる → 更新対象
      # （ローカライズ検出は template-tracker.sh に任せる）
      echo "🔄 更新: $output_file（$INSTALLED_VERSION → $PLUGIN_VERSION）"
      cp "$template" "$output_file"
      sed -i '' "s/{{VERSION}}/$PLUGIN_VERSION/g" "$output_file" 2>/dev/null || \
      sed -i "s/{{VERSION}}/$PLUGIN_VERSION/g" "$output_file"
    else
      echo "✅ 最新: $output_file"
    fi
  else
    # マーカーなし → ユーザーカスタム、保護
    echo "🛡️ 保護: $output_file（ユーザーカスタム）"
  fi
done
```

**判定ロジック:**

| マーカー | 条件 | 処理 |
|---------|------|------|
| あり | 条件なし / 条件満たす | 更新（ローカライズ検出） |
| あり | 条件満たさない | 削除提案 |
| なし | - | 保護（ユーザーカスタム） |

#### Skills Gate 有効化の提案

Skills Gate が無効で、`skills-gate.md` が存在しない場合、有効化を提案します。

```bash
# Skills Gate が無効な場合、有効化を提案
if [ "$SKILLS_GATE_ENABLED" != "true" ]; then
  echo ""
  echo "💡 Skills Gate を有効にしますか？"
  echo ""
  echo "Skills Gate は、コード編集前にスキルの使用を促す機能です。"
  echo "- Rules: Claude に「スキルを使うべき」と認識させる"
  echo "- Hooks: 忘れた場合の最終防衛線"
  echo ""
  echo "有効にすると:"
  echo "- skills-gate.md ルールが追加されます"
  echo "- スキル使用が習慣化され、作業品質が向上します"
  echo ""
fi
```

**回答を待つ**

- **yes** → Skills Gate を有効化し、`skills-gate.md` を追加
- **no** → スキップ

```bash
# ユーザーが yes を選択した場合
if [ "$USER_CHOICE" = "yes" ]; then
  # skills-config.json を有効化
  if [ -f "$SKILLS_CONFIG" ]; then
    jq '.enabled = true' "$SKILLS_CONFIG" > tmp.json && mv tmp.json "$SKILLS_CONFIG"
  else
    mkdir -p .claude/state
    cat > "$SKILLS_CONFIG" << EOF
{
  "version": "1.0",
  "enabled": true,
  "skills": ["impl", "review"],
  "updated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
  fi

  # skills-gate.md を追加
  cp "$PLUGIN_PATH/templates/rules/skills-gate.md.template" ".claude/rules/skills-gate.md"
  sed -i '' "s/{{VERSION}}/$PLUGIN_VERSION/g" ".claude/rules/skills-gate.md" 2>/dev/null || \
  sed -i "s/{{VERSION}}/$PLUGIN_VERSION/g" ".claude/rules/skills-gate.md"
  echo "✅ Skills Gate を有効化しました"
  echo "✅ 作成: .claude/rules/skills-gate.md"
fi
```

### Step 4.5: Skills 設定の差分検出と更新

プラグイン側のスキルと、プロジェクト側の設定を比較して差分を検出・提案します。

#### Step 4.5.1: プラグイン側のスキル一覧を取得

```bash
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/plugins/claude-code-harness}"
SKILLS_CONFIG=".claude/state/skills-config.json"
mkdir -p .claude/state

# プラグイン側の利用可能スキル一覧を取得
AVAILABLE_SKILLS=()
if [ -d "$PLUGIN_ROOT/skills" ]; then
  for skill_dir in "$PLUGIN_ROOT/skills"/*/; do
    if [ -d "$skill_dir" ]; then
      skill_name=$(basename "$skill_dir")
      AVAILABLE_SKILLS+=("$skill_name")
    fi
  done
fi

echo "📦 プラグイン側の利用可能スキル: ${AVAILABLE_SKILLS[*]}"
```

#### Step 4.5.2: プロジェクト側の設定を取得

```bash
if [ -f "$SKILLS_CONFIG" ]; then
  # 既存設定からスキル一覧を取得
  if command -v jq >/dev/null 2>&1; then
    CURRENT_SKILLS=$(jq -r '.skills[]?' "$SKILLS_CONFIG" 2>/dev/null | tr '\n' ' ')
  else
    CURRENT_SKILLS=""
  fi
  echo "📋 プロジェクト側の登録スキル: $CURRENT_SKILLS"
else
  CURRENT_SKILLS=""
  echo "📋 プロジェクト側の登録スキル: (未設定)"
fi
```

#### Step 4.5.3: 差分を検出

```bash
NEW_SKILLS=()
REMOVED_SKILLS=()

# プラグインにあってプロジェクトにないスキル（新規追加候補）
for skill in "${AVAILABLE_SKILLS[@]}"; do
  if ! echo "$CURRENT_SKILLS" | grep -qw "$skill"; then
    NEW_SKILLS+=("$skill")
  fi
done

# プロジェクトにあってプラグインにないスキル（削除候補）
for skill in $CURRENT_SKILLS; do
  found=false
  for avail in "${AVAILABLE_SKILLS[@]}"; do
    if [ "$skill" = "$avail" ]; then
      found=true
      break
    fi
  done
  if [ "$found" = false ]; then
    REMOVED_SKILLS+=("$skill")
  fi
done
```

#### Step 4.5.4: 差分があれば提案

**新しいスキルが検出された場合:**

> 🆕 **新しいスキルが利用可能です**
>
> 以下のスキルが追加されました：
> {{NEW_SKILLS のリストと説明}}
>
> **追加しますか？**
> - **yes** - すべて追加
> - **選択** - 個別に選択
> - **スキップ** - 今回は追加しない

**回答を待つ**

- **yes** → すべての新スキルを skills-config.json に追加
- **選択** → 各スキルを個別に確認
- **スキップ** → skills-config.json は更新しない

**削除されたスキルが検出された場合:**

> ⚠️ **以下のスキルはプラグインから削除されました**
>
> {{REMOVED_SKILLS のリスト}}
>
> 設定から削除しますか？ (yes / no)

**回答を待つ**

#### Step 4.5.5: skills-config.json を更新

```bash
if [ -f "$SKILLS_CONFIG" ]; then
  # 既存設定を保持しつつ、新スキルを追加
  if command -v jq >/dev/null 2>&1; then
    # 承認された新スキルを追加
    for skill in "${APPROVED_NEW_SKILLS[@]}"; do
      jq --arg s "$skill" '.skills += [$s] | .skills |= unique' "$SKILLS_CONFIG" > tmp.json
      mv tmp.json "$SKILLS_CONFIG"
    done

    # 削除されたスキルを除去
    for skill in "${APPROVED_REMOVED_SKILLS[@]}"; do
      jq --arg s "$skill" '.skills -= [$s]' "$SKILLS_CONFIG" > tmp.json
      mv tmp.json "$SKILLS_CONFIG"
    done

    # バージョンとタイムスタンプを更新
    jq '.version = "1.0" | .updated_at = "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"' "$SKILLS_CONFIG" > tmp.json
    mv tmp.json "$SKILLS_CONFIG"
    echo "✅ skills-config.json: 更新"
  else
    echo "⚠️ jq が見つかりません。Skills 設定の自動更新はスキップされます"
    echo "   手動で /skills-update を実行するか、jq をインストールしてください"
  fi
else
  # 新規作成（デフォルトスキル + 承認された新スキル）
  DEFAULT_SKILLS='["impl", "review"]'
  cat > "$SKILLS_CONFIG" << SKILLSEOF
{
  "version": "1.0",
  "enabled": true,
  "skills": $DEFAULT_SKILLS,
  "updated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
SKILLSEOF
  echo "✅ skills-config.json: 新規作成"
fi
```

> 💡 **Skills 差分検出について**
> - プラグイン更新で新しいスキルが追加された場合、自動的に検出・提案されます
> - 既存のスキル設定は保持されます
> - 個別のスキル追加/削除は `/skills-update` コマンドでも行えます

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
> - Skills 設定: {{追加されたスキル / 変更なし}}
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
