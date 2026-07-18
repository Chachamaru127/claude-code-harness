#!/bin/bash
# check-consistency.sh
# プラグインの整合性チェック
#
# Usage: ./scripts/ci/check-consistency.sh
# Exit codes:
#   0 - All checks passed
#   1 - Inconsistencies found

set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ERRORS=0

echo "🔍 claude-code-harness 整合性チェック"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ================================
# 1. テンプレートファイルの存在確認
# ================================
echo ""
echo "📁 [1/16] テンプレートファイルの存在確認..."

REQUIRED_TEMPLATES=(
  "templates/AGENTS.md.template"
  "templates/CLAUDE.md.template"
  "templates/Plans.md.template"
  "templates/locales/ja/AGENTS.md.template"
  "templates/locales/ja/CLAUDE.md.template"
  "templates/locales/ja/Plans.md.template"
  "templates/locales/ja/.claude-code-harness.config.yaml.template"
  "templates/.claude-code-harness-version.template"
  "templates/.claude-code-harness.config.yaml.template"
  "templates/cursor/commands/start-session.md"
  "templates/cursor/commands/project-overview.md"
  "templates/cursor/commands/plan-with-cc.md"
  "templates/cursor/commands/handoff-to-claude.md"
  "templates/cursor/commands/review-cc-work.md"
  "templates/claude/settings.security.json.template"
  "templates/claude/settings.local.json.template"
  "templates/rules/workflow.md.template"
  "templates/rules/coding-standards.md.template"
  "templates/rules/plans-management.md.template"
  "templates/rules/testing.md.template"
  "templates/rules/ui-debugging-agent-browser.md.template"
)

for template in "${REQUIRED_TEMPLATES[@]}"; do
  if [ ! -f "$PLUGIN_ROOT/$template" ]; then
    echo "  ❌ 不足: $template"
    ERRORS=$((ERRORS + 1))
  else
    echo "  ✅ $template"
  fi
done

# ================================
# 2. コマンド ↔ スキル の整合性
# ================================
echo ""
echo "🔗 [2/16] コマンド ↔ スキル の参照整合性..."

# コマンドが参照するテンプレートが存在するか
check_command_references() {
  local cmd_file="$1"
  local cmd_name=$(basename "$cmd_file" .md)

  # テンプレートへの参照を抽出
  local refs=$(grep -oE 'templates/[a-zA-Z0-9/_.-]+' "$cmd_file" 2>/dev/null || true)

  for ref in $refs; do
    if [ ! -e "$PLUGIN_ROOT/$ref" ] && [ ! -e "$PLUGIN_ROOT/${ref}.template" ]; then
      echo "  ❌ $cmd_name: 参照先が存在しない: $ref"
      ERRORS=$((ERRORS + 1))
    fi
  done
}

