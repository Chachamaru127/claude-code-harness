#!/usr/bin/env bash
#
# Guard the harness-plan planning quality contract across shipped skill mirrors.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

fail() {
  echo "test-harness-plan-quality: FAIL: $*" >&2
  exit 1
}

assert_file() {
  local path="$1"
  [ -f "$path" ] || fail "missing file: $path"
}

assert_absent() {
  local path="$1"
  local needle="$2"
  if grep -qF "$needle" "$path"; then
    fail "$path should not contain: $needle"
  fi
}

assert_contains() {
  local path="$1"
  local needle="$2"
  if ! grep -qF "$needle" "$path"; then
    fail "$path missing: $needle"
  fi
}

plan_output_contract_valid() {
  local output="$1"

  { grep -qF "Spec delta:" <<<"$output" || grep -qF "Spec skip reason:" <<<"$output"; } \
    && grep -qF "Plans.md:" <<<"$output"
}

nontrivial_planning_gate_valid() {
  local output="$1"

  { grep -qF "team_validation_mode: native" <<<"$output" \
      || grep -qF "team_validation_mode: subagent" <<<"$output" \
      || grep -qF "team_validation_mode: manual-pass" <<<"$output"; } \
    && grep -qF "Spec / Plans Fit:" <<<"$output" \
    && grep -qF "Memory / Wheel Check:" <<<"$output" \
    && grep -qF "Product Fit:" <<<"$output" \
    && grep -qF "Security Fit:" <<<"$output" \
    && grep -qF "Quality Baseline Fit:" <<<"$output" \
    && grep -qF "Works In Practice:" <<<"$output" \
    && ! grep -qF "team_validation_mode: unavailable" <<<"$output"
}

lightweight_planning_gate_valid() {
  local output="$1"

  grep -qF "team_validation_mode: not_required_lightweight" <<<"$output" \
    && grep -qF "Spec skip reason:" <<<"$output" \
    && grep -qF "Plans.md:" <<<"$output"
}

security_gate_avoids_secret_read() {
  local output="$1"

  grep -qF "Security Fit:" <<<"$output" \
    && grep -qF "do not read secrets" <<<"$output" \
    && grep -qF "Risk Gate" <<<"$output" \
    && ! grep -qE 'cat \.env|Read \.env|open secret|print token' <<<"$output"
}

assert_plan_output_contract_valid() {
  local label="$1"
  local output="$2"

  if ! plan_output_contract_valid "$output"; then
    fail "$label should include Spec delta or Spec skip reason plus Plans.md"
  fi
}

assert_plan_output_contract_invalid() {
  local label="$1"
  local output="$2"

  if plan_output_contract_valid "$output"; then
    fail "$label should fail without Spec delta or Spec skip reason"
  fi
}

assert_nontrivial_gate_valid() {
  local label="$1"
  local output="$2"

  if ! nontrivial_planning_gate_valid "$output"; then
    fail "$label should include team validation plus Spec/Memory/Product/Security/Works gates"
  fi
}

assert_nontrivial_gate_invalid() {
  local label="$1"
  local output="$2"

  if nontrivial_planning_gate_valid "$output"; then
    fail "$label should fail without complete non-trivial planning gates"
  fi
}

assert_lightweight_gate_valid() {
  local label="$1"
  local output="$2"

  if ! lightweight_planning_gate_valid "$output"; then
    fail "$label should allow not_required_lightweight for lightweight work"
  fi
}

assert_security_gate_safe() {
  local label="$1"
  local output="$2"

  if ! security_gate_avoids_secret_read "$output"; then
    fail "$label should avoid requiring secret reads"
  fi
}

primary_surfaces=(
  "skills/harness-plan"
  "codex/.codex/skills/harness-plan"
)

