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

func TestEvaluatePreTool_MalformedConfigFailsClosed(t *testing.T) {
	projectRoot := t.TempDir()
	// A present-but-broken config must fail closed: writes are denied until the
	// operator fixes it, so a typo can never silently drop protections.
	writeProjectConfig(t, projectRoot, ".claude-code-harness.config.json", `{ not json `)

	result := EvaluatePreTool(hookproto.HookInput{
		CWD:      projectRoot,
		ToolName: "Write",
		ToolInput: map[string]interface{}{
			"file_path": filepath.Join(projectRoot, "src", "app.ts"),
		},
	})

	if result.Decision != hookproto.DecisionDeny {
		t.Fatalf("expected deny (fail closed) with malformed config, got %s (%s)", result.Decision, result.Reason)
	}
	if !strings.Contains(result.Reason, "could not be parsed") {
		t.Fatalf("reason should explain the parse failure, got %q", result.Reason)
	}
}

func TestEvaluatePreTool_UnknownConfigKeyFailsClosed(t *testing.T) {
	projectRoot := t.TempDir()
	// A typo'd key (protectedd) must not silently drop the protection.
	writeProjectConfig(t, projectRoot, ".claude-code-harness.config.json",
		`{"paths": {"protectedd": ["infra/"]}}`)

	result := EvaluatePreTool(hookproto.HookInput{
		CWD:      projectRoot,
		ToolName: "Write",
		ToolInput: map[string]interface{}{
			"file_path": filepath.Join(projectRoot, "infra", "main.tf"),
		},
	})

	if result.Decision != hookproto.DecisionDeny {
		t.Fatalf("expected deny (fail closed) for unknown config key, got %s (%s)", result.Decision, result.Reason)
	}
}

func TestEvaluatePreTool_InvalidGlobFailsClosed(t *testing.T) {
	projectRoot := t.TempDir()
	// A malformed glob pattern is a config error and must fail closed.
	writeProjectConfig(t, projectRoot, ".claude-code-harness.config.json",
		`{"paths": {"protected": ["["]}}`)

	result := EvaluatePreTool(hookproto.HookInput{
		CWD:      projectRoot,
		ToolName: "Write",
		ToolInput: map[string]interface{}{
			"file_path": filepath.Join(projectRoot, "src", "app.ts"),
		},
	})

	if result.Decision != hookproto.DecisionDeny {
		t.Fatalf("expected deny (fail closed) for invalid glob, got %s (%s)", result.Decision, result.Reason)
	}
}

func TestEvaluatePreTool_NestedCwdDoesNotBypassProtectedPath(t *testing.T) {
	projectRoot := t.TempDir()
	writeProjectConfig(t, projectRoot, ".claude-code-harness.config.json",
		`{"paths": {"protected": ["secretsdir/"]}}`)
	nested := filepath.Join(projectRoot, "app", "service")
	if err := os.MkdirAll(nested, 0o755); err != nil {
		t.Fatalf("mkdir nested: %v", err)
	}

	// Hook invoked from a nested cwd, but the write targets the config-root
	// protected dir. It must still be denied.
	result := EvaluatePreTool(hookproto.HookInput{
		CWD:      nested,
		ToolName: "Write",
		ToolInput: map[string]interface{}{
			"file_path": filepath.Join(projectRoot, "secretsdir", "key.txt"),
		},
	})

	if result.Decision != hookproto.DecisionDeny {
		t.Fatalf("expected deny for protected path from nested cwd, got %s (%s)", result.Decision, result.Reason)
	}
}

// allowRmRfEscapeInput builds an EvaluatePreTool input with allow_rm_rf opted in.
func allowRmRfEscapeInput(t *testing.T, command string) hookproto.HookInput {
	t.Helper()
	projectRoot := t.TempDir()
	writeProjectConfig(t, projectRoot, ".claude-code-harness.config.json",
		`{"destructive_commands": {"allow_rm_rf": true}}`)
	return hookproto.HookInput{
		CWD:       projectRoot,
		ToolName:  "Bash",
		ToolInput: map[string]interface{}{"command": command},
	}
}

func TestEvaluatePreTool_AllowRmRfCannotEscapeWorktree(t *testing.T) {
	// Even with allow_rm_rf, a destructive delete outside the task worktree is
	// hard-stopped by the runtime floor (non-exemptable).
	cases := []string{
		"rm -rf /etc/harness-escape-test",
		"rm --recursive /etc/harness-escape-test",
		"rm -fr /etc/harness-escape-test",
	}
	for _, cmd := range cases {
		result := EvaluatePreTool(allowRmRfEscapeInput(t, cmd))
		if result.Decision != hookproto.DecisionDeny {
			t.Fatalf("expected deny (worktree escape) for %q, got %s (%s)", cmd, result.Decision, result.Reason)
		}
	}
}

func TestEvaluatePreTool_AllowRmRfStillAsksFindDeleteEscape(t *testing.T) {
	// find-based deletion is outside the allow_rm_rf exemption, so it still asks
	// (a human sees it) rather than being silently approved.
	result := EvaluatePreTool(allowRmRfEscapeInput(t, "find /etc/harness-escape-test -delete"))
	if result.Decision != hookproto.DecisionAsk {
		t.Fatalf("expected ask for find -delete with allow_rm_rf, got %s (%s)", result.Decision, result.Reason)
	}
}