for cmd in "$PLUGIN_ROOT/commands"/*.md; do
  check_command_references "$cmd"
done
echo "  ✅ コマンド参照チェック完了"

# ================================
# 3. バージョン番号の一貫性
# ================================
echo ""
echo "🏷️ [3/16] バージョン番号の一貫性..."

VERSION_FILE="$PLUGIN_ROOT/VERSION"
PLUGIN_JSON="$PLUGIN_ROOT/.claude-plugin/plugin.json"

if [ -f "$VERSION_FILE" ] && [ -f "$PLUGIN_JSON" ]; then
  FILE_VERSION=$(cat "$VERSION_FILE" | tr -d '[:space:]')
  JSON_VERSION=$(grep '"version"' "$PLUGIN_JSON" | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')

  if [ "$FILE_VERSION" != "$JSON_VERSION" ]; then
    echo "  ❌ バージョン不一致: VERSION=$FILE_VERSION, plugin.json=$JSON_VERSION"
    ERRORS=$((ERRORS + 1))
  else
    echo "  ✅ VERSION と plugin.json が一致: $FILE_VERSION"
  fi
fi

LATEST_RELEASE_URL="https://github.com/Chachamaru127/claude-code-harness/releases/latest"
LATEST_RELEASE_BADGE="https://img.shields.io/github/v/release/Chachamaru127/claude-code-harness?display_name=tag&sort=semver"

# ================================
# 4. スキルの期待ファイル構成
# ================================
echo ""
echo "📋 [4/16] スキル定義の期待ファイル構成..."

# 2agent 設定は harness-setup に統合済み
# skills/harness-setup/SKILL.md の存在を確認
SETUP_SKILL="$PLUGIN_ROOT/skills/harness-setup/SKILL.md"
if [ -f "$SETUP_SKILL" ]; then
  echo "  ✅ skills/harness-setup/SKILL.md が存在（2agent 設定を包含）"
else
  echo "  ❌ skills/harness-setup/SKILL.md が見つかりません"
  ERRORS=$((ERRORS + 1))
fi

# ================================
# 5. Hooks 設定の整合性
# ================================
echo ""
echo "🪝 [5/16] Hooks 設定の整合性..."

HOOKS_JSON="$PLUGIN_ROOT/hooks/hooks.json"
if [ -f "$HOOKS_JSON" ]; then
  # hooks.json 内のスクリプト参照を確認
  SCRIPT_REFS=$(grep -oE '\$\{CLAUDE_PLUGIN_ROOT\}/scripts/[a-zA-Z0-9_./-]+' "$HOOKS_JSON" 2>/dev/null || true)

  for ref in $SCRIPT_REFS; do
    script_name=$(echo "$ref" | sed 's|\${CLAUDE_PLUGIN_ROOT}/scripts/||')
    if [ ! -f "$PLUGIN_ROOT/scripts/$script_name" ]; then
      echo "  ❌ hooks.json: スクリプトが存在しない: scripts/$script_name"
      ERRORS=$((ERRORS + 1))
    else
      echo "  ✅ scripts/$script_name"
    fi
  done
fi

# ================================
# 6. /start-task 廃止の回帰チェック
# ================================
echo ""
echo "🚫 [6/16] /start-task 廃止の回帰チェック..."

# 運用導線ファイル（CHANGELOG等の履歴は除外）
START_TASK_TARGETS=(
  "commands/"
  "skills/"
  "workflows/"
  "profiles/"
  "templates/"
  "scripts/"
  "DEVELOPMENT_FLOW_GUIDE.md"
  "IMPLEMENTATION_GUIDE.md"
  "README.md"
)

START_TASK_FOUND=0
for target in "${START_TASK_TARGETS[@]}"; do
  if [ -e "$PLUGIN_ROOT/$target" ]; then
    # /start-task への参照を検索（履歴・説明文脈は除外）
    # 除外パターン: 削除/廃止/Removed（履歴）, 相当/統合/従来/吸収（移行説明）, 改善/使い分け（CHANGELOG）
    REFS=$(grep -rn "/start-task" "$PLUGIN_ROOT/$target" 2>/dev/null \
      | grep -v "削除" | grep -v "廃止" | grep -v "Removed" \
      | grep -v "相当" | grep -v "統合" | grep -v "従来" | grep -v "吸収" \
      | grep -v "改善" | grep -v "使い分け" | grep -v "CHANGELOG" \
      | grep -v "check-consistency.sh" \
      || true)
    if [ -n "$REFS" ]; then
      echo "  ❌ /start-task 参照が残存: $target"
      sed -n '1,3p' <<<"$REFS" | sed 's/^/      /'
      START_TASK_FOUND=$((START_TASK_FOUND + 1))
    fi
  fi
done

if [ $START_TASK_FOUND -eq 0 ]; then
  echo "  ✅ /start-task 参照なし（運用導線）"
else
  ERRORS=$((ERRORS + START_TASK_FOUND))
fi

# ================================
# 7. docs/ 正規化の回帰チェック
# ================================
echo ""
echo "📁 [7/16] docs/ 正規化の回帰チェック..."

# proposal.md / priority_matrix.md のルート参照をチェック
DOCS_TARGETS=(
  "commands/"
  "skills/"
)

DOCS_ISSUES=0
for target in "${DOCS_TARGETS[@]}"; do
  if [ -d "$PLUGIN_ROOT/$target" ]; then
    # ルート直下の proposal.md / technical-spec.md / priority_matrix.md への参照を検索
    # docs/ プレフィックスがないものを検出
    REFS=$(grep -rn "proposal.md\|technical-spec.md\|priority_matrix.md" "$PLUGIN_ROOT/$target" 2>/dev/null | grep -v "docs/" | grep -v "\.template" || true)
    if [ -n "$REFS" ]; then
      echo "  ❌ docs/ プレフィックスなしの参照: $target"
      sed -n '1,3p' <<<"$REFS" | sed 's/^/      /'
      DOCS_ISSUES=$((DOCS_ISSUES + 1))
    fi
  fi
done

if [ $DOCS_ISSUES -eq 0 ]; then
  echo "  ✅ docs/ 正規化OK"
else
  ERRORS=$((ERRORS + DOCS_ISSUES))
fi

# ================================
# 8. bypassPermissions 前提運用の回帰チェック
# ================================
echo ""
echo "🔓 [8/16] bypassPermissions 前提運用の回帰チェック..."

BYPASS_ISSUES=0

# Check 1: disableBypassPermissionsMode が templates に戻っていないこと
SECURITY_TEMPLATE="$PLUGIN_ROOT/templates/claude/settings.security.json.template"
if [ -f "$SECURITY_TEMPLATE" ]; then
  if grep -q "disableBypassPermissionsMode" "$SECURITY_TEMPLATE"; then
    echo "  ❌ settings.security.json.template に disableBypassPermissionsMode が残存"
    echo "      bypassPermissions 前提運用のため、この設定は削除してください"
    BYPASS_ISSUES=$((BYPASS_ISSUES + 1))
  else
    echo "  ✅ disableBypassPermissionsMode なし"
  fi
fi

# Check 2: permissions.ask セクションに Edit / Write が入っていないこと
# NOTE: deny セクションの Edit/Write は二重防御として正当。ask のみをチェック
if [ -f "$SECURITY_TEMPLATE" ]; then
  # ask セクションのみ抽出して Edit/Write を検索
  ASK_EDIT_WRITE=$(sed -n '/"ask"/,/\]/p' "$SECURITY_TEMPLATE" | grep -E '"(Edit|Write|MultiEdit)' || true)
  if [ -n "$ASK_EDIT_WRITE" ]; then
    echo "  ❌ settings.security.json.template の ask に Edit/Write が含まれている"
    echo "      bypassPermissions 前提運用のため、Edit/Write は ask に入れないでください"
    BYPASS_ISSUES=$((BYPASS_ISSUES + 1))
  else
    echo "  ✅ ask に Edit/Write なし"
  fi
fi

# Check 2.5: Bash パーミッション構文の回帰チェック（prefix は :* 必須）
if [ -f "$SECURITY_TEMPLATE" ]; then
  # Portable regex: use [(] / [*] instead of escaping to avoid BSD grep issues.
  if grep -nEq 'Bash[(][^)]*[^:][*]' "$SECURITY_TEMPLATE"; then
    echo "  ❌ settings.security.json.template に不正な Bash パーミッション構文が含まれています"
    echo "      prefix マッチングは :* を使用してください（例: Bash(git status:*)）"
    grep -nE 'Bash[(][^)]*[^:][*]' "$SECURITY_TEMPLATE" | sed -n '1,3p' | sed 's/^/      /'
    BYPASS_ISSUES=$((BYPASS_ISSUES + 1))
  else
    echo "  ✅ Bash パーミッション構文OK (:*)"
  fi
fi

# Check 3: settings.local.json.template が存在し、defaultMode が documented な permission mode であること
# NOTE: shipped default は bypassPermissions を維持し、Auto Mode は teammate 実行経路の follow-up rollout として扱う
LOCAL_TEMPLATE="$PLUGIN_ROOT/templates/claude/settings.local.json.template"
if [ -f "$LOCAL_TEMPLATE" ]; then
  if grep -q '"defaultMode"[[:space:]]*:[[:space:]]*"bypassPermissions"' "$LOCAL_TEMPLATE"; then
    mode_val=$(grep '"defaultMode"' "$LOCAL_TEMPLATE" | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
    echo "  ✅ settings.local.json.template: defaultMode=${mode_val}"
  else
    echo "  ❌ settings.local.json.template に defaultMode=bypassPermissions がありません"
    BYPASS_ISSUES=$((BYPASS_ISSUES + 1))
  fi
else
  echo "  ❌ settings.local.json.template が存在しません"
  BYPASS_ISSUES=$((BYPASS_ISSUES + 1))
fi

# Check 4: managed sandbox precedence key は managed settings 専用。
# 通常配布の harness.toml / plugin settings / templates に混ぜると、
# Claude Code 本体の managed settings precedence と責務が曖昧になる。
MANAGED_SANDBOX_KEY_RE='allowManagedDomainsOnly|allowManagedReadPathsOnly'
MANAGED_SANDBOX_DEFAULT_TARGETS=(
  "$PLUGIN_ROOT/harness.toml"
  "$PLUGIN_ROOT/.claude-plugin/settings.json"
  "$PLUGIN_ROOT/templates/claude/settings.security.json.template"
  "$PLUGIN_ROOT/templates/sandbox-settings.json.template"
)
MANAGED_SANDBOX_ISSUES=0
for target in "${MANAGED_SANDBOX_DEFAULT_TARGETS[@]}"; do
  if [ ! -f "$target" ]; then
    continue
  fi
  FOUND_KEYS=$(grep -nE "$MANAGED_SANDBOX_KEY_RE" "$target" || true)
  if [ -n "$FOUND_KEYS" ]; then
    echo "  ❌ managed sandbox key は通常 template/default に入れないでください: ${target#$PLUGIN_ROOT/}"
    sed -n '1,3p' <<<"$FOUND_KEYS" | sed 's/^/      /'
    MANAGED_SANDBOX_ISSUES=$((MANAGED_SANDBOX_ISSUES + 1))
  fi
done

if [ $MANAGED_SANDBOX_ISSUES -eq 0 ]; then
  echo "  ✅ managed sandbox key は managed settings 専用として分離"
else
  BYPASS_ISSUES=$((BYPASS_ISSUES + MANAGED_SANDBOX_ISSUES))
fi

if [ $BYPASS_ISSUES -eq 0 ]; then
  echo "  ✅ bypassPermissions 前提運用OK"
else
  ERRORS=$((ERRORS + BYPASS_ISSUES))
fi

# ================================
# 9. ccp-* スキル廃止の回帰チェック
# ================================
echo ""
echo "🚫 [9/16] ccp-* スキル廃止の回帰チェック..."

CCP_ISSUES=0

# Check 1: skills の name: に ccp- が含まれていないこと
CCP_NAMES=$(grep -rn "^name: ccp-" "$PLUGIN_ROOT/skills/" 2>/dev/null || true)
if [ -n "$CCP_NAMES" ]; then
  echo "  ❌ skills に name: ccp-* が残存"
  sed -n '1,3p' <<<"$CCP_NAMES" | sed 's/^/      /'
  CCP_ISSUES=$((CCP_ISSUES + 1))
else
  echo "  ✅ skills に name: ccp-* なし"
fi

# Check 2: workflows の skill: に ccp- が含まれていないこと
CCP_WORKFLOWS=$(grep -rn "skill: ccp-" "$PLUGIN_ROOT/workflows/" 2>/dev/null || true)
if [ -n "$CCP_WORKFLOWS" ]; then
  echo "  ❌ workflows に skill: ccp-* が残存"
  sed -n '1,3p' <<<"$CCP_WORKFLOWS" | sed 's/^/      /'
  CCP_ISSUES=$((CCP_ISSUES + 1))
else
  echo "  ✅ workflows に skill: ccp-* なし"
fi

# Check 3: ccp-* ディレクトリが残っていないこと
CCP_DIRS=$(find "$PLUGIN_ROOT/skills" -type d -name "ccp-*" 2>/dev/null || true)
if [ -n "$CCP_DIRS" ]; then
  echo "  ❌ ccp-* ディレクトリが残存"
  sed -n '1,3p' <<<"$CCP_DIRS" | sed 's/^/      /'
  CCP_ISSUES=$((CCP_ISSUES + 1))
else
  echo "  ✅ ccp-* ディレクトリなし"
fi

if [ $CCP_ISSUES -eq 0 ]; then
  echo "  ✅ ccp-* スキル廃止OK"
else
  ERRORS=$((ERRORS + CCP_ISSUES))
fi

# ================================
# 10. スキル Mirror チェック
# ================================
echo ""
echo "📦 [10/16] スキル Mirror チェック..."

SKILLS_DIR="$PLUGIN_ROOT/skills"
CODEX_SKILLS_DIR="$PLUGIN_ROOT/skills-codex"
CODEX_MIRROR="$PLUGIN_ROOT/codex/.codex/skills"
OPENCODE_MIRROR="$PLUGIN_ROOT/opencode/skills"
MIRROR_ISSUES=0

# コアスキル（5動詞 harness- prefix + aux）の mirror チェック
# SSOT: skills/ → ミラー先: codex/.codex/skills/, opencode/skills/
# NOTE: mirror 側には disable-model-invocation: true が追加されている（自動発動抑制）
#       この差異は意図的なため、比較時に除外する
HARNESS_SKILLS="harness-plan harness-work harness-review harness-release harness-setup harness-sync harness-loop"

resolved_ssot_dir() {
  local mirror_name="$1"
  local skill="$2"
  if [ "$mirror_name" = "codex" ] && [ -d "$CODEX_SKILLS_DIR/$skill" ]; then
    printf '%s\n' "$CODEX_SKILLS_DIR/$skill"
    return 0
  fi
  printf '%s\n' "$SKILLS_DIR/$skill"
}

# mirror 比較用ヘルパー: disable-model-invocation 行を除外してファイル単位で diff
# mirror 固有の設定（自動発動抑制）は意図的な差異のため許容する
diff_mirror() {
  local src_dir="$1"
  local mirror_dir="$2"

  # ファイル一覧を比較（ファイル構成の一致を確認）
  local src_files mirror_files
  src_files="$(cd "$src_dir" && find . -type f | sort)"
  mirror_files="$(cd "$mirror_dir" && find . -type f | sort)"
  if [ "$src_files" != "$mirror_files" ]; then
    return 1
  fi

  # 各ファイルを個別に比較（disable-model-invocation 行のみ除外）
  local f compared=0
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    if ! diff -q \
      <(grep -v '^disable-model-invocation:' "$src_dir/$f") \
      <(grep -v '^disable-model-invocation:' "$mirror_dir/$f") \
      >/dev/null 2>&1; then
      return 1
    fi
    compared=$((compared + 1))
  done <<< "$src_files"

  # ファイル比較が1件も実行されなかった場合は安全側に倒す
  [ "$compared" -gt 0 ]
}

for skill in $HARNESS_SKILLS; do
  src="$(resolved_ssot_dir codex "$skill")"
  if [ ! -d "$src" ]; then
    echo "  ❌ $(basename "$(dirname "$src")")/$skill が存在しません（SSOT 欠落）"
    MIRROR_ISSUES=$((MIRROR_ISSUES + 1))
    continue
  fi

  for mirror_name in codex; do
    case "$mirror_name" in
      codex) mirror_root="$CODEX_MIRROR" ;;
    esac

    if [ ! -d "$mirror_root" ]; then
      continue
    fi

    mirror_path="$mirror_root/$skill"
    if [ ! -d "$mirror_path" ]; then
      echo "  ❌ $mirror_name: $skill がディレクトリとして存在しません"
      MIRROR_ISSUES=$((MIRROR_ISSUES + 1))
      continue
    fi

    if [ -L "$mirror_path" ]; then
      echo "  ❌ $mirror_name: $skill が symlink のままです"
      MIRROR_ISSUES=$((MIRROR_ISSUES + 1))
      continue
    fi

    mirror_src="$(resolved_ssot_dir "$mirror_name" "$skill")"
    if [ ! -d "$mirror_src" ]; then
      echo "  ❌ $mirror_name: SSOT が見つかりません (${mirror_src})"
      MIRROR_ISSUES=$((MIRROR_ISSUES + 1))
      continue
    fi

    if diff_mirror "$mirror_src" "$mirror_path"; then
      echo "  ✅ $mirror_name: $skill mirror is in sync"
    else
      echo "  ❌ $mirror_name: $skill mirror が SSOT と不一致"
      MIRROR_ISSUES=$((MIRROR_ISSUES + 1))
    fi
  done
done

if [ -d "$OPENCODE_MIRROR" ]; then
  if node "$PLUGIN_ROOT/scripts/validate-opencode.js" >/dev/null 2>&1; then
    echo "  ✅ opencode: generated skill mirror is valid"
  else
    echo "  ❌ opencode: generated skill mirror validation failed"
    MIRROR_ISSUES=$((MIRROR_ISSUES + 1))
  fi
fi

if [ $MIRROR_ISSUES -gt 0 ]; then
  ERRORS=$((ERRORS + MIRROR_ISSUES))
fi

# breezing alias は codex mirror のみ。
# Codex ネイティブ版が skills-codex/ にある場合はそちらを SSOT とみなす。
BREEZING_SRC="$SKILLS_DIR/breezing"
if [ -d "$CODEX_SKILLS_DIR/breezing" ]; then
  BREEZING_SRC="$CODEX_SKILLS_DIR/breezing"
fi

if [ -d "$BREEZING_SRC" ]; then
  BREEZING_CODEX="$CODEX_MIRROR/breezing"
  if [ ! -d "$BREEZING_CODEX" ]; then
    echo "  ❌ codex: breezing がディレクトリとして存在しません"
    ERRORS=$((ERRORS + 1))
  elif [ -L "$BREEZING_CODEX" ]; then
    echo "  ❌ codex: breezing が symlink のままです"
    ERRORS=$((ERRORS + 1))
  elif diff_mirror "$BREEZING_SRC" "$BREEZING_CODEX"; then
    echo "  ✅ codex: breezing mirror is in sync"
  else
    echo "  ❌ codex: breezing mirror が SSOT と不一致"
    ERRORS=$((ERRORS + 1))
  fi
else
  echo "  ❌ breezing の SSOT が見つかりません（skills/ または skills-codex/）"
  ERRORS=$((ERRORS + 1))
fi

FULL_MIRROR_LOG="$(mktemp "${TMPDIR:-/tmp}/harness-skill-mirrors.XXXXXX")"
if bash "$PLUGIN_ROOT/scripts/sync-skill-mirrors.sh" --check >"$FULL_MIRROR_LOG" 2>&1; then
  echo "  ✅ all shipped skill mirrors are in sync"
else
  echo "  ❌ full skill mirror check failed"
  sed 's/^/      /' "$FULL_MIRROR_LOG" | tail -80
  ERRORS=$((ERRORS + 1))
fi
rm -f "$FULL_MIRROR_LOG"

# ================================
# 10.5 Skill orchestration design contract
# ================================
echo ""
echo "🧭 [10.5/16] Skill orchestration design contract..."

SKILL_DESIGN_LOG="$(mktemp "${TMPDIR:-/tmp}/harness-skill-design.XXXXXX")"
if bash "$PLUGIN_ROOT/tests/test-skill-design-contract.sh" >"$SKILL_DESIGN_LOG" 2>&1; then
  echo "  ✅ core skill design metadata is consistent"
else
  echo "  ❌ core skill design metadata check failed"
  sed 's/^/      /' "$SKILL_DESIGN_LOG" | tail -80
  ERRORS=$((ERRORS + 1))
fi
rm -f "$SKILL_DESIGN_LOG"

# ================================
# 10.6 Weak-supervision contract tests
# ================================
echo ""
echo "🧪 [10.6/16] Weak-supervision contract tests..."

WEAK_SUPERVISION_LOG="$(mktemp "${TMPDIR:-/tmp}/harness-weak-supervision.XXXXXX")"
if bash "$PLUGIN_ROOT/tests/test-weak-supervision-report.sh" >"$WEAK_SUPERVISION_LOG" 2>&1; then
  echo "  ✅ weak-supervision report/schema fixtures pass"
else
  echo "  ❌ weak-supervision report/schema fixture check failed"
  sed 's/^/      /' "$WEAK_SUPERVISION_LOG" | tail -80
  ERRORS=$((ERRORS + 1))
fi
rm -f "$WEAK_SUPERVISION_LOG"

# ================================
# 11. CHANGELOG フォーマット検証
# ================================
echo ""
echo "📝 [11/16] CHANGELOG フォーマット検証..."

CHANGELOG_ISSUES=0

for changelog in "$PLUGIN_ROOT/CHANGELOG.md" "$PLUGIN_ROOT/CHANGELOG_ja.md"; do
  if [ ! -f "$changelog" ]; then
    continue
  fi

  cl_name=$(basename "$changelog")

  # Check 1: Keep a Changelog ヘッダー（## [x.y.z] - YYYY-MM-DD 形式）
  BAD_DATES=$(grep -nE '^\#\# \[[0-9]' "$changelog" | grep -vE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | grep -v "Unreleased" || true)
  if [ -n "$BAD_DATES" ]; then
    echo "  ❌ $cl_name: ISO 8601 日付でないエントリ"
    sed -n '1,3p' <<<"$BAD_DATES" | sed 's/^/      /'
    CHANGELOG_ISSUES=$((CHANGELOG_ISSUES + 1))
  fi

  # Check 2: 非標準セクション見出し（Keep a Changelog 1.1.0 の 6 種以外）
  NON_STANDARD=$(grep -nE '^\#\#\# ' "$changelog" \
    | grep -viE '(Added|Changed|Deprecated|Removed|Fixed|Security|What.*Changed|あなたにとって)' \
    | grep -viE '(Internal|Breaking|Migration|Summary|Before)' \
    || true)
  if [ -n "$NON_STANDARD" ]; then
    echo "  ⚠️ $cl_name: 非標準セクション見出し（確認推奨）"
    sed -n '1,3p' <<<"$NON_STANDARD" | sed 's/^/      /'
    # 警告のみ（エラーにはしない）
  fi

  # Check 3: [Unreleased] セクションが存在するか
  if ! grep -q '^\#\# \[Unreleased\]' "$changelog"; then
    echo "  ❌ $cl_name: [Unreleased] セクションがありません"
    CHANGELOG_ISSUES=$((CHANGELOG_ISSUES + 1))
  fi

  # Check 4: [Unreleased] 単一性（Phase 114.5 — auto-merge が見出しを無音で
  # 二重化する既知リスクの機械検知。## [Unreleased] は 1 回、セクション内の
  # ### Added / ### Fixed は各 1 以下でなければならない）
  UNRELEASED_COUNT=$(grep -c '^\#\# \[Unreleased\]' "$changelog" || true)
  if [ "$UNRELEASED_COUNT" -gt 1 ]; then
    echo "  ❌ $cl_name: [Unreleased] 見出しが ${UNRELEASED_COUNT} 回出現（1 回であるべき）"
    CHANGELOG_ISSUES=$((CHANGELOG_ISSUES + 1))
  elif [ "$UNRELEASED_COUNT" -eq 1 ]; then
    for heading in Added Fixed; do
      H_COUNT=$(awk '/^## \[Unreleased\]/{f=1;next} /^## \[/{f=0} f' "$changelog" \
        | grep -c "^### ${heading}" || true)
      if [ "$H_COUNT" -gt 1 ]; then
        echo "  ❌ $cl_name: [Unreleased] 内の ### ${heading} が ${H_COUNT} 回出現（merge 見出し二重化の疑い、1 以下であるべき）"
        CHANGELOG_ISSUES=$((CHANGELOG_ISSUES + 1))
      fi
    done
  fi
done

if [ $CHANGELOG_ISSUES -eq 0 ]; then
  echo "  ✅ CHANGELOG フォーマットOK"
else
  ERRORS=$((ERRORS + CHANGELOG_ISSUES))
fi

# ================================
# 12. README claim drift チェック
# ================================
echo ""
echo "📚 [12/16] README claim drift チェック..."

README_ISSUES=0
README_EN="$PLUGIN_ROOT/README.md"
README_JA="$PLUGIN_ROOT/README_ja.md"
SCOPE_DOC="$PLUGIN_ROOT/docs/distribution-scope.md"
RUBRIC_DOC="$PLUGIN_ROOT/docs/benchmark-rubric.md"
POSITIONING_DOC="$PLUGIN_ROOT/docs/positioning-notes.md"
WORK_ALL_DOC="$PLUGIN_ROOT/docs/evidence/work-all.md"

check_fixed_string() {
  local file_path="$1"
  local needle="$2"
  local label="$3"

  if [ ! -f "$file_path" ]; then
    echo "  ❌ ${label}: ファイルが存在しません: $file_path"
    README_ISSUES=$((README_ISSUES + 1))
    return
  fi

  if grep -qF "$needle" "$file_path"; then
    echo "  ✅ ${label}"
  else
    echo "  ❌ ${label}: 必須文字列が見つかりません"
    README_ISSUES=$((README_ISSUES + 1))
  fi
}

check_absent_string() {
  local file_path="$1"
  local needle="$2"
  local label="$3"

  if [ ! -f "$file_path" ]; then
    echo "  ❌ ${label}: ファイルが存在しません: $file_path"
    README_ISSUES=$((README_ISSUES + 1))
    return
  fi

  if grep -qF "$needle" "$file_path"; then
    echo "  ❌ ${label}: 古い claim が残っています"
    README_ISSUES=$((README_ISSUES + 1))
  else
    echo "  ✅ ${label}"
  fi
}

check_exists() {
  local file_path="$1"
  local label="$2"

  if [ -f "$file_path" ]; then
    echo "  ✅ ${label}"
  else
    echo "  ❌ ${label}: ファイルが存在しません"
    README_ISSUES=$((README_ISSUES + 1))
  fi
}

check_fixed_string "$README_EN" "$LATEST_RELEASE_URL" "README.md latest release link"
check_fixed_string "$README_JA" "$LATEST_RELEASE_URL" "README_ja.md latest release link"
check_fixed_string "$README_EN" "$LATEST_RELEASE_BADGE" "README.md latest release badge"
check_fixed_string "$README_JA" "$LATEST_RELEASE_BADGE" "README_ja.md latest release badge"

check_exists "$SCOPE_DOC" "distribution-scope.md"
check_exists "$RUBRIC_DOC" "benchmark-rubric.md"
check_exists "$POSITIONING_DOC" "positioning-notes.md"
check_exists "$WORK_ALL_DOC" "work-all evidence doc"

check_fixed_string "$README_EN" "docs/CLAUDE_CODE_COMPATIBILITY.md" "README.md compatibility doc link"
check_fixed_string "$README_EN" "docs/CURSOR_INTEGRATION.md" "README.md cursor doc link"
check_fixed_string "$README_EN" "docs/evidence/work-all.md" "README.md work-all evidence link"
check_fixed_string "$README_EN" "docs/distribution-scope.md" "README.md distribution scope link"
check_fixed_string "$README_EN" "5 verb skills" "README.md 5 verb skills message"
check_fixed_string "$README_EN" "Go-native guardrail engine" "README.md Go-native guardrail engine message"
check_absent_string "$README_EN" "Production-ready code." "README.md stale production-ready wording"

check_fixed_string "$README_JA" "docs/CLAUDE_CODE_COMPATIBILITY.md" "README_ja.md compatibility doc link"
check_fixed_string "$README_JA" "docs/CURSOR_INTEGRATION.md" "README_ja.md cursor doc link"
check_fixed_string "$README_JA" "docs/evidence/work-all.md" "README_ja.md work-all evidence link"
check_fixed_string "$README_JA" "docs/distribution-scope.md" "README_ja.md distribution scope link"
check_fixed_string "$README_JA" "5動詞スキル" "README_ja.md 5動詞スキル message"
check_fixed_string "$README_JA" "Go ネイティブガードレールエンジン" "README_ja.md Go ネイティブガードレールエンジン message"
check_absent_string "$README_JA" "本番品質のコード。" "README_ja.md stale production-ready wording"

check_fixed_string "$SCOPE_DOC" '| `commands/` | Compatibility-retained |' "distribution-scope commands classification"
check_fixed_string "$SCOPE_DOC" '| `mcp-server/` | Development-only and distribution-excluded |' "distribution-scope mcp-server classification"
check_fixed_string "$RUBRIC_DOC" "| Static evidence |" "benchmark-rubric static evidence"
check_fixed_string "$RUBRIC_DOC" "| Executed evidence |" "benchmark-rubric executed evidence"
check_fixed_string "$POSITIONING_DOC" "runtime enforcement" "positioning-notes runtime enforcement"

if bash "$PLUGIN_ROOT/tests/test-public-claims-contract.sh"; then
  echo "  ✅ public claims publication contract"
else
  echo "  ❌ public claims publication contract"
  README_ISSUES=$((README_ISSUES + 1))
fi

if [ $README_ISSUES -eq 0 ]; then
  echo "  ✅ README claim drift チェックOK"
else
  ERRORS=$((ERRORS + README_ISSUES))
fi

# ================================
# 13. EN/JA ビジュアル同期チェック
# ================================
echo ""
echo "🎨 [13/16] EN/JA ビジュアル同期チェック..."

VISUAL_EN_DIR="$PLUGIN_ROOT/assets/readme-visuals-en/generated"
VISUAL_JA_DIR="$PLUGIN_ROOT/assets/readme-visuals-ja/generated"
VISUAL_ISSUES=0

if [ -d "$VISUAL_EN_DIR" ] && [ -d "$VISUAL_JA_DIR" ]; then
  # EN にあるファイルが JA にも存在し、viewBox サイズが一致することを確認
  for en_svg in "$VISUAL_EN_DIR"/*.svg; do
    [ ! -f "$en_svg" ] && continue
    svg_name=$(basename "$en_svg")
    ja_svg="$VISUAL_JA_DIR/$svg_name"

    if [ ! -f "$ja_svg" ]; then
      echo "  ❌ JA 版が欠落: $svg_name"
      VISUAL_ISSUES=$((VISUAL_ISSUES + 1))
      continue
    fi

    # viewBox の高さを比較（構造の大幅な乖離を検出）
    en_viewbox=$(grep -o 'viewBox="[^"]*"' "$en_svg" | head -1)
    ja_viewbox=$(grep -o 'viewBox="[^"]*"' "$ja_svg" | head -1)
    if [ "$en_viewbox" != "$ja_viewbox" ]; then
      echo "  ⚠️ viewBox 不一致: $svg_name (EN: $en_viewbox / JA: $ja_viewbox)"
      # 警告のみ（日本語は文字幅が異なるため高さ差は許容）
    fi

    # テーブル行数を比較（<rect y= の数で簡易判定）
    en_rows=$(grep -c '<rect y=' "$en_svg" 2>/dev/null || echo 0)
    ja_rows=$(grep -c '<rect y=' "$ja_svg" 2>/dev/null || echo 0)
    if [ "$en_rows" != "$ja_rows" ]; then
      echo "  ❌ 行数不一致: $svg_name (EN: ${en_rows}行 / JA: ${ja_rows}行)"
      VISUAL_ISSUES=$((VISUAL_ISSUES + 1))
    else
      echo "  ✅ $svg_name (${en_rows}行)"
    fi
  done
else
  echo "  ⚠️ EN/JA ビジュアルディレクトリが見つかりません（スキップ）"
fi

if [ $VISUAL_ISSUES -gt 0 ]; then
  ERRORS=$((ERRORS + VISUAL_ISSUES))
fi

# ================================
# 14. i18n 回帰ゲート
# ================================
echo ""
echo "🌐 [14/16] i18n 回帰ゲート..."

I18N_ISSUES=0

run_i18n_gate() {
  local label="$1"
  shift

  local log_file
  log_file="$(mktemp "${TMPDIR:-/tmp}/harness-i18n-gate.XXXXXX")"

  if "$@" >"$log_file" 2>&1; then
    echo "  ✅ $label"
  else
    echo "  ❌ $label"
    sed 's/^/      /' "$log_file" | tail -80
    I18N_ISSUES=$((I18N_ISSUES + 1))
  fi

  rm -f "$log_file"
}

run_i18n_gate "translation metadata" \
  bash "$PLUGIN_ROOT/scripts/i18n/check-translations.sh"
run_i18n_gate "English default config/schema surfaces" \
  bash "$PLUGIN_ROOT/tests/test-i18n-default-language.sh"
run_i18n_gate "skill frontmatter bilingual metadata" \
  bash "$PLUGIN_ROOT/tests/test-i18n-skill-frontmatter.sh"
run_i18n_gate "locale roundtrip idempotency" \
  bash "$PLUGIN_ROOT/tests/test-i18n-locale-roundtrip.sh"
run_i18n_gate "setup language rendering" \
  bash "$PLUGIN_ROOT/tests/test-setup-language-rendering.sh"
run_i18n_gate "Japanese UX opt-in surfaces" \
  bash "$PLUGIN_ROOT/tests/test-i18n-japanese-ux-regression.sh"
run_i18n_gate "harness-work completion report locale and mirror parity" \
  bash "$PLUGIN_ROOT/tests/test-harness-work-completion-i18n.sh"

if [ $I18N_ISSUES -eq 0 ]; then
  echo "  ✅ i18n 回帰ゲートOK"
else
  ERRORS=$((ERRORS + I18N_ISSUES))
fi

# ================================
# 15. Shared File Discipline 規約の存在確認
# ================================
echo ""
echo "📜 [15/16] Shared File Discipline 規約の存在確認..."

SHARED_FILE_DISCIPLINE="$PLUGIN_ROOT/.claude/rules/shared-file-discipline.md"

if [ ! -f "$SHARED_FILE_DISCIPLINE" ]; then
  echo "  ❌ 不足: .claude/rules/shared-file-discipline.md"
  echo "      並列 worktree の共有ファイル編集規約 (Phase 92.1.3)。"
  echo "      参照: docs/team-composition.md, spec.md Tri-Tool Contract"
  ERRORS=$((ERRORS + 1))
else
  echo "  ✅ .claude/rules/shared-file-discipline.md"
  # 3 invariant のキーフレーズが規約本文に含まれることを確認（形骸化防止）
  for phrase in \
    "owner-assigned append-only" \
    "VERSION" \
    "worktree 内で bump しない" \
    "trunk で 1 回再生成"
  do
    if ! grep -q "$phrase" "$SHARED_FILE_DISCIPLINE"; then
      echo "  ❌ shared-file-discipline.md に必須フレーズが不足: $phrase"
      ERRORS=$((ERRORS + 1))
    fi
  done
  if grep -q "owner-assigned append-only" "$SHARED_FILE_DISCIPLINE" \
    && grep -q "worktree 内で bump しない" "$SHARED_FILE_DISCIPLINE" \
    && grep -q "trunk で 1 回再生成" "$SHARED_FILE_DISCIPLINE"; then
    echo "  ✅ 3 invariant キーフレーズ確認OK"
  fi
fi

# ================================
# 16. Reviewer cyber-safeguard 緩和の invariant
# ================================
echo ""
echo "🛡️ [16/16] Reviewer cyber-safeguard 緩和の invariant..."

REVIEWER_AGENT="$PLUGIN_ROOT/agents/reviewer.md"
SECURITY_PROFILE="$PLUGIN_ROOT/skills/harness-review/references/security-profile.md"

# (a) reviewer.md は非 Fable model に pin されていること（Fable 継承で cyber-safeguard 自動切替を防ぐ）
if [ ! -f "$REVIEWER_AGENT" ]; then
  echo "  ❌ 不足: agents/reviewer.md"
  ERRORS=$((ERRORS + 1))
else
  REVIEWER_MODEL="$(grep -E '^model:' "$REVIEWER_AGENT" | head -1 | sed 's/^model:[[:space:]]*//')"
  if [ -z "$REVIEWER_MODEL" ]; then
    echo "  ❌ agents/reviewer.md に model: pin がない（Fable 継承を防ぐため非 Fable pin が必須）"
    ERRORS=$((ERRORS + 1))
  elif printf '%s' "$REVIEWER_MODEL" | grep -qiE 'fable|inherit'; then
    echo "  ❌ agents/reviewer.md の model が Fable/inherit: $REVIEWER_MODEL"
    echo "      cyber-safeguard 自動切替を避けるため非 Fable の固定 model に pin すること"
    ERRORS=$((ERRORS + 1))
  else
    echo "  ✅ reviewer 非 Fable model pin: $REVIEWER_MODEL"
  fi
