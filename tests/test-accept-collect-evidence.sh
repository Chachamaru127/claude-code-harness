#!/bin/bash
# tests/test-accept-collect-evidence.sh
# Phase 134.4 - scripts/accept-collect-evidence.sh の機械検証
#
# 検証観点:
#   (a) artifact 全揃いタスクで evidence が artifact 引用になる (present:true + data 転記)
#   (b) review-result.json の pending_validations (PENDING_BROWSER 由来) が
#       accept-evidence.v1.pending_validations にそのまま流れる
#   (d) review-result.json はシングルトンなので task.id 一致時のみ採用する鮮度チェック
#       (task.id 不一致 / task.id 欠落は present:false + stale 理由)
#   (c) worker-report 欠損の旧タスクでもエラーで落ちず「該当なし」を返す互換性
#       (4 artifact 全欠損でも exit 0 + valid JSON)
#
# read-only script なので実 .claude/state は一切触らず、tempdir を cwd にして実行する。

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT_DIR/scripts/accept-collect-evidence.sh"

PASS=0
FAIL=0
FAIL_MESSAGES=()

pass() { PASS=$((PASS + 1)); echo "✓ $1"; }
fail() { FAIL=$((FAIL + 1)); FAIL_MESSAGES+=("$1"); echo "✗ $1" >&2; }

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# ---- pre-checks ----

if [[ ! -x "$SCRIPT" ]]; then
  fail "accept-collect-evidence.sh not executable: $SCRIPT"
  echo "PASS=$PASS FAIL=$FAIL"
  exit 1
fi
pass "accept-collect-evidence.sh exists and is executable"

# ---- usage error ----

set +e
bash "$SCRIPT" 2>/dev/null
exit_code=$?
set -e
if [[ "$exit_code" -eq 1 ]]; then
  pass "exits 1 with no task-id arg"
else
  fail "should exit 1 with no task-id arg (got $exit_code)"
fi

# ---- ヘルパー: 各ケース用の作業ディレクトリを用意 ----

new_case_dir() {
  local case_name="$1"
  local dir="$TMP_DIR/$case_name"
  mkdir -p "$dir/.claude/state/review"
  printf '%s' "$dir"
}

# ==== Case A: artifact 全揃い (DoD a) ====

CASE_A_DIR="$(new_case_dir "case-all-present")"
TASK_ID="134.4"

cat > "$CASE_A_DIR/.claude/state/review/${TASK_ID}.worker-report.json" <<'EOF'
{"schema_version":"worker-report.v1","task_id":"134.4","self_review":["ok"]}
EOF
cat > "$CASE_A_DIR/.claude/state/review-result.json" <<EOF
{"schema_version":"review-result.v1","verdict":"APPROVE","task":{"id":"${TASK_ID}"},"pending_validations":[]}
EOF
cat > "$CASE_A_DIR/.claude/state/review/${TASK_ID}.runtime-review.json" <<'EOF'
{"schema_version":"runtime-review.v1","result":"pass"}
EOF
cat > "$CASE_A_DIR/.claude/state/review/${TASK_ID}.browser-result.json" <<'EOF'
{"schema_version":"browser-review-result.v1","browser_verdict":"PASS"}
EOF

OUT_A="$(cd "$CASE_A_DIR" && bash "$SCRIPT" "$TASK_ID")"

if jq -e '.' <<<"$OUT_A" >/dev/null 2>&1; then
  pass "[all-present] output is valid JSON"
else
  fail "[all-present] output is not valid JSON: $OUT_A"
fi

if jq -e '.schema_version == "accept-evidence.v1"' <<<"$OUT_A" >/dev/null 2>&1; then
  pass "[all-present] schema_version = accept-evidence.v1"
else
  fail "[all-present] schema_version mismatch"
fi

if jq -e --arg t "$TASK_ID" '.task_id == $t' <<<"$OUT_A" >/dev/null 2>&1; then
  pass "[all-present] task_id propagates"
else
  fail "[all-present] task_id mismatch"
fi

for field in worker_report review_result runtime_review browser_result; do
  if jq -e --arg f "$field" '.[$f].present == true' <<<"$OUT_A" >/dev/null 2>&1; then
    pass "[all-present] $field.present == true"
  else
    fail "[all-present] $field.present should be true"
  fi
  if jq -e --arg f "$field" '.[$f].data != null' <<<"$OUT_A" >/dev/null 2>&1; then
    pass "[all-present] $field.data is populated (artifact 引用、DoD a)"
  else
    fail "[all-present] $field.data should be populated"
  fi
done

if jq -e '.worker_report.data.self_review == ["ok"]' <<<"$OUT_A" >/dev/null 2>&1; then
  pass "[all-present] worker_report.data is a literal transcription of the artifact (no new claims)"
