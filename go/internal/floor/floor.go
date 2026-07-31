// Package floor implements the PRE-MERGE POLICY GATE (Phase 91.6 "FLOOR") — the
// universal integration-time file gate that an untrusted (codex/cursor) backend's
// changes must pass before they are cherry-picked into the trunk.
//
// This is distinct from the RUNTIME ACTION HARD FLOOR in go/internal/runtimefloor,
// which pattern-matches Bash commands before a worker action runs and always
// escalates five non-overridable categories to a human.
//
// Non-Claude backends produce changes that are untrusted until they clear the
// harness's guardrails. The FLOOR is the mandatory gate that runs, in order:
//
//  1. policy.VerifyDenySurface() — chain integrity. The deny rules that
//     constrain the agent must not have been weakened; if they have, nothing
//     downstream can be trusted to adjudicate, so the gate fails immediately.
//  2. policy check over the candidate changed files — each file is evaluated as
//     a write through the real R01-R13 engine; a deny means the take-in is
//     refused.
//  3. the contract greps — test-support-claim-wording.sh, check-consistency.sh,
//     validate-plugin.sh — which encode repo-wide invariants (support-claim
//     wording, mirror/consistency, plugin structure).
//
// ALL steps must pass for the gate to pass. The ScriptRunner seam keeps step 3
// injectable so tests never shell out.
package floor

import (
	"fmt"
	"os/exec"
	"path/filepath"

	"github.com/Chachamaru127/claude-code-harness/go/internal/guardrail"
	"github.com/Chachamaru127/claude-code-harness/go/internal/policy"
	"github.com/Chachamaru127/claude-code-harness/go/pkg/hookproto"
)

// Step names are stable identifiers so callers (and tests) can assert which part
// of the backstop failed.
const (
	StepDenySurface  = "deny-surface-integrity"
	StepPolicyCheck  = "policy-check-changed-files"
	StepSupportWord  = "test-support-claim-wording.sh"
	StepConsistency  = "check-consistency.sh"
	StepValidatePlug = "validate-plugin.sh"
)

// contractScripts are the three repo scripts run as step 3, in order. They are
// paths relative to the repo root; the ScriptRunner resolves them against it.
var contractScripts = []struct {
	step   string
	script string
}{
	{StepSupportWord, "tests/test-support-claim-wording.sh"},
	{StepConsistency, "scripts/ci/check-consistency.sh"},
	{StepValidatePlug, "tests/validate-plugin.sh"},
}

// StepResult is the outcome of one FLOOR step.
type StepResult struct {
	Name   string
	Passed bool
	Detail string
}

// Report is the FLOOR outcome. Passed is true iff every step passed.
type Report struct {
	Passed bool
	Steps  []StepResult
}

// verifyDenySurface is the chain-integrity check used by step 1. It defaults to
// policy.VerifyDenySurface and is a package var only so tests can simulate a
// weakened surface (proving the bypass — "scripts pass but the chain is
// compromised" — is closed) without mutating the real rule baseline. Production
// never reassigns it.
var verifyDenySurface = policy.VerifyDenySurface

// ScriptRunner runs a repo script and returns (exitCode, combinedOutput). The
// default production runner shells out to `bash <repoRoot>/<script>`; tests
// inject a test double so the gate logic is exercised without executing anything.
type ScriptRunner interface {
	Run(repoRoot, script string, args ...string) (int, string)
}

// Gate runs the mandatory pre-merge policy gate for a non-CC backend take-in over
// changedFiles, using runner for the contract scripts. It evaluates every step
// (it does not short-circuit) so the Report names each failure, then sets
// Passed iff all steps passed.
func Gate(repoRoot string, changedFiles []string, runner ScriptRunner) Report {
	if runner == nil {
		runner = DefaultRunner{}
	}

	report := Report{Passed: true}
	add := func(s StepResult) {
		report.Steps = append(report.Steps, s)
		if !s.Passed {
			report.Passed = false
		}
	}

	// Step 1: chain integrity. If the deny surface is weakened, the rest of the
	// gate cannot be trusted — but we still record it as a normal failing step.
	if err := verifyDenySurface(); err != nil {
		add(StepResult{Name: StepDenySurface, Passed: false, Detail: err.Error()})
	} else {
		add(StepResult{Name: StepDenySurface, Passed: true, Detail: "deny surface intact"})
	}

	// Step 2: policy check over the candidate changes.
	add(policyCheckStep(repoRoot, changedFiles))

	// Step 3: the contract greps.
	for _, cs := range contractScripts {
		add(scriptStep(runner, repoRoot, cs.step, cs.script))
	}

	return report
}

