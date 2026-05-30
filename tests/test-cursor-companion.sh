#!/usr/bin/env bash
# test-cursor-companion.sh
# scripts/cursor-companion.sh の挙動を MOCK cursor-agent で検証する。
#
# 隔離: 実 cursor-agent は呼ばない。temp dir に偽の cursor-agent を置き、
#       PATH の先頭に挿すことでラッパーの command -v 解決がモックを拾う。
#       実ネットワーク smoke は HARNESS_CURSOR_AGENT_SMOKE=1 のときだけ走る
#       （default では skip）。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WRAPPER="${PROJECT_ROOT}/scripts/cursor-companion.sh"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

[ -f "$WRAPPER" ] || fail "missing script: $WRAPPER"

command -v jq >/dev/null 2>&1 || fail "jq is required for these tests"

# 隔離した temp 作業領域（TMPDIR を尊重する）
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/cursor-companion-test.XXXXXX")"
MOCK_BIN_DIR="${TMP_DIR}/bin"
MOCK_AGENT="${MOCK_BIN_DIR}/cursor-agent"
ARGS_FILE="${TMP_DIR}/captured-args.txt"
# write モード用の独立 workspace（repo root でも $HOME でもない実在ディレクトリ）
WORKSPACE_DIR="${TMP_DIR}/ws"
mkdir -p "${MOCK_BIN_DIR}" "${WORKSPACE_DIR}"