fi

# (b) security-profile.md に findings 還流契約のキーフレーズが存在すること（形骸化防止）
if [ ! -f "$SECURITY_PROFILE" ]; then
  echo "  ❌ 不足: skills/harness-review/references/security-profile.md"
  ERRORS=$((ERRORS + 1))
else
  for phrase in \
    "Fresh-context 隔離と findings 還流の契約" \
    "neutral 還流" \
    "safeguard invariant"
  do
    if ! grep -q "$phrase" "$SECURITY_PROFILE"; then
      echo "  ❌ security-profile.md に必須フレーズが不足: $phrase"
      ERRORS=$((ERRORS + 1))
    fi
  done
  if grep -q "Fresh-context 隔離と findings 還流の契約" "$SECURITY_PROFILE" \
    && grep -q "neutral 還流" "$SECURITY_PROFILE"; then
    echo "  ✅ findings 還流契約フレーズ確認OK"
  fi
fi

# ================================
# 17. Retired alias residue gate
# ================================
echo ""
echo "🧹 [17/17] Retired alias residue gate..."

HARNESS_BIN="$PLUGIN_ROOT/bin/harness"
if [ ! -x "$HARNESS_BIN" ]; then
  echo "  ❌ bin/harness が見つかりません（Lead 統合後に trunk で再生成）"
  ERRORS=$((ERRORS + 1))