check_plan_surface() {
  local surface="$1"
  skill="$surface/SKILL.md"
  create_ref="$surface/references/create.md"
  quality_ref="$surface/references/planning-quality.md"

  assert_file "$skill"
  assert_file "$create_ref"
  assert_file "$quality_ref"

  assert_contains "$skill" "Research-backed, team-validated task planning"
  assert_contains "$skill" "team-validated task planning"
  assert_contains "$skill" "### 標準の計画品質契約"
  assert_contains "$skill" "See [references/planning-quality.md]"
  assert_contains "$skill" "Non-trivial planning gate"
  assert_contains "$skill" "TeamAgent またはサブエージェント前提"
  assert_contains "$skill" "Product / Architecture / Security / QA / Skeptic"
  assert_contains "$skill" "Required / Recommended / Optional / Reject"
  assert_contains "$skill" "車輪の再発明防止確認"
  assert_contains "$skill" "プロダクト目的から外れていないか"
  assert_contains "$skill" "セキュリティ、権限、秘密情報、サプライチェーン"
  assert_contains "$skill" "lint / formatter baseline"
  assert_contains "$skill" "source code changes"
  assert_contains "$skill" "ちゃんと動く計画か"
  assert_contains "$skill" '`team_validation_mode`: `not_required_lightweight` / `native` / `subagent` / `manual-pass` / `unavailable`'
  assert_contains "$skill" '`unavailable` のまま Required にしてはいけない'
  assert_contains "$skill" "agent_type 名ではない"
  assert_contains "$skill" "任意 agent spawn を要求しない"
  assert_contains "$skill" "Security gate は秘密情報の実読取を要求しない"
  assert_contains "$skill" "co-required planning output"
  assert_contains "$skill" "spec.md > sub-spec > Plans.md"
  assert_contains "$skill" "spec.md product contract and Plans.md task contract"
  assert_contains "$skill" '`/harness-plan create` は `Spec delta` または `Spec skip reason` と `Plans.md` task 生成をセットで返す'
  assert_contains "$skill" "Harness が生成し、consumer は承認・修正だけ"
  assert_contains "$skill" '`create` と product-impacting `add` は毎回 root `spec.md` を読む'
  assert_contains "$skill" '出力には必ず `Spec delta` または `Spec skip reason` を含める'
  assert_contains "$skill" 'consumer repo に root `spec.md` がない時だけ'
  assert_contains "$skill" "not_observed != absent"

  assert_absent "$skill" "/harness-plan maxplan"
  assert_absent "$skill" "argument-hint: \"[create|maxplan"
  assert_absent "$skill" "### maxplan"

  assert_contains "$create_ref" "## Step 3: 計画品質チェック"
  assert_contains "$create_ref" "references/planning-quality.md"
  assert_contains "$create_ref" "TeamAgent またはサブエージェント前提"
  assert_contains "$create_ref" "Product / Architecture / Security / QA / Skeptic"
  assert_contains "$create_ref" "product fit、security fit、works in practice"
  assert_contains "$create_ref" '`formatter_baseline`'
  assert_contains "$create_ref" "lint / formatter が未設定なら setup task"
  assert_contains "$create_ref" "planning では package install しない"
  assert_contains "$create_ref" "Product Fit、Evidence Strength、User Value、Implementation Feasibility、Regression Safety、Strategic Leverage、Security Safety、Works In Practice"
  assert_contains "$create_ref" '`harness-mem` の DB は直接読まない'
  assert_contains "$create_ref" "車輪の再発明を避ける"
  assert_contains "$create_ref" '`サブエージェント未使用`'
  assert_contains "$create_ref" '`team_validation_mode` は `not_required_lightweight` / `native` / `subagent` / `manual-pass` / `unavailable`'
  assert_contains "$create_ref" "Product / Architecture / Security / QA / Skeptic は perspective 名であり agent_type 名ではない"
  assert_contains "$create_ref" 'Security gate は `.env` や secret の実読取を要求しない'
  assert_contains "$create_ref" "## Step 4.4: spec.md / Plans.md 二正本チェック"
  assert_contains "$create_ref" 'root `spec.md` を毎回読む'
  assert_contains "$create_ref" "Spec delta"
  assert_contains "$create_ref" "Spec skip reason"
  assert_contains "$create_ref" "co-required planning output"
  assert_contains "$create_ref" "Harness が生成し、consumer は承認・修正だけ"
  assert_contains "$create_ref" "ユーザーに spec を一から書かせない"
  assert_contains "$create_ref" "docs-only / mechanical task"

  assert_contains "$quality_ref" "これは独立サブコマンドではない"
  assert_contains "$quality_ref" "WebSearch"
  assert_contains "$quality_ref" "cross-project 検索は、ユーザーが明示した場合だけ使う"
  assert_contains "$quality_ref" "harness-mem の DB を直接読む前提にしない"
  assert_contains "$quality_ref" "TeamAgent / サブエージェントによる複数視点の議論"
  assert_contains "$quality_ref" "non-trivial planning では TeamAgent またはサブエージェント検証を前提にする"
  assert_contains "$quality_ref" '`team_validation_mode` を必ず入れる'
  assert_contains "$quality_ref" '`not_required_lightweight`'
  assert_contains "$quality_ref" '`manual-pass`'
  assert_contains "$quality_ref" 'non-trivial work を Required にしてはいけない'
  assert_contains "$quality_ref" '`team_validation_mode: unavailable` の plan は Required にしない'
  assert_contains "$quality_ref" "車輪の再発明防止確認"
  assert_contains "$quality_ref" '`create` と product-impacting `add` では root `spec.md` を毎回読む'
  assert_contains "$quality_ref" 'root `spec.md` がない consumer repo だけ'
  assert_contains "$quality_ref" "Spec delta"
  assert_contains "$quality_ref" "Spec skip reason"
  assert_contains "$quality_ref" "co-required planning output"
  assert_contains "$quality_ref" "not_observed != absent"
  assert_contains "$quality_ref" "Product / Strategy"
  assert_contains "$quality_ref" "Architecture / Implementation"
  assert_contains "$quality_ref" "Security / Abuse"
  assert_contains "$quality_ref" "perspective 名であり、agent_type 名ではない"
  assert_contains "$quality_ref" "任意 agent spawn を要求しない"
  assert_contains "$quality_ref" "QA / Regression"
  assert_contains "$quality_ref" "Skeptic"
  assert_contains "$quality_ref" "## Step 5.5: 実装プラン検証ゲート"
  assert_contains "$quality_ref" "Spec / Plans Fit"
  assert_contains "$quality_ref" "Memory / Wheel Check"
  assert_contains "$quality_ref" "Security Fit"
  assert_contains "$quality_ref" "Quality Baseline Fit"
  assert_contains "$quality_ref" "formatter_baseline setup task"
  assert_contains "$quality_ref" "source code changes"
  assert_contains "$quality_ref" "planning では package install しない"
  assert_contains "$quality_ref" "Works In Practice"
  assert_contains "$quality_ref" "Security Fit は secret の実読取を要求しない"
  assert_contains "$quality_ref" "Risk Gate として止める"
  assert_contains "$quality_ref" "Implementation Feasibility"
  assert_contains "$quality_ref" "Regression Safety"
  assert_contains "$quality_ref" "Security Safety"
  assert_contains "$quality_ref" "Works In Practice"
  assert_contains "$quality_ref" "導入先プロダクトの核に直結"
  assert_absent "$quality_ref" "Harness の核に直結"
  assert_contains "$quality_ref" "Evidence Strength が 2 以下なら Required 禁止"
  assert_contains "$quality_ref" "Regression Safety が 2 以下なら、先に spike / spec / test を置く"
  assert_contains "$quality_ref" "Security Safety が 2 以下なら Required 禁止"
  assert_contains "$quality_ref" "Works In Practice が 2 以下なら、DoD を作り直すか spike に落とす"
  assert_contains "$quality_ref" '## Step 7: `$easy` 報告'
}

