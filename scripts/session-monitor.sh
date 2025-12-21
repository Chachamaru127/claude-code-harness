#!/bin/bash
# session-monitor.sh
# セッション開始時にプロジェクト状態を収集・表示
#
# Usage: SessionStart hook から自動実行
# Output: プロジェクト状態サマリー + 状態ファイル生成

# エラーで停止しない（Git エラー等を許容）
set +e

# ================================
# 設定
# ================================
STATE_DIR=".claude/state"
STATE_FILE="$STATE_DIR/session.json"
TOOLING_POLICY_FILE="$STATE_DIR/tooling-policy.json"
PLANS_FILE="Plans.md"

# ================================
# ヘルパー関数
# ================================

# 相対時間を計算（秒数から「X分前」「X時間前」等）
relative_time() {
  local seconds=$1
  if [ "$seconds" -lt 60 ]; then
    echo "${seconds}秒前"
  elif [ "$seconds" -lt 3600 ]; then
    echo "$((seconds / 60))分前"
  elif [ "$seconds" -lt 86400 ]; then
    echo "$((seconds / 3600))時間前"
  else
    echo "$((seconds / 86400))日前"
  fi
}

# Plans.md からタスク数をカウント
count_tasks() {
  local marker=$1
  local count=0
  if [ -f "$PLANS_FILE" ]; then
    count=$(grep -c "$marker" "$PLANS_FILE" 2>/dev/null || true)
    [ -z "$count" ] && count=0
  fi
  echo "$count"
}

# ================================
# 状態収集
# ================================

# プロジェクト情報
PROJECT_NAME=$(basename "$(pwd)")
CURRENT_TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Git 情報
if [ -d ".git" ]; then
  GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
  [ -z "$GIT_BRANCH" ] && GIT_BRANCH="unknown"
  GIT_UNCOMMITTED=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  [ -z "$GIT_UNCOMMITTED" ] && GIT_UNCOMMITTED="0"
  GIT_LAST_COMMIT=$(git log -1 --format="%h" 2>/dev/null || echo "none")
  GIT_LAST_COMMIT_TIME=$(git log -1 --format="%ct" 2>/dev/null || echo "0")
else
  GIT_BRANCH="(no git)"
  GIT_UNCOMMITTED="0"
  GIT_LAST_COMMIT="none"
  GIT_LAST_COMMIT_TIME="0"
fi

# Plans.md 情報
if [ -f "$PLANS_FILE" ]; then
  PLANS_EXISTS="true"
  PLANS_MODIFIED=$(stat -f "%m" "$PLANS_FILE" 2>/dev/null || stat -c "%Y" "$PLANS_FILE" 2>/dev/null || echo "0")
  WIP_COUNT=$(count_tasks "cc:WIP")
  TODO_COUNT=$(count_tasks "cc:TODO")
  # pm:* を正規。cursor:* は互換で同義扱い
  PENDING_COUNT=$(( $(count_tasks "pm:依頼中") + $(count_tasks "cursor:依頼中") ))
  COMPLETED_COUNT=$(count_tasks "cc:完了")
else
  PLANS_EXISTS="false"
  PLANS_MODIFIED="0"
  WIP_COUNT="0"
  TODO_COUNT="0"
  PENDING_COUNT="0"
  COMPLETED_COUNT="0"
fi

# 前回セッション情報
LAST_SESSION_TIME="0"
if [ -f "$STATE_FILE" ]; then
  LAST_SESSION_TIME=$(cat "$STATE_FILE" | grep -o '"started_at":"[^"]*"' | cut -d'"' -f4 | xargs -I{} date -j -f "%Y-%m-%dT%H:%M:%SZ" "{}" "+%s" 2>/dev/null || echo "0")
fi

# ================================
# 状態ファイル生成
# ================================
mkdir -p "$STATE_DIR"

