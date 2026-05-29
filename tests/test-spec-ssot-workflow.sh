#!/bin/bash
# Verify that Plans.md task workflows also preserve a project spec SSOT when needed.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

pass() {
  echo "PASS: $1"
}

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

require_contains() {
  local file="$1"
  local pattern="$2"
  local label="$3"

  if grep -Fq "$pattern" "$file"; then
    pass "$label"
  else
    fail "$label ($file に '$pattern' がありません)"
  fi
}

SPEC_DOC="$PLUGIN_ROOT/docs/plans/spec-ssot.md"
ROOT_SPEC="$PLUGIN_ROOT/spec.md"
PLAN_SKILL="$PLUGIN_ROOT/skills/harness-plan/SKILL.md"
PLAN_CREATE_REF="$PLUGIN_ROOT/skills/harness-plan/references/create.md"
WORK_SKILL="$PLUGIN_ROOT/skills/harness-work/SKILL.md"
WORK_EXEC_REF="$PLUGIN_ROOT/skills/harness-work/references/execution-modes.md"
CODEX_WORK_SKILL="$PLUGIN_ROOT/skills-codex/harness-work/SKILL.md"
CODEX_WORK_EXEC_REF="$PLUGIN_ROOT/skills-codex/harness-work/references/execution-modes.md"
WORKER_AGENT="$PLUGIN_ROOT/agents/worker.md"
REVIEWER_AGENT="$PLUGIN_ROOT/agents/reviewer.md"
REVIEW_SKILL="$PLUGIN_ROOT/skills/harness-review/SKILL.md"

echo "=== spec SSOT workflow test ==="

[ -f "$SPEC_DOC" ] || fail "docs/plans/spec-ssot.md が見つかりません"
[ -f "$ROOT_SPEC" ] || fail "root spec.md が見つかりません"

require_contains "$SPEC_DOC" 'Plans.md is the task ledger. `spec.md` is the product contract.' "spec doc が Plans.md と root spec.md の役割を分けている"
require_contains "$SPEC_DOC" "co-required planning output" "spec doc が co-required planning output を定義している"
require_contains "$SPEC_DOC" 'Precedence stays: `spec.md` > sub-spec > `Plans.md`' "spec doc が spec precedence を維持している"
require_contains "$SPEC_DOC" 'Use the root `spec.md` first.' "spec doc が root spec.md 最優先を明示している"
require_contains "$SPEC_DOC" 'Only when the consumer repository has no root `spec.md`, fall back' "spec doc が consumer fallback 条件を限定している"
require_contains "$SPEC_DOC" "docs/spec/00-project-spec.md" "spec doc が fallback spec path を示している"
require_contains "$SPEC_DOC" "When To Create Or Update It" "spec doc が作成/更新条件を持つ"
require_contains "$SPEC_DOC" "When To Skip" "spec doc がスキップ条件を持つ"
require_contains "$SPEC_DOC" "Spec delta" "spec doc が Spec delta 出力を要求している"
require_contains "$SPEC_DOC" "Spec skip reason" "spec doc が Spec skip reason 出力を要求している"
require_contains "$SPEC_DOC" 'Every `create` output and every product-impacting `add` output' "spec doc が create/add 両方の spec result を要求している"
require_contains "$SPEC_DOC" "produce the spec result before generating tasks" "spec doc が add でも spec result を task より先に要求している"
require_contains "$SPEC_DOC" 'Harness generates `Spec delta` and `Spec skip reason`; the consumer approves or edits them' "spec doc が Harness 生成 / consumer 承認修正境界を示している"
require_contains "$SPEC_DOC" "task context or sprint contract" "spec doc が docs-only / mechanical task の skip reason 保存先を示している"
require_contains "$SPEC_DOC" "not_observed != absent" "spec doc が未観測データ契約を維持している"
require_contains "$SPEC_DOC" "The agent drafts the spec delta" "spec doc がユーザー手書き前提ではないことを示している"
require_contains "$SPEC_DOC" "team-validated" "spec doc が non-trivial planning の team validation を要求している"
require_contains "$SPEC_DOC" "TeamAgent or sub-agent perspectives" "spec doc が TeamAgent / sub-agent 前提を示している"
require_contains "$SPEC_DOC" "team_validation_mode" "spec doc が team_validation_mode を要求している"
require_contains "$SPEC_DOC" 'Non-trivial work must use `native`, `subagent`, or `manual-pass`' "spec doc が non-trivial mode を限定している"
require_contains "$SPEC_DOC" 'not required runtime `agent_type` names' "spec doc が perspective と agent_type を分けている"
require_contains "$SPEC_DOC" "project-scoped harness-mem / harness-recall / repo-memory wheel check" "spec doc が車輪の再発明防止確認を要求している"
require_contains "$SPEC_DOC" "security fit for permissions, secrets, external sends, supply chain" "spec doc が security gate を要求している"
require_contains "$SPEC_DOC" "works-in-practice proof through test, smoke, CI, review" "spec doc が works-in-practice gate を要求している"
require_contains "$SPEC_DOC" "Security fit must not require reading secrets" "spec doc が secret read を要求しない"