else
  RETIRED_ALIAS_LOG="$(mktemp "${TMPDIR:-/tmp}/harness-retired-alias.XXXXXX")"
  if (cd "$PLUGIN_ROOT" && "$HARNESS_BIN" retired-alias scan) >"$RETIRED_ALIAS_LOG" 2>&1; then
    echo "  ✅ retired-alias scan: 0 hits"
  else
    echo "  ❌ retired-alias scan detected residue"
    sed 's/^/      /' "$RETIRED_ALIAS_LOG" | tail -40
    ERRORS=$((ERRORS + 1))
  fi
  rm -f "$RETIRED_ALIAS_LOG"
fi

# ================================
# 18. Night Watch patrol gate
# ================================
echo ""
echo "🌙 [18/19] Night Watch patrol gate..."

NIGHT_WATCH_SCHEMA="$PLUGIN_ROOT/templates/schemas/night-watch-report.v1.json"
NIGHT_WATCH_CONFIG="$PLUGIN_ROOT/templates/night-watch-config.yaml"
NIGHT_WATCH_REPORT="$PLUGIN_ROOT/scripts/night-watch-report.sh"
NIGHT_WATCH_INSTALL="$PLUGIN_ROOT/scripts/night-watch-install.sh"

for required in \
  "$NIGHT_WATCH_SCHEMA" \
  "$NIGHT_WATCH_CONFIG" \
  "$NIGHT_WATCH_REPORT" \
  "$NIGHT_WATCH_INSTALL" \
  "$PLUGIN_ROOT/templates/night-watch-cron.template"
