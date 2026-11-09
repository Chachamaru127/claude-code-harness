#!/bin/bash
# tests/test-progress-regen.sh
# Phase 65.4.2 - PostToolUse hook 自動再生成 + 60s rate limit 検証
#
# 検証ケース (Plans.md §65.4.2 DoD a-e):
#   1. 初回      - state file なし → 再生成実行 + state file 作成
#   2. 60 秒以内 - state file あり (last regen 30 秒前) → skip
#   3. 60 秒超   - state file あり (last regen 90 秒前) → 再生成実行
#   4. hook input 不正 - stdin が空でも crash しない
#   + dual sync 検証 (.claude-plugin/hooks.json と hooks/hooks.json 一致)
#   + JSON validity 検証

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

HANDLER="$ROOT_DIR/scripts/hook-handlers/posttool-progress-regen.sh"

PASS=0
FAIL=0
FAIL_MESSAGES=()

pass() { PASS=$((PASS + 1)); echo "✓ $1"; }
fail() { FAIL=$((FAIL + 1)); FAIL_MESSAGES+=("$1"); echo "✗ $1" >&2; }

if [[ ! -x "$HANDLER" ]]; then
  fail "posttool-progress-regen.sh not executable"
  echo "PASS=$PASS FAIL=$FAIL"; exit 1
fi
pass "handler exists and is executable"

# isolated test project root
TMP_PROJ="$(mktemp -d "${TMPDIR:-/tmp}/test-progress-regen.XXXXXX")"
trap 'rm -rf "$TMP_PROJ"' EXIT

mkdir -p "$TMP_PROJ/.claude/state"
mkdir -p "$TMP_PROJ/out"

cat > "$TMP_PROJ/Plans.md" <<'PLANS'
# Plans

| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 99.1.1 | 完了 task | dod | - | cc:完了 [a1b2c3d] |
| 99.1.2 | 進行中 | dod | - | cc:WIP |
PLANS

STATE_FILE="$TMP_PROJ/.claude/state/progress-last-regen.txt"

# ============================================================
# Case 1: 初回 — state file なし → 再生成 + state file 作成
# ============================================================

rm -f "$STATE_FILE"
OUT="$(echo "" | PROJECT_ROOT="$TMP_PROJ" bash "$HANDLER" 2>"$TMP_PROJ/c1-stderr.txt")"

if echo "$OUT" | jq -e '.ok == true' >/dev/null 2>&1; then
  pass "Case 1 (初回): JSON {ok:true} 返却"
else
  fail "Case 1: bad JSON. got: $OUT"
fi

if echo "$OUT" | jq -e '.regenerated == true' >/dev/null 2>&1; then
  pass "Case 1 (初回): regenerated:true マーカー"
else
  fail "Case 1: regenerated marker missing. got: $OUT"
fi

# background regen が完了するまで少し待つ
sleep 1

if [[ -f "$STATE_FILE" ]]; then
  pass "Case 1 (初回): state file 作成された"
else
  fail "Case 1: state file 未作成"
fi

# state file は epoch seconds (整数)
LAST_VAL="$(cat "$STATE_FILE" 2>/dev/null || echo "")"
if [[ "$LAST_VAL" =~ ^[0-9]+$ ]]; then
  pass "Case 1 (初回): state file 内容が epoch seconds (整数)"
else
  fail "Case 1: state file 内容が epoch でない. got: $LAST_VAL"
fi

# ============================================================
# Case 2: 60 秒以内 — state file あり (last 30 秒前) → skip
# ============================================================

# 30 秒前の epoch を state file に書く
NOW="$(date +%s)"
echo $((NOW - 30)) > "$STATE_FILE"

OUT="$(echo "" | PROJECT_ROOT="$TMP_PROJ" bash "$HANDLER" 2>"$TMP_PROJ/c2-stderr.txt")"

if echo "$OUT" | jq -e '.skipped == "rate-limit"' >/dev/null 2>&1; then
  pass "Case 2 (30秒前): skipped:rate-limit"
else
  fail "Case 2: rate-limit skip not triggered. got: $OUT"
fi

# state file は変更されていない
LAST_VAL_AFTER="$(cat "$STATE_FILE")"
if [[ "$LAST_VAL_AFTER" == "$((NOW - 30))" ]]; then
  pass "Case 2 (rate-limit): state file 未更新"
else
  fail "Case 2: state file 更新された (skip だったはず). before=$((NOW - 30)) after=$LAST_VAL_AFTER"
fi

# ============================================================
# Case 3: 60 秒超 — state file あり (last 90 秒前) → 再生成
# ============================================================

NOW="$(date +%s)"
echo $((NOW - 90)) > "$STATE_FILE"

OUT="$(echo "" | PROJECT_ROOT="$TMP_PROJ" bash "$HANDLER" 2>"$TMP_PROJ/c3-stderr.txt")"

if echo "$OUT" | jq -e '.regenerated == true' >/dev/null 2>&1; then
  pass "Case 3 (90秒前): 再生成実行"
else
  fail "Case 3: regenerated marker missing. got: $OUT"
fi

sleep 1

LAST_VAL_C3="$(cat "$STATE_FILE")"
if [[ "$LAST_VAL_C3" -gt "$((NOW - 90))" ]]; then
  pass "Case 3 (90秒前): state file 更新された"
else
  fail "Case 3: state file 未更新. before=$((NOW - 90)) after=$LAST_VAL_C3"
fi

