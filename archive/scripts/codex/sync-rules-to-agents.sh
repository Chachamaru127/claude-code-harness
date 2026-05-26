#!/bin/bash
# sync-rules-to-agents.sh
# .claude/rules/*.md → codex/AGENTS.md への自動変換 + SSOT ドリフト検知
#
# 使い方:
#   ./scripts/codex/sync-rules-to-agents.sh           # 変換して書き込み
#   ./scripts/codex/sync-rules-to-agents.sh --check   # ドリフトチェックのみ（書き込みなし）
#   ./scripts/codex/sync-rules-to-agents.sh --dry-run # 変換内容をプレビュー
#
# 出力: codex/AGENTS.md の ## Rules セクションを更新

set -euo pipefail

# ===== 設定 =====
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
RULES_DIR="${PROJECT_ROOT}/.claude/rules"
AGENTS_MD="${PROJECT_ROOT}/codex/AGENTS.md"
HASH_FILE="${PROJECT_ROOT}/.claude/state/rules-hash.txt"
SECTION_MARKER_START="<!-- sync-rules-to-agents: start -->"
SECTION_MARKER_END="<!-- sync-rules-to-agents: end -->"

# ===== オプション解析 =====
MODE="write"
for arg in "$@"; do
  case "$arg" in
    --check)    MODE="check" ;;
    --dry-run)  MODE="dry-run" ;;
  esac
done

# ===== ルールファイル一覧取得 =====
# CLAUDE.md は自動生成のメモリコンテキストのみのため除外
RULE_FILES=()
while IFS= read -r f; do
  basename_f="$(basename "$f")"
  case "$basename_f" in
    CLAUDE.md) continue ;;  # memory context ファイルは除外
    *.md) RULE_FILES+=("$f") ;;
  esac
done < <(find "$RULES_DIR" -maxdepth 1 -name "*.md" | sort)

