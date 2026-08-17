package guardrail

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/Chachamaru127/claude-code-harness/go/pkg/hookproto"
)

// scopeLeashFixture writes .claude/state/active-task.json and a matching
// sprint-contract.json with the given declared_scope, and optionally a
// harness.toml pinning [scope_leash] enforce_level.
func scopeLeashFixture(t *testing.T, taskID string, declaredScope []string, enforceLevel string) string {
	t.Helper()
	dir := t.TempDir()
	stateDir := filepath.Join(dir, ".claude", "state")
	if err := os.MkdirAll(filepath.Join(stateDir, "contracts"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(
		filepath.Join(stateDir, "active-task.json"),
		[]byte(`{"phase":"134","task":"`+taskID+`"}`),
		0o600,
	); err != nil {
		t.Fatal(err)
	}

	scopeJSON := "[]"
	if len(declaredScope) > 0 {
		quoted := make([]string, len(declaredScope))
		for i, p := range declaredScope {
			quoted[i] = `"` + p + `"`
		}
		scopeJSON = "[" + strings.Join(quoted, ",") + "]"
	}
	contract := `{"task":{"id":"` + taskID + `","declared_scope":` + scopeJSON + `}}`
	if err := os.WriteFile(
		filepath.Join(stateDir, "contracts", taskID+".sprint-contract.json"),
		[]byte(contract),
		0o600,
	); err != nil {
		t.Fatal(err)
	}

	if enforceLevel != "" {
		toml := "[scope_leash]\nenforce_level = \"" + enforceLevel + "\"\n"
		if err := os.WriteFile(filepath.Join(dir, "harness.toml"), []byte(toml), 0o600); err != nil {
			t.Fatal(err)
		}
	}
	return dir
}

func writeInput(dir, filePath string) hookproto.HookInput {
	return hookproto.HookInput{
		CWD:      dir,
		ToolName: "Write",
		ToolInput: map[string]interface{}{
			"file_path": filePath,
			"content":   "x",
		},
	}
}

func TestEvaluatePreTool_ScopeLeashWarnRecordsOutOfScopeWrite(t *testing.T) {
	clearGuardrailKnobEnv(t)
	dir := scopeLeashFixture(t, "134.5", []string{"go/internal/guardrail/pre_tool.go"}, "warn")

	jsonlPath := filepath.Join(dir, ".claude", "state", "scope-leash.jsonl")
	if _, err := os.Stat(jsonlPath); !os.IsNotExist(err) {
		t.Fatalf("RED precondition: scope-leash.jsonl must not exist yet, stat err=%v", err)
	}

	result := EvaluatePreTool(writeInput(dir, filepath.Join(dir, "other/bar.go")))

	if result.Decision != hookproto.DecisionApprove {
		t.Fatalf("warn level must not block, got %s (reason=%q)", result.Decision, result.Reason)
	}
	if !strings.Contains(result.SystemMessage, "SCOPE_LEASH") {
		t.Fatalf("expected SCOPE_LEASH warning in systemMessage, got %q", result.SystemMessage)
	}

	data, err := os.ReadFile(jsonlPath)
	if err != nil {
		t.Fatalf("scope-leash.jsonl was not written: %v", err)
	}
	if !strings.Contains(string(data), "other/bar.go") || !strings.Contains(string(data), "134.5") {
		t.Fatalf("scope-leash.jsonl entry missing target/task: %s", data)
	}
}

func TestEvaluatePreTool_ScopeLeashInScopeWriteIsSilent(t *testing.T) {
	clearGuardrailKnobEnv(t)
	dir := scopeLeashFixture(t, "134.5", []string{"go/internal/guardrail/pre_tool.go"}, "warn")

	result := EvaluatePreTool(writeInput(dir, filepath.Join(dir, "go/internal/guardrail/pre_tool.go")))

	if result.Decision != hookproto.DecisionApprove {
		t.Fatalf("in-scope write must approve, got %s (reason=%q)", result.Decision, result.Reason)
	}
	if result.SystemMessage != "" {
		t.Fatalf("in-scope write must not carry a scope warning, got %q", result.SystemMessage)
	}
	if _, err := os.Stat(filepath.Join(dir, ".claude", "state", "scope-leash.jsonl")); !os.IsNotExist(err) {
		t.Fatalf("in-scope write must not record a scope-leash warning")
	}
}

func TestEvaluatePreTool_ScopeLeashEnforceDeniesOutOfScopeWrite(t *testing.T) {
	clearGuardrailKnobEnv(t)
	dir := scopeLeashFixture(t, "134.5", []string{"go/internal/guardrail/pre_tool.go"}, "enforce")

	result := EvaluatePreTool(writeInput(dir, filepath.Join(dir, "other/bar.go")))

	if result.Decision != hookproto.DecisionDeny {
		t.Fatalf("enforce level must deny out-of-scope write, got %s", result.Decision)
	}
	if !strings.Contains(result.Reason, "SCOPE_LEASH") {
		t.Fatalf("expected SCOPE_LEASH in deny reason, got %q", result.Reason)
	}
}

func TestEvaluatePreTool_ScopeLeashEnforceAllowsInScopeWrite(t *testing.T) {
	clearGuardrailKnobEnv(t)
	dir := scopeLeashFixture(t, "134.5", []string{"go/internal/guardrail/pre_tool.go"}, "enforce")

	result := EvaluatePreTool(writeInput(dir, filepath.Join(dir, "go/internal/guardrail/pre_tool.go")))

	if result.Decision != hookproto.DecisionApprove {
		t.Fatalf("enforce level must allow in-scope write, got %s (reason=%q)", result.Decision, result.Reason)
	}
}

func TestEvaluatePreTool_ScopeLeashOffLevelSkips(t *testing.T) {
	clearGuardrailKnobEnv(t)
	dir := scopeLeashFixture(t, "134.5", []string{"go/internal/guardrail/pre_tool.go"}, "off")

	result := EvaluatePreTool(writeInput(dir, filepath.Join(dir, "other/bar.go")))

	if result.Decision != hookproto.DecisionApprove {
		t.Fatalf("off level must approve, got %s (reason=%q)", result.Decision, result.Reason)
	}
	if result.SystemMessage != "" {
		t.Fatalf("off level must not emit a scope warning, got %q", result.SystemMessage)
	}
	if _, err := os.Stat(filepath.Join(dir, ".claude", "state", "scope-leash.jsonl")); !os.IsNotExist(err) {
		t.Fatalf("off level must not record a scope-leash warning")
	}
}

// TestEvaluatePreTool_ScopeLeashEmptyScopeNeverFires proves the false-positive
// guard: with no declared_scope on file (or contract absent altogether), even
// enforce level never blocks and never records — 空 scope は即 skip.
func TestEvaluatePreTool_ScopeLeashEmptyScopeNeverFires(t *testing.T) {
	clearGuardrailKnobEnv(t)
	dir := scopeLeashFixture(t, "134.5", nil, "enforce")

	result := EvaluatePreTool(writeInput(dir, filepath.Join(dir, "anything/at/all.go")))

	if result.Decision != hookproto.DecisionApprove {
		t.Fatalf("empty declared_scope must never block, got %s (reason=%q)", result.Decision, result.Reason)
	}
	if result.SystemMessage != "" {
		t.Fatalf("empty declared_scope must not emit a scope warning, got %q", result.SystemMessage)
	}
	if _, err := os.Stat(filepath.Join(dir, ".claude", "state", "scope-leash.jsonl")); !os.IsNotExist(err) {
		t.Fatalf("empty declared_scope must not record a scope-leash warning")
	}
}

// TestEvaluatePreTool_ScopeLeashNoActiveTaskNeverFires proves that without an
// active-task.json (no session claims a task), the check is a no-op even in
// enforce mode.
func TestEvaluatePreTool_ScopeLeashNoActiveTaskNeverFires(t *testing.T) {
	clearGuardrailKnobEnv(t)
	dir := t.TempDir()
	if err := os.WriteFile(filepath.Join(dir, "harness.toml"), []byte("[scope_leash]\nenforce_level = \"enforce\"\n"), 0o600); err != nil {
		t.Fatal(err)
	}

	result := EvaluatePreTool(writeInput(dir, filepath.Join(dir, "anything/at/all.go")))

	if result.Decision != hookproto.DecisionApprove {
		t.Fatalf("no active task must never block, got %s (reason=%q)", result.Decision, result.Reason)
	}
}

// TestEvaluatePreTool_ScopeLeashEnforceExemptsClaudeStateWrite proves the
// regression this test file was added for (code review major finding,
// 2026-08-16): declared_scope is auto-inferred from Plans.md Title/DoD text
// and never contains .claude/ paths, so with enforce_level=enforce a write to
// harness's own internal state (e.g. .claude/state/active-task.json) must not
// be denied just because the task's declared scope doesn't mention it.
func TestEvaluatePreTool_ScopeLeashEnforceExemptsClaudeStateWrite(t *testing.T) {
	clearGuardrailKnobEnv(t)
	dir := scopeLeashFixture(t, "134.5", []string{"go/internal/guardrail/pre_tool.go"}, "enforce")

	result := EvaluatePreTool(writeInput(dir, filepath.Join(dir, ".claude/state/some-internal-file.json")))

	if result.Decision != hookproto.DecisionApprove {
		t.Fatalf(".claude/ write must be exempt from scope leash, got %s (reason=%q)", result.Decision, result.Reason)
	}
	if result.SystemMessage != "" {
		t.Fatalf(".claude/ write must not carry a scope warning either, got %q", result.SystemMessage)
	}
	if _, err := os.Stat(filepath.Join(dir, ".claude", "state", "scope-leash.jsonl")); !os.IsNotExist(err) {
		t.Fatalf(".claude/ write must not record a scope-leash warning")
	}
}

// TestEvaluatePreTool_ScopeLeashEnforceStillDeniesNonClaudeOutOfScopeWrite is
// the companion negative case for the fix above: the .claude/ exemption must
// not widen into a general bypass — a normal out-of-scope write under the
// same enforce-level contract must still be denied.
func TestEvaluatePreTool_ScopeLeashEnforceStillDeniesNonClaudeOutOfScopeWrite(t *testing.T) {
	clearGuardrailKnobEnv(t)
	dir := scopeLeashFixture(t, "134.5", []string{"go/internal/guardrail/pre_tool.go"}, "enforce")

	result := EvaluatePreTool(writeInput(dir, filepath.Join(dir, "other/bar.go")))

	if result.Decision != hookproto.DecisionDeny {
		t.Fatalf("non-.claude out-of-scope write must still be denied, got %s", result.Decision)
	}
	if !strings.Contains(result.Reason, "SCOPE_LEASH") {
		t.Fatalf("expected SCOPE_LEASH in deny reason, got %q", result.Reason)
	}
}