# ============================================================
# Case 4: hook input 不正 — stdin 空 / EOF / large input
# ============================================================

# 4-a: 空 stdin
OUT="$(echo -n "" | PROJECT_ROOT="$TMP_PROJ" bash "$HANDLER" 2>/dev/null)"
if echo "$OUT" | jq -e '.ok == true' >/dev/null 2>&1; then
  pass "Case 4-a (empty stdin): {ok:true} 返却 (crash しない)"
else
  fail "Case 4-a: crashed or bad output. got: $OUT"
fi

# 4-b: 不正 JSON stdin
OUT="$(echo "not-json{garbage" | PROJECT_ROOT="$TMP_PROJ" bash "$HANDLER" 2>/dev/null)"
if echo "$OUT" | jq -e '.ok == true' >/dev/null 2>&1; then
  pass "Case 4-b (garbage stdin): {ok:true} 返却 (handler は stdin を読み捨てる)"
else
  fail "Case 4-b: bad output. got: $OUT"
fi

# 4-c: Plans.md なし → no-plans-md skipped
TMP_PROJ_NO_PLANS="$(mktemp -d "${TMPDIR:-/tmp}/test-progress-no-plans.XXXXXX")"
trap "rm -rf '$TMP_PROJ' '$TMP_PROJ_NO_PLANS'" EXIT
mkdir -p "$TMP_PROJ_NO_PLANS/.claude/state"
OUT="$(echo "" | PROJECT_ROOT="$TMP_PROJ_NO_PLANS" bash "$HANDLER" 2>/dev/null)"
if echo "$OUT" | jq -e '.skipped == "no-plans-md"' >/dev/null 2>&1; then
  pass "Case 4-c (no Plans.md): skipped:no-plans-md"
else
  fail "Case 4-c: bad output. got: $OUT"
fi

# ============================================================
# Case 5: locale は cwd ではなく PROJECT_ROOT の config から解決する
# (この test の cwd は i18n.language: en の repo root)
# ============================================================

TMP_PROJ_JA="$(mktemp -d "${TMPDIR:-/tmp}/test-progress-regen-ja.XXXXXX")"
trap "rm -rf '$TMP_PROJ' '$TMP_PROJ_NO_PLANS' '$TMP_PROJ_JA'" EXIT
cp "$TMP_PROJ/Plans.md" "$TMP_PROJ_JA/Plans.md"
printf 'i18n:\n  language: ja\n' > "$TMP_PROJ_JA/.claude-code-harness.config.yaml"
echo "" | env -u CONFIG_FILE -u CLAUDE_CODE_HARNESS_LANG PROJECT_ROOT="$TMP_PROJ_JA" bash "$HANDLER" >/dev/null 2>&1
for _ in $(seq 1 50); do
  [[ -s "$TMP_PROJ_JA/out/progress-snapshot.html" ]] && break
  sleep 0.2
done
if grep -q '<html lang="ja">' "$TMP_PROJ_JA/out/progress-snapshot.html" 2>/dev/null; then
  pass "Case 5: ja project regenerated from an en cwd renders lang=ja"
else
  fail "Case 5: locale resolved from cwd instead of PROJECT_ROOT. got: $(grep -o '<html lang="[a-z]*">' "$TMP_PROJ_JA/out/progress-snapshot.html" 2>/dev/null)"
fi

# ============================================================
# 共通検証: dual hooks.json sync (P29 規約)
# ============================================================

if diff -q "$ROOT_DIR/.claude-plugin/hooks.json" "$ROOT_DIR/hooks/hooks.json" >/dev/null 2>&1; then
  pass "dual hooks.json sync: .claude-plugin と hooks/ が完全一致"
else
  fail "dual hooks.json sync 違反: 2 ファイル不一致"
fi

# JSON validity
for f in "$ROOT_DIR/.claude-plugin/hooks.json" "$ROOT_DIR/hooks/hooks.json"; do
  if jq -e . "$f" >/dev/null 2>&1; then
    pass "$(basename "$(dirname "$f")")/hooks.json: JSON valid"
  else
    fail "$(basename "$(dirname "$f")")/hooks.json: JSON invalid"
  fi
done

# posttool-progress-regen.sh エントリが両方に存在
for f in "$ROOT_DIR/.claude-plugin/hooks.json" "$ROOT_DIR/hooks/hooks.json"; do
  if grep -q "posttool-progress-regen.sh" "$f"; then
    pass "$(basename "$(dirname "$f")")/hooks.json: posttool-progress-regen.sh エントリ存在"
  else
    fail "$(basename "$(dirname "$f")")/hooks.json: hook エントリ未追加"
  fi
done

# PostToolUse 配下に存在することを確認 (jq path query)
for f in "$ROOT_DIR/.claude-plugin/hooks.json" "$ROOT_DIR/hooks/hooks.json"; do
  if jq -e '
    .hooks.PostToolUse | map(.hooks[]?.command? // "" | tostring)
    | flatten
    | map(select(test("posttool-progress-regen")))
    | length > 0
  ' "$f" >/dev/null 2>&1; then
    pass "$(basename "$(dirname "$f")")/hooks.json: PostToolUse 配下に登録"
  else
    fail "$(basename "$(dirname "$f")")/hooks.json: PostToolUse 配下に未登録"
  fi
done

# ============================================================
# Result
# ============================================================

echo ""
echo "============================================================"
echo "Test Summary (test-progress-regen.sh)"
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