if [ ${#RULE_FILES[@]} -eq 0 ]; then
  echo "INFO: No rule files found in ${RULES_DIR}" >&2
  exit 0
fi

# ===== ルールコンテンツを AGENTS.md 形式に変換 =====
build_rules_section() {
  echo "${SECTION_MARKER_START}"
  echo ""
  echo "## Rules (from .claude/rules/)"
  echo ""
  echo "> このセクションは \`scripts/codex/sync-rules-to-agents.sh\` によって自動生成されます。"
  echo "> 直接編集しないでください。SSOT は \`.claude/rules/\` です。"
  echo ""
  echo "| ルールファイル | 説明 |"
  echo "|--------------|------|"

  for f in "${RULE_FILES[@]}"; do
    name="$(basename "$f" .md)"
    # frontmatter から description を取得
    desc=$(awk '/^---/{count++; next} count==1 && /^description:/{sub(/^description:[[:space:]]*/, ""); print; exit}' "$f" 2>/dev/null || true)
    if [ -z "$desc" ]; then
      # frontmatter がない場合は最初の H1 見出しを使用
      desc=$(grep -m1 '^# ' "$f" 2>/dev/null | sed 's/^# //' || true)
    fi
    [ -z "$desc" ] && desc="${name}"
    echo "| \`${name}.md\` | ${desc} |"
  done

  echo ""

  # 各ルールファイルの重要セクションを展開
  for f in "${RULE_FILES[@]}"; do
    name="$(basename "$f" .md)"
    echo "### ${name}"
    echo ""
    # codex-cli-only.md: Claude Code 向けルール（MCP 廃止/再登録禁止）は Codex 環境では不要
    # Codex 自身が codex exec を呼び出す必要はないため、スキップ（参照リンクのみ）
    if [ "$name" = "codex-cli-only" ]; then
      echo "> このルールは Claude Code 向けです。Codex 環境では適用しません。"
    # test-quality.md: 「絶対禁止事項」セクションを優先的に展開（AGENTS.md 形式テンプレート）
    # 禁止パターン表と対応フローを抽出して AGENTS.md に埋め込む
    elif [ "$name" = "test-quality" ]; then
      awk '
        BEGIN { in_front=0; done_front=0; in_prohibited=0; lines=0 }
        /^---/ && !done_front { in_front=!in_front; if (!in_front) done_front=1; next }
        in_front { next }
        !done_front { next }
        /^## 絶対禁止事項/ { in_prohibited=1 }
        /^## / && !/^## 絶対禁止事項/ && in_prohibited { in_prohibited=0 }
        in_prohibited && lines < 40 { print; lines++ }
      ' "$f"
    # implementation-quality.md: 「絶対禁止事項」と「実装時のセルフチェック」を展開
    # 形骸化実装禁止パターン表 + チェックリストを AGENTS.md に埋め込む
    elif [ "$name" = "implementation-quality" ]; then
      awk '
        BEGIN { in_front=0; done_front=0; in_section=0; lines=0 }
        /^---/ && !done_front { in_front=!in_front; if (!in_front) done_front=1; next }
        in_front { next }
        !done_front { next }
        /^## 絶対禁止事項|^## 実装時のセルフチェック/ { in_section=1 }
        /^## / && !/^## 絶対禁止事項/ && !/^## 実装時のセルフチェック/ && in_section { in_section=0 }
        in_section && lines < 60 { print; lines++ }
      ' "$f"
    else
      # 他のルールファイルは先頭 50 行を出力
      awk '
        BEGIN { in_front=0; done_front=0; lines=0 }
        /^---/ && !done_front { in_front=!in_front; if (!in_front) done_front=1; next }
        in_front { next }
        done_front && lines < 50 { print; lines++ }
      ' "$f"
    fi
    echo ""
    echo "<!-- 全文: .claude/rules/${name}.md -->"
    echo ""
  done

  echo "${SECTION_MARKER_END}"
}

# ===== 現在のルールコンテンツのハッシュを計算 =====
compute_rules_hash() {
  cat "${RULE_FILES[@]}" | shasum -a 256 | awk '{print $1}'
}

CURRENT_HASH="$(compute_rules_hash)"

# ===== --check モード: ドリフト検知のみ =====
if [ "$MODE" = "check" ]; then
  if [ ! -f "$HASH_FILE" ]; then
    echo "DRIFT: hash file not found (${HASH_FILE}). Run without --check to initialize." >&2
    exit 1
  fi
  SAVED_HASH="$(cat "$HASH_FILE" 2>/dev/null || true)"
  if [ "$CURRENT_HASH" = "$SAVED_HASH" ]; then
    echo "OK: rules are in sync (hash: ${CURRENT_HASH})"
    exit 0
  else
    echo "DRIFT: rules have changed since last sync." >&2
    echo "  saved:   ${SAVED_HASH}" >&2
    echo "  current: ${CURRENT_HASH}" >&2
    echo "  Run ./scripts/codex/sync-rules-to-agents.sh to update." >&2
    exit 1
  fi
fi

# ===== 変換コンテンツを tmpファイルに書き出し =====
NEW_SECTION_FILE="$(mktemp)"
build_rules_section > "$NEW_SECTION_FILE"

# ===== --dry-run モード: プレビューのみ =====
if [ "$MODE" = "dry-run" ]; then
  echo "=== DRY RUN: would write to ${AGENTS_MD} ==="
  echo ""
  cat "$NEW_SECTION_FILE"
  rm -f "$NEW_SECTION_FILE"
  exit 0
fi

# ===== write モード: AGENTS.md を更新 =====
if [ ! -f "$AGENTS_MD" ]; then
  echo "ERROR: ${AGENTS_MD} not found." >&2
  rm -f "$NEW_SECTION_FILE"
  exit 1
fi

# 既存セクションがあれば置換、なければ末尾に追加
if grep -q "${SECTION_MARKER_START}" "$AGENTS_MD" 2>/dev/null; then
  # 既存セクションを置換（awk でマーカー間を新ファイルで差し替え）
  TMP_FILE="$(mktemp)"
  awk -v new_file="$NEW_SECTION_FILE" \
    -v start="${SECTION_MARKER_START}" \
    -v end="${SECTION_MARKER_END}" '
    BEGIN { in_section=0; inserted=0 }
    $0 ~ start {
      in_section=1
      while ((getline line < new_file) > 0) { print line }
      close(new_file)
      inserted=1
      next
    }
    $0 ~ end   { in_section=0; next }
    !in_section { print }
  ' "$AGENTS_MD" > "$TMP_FILE"
  mv "$TMP_FILE" "$AGENTS_MD"
  echo "INFO: Updated existing Rules section in ${AGENTS_MD}"
else
  # セクションが存在しない場合は末尾に追加
  printf '\n' >> "$AGENTS_MD"
  cat "$NEW_SECTION_FILE" >> "$AGENTS_MD"
  echo "INFO: Appended Rules section to ${AGENTS_MD}"
fi

rm -f "$NEW_SECTION_FILE"

# ===== ハッシュを保存 =====
mkdir -p "$(dirname "$HASH_FILE")"
echo "$CURRENT_HASH" > "$HASH_FILE"
echo "INFO: Saved hash (${CURRENT_HASH}) to ${HASH_FILE}"

echo "DONE: sync complete."