cat > "$STATE_FILE" << EOF
{
  "session_id": "$(uuidgen 2>/dev/null || echo "session-$(date +%s)")",
  "started_at": "$CURRENT_TIME",
  "cwd": "$(pwd)",
  "project_name": "$PROJECT_NAME",
  "prompt_seq": 0,
  "git": {
    "branch": "$GIT_BRANCH",
    "uncommitted_changes": $GIT_UNCOMMITTED,
    "last_commit": "$GIT_LAST_COMMIT"
  },
  "plans": {
    "exists": $PLANS_EXISTS,
    "last_modified": $PLANS_MODIFIED,
    "wip_tasks": $WIP_COUNT,
    "todo_tasks": $TODO_COUNT,
    "pending_tasks": $PENDING_COUNT,
    "completed_tasks": $COMPLETED_COUNT
  },
  "changes_this_session": []
}
EOF

# ================================
# Tooling Policy ファイル生成
# ================================

# LSP 可用性の判定（公式LSPプラグイン導入状況）
LSP_AVAILABLE="false"
LSP_PLUGINS=""

# 既知の公式LSPプラグイン名（マーケットプレイス）
# 全10種の公式プラグインをサポート
OFFICIAL_LSP_PLUGINS="typescript-lsp pyright-lsp rust-analyzer-lsp gopls-lsp clangd-lsp jdtls-lsp swift-lsp lua-lsp php-lsp csharp-lsp"

if command -v claude >/dev/null 2>&1; then
  # claude plugin list でインストール済みプラグインを確認
  INSTALLED_PLUGINS=$(claude plugin list 2>/dev/null | grep -o '[a-z-]*lsp' || true)

  # 公式LSPプラグインが1つでも導入されているかチェック
  for plugin in $OFFICIAL_LSP_PLUGINS; do
    if echo "$INSTALLED_PLUGINS" | grep -q "$plugin"; then
      LSP_AVAILABLE="true"
      LSP_PLUGINS="$LSP_PLUGINS $plugin"
    fi
  done
fi

# Skillsインデックスの生成（name + description）
SKILLS_INDEX="[]"
if [ -d "skills" ]; then
  # JSONフォーマットでskillsを収集（jq優先、なければpythonでフォールバック）
  if command -v jq >/dev/null 2>&1; then
    SKILLS_INDEX=$(
      find skills -name 'doc.md' -type f 2>/dev/null | while read -r doc_file; do
        skill_name=$(dirname "$doc_file" | sed 's|skills/||')
        description=$(grep -m 1 '^description:' "$doc_file" 2>/dev/null | sed 's/^description: *//' || echo "")
        [ -z "$description" ] && description="No description"
        printf '{"name":"%s","description":"%s"}\n' "$skill_name" "$description"
      done | jq -s '.' 2>/dev/null || echo "[]"
    )
  elif command -v python3 >/dev/null 2>&1; then
    SKILLS_INDEX=$(
      find skills -name 'doc.md' -type f 2>/dev/null | python3 - <<'PY' 2>/dev/null
import sys, json, re, os
skills = []
for line in sys.stdin:
    doc_file = line.strip()
    skill_name = os.path.dirname(doc_file).replace("skills/", "", 1)
    description = "No description"
    try:
        with open(doc_file, "r") as f:
            for fline in f:
                if fline.startswith("description:"):
                    description = fline.replace("description:", "").strip()
                    break
    except Exception:
        pass
    skills.append({"name": skill_name, "description": description})
print(json.dumps(skills))
PY
    )
  fi
fi