else
  fail "[all-present] worker_report.data does not match source artifact"
fi

if jq -e '.pending_validations == []' <<<"$OUT_A" >/dev/null 2>&1; then
  pass "[all-present] pending_validations is empty when review-result has none"
else
  fail "[all-present] pending_validations should be empty"
fi

# ==== Case B: review-result.json に PENDING_BROWSER 由来 pending_validations (DoD b) ====

CASE_B_DIR="$(new_case_dir "case-pending-browser")"

cat > "$CASE_B_DIR/.claude/state/review/${TASK_ID}.worker-report.json" <<'EOF'
{"schema_version":"worker-report.v1","task_id":"134.4"}
EOF
cat > "$CASE_B_DIR/.claude/state/review-result.json" <<EOF
{
  "schema_version": "review-result.v1",
  "verdict": "APPROVE",
  "task": {"id": "${TASK_ID}"},
  "browser_verdict": "PENDING_BROWSER",
  "pending_validations": [
    {"layer": "browser", "reason": "browser verdict is PENDING_BROWSER"}
  ]
}
EOF

OUT_B="$(cd "$CASE_B_DIR" && bash "$SCRIPT" "$TASK_ID")"

if jq -e '.review_result.present == true' <<<"$OUT_B" >/dev/null 2>&1; then
  pass "[pending-browser] review_result.present == true (task.id matched)"
else
  fail "[pending-browser] review_result.present should be true"
fi

if jq -e '(.pending_validations | length) == 1 and .pending_validations[0].layer == "browser"' <<<"$OUT_B" >/dev/null 2>&1; then
  pass "[pending-browser] pending_validations carries the browser layer (DoD b)"
else
  fail "[pending-browser] pending_validations missing browser layer"
fi

if jq -e '.pending_validations[0].reason | contains("PENDING_BROWSER")' <<<"$OUT_B" >/dev/null 2>&1; then
  pass "[pending-browser] pending_validations reason quotes PENDING_BROWSER literally"
else
  fail "[pending-browser] pending_validations reason missing PENDING_BROWSER"
fi

# runtime/browser artifact 自体は欠損 (この artifact 名では書いていない)
if jq -e '.runtime_review.present == false and .runtime_review.reason == "file not found"' <<<"$OUT_B" >/dev/null 2>&1; then
  pass "[pending-browser] runtime_review absent artifact reports file not found"
else
  fail "[pending-browser] runtime_review absent-artifact reporting incorrect"
fi

# ==== Case C: review-result.json の task.id が別タスク (鮮度チェック、シングルトン混入防止) ====

CASE_C_DIR="$(new_case_dir "case-stale-review-result")"

cat > "$CASE_C_DIR/.claude/state/review-result.json" <<'EOF'
{"schema_version":"review-result.v1","verdict":"APPROVE","task":{"id":"999.9"},"pending_validations":[]}
EOF

OUT_C="$(cd "$CASE_C_DIR" && bash "$SCRIPT" "$TASK_ID")"

if jq -e '.review_result.present == false' <<<"$OUT_C" >/dev/null 2>&1; then
  pass "[stale-review-result] review_result.present == false on task.id mismatch (freshness check)"
else
  fail "[stale-review-result] review_result.present should be false on task.id mismatch"
fi

if jq -e '.review_result.reason | (contains("stale") and contains("999.9") and contains("134.4"))' <<<"$OUT_C" >/dev/null 2>&1; then
  pass "[stale-review-result] reason names both the found and expected task.id"
else
  fail "[stale-review-result] reason does not explain the mismatch"
fi

if jq -e '.pending_validations == []' <<<"$OUT_C" >/dev/null 2>&1; then
  pass "[stale-review-result] pending_validations does not leak from the mismatched review-result.json"
else
  fail "[stale-review-result] pending_validations should be empty when review-result is stale"
fi

# ==== Case D: review-result.json に task.id フィールド自体が無い (旧 schema 互換) ====

CASE_D_DIR="$(new_case_dir "case-no-task-id")"

cat > "$CASE_D_DIR/.claude/state/review-result.json" <<'EOF'
{"schema_version":"review-result.v1","verdict":"APPROVE"}
EOF

OUT_D="$(cd "$CASE_D_DIR" && bash "$SCRIPT" "$TASK_ID")"

if jq -e '.review_result.present == false and (.review_result.reason | contains("stale") and contains("no task.id"))' <<<"$OUT_D" >/dev/null 2>&1; then
  pass "[no-task-id] review-result.json without task.id is treated as stale, not a crash"
else
  fail "[no-task-id] missing task.id should be reported as stale"
fi