require_contains "$ROOT_SPEC" "Plans.md is the task ledger" "root spec が Plans.md を task ledger と定義している"
require_contains "$ROOT_SPEC" "co-required planning output" "root spec が co-required planning output を定義している"
require_contains "$ROOT_SPEC" "spec.md > sub-spec > Plans.md" "root spec が precedence を維持している"
require_contains "$ROOT_SPEC" "spec.md product contract and Plans.md task contract" "root spec が二正本 planning surface を定義している"
require_contains "$ROOT_SPEC" "Spec delta" "root spec が Spec delta 出力契約を持つ"
require_contains "$ROOT_SPEC" "Spec skip reason" "root spec が Spec skip reason 出力契約を持つ"
require_contains "$ROOT_SPEC" 'product-impacting `/harness-plan add` must produce' "root spec が product-impacting add の spec result を要求する"
require_contains "$ROOT_SPEC" "produce the spec result before producing task rows" "root spec が add でも spec result を task より先に要求している"
require_contains "$ROOT_SPEC" "Harness generates the spec result" "root spec が Harness 生成 / consumer 承認修正境界を持つ"
require_contains "$ROOT_SPEC" "not_observed != absent" "root spec が未観測データ契約を持つ"
require_contains "$ROOT_SPEC" "Non-trivial planning must be team-validated" "root spec が non-trivial planning の team validation を要求する"
require_contains "$ROOT_SPEC" "TeamAgent or sub-agent perspectives" "root spec が TeamAgent / sub-agent 前提を示す"
require_contains "$ROOT_SPEC" "team_validation_mode" "root spec が team_validation_mode を要求する"
require_contains "$ROOT_SPEC" 'Non-trivial work must use `native`, `subagent`, or `manual-pass`' "root spec が non-trivial mode を限定している"
require_contains "$ROOT_SPEC" 'not required runtime `agent_type` names' "root spec が perspective と agent_type を分けている"
require_contains "$ROOT_SPEC" "project-scoped harness-mem / harness-recall / repo-memory wheel check" "root spec が車輪の再発明防止確認を要求する"
require_contains "$ROOT_SPEC" "security validation for permissions, secrets, external sends, supply chain" "root spec が security validation を要求する"
require_contains "$ROOT_SPEC" "works-in-practice validation" "root spec が works-in-practice validation を要求する"
require_contains "$ROOT_SPEC" "Security validation must not require reading secrets" "root spec が secret read を要求しない"
require_contains "$ROOT_SPEC" "docs/architecture/hokage-core.md" "root spec が Hokage Core を sub-spec として参照する"
require_contains "$ROOT_SPEC" "go/SPEC.md" "root spec が Go runtime sub-spec を参照する"
require_contains "$ROOT_SPEC" "Host Adapter Boundary" "root spec が host adapter boundary を持つ"
require_contains "$ROOT_SPEC" "Support Tiers And Host Claims" "root spec が support tier 契約を持つ"
require_contains "$ROOT_SPEC" "Onboarding Contract" "root spec が onboarding contract を持つ"
require_contains "$ROOT_SPEC" "New Session Bootstrap Rule" "root spec が new session bootstrap rule を持つ"
require_contains "$ROOT_SPEC" "future/unsupported" "root spec が unsupported host claim を tier 管理する"

require_contains "$PLAN_SKILL" "spec.md / Plans.md 二正本チェック（デフォルト）" "harness-plan が二正本チェックを default flow に含む"
require_contains "$PLAN_SKILL" "purpose: \"Maintain co-required planning output for the spec.md product contract and Plans.md task contract\"" "harness-plan purpose が二正本 contract を含む"
require_contains "$PLAN_SKILL" "docs/plans/spec-ssot.md" "harness-plan が spec SSOT doc を参照する"
require_contains "$PLAN_SKILL" '出力には必ず `Spec delta` または `Spec skip reason` を含める' "harness-plan が spec delta / skip reason 出力を要求する"
require_contains "$PLAN_SKILL" "Harness が生成し、consumer は承認・修正だけ" "harness-plan が Harness 生成 / consumer 承認修正境界を持つ"
require_contains "$PLAN_SKILL" "Non-trivial planning gate" "harness-plan が non-trivial planning gate を持つ"
require_contains "$PLAN_SKILL" "TeamAgent またはサブエージェント前提" "harness-plan が TeamAgent / subagent 前提を持つ"
require_contains "$PLAN_SKILL" "車輪の再発明防止確認" "harness-plan が memory wheel check を要求する"
require_contains "$PLAN_SKILL" "ちゃんと動く計画か" "harness-plan が works-in-practice gate を要求する"
require_contains "$PLAN_CREATE_REF" "## Step 4.4: spec.md / Plans.md 二正本チェック" "harness-plan create reference に二正本ステップがある"
require_contains "$PLAN_CREATE_REF" 'root `spec.md` を毎回読む' "harness-plan create が root spec.md pre-read を要求する"
require_contains "$PLAN_CREATE_REF" '`/harness-plan create` の出力は必ず次の 2 点セット' "harness-plan create が Spec + Plans の2点セットを要求する"
require_contains "$PLAN_CREATE_REF" "product fit、security fit、works in practice" "harness-plan create が実装プラン検証観点を持つ"

require_contains "$WORK_SKILL" "仕様正本 preflight" "harness-work が実装前の仕様正本 preflight を持つ"
require_contains "$WORK_SKILL" "spec_path" "harness-work が Worker / Reviewer へ spec_path を渡す"
require_contains "$WORK_EXEC_REF" "project spec SSOT" "shared execution mode が spec SSOT preflight を持つ"

require_contains "$CODEX_WORK_SKILL" "仕様正本 preflight" "Codex harness-work が仕様正本 preflight を持つ"
require_contains "$CODEX_WORK_SKILL" "spec_skip_reason" "Codex harness-work が spec_skip_reason を Worker に渡す"
require_contains "$CODEX_WORK_EXEC_REF" "project spec SSOT" "Codex execution mode が spec SSOT preflight を持つ"

require_contains "$WORKER_AGENT" "spec_path" "Worker input が spec_path を受け取る"
require_contains "$REVIEWER_AGENT" "spec_path" "Reviewer input が spec_path を受け取る"
require_contains "$REVIEW_SKILL" "仕様正本 alignment check" "harness-review が spec alignment を確認する"

echo "All spec SSOT workflow checks passed."