for surface in "${primary_surfaces[@]}"; do
  check_plan_surface "$surface"
  assert_contains "$surface/SKILL.md" "purpose: \"Maintain co-required planning output for the spec.md product contract and Plans.md task contract\""
  assert_contains "$surface/SKILL.md" "argument-hint: \"[create|add|update|sync|sync --no-retro|--ci]\""
done

opencode_surface="opencode/skills/harness-plan"
check_plan_surface "$opencode_surface"
assert_absent "$opencode_surface/SKILL.md" "purpose: \"Maintain co-required planning output for the spec.md product contract and Plans.md task contract\""
assert_absent "$opencode_surface/SKILL.md" "argument-hint: \"[create|add|update|sync|sync --no-retro|--ci]\""
node scripts/validate-opencode.js >/dev/null

assert_contains "scripts/sync-skill-mirrors.sh" '".agents/skills"'
if [ -d ".agents/skills/harness-plan" ]; then
  check_plan_surface ".agents/skills/harness-plan"
fi

assert_plan_output_contract_valid "create fixture with Spec delta" "Spec delta:
- path: spec.md
- change: add product contract
Plans.md:
| Task | 内容 | DoD | Depends | Status |"

assert_plan_output_contract_valid "add fixture with Spec skip reason" "Spec skip reason:
- path checked: spec.md
- reason: docs-only task
Plans.md:
| Task | 内容 | DoD | Depends | Status |"