# LSP可用性を拡張子別にマッピング（簡略版）
LSP_BY_EXT="{}"
if [ "$LSP_AVAILABLE" = "true" ]; then
  # 公式LSPプラグインが導入されている場合、対応拡張子をマッピング
  if echo "$LSP_PLUGINS" | grep -q "typescript-lsp"; then
    LSP_BY_EXT=$(echo "$LSP_BY_EXT" | jq '. + {"ts": true, "tsx": true, "js": true, "jsx": true}' 2>/dev/null || echo '{"ts":true,"tsx":true,"js":true,"jsx":true}')
  fi
  if echo "$LSP_PLUGINS" | grep -q "pyright-lsp"; then
    LSP_BY_EXT=$(echo "$LSP_BY_EXT" | jq '. + {"py": true}' 2>/dev/null || echo '{"py":true}')
  fi
  if echo "$LSP_PLUGINS" | grep -q "rust-analyzer-lsp"; then
    LSP_BY_EXT=$(echo "$LSP_BY_EXT" | jq '. + {"rs": true}' 2>/dev/null || echo '{"rs":true}')
  fi
  if echo "$LSP_PLUGINS" | grep -q "gopls-lsp"; then
    LSP_BY_EXT=$(echo "$LSP_BY_EXT" | jq '. + {"go": true}' 2>/dev/null || echo '{"go":true}')
  fi
  if echo "$LSP_PLUGINS" | grep -q "clangd-lsp"; then
    LSP_BY_EXT=$(echo "$LSP_BY_EXT" | jq '. + {"c": true, "cpp": true, "h": true, "hpp": true}' 2>/dev/null || echo '{"c":true,"cpp":true,"h":true,"hpp":true}')
  fi
  if echo "$LSP_PLUGINS" | grep -q "jdtls-lsp"; then
    LSP_BY_EXT=$(echo "$LSP_BY_EXT" | jq '. + {"java": true}' 2>/dev/null || echo '{"java":true}')
  fi
  if echo "$LSP_PLUGINS" | grep -q "swift-lsp"; then
    LSP_BY_EXT=$(echo "$LSP_BY_EXT" | jq '. + {"swift": true}' 2>/dev/null || echo '{"swift":true}')
  fi
  if echo "$LSP_PLUGINS" | grep -q "lua-lsp"; then
    LSP_BY_EXT=$(echo "$LSP_BY_EXT" | jq '. + {"lua": true}' 2>/dev/null || echo '{"lua":true}')
  fi
  if echo "$LSP_PLUGINS" | grep -q "php-lsp"; then
    LSP_BY_EXT=$(echo "$LSP_BY_EXT" | jq '. + {"php": true}' 2>/dev/null || echo '{"php":true}')
  fi
  if echo "$LSP_PLUGINS" | grep -q "csharp-lsp"; then
    LSP_BY_EXT=$(echo "$LSP_BY_EXT" | jq '. + {"cs": true}' 2>/dev/null || echo '{"cs":true}')
  fi
fi

# tooling-policy.json を生成
cat > "$TOOLING_POLICY_FILE" << EOF
{
  "lsp": {
    "available": $LSP_AVAILABLE,
    "plugins": "$LSP_PLUGINS",
    "available_by_ext": $LSP_BY_EXT,
    "last_used_prompt_seq": 0,
    "last_used_tool_name": "",
    "used_since_last_prompt": false
  },
  "skills": {
    "index": $SKILLS_INDEX,
    "decision_required": false
  }
}
EOF

# ================================
# サマリー出力
# ================================
echo ""
echo "📊 セッション開始 - プロジェクト状態"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📂 プロジェクト: $PROJECT_NAME"
echo "🔀 ブランチ: $GIT_BRANCH"

if [ "$GIT_UNCOMMITTED" -gt 0 ]; then
  echo "📝 未コミット: ${GIT_UNCOMMITTED}ファイル"
fi

if [ "$PLANS_EXISTS" = "true" ]; then
  TOTAL_ACTIVE=$((WIP_COUNT + TODO_COUNT + PENDING_COUNT))
  if [ "$TOTAL_ACTIVE" -gt 0 ]; then
    echo "📋 Plans.md: WIP ${WIP_COUNT}件 / TODO $((TODO_COUNT + PENDING_COUNT))件"
  fi
fi

if [ -n "$LAST_SESSION_TIME" ] && [ "$LAST_SESSION_TIME" != "0" ] && [ "$LAST_SESSION_TIME" -gt 0 ] 2>/dev/null; then
  NOW=$(date +%s)
  DIFF=$((NOW - LAST_SESSION_TIME))
  echo "⏰ 前回セッション: $(relative_time $DIFF)"
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

exit 0
