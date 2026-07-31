package main

import (
	"testing"

	"github.com/Chachamaru127/claude-code-harness/go/internal/policy"
	"github.com/Chachamaru127/claude-code-harness/go/pkg/hookproto"
)

// TestPolicyGate_IntactSurfacePreconditionHolds asserts the chain-integrity
// precondition that runPolicy / runPreToolHosted run before adjudicating: on the
// real rule table the deny surface is intact, so VerifyDenySurface() returns nil
// and the gates proceed to the normal evaluation path (exit codes proven by the
// Deny/Allow tests). If the surface were weakened the gates fail closed (exit 3)
// instead — this guards that the happy path stays reachable.
func TestPolicyGate_IntactSurfacePreconditionHolds(t *testing.T) {
	if err := policy.VerifyDenySurface(); err != nil {
		t.Fatalf("intact deny surface must pass the gate precondition, got %v", err)
	}

	// And with the precondition satisfied, the normal decision path is intact:
	// a denied action still maps to exit 2, a benign one to exit 0.
	if _, code := policyCheckResult(hookproto.HookInput{
		CWD:       t.TempDir(),
		ToolName:  "Bash",
		ToolInput: map[string]interface{}{"command": "git push --force origin main"},
	}); code != 2 {
		t.Errorf("with surface intact, force-push should still exit 2, got %d", code)
	}
	if _, code := policyCheckResult(hookproto.HookInput{
		ToolName:  "Read",
		ToolInput: map[string]interface{}{"file_path": "/tmp/example.txt"},
	}); code != 0 {
		t.Errorf("with surface intact, benign Read should still exit 0, got %d", code)
	}
}

// TestPolicyCheckResult_Deny verifies that an action the R01-R13 kernel denies
// (R06: git force-push) yields process exit code 2 with a non-nil deny payload.
func TestPolicyCheckResult_Deny(t *testing.T) {
	out, code := policyCheckResult(hookproto.HookInput{
		CWD:      t.TempDir(),
		ToolName: "Bash",
		ToolInput: map[string]interface{}{
			"command": "git push --force origin main",
		},
	})
	if code != 2 {
		t.Fatalf("git force-push should deny with exit 2, got exit %d", code)
	}
	if out == nil {
		t.Fatal("deny should emit a hookSpecificOutput payload, got nil")
	}
}

// TestPolicyCheckResult_Allow verifies a benign action passes with exit 0 and no
// output payload (pure approve).
func TestPolicyCheckResult_Allow(t *testing.T) {
	out, code := policyCheckResult(hookproto.HookInput{
		ToolName: "Read",
		ToolInput: map[string]interface{}{
			"file_path": "/tmp/example.txt",
		},
	})
	if code != 0 {
		t.Fatalf("benign Read should allow with exit 0, got exit %d", code)
	}
	if out != nil {
		t.Fatalf("clean approve should emit no payload, got %v", out)
	}
}