do
  if [ ! -f "$required" ]; then
    echo "  ❌ 不足: ${required#$PLUGIN_ROOT/}"
    ERRORS=$((ERRORS + 1))
  fi
done

if [ -f "$NIGHT_WATCH_CONFIG" ]; then
  if ! grep -q 'stale_task_hours: 72' "$NIGHT_WATCH_CONFIG"; then
    echo "  ❌ night-watch-config.yaml missing stale_task_hours: 72"
    ERRORS=$((ERRORS + 1))
  fi
  if ! grep -q 'open_decision_hours: 168' "$NIGHT_WATCH_CONFIG"; then
    echo "  ❌ night-watch-config.yaml missing open_decision_hours: 168"
    ERRORS=$((ERRORS + 1))
  fi
  if ! grep -q 'NIGHT_WATCH_ENABLED: false' "$NIGHT_WATCH_CONFIG"; then
    echo "  ❌ night-watch-config.yaml missing default OFF marker"
    ERRORS=$((ERRORS + 1))
  fi
fi

if [ -x "$NIGHT_WATCH_REPORT" ] || [ -f "$NIGHT_WATCH_REPORT" ]; then
  NW_LOG="$(mktemp "${TMPDIR:-/tmp}/night-watch-report.XXXXXX")"
  if bash "$NIGHT_WATCH_REPORT" --dry-run >"$NW_LOG" 2>&1; then
    if command -v jq >/dev/null 2>&1; then
      if jq -e '.schema_version == "night-watch-report.v1"' "$NW_LOG" >/dev/null 2>&1; then
        echo "  ✅ night-watch-report --dry-run schema OK"
      else
        echo "  ❌ night-watch-report --dry-run JSON invalid"
        sed 's/^/      /' "$NW_LOG" | tail -20
        ERRORS=$((ERRORS + 1))
      fi
    else
      echo "  ⚠️ jq not found; skipping night-watch-report JSON assert"
    fi
  else
    echo "  ❌ night-watch-report --dry-run failed"
    sed 's/^/      /' "$NW_LOG" | tail -40
    ERRORS=$((ERRORS + 1))
  fi
  rm -f "$NW_LOG"
