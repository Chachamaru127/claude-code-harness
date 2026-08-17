#!/bin/bash
# scripts/ci/check-verification-chain-wiring.sh
# Phase 134.8 - 検証チェーン (Phase 134.1-134.6) の配線が切れていないかを機械検証する。
#
# Phase 134 の Purpose どおり、検証機構そのものは実装されていても継ぎ目で切れると
# 静かに無力化する (「配線した ≠ 効いている」D58)。このゲートは 5 点の配線が
# 実際にソース上に存在するかを grep/go list で確認する static gate であり、
# 実効性 (RED→GREEN) の確認は tests/test-risk-flag-escalation.sh /
# tests/test-pending-browser-visible.sh / tests/test-scope-leash-fires-on-security-diff.sh
# の 3 契約テストが担当する (このスクリプトは「存在確認」まで)。
#
# 5 点:
#   1. scope leash: go/internal/guardrail が go/internal/scopeleash を import している (go list -deps)
#   2. fail-visible producer: scripts/write-review-result.sh の出力に pending_validations がある
#   3. evidence 機械接続: skills/harness-accept/SKILL.md が accept-collect-evidence.sh を呼んでいる
#   4. risk_flags 昇格テーブル: scripts/enrich-sprint-contract.sh に security-sensitive/data-migration/
#      ux-regression の 3 mapping がある
#   5. ratchet: scripts/ensure-sprint-contract-ready.sh が risk_flags から最低 profile を再計算し
#      不足時に fail-closed (exit 5) する
#
# Usage: bash scripts/ci/check-verification-chain-wiring.sh [path/to/repo/root]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

ROOT_DIR="${1:-$DEFAULT_ROOT}"
ROOT_DIR="$(cd "$ROOT_DIR" && pwd)"

ERRORS=0

echo "=== Verification Chain Wiring Check ==="
echo ""

# ---- 1. scope leash import (go list -deps) ----
GO_DIR="$ROOT_DIR/go"
if [ -f "$GO_DIR/go.mod" ]; then
  GUARDRAIL_DEPS="$(cd "$GO_DIR" && go list -deps ./internal/guardrail/... 2>/dev/null || true)"
  if grep -q "/internal/scopeleash$" <<<"$GUARDRAIL_DEPS"; then
    echo "✅ (1) go/internal/guardrail imports go/internal/scopeleash (go list -deps)"
  else
    echo "❌ (1) go/internal/guardrail does NOT import go/internal/scopeleash — scope leash is unwired"
    ERRORS=$((ERRORS + 1))
  fi
else
  echo "❌ (1) $GO_DIR/go.mod not found — cannot verify scope leash import"
  ERRORS=$((ERRORS + 1))
fi

# ---- 2. fail-visible producer: pending_validations ----
WRITE_REVIEW_RESULT="$ROOT_DIR/scripts/write-review-result.sh"
if [ -f "$WRITE_REVIEW_RESULT" ] && grep -q "pending_validations" "$WRITE_REVIEW_RESULT"; then
  echo "✅ (2) scripts/write-review-result.sh emits pending_validations"
else
  echo "❌ (2) scripts/write-review-result.sh does NOT emit pending_validations — fail-visible producer is unwired"
  ERRORS=$((ERRORS + 1))
fi

# ---- 3. evidence 機械接続: SKILL.md の collect-evidence 呼び出し ----
HARNESS_ACCEPT_SKILL="$ROOT_DIR/skills/harness-accept/SKILL.md"
if [ -f "$HARNESS_ACCEPT_SKILL" ] && grep -q "accept-collect-evidence.sh" "$HARNESS_ACCEPT_SKILL"; then
  echo "✅ (3) skills/harness-accept/SKILL.md calls scripts/accept-collect-evidence.sh"
else
  echo "❌ (3) skills/harness-accept/SKILL.md does NOT call scripts/accept-collect-evidence.sh — exit-side evidence read is unwired"
  ERRORS=$((ERRORS + 1))
fi

# ---- 4. risk_flags → reviewer_profile 昇格テーブル ----
ENRICH_SCRIPT="$ROOT_DIR/scripts/enrich-sprint-contract.sh"
ESCALATION_MISSING=()
if [ -f "$ENRICH_SCRIPT" ]; then
  for pair in "security-sensitive.*runtime" "data-migration.*runtime" "ux-regression.*browser"; do
    if ! grep -qE "$pair" "$ENRICH_SCRIPT"; then
      ESCALATION_MISSING+=("$pair")
    fi
  done
  if [ "${#ESCALATION_MISSING[@]}" -eq 0 ]; then
    echo "✅ (4) scripts/enrich-sprint-contract.sh has the risk_flags → reviewer_profile escalation table (security-sensitive/data-migration/ux-regression)"
  else
    echo "❌ (4) scripts/enrich-sprint-contract.sh is missing escalation mapping(s): ${ESCALATION_MISSING[*]}"
    ERRORS=$((ERRORS + 1))
  fi
else
  echo "❌ (4) $ENRICH_SCRIPT not found"
  ERRORS=$((ERRORS + 1))
fi

# ---- 5. ratchet: ensure-sprint-contract-ready.sh の fail-closed 再計算 ----
ENSURE_SCRIPT="$ROOT_DIR/scripts/ensure-sprint-contract-ready.sh"
if [ -f "$ENSURE_SCRIPT" ] \
  && grep -q "required_profile_for_risk" "$ENSURE_SCRIPT" \
  && grep -qE "exit 5\b" "$ENSURE_SCRIPT"; then
  echo "✅ (5) scripts/ensure-sprint-contract-ready.sh recomputes the risk-flag minimum profile and fails closed (exit 5) when below it (ratchet)"
else
  echo "❌ (5) scripts/ensure-sprint-contract-ready.sh does NOT re-derive the minimum profile from risk_flags with a fail-closed exit — ratchet is unwired"
  ERRORS=$((ERRORS + 1))
fi

echo ""
if [ $ERRORS -eq 0 ]; then
  echo "✅ すべての配線チェックに合格しました (5/5)"
  exit 0
else
  echo "❌ $ERRORS 件の配線が切れています"
  exit 1
fi
