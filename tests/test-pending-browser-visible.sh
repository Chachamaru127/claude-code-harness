#!/bin/bash
# tests/test-pending-browser-visible.sh
# Phase 134.8 - 実効性契約テスト: PENDING_BROWSER が中間 (write-review-result.sh) から
# 出口 (accept-collect-evidence.sh) まで無言で縮退せず可視のまま伝わり、Accept surface が
# 「passed:false」「ship にしない」と判定する契約を持つことを end-to-end で確認する。
#
# harness-accept の Step 4/5 (criterion 単位の passed:false 判定、ship→wait への丸め) は
# LLM が SKILL.md の記述に従って実行する prose 契約であり、スクリプトが直接 "passed:false"
# を計算するわけではない。このテストは:
#   (機械側) PENDING_BROWSER の browser_verdict → write-review-result.sh →
#            accept-collect-evidence.sh の 2 段が実スクリプトで pending_validations を
#            落とさず伝播すること (mechanical chain)
#   (契約側) skills/harness-accept/SKILL.md が「pending_validations 該当時は passed:false」
#            「pending 該当 criteria が 1 件以上なら ship にしない (wait に丸める)」を
#            明文化していること (documented contract, LLM 実行側の grep 検証)
# の両方を検証する。
#
# Usage: bash tests/test-pending-browser-visible.sh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WRITE_REVIEW_RESULT="${WRITE_REVIEW_RESULT_SCRIPT:-$ROOT_DIR/scripts/write-review-result.sh}"
ACCEPT_COLLECT_EVIDENCE="${ACCEPT_COLLECT_EVIDENCE_SCRIPT:-$ROOT_DIR/scripts/accept-collect-evidence.sh}"
HARNESS_ACCEPT_SKILL="${HARNESS_ACCEPT_SKILL_FILE:-$ROOT_DIR/skills/harness-accept/SKILL.md}"

PASS=0
FAIL=0
pass() { PASS=$((PASS + 1)); echo "✓ $1"; }
fail() { FAIL=$((FAIL + 1)); echo "✗ $1" >&2; }

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/pending-browser-visible-test.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT

TASK_ID="134.8-pb"
PROJECT_DIR="$WORK_DIR/project"
mkdir -p "$PROJECT_DIR/.claude/state/review"

# ==== ステージ 1: PENDING_BROWSER 判定の reviewer 入力 → write-review-result.sh ====

cat > "$WORK_DIR/review-input.json" <<EOF
{
  "verdict": "APPROVE",
  "reviewer_profile": "browser",
  "browser_verdict": "PENDING_BROWSER",
  "task": {"id": "${TASK_ID}", "title": "pending browser visibility"}
}
EOF

REVIEW_RESULT_PATH="$PROJECT_DIR/.claude/state/review-result.json"
if ! bash "$WRITE_REVIEW_RESULT" "$WORK_DIR/review-input.json" "" "$REVIEW_RESULT_PATH" >/dev/null 2>"$WORK_DIR/write-review-result.err"; then
  fail "write-review-result.sh がエラー終了した: $(cat "$WORK_DIR/write-review-result.err")"
  echo "PASS=$PASS FAIL=$FAIL"
  exit 1
fi
pass "write-review-result.sh が PENDING_BROWSER 入力を処理した"

if jq -e '.browser_verdict == "PENDING_BROWSER"' "$REVIEW_RESULT_PATH" >/dev/null 2>&1; then
  pass "review-result.json.browser_verdict == PENDING_BROWSER"
else
  fail "review-result.json.browser_verdict が PENDING_BROWSER でない: $(jq -c . "$REVIEW_RESULT_PATH")"
fi

if jq -e '(.pending_validations | length) == 1 and .pending_validations[0].layer == "browser"' "$REVIEW_RESULT_PATH" >/dev/null 2>&1; then
  pass "review-result.json.pending_validations に browser layer が積まれる (中間の fail-visible producer, Phase 134.2)"
else
  PV_ACTUAL="$(jq -c '.pending_validations // "missing"' "$REVIEW_RESULT_PATH" 2>&1)"
  fail "review-result.json.pending_validations に browser layer が無い: $PV_ACTUAL"
fi

# combine_verdict の語彙は変わらない regression (Phase 134.2 DoD の再確認)
if jq -e '.verdict == "APPROVE"' "$REVIEW_RESULT_PATH" >/dev/null 2>&1; then
  pass "PENDING_BROWSER でも combine_verdict の語彙 (APPROVE) は変わらない (静的判定を維持する設計どおり)"
else
  fail "combine_verdict の verdict 語彙が変化した: $(jq -r '.verdict' "$REVIEW_RESULT_PATH")"
fi

# ==== ステージ 2: review-result.json → accept-collect-evidence.sh ====

EVIDENCE_JSON="$(cd "$PROJECT_DIR" && bash "$ACCEPT_COLLECT_EVIDENCE" "$TASK_ID" 2>"$WORK_DIR/accept-collect-evidence.err")"
if [ -z "$EVIDENCE_JSON" ]; then
  fail "accept-collect-evidence.sh が出力を返さなかった: $(cat "$WORK_DIR/accept-collect-evidence.err")"
  echo "PASS=$PASS FAIL=$FAIL"
  exit 1
fi
pass "accept-collect-evidence.sh が accept-evidence.v1 を返した"

if jq -e '.review_result.present == true' <<<"$EVIDENCE_JSON" >/dev/null 2>&1; then
  pass "accept-evidence.v1.review_result.present == true (task.id 一致で採用された)"
else
  fail "accept-evidence.v1.review_result.present が true でない: $(jq -c '.review_result' <<<"$EVIDENCE_JSON")"
fi

if jq -e '(.pending_validations | length) == 1 and .pending_validations[0].layer == "browser"' <<<"$EVIDENCE_JSON" >/dev/null 2>&1; then
  pass "accept-evidence.v1.pending_validations に browser layer が中間から出口まで無言縮退せず伝わる (end-to-end)"
else
  EV_PV_ACTUAL="$(jq -c '.pending_validations // "missing"' <<<"$EVIDENCE_JSON" 2>&1)"
  fail "accept-evidence.v1.pending_validations に browser layer が伝わっていない: $EV_PV_ACTUAL"
fi

# ==== ステージ 3: 出口契約 (SKILL.md の prose) が pending → passed:false / ship を wait に丸める、を明文化しているか ====

if [ -f "$HARNESS_ACCEPT_SKILL" ] && grep -q 'pending_validations.*該当.*layer.*passed: false\|passed: false' "$HARNESS_ACCEPT_SKILL"; then
  pass "SKILL.md が pending_validations 該当時に passed: false と記述している"
else
  fail "SKILL.md に pending_validations → passed: false の記述が無い"
fi

if [ -f "$HARNESS_ACCEPT_SKILL" ] && grep -q 'pending_count >= 1' "$HARNESS_ACCEPT_SKILL" && grep -q 'wait に丸め' "$HARNESS_ACCEPT_SKILL"; then
  pass "SKILL.md が pending 該当 criteria 1 件以上で ship を wait に丸めるロジックを記述している (recommendation が ship にならない)"
else
  fail "SKILL.md に pending 補正 (ship→wait) のロジック記述が無い"
fi

# ==== サマリ ====
echo ""
echo "============================================"
echo "PASS=$PASS FAIL=$FAIL"
if [ "$FAIL" -eq 0 ]; then
  echo "All assertions passed."
  exit 0
fi
exit 1
