---
name: ccp-update-2agent-files
description: "既存の2エージェント体制セットアップを更新するスキル（差分更新・マージ対応）"
metadata:
  skillport:
    category: core
    tags: [update, 2agent, merge, case-insensitive]
    alwaysApply: false
---

# Update 2-Agent Files Skill

既存の2エージェント体制セットアップを最新バージョンに更新するスキル。
ユーザーデータを保持しながら、プラグインの改善を適用します。

---

## 目的

- 既存の AGENTS.md, CLAUDE.md, Plans.md を最新テンプレートで更新
- ユーザーのタスク・記録を保持
- Case-insensitive なファイル検出
- バージョン管理と更新履歴

---

## Case-Insensitive ファイル検出

### 検出ロジック

**重要**: macOS/Windows は case-insensitive、Linux は case-sensitive。
すべての環境で一貫した動作を保証するため、明示的に検索する。

```bash
# 既存ファイルを case-insensitive で検索
detect_file() {
  local pattern="$1"
  local found=$(find . -maxdepth 1 -iname "$pattern" -type f 2>/dev/null | head -1)
  if [ -n "$found" ]; then
    echo "$found"
  fi
}

AGENTS_FILE=$(detect_file "agents.md")
CLAUDE_FILE=$(detect_file "claude.md")
PLANS_FILE=$(detect_file "plans.md")
VERSION_FILE=".cursor-cc-version"
```

### 検出結果の正規化

```bash
# 標準ファイル名との比較
normalize_filename() {
  local found="$1"
  local standard="$2"

  if [ -n "$found" ] && [ "$found" != "./$standard" ]; then
    echo "検出: $found → 推奨: $standard"
    # ユーザーに確認後、リネーム
    # mv "$found" "$standard"
  fi
}

normalize_filename "$AGENTS_FILE" "AGENTS.md"
normalize_filename "$CLAUDE_FILE" "CLAUDE.md"
normalize_filename "$PLANS_FILE" "Plans.md"
```

---

## 期待されるファイル構成（v0.3.8）

更新時に以下のファイルが**存在すべき**かチェックする：

```
./
├── AGENTS.md
├── CLAUDE.md
├── Plans.md
├── .cursor-cc-version
├── .cursor-cc-config.yaml          # v0.3.7+
├── .cursor/
│   └── commands/
│       ├── start-session.md        # v0.3.5+
│       ├── project-overview.md     # v0.3.5+
│       ├── plan-with-cc.md         # v0.3.5+
│       ├── assign-to-cc.md
│       └── review-cc-work.md
└── .claude/
    ├── memory/
    │   ├── session-log.md
    │   ├── decisions.md
    │   └── patterns.md
    └── scripts/
        └── auto-cleanup-hook.sh    # v0.3.7+
```

---

## 更新フロー

### Step 1: 環境確認

```bash
# プラグインバージョン
PLUGIN_VERSION=$(cat ~/.claude/plugins/marketplaces/cursor-cc-marketplace/VERSION)
PLUGIN_PATH="$HOME/.claude/plugins/marketplaces/cursor-cc-marketplace"

# インストール済みバージョン
if [ -f .cursor-cc-version ]; then
  INSTALLED_VERSION=$(grep "^version:" .cursor-cc-version | cut -d' ' -f2)
  SETUP_STATUS="existing"
else
  INSTALLED_VERSION=""
  SETUP_STATUS="not_installed"
fi

# プロジェクト情報
PROJECT_NAME=$(basename "$(pwd)")
TODAY=$(date +%Y-%m-%d)
```

### Step 2: 足りないファイルの検出（重要）

**テンプレート変更の有無に関わらず、必須ファイルが存在するかチェック**

```bash
# 必須ファイルリスト
REQUIRED_FILES=(
  ".cursor/commands/start-session.md"
  ".cursor/commands/project-overview.md"
  ".cursor/commands/plan-with-cc.md"
  ".cursor/commands/assign-to-cc.md"
  ".cursor/commands/review-cc-work.md"
  ".claude/scripts/auto-cleanup-hook.sh"
  ".cursor-cc-config.yaml"
)

MISSING_FILES=()

for file in "${REQUIRED_FILES[@]}"; do
  if [ ! -f "$file" ]; then
    MISSING_FILES+=("$file")
    echo "⚠️ 不足: $file"
  fi
done

if [ ${#MISSING_FILES[@]} -gt 0 ]; then
  echo ""
  echo "📋 ${#MISSING_FILES[@]} 個のファイルが不足しています。追加します。"
  NEEDS_FILE_ADD=true
else
  echo "✅ 必須ファイルは全て揃っています"
  NEEDS_FILE_ADD=false
fi
```

### Step 3: 更新判定

| 条件 | update_type | 動作 |
|------|-------------|------|
| `.cursor-cc-version` なし | `not_installed` | `/setup-2agent` を案内 |
| バージョン同じ & ファイル揃ってる | `current` | スキップ |
| バージョン同じ & ファイル不足 | `missing_files` | 不足分を追加 |
| バージョン古い | `outdated` | 更新を実行 |