// policyCheckStep evaluates each changed file as a write through the real
// R01-R13 engine (guardrail.EvaluatePreTool). The first file that denies fails
// the step with the rule's reason; if none deny, the step passes. Evaluating
// candidate writes — rather than reimplementing the rules — guarantees the gate
// uses exactly the same deny logic that the per-event hook enforces.
func policyCheckStep(repoRoot string, changedFiles []string) StepResult {
	for _, f := range changedFiles {
		path := f
		if repoRoot != "" && !filepath.IsAbs(f) {
			path = filepath.Join(repoRoot, f)
		}
		input := hookproto.HookInput{
			AuditRoot: repoRoot,
			ToolName:  "Write",
			ToolInput: map[string]interface{}{
				"file_path": path,
				// A non-empty content keeps the input well-formed for any rule
				// that inspects the payload; the deny rules of interest key on
				// the path.
				"content": "",
			},
		}
		result := guardrail.EvaluatePreTool(input)
		if result.Decision == hookproto.DecisionDeny {
			return StepResult{
				Name:   StepPolicyCheck,
				Passed: false,
				Detail: fmt.Sprintf("policy denies change to %s: %s", f, result.Reason),
			}
		}
	}
	return StepResult{
		Name:   StepPolicyCheck,
		Passed: true,
		Detail: fmt.Sprintf("policy clean over %d changed file(s)", len(changedFiles)),
	}
}

// scriptStep runs one contract script and maps a non-zero exit (or runner-level
// failure) to a failed step. An absent script surfaces as a non-zero exit from
// the runner, so it also fails the step.
func scriptStep(runner ScriptRunner, repoRoot, step, script string) StepResult {
	exitCode, output := runner.Run(repoRoot, script)
	if exitCode != 0 {
		return StepResult{
			Name:   step,
			Passed: false,
			Detail: fmt.Sprintf("exit %d: %s", exitCode, trimDetail(output)),
		}
	}
	return StepResult{Name: step, Passed: true, Detail: "passed"}
}

// trimDetail bounds an attached script output so a failing Report stays
// readable; the full output is the runner's responsibility to surface elsewhere.
func trimDetail(s string) string {
	const cap = 500
	if len(s) <= cap {
		return s
	}
	return s[:cap] + "…(truncated)"
}

// DefaultRunner is the production ScriptRunner. It shells out to
// `bash <repoRoot>/<script> [args...]` and returns the exit code with combined
// stdout+stderr. These scripts are plain execs (NOT git), so a direct
// exec.Command seam is appropriate — they are intentionally not routed through
// gitport. A missing script yields bash exit 127, which fails the step.
type DefaultRunner struct{}

// Run executes the script under bash and returns (exitCode, combinedOutput).
func (DefaultRunner) Run(repoRoot, script string, args ...string) (int, string) {
	full := script
	if repoRoot != "" && !filepath.IsAbs(script) {
		full = filepath.Join(repoRoot, script)
	}
	cmdArgs := append([]string{full}, args...)
	cmd := exec.Command("bash", cmdArgs...)
	if repoRoot != "" {
		cmd.Dir = repoRoot
	}
	out, err := cmd.CombinedOutput()
	if err != nil {
		if ee, ok := err.(*exec.ExitError); ok {
			return ee.ExitCode(), string(out)
		}
		// Spawn-level failure (bash missing, script unreadable, …): non-zero.
		return 127, string(out) + err.Error()
	}
	return 0, string(out)
}
