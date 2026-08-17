#!/usr/bin/env bash
# Phase 135.4 — writing-rule-approve.sh / writing-rule-list.sh contract tests.
#
# Everything runs against a tempdir HOME so we never touch the real
# ~/.claude/writing-lint files.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APPROVE="$ROOT/scripts/writing-rule-approve.sh"
LIST="$ROOT/scripts/writing-rule-list.sh"

PASS=0
FAIL=0
FAIL_MESSAGES=()

pass() { PASS=$((PASS + 1)); echo "✓ $1" >&2; }
fail() { FAIL=$((FAIL + 1)); FAIL_MESSAGES+=("$1"); echo "✗ $1" >&2; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/writing-rule-approve-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

REAL_HOME="$HOME"
export HOME="$TMP/home"
mkdir -p "$HOME"

PROPOSALS="$HOME/.claude/writing-lint/proposals.jsonl"
RULES="$HOME/.claude/writing-lint/rules.jsonl"
mkdir -p "$(dirname "$PROPOSALS")"

if [[ ! -x "$APPROVE" || ! -x "$LIST" ]]; then
  fail "pre-flight: writing-rule-approve.sh / writing-rule-list.sh missing or not executable"
  echo "PASS=$PASS FAIL=$FAIL"
  exit 1
fi
pass "pre-flight: scripts exist and are executable"

cat >"$PROPOSALS" <<'JSON'
{"id": "no-meta-narration-fixture", "pattern": "以下の点をご確認ください", "good": "本題から直接書く", "status": "pending", "scenes": ["chat"], "severity": "warning", "evidence": "operator rewrote the meta-narration opener", "created_at": "2026-08-15T00:00:00Z"}
JSON

## (a) approve promotes pending -> approved and appends rules.jsonl -------

approve_out="$(bash "$APPROVE" --id no-meta-narration-fixture)"
if grep -q "approved: no-meta-narration-fixture" <<<"$approve_out"; then
  pass "approve: prints confirmation"
else
  fail "approve: prints confirmation (got: $approve_out)"
fi

if [[ -f "$RULES" ]] && grep -q '"id": "no-meta-narration-fixture"' "$RULES"; then
  pass "approve: rules.jsonl contains the promoted rule"
else
  fail "approve: rules.jsonl contains the promoted rule"
fi

if python3 - "$RULES" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as f:
    lines = [json.loads(l) for l in f if l.strip()]
rule = next(r for r in lines if r["id"] == "no-meta-narration-fixture")
assert rule["pattern"] == "以下の点をご確認ください"
assert rule["good"] == "本題から直接書く"
assert rule["enabled"] is True
assert rule["scenes"] == ["chat"]
assert rule["severity"] == "warning"
PY
then
  pass "approve: promoted rule matches writing-rule.v1 shape"
else
  fail "approve: promoted rule matches writing-rule.v1 shape"
fi

if python3 - "$PROPOSALS" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as f:
    lines = [json.loads(l) for l in f if l.strip()]
rec = next(r for r in lines if r["id"] == "no-meta-narration-fixture")
assert rec["status"] == "approved", rec
assert "decided_at" in rec
PY
then
  pass "approve: proposals.jsonl status flips to approved with decided_at"
else
  fail "approve: proposals.jsonl status flips to approved with decided_at"
fi

# re-approving an already-approved proposal must fail (no double promotion)
set +e
bash "$APPROVE" --id no-meta-narration-fixture >/tmp/writing-rule-approve-reapprove.$$ 2>&1
reapprove_rc=$?
set -e
if [[ "$reapprove_rc" -ne 0 ]]; then
  pass "approve: re-approving an already-decided proposal fails"
else
  fail "approve: re-approving an already-decided proposal fails"
fi
rm -f "/tmp/writing-rule-approve-reapprove.$$"

## reject path -------------------------------------------------------------

cat >>"$PROPOSALS" <<'JSON'
{"id": "reject-fixture", "pattern": "とても良い", "good": "具体的な理由を書く", "status": "pending"}
JSON

reject_out="$(bash "$APPROVE" --id reject-fixture --reject)"
if grep -q "rejected: reject-fixture" <<<"$reject_out"; then
  pass "reject: prints confirmation"
else
  fail "reject: prints confirmation (got: $reject_out)"
fi

if grep -q '"id": "reject-fixture"' "$RULES" 2>/dev/null; then
  fail "reject: rejected proposal must NOT be written to rules.jsonl"
else
  pass "reject: rejected proposal is not written to rules.jsonl"
fi

## (d) regression: an RE2-uncompilable pattern is rejected at approval time
## (silent-disable finding: schema validation alone never compile-checked
## `pattern`; without the fail-closed `harness writing-rule-vet` gate this
## proposal would reach rules.jsonl and later silently disable writing-lint
## scanning for every rule sharing the dictionary) -------------------------

cat >>"$PROPOSALS" <<'JSON'
{"id": "bad-lookahead-fixture", "pattern": "(?=foo)bar", "good": "g", "status": "pending"}
JSON

set +e
bad_out="$(bash "$APPROVE" --id bad-lookahead-fixture 2>&1)"
bad_rc=$?
set -e
if [[ "$bad_rc" -ne 0 ]]; then
  pass "approve: an RE2-uncompilable pattern is rejected (exit != 0)"
else
  fail "approve: an RE2-uncompilable pattern is rejected (exit != 0) (got: $bad_out)"
fi

if grep -q "writing-rule-vet" <<<"$bad_out"; then
  pass "approve: rejection message names writing-rule-vet"
else
  fail "approve: rejection message names writing-rule-vet (got: $bad_out)"
fi

if grep -q '"id": "bad-lookahead-fixture"' "$RULES" 2>/dev/null; then
  fail "approve: RE2-uncompilable pattern must NOT reach rules.jsonl"
else
  pass "approve: RE2-uncompilable pattern is not written to rules.jsonl"
fi

## (d2) regression: a vet-rejected proposal stays pending and can be
## re-approved after the pattern is fixed (stuck-approved finding: status
## was persisted before the vet gate, so a rejected proposal was frozen at
## approved and the same id could never be retried) -------------------------

bad_status="$(python3 -c "
import json
for line in open('$PROPOSALS', encoding='utf-8'):
    rec = json.loads(line)
    if rec.get('id') == 'bad-lookahead-fixture':
        print(rec.get('status'))
")"
if [[ "$bad_status" == "pending" ]]; then
  pass "approve: vet-rejected proposal stays pending (not stuck at approved)"
else
  fail "approve: vet-rejected proposal stays pending (got status=$bad_status)"
fi

python3 -c "
import json
lines = []
for line in open('$PROPOSALS', encoding='utf-8'):
    rec = json.loads(line)
    if rec.get('id') == 'bad-lookahead-fixture':
        rec['pattern'] = 'foobar'
    lines.append(json.dumps(rec, ensure_ascii=False))
open('$PROPOSALS', 'w', encoding='utf-8').write('\n'.join(lines) + '\n')
"
set +e
retry_out="$(bash "$APPROVE" --id bad-lookahead-fixture 2>&1)"
retry_rc=$?
set -e
if [[ "$retry_rc" -eq 0 ]] && grep -q '"id": "bad-lookahead-fixture"' "$RULES"; then
  pass "approve: same id can be re-approved after fixing the pattern"
else
  fail "approve: same id can be re-approved after fixing the pattern (rc=$retry_rc, got: $retry_out)"
fi

## writing-rule-list.sh -----------------------------------------------------

cat >>"$PROPOSALS" <<'JSON'
{"id": "still-pending-fixture", "pattern": "非常に", "good": "強調語を数値・事実に置き換える", "status": "pending"}
JSON

list_out="$(bash "$LIST")"
if grep -q "still-pending-fixture" <<<"$list_out" && ! grep -q "no-meta-narration-fixture" <<<"$list_out"; then
  pass "list: default view shows only pending proposals"
else
  fail "list: default view shows only pending proposals (got: $list_out)"
fi

if grep -q "scripts/writing-rule-approve.sh --id still-pending-fixture" <<<"$list_out"; then
  pass "list: includes the copy-paste approve command"
else
  fail "list: includes the copy-paste approve command"
fi

json_out="$(bash "$LIST" --json)"
if python3 - "$json_out" <<'PY'
import json, sys
data = json.loads(sys.argv[1])
assert isinstance(data, list)
assert len(data) == 1
assert data[0]["id"] == "still-pending-fixture"
PY
then
  pass "list --json: emits a filtered JSON array"
else
  fail "list --json: emits a filtered JSON array (got: $json_out)"
fi

## (b) regression: newly-approved rule is hit by the writinglint engine -----

REPO="$TMP/repo"
mkdir -p "$REPO"
cat >"$REPO/.claude-code-harness.config.yaml" <<'YAML'
writing_lint:
  enabled: true
YAML
cat >"$REPO/note.md" <<'MD'
以下の点をご確認ください。作業は完了しました。
MD

BUILD_DIR="$TMP/build"
mkdir -p "$BUILD_DIR"
# go build needs the real HOME (module cache / GOCACHE) — not the fixture HOME above.
if ! (cd "$ROOT/go" && HOME="$REAL_HOME" go build -o "$BUILD_DIR/harness-test" ./cmd/harness) 2>"$TMP/build.log"; then
  fail "regression: go build ./cmd/harness (see $TMP/build.log)"
else
  pass "regression: go build ./cmd/harness"

  hook_payload='{"tool_name":"Write","tool_input":{"file_path":"note.md"},"cwd":"'"$REPO"'"}'
  scan_out="$(cd "$REPO" && CLAUDE_WRITING_LINT_DICT="$RULES" "$BUILD_DIR/harness-test" hook writing-lint <<<"$hook_payload")"

  if grep -q "no-meta-narration-fixture" <<<"$scan_out" && grep -q "本題から直接書く" <<<"$scan_out"; then
    pass "regression: re-scan after approval hits the newly promoted rule"
  else
    fail "regression: re-scan after approval hits the newly promoted rule (got: $scan_out)"
  fi
fi

## (c) no automatic promotion path exists ------------------------------------

if grep -rn "writing-rule-approve.sh" "$ROOT/hooks/hooks.json" "$ROOT/.claude-plugin/hooks.json" >/dev/null 2>&1; then
  fail "no-auto-promotion: writing-rule-approve.sh must not be wired into any hook"
else
  pass "no-auto-promotion: writing-rule-approve.sh is not wired into hooks.json"
fi

if grep -rln "writing-rule-approve" "$ROOT/go" --include='*.go' | grep -v '_test.go' >/dev/null 2>&1; then
  fail "no-auto-promotion: no Go code should invoke writing-rule-approve.sh programmatically"
else
  pass "no-auto-promotion: no Go code invokes writing-rule-approve.sh"
fi

if grep -rn "status.*=.*\"approved\"\|status.*:.*\"approved\"" "$ROOT/skills/japanese-writing-drafter/SKILL.md" >/dev/null 2>&1; then
  fail "no-auto-promotion: japanese-writing-drafter must never write status:approved itself"
else
  pass "no-auto-promotion: japanese-writing-drafter only ever writes status:pending"
fi

echo ""
echo "PASS=$PASS FAIL=$FAIL"
if [[ "$FAIL" -gt 0 ]]; then
  for msg in "${FAIL_MESSAGES[@]}"; do
    echo "  - $msg" >&2
  done
  exit 1
fi

echo "test-writing-rule-approve: ok"