else
  echo "  ❌ scripts/night-watch-report.sh missing"
  ERRORS=$((ERRORS + 1))
fi

if bash "$PLUGIN_ROOT/tests/test-night-watch-install.sh" >/dev/null 2>&1; then
  echo "  ✅ night-watch opt-in install fixture test PASS"
else
  echo "  ❌ night-watch install fixture test failed"
  ERRORS=$((ERRORS + 1))
fi

if (cd "$PLUGIN_ROOT/go" && go test ./internal/nightwatch/... -count=1 >/dev/null 2>&1); then
  echo "  ✅ go test ./internal/nightwatch/... PASS"
else
  echo "  ❌ go test ./internal/nightwatch/... failed"
  ERRORS=$((ERRORS + 1))
fi

# ================================
# 19. Client Mirror drift gate
# ================================
echo ""
echo "🪞 [19/19] Client Mirror drift gate..."

MIRROR_SCHEMA="$PLUGIN_ROOT/templates/schemas/mirror-state.v1.json"
MIRROR_HOOK="$PLUGIN_ROOT/scripts/hook-handlers/skill-mirror-drift.sh"

for required in "$MIRROR_SCHEMA" "$MIRROR_HOOK"; do
  if [ ! -f "$required" ]; then
    echo "  ❌ 不足: ${required#$PLUGIN_ROOT/}"
    ERRORS=$((ERRORS + 1))
  fi
