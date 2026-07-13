package guardrail

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/Chachamaru127/claude-code-harness/go/pkg/hookproto"
)

func writeProjectConfig(t *testing.T, dir, name, body string) {
	t.Helper()
	if err := os.WriteFile(filepath.Join(dir, name), []byte(body), 0o600); err != nil {
		t.Fatalf("write project config: %v", err)
	}
}

func TestEvaluatePreTool_DeniesConfiguredProtectedPathWrite(t *testing.T) {
	projectRoot := t.TempDir()
	writeProjectConfig(t, projectRoot, ".claude-code-harness.config.json",
		`{"paths": {"protected": ["infra/", "generated/"]}}`)

	result := EvaluatePreTool(hookproto.HookInput{
		CWD:      projectRoot,
		ToolName: "Write",
		ToolInput: map[string]interface{}{
			"file_path": filepath.Join(projectRoot, "infra", "main.tf"),
		},
	})

	if result.Decision != hookproto.DecisionDeny {
		t.Fatalf("expected deny, got %s (%s)", result.Decision, result.Reason)
	}
	if !strings.Contains(result.Reason, "paths.protected") {
		t.Fatalf("reason should mention paths.protected, got %q", result.Reason)
	}
}

func TestEvaluatePreTool_NonDottedConfigFilenameHonored(t *testing.T) {
	projectRoot := t.TempDir()
	// Users who copy the shipped example commonly land on the non-dotted name.
	writeProjectConfig(t, projectRoot, "claude-code-harness.config.json",
		`{"paths": {"protected": ["secretsdir/"]}}`)

	result := EvaluatePreTool(hookproto.HookInput{
		CWD:      projectRoot,
		ToolName: "Write",
		ToolInput: map[string]interface{}{
			"file_path": filepath.Join(projectRoot, "secretsdir", "note.txt"),
		},
	})

	if result.Decision != hookproto.DecisionDeny {
		t.Fatalf("expected deny via non-dotted config, got %s", result.Decision)
	}
}

func TestEvaluatePreTool_AllowsUnprotectedConfigPath(t *testing.T) {
	projectRoot := t.TempDir()
	writeProjectConfig(t, projectRoot, ".claude-code-harness.config.json",
		`{"paths": {"protected": ["infra/"]}}`)

	result := EvaluatePreTool(hookproto.HookInput{
		CWD:      projectRoot,
		ToolName: "Write",
		ToolInput: map[string]interface{}{
			"file_path": filepath.Join(projectRoot, "src", "app.ts"),
		},
	})

	if result.Decision != hookproto.DecisionApprove {
		t.Fatalf("expected approve for unprotected path, got %s (%s)", result.Decision, result.Reason)
	}
}

func TestEvaluatePreTool_ConfiguredProtectedBranchPushAsked(t *testing.T) {
	projectRoot := t.TempDir()
	writeProjectConfig(t, projectRoot, ".claude-code-harness.config.json",
		`{"git": {"protected_branches": ["production"]}}`)

	result := EvaluatePreTool(hookproto.HookInput{
		CWD:      projectRoot,
		ToolName: "Bash",
		ToolInput: map[string]interface{}{
			"command": "git push origin production",
		},
	})

	if result.Decision != hookproto.DecisionAsk {
		t.Fatalf("expected ask for configured protected branch push, got %s (%s)", result.Decision, result.Reason)
	}
}

func TestEvaluatePreTool_MalformedConfigDoesNotAddDenies(t *testing.T) {
	projectRoot := t.TempDir()
	// Malformed config must not crash and must not fabricate protected paths.
	writeProjectConfig(t, projectRoot, ".claude-code-harness.config.json", `{ not json `)

	result := EvaluatePreTool(hookproto.HookInput{
		CWD:      projectRoot,
		ToolName: "Write",
		ToolInput: map[string]interface{}{
			"file_path": filepath.Join(projectRoot, "src", "app.ts"),
		},
	})

	if result.Decision != hookproto.DecisionApprove {
		t.Fatalf("expected approve with malformed config, got %s (%s)", result.Decision, result.Reason)
	}
}
