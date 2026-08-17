#!/bin/bash
# tests/test-scope-leash-fires-on-security-diff.sh
# Phase 134.8 - 実効性契約テスト: scope leash (Phase 134.5) が go/internal/scopeleash の
# spike のまま眠っておらず、実際にコンパイル済みの bin/harness へ stdin payload を投入した
# ときに warn 記録 / enforce deny として発火することを確認する。
#
# go/internal/guardrail のユニットテスト (pre_tool_scope_leash_test.go) は
# EvaluatePreTool() を直接呼ぶが、それだけでは「main.go の hook pre-tool エントリポイント
# まで正しく配線されているか」は確認できない。このテストは実際に `go build` した CLI
# バイナリへ Claude Code の PreToolUse stdin 形式そのままの payload を渡し、プロセス境界を
# 越えて動くことを確認する。
#
# fixture project (tempdir) のセキュリティ関連ファイル (go/internal/guardrail/pre_tool.go
# 相当のパス) を declared_scope に置き、その外側への Write を "security diff" として扱う。
#
# Usage: bash tests/test-scope-leash-fires-on-security-diff.sh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

PASS=0
FAIL=0
pass() { PASS=$((PASS + 1)); echo "✓ $1"; }
fail() { FAIL=$((FAIL + 1)); echo "✗ $1" >&2; }

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required" >&2
  exit 2
fi

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/scope-leash-e2e-test.XXXXXX")"
trap 'rm -rf "$WORK_DIR"; [ -n "${HARNESS_BIN_TMP:-}" ] && rm -f "$HARNESS_BIN_TMP"' EXIT

# HARNESS_BIN_OVERRIDE lets this test point at an already-built binary
# (used for RED verification against a pre-134.5 build — see notes in the
# Phase 134.8 worker report). Default behavior builds fresh from source.
if [ -n "${HARNESS_BIN_OVERRIDE:-}" ]; then
  HARNESS_BIN="$HARNESS_BIN_OVERRIDE"
  pass "既存バイナリを使用 (HARNESS_BIN_OVERRIDE=$HARNESS_BIN)"
else
  HARNESS_BIN_TMP="$(mktemp "${TMPDIR:-/tmp}/scope-leash-e2e-bin.XXXXXX")"
  HARNESS_BIN="$HARNESS_BIN_TMP"
  if ! GO111MODULE=on go build -o "$HARNESS_BIN" "$ROOT_DIR/go/cmd/harness" 2>"$WORK_DIR/build.err"; then
    fail "harness CLI のビルドに失敗した: $(cat "$WORK_DIR/build.err")"
    echo "PASS=$PASS FAIL=$FAIL"
    exit 1
  fi
  pass "go/cmd/harness から実バイナリをビルドした"
fi

TASK_ID="134.8-scope"
SECURITY_FILE="go/internal/guardrail/pre_tool.go"

# fixture_project <suffix> <enforce_level> を作り、絶対パスを返す。
fixture_project() {
  local suffix="$1"
  local enforce_level="$2"
  local dir="$WORK_DIR/proj-$suffix"
  mkdir -p "$dir/.claude/state/contracts"
  printf '{"phase":"134","task":"%s"}' "$TASK_ID" > "$dir/.claude/state/active-task.json"
  printf '{"task":{"id":"%s","declared_scope":["%s"]}}' "$TASK_ID" "$SECURITY_FILE" \
    > "$dir/.claude/state/contracts/${TASK_ID}.sprint-contract.json"
  if [ -n "$enforce_level" ]; then
    printf '[scope_leash]\nenforce_level = "%s"\n' "$enforce_level" > "$dir/harness.toml"
  fi
  printf '%s' "$dir"
}

# hook_write <project-dir> <target-file-relative-path> を実行し stdout を返す。
hook_write() {
  local dir="$1"
  local target="$2"
  jq -n \
    --arg cwd "$dir" \
    --arg path "$dir/$target" \
    '{
      session_id: "sess-scope-leash-e2e",
      hook_event_name: "PreToolUse",
      tool_name: "Write",
      tool_input: {file_path: $path, content: "x"},
      cwd: $cwd
    }' | "$HARNESS_BIN" hook pre-tool
}

# ==== (a) warn: out-of-scope write → allow だが additionalContext に SCOPE_LEASH + scope-leash.jsonl 記録 ====

PROJ_A="$(fixture_project "warn" "warn")"
JSONL_A="$PROJ_A/.claude/state/scope-leash.jsonl"

if [ -f "$JSONL_A" ]; then
  fail "(a) RED precondition が崩れている: scope-leash.jsonl が最初から存在する"
fi

set +e
OUT_A="$(hook_write "$PROJ_A" "other/bar.go" 2>"$WORK_DIR/out-a.err")"
EXIT_A=$?
set -e

