#!/bin/bash
# tests/test-risk-flag-escalation.sh
# Phase 134.8 - 実効性契約テスト: risk_flags → reviewer_profile 自動昇格 + ratchet (Phase 134.1)。
#
# scripts/generate-sprint-contract.js で下地の sprint-contract.json を作り、
# scripts/enrich-sprint-contract.sh --risk / scripts/ensure-sprint-contract-ready.sh --approve
# の実スクリプトを実際に叩いて確認する (契約テストなので中身の再実装はしない)。
#
# 検証観点:
#   (a) security-sensitive 単独で --approve すると profile が runtime 以上へ自動昇格し、承認できる
#   (b) 昇格テーブル外の flag (perf-sensitive) では profile が static のまま (昇格しない)
#   (c) --profile static を明示指定しつつ --profile-override-reason 無しで security-sensitive を
#       付けた場合、ensure-sprint-contract-ready.sh の ratchet が fail-closed (exit 5) する
#       (enrich 側の自動昇格を override 指定で迂回した状態を、ensure 側が独立に再検査する)
#   (d) --profile-override-reason 付きなら ratchet を意図的に通過できる (fail-open ではなく
#       「理由を記録した上での意図的固定」であることの確認)
#
# Usage: bash tests/test-risk-flag-escalation.sh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GENERATE_JS="$ROOT_DIR/scripts/generate-sprint-contract.js"
# ENRICH_SCRIPT / ENSURE_SCRIPT env overrides exist only so this test can be
# pointed at a deliberately-unwired copy of the two scripts for RED
# verification (see notes in the Phase 134.8 worker report). Default is the
# real, shipped scripts.
ENRICH="${ENRICH_SCRIPT:-$ROOT_DIR/scripts/enrich-sprint-contract.sh}"
ENSURE="${ENSURE_SCRIPT:-$ROOT_DIR/scripts/ensure-sprint-contract-ready.sh}"

PASS=0
FAIL=0
pass() { PASS=$((PASS + 1)); echo "✓ $1"; }
fail() { FAIL=$((FAIL + 1)); echo "✗ $1" >&2; }

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/risk-flag-escalation-test.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT

make_contract() {
  local task_id="$1"
  local out="$2"
  cat > "$WORK_DIR/Plans.md" <<EOF
| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| ${task_id} | test task | test dod | - | cc:todo |
EOF
  node "$GENERATE_JS" "$task_id" "$WORK_DIR/Plans.md" "$out" >/dev/null
}

# ---- (a) security-sensitive 単独 → profile が runtime 以上へ自動昇格 ----
# generate-sprint-contract.js の既定 reviewer_profile は既に "runtime" なので、
# 昇格そのものを検証するにはまず static へ明示的に落としてから --risk を渡す。
CONTRACT_A="$WORK_DIR/contract-a.json"
make_contract "134.8-a" "$CONTRACT_A"

"$ENRICH" "$CONTRACT_A" --profile "static" --risk "security-sensitive" --approve >/dev/null

if "$ENSURE" "$CONTRACT_A" >/dev/null 2>&1; then
  pass "(a) security-sensitive 単独で approve が通る (ratchet 満たしている)"
else
  fail "(a) security-sensitive 単独の approve が通らなかった (ensure exit=$?)"
fi

PROFILE_A="$(jq -r '.review.reviewer_profile' "$CONTRACT_A")"
if [ "$PROFILE_A" = "runtime" ] || [ "$PROFILE_A" = "browser" ] || [ "$PROFILE_A" = "ui-rubric" ]; then
  pass "(a) profile が runtime 以上へ自動昇格した (got: $PROFILE_A)"
else
  fail "(a) profile が昇格していない (got: $PROFILE_A, expected runtime 以上)"
fi

# ---- (b) 昇格テーブル外の flag (perf-sensitive) では profile 不変 ----
CONTRACT_B="$WORK_DIR/contract-b.json"
make_contract "134.8-b" "$CONTRACT_B"

"$ENRICH" "$CONTRACT_B" --profile "static" --risk "perf-sensitive" --approve >/dev/null

PROFILE_B="$(jq -r '.review.reviewer_profile' "$CONTRACT_B")"
if [ "$PROFILE_B" = "static" ]; then
  pass "(b) 昇格テーブル外の flag (perf-sensitive) では profile が static のまま (negative test)"
else
  fail "(b) 昇格テーブル外の flag なのに profile が変化した (got: $PROFILE_B)"
fi

if "$ENSURE" "$CONTRACT_B" >/dev/null 2>&1; then
  pass "(b) perf-sensitive のみなら static profile でも approve が通る"
else
  fail "(b) perf-sensitive のみで static profile の approve が通らなかった"
fi

# ---- (c) --profile static 明示 + security-sensitive risk_flag (override reason 無し)
#          → ensure 側の ratchet が独立に fail-closed する ----
CONTRACT_C="$WORK_DIR/contract-c.json"
make_contract "134.8-c" "$CONTRACT_C"

"$ENRICH" "$CONTRACT_C" --risk "security-sensitive" --profile "static" --approve >/dev/null

PROFILE_C="$(jq -r '.review.reviewer_profile' "$CONTRACT_C")"
set +e
"$ENSURE" "$CONTRACT_C" >"$WORK_DIR/ensure-c.log" 2>&1
ENSURE_C_EXIT=$?
set -e

if [ "$PROFILE_C" = "static" ] && [ "$ENSURE_C_EXIT" -eq 5 ]; then
  pass "(c) --profile static で意図的に自動昇格を迂回しても、ensure 側の ratchet が独立に fail-closed する (exit 5)"
else
  fail "(c) ratchet が fail-closed しなかった (profile=$PROFILE_C, ensure exit=$ENSURE_C_EXIT, log: $(cat "$WORK_DIR/ensure-c.log"))"
fi

# ---- (d) --profile-override-reason 付きなら ratchet を意図的に通過できる ----
CONTRACT_D="$WORK_DIR/contract-d.json"
make_contract "134.8-d" "$CONTRACT_D"

"$ENRICH" "$CONTRACT_D" --risk "security-sensitive" --profile "static" \
  --profile-override-reason "static-only: covered by dedicated security review outside this contract" \
  --approve >/dev/null

if "$ENSURE" "$CONTRACT_D" >/dev/null 2>&1; then
  pass "(d) profile-override-reason 付きなら ratchet を意図的に通過できる (fail-open ではなく理由記録付きの意図的固定)"
else
  fail "(d) profile-override-reason を付けても approve が通らなかった"
fi

if jq -e '(.review.reviewer_notes // []) | any(startswith("profile-override-reason: "))' "$CONTRACT_D" >/dev/null 2>&1; then
  pass "(d) profile-override-reason が review.reviewer_notes に記録されている"
else
  fail "(d) profile-override-reason が reviewer_notes に記録されていない"
fi

# ---- サマリ ----
echo ""
echo "============================================"
echo "PASS=$PASS FAIL=$FAIL"
if [ "$FAIL" -eq 0 ]; then
  echo "All assertions passed."
  exit 0
fi
exit 1