assert_plan_output_contract_invalid "create fixture missing spec result" "Plans.md:
| Task | 内容 | DoD | Depends | Status |"

assert_plan_output_contract_invalid "add fixture missing spec result" "Plan:
- add a task with no spec result"

assert_lightweight_gate_valid "lightweight fixture" "team_validation_mode: not_required_lightweight
Spec skip reason:
- path checked: spec.md
- reason: typo/docs-only/update/sync lightweight work
Plans.md:
| Task | 内容 | DoD | Depends | Status |"

assert_nontrivial_gate_valid "non-trivial fixture with subagent validation" "team_validation_mode: subagent
Spec delta:
- path: spec.md
- change: add behavior rule
Spec / Plans Fit: pass
Memory / Wheel Check: pass
Product Fit: pass
Security Fit: pass
Quality Baseline Fit: pass
Works In Practice: pass
Plans.md:
| Task | 内容 | DoD | Depends | Status |"

assert_nontrivial_gate_valid "opencode manual-pass fixture" "team_validation_mode: manual-pass
サブエージェント未使用: Task unavailable, manual separated perspectives used
Spec skip reason:
- path checked: spec.md
- reason: existing contract covers task
Spec / Plans Fit: pass
Memory / Wheel Check: pass
Product Fit: pass
Security Fit: pass
Quality Baseline Fit: pass
Works In Practice: pass
Plans.md:
| Task | 内容 | DoD | Depends | Status |"

assert_nontrivial_gate_invalid "non-trivial missing security gate" "team_validation_mode: subagent
Spec / Plans Fit: pass
Memory / Wheel Check: pass
Product Fit: pass
Quality Baseline Fit: pass
Works In Practice: pass
Plans.md:
| Task | 内容 | DoD | Depends | Status |"

assert_nontrivial_gate_invalid "non-trivial unavailable mode" "team_validation_mode: unavailable
Spec / Plans Fit: pass
Memory / Wheel Check: pass
Product Fit: pass
Security Fit: pass
Quality Baseline Fit: pass
Works In Practice: pass
Plans.md:
| Task | 内容 | DoD | Depends | Status |"

assert_security_gate_safe "security fixture avoids secret reads" "Security Fit: do not read secrets; stop at Risk Gate if .env or tokens are needed."

[ ! -e skills/harness-plan/references/maxplan.md ] || fail "maxplan reference must not exist in SSOT"

diff -qr --exclude='.DS_Store' skills/harness-plan codex/.codex/skills/harness-plan >/dev/null \
  || fail "codex harness-plan mirror drifted"
diff -qr --exclude='.DS_Store' skills/harness-plan/references opencode/skills/harness-plan/references >/dev/null \
  || fail "opencode harness-plan references drifted"

echo "test-harness-plan-quality: ok"