```bash
if [ "$SETUP_STATUS" = "not_installed" ]; then
  echo "⚠️ セットアップされていません。/setup-2agent を実行してください。"
  exit 1
fi

if [ "$INSTALLED_VERSION" = "$PLUGIN_VERSION" ]; then
  echo "✅ 最新バージョン (v${PLUGIN_VERSION}) です。"
  echo "強制更新する場合は「強制更新して」と言ってください。"
  # --force オプションがあれば続行
fi
```

### Step 4: バックアップ作成

```bash
BACKUP_DIR=".cursor-cc-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

# 既存ファイルをバックアップ
[ -n "$AGENTS_FILE" ] && cp "$AGENTS_FILE" "$BACKUP_DIR/"
[ -n "$CLAUDE_FILE" ] && cp "$CLAUDE_FILE" "$BACKUP_DIR/"
[ -n "$PLANS_FILE" ] && cp "$PLANS_FILE" "$BACKUP_DIR/"
[ -f .cursor-cc-version ] && cp .cursor-cc-version "$BACKUP_DIR/"

echo "📦 バックアップ: $BACKUP_DIR"
```

### Step 5: Plans.md のマージ更新

**ccp-merge-plans スキルを呼び出す**

```bash
# 既存の Plans.md からタスクセクションを抽出
extract_tasks "$PLANS_FILE" > /tmp/existing_tasks.md

# テンプレートに既存タスクをマージ
merge_plans "$PLUGIN_PATH/templates/Plans.md.template" /tmp/existing_tasks.md > Plans.md
```

### Step 6: AGENTS.md / CLAUDE.md の更新

```bash
# プロジェクト名を保持しつつテンプレートを適用
sed -e "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" \
    -e "s/{{DATE}}/$TODAY/g" \
    "$PLUGIN_PATH/templates/AGENTS.md.template" > AGENTS.md

sed -e "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" \
    -e "s/{{DATE}}/$TODAY/g" \
    "$PLUGIN_PATH/templates/CLAUDE.md.template" > CLAUDE.md

# 旧ファイル名を削除（正規化）
[ -n "$AGENTS_FILE" ] && [ "$AGENTS_FILE" != "./AGENTS.md" ] && rm "$AGENTS_FILE"
[ -n "$CLAUDE_FILE" ] && [ "$CLAUDE_FILE" != "./CLAUDE.md" ] && rm "$CLAUDE_FILE"
[ -n "$PLANS_FILE" ] && [ "$PLANS_FILE" != "./Plans.md" ] && rm "$PLANS_FILE"
```

### Step 7: Cursor コマンドの更新（全5ファイル）

```bash
mkdir -p .cursor/commands
cp "$PLUGIN_PATH/templates/cursor/commands/start-session.md" .cursor/commands/
cp "$PLUGIN_PATH/templates/cursor/commands/project-overview.md" .cursor/commands/
cp "$PLUGIN_PATH/templates/cursor/commands/plan-with-cc.md" .cursor/commands/
cp "$PLUGIN_PATH/templates/cursor/commands/assign-to-cc.md" .cursor/commands/
cp "$PLUGIN_PATH/templates/cursor/commands/review-cc-work.md" .cursor/commands/
```

### Step 8: Hooks 設定の更新（v0.3.7+）

```bash
# スクリプトディレクトリ作成
mkdir -p .claude/scripts

# Hook スクリプトをコピー
cp "$PLUGIN_PATH/templates/hooks/auto-cleanup-hook.sh" .claude/scripts/
chmod +x .claude/scripts/auto-cleanup-hook.sh

# 設定ファイルをコピー（存在しない場合のみ）
[ ! -f .cursor-cc-config.yaml ] && \
  cp "$PLUGIN_PATH/templates/.cursor-cc-config.yaml.template" .cursor-cc-config.yaml

# .claude/settings.json を更新（既存設定を保持しつつ hooks を追加）
# 注: 既存の settings.json がある場合はマージが必要
```

### Step 9: バージョンファイルの更新

```bash
cat > .cursor-cc-version << EOF
# cursor-cc-plugins version tracking
# Updated by /update-2agent

version: ${PLUGIN_VERSION}
installed_at: ${TODAY}
last_setup_command: update-2agent
updated_from: ${INSTALLED_VERSION}
update_history:
  - ${INSTALLED_VERSION} -> ${PLUGIN_VERSION} (${TODAY})
EOF
```

---

## 出力

| 項目 | 説明 |
|------|------|
| `update_performed` | 更新が実行されたか |
| `old_version` | 更新前のバージョン |
| `new_version` | 更新後のバージョン |
| `backup_path` | バックアップの場所 |
| `tasks_preserved` | 保持されたタスク数 |
| `normalized_files` | 正規化されたファイル |

---

## エラー処理

| エラー | 対応 |
|--------|------|
| Plans.md 解析失敗 | バックアップを保持し、テンプレートで再作成 |
| ファイル書き込み失敗 | バックアップから復元 |
| テンプレート見つからない | プラグイン再インストールを案内 |

---

## 関連スキル

- `ccp-merge-plans` - Plans.md のマージロジック
- `ccp-setup-2agent-files` - 初回セットアップ
- `ccp-generate-workflow-files` - ワークフローファイル生成