done

MIRROR_BIN="$PLUGIN_ROOT/bin/harness"
case "$(uname -s)" in
  Darwin) MIRROR_BIN="$PLUGIN_ROOT/bin/harness-darwin-$(uname -m | sed 's/x86_64/amd64/')" ;;
esac
[ -x "$MIRROR_BIN" ] || MIRROR_BIN="$PLUGIN_ROOT/bin/harness"

if [ -x "$MIRROR_BIN" ]; then
  MIRROR_LOG="$(mktemp "${TMPDIR:-/tmp}/mirror-verify.XXXXXX")"
  if (cd "$PLUGIN_ROOT" && "$MIRROR_BIN" mirror verify) >"$MIRROR_LOG" 2>&1; then
    echo "  ✅ mirror verify: 0 drift (in-sync)"
  else
    echo "  ❌ mirror verify detected drift"
    sed 's/^/      /' "$MIRROR_LOG" | tail -20
    ERRORS=$((ERRORS + 1))
  fi
  rm -f "$MIRROR_LOG"
else
  echo "  ⚠️ bin/harness missing; skipping mirror verify (build first)"
fi

if (cd "$PLUGIN_ROOT/go" && go test ./internal/clientmirror/... -count=1 >/dev/null 2>&1); then
  echo "  ✅ go test ./internal/clientmirror/... PASS"
