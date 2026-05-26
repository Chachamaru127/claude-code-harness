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
    fail "$label ($file is missing '$pattern')"
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
SCAFFOLDER_AGENT="$PLUGIN_ROOT/agents/scaffolder.md"
REVIEWER_AGENT="$PLUGIN_ROOT/agents/reviewer.md"
REVIEW_SKILL="$PLUGIN_ROOT/skills/harness-review/SKILL.md"

echo "=== spec SSOT workflow test ==="

[ -f "$SPEC_DOC" ] || fail "docs/plans/spec-ssot.md not found"
[ -f "$ROOT_SPEC" ] || fail "root spec.md not found"

require_contains "$SPEC_DOC" 'Plans.md is the task ledger. `spec.md` is the product contract.' "spec doc separates the roles of Plans.md and root spec.md"
require_contains "$SPEC_DOC" "co-required planning output" "spec doc defines co-required planning output"
require_contains "$SPEC_DOC" 'Precedence stays: `spec.md` > sub-spec > `Plans.md`' "spec doc maintains spec precedence"
require_contains "$SPEC_DOC" 'Use the root `spec.md` first.' "spec doc declares root spec.md as highest priority"
require_contains "$SPEC_DOC" 'Only when the consumer repository has no root `spec.md`, fall back' "spec doc restricts consumer fallback condition"
require_contains "$SPEC_DOC" "docs/spec/00-project-spec.md" "spec doc shows fallback spec path"
require_contains "$SPEC_DOC" "When To Create Or Update It" "spec doc has creation/update conditions"
require_contains "$SPEC_DOC" "When To Skip" "spec doc has skip conditions"
require_contains "$SPEC_DOC" "Spec delta" "spec doc requires Spec delta output"
require_contains "$SPEC_DOC" "Spec skip reason" "spec doc requires Spec skip reason output"
require_contains "$SPEC_DOC" 'Every `create` output and every product-impacting `add` output' "spec doc requires spec result for both create and add"
require_contains "$SPEC_DOC" "produce the spec result before generating tasks" "spec doc requires spec result before tasks even for add"
require_contains "$SPEC_DOC" 'Harness generates `Spec delta` and `Spec skip reason`; the consumer approves or edits them' "spec doc shows Harness-generated / consumer-approves boundary"
require_contains "$SPEC_DOC" "task context or sprint contract" "spec doc shows skip reason storage location for docs-only / mechanical tasks"
require_contains "$SPEC_DOC" "not_observed != absent" "spec doc maintains the unobserved-data contract"
require_contains "$SPEC_DOC" "The agent drafts the spec delta" "spec doc indicates Harness drafts the spec (not handwritten by user)"

require_contains "$ROOT_SPEC" "Plans.md is the task ledger" "root spec defines Plans.md as task ledger"
require_contains "$ROOT_SPEC" "co-required planning output" "root spec defines co-required planning output"
require_contains "$ROOT_SPEC" "spec.md > sub-spec > Plans.md" "root spec maintains precedence"
require_contains "$ROOT_SPEC" "spec.md product contract and Plans.md task contract" "root spec defines dual planning surface"
require_contains "$ROOT_SPEC" "Spec delta" "root spec has Spec delta output contract"
require_contains "$ROOT_SPEC" "Spec skip reason" "root spec has Spec skip reason output contract"
require_contains "$ROOT_SPEC" 'product-impacting `/harness-plan add` must produce' "root spec requires spec result for product-impacting add"
require_contains "$ROOT_SPEC" "produce the spec result before producing task rows" "root spec requires spec result before tasks even for add"
require_contains "$ROOT_SPEC" "Harness generates the spec result" "root spec has Harness-generated / consumer-approves boundary"
require_contains "$ROOT_SPEC" "not_observed != absent" "root spec has unobserved-data contract"
require_contains "$ROOT_SPEC" "docs/architecture/hokage-core.md" "root spec references Hokage Core as sub-spec"
require_contains "$ROOT_SPEC" "go/SPEC.md" "root spec references Go runtime sub-spec"
require_contains "$ROOT_SPEC" "Host Adapter Boundary" "root spec has host adapter boundary"
require_contains "$ROOT_SPEC" "Support Tiers And Host Claims" "root spec has support tier contract"
require_contains "$ROOT_SPEC" "Onboarding Contract" "root spec has onboarding contract"
require_contains "$ROOT_SPEC" "New Session Bootstrap Rule" "root spec has new session bootstrap rule"
require_contains "$ROOT_SPEC" "future/unsupported" "root spec tier-manages unsupported host claims"

require_contains "$PLAN_SKILL" "spec.md / Plans.md dual-contract check (default)" "harness-plan includes dual-contract check in default flow"
require_contains "$PLAN_SKILL" "purpose: \"Maintain co-required planning output for the spec.md product contract and Plans.md task contract\"" "harness-plan purpose includes dual-contract"
require_contains "$PLAN_SKILL" "docs/plans/spec-ssot.md" "harness-plan references spec SSOT doc"
require_contains "$PLAN_SKILL" 'The output must always include either a `Spec delta` or a `Spec skip reason`' "harness-plan requires spec delta / skip reason output"
require_contains "$PLAN_SKILL" "generated by Harness; the consumer only approves or revises them" "harness-plan has Harness-generated / consumer-approves boundary"
require_contains "$PLAN_CREATE_REF" "## Step 4.4: spec.md / Plans.md dual-contract check" "harness-plan create reference has dual-contract step"
require_contains "$PLAN_CREATE_REF" 'Read the root `spec.md` every time' "harness-plan create requires root spec.md pre-read"
require_contains "$PLAN_CREATE_REF" 'The output of `/harness-plan create` must always be the following pair' "harness-plan create requires Spec + Plans output pair"

require_contains "$WORK_SKILL" "Spec SSOT preflight" "harness-work has Spec SSOT preflight before implementation"
require_contains "$WORK_SKILL" "spec_path" "harness-work passes spec_path to Worker / Reviewer"
require_contains "$WORK_EXEC_REF" "project spec SSOT" "shared execution mode has spec SSOT preflight"

# skills-codex/ is archived — skip Codex harness-work checks
if [ -f "$CODEX_WORK_SKILL" ]; then
  require_contains "$CODEX_WORK_SKILL" "Spec SSOT preflight" "Codex harness-work has Spec SSOT preflight"
  require_contains "$CODEX_WORK_SKILL" "spec_skip_reason" "Codex harness-work passes spec_skip_reason to Worker"
fi
if [ -f "$CODEX_WORK_EXEC_REF" ]; then
  require_contains "$CODEX_WORK_EXEC_REF" "project spec SSOT" "Codex execution mode has spec SSOT preflight"
fi

require_contains "$WORKER_AGENT" "spec_path" "Worker input receives spec_path"
require_contains "$SCAFFOLDER_AGENT" "spec_required" "Scaffolder analyze returns spec_required"
require_contains "$REVIEWER_AGENT" "spec_path" "Reviewer input receives spec_path"
require_contains "$REVIEW_SKILL" "Spec alignment check" "harness-review verifies spec alignment"

echo "All spec SSOT workflow checks passed."