func TestEvaluatePreTool_SecretAllowRejectsRelativeTraversal(t *testing.T) {
	projectRoot := t.TempDir()
	// A relative secretAllow entry that escapes the worktree must not allowlist
	// an out-of-tree secret (e.g. the user's real SSH key).
	writeProjectConfig(t, projectRoot, ".claude-code-harness.config.json",
		`{"runtimefloor": {"secretAllow": ["../.ssh/id_rsa"]}}`)

	result := EvaluatePreTool(hookproto.HookInput{
		CWD:       projectRoot,
		ToolName:  "Bash",
		ToolInput: map[string]interface{}{"command": "cat ../.ssh/id_rsa"},
	})
	if result.Decision != hookproto.DecisionDeny {
		t.Fatalf("expected deny for traversing relative secretAllow, got %s (%s)", result.Decision, result.Reason)
	}
}

func TestEvaluatePreTool_ForceRefspecShorthandStillAsked(t *testing.T) {
	projectRoot := t.TempDir()
	writeProjectConfig(t, projectRoot, ".claude-code-harness.config.json",
		`{"git": {"protected_branches": ["production"]}}`)

	for _, cmd := range []string{
		"git push origin +production",
		"git push origin +main",
		"git push origin +production:production",
	} {
		result := EvaluatePreTool(hookproto.HookInput{
			CWD:       projectRoot,
			ToolName:  "Bash",
			ToolInput: map[string]interface{}{"command": cmd},
		})
		if result.Decision != hookproto.DecisionAsk {
			t.Fatalf("expected ask for force-refspec %q, got %s (%s)", cmd, result.Decision, result.Reason)
		}
	}
}

func TestEvaluatePreTool_AllowRmRfSuppressesConfirmation(t *testing.T) {
	projectRoot := t.TempDir()
	writeProjectConfig(t, projectRoot, ".claude-code-harness.config.json",
		`{"destructive_commands": {"allow_rm_rf": true}}`)

	result := EvaluatePreTool(hookproto.HookInput{
		CWD:       projectRoot,
		ToolName:  "Bash",
		ToolInput: map[string]interface{}{"command": "rm -rf build/"},
	})

	if result.Decision != hookproto.DecisionApprove {
		t.Fatalf("expected approve with allow_rm_rf, got %s (%s)", result.Decision, result.Reason)
	}
}

func TestEvaluatePreTool_RmRfAsksWithoutOptIn(t *testing.T) {
	projectRoot := t.TempDir()
	// No config: the destructive-delete confirmation stays on.
	result := EvaluatePreTool(hookproto.HookInput{
		CWD:       projectRoot,
		ToolName:  "Bash",
		ToolInput: map[string]interface{}{"command": "rm -rf build/"},
	})

	if result.Decision != hookproto.DecisionAsk {
		t.Fatalf("expected ask without opt-in, got %s (%s)", result.Decision, result.Reason)
	}
}

func TestEvaluatePreTool_AllowRmRfFalseStillAsks(t *testing.T) {
	projectRoot := t.TempDir()
	writeProjectConfig(t, projectRoot, ".claude-code-harness.config.json",
		`{"destructive_commands": {"allow_rm_rf": false}}`)

	result := EvaluatePreTool(hookproto.HookInput{
		CWD:       projectRoot,
		ToolName:  "Bash",
		ToolInput: map[string]interface{}{"command": "rm -rf build/"},
	})

	if result.Decision != hookproto.DecisionAsk {
		t.Fatalf("expected ask with allow_rm_rf=false, got %s (%s)", result.Decision, result.Reason)
	}
}

func TestEvaluatePreTool_SecretAllowPermitsBareRelativeEnvRead(t *testing.T) {
	projectRoot := t.TempDir()
	writeProjectConfig(t, projectRoot, ".claude-code-harness.config.json",
		`{"runtimefloor": {"secretAllow": [".env"]}}`)

	for _, cmd := range []string{"cat .env", "grep TOKEN .env", "cat ./.env"} {
		result := EvaluatePreTool(hookproto.HookInput{
			CWD:       projectRoot,
			ToolName:  "Bash",
			ToolInput: map[string]interface{}{"command": cmd},
		})
		if result.Decision != hookproto.DecisionApprove {
			t.Fatalf("expected approve for allowlisted %q, got %s (%s)", cmd, result.Decision, result.Reason)
		}
	}
}

func TestEvaluatePreTool_SecretAllowStaysScopedToProject(t *testing.T) {
	projectRoot := t.TempDir()
	writeProjectConfig(t, projectRoot, ".claude-code-harness.config.json",
		`{"runtimefloor": {"secretAllow": [".env"]}}`)

	// A .env under an unrelated absolute path is not the project's declared
	// secret and must still require approval.
	result := EvaluatePreTool(hookproto.HookInput{
		CWD:       projectRoot,
		ToolName:  "Bash",
		ToolInput: map[string]interface{}{"command": "cat /etc/other/.env"},
	})
	if result.Decision != hookproto.DecisionDeny {
		t.Fatalf("expected deny for out-of-project .env, got %s (%s)", result.Decision, result.Reason)
	}
}

func TestEvaluatePreTool_EnvReadDeniedWithoutSecretAllow(t *testing.T) {
	projectRoot := t.TempDir()
	result := EvaluatePreTool(hookproto.HookInput{
		CWD:       projectRoot,
		ToolName:  "Bash",
		ToolInput: map[string]interface{}{"command": "cat .env"},
	})
	if result.Decision != hookproto.DecisionDeny {
		t.Fatalf("expected deny without secretAllow, got %s (%s)", result.Decision, result.Reason)
	}
}