# ==== Case E: 4 artifact 全欠損 (DoD c: worker-report 欠損の旧タスク互換) ====

CASE_E_DIR="$(new_case_dir "case-all-missing")"
OLD_TASK_ID="42.0"

set +e
OUT_E="$(cd "$CASE_E_DIR" && bash "$SCRIPT" "$OLD_TASK_ID")"
exit_code=$?
set -e

if [[ "$exit_code" -eq 0 ]]; then
  pass "[all-missing] exits 0 even when all 4 artifacts are absent (DoD c)"
else
  fail "[all-missing] should exit 0 on total absence (got $exit_code)"
fi

if jq -e '.' <<<"$OUT_E" >/dev/null 2>&1; then
  pass "[all-missing] output is still valid JSON"
else
  fail "[all-missing] output is not valid JSON: $OUT_E"
fi

for field in worker_report review_result runtime_review browser_result; do
  if jq -e --arg f "$field" '.[$f].present == false and .[$f].data == null' <<<"$OUT_E" >/dev/null 2>&1; then
    pass "[all-missing] $field reports absent (該当なし) without error"
  else
    fail "[all-missing] $field should report present:false, data:null"
  fi
done

if jq -e '.pending_validations == []' <<<"$OUT_E" >/dev/null 2>&1; then
  pass "[all-missing] pending_validations defaults to empty array"
else
  fail "[all-missing] pending_validations should default to []"
fi

# ==== Case F: worker-report.json が壊れた JSON (invalid JSON 縮退) ====

CASE_F_DIR="$(new_case_dir "case-invalid-json")"
printf 'not json {' > "$CASE_F_DIR/.claude/state/review/${TASK_ID}.worker-report.json"

set +e
OUT_F="$(cd "$CASE_F_DIR" && bash "$SCRIPT" "$TASK_ID")"
exit_code=$?
set -e

if [[ "$exit_code" -eq 0 ]]; then
  pass "[invalid-json] exits 0 on malformed artifact JSON"
else
  fail "[invalid-json] should exit 0 on malformed artifact JSON (got $exit_code)"
fi

if jq -e '.worker_report.present == false and .worker_report.reason == "invalid JSON"' <<<"$OUT_F" >/dev/null 2>&1; then
  pass "[invalid-json] worker_report reports invalid JSON reason"
else
  fail "[invalid-json] worker_report should report invalid JSON reason"
fi

# ==== Case G: browser-result.json に video artifact あり (Phase 134.6 demo_artifacts 流し込み) ====

CASE_G_DIR="$(new_case_dir "case-video-artifact")"

cat > "$CASE_G_DIR/.claude/state/review/${TASK_ID}.browser-result.json" <<'EOF'
{
  "schema_version": "browser-review-result.v1",
  "browser_verdict": "APPROVE",
  "artifacts": [
    {"kind": "video", "path": "test-results/nested/trace.webm"},
    {"kind": "text", "note": "use.video 未設定の可能性"}
  ]
}
EOF

OUT_G="$(cd "$CASE_G_DIR" && bash "$SCRIPT" "$TASK_ID")"

if jq -e '(.demo_artifacts | length) == 1 and .demo_artifacts[0].kind == "video"' <<<"$OUT_G" >/dev/null 2>&1; then
  pass "[video-artifact] demo_artifacts carries only the kind:video entry"
else
  fail "[video-artifact] demo_artifacts should carry exactly the kind:video entry"
fi

if jq -e '.demo_artifacts[0].path == "test-results/nested/trace.webm"' <<<"$OUT_G" >/dev/null 2>&1; then
  pass "[video-artifact] demo_artifacts[0].path matches browser_result artifact path"
else
  fail "[video-artifact] demo_artifacts[0].path mismatch"
fi

# ==== Case H: browser-result.json が欠損 → demo_artifacts は空配列 ====

CASE_H_DIR="$(new_case_dir "case-no-browser-result")"

OUT_H="$(cd "$CASE_H_DIR" && bash "$SCRIPT" "$TASK_ID")"

if jq -e '.demo_artifacts == []' <<<"$OUT_H" >/dev/null 2>&1; then
  pass "[no-browser-result] demo_artifacts defaults to [] when browser_result is absent"
else
  fail "[no-browser-result] demo_artifacts should default to []"
fi

# ==== Summary ====

echo ""
echo "============================================"
echo "PASS=$PASS FAIL=$FAIL"
if [[ "$FAIL" -gt 0 ]]; then
  echo ""
  echo "FAIL details:" >&2
  for msg in "${FAIL_MESSAGES[@]}"; do
    echo "  - $msg" >&2
  done
  exit 1
fi
echo "All assertions passed."
exit 0
