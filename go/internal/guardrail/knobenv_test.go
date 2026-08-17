package guardrail

import "testing"

// clearGuardrailKnobEnv zeroes every operator/environment knob that
// BuildContext or the runtime floor reads. Tests that assert on rule
// decisions must call this first: the developer machine may have
// HARNESS_WORK_MODE=1 (or other knobs) exported ambiently — see the
// 2026-08-11 incident where an ambient HARNESS_WORK_MODE leaked into
// the test process and flipped an R04 expectation.
//
// Keep this list in sync with the keys scanned by
// scripts/ci/check-config-knob-wiring.sh.
func clearGuardrailKnobEnv(t *testing.T) {
	t.Helper()
	for _, key := range []string{
		"HARNESS_WORK_MODE",
		"ULTRAWORK_MODE",
		"HARNESS_CODEX_MODE",
		"HARNESS_BREEZING_ROLE",
		"HARNESS_SESSION_ID",
		"HARNESS_TDD_BYPASS",
		"HARNESS_TDD_BYPASS_REASON",
		"HARNESS_TDD_ENFORCE_ENABLED",
		"HARNESS_TDD_ENFORCE_LEVEL",
		"HARNESS_TDD_HOOK_ENABLED",
		"HARNESS_TDD_BYPASS_AUDIT_REQUIRED",
		"HARNESS_SCOPE_LEASH_LEVEL",
		"HARNESS_ACTIVE_PHASE",
		"HARNESS_ACTIVE_TASK",
		"HARNESS_RUNTIME_FLOOR_EGRESS",
		"HARNESS_RUNTIME_FLOOR_SECRET_ALLOW",
	} {
		t.Setenv(key, "")
	}
}
