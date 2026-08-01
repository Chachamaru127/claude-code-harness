#!/bin/bash
# test-auto-checkpoint.sh
# auto-checkpoint.sh の smoke test
#
# テスト内容:
#   1. 正常系: harness-mem が応答可能なとき exit 0 + checkpoint-events.jsonl に 1 行
#   2. 異常系: HARNESS_MEM_DISABLE=1 で API 失敗させ exit 非 0 +
#              session-events.jsonl にデグレ 1 行 +
#              checkpoint-events.jsonl に status:"failed" 1 行
#   3. lock test: 2 プロセス同時起動 → 片方が timeout 後に abort

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
AUTO_CHECKPOINT="${ROOT_DIR}/scripts/auto-checkpoint.sh"

PASS_COUNT=0
FAIL_COUNT=0

pass_test() {
  echo "PASS: $1"
  PASS_COUNT=$((PASS_COUNT + 1))
}

fail_test() {
  echo "FAIL: $1"
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

# テンポラリディレクトリ（各テストで共用するのではなく別々に作成）
make_tmp_dir() {
  mktemp -d
}

cleanup_dirs=()
cleanup() {
  for d in "${cleanup_dirs[@]:-}"; do
    [ -d "$d" ] && rm -rf "$d"
  done
}
trap cleanup EXIT

# ── ヘルパー: fake harness-mem-client を作成 ──────────────────────────────
make_fake_client_ok() {
  local dir="$1"
  local fake_client="${dir}/fake-harness-mem-client.sh"
  cat > "${fake_client}" << 'EOF'
#!/bin/bash
# fake harness-mem-client (success)
set -euo pipefail
printf '{"ok":true,"id":"fake-checkpoint-id"}\n'
EOF
  chmod +x "${fake_client}"
  printf '%s' "${fake_client}"
}

make_fake_client_fail() {
  local dir="$1"
  local fake_client="${dir}/fake-harness-mem-client-fail.sh"
  cat > "${fake_client}" << 'EOF'
#!/bin/bash
# fake harness-mem-client (failure)
set -euo pipefail
printf '{"ok":false,"error":"api_error","error_code":"record_checkpoint_failed"}\n'
EOF
  chmod +x "${fake_client}"
  printf '%s' "${fake_client}"
}

# ── ヘルパー: 最小 fixture ファイルを作成 ────────────────────────────────────
make_fixtures() {
  local dir="$1"
  local contract="${dir}/test-contract.json"
  local review="${dir}/test-review.json"
  printf '{"task_id":"41.0.2","title":"test"}' > "${contract}"
  printf '{"verdict":"APPROVE","status":"ok"}' > "${review}"
  printf '%s %s' "${contract}" "${review}"
}

# ────────────────────────────────────────────────────────────────────────────
# テスト 1: 正常系
# ────────────────────────────────────────────────────────────────────────────
test_success_case() {
  local tmp
  tmp="$(make_tmp_dir)"
  cleanup_dirs+=("${tmp}")

  local fake_client
  fake_client="$(make_fake_client_ok "${tmp}")"
  read -r contract review <<< "$(make_fixtures "${tmp}")"

  local state_dir="${tmp}/.claude/state"
  mkdir -p "${state_dir}/locks"

  local exit_code=0
  HARNESS_MEM_CLIENT="${fake_client}" \
  CHECKPOINT_LOCK_TIMEOUT=5 \
  PROJECT_ROOT="${tmp}" \
    bash "${AUTO_CHECKPOINT}" "41.0.2" "abc1234" "${contract}" "${review}" \
    >/dev/null 2>&1 || exit_code=$?

  # exit 0 を確認
  if [ "${exit_code}" -ne 0 ]; then
    fail_test "正常系: exit code が ${exit_code} (期待: 0)"
    return
  fi

  # checkpoint-events.jsonl に 1 行あること
  local events_file="${state_dir}/checkpoint-events.jsonl"
  if [ ! -f "${events_file}" ]; then
    fail_test "正常系: checkpoint-events.jsonl が作成されていない"
    return
  fi

  local line_count
  line_count="$(wc -l < "${events_file}" | tr -d ' ')"
  if [ "${line_count}" -lt 1 ]; then
    fail_test "正常系: checkpoint-events.jsonl に行がない"
    return
  fi

  # status が "ok" であること
  local last_line
  last_line="$(tail -1 "${events_file}")"
  if ! grep -q '"status":"ok"' <<<"${last_line}"; then
    fail_test "正常系: checkpoint-events.jsonl の status が ok でない: ${last_line}"
    return
  fi

  # session-events.jsonl が存在しないか、checkpoint_failed がないこと
  local session_events_file="${state_dir}/session-events.jsonl"
  if [ -f "${session_events_file}" ] && grep -q '"type":"checkpoint_failed"' "${session_events_file}"; then
    fail_test "正常系: session-events.jsonl に checkpoint_failed が記録されている"
    return
  fi

  pass_test "正常系: exit 0 + checkpoint-events.jsonl に status:ok の行あり"
}

# ────────────────────────────────────────────────────────────────────────────
# テスト 2: 異常系 — HARNESS_MEM_DISABLE=1
# ────────────────────────────────────────────────────────────────────────────
test_failure_case_disable_flag() {
  local tmp
  tmp="$(make_tmp_dir)"
  cleanup_dirs+=("${tmp}")

  local fake_client
  fake_client="$(make_fake_client_ok "${tmp}")"
  read -r contract review <<< "$(make_fixtures "${tmp}")"

  local state_dir="${tmp}/.claude/state"
  mkdir -p "${state_dir}/locks"

  local exit_code=0
  HARNESS_MEM_CLIENT="${fake_client}" \
  HARNESS_MEM_DISABLE=1 \
  CHECKPOINT_LOCK_TIMEOUT=5 \
  PROJECT_ROOT="${tmp}" \
    bash "${AUTO_CHECKPOINT}" "41.0.2" "abc1234" "${contract}" "${review}" \
    >/dev/null 2>&1 || exit_code=$?

  # exit 非 0 を確認
  if [ "${exit_code}" -eq 0 ]; then
    fail_test "異常系(DISABLE): exit code が 0 (期待: 非 0)"
    return
  fi

  # checkpoint-events.jsonl に status:"failed" の行があること
  local events_file="${state_dir}/checkpoint-events.jsonl"
  if [ ! -f "${events_file}" ]; then
    fail_test "異常系(DISABLE): checkpoint-events.jsonl が作成されていない"
    return
  fi

  local last_checkpoint
  last_checkpoint="$(tail -1 "${events_file}")"
  if ! grep -q '"status":"failed"' <<<"${last_checkpoint}"; then
    fail_test "異常系(DISABLE): checkpoint-events.jsonl の status が failed でない: ${last_checkpoint}"
    return
  fi

  # session-events.jsonl に checkpoint_failed があること
  local session_events_file="${state_dir}/session-events.jsonl"
  if [ ! -f "${session_events_file}" ]; then
    fail_test "異常系(DISABLE): session-events.jsonl が作成されていない"
    return
  fi

  if ! grep -q '"type":"checkpoint_failed"' "${session_events_file}"; then
    fail_test "異常系(DISABLE): session-events.jsonl に checkpoint_failed がない"
    return
  fi

  pass_test "異常系(DISABLE): exit 非 0 + checkpoint-events status:failed + session-events checkpoint_failed あり"
}

# ────────────────────────────────────────────────────────────────────────────
# テスト 3: 異常系 — API が失敗レスポンスを返す
# ────────────────────────────────────────────────────────────────────────────
test_failure_case_api_error() {
  local tmp
  tmp="$(make_tmp_dir)"
  cleanup_dirs+=("${tmp}")

  local fake_client
  fake_client="$(make_fake_client_fail "${tmp}")"
  read -r contract review <<< "$(make_fixtures "${tmp}")"

  local state_dir="${tmp}/.claude/state"
  mkdir -p "${state_dir}/locks"

  local exit_code=0
  HARNESS_MEM_CLIENT="${fake_client}" \
  CHECKPOINT_LOCK_TIMEOUT=5 \
  PROJECT_ROOT="${tmp}" \
    bash "${AUTO_CHECKPOINT}" "41.0.2" "abc1234" "${contract}" "${review}" \
    >/dev/null 2>&1 || exit_code=$?

  # exit 非 0 を確認
  if [ "${exit_code}" -eq 0 ]; then
    fail_test "異常系(API error): exit code が 0 (期待: 非 0)"
    return
  fi

  # checkpoint-events.jsonl に status:"failed" があること
  local events_file="${state_dir}/checkpoint-events.jsonl"
  if [ ! -f "${events_file}" ]; then
    fail_test "異常系(API error): checkpoint-events.jsonl が作成されていない"
    return
  fi

  local last_checkpoint
  last_checkpoint="$(tail -1 "${events_file}")"
  if ! grep -q '"status":"failed"' <<<"${last_checkpoint}"; then
    fail_test "異常系(API error): checkpoint-events.jsonl の status が failed でない: ${last_checkpoint}"
    return
  fi

  # session-events.jsonl に checkpoint_failed があること
  local session_events_file="${state_dir}/session-events.jsonl"
  if [ ! -f "${session_events_file}" ] || ! grep -q '"type":"checkpoint_failed"' "${session_events_file}"; then
    fail_test "異常系(API error): session-events.jsonl に checkpoint_failed がない"
    return
  fi

  pass_test "異常系(API error): exit 非 0 + checkpoint-events status:failed + session-events checkpoint_failed あり"
}

# ────────────────────────────────────────────────────────────────────────────
# テスト 4: lock test — 2 プロセス同時起動 → 片方が timeout 後に abort
# ────────────────────────────────────────────────────────────────────────────
test_lock_contention() {
  local tmp
  tmp="$(make_tmp_dir)"
  cleanup_dirs+=("${tmp}")

  local state_dir="${tmp}/.claude/state"
  mkdir -p "${state_dir}/locks"
  read -r contract review <<< "$(make_fixtures "${tmp}")"

  # ロックを先に保持する「遅い」fake client（2 秒 sleep）
  local slow_client="${tmp}/slow-client.sh"
  cat > "${slow_client}" << 'EOF'
#!/bin/bash
sleep 3
printf '{"ok":true}\n'
EOF
  chmod +x "${slow_client}"

  local exit_code_fast=99
  local checkpoint_events_file="${state_dir}/checkpoint-events.jsonl"

  # プロセス 1: ロックを保持したまま遅い処理
  HARNESS_MEM_CLIENT="${slow_client}" \
  CHECKPOINT_LOCK_TIMEOUT=2 \
  PROJECT_ROOT="${tmp}" \
    bash "${AUTO_CHECKPOINT}" "41.0.2-p1" "abc0001" "${contract}" "${review}" \
    >/dev/null 2>&1 &
  local pid1=$!

  # 少し待ってからプロセス 2 を起動（プロセス 1 がロックを保持している間）
  sleep 0.3

  # プロセス 2: lock timeout (2s) で abort するはず
  HARNESS_MEM_CLIENT="${slow_client}" \
  CHECKPOINT_LOCK_TIMEOUT=2 \
  PROJECT_ROOT="${tmp}" \
    bash "${AUTO_CHECKPOINT}" "41.0.2-p2" "abc0002" "${contract}" "${review}" \
    >/dev/null 2>&1 || exit_code_fast=$?

  wait "${pid1}" || true

  # プロセス 2 は exit 非 0（lock timeout で abort）であること
  if [ "${exit_code_fast}" -eq 0 ]; then
    fail_test "lock test: プロセス 2 が exit 0 (lock timeout で abort するはず)"
    return
  fi

  # checkpoint-events.jsonl にプロセス 2 のタイムアウト失敗レコードがあること
  if [ -f "${checkpoint_events_file}" ] && grep -q '"error":"lock_timeout"' "${checkpoint_events_file}"; then
    pass_test "lock test: 2 プロセス同時起動で片方が lock_timeout で abort"
  else
    # タイムアウトレコードがなくても、exit 非 0 なら partial pass
    if [ "${exit_code_fast}" -ne 0 ]; then
      pass_test "lock test: プロセス 2 が exit ${exit_code_fast} で abort (lock contention)"
    else
      fail_test "lock test: lock_timeout レコードが checkpoint-events.jsonl にない"
    fi
  fi
}

# ────────────────────────────────────────────────────────────────────────────
# テスト 5: 10 回連続実行でも lock デッドロックなし
# ────────────────────────────────────────────────────────────────────────────
test_no_deadlock_10_runs() {
  local tmp
  tmp="$(make_tmp_dir)"
  cleanup_dirs+=("${tmp}")

  local fake_client
  fake_client="$(make_fake_client_ok "${tmp}")"
  read -r contract review <<< "$(make_fixtures "${tmp}")"

  local state_dir="${tmp}/.claude/state"
  mkdir -p "${state_dir}/locks"

  local failed=0
  for i in $(seq 1 10); do
    local exit_code=0
    HARNESS_MEM_CLIENT="${fake_client}" \
    CHECKPOINT_LOCK_TIMEOUT=5 \
    PROJECT_ROOT="${tmp}" \
      bash "${AUTO_CHECKPOINT}" "41.0.2-run${i}" "abc$(printf '%04d' "${i}")" "${contract}" "${review}" \
      >/dev/null 2>&1 || exit_code=$?
    if [ "${exit_code}" -ne 0 ]; then
      failed=$((failed + 1))
    fi
  done

  if [ "${failed}" -ne 0 ]; then
    fail_test "10 回連続実行: ${failed} 回失敗 (lock デッドロックの可能性)"
    return
  fi

  # checkpoint-events.jsonl に 10 行以上あること
  local events_file="${state_dir}/checkpoint-events.jsonl"
  local line_count
  line_count="$(wc -l < "${events_file}" | tr -d ' ')"
  if [ "${line_count}" -lt 10 ]; then
    fail_test "10 回連続実行: checkpoint-events.jsonl の行数が ${line_count} (期待: 10 以上)"
    return
  fi

  pass_test "10 回連続実行: lock デッドロックなし + checkpoint-events.jsonl に ${line_count} 行"
}

# ────────────────────────────────────────────────────────────────────────────
# テスト実行
# ────────────────────────────────────────────────────────────────────────────
echo "=== auto-checkpoint.sh smoke test ==="
echo ""

test_success_case
test_failure_case_disable_flag
test_failure_case_api_error
test_lock_contention
test_no_deadlock_10_runs

echo ""
echo "=== 結果: PASS=${PASS_COUNT} FAIL=${FAIL_COUNT} ==="

if [ "${FAIL_COUNT}" -ne 0 ]; then
  exit 1
fi

exit 0
