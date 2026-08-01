#!/bin/bash
# test-detect-review-plateau.sh
# detect-review-plateau.sh のゴールデンフィクスチャテスト
#
# Usage: ./tests/test-detect-review-plateau.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPT="$PROJECT_ROOT/scripts/detect-review-plateau.sh"
FIXTURE_DIR="$PROJECT_ROOT/tests/fixtures/review-calibration"

# --- ユーティリティ ---
PASS=0
FAIL=0

pass() {
  echo "  [PASS] $1"
  PASS=$(( PASS + 1 ))
}

fail() {
  echo "  [FAIL] $1"
  FAIL=$(( FAIL + 1 ))
}

run_case() {
  local label="$1"
  local task_id="$2"
  local fixture="$3"
  local expected_status="$4"
  local expected_exit="$5"

  local actual_output actual_exit actual_status

  # detect-review-plateau.sh を実行（set -e を回避するため || で exit code を捕捉）
  actual_output="$(bash "$SCRIPT" "$task_id" --calibration-file "$fixture" 2>&1)" || actual_exit=$?
  actual_exit="${actual_exit:-0}"

  # stdout から STATUS 行を抽出
  actual_status="$(echo "$actual_output" | grep '^STATUS:' | awk '{print $2}')"

  # exit code チェック
  if [ "$actual_exit" = "$expected_exit" ]; then
    pass "$label: exit code = $expected_exit"
  else
    fail "$label: exit code expected=$expected_exit actual=$actual_exit"
  fi

  # STATUS チェック
  if [ "$actual_status" = "$expected_status" ]; then
    pass "$label: STATUS = $expected_status"
  else
    fail "$label: STATUS expected=$expected_status actual=$actual_status"
  fi

  # ENTRIES 行が存在するかチェック
  if grep -q '^ENTRIES:' <<<"$actual_output"; then
    pass "$label: ENTRIES line present"
  else
    fail "$label: ENTRIES line missing"
  fi

  # REASON 行が存在するかチェック
  if grep -q '^REASON:' <<<"$actual_output"; then
    pass "$label: REASON line present"
  else
    fail "$label: REASON line missing"
  fi

  # N>=3 の場合は JACCARD_AVG 行も期待
  if [ "$expected_exit" != "1" ]; then
    if grep -q '^JACCARD_AVG:' <<<"$actual_output"; then
      pass "$label: JACCARD_AVG line present"
    else
      fail "$label: JACCARD_AVG line missing (expected for N>=3)"
    fi
  fi
}

# --- テストケース ---
echo "=== detect-review-plateau.sh テスト ==="
echo ""

echo "--- Case 1: plateau.jsonl → PIVOT_REQUIRED (exit 2) ---"
run_case \
  "plateau" \
  "test-plateau" \
  "$FIXTURE_DIR/plateau.jsonl" \
  "PIVOT_REQUIRED" \
  "2"
echo ""

echo "--- Case 2: improved.jsonl → PIVOT_NOT_REQUIRED (exit 0) ---"
run_case \
  "improved" \
  "test-improved" \
  "$FIXTURE_DIR/improved.jsonl" \
  "PIVOT_NOT_REQUIRED" \
  "0"
echo ""

echo "--- Case 3: insufficient.jsonl → INSUFFICIENT_DATA (exit 1) ---"
run_case \
  "insufficient" \
  "test-insufficient" \
  "$FIXTURE_DIR/insufficient.jsonl" \
  "INSUFFICIENT_DATA" \
  "1"
echo ""

# --- task_id 未指定エラー ---
echo "--- Case 4: task_id 未指定 → エラー終了 ---"
if bash "$SCRIPT" 2>/dev/null; then
  fail "no-task-id: should exit non-zero"
else
  pass "no-task-id: exits with error as expected"
fi
echo ""

# --- 存在しないファイル ---
echo "--- Case 5: calibration file が存在しない → INSUFFICIENT_DATA (exit 1) ---"
actual_output="$(bash "$SCRIPT" "some-task" --calibration-file "/nonexistent/file.jsonl" 2>&1)" || actual_exit=$?
actual_exit="${actual_exit:-0}"
actual_status="$(echo "$actual_output" | grep '^STATUS:' | awk '{print $2}')"
if [ "$actual_exit" = "1" ] && [ "$actual_status" = "INSUFFICIENT_DATA" ]; then
  pass "missing-file: INSUFFICIENT_DATA exit 1"
else
  fail "missing-file: expected exit=1 STATUS=INSUFFICIENT_DATA, got exit=$actual_exit STATUS=$actual_status"
fi
echo ""

# --- サマリ ---
TOTAL=$(( PASS + FAIL ))
echo "=== 結果: $PASS/$TOTAL PASS ==="
if [ "$FAIL" -gt 0 ]; then
  echo "FAILED: $FAIL テストが失敗しました"
  exit 1
fi
echo "All tests passed."
exit 0