else
  echo "  ❌ go test ./internal/clientmirror/... failed"
  ERRORS=$((ERRORS + 1))
fi


# ================================
# 20. Plans Depends/Status gate
# ================================
echo ""
echo "📌 [20/23] Plans Depends/Status gate..."

if (cd "$PLUGIN_ROOT/go" && go run ./cmd/harness plans check-deps "$PLUGIN_ROOT/Plans.md") >/tmp/harness-plans-deps.$$ 2>&1; then
  echo "  ✅ Plans dependency closure OK"
else
  echo "  ❌ Plans dependency closure failed"
  sed 's/^/      /' /tmp/harness-plans-deps.$$ | tail -40
  ERRORS=$((ERRORS + 1))
fi
rm -f /tmp/harness-plans-deps.$$

# ================================
# 21. Branch alignment ledger gate
# ================================
echo ""
echo "🧾 [21/23] Branch alignment ledger gate..."

if bash "$PLUGIN_ROOT/scripts/ci/check-branch-alignment-ledger.sh" >/tmp/harness-branch-ledger.$$ 2>&1; then
  echo "  ✅ branch alignment ledger OK"
else
  echo "  ❌ branch alignment ledger failed"
  sed 's/^/      /' /tmp/harness-branch-ledger.$$ | tail -40
  ERRORS=$((ERRORS + 1))
fi
rm -f /tmp/harness-branch-ledger.$$

# ================================
# 22. Binary/source drift gate
# ================================
echo ""
echo "🧱 [22/23] Binary/source drift gate..."

if bash "$PLUGIN_ROOT/scripts/ci/check-binary-source-drift.sh" >/tmp/harness-bin-drift.$$ 2>&1; then
  echo "  ✅ binary/source drift OK"
else
  echo "  ❌ binary/source drift failed"
  sed 's/^/      /' /tmp/harness-bin-drift.$$ | tail -40
  ERRORS=$((ERRORS + 1))
fi
rm -f /tmp/harness-bin-drift.$$

# ================================
# 23. i18n hookhandler ratchet
# ================================
echo ""
echo "🌐 [23/24] i18n hookhandler ratchet..."

if bash "$PLUGIN_ROOT/scripts/ci/check-i18n-hookhandler-ratchet.sh" "$PLUGIN_ROOT" >/tmp/harness-i18n-ratchet.$$ 2>&1; then
  sed 's/^/  /' /tmp/harness-i18n-ratchet.$$ | tail -2
else
  echo "  ❌ i18n hookhandler ratchet failed"
  sed 's/^/      /' /tmp/harness-i18n-ratchet.$$ | tail -10
  ERRORS=$((ERRORS + 1))
fi

# ================================
# 24. validate-plugin invocation pin（workflow-test-wiring ratchet）
# ================================
# validate-plugin.sh からのテスト呼び出し削除（coverage shrink）を、
# validate job とは別の CI gate で検知する（workflow-test-wiring.md 参照）
echo ""
echo "🧷 [24/24] validate-plugin invocation pin..."

if bash "$PLUGIN_ROOT/tests/test-validate-plugin-wiring.sh" >/tmp/harness-vp-wiring.$$ 2>&1; then
  sed 's/^/  ✅ /' /tmp/harness-vp-wiring.$$ | tail -1
else
  echo "  ❌ validate-plugin invocation pin failed（coverage shrink の疑い）"
  sed 's/^/      /' /tmp/harness-vp-wiring.$$ | tail -10
  ERRORS=$((ERRORS + 1))
fi
rm -f /tmp/harness-i18n-ratchet.$$

# ================================
# 結果サマリー
# ================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ $ERRORS -eq 0 ]; then
  echo "✅ すべてのチェックに合格しました"
  exit 0
else
  echo "❌ $ERRORS 個の問題が見つかりました"
  exit 1
fi
