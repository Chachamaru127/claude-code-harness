#!/usr/bin/env bash
# test-impl-backend.sh
# set-impl-backend.sh / resolve-impl-backend.sh の挙動を検証する。
#
# 隔離: HARNESS_ENV_LOCAL で一時 env.local を使い、実 env.local には触れない。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SET="${PROJECT_ROOT}/scripts/set-impl-backend.sh"
RESOLVE="${PROJECT_ROOT}/scripts/resolve-impl-backend.sh"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

# 隔離した一時 env.local を用意する（TMPDIR を尊重する）
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/impl-backend-test.XXXXXX")"
export HARNESS_ENV_LOCAL="${TMP_DIR}/env.local"
# ユーザースコープも先頭で隔離する。実 ~/.config/claude-harness/impl-backend.env を
# 読みに行くと、opt-in 済みマシンで (a)-(h) の default 判定が壊れる
# （active-watching-test-policy: optional user-scope config を隔離せず依存しない）。
export HARNESS_USER_BACKEND_FILE="${TMP_DIR}/user-backend"

cleanup() {
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

[ -f "$SET" ] || fail "missing script: $SET"
[ -f "$RESOLVE" ] || fail "missing script: $RESOLVE"

# 各テストの前に env.local をリセットするヘルパ
reset_env_local() {
  rm -f "${HARNESS_ENV_LOCAL}"
}

# ---------------------------------------------------------------------------
# (a) --backend フラグが env と file の両方に勝つ
# ---------------------------------------------------------------------------
reset_env_local
printf 'export HARNESS_IMPL_BACKEND=codex\n' > "${HARNESS_ENV_LOCAL}"
got="$(HARNESS_IMPL_BACKEND=codex bash "$RESOLVE" --backend cursor)"
[ "$got" = "cursor" ] || fail "(a) flag should win over env+file, got '$got'"

# ---------------------------------------------------------------------------
# (b) HARNESS_IMPL_BACKEND env が file に勝つ
# ---------------------------------------------------------------------------
reset_env_local
printf 'export HARNESS_IMPL_BACKEND=cursor\n' > "${HARNESS_ENV_LOCAL}"
got="$(HARNESS_IMPL_BACKEND=codex bash "$RESOLVE")"
[ "$got" = "codex" ] || fail "(b) env should win over file, got '$got'"

# ---------------------------------------------------------------------------
# (c) env / flag が無いとき file の値を使う
# ---------------------------------------------------------------------------
reset_env_local
printf 'export HARNESS_IMPL_BACKEND=cursor\n' > "${HARNESS_ENV_LOCAL}"
got="$(env -u HARNESS_IMPL_BACKEND bash "$RESOLVE")"
[ "$got" = "cursor" ] || fail "(c) file value should be used, got '$got'"

# ---------------------------------------------------------------------------
# (d) 何も設定されていないとき既定値 claude
# ---------------------------------------------------------------------------
reset_env_local
got="$(env -u HARNESS_IMPL_BACKEND bash "$RESOLVE")"
[ "$got" = "claude" ] || fail "(d) default should be claude, got '$got'"

# ---------------------------------------------------------------------------
# (e) set-impl-backend が書き込み、resolve が読み戻す
# ---------------------------------------------------------------------------
reset_env_local
env -u HARNESS_IMPL_BACKEND bash "$SET" codex >/dev/null
got="$(env -u HARNESS_IMPL_BACKEND bash "$RESOLVE")"
[ "$got" = "codex" ] || fail "(e) set then resolve should return codex, got '$got'"
grep -qE "^export HARNESS_IMPL_BACKEND=codex$" "${HARNESS_ENV_LOCAL}" \
  || fail "(e) env.local should contain the export line"

# ---------------------------------------------------------------------------
# (f) set then set-different が置換する（重複行を残さない）
# ---------------------------------------------------------------------------
reset_env_local
env -u HARNESS_IMPL_BACKEND bash "$SET" codex >/dev/null
env -u HARNESS_IMPL_BACKEND bash "$SET" cursor >/dev/null
got="$(env -u HARNESS_IMPL_BACKEND bash "$RESOLVE")"
[ "$got" = "cursor" ] || fail "(f) set-different should replace, got '$got'"
count="$(grep -cE "^export HARNESS_IMPL_BACKEND=" "${HARNESS_ENV_LOCAL}")"
[ "$count" = "1" ] || fail "(f) should have exactly 1 setting line, got $count"

# 冪等性: 同じ値で再実行しても重複を作らない
env -u HARNESS_IMPL_BACKEND bash "$SET" cursor >/dev/null
count="$(grep -cE "^export HARNESS_IMPL_BACKEND=" "${HARNESS_ENV_LOCAL}")"
[ "$count" = "1" ] || fail "(f) idempotent set should keep 1 line, got $count"

# ---------------------------------------------------------------------------
# (g) --unset が設定を削除する
# ---------------------------------------------------------------------------
reset_env_local
env -u HARNESS_IMPL_BACKEND bash "$SET" cursor >/dev/null
env -u HARNESS_IMPL_BACKEND bash "$SET" --unset >/dev/null
count="$(grep -cE "^export HARNESS_IMPL_BACKEND=" "${HARNESS_ENV_LOCAL}" || true)"
[ "$count" = "0" ] || fail "(g) --unset should remove the line, got $count"
got="$(env -u HARNESS_IMPL_BACKEND bash "$RESOLVE")"
[ "$got" = "claude" ] || fail "(g) after unset resolve should default to claude, got '$got'"

# ---------------------------------------------------------------------------
# (h) set-impl-backend に不正な引数を渡すと非ゼロ終了
# ---------------------------------------------------------------------------
reset_env_local
if env -u HARNESS_IMPL_BACKEND bash "$SET" bogus >/dev/null 2>&1; then
  fail "(h) invalid arg should exit non-zero"
fi

# ---------------------------------------------------------------------------
# 追加: --show が解決結果を表示する
# ---------------------------------------------------------------------------
reset_env_local
env -u HARNESS_IMPL_BACKEND bash "$SET" codex >/dev/null
got="$(env -u HARNESS_IMPL_BACKEND bash "$SET" --show)"
[ "$got" = "codex" ] || fail "(--show) should print resolved backend, got '$got'"

# ---------------------------------------------------------------------------
# 追加: file の不正値は警告して claude にフォールバック
# ---------------------------------------------------------------------------
reset_env_local
printf 'export HARNESS_IMPL_BACKEND=bogus\n' > "${HARNESS_ENV_LOCAL}"
got="$(env -u HARNESS_IMPL_BACKEND bash "$RESOLVE" 2>/dev/null)"
[ "$got" = "claude" ] || fail "(invalid-file) should fall back to claude, got '$got'"

# ---------------------------------------------------------------------------
# ユーザースコープ（--user / HARNESS_USER_BACKEND_FILE）
# ---------------------------------------------------------------------------
reset_user() { rm -f "${HARNESS_USER_BACKEND_FILE}"; }

# (i) project / env / flag が無いとき user file の値を使う
reset_env_local; reset_user
env -u HARNESS_IMPL_BACKEND bash "$SET" --user cursor >/dev/null
got="$(env -u HARNESS_IMPL_BACKEND bash "$RESOLVE")"
[ "$got" = "cursor" ] || fail "(i) user-scope value should be used, got '$got'"
grep -qE "^export HARNESS_IMPL_BACKEND=cursor$" "${HARNESS_USER_BACKEND_FILE}" \
  || fail "(i) user file should contain the export line"

# (j) project env.local が user file に勝つ
reset_env_local; reset_user
env -u HARNESS_IMPL_BACKEND bash "$SET" --user cursor >/dev/null
env -u HARNESS_IMPL_BACKEND bash "$SET" codex >/dev/null
got="$(env -u HARNESS_IMPL_BACKEND bash "$RESOLVE")"
[ "$got" = "codex" ] || fail "(j) project should win over user-scope, got '$got'"

# (k) env が user file に勝つ
reset_env_local; reset_user
env -u HARNESS_IMPL_BACKEND bash "$SET" --user cursor >/dev/null
got="$(HARNESS_IMPL_BACKEND=claude bash "$RESOLVE")"
[ "$got" = "claude" ] || fail "(k) env should win over user-scope, got '$got'"

# (l) --unset --user は user file だけ削除する（project は触らない）
reset_env_local; reset_user
env -u HARNESS_IMPL_BACKEND bash "$SET" codex >/dev/null
env -u HARNESS_IMPL_BACKEND bash "$SET" --user cursor >/dev/null
env -u HARNESS_IMPL_BACKEND bash "$SET" --unset --user >/dev/null
ucount="$(grep -cE "^export HARNESS_IMPL_BACKEND=" "${HARNESS_USER_BACKEND_FILE}" 2>/dev/null || true)"
[ "$ucount" = "0" ] || fail "(l) --unset --user should clear user file, got $ucount"
got="$(env -u HARNESS_IMPL_BACKEND bash "$RESOLVE")"
[ "$got" = "codex" ] || fail "(l) project setting should survive user unset, got '$got'"

echo "ok"