if [ "$EXIT_A" -eq 0 ]; then
  pass "(a) warn level は exit 0 (block しない)"
else
  fail "(a) warn level が exit $EXIT_A でブロックした (stderr: $(cat "$WORK_DIR/out-a.err"))"
fi

if [ -n "$OUT_A" ] && jq -e '.hookSpecificOutput.permissionDecision == "allow"' <<<"$OUT_A" >/dev/null 2>&1; then
  pass "(a) permissionDecision == allow"
else
  fail "(a) permissionDecision が allow でない: $OUT_A"
fi

if [ -n "$OUT_A" ] && jq -e '.hookSpecificOutput.additionalContext // "" | contains("SCOPE_LEASH")' <<<"$OUT_A" >/dev/null 2>&1; then
  pass "(a) additionalContext に SCOPE_LEASH 警告が含まれる"
else
  fail "(a) additionalContext に SCOPE_LEASH が含まれない: $OUT_A"
fi

if [ -f "$JSONL_A" ] && grep -q "other/bar.go" "$JSONL_A" && grep -q "$TASK_ID" "$JSONL_A"; then
  pass "(a) 実バイナリ経由の warn が .claude/state/scope-leash.jsonl に記録された (RED→GREEN: 配線前は生成されない)"
else
  fail "(a) scope-leash.jsonl に記録が無い、または target/task が欠けている"
fi

# ==== (b) enforce: out-of-scope write → deny ====

PROJ_B="$(fixture_project "enforce" "enforce")"

set +e
OUT_B="$(hook_write "$PROJ_B" "other/bar.go" 2>"$WORK_DIR/out-b.err")"
EXIT_B=$?
set -e

if [ "$EXIT_B" -eq 2 ]; then
  pass "(b) enforce level は exit 2 (deny) でブロックする"
else
  fail "(b) enforce level が deny (exit 2) しなかった (got exit $EXIT_B, stdout: $OUT_B)"
fi

if [ -n "$OUT_B" ] && jq -e '.hookSpecificOutput.permissionDecision == "deny"' <<<"$OUT_B" >/dev/null 2>&1; then
  pass "(b) permissionDecision == deny"
else
  fail "(b) permissionDecision が deny でない: $OUT_B"
fi

if [ -n "$OUT_B" ] && jq -e '.hookSpecificOutput.permissionDecisionReason // "" | contains("SCOPE_LEASH")' <<<"$OUT_B" >/dev/null 2>&1; then
  pass "(b) permissionDecisionReason に SCOPE_LEASH が含まれる"
else
  fail "(b) permissionDecisionReason に SCOPE_LEASH が含まれない: $OUT_B"
fi

# ==== (c) enforce: in-scope write → 一切ブロックしない (positive/negative の negative 側) ====

PROJ_C="$(fixture_project "enforce-inscope" "enforce")"

set +e
OUT_C="$(hook_write "$PROJ_C" "$SECURITY_FILE" 2>"$WORK_DIR/out-c.err")"
EXIT_C=$?
set -e

if [ "$EXIT_C" -eq 0 ]; then
  pass "(c) enforce level でも in-scope write は exit 0 (block しない)"
else
  fail "(c) enforce level が in-scope write を誤ってブロックした (exit $EXIT_C)"
fi

if [ -f "$PROJ_C/.claude/state/scope-leash.jsonl" ]; then
  fail "(c) in-scope write なのに scope-leash.jsonl が生成された (誤爆)"
else
  pass "(c) in-scope write では scope-leash.jsonl が生成されない"
fi

# ==== (d) 空 scope (declared_scope なし) → enforce でも一切発火しない (誤爆防止) ====

PROJ_D="$WORK_DIR/proj-empty-scope"
mkdir -p "$PROJ_D/.claude/state/contracts"
printf '{"phase":"134","task":"%s"}' "$TASK_ID" > "$PROJ_D/.claude/state/active-task.json"
printf '{"task":{"id":"%s","declared_scope":[]}}' "$TASK_ID" \
  > "$PROJ_D/.claude/state/contracts/${TASK_ID}.sprint-contract.json"
printf '[scope_leash]\nenforce_level = "enforce"\n' > "$PROJ_D/harness.toml"

set +e
OUT_D="$(hook_write "$PROJ_D" "anything/at/all.go" 2>"$WORK_DIR/out-d.err")"
EXIT_D=$?
set -e

if [ "$EXIT_D" -eq 0 ] && [ -z "$OUT_D" ]; then
  pass "(d) 空 declared_scope は enforce でも一切発火しない (誤爆防止)"
else
  fail "(d) 空 declared_scope で発火した (exit $EXIT_D, stdout: $OUT_D)"
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
