#!/bin/bash
# tests/test-audit-ui-presence.sh
# Phase 65.5.2 - 監査 UI が 3 HTML 全てに統合されているか機械検証
#
# 検証ケース (Plans.md §65.5.2 DoD a-d):
#   (a) 3 種 HTML テンプレートに audit-trail セクションが共通追加
#   (b) 4 項目 (検索範囲 / 参照 ID / redact 件数 / audit log) が表示
#   (c) audit log が JSON Lines で human-readable
#   (d) grep -c "audit-trail" で 3 HTML 全てに含まれる

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

PASS=0
FAIL=0
FAIL_MESSAGES=()

pass() { PASS=$((PASS + 1)); echo "✓ $1"; }
fail() { FAIL=$((FAIL + 1)); FAIL_MESSAGES+=("$1"); echo "✗ $1" >&2; }

# ============================================================
# (a)(d) 3 templates に audit-trail セクション存在
# ============================================================

for tpl in plan-brief accept progress; do
  TEMPLATE="$ROOT_DIR/templates/html/${tpl}.html.template"
  if [[ ! -f "$TEMPLATE" ]]; then
    fail "(a) template missing: $TEMPLATE"
    continue
  fi
  if grep -q 'class="audit-trail"' "$TEMPLATE"; then
    pass "(a)(d) ${tpl}.html.template に audit-trail セクションあり"
  else
    fail "(a)(d) ${tpl}.html.template に audit-trail なし"
  fi
done

# ============================================================
# (b) 4 項目 (検索範囲 / 参照 ID / redact 件数 / audit log) 表示
# ============================================================

for tpl in plan-brief accept progress; do
  TEMPLATE="$ROOT_DIR/templates/html/${tpl}.html.template"
  ALL_FIELDS_OK="true"
  for field in audit_search_scope audit_referenced_ids audit_redaction_summary audit_log_path; do
    if grep -q "{{${field}}}" "$TEMPLATE"; then
      :
    else
      fail "(b) ${tpl}.html.template に {{${field}}} placeholder なし"
      ALL_FIELDS_OK="false"
    fi
  done
  if [[ "$ALL_FIELDS_OK" == "true" ]]; then
    pass "(b) ${tpl}.html.template に 4 項目 placeholder 全部あり"
  fi
done

# ============================================================
# (b) 4 項目のラベル (検索範囲 / 参照 ID / redact 件数 / audit log) も表示
# ============================================================

for tpl in plan-brief accept progress; do
  TEMPLATE="$ROOT_DIR/templates/html/${tpl}.html.template"
  ALL_LABELS_OK="true"
  for label in "検索範囲" "参照 ID" "redact 件数" "audit log"; do
    if grep -q "$label" "$TEMPLATE"; then
      :
    else
      fail "(b) ${tpl}.html.template に '$label' ラベルなし"
      ALL_LABELS_OK="false"
    fi
  done
  if [[ "$ALL_LABELS_OK" == "true" ]]; then
    pass "(b) ${tpl}.html.template に 4 項目ラベル (検索範囲/参照ID/redact 件数/audit log) 全部あり"
  fi
done

# ============================================================
# (b) 「🔍 この artifact の根拠」見出しが 3 HTML 全てに存在
# ============================================================

for tpl in plan-brief accept progress; do
  TEMPLATE="$ROOT_DIR/templates/html/${tpl}.html.template"
  if grep -q "この artifact の根拠" "$TEMPLATE"; then
    pass "(b) ${tpl}.html.template に '🔍 この artifact の根拠' 見出しあり"
  else
    fail "(b) ${tpl}.html.template に 見出しなし"
  fi
done

# ============================================================
# (c) audit log が JSON Lines で human-readable (cross-project-audit-log.sh の出力)
# ============================================================

# audit-log.sh の実 output を生成して検証
TMP_AUDIT="$(mktemp "${TMPDIR:-/tmp}/audit-test.XXXXXX")"
trap 'rm -f "$TMP_AUDIT"' EXIT

bash "$ROOT_DIR/scripts/cross-project-audit-log.sh" \
  --group "TestG" --members "p1,p2" \
  --query-hash "$(printf 'q' | shasum -a 256 | awk '{print $1}')" \
  --dict-count 1 --ner-count 0 \
  --passed-final-scan true \
  --out "$TMP_AUDIT" 2>/dev/null

if jq -e '.schema_version == "cross-project-audit.v1"' "$TMP_AUDIT" >/dev/null 2>&1; then
  pass "(c) audit log の JSON Lines が parseable + schema 準拠"
else
  fail "(c) audit log JSON parse 失敗"
fi

if [[ "$(wc -l < "$TMP_AUDIT" | tr -d ' ')" == "1" ]]; then
  pass "(c) audit log は 1 行 1 JSON (JSON Lines 規約準拠)"
else
  fail "(c) audit log 行数 != 1"
fi

# ============================================================
# Render with audit fields injected (smoke test)
# ============================================================

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/test-audit-ui-render.XXXXXX")"
trap "rm -f '$TMP_AUDIT'; rm -rf '$TMP_DIR'" EXIT

# progress fixture with audit fields
SNAP="$TMP_DIR/snap.json"
bash "$ROOT_DIR/scripts/progress-snapshot.sh" --plans Plans.md --project test > "$SNAP"

# Inject audit fields
SNAP2="$TMP_DIR/snap-audit.json"
jq '. + {
  audit_search_scope: "project=test / group=Personal Tools",
  audit_referenced_ids: "D43, P29, past-plans×3",
  audit_redaction_summary: "dict 2 件 + NER 1 件",
  audit_log_path: ".claude/state/audit/cross-project-search.jsonl"
}' "$SNAP" > "$SNAP2"

HTML="$TMP_DIR/audit-test.html"
bash "$ROOT_DIR/scripts/render-html.sh" --template progress --data "$SNAP2" --out "$HTML" 2>/dev/null

if grep -q "project=test / group=Personal Tools" "$HTML" && \
   grep -q "D43, P29, past-plans×3" "$HTML" && \
   grep -q "dict 2 件 + NER 1 件" "$HTML"; then
  pass "(b) Progress HTML render: 4 項目の値が出力に展開"
else
  fail "(b) audit field rendering broken"
fi

# ============================================================
# Result
# ============================================================

echo ""
echo "============================================================"
echo "Test Summary (test-audit-ui-presence.sh)"
echo "============================================================"
echo "PASS: $PASS"
echo "FAIL: $FAIL"

if [[ $FAIL -gt 0 ]]; then
  echo ""
  echo "Failed tests:"
  for msg in "${FAIL_MESSAGES[@]}"; do
    echo "  - $msg"
  done
  exit 1
fi

exit 0