cleanup() {
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

# モック cursor-agent を生成するヘルパ。
#   $1 = stdout に出す内容（空なら何も出さない）
#   $2 = exit code
#   $3 = stderr に出す内容（省略可）
# 起動時に自分の引数を ARGS_FILE に記録する（--mode ask / --force の検証用）。
make_mock() {
  local stdout_body="$1"
  local exit_code="$2"
  local stderr_body="${3:-}"
  {
    printf '#!/usr/bin/env bash\n'
    # captured args を 1 行で記録する
    printf 'printf %s "$*" > %s\n' "'%s\\n'" "${ARGS_FILE}"
    if [ -n "${stderr_body}" ]; then
      printf 'echo %s >&2\n' "${stderr_body}"
    fi
    if [ -n "${stdout_body}" ]; then
      printf 'cat <<'\''JSON_EOF'\''\n%s\nJSON_EOF\n' "${stdout_body}"
    fi
    printf 'exit %s\n' "${exit_code}"
  } >"${MOCK_AGENT}"
  chmod +x "${MOCK_AGENT}"
}

# ラッパーをモック PATH 付きで実行するヘルパ。
# command -v が先頭の MOCK_BIN_DIR から cursor-agent を拾うことを保証する。
run_wrapper() {
  PATH="${MOCK_BIN_DIR}:${PATH}" bash "${WRAPPER}" "$@"
}

# ---------------------------------------------------------------------------
# (a) success: is_error=false / result="DONE" / exit 0
#     → ラッパーは DONE を出力し exit 0
# ---------------------------------------------------------------------------
make_mock '{"is_error":false,"result":"DONE"}' 0
set +e
out="$(run_wrapper task "do the thing" 2>/dev/null)"
rc=$?
set -e
[ "$rc" -eq 0 ] || fail "(a) success should exit 0, got $rc"
[ "$out" = "DONE" ] || fail "(a) success should print 'DONE', got '$out'"

# ---------------------------------------------------------------------------
# (b) error-no-json: stdout 空 / stderr=boom / exit 1
#     → ラッパーは非ゼロ終了し、偽の空 success（DONE/空文字）を出力しない
# ---------------------------------------------------------------------------
make_mock '' 1 'boom'
set +e
out="$(run_wrapper task "do the thing" 2>/dev/null)"
rc=$?
set -e
[ "$rc" -ne 0 ] || fail "(b) error-no-json should exit non-zero, got 0"
[ "$out" != "DONE" ] || fail "(b) error must not print a bogus 'DONE'"
[ -z "$out" ] && true # stdout は空であるべき（空 success として扱われない）
[ -z "$out" ] || fail "(b) error must not print any stdout result, got '$out'"

# ---------------------------------------------------------------------------
# (c) is_error true: is_error=true / result="nope" / exit 0
#     → ラッパーは failure 扱いで exit 1
# ---------------------------------------------------------------------------
make_mock '{"is_error":true,"result":"nope"}' 0
set +e
out="$(run_wrapper task "do the thing" 2>/dev/null)"
rc=$?
set -e
[ "$rc" -eq 1 ] || fail "(c) is_error=true should exit 1, got $rc"
[ "$out" != "nope" ] || fail "(c) is_error=true must not print result as success"

# ---------------------------------------------------------------------------
# (d) read-only default は --mode ask を構築する / write では付けない
# ---------------------------------------------------------------------------
make_mock '{"is_error":false,"result":"DONE"}' 0
run_wrapper task "do the thing" >/dev/null 2>&1
grep -q -- "--mode ask" "${ARGS_FILE}" \
  || fail "(d) read-only default should build '--mode ask', args were: $(cat "${ARGS_FILE}")"

make_mock '{"is_error":false,"result":"DONE"}' 0
run_wrapper task --write --workspace "${WORKSPACE_DIR}" "do the thing" >/dev/null 2>&1
if grep -q -- "--mode ask" "${ARGS_FILE}"; then
  fail "(d) write mode must NOT build '--mode ask', args were: $(cat "${ARGS_FILE}")"
fi

# ---------------------------------------------------------------------------
# (e) --force は read-only / write のどちらでも構築されない
# ---------------------------------------------------------------------------
make_mock '{"is_error":false,"result":"DONE"}' 0
run_wrapper task "do the thing" >/dev/null 2>&1
if grep -qE -- "--force|--yolo" "${ARGS_FILE}"; then
  fail "(e) read-only must never build --force/--yolo, args were: $(cat "${ARGS_FILE}")"
fi
make_mock '{"is_error":false,"result":"DONE"}' 0
run_wrapper task --write --workspace "${WORKSPACE_DIR}" "do the thing" >/dev/null 2>&1
if grep -qE -- "--force|--yolo" "${ARGS_FILE}"; then
  fail "(e) write mode must never build --force/--yolo, args were: $(cat "${ARGS_FILE}")"
fi

# ---------------------------------------------------------------------------
# (e2) --trust は read-only / write のどちらでも構築される（headless 動作に必須）。
#      --trust は workspace 信頼付与のみで、--force/--yolo（コマンド自動実行）とは別物。
# ---------------------------------------------------------------------------
make_mock '{"is_error":false,"result":"DONE"}' 0
run_wrapper task "do the thing" >/dev/null 2>&1
grep -q -- "--trust" "${ARGS_FILE}" \
  || fail "(e2) read-only must build --trust (headless 必須), args were: $(cat "${ARGS_FILE}")"
make_mock '{"is_error":false,"result":"DONE"}' 0
run_wrapper task --write --workspace "${WORKSPACE_DIR}" "do the thing" >/dev/null 2>&1
grep -q -- "--trust" "${ARGS_FILE}" \
  || fail "(e2) write mode must build --trust (headless 必須), args were: $(cat "${ARGS_FILE}")"

# ---------------------------------------------------------------------------
# (f) --write without --workspace → exit 2 (guard)
# ---------------------------------------------------------------------------
make_mock '{"is_error":false,"result":"DONE"}' 0
set +e
run_wrapper task --write "do the thing" >/dev/null 2>&1
rc=$?
set -e
[ "$rc" -eq 2 ] || fail "(f) --write without --workspace should exit 2, got $rc"

# ---------------------------------------------------------------------------
# (g) --write --workspace=<repo root> → exit 2 (guard)
# ---------------------------------------------------------------------------
make_mock '{"is_error":false,"result":"DONE"}' 0
set +e
run_wrapper task --write --workspace "${PROJECT_ROOT}" "do the thing" >/dev/null 2>&1
rc=$?
set -e
[ "$rc" -eq 2 ] || fail "(g) --write --workspace=repo-root should exit 2, got $rc"

# ---------------------------------------------------------------------------
# (h) cursor-agent 不在 → exit 3 (not-found), ハングしない
#     PATH からモックを外し、$HOME も temp に差し替えてフォールバックも外す。
# ---------------------------------------------------------------------------
set +e
PATH="/usr/bin:/bin" HOME="${TMP_DIR}/empty-home" \
  bash "${WRAPPER}" task "do the thing" >/dev/null 2>&1
rc=$?
set -e
[ "$rc" -eq 3 ] || fail "(h) missing cursor-agent should exit 3, got $rc"

# ---------------------------------------------------------------------------
# (i) --debug 引数: 成功パスで wrapper stderr に [cursor-companion DEBUG] と cmd:
#     が含まれ、ARGS_FILE には --debug が混入していない（cursor-agent に渡らない）
# ---------------------------------------------------------------------------
make_mock '{"is_error":false,"result":"DONE"}' 0
DEBUG_ERR="${TMP_DIR}/debug-flag-stderr.txt"
set +e
out="$(run_wrapper --debug task "do the thing" 2>"${DEBUG_ERR}")"
rc=$?
set -e
[ "$rc" -eq 0 ] || fail "(i) --debug success path should exit 0, got $rc"
[ "$out" = "DONE" ] || fail "(i) --debug success path should still print 'DONE', got '$out'"
grep -q "\[cursor-companion DEBUG\]" "${DEBUG_ERR}" \
  || fail "(i) --debug wrapper stderr should contain '[cursor-companion DEBUG]', got: $(cat "${DEBUG_ERR}")"
grep -q "cmd:" "${DEBUG_ERR}" \
  || fail "(i) --debug wrapper stderr should contain 'cmd:', got: $(cat "${DEBUG_ERR}")"
if grep -q -- "--debug" "${ARGS_FILE}"; then
  fail "(i) --debug must NOT be passed to cursor-agent, args were: $(cat "${ARGS_FILE}")"
fi

# (i-b) --debug は task の後ろにも置ける
make_mock '{"is_error":false,"result":"DONE"}' 0
DEBUG_ERR2="${TMP_DIR}/debug-flag-after-task-stderr.txt"
set +e
out="$(run_wrapper task --debug "do the thing" 2>"${DEBUG_ERR2}")"
rc=$?
set -e
[ "$rc" -eq 0 ] || fail "(i-b) 'task --debug' should exit 0, got $rc"
grep -q "\[cursor-companion DEBUG\]" "${DEBUG_ERR2}" \
  || fail "(i-b) 'task --debug' should also trigger debug output, got: $(cat "${DEBUG_ERR2}")"
if grep -q -- "--debug" "${ARGS_FILE}"; then
  fail "(i-b) 'task --debug' must NOT be passed to cursor-agent, args were: $(cat "${ARGS_FILE}")"
fi

# ---------------------------------------------------------------------------
# (ii) HARNESS_CURSOR_DEBUG=1 env: --debug フラグなしでも同じ debug 出力
# ---------------------------------------------------------------------------
make_mock '{"is_error":false,"result":"DONE"}' 0
DEBUG_ENV_ERR="${TMP_DIR}/debug-env-stderr.txt"
set +e
out="$(HARNESS_CURSOR_DEBUG=1 run_wrapper task "do the thing" 2>"${DEBUG_ENV_ERR}")"
rc=$?
set -e
[ "$rc" -eq 0 ] || fail "(ii) HARNESS_CURSOR_DEBUG=1 success path should exit 0, got $rc"
[ "$out" = "DONE" ] || fail "(ii) HARNESS_CURSOR_DEBUG=1 should still print 'DONE', got '$out'"
grep -q "\[cursor-companion DEBUG\]" "${DEBUG_ENV_ERR}" \
  || fail "(ii) HARNESS_CURSOR_DEBUG=1 stderr should contain '[cursor-companion DEBUG]', got: $(cat "${DEBUG_ENV_ERR}")"
grep -q "cmd:" "${DEBUG_ENV_ERR}" \
  || fail "(ii) HARNESS_CURSOR_DEBUG=1 stderr should contain 'cmd:', got: $(cat "${DEBUG_ENV_ERR}")"
if grep -q -- "--debug" "${ARGS_FILE}"; then
  fail "(ii) HARNESS_CURSOR_DEBUG=1 must NOT pass --debug to cursor-agent, args were: $(cat "${ARGS_FILE}")"
fi

# ---------------------------------------------------------------------------
# (iii) secret マスキング: mask_args() を直接 source して call し、
#       --api-key / Authorization が [REDACTED] に置換され、PROMPT は素通しを assert
# ---------------------------------------------------------------------------
(
  # source guard により main は実行されず関数だけ load される
  CURSOR_COMPANION_SOURCED_FOR_TEST=1
  export CURSOR_COMPANION_SOURCED_FOR_TEST
  # shellcheck disable=SC1090
  . "${WRAPPER}"
  masked="$(mask_args "--api-key" "SUPERSECRET" "--header" "Authorization: Bearer ABCDEFG" "prompt-text")"
  # SUPERSECRET は --api-key の次なので [REDACTED] になる
  if printf '%s' "${masked}" | grep -q "SUPERSECRET"; then
    echo "FAIL: (iii) --api-key value 'SUPERSECRET' must be masked, masked='${masked}'" >&2
    exit 1
  fi
  # ABCDEFG は Authorization ヘッダの値なので [REDACTED] になる
  if printf '%s' "${masked}" | grep -q "ABCDEFG"; then
    echo "FAIL: (iii) Authorization bearer 'ABCDEFG' must be masked, masked='${masked}'" >&2
    exit 1
  fi
  # [REDACTED] が含まれている
  if ! printf '%s' "${masked}" | grep -q "\[REDACTED\]"; then
    echo "FAIL: (iii) mask_args must emit '[REDACTED]', masked='${masked}'" >&2
    exit 1
  fi
  # PROMPT は素通し（マスクしない）
  if ! printf '%s' "${masked}" | grep -q "prompt-text"; then
    echo "FAIL: (iii) prompt body 'prompt-text' must NOT be masked, masked='${masked}'" >&2
    exit 1
  fi
) || fail "(iii) mask_args unit test failed"

# (iii-b) -H Authorization も同様にマスクされる
(
  CURSOR_COMPANION_SOURCED_FOR_TEST=1
  export CURSOR_COMPANION_SOURCED_FOR_TEST
  # shellcheck disable=SC1090
  . "${WRAPPER}"
  masked="$(mask_args "-H" "Authorization: Bearer XYZ123" "next")"
  if printf '%s' "${masked}" | grep -q "XYZ123"; then
    echo "FAIL: (iii-b) -H Authorization value must be masked, masked='${masked}'" >&2
    exit 1
  fi
  if ! printf '%s' "${masked}" | grep -q "\[REDACTED\]"; then
    echo "FAIL: (iii-b) mask_args must emit '[REDACTED]', masked='${masked}'" >&2
    exit 1
  fi
  if ! printf '%s' "${masked}" | grep -q "next"; then
    echo "FAIL: (iii-b) following token 'next' must remain, masked='${masked}'" >&2
    exit 1
  fi
) || fail "(iii-b) mask_args -H unit test failed"

# (iii-c) --auth-token も同様にマスクされる
(
  CURSOR_COMPANION_SOURCED_FOR_TEST=1
  export CURSOR_COMPANION_SOURCED_FOR_TEST
  # shellcheck disable=SC1090
  . "${WRAPPER}"
  masked="$(mask_args "--auth-token" "TOPSECRET" "prompt")"
  if printf '%s' "${masked}" | grep -q "TOPSECRET"; then
    echo "FAIL: (iii-c) --auth-token value must be masked, masked='${masked}'" >&2
    exit 1
  fi
  if ! printf '%s' "${masked}" | grep -q "prompt"; then
    echo "FAIL: (iii-c) prompt must remain unmasked, masked='${masked}'" >&2
    exit 1
  fi
) || fail "(iii-c) mask_args --auth-token unit test failed"

# ---------------------------------------------------------------------------
# (iii-d) standalone "Authorization: Bearer ..." 単独要素もマスクされる
#         （-H や --header と組まれず、1 要素として cmd に含まれた場合）
# ---------------------------------------------------------------------------
(
  set -euo pipefail
  CURSOR_COMPANION_SOURCED_FOR_TEST=1
  # shellcheck disable=SC1090
  source "${WRAPPER}"
  masked="$(mask_args "Authorization: Bearer STANDALONE_TOKEN" "prompt-after")"
  if echo "${masked}" | grep -q "STANDALONE_TOKEN"; then
    echo "FAIL: (iii-d) standalone Authorization token must be masked, masked='${masked}'" >&2
    exit 1
  fi
  if ! echo "${masked}" | grep -q "\[REDACTED\]"; then
    echo "FAIL: (iii-d) [REDACTED] missing from masked, masked='${masked}'" >&2
    exit 1
  fi
  if ! echo "${masked}" | grep -q "prompt-after"; then
    echo "FAIL: (iii-d) trailing prompt must remain unmasked, masked='${masked}'" >&2
    exit 1
  fi
) || fail "(iii-d) mask_args standalone Authorization unit test failed"

# ---------------------------------------------------------------------------
# (iv) Default-off: --debug もなく env も無い → wrapper stderr に DEBUG marker なし
# ---------------------------------------------------------------------------
make_mock '{"is_error":false,"result":"DONE"}' 0
DEFAULT_ERR="${TMP_DIR}/default-off-stderr.txt"
set +e
out="$(run_wrapper task "do the thing" 2>"${DEFAULT_ERR}")"
rc=$?
set -e
[ "$rc" -eq 0 ] || fail "(iv) default-off success path should exit 0, got $rc"
if grep -q "\[cursor-companion DEBUG\]" "${DEFAULT_ERR}"; then
  fail "(iv) default-off (no --debug, no env) must NOT emit DEBUG marker, stderr was: $(cat "${DEFAULT_ERR}")"
fi

# ---------------------------------------------------------------------------
# (v) Model-routing failure surfacing:
#     HARNESS_CURSOR_COMPANION_MODEL_ROUTER で偽の model-routing.sh を差し込む。
#     --debug 有効時、wrapper stderr に "model-routing.sh stderr:" と "ERROR: bogus"
#     が出ること。既存の "could not resolve a Cursor model" は依然 exit 2。
# ---------------------------------------------------------------------------
FAKE_MR="${TMP_DIR}/fake-model-routing.sh"
{
  printf '#!/usr/bin/env bash\n'
  printf 'echo "ERROR: bogus" >&2\n'
  printf 'exit 2\n'
} >"${FAKE_MR}"
chmod +x "${FAKE_MR}"

make_mock '{"is_error":false,"result":"DONE"}' 0
MR_ERR="${TMP_DIR}/model-routing-debug-stderr.txt"
set +e
HARNESS_CURSOR_COMPANION_MODEL_ROUTER="${FAKE_MR}" \
  run_wrapper --debug task "do the thing" >/dev/null 2>"${MR_ERR}"
rc=$?
set -e
[ "$rc" -eq 2 ] || fail "(v) bogus model-routing should still exit 2, got $rc"
grep -q "model-routing.sh stderr:" "${MR_ERR}" \
  || fail "(v) --debug should surface 'model-routing.sh stderr:' prefix, stderr was: $(cat "${MR_ERR}")"
grep -q "ERROR: bogus" "${MR_ERR}" \
  || fail "(v) --debug should surface fake model-routing's 'ERROR: bogus' stderr, stderr was: $(cat "${MR_ERR}")"
grep -q "could not resolve a Cursor model" "${MR_ERR}" \
  || fail "(v) existing 'could not resolve a Cursor model' error must still be emitted, stderr was: $(cat "${MR_ERR}")"

# (v-b) DEBUG=0 のときは model-routing.sh の stderr を呑む（既存挙動の保護）
make_mock '{"is_error":false,"result":"DONE"}' 0
MR_ERR2="${TMP_DIR}/model-routing-silent-stderr.txt"
set +e
HARNESS_CURSOR_COMPANION_MODEL_ROUTER="${FAKE_MR}" \
  run_wrapper task "do the thing" >/dev/null 2>"${MR_ERR2}"
rc=$?
set -e
[ "$rc" -eq 2 ] || fail "(v-b) bogus model-routing without --debug should still exit 2, got $rc"
if grep -q "model-routing.sh stderr:" "${MR_ERR2}"; then
  fail "(v-b) DEBUG=0 must NOT surface model-routing.sh stderr, stderr was: $(cat "${MR_ERR2}")"
fi
if grep -q "ERROR: bogus" "${MR_ERR2}"; then
  fail "(v-b) DEBUG=0 must NOT surface fake 'ERROR: bogus', stderr was: $(cat "${MR_ERR2}")"
fi

# ---------------------------------------------------------------------------
# 任意: 実ネットワーク smoke（default skip）
# ---------------------------------------------------------------------------
if [ "${HARNESS_CURSOR_AGENT_SMOKE:-0}" = "1" ]; then
  echo "running real cursor-agent smoke..."
  bash "${WRAPPER}" task "Reply with the single word READY" || fail "(smoke) real cursor-agent failed"
fi

echo "ok"
