package guardrail

import (
	"strings"
	"testing"

	"github.com/Chachamaru127/claude-code-harness/go/pkg/hookproto"
)

// helper to build a RuleContext for testing
func makeCtx(toolName string, toolInput map[string]interface{}) hookproto.RuleContext {
	return hookproto.RuleContext{
		Input: hookproto.HookInput{
			ToolName:  toolName,
			ToolInput: toolInput,
		},
		ProjectRoot:  "/project",
		WorkMode:     false,
		CodexMode:    false,
		BreezingRole: "",
	}
}

// ---------------------------------------------------------------------------
// R01: sudo block
// ---------------------------------------------------------------------------

func TestR01_SudoBlocked(t *testing.T) {
	ctx := makeCtx("Bash", map[string]interface{}{"command": "sudo rm -rf /"})
	result := EvaluateRules(ctx)
	if result.Decision != hookproto.DecisionDeny {
		t.Errorf("expected deny, got %s", result.Decision)
	}
}

func TestR01_SudoInMiddle(t *testing.T) {
	ctx := makeCtx("Bash", map[string]interface{}{"command": "echo hello && sudo apt install"})
	result := EvaluateRules(ctx)
	if result.Decision != hookproto.DecisionDeny {
		t.Errorf("expected deny, got %s", result.Decision)
	}
}

func TestR01_SudoWrappedByEnv(t *testing.T) {
	ctx := makeCtx("Bash", map[string]interface{}{"command": "env sudo id"})
	result := EvaluateRules(ctx)
	if result.Decision != hookproto.DecisionDeny {
		t.Errorf("expected deny, got %s", result.Decision)
	}
}

func TestR01_SudoWrappedByWatch(t *testing.T) {
	ctx := makeCtx("Bash", map[string]interface{}{"command": "watch sudo id"})
	result := EvaluateRules(ctx)
	if result.Decision != hookproto.DecisionDeny {
		t.Errorf("expected deny, got %s", result.Decision)
	}
}

func TestR01_NoSudo(t *testing.T) {
	ctx := makeCtx("Bash", map[string]interface{}{"command": "ls -la"})
	result := EvaluateRules(ctx)
	if result.Decision != hookproto.DecisionApprove {
		t.Errorf("expected approve, got %s", result.Decision)
	}
}

// ---------------------------------------------------------------------------
// R02: protected path write block
// ---------------------------------------------------------------------------

func TestR02_WriteToEnv(t *testing.T) {
	ctx := makeCtx("Write", map[string]interface{}{"file_path": ".env"})
	result := EvaluateRules(ctx)
	if result.Decision != hookproto.DecisionDeny {
		t.Errorf("expected deny, got %s", result.Decision)
	}
}

func TestR02_WriteToGitDir(t *testing.T) {
	ctx := makeCtx("Edit", map[string]interface{}{"file_path": ".git/config"})
	result := EvaluateRules(ctx)
	if result.Decision != hookproto.DecisionDeny {
		t.Errorf("expected deny, got %s", result.Decision)
	}
}

func TestR02_WriteToIdRsa(t *testing.T) {
	ctx := makeCtx("Write", map[string]interface{}{"file_path": "/home/user/.ssh/id_rsa"})
	result := EvaluateRules(ctx)
	if result.Decision != hookproto.DecisionDeny {
		t.Errorf("expected deny, got %s", result.Decision)
	}
}

func TestR02_WriteToNormalFile(t *testing.T) {
	ctx := makeCtx("Write", map[string]interface{}{"file_path": "/project/src/main.ts"})
	result := EvaluateRules(ctx)
	if result.Decision != hookproto.DecisionApprove {
		t.Errorf("expected approve, got %s", result.Decision)
	}
}

func TestR02_WriteToPemFile(t *testing.T) {
	ctx := makeCtx("Write", map[string]interface{}{"file_path": "certs/server.pem"})
	result := EvaluateRules(ctx)
	if result.Decision != hookproto.DecisionDeny {
		t.Errorf("expected deny, got %s", result.Decision)
	}
}

func TestR02_WriteToClaudeSkillsAsks(t *testing.T) {
	ctx := makeCtx("Write", map[string]interface{}{"file_path": "/project/.claude/skills/demo/SKILL.md"})
	result := EvaluateRules(ctx)
	if result.Decision != hookproto.DecisionAsk {
		t.Errorf("expected ask, got %s", result.Decision)
	}
}

func TestR02_MultiEditClaudeAgentsAsks(t *testing.T) {
	ctx := makeCtx("MultiEdit", map[string]interface{}{"file_path": "/project/.claude/agents/worker.md"})
	result := EvaluateRules(ctx)
	if result.Decision != hookproto.DecisionAsk {
		t.Errorf("expected ask, got %s", result.Decision)
	}
}

func TestR02_EditClaudeCommandsAsks(t *testing.T) {
	ctx := makeCtx("Edit", map[string]interface{}{"file_path": "/project/.claude/commands/work.md"})
	result := EvaluateRules(ctx)
	if result.Decision != hookproto.DecisionAsk {
		t.Errorf("expected ask, got %s", result.Decision)
	}
}

func TestR02_WriteVSCodeAsks(t *testing.T) {
	ctx := makeCtx("Write", map[string]interface{}{"file_path": "/project/.vscode/settings.json"})
	result := EvaluateRules(ctx)
	if result.Decision != hookproto.DecisionAsk {
		t.Errorf("expected ask, got %s", result.Decision)
	}
}

func TestR02_WriteShellProfileDeniedInWorkMode(t *testing.T) {
	ctx := makeCtx("Write", map[string]interface{}{"file_path": "/Users/example/.zshrc"})
	ctx.WorkMode = true
	result := EvaluateRules(ctx)
	if result.Decision != hookproto.DecisionDeny {
		t.Errorf("expected deny in work mode, got %s", result.Decision)
	}
}

func TestR02_WriteClaudeRulesWarns(t *testing.T) {
	ctx := makeCtx("Write", map[string]interface{}{"file_path": "/project/.claude/rules/test-quality.md"})
	result := EvaluateRules(ctx)
	if result.Decision != hookproto.DecisionApprove {
		t.Errorf("expected approve warning, got %s", result.Decision)
	}
	if result.SystemMessage == "" {
		t.Error("expected warning systemMessage")
	}
}

func TestR02_WriteClaudeStateNotOverDenied(t *testing.T) {
	ctx := makeCtx("Write", map[string]interface{}{"file_path": "/project/.claude/state/session.json"})
	result := EvaluateRules(ctx)
	if result.Decision != hookproto.DecisionApprove {
		t.Errorf("expected approve for non-taxonomy .claude path, got %s", result.Decision)
	}
	if result.SystemMessage != "" {
		t.Errorf("expected no warning for non-taxonomy .claude path, got: %s", result.SystemMessage)
	}
}

// ---------------------------------------------------------------------------
// R03: Bash write to protected paths
// ---------------------------------------------------------------------------

func TestR03_EchoToEnv(t *testing.T) {
	ctx := makeCtx("Bash", map[string]interface{}{"command": "echo SECRET=foo > .env"})
	result := EvaluateRules(ctx)
	if result.Decision != hookproto.DecisionDeny {
		t.Errorf("expected deny, got %s", result.Decision)
	}
}

func TestR03_TeeToGit(t *testing.T) {
	ctx := makeCtx("Bash", map[string]interface{}{"command": "echo test | tee .git/config"})
	result := EvaluateRules(ctx)
	if result.Decision != hookproto.DecisionDeny {
		t.Errorf("expected deny, got %s", result.Decision)
	}
}

func TestR03_NormalBash(t *testing.T) {
	ctx := makeCtx("Bash", map[string]interface{}{"command": "echo hello > output.txt"})
	result := EvaluateRules(ctx)
	if result.Decision != hookproto.DecisionApprove {
		t.Errorf("expected approve, got %s", result.Decision)
	}
}

func TestR03_RedirectToShellProfileDenied(t *testing.T) {
	ctx := makeCtx("Bash", map[string]interface{}{"command": "printf 'bad' >> ~/.zshrc"})
	result := EvaluateRules(ctx)
	if result.Decision != hookproto.DecisionDeny {
		t.Errorf("expected deny, got %s", result.Decision)
	}
}

func TestR03_TeeToClaudeSkillsAsksInWorkMode(t *testing.T) {
	ctx := makeCtx("Bash", map[string]interface{}{"command": "printf '%s' data | tee -a .claude/skills/demo/SKILL.md"})
	ctx.WorkMode = true
	result := EvaluateRules(ctx)
	if result.Decision != hookproto.DecisionAsk {
		t.Errorf("expected ask in work mode, got %s", result.Decision)
	}
}

func TestR03_TeeToVSCodeAsks(t *testing.T) {
	ctx := makeCtx("Bash", map[string]interface{}{"command": "echo '{}' | tee .vscode/settings.json >/dev/null"})
	result := EvaluateRules(ctx)
	if result.Decision != hookproto.DecisionAsk {
		t.Errorf("expected ask, got %s", result.Decision)
	}
}

func TestR03_RedirectToClaudeMemoryWarns(t *testing.T) {
	ctx := makeCtx("Bash", map[string]interface{}{"command": "cat <<'EOF' > .claude/memory/patterns.md\nx\nEOF"})
	result := EvaluateRules(ctx)
	if result.Decision != hookproto.DecisionApprove {
		t.Errorf("expected approve warning, got %s", result.Decision)
	}
	if result.SystemMessage == "" {
		t.Error("expected warning systemMessage")
	}
}

func TestR03_RedirectToClaudeHooksDeniedInWorkMode(t *testing.T) {
	ctx := makeCtx("Bash", map[string]interface{}{"command": "echo '#!/bin/sh' > .claude/hooks/pre-tool.sh"})
	ctx.WorkMode = true
	result := EvaluateRules(ctx)
	if result.Decision != hookproto.DecisionDeny {
		t.Errorf("expected deny in work mode, got %s", result.Decision)
	}
}

func TestR03_RedirectToClaudeStateNotOverDenied(t *testing.T) {
	ctx := makeCtx("Bash", map[string]interface{}{"command": "echo '{}' > .claude/state/session.json"})
	result := EvaluateRules(ctx)
	if result.Decision != hookproto.DecisionApprove {
		t.Errorf("expected approve for non-taxonomy .claude path, got %s", result.Decision)
	}
	if result.SystemMessage != "" {
		t.Errorf("expected no warning for non-taxonomy .claude path, got: %s", result.SystemMessage)
	}
}

func TestR03_EnvAskListReturnsAsk(t *testing.T) {
	ctx := makeCtx("Bash", map[string]interface{}{"command": "printf 'SECRET=foo\n' > .env"})
	ctx.ProtectedPathAskList = []hookproto.ProtectedPathAskEntry{{
		Path:   ".env",
		Reason: "customer deploy env update",
		Source: "/project/harness.toml",
	}}
	result := EvaluateRules(ctx)
	if result.Decision != hookproto.DecisionAsk {
		t.Fatalf("expected ask, got %s", result.Decision)
	}
	for _, want := range []string{"R03", ".env", "harness.toml", "customer deploy env update"} {
		if !strings.Contains(result.Reason, want) {
			t.Fatalf("expected ask reason to contain %q, got %q", want, result.Reason)
		}
	}
	if strings.Contains(result.Reason, "SECRET=foo") {
		t.Fatalf("ask reason echoed command content: %q", result.Reason)
	}
}

func TestR02_EnvAskListDoesNotBypassWriteDeny(t *testing.T) {
	ctx := makeCtx("Write", map[string]interface{}{"file_path": ".env"})
	ctx.ProtectedPathAskList = []hookproto.ProtectedPathAskEntry{{
		Path:   ".env",
		Reason: "customer deploy env update",
		Source: "/project/harness.toml",
	}}
	result := EvaluateRules(ctx)
	if result.Decision != hookproto.DecisionDeny {
		t.Fatalf("expected R02 deny, got %s", result.Decision)
	}
}

func TestR03_EnvAskListRequiresNonEmptyReason(t *testing.T) {
	ctx := makeCtx("Bash", map[string]interface{}{"command": "printf 'SECRET=foo\n' > .env"})
	ctx.ProtectedPathAskList = []hookproto.ProtectedPathAskEntry{{
		Path:   ".env",
		Reason: " ",
		Source: "/project/harness.toml",
	}}
	result := EvaluateRules(ctx)
	if result.Decision != hookproto.DecisionDeny {
		t.Fatalf("expected deny when ask-list reason is empty, got %s", result.Decision)
	}
}

func TestR03_EnvAskListRequiresExactPath(t *testing.T) {
	ctx := makeCtx("Bash", map[string]interface{}{"command": "printf 'SECRET=foo\n' > .env.production"})
	ctx.ProtectedPathAskList = []hookproto.ProtectedPathAskEntry{{
		Path:   ".env",
		Reason: "customer deploy env update",
		Source: "/project/harness.toml",
	}}
	result := EvaluateRules(ctx)
	if result.Decision != hookproto.DecisionDeny {
		t.Fatalf("expected deny for non-exact ask-list path, got %s", result.Decision)
	}
}

func TestR03_EnvAskListCanMatchNarrowEnvVariant(t *testing.T) {
	ctx := makeCtx("Bash", map[string]interface{}{"command": "printf 'SECRET=foo\n' > .env.production"})
	ctx.ProtectedPathAskList = []hookproto.ProtectedPathAskEntry{{
		Path:   ".env.production",
		Reason: "customer deploy env update",
		Source: "/project/harness.toml",
	}}
	result := EvaluateRules(ctx)
	if result.Decision != hookproto.DecisionAsk {
		t.Fatalf("expected ask for exact env variant path, got %s", result.Decision)
	}
}

func TestR03_EnvAskListCanMatchAbsolutePathInsideProject(t *testing.T) {
	ctx := makeCtx("Bash", map[string]interface{}{"command": "printf 'SECRET=foo\n' > /project/.env"})
	ctx.ProtectedPathAskList = []hookproto.ProtectedPathAskEntry{{
		Path:   ".env",
		Reason: "customer deploy env update",
		Source: "/project/harness.toml",
	}}
	result := EvaluateRules(ctx)
	if result.Decision != hookproto.DecisionAsk {
		t.Fatalf("expected ask for absolute path inside project, got %s", result.Decision)
	}
}

func TestR03_EnvAskListDoesNotBypassOutsideProjectPath(t *testing.T) {
	tests := []struct {
		name    string
		command string
		path    string
	}{
		{name: "relative traversal", command: "echo data > ../other/.env", path: "../other/.env"},
		{name: "absolute outside project", command: "echo data > /tmp/.env", path: "/tmp/.env"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			ctx := makeCtx("Bash", map[string]interface{}{"command": tt.command})
			ctx.ProtectedPathAskList = []hookproto.ProtectedPathAskEntry{{
				Path:   tt.path,
				Reason: "customer deploy env update",
				Source: "/project/harness.toml",
			}}
			result := EvaluateRules(ctx)
			if result.Decision != hookproto.DecisionDeny {
				t.Fatalf("expected deny for project-external path %s, got %s", tt.path, result.Decision)
			}
		})
	}
}

func TestR03_EnvAskListDoesNotBypassHardDenyPaths(t *testing.T) {
	tests := []struct {
		name    string
		command string
		path    string
	}{
		{name: "git", command: "echo data > .git/config", path: ".git/config"},
		{name: "secrets", command: "echo data > secrets/.env", path: "secrets/.env"},
		{name: "pem", command: "echo data > certs/server.pem", path: "certs/server.pem"},
		{name: "key", command: "echo data > .env.key", path: ".env.key"},
		{name: "ssh trust", command: "echo data > .ssh/authorized_keys", path: ".ssh/authorized_keys"},
		{name: "shell rc", command: "echo data > .zshrc", path: ".zshrc"},
		{name: "claude hooks", command: "echo data > .claude/hooks/pre-tool.sh", path: ".claude/hooks/pre-tool.sh"},
		{name: "husky", command: "echo data > .husky/pre-commit", path: ".husky/pre-commit"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			ctx := makeCtx("Bash", map[string]interface{}{"command": tt.command})
			ctx.ProtectedPathAskList = []hookproto.ProtectedPathAskEntry{{
				Path:   tt.path,
				Reason: "customer deploy env update",
				Source: "/project/harness.toml",
			}}
			result := EvaluateRules(ctx)
			if result.Decision != hookproto.DecisionDeny {
				t.Fatalf("expected deny for %s, got %s", tt.path, result.Decision)
			}
		})
	}
}

func TestR03_EnvAskListDoesNotHideMixedHardDenyTarget(t *testing.T) {
	ctx := makeCtx("Bash", map[string]interface{}{"command": "echo safe > .env && echo hard > .git/config"})
	ctx.ProtectedPathAskList = []hookproto.ProtectedPathAskEntry{{
		Path:   ".env",
		Reason: "customer deploy env update",
		Source: "/project/harness.toml",
	}}
	result := EvaluateRules(ctx)
	if result.Decision != hookproto.DecisionDeny {
		t.Fatalf("expected deny when command also writes hard-deny path, got %s", result.Decision)
	}
}

func TestR03_SedInPlaceEnvWriteOutOfScope(t *testing.T) {
	ctx := makeCtx("Bash", map[string]interface{}{"command": "sed -i '' 's/foo/bar/' .env"})
	ctx.ProtectedPathAskList = []hookproto.ProtectedPathAskEntry{{
		Path:   ".env",
		Reason: "customer deploy env update",
		Source: "/project/harness.toml",
	}}
	result := EvaluateRules(ctx)
	if result.Decision != hookproto.DecisionApprove {
		t.Fatalf("expected approve because R03 currently extracts redirection/tee targets only, got %s", result.Decision)
	}
}

// ---------------------------------------------------------------------------
// R04: write outside project root
// ---------------------------------------------------------------------------

func TestR04_WriteOutsideProject(t *testing.T) {
	ctx := makeCtx("Write", map[string]interface{}{"file_path": "/tmp/malicious.sh"})
	result := EvaluateRules(ctx)
	if result.Decision != hookproto.DecisionAsk {
		t.Errorf("expected ask, got %s", result.Decision)
	}
}

func TestR04_WriteInsideProject(t *testing.T) {
	ctx := makeCtx("Write", map[string]interface{}{"file_path": "/project/src/index.ts"})
	result := EvaluateRules(ctx)
	if result.Decision != hookproto.DecisionApprove {
		t.Errorf("expected approve, got %s", result.Decision)
	}
}

func TestR04_RelativePath(t *testing.T) {
	ctx := makeCtx("Write", map[string]interface{}{"file_path": "src/index.ts"})
	result := EvaluateRules(ctx)
	if result.Decision != hookproto.DecisionApprove {
		t.Errorf("expected approve, got %s", result.Decision)
	}
}

func TestR04_WorkModeBypass(t *testing.T) {
	ctx := makeCtx("Write", map[string]interface{}{"file_path": "/tmp/file.txt"})
	ctx.WorkMode = true
	result := EvaluateRules(ctx)
	if result.Decision != hookproto.DecisionApprove {
		t.Errorf("expected approve in work mode, got %s", result.Decision)
	}
}

// ---------------------------------------------------------------------------
// R05: rm -rf confirmation
// ---------------------------------------------------------------------------

func TestR05_RmRfBlocked(t *testing.T) {
	ctx := makeCtx("Bash", map[string]interface{}{"command": "rm -rf /var/data"})
	result := EvaluateRules(ctx)
	if result.Decision != hookproto.DecisionAsk {
		t.Errorf("expected ask, got %s", result.Decision)
	}
}

func TestR05_RmRfWorkMode(t *testing.T) {
	ctx := makeCtx("Bash", map[string]interface{}{"command": "rm -rf ./dist"})
	ctx.WorkMode = true
	result := EvaluateRules(ctx)
	if result.Decision != hookproto.DecisionApprove {
		t.Errorf("expected approve in work mode, got %s", result.Decision)
	}
}

func TestR05_RmFOnly(t *testing.T) {
	// rm -f (without -r) should NOT trigger R05
	ctx := makeCtx("Bash", map[string]interface{}{"command": "rm -f temp.txt"})
	result := EvaluateRules(ctx)
	if result.Decision != hookproto.DecisionApprove {
		t.Errorf("expected approve for rm -f (no -r), got %s", result.Decision)
	}
}

func TestR05_RmRecursive(t *testing.T) {
	ctx := makeCtx("Bash", map[string]interface{}{"command": "rm --recursive ./dir"})
	result := EvaluateRules(ctx)
	if result.Decision != hookproto.DecisionAsk {
		t.Errorf("expected ask, got %s", result.Decision)
	}
}

func TestR05_FindDelete(t *testing.T) {
	ctx := makeCtx("Bash", map[string]interface{}{"command": "find . -name '*.tmp' -delete"})
	result := EvaluateRules(ctx)
	if result.Decision != hookproto.DecisionAsk {
		t.Errorf("expected ask, got %s", result.Decision)
	}
}

func TestR05_FindExecRmRf(t *testing.T) {
	ctx := makeCtx("Bash", map[string]interface{}{"command": `find . -type f -exec rm -rf {} \;`})
	result := EvaluateRules(ctx)
	if result.Decision != hookproto.DecisionAsk {
		t.Errorf("expected ask, got %s", result.Decision)
	}
}

func TestR05_FindPrintOnly(t *testing.T) {
	ctx := makeCtx("Bash", map[string]interface{}{"command": "find . -name '*.tmp' -print"})
	result := EvaluateRules(ctx)
	if result.Decision != hookproto.DecisionApprove {
		t.Errorf("expected approve, got %s", result.Decision)
	}
}

func TestR05_MacOSPrivatePath(t *testing.T) {
	ctx := makeCtx("Bash", map[string]interface{}{"command": "rm -r /private/etc"})
	result := EvaluateRules(ctx)
	if result.Decision != hookproto.DecisionAsk {
		t.Errorf("expected ask, got %s", result.Decision)
	}
}

func TestR05_MacOSUserLibrary(t *testing.T) {
	ctx := makeCtx("Bash", map[string]interface{}{"command": "rm -r ~/Library/Messages"})
	result := EvaluateRules(ctx)
	if result.Decision != hookproto.DecisionAsk {
		t.Errorf("expected ask, got %s", result.Decision)
	}
}

// ---------------------------------------------------------------------------
// R06: force push block
// ---------------------------------------------------------------------------

func TestR06_ForcePush(t *testing.T) {
	ctx := makeCtx("Bash", map[string]interface{}{"command": "git push --force origin main"})
	result := EvaluateRules(ctx)
	if result.Decision != hookproto.DecisionDeny {
		t.Errorf("expected deny, got %s", result.Decision)
	}
}

func TestR06_ForceWithLease(t *testing.T) {
	ctx := makeCtx("Bash", map[string]interface{}{"command": "git push --force-with-lease origin feature"})
	result := EvaluateRules(ctx)
	if result.Decision != hookproto.DecisionDeny {
		t.Errorf("expected deny, got %s", result.Decision)
	}
}

func TestR06_ShortForce(t *testing.T) {
	ctx := makeCtx("Bash", map[string]interface{}{"command": "git push -f origin main"})
	result := EvaluateRules(ctx)
	if result.Decision != hookproto.DecisionDeny {
		t.Errorf("expected deny, got %s", result.Decision)
	}
}

func TestR06_NormalPush(t *testing.T) {
	ctx := makeCtx("Bash", map[string]interface{}{"command": "git push origin feature"})
	result := EvaluateRules(ctx)
	// R12 might trigger a warning for protected branch, but this is "feature"
	if result.Decision == hookproto.DecisionDeny {
		t.Errorf("expected non-deny for normal push, got deny")
	}
}

// ---------------------------------------------------------------------------
// R07: Codex mode write block
// ---------------------------------------------------------------------------

func TestR07_CodexModeWrite(t *testing.T) {
	ctx := makeCtx("Write", map[string]interface{}{"file_path": "/project/src/main.ts"})
	ctx.CodexMode = true
	result := EvaluateRules(ctx)
	if result.Decision != hookproto.DecisionDeny {
		t.Errorf("expected deny in codex mode, got %s", result.Decision)
	}
}

func TestR07_CodexModeEdit(t *testing.T) {
	ctx := makeCtx("Edit", map[string]interface{}{"file_path": "/project/src/main.ts"})
	ctx.CodexMode = true
	result := EvaluateRules(ctx)
	if result.Decision != hookproto.DecisionDeny {
		t.Errorf("expected deny in codex mode, got %s", result.Decision)
	}
}

func TestR07_CodexModeBash(t *testing.T) {
	// Bash is NOT blocked by R07 (only Write/Edit/MultiEdit)
	ctx := makeCtx("Bash", map[string]interface{}{"command": "echo hello"})
	ctx.CodexMode = true
	result := EvaluateRules(ctx)
	if result.Decision != hookproto.DecisionApprove {
		t.Errorf("expected approve for Bash in codex mode, got %s", result.Decision)
	}
}

func TestR07_NormalModeWrite(t *testing.T) {
	ctx := makeCtx("Write", map[string]interface{}{"file_path": "/project/src/main.ts"})
	ctx.CodexMode = false
	result := EvaluateRules(ctx)
	if result.Decision != hookproto.DecisionApprove {
		t.Errorf("expected approve in normal mode, got %s", result.Decision)
	}
}

// ---------------------------------------------------------------------------
// R08: Breezing reviewer write block
// ---------------------------------------------------------------------------

func TestR08_ReviewerWrite(t *testing.T) {
	ctx := makeCtx("Write", map[string]interface{}{"file_path": "/project/src/main.ts"})
	ctx.BreezingRole = "reviewer"
	result := EvaluateRules(ctx)
	if result.Decision != hookproto.DecisionDeny {
		t.Errorf("expected deny for reviewer write, got %s", result.Decision)
	}
}

func TestR08_ReviewerBashGitCommit(t *testing.T) {
	ctx := makeCtx("Bash", map[string]interface{}{"command": "git commit -m 'test'"})
	ctx.BreezingRole = "reviewer"
	result := EvaluateRules(ctx)
	if result.Decision != hookproto.DecisionDeny {
		t.Errorf("expected deny for reviewer git commit, got %s", result.Decision)
	}
}

func TestR08_ReviewerBashReadOnly(t *testing.T) {
	ctx := makeCtx("Bash", map[string]interface{}{"command": "cat README.md"})
	ctx.BreezingRole = "reviewer"
	result := EvaluateRules(ctx)
	if result.Decision != hookproto.DecisionApprove {
		t.Errorf("expected approve for reviewer read-only bash, got %s", result.Decision)
	}
}

func TestR08_WorkerWrite(t *testing.T) {
	ctx := makeCtx("Write", map[string]interface{}{"file_path": "/project/src/main.ts"})
	ctx.BreezingRole = "worker"
	result := EvaluateRules(ctx)
	if result.Decision != hookproto.DecisionApprove {
		t.Errorf("expected approve for worker write, got %s", result.Decision)
	}
}

// ---------------------------------------------------------------------------
// R09: secret file read warning
// ---------------------------------------------------------------------------

func TestR09_ReadEnv(t *testing.T) {
	ctx := makeCtx("Read", map[string]interface{}{"file_path": "/project/.env"})
	result := EvaluateRules(ctx)
	if result.Decision != hookproto.DecisionApprove {
		t.Errorf("expected approve (warning only), got %s", result.Decision)
	}
	if result.SystemMessage == "" {
		t.Error("expected a warning systemMessage")
	}
}

func TestR09_ReadIdRsa(t *testing.T) {
	ctx := makeCtx("Read", map[string]interface{}{"file_path": "/home/user/.ssh/id_rsa"})
	result := EvaluateRules(ctx)
	if result.SystemMessage == "" {
		t.Error("expected a warning systemMessage for id_rsa")
	}
}

func TestR09_ReadNormalFile(t *testing.T) {
	ctx := makeCtx("Read", map[string]interface{}{"file_path": "/project/README.md"})
	result := EvaluateRules(ctx)
	if result.SystemMessage != "" {
		t.Errorf("expected no warning for normal file, got: %s", result.SystemMessage)
	}
}

// ---------------------------------------------------------------------------
// R10: --no-verify / --no-gpg-sign block
// ---------------------------------------------------------------------------

func TestR10_NoVerify(t *testing.T) {
	ctx := makeCtx("Bash", map[string]interface{}{"command": "git commit --no-verify -m 'test'"})
	result := EvaluateRules(ctx)
	if result.Decision != hookproto.DecisionDeny {
		t.Errorf("expected deny, got %s", result.Decision)
	}
}

func TestR10_NoGpgSign(t *testing.T) {
	ctx := makeCtx("Bash", map[string]interface{}{"command": "git commit --no-gpg-sign -m 'test'"})
	result := EvaluateRules(ctx)
	if result.Decision != hookproto.DecisionDeny {
		t.Errorf("expected deny, got %s", result.Decision)
	}
}

func TestR10_NormalCommit(t *testing.T) {
	ctx := makeCtx("Bash", map[string]interface{}{"command": "git commit -m 'test'"})
	result := EvaluateRules(ctx)
	if result.Decision != hookproto.DecisionApprove {
		t.Errorf("expected approve, got %s", result.Decision)
	}
}

// TestR10_ShellMetacharBypass guards against issue #171: the flag is still
// effective when followed by a shell metacharacter with no intervening space
// (e.g. `--no-verify&&cmd`), so the guardrail must still deny those forms.
func TestR10_ShellMetacharBypass(t *testing.T) {
	denyCases := []string{
		`git commit -m "msg" --no-verify&&echo done`,
		`git commit -m "msg" --no-verify;echo ok`,
		`git commit -m "msg" --no-verify|tee /dev/null`,
		`git commit -m "msg" --no-verify&background`,
		`git commit -m "msg" --no-gpg-sign&&echo done`,
		`git commit -m "msg" --no-gpg-sign;echo ok`,
		`(git commit --no-verify -m x)`,
		`git commit -m "msg";--no-verify`,
	}
	for _, cmd := range denyCases {
		ctx := makeCtx("Bash", map[string]interface{}{"command": cmd})
		result := EvaluateRules(ctx)
		if result.Decision != hookproto.DecisionDeny {
			t.Errorf("expected deny for %q, got %s", cmd, result.Decision)
		}
	}
}

// TestR10_NoFalsePositive ensures the broadened boundary does not flag commands
// that merely contain the flag name as a substring of a larger token.
func TestR10_NoFalsePositive(t *testing.T) {
	approveCases := []string{
		`git commit -m "add --no-verify-mode docs"`,
		`echo --no-verifyx`,
		`git commit -m "msg --no-gpg-signature note"`,
	}
	for _, cmd := range approveCases {
		ctx := makeCtx("Bash", map[string]interface{}{"command": cmd})
		result := EvaluateRules(ctx)
		if result.Decision == hookproto.DecisionDeny {
			t.Errorf("expected non-deny for %q, got deny", cmd)
		}
	}
}

// ---------------------------------------------------------------------------
// R11: protected branch reset --hard
// ---------------------------------------------------------------------------

func TestR11_ResetHardMain(t *testing.T) {
	ctx := makeCtx("Bash", map[string]interface{}{"command": "git reset --hard origin/main"})
	result := EvaluateRules(ctx)
	if result.Decision != hookproto.DecisionDeny {
		t.Errorf("expected deny, got %s", result.Decision)
	}
}

func TestR11_ResetHardMaster(t *testing.T) {
	ctx := makeCtx("Bash", map[string]interface{}{"command": "git reset --hard master"})
	result := EvaluateRules(ctx)
	if result.Decision != hookproto.DecisionDeny {
		t.Errorf("expected deny, got %s", result.Decision)
	}
}

func TestR11_ResetHardFeature(t *testing.T) {
	ctx := makeCtx("Bash", map[string]interface{}{"command": "git reset --hard origin/feature"})
	result := EvaluateRules(ctx)
	if result.Decision != hookproto.DecisionApprove {
		t.Errorf("expected approve for non-protected branch, got %s", result.Decision)
	}
}

func TestR11_ResetSoftMain(t *testing.T) {
	ctx := makeCtx("Bash", map[string]interface{}{"command": "git reset --soft main"})
	result := EvaluateRules(ctx)
	if result.Decision != hookproto.DecisionApprove {
		t.Errorf("expected approve for soft reset, got %s", result.Decision)
	}
}

// ---------------------------------------------------------------------------
// R12: configurable direct push policy for protected branch
// ---------------------------------------------------------------------------

func TestR12_PushToMain(t *testing.T) {
	ctx := makeCtx("Bash", map[string]interface{}{"command": "git push origin main"})
	result := EvaluateRules(ctx)
	if result.Decision != hookproto.DecisionAsk {
		t.Errorf("expected ask, got %s", result.Decision)
	}
	if result.Reason == "" {
		t.Error("expected ask reason for push to main")
	}
}

func TestR12_PushToFeature(t *testing.T) {
	ctx := makeCtx("Bash", map[string]interface{}{"command": "git push origin feature-branch"})
	result := EvaluateRules(ctx)
	if result.Decision != hookproto.DecisionApprove {
		t.Errorf("expected approve for feature branch push, got %s", result.Decision)
	}
	if result.SystemMessage != "" {
		t.Errorf("expected no warning for feature branch push, got: %s", result.SystemMessage)
	}
}

func TestR12_PushRefspecToMain(t *testing.T) {
	ctx := makeCtx("Bash", map[string]interface{}{"command": "git push origin HEAD:main"})
	result := EvaluateRules(ctx)
	if result.Decision != hookproto.DecisionAsk {
		t.Errorf("expected ask, got %s", result.Decision)
	}
	if result.Reason == "" {
		t.Error("expected ask reason for refspec push to main")
	}
}

func TestR12_PushToMainPolicyDeny(t *testing.T) {
	ctx := makeCtx("Bash", map[string]interface{}{"command": "git push origin main"})
	ctx.ProtectedBranchPushPolicy = "deny"
	result := EvaluateRules(ctx)
	if result.Decision != hookproto.DecisionDeny {
		t.Errorf("expected deny, got %s", result.Decision)
	}
}

func TestR12_PushToMainPolicyAllow(t *testing.T) {
	ctx := makeCtx("Bash", map[string]interface{}{"command": "git push origin main"})
	ctx.ProtectedBranchPushPolicy = "allow"
	result := EvaluateRules(ctx)
	if result.Decision != hookproto.DecisionApprove {
		t.Errorf("expected approve, got %s", result.Decision)
	}
}

func TestR12_PushToMainInvalidPolicyDefaultsAsk(t *testing.T) {
	ctx := makeCtx("Bash", map[string]interface{}{"command": "git push origin main"})
	ctx.ProtectedBranchPushPolicy = "unexpected"
	result := EvaluateRules(ctx)
	if result.Decision != hookproto.DecisionAsk {
		t.Errorf("expected ask, got %s", result.Decision)
	}
}

// ---------------------------------------------------------------------------
// R13: protected review paths warning
// ---------------------------------------------------------------------------

func TestR13_WritePackageJson(t *testing.T) {
	ctx := makeCtx("Write", map[string]interface{}{"file_path": "/project/package.json"})
	result := EvaluateRules(ctx)
	if result.Decision != hookproto.DecisionApprove {
		t.Errorf("expected approve (warning only), got %s", result.Decision)
	}
	if result.SystemMessage == "" {
		t.Error("expected warning systemMessage for package.json")
	}
}

func TestR13_WriteDockerfile(t *testing.T) {
	ctx := makeCtx("Edit", map[string]interface{}{"file_path": "Dockerfile"})
	result := EvaluateRules(ctx)
	if result.SystemMessage == "" {
		t.Error("expected warning for Dockerfile")
	}
}

func TestR13_WriteGitHubWorkflow(t *testing.T) {
	ctx := makeCtx("Write", map[string]interface{}{"file_path": ".github/workflows/ci.yml"})
	result := EvaluateRules(ctx)
	if result.SystemMessage == "" {
		t.Error("expected warning for GitHub workflow")
	}
}

func TestR13_WriteNormalFile(t *testing.T) {
	ctx := makeCtx("Write", map[string]interface{}{"file_path": "/project/src/utils.ts"})
	result := EvaluateRules(ctx)
	if result.SystemMessage != "" {
		t.Errorf("expected no warning for normal file, got: %s", result.SystemMessage)
	}
}

// ---------------------------------------------------------------------------
// Rule evaluation order: first match wins
// ---------------------------------------------------------------------------

func ruleIndex(id string) int {
	for i, rule := range Rules {
		if rule.ID == id {
			return i
		}
	}
	return -1
}

func TestR14_RegisteredBeforeOutsideRootAsk(t *testing.T) {
	r02 := ruleIndex("R02:no-write-protected-paths")
	r03 := ruleIndex("R03:no-bash-write-protected-paths")
	r14 := ruleIndex("R14:test-required-for-src-write")
	r04 := ruleIndex("R04:confirm-write-outside-project")

	if r02 < 0 || r03 < 0 || r14 < 0 || r04 < 0 {
		t.Fatalf("expected R02/R03/R14/R04 to be registered, got R02=%d R03=%d R14=%d R04=%d", r02, r03, r14, r04)
	}
	if !(r02 < r14 && r03 < r14 && r14 < r04) {
		t.Fatalf("expected R14 after protected write basics and before outside-root ask, got R02=%d R03=%d R14=%d R04=%d", r02, r03, r14, r04)
	}
}

func TestR14_TddBypassDoesNotBypassCodexWriteDeny(t *testing.T) {
	ctx := makeCtx("Write", map[string]interface{}{
		"file_path": "/project/src/app.go",
		"content":   "package main\n",
	})
	ctx.CodexMode = true
	ctx.TddEnforceLevel = tddEnforceLevelMax
	ctx.TddHookEnabled = true
	ctx.TddBypass = true

	result := EvaluateRules(ctx)

	if result.Decision != hookproto.DecisionDeny {
		t.Fatalf("expected TDD bypass to continue into Codex write deny, got %s", result.Decision)
	}
	if !strings.Contains(result.Reason, "Codex mode") {
		t.Fatalf("expected Codex write denial reason, got %q", result.Reason)
	}
}

func TestFirstMatchWins(t *testing.T) {
	// sudo rm -rf should be caught by R01 (sudo) before R05 (rm -rf)
	ctx := makeCtx("Bash", map[string]interface{}{"command": "sudo rm -rf /"})
	result := EvaluateRules(ctx)
	if result.Decision != hookproto.DecisionDeny {
		t.Errorf("expected deny, got %s", result.Decision)
	}
	// R01 reason mentions sudo
	if result.Reason == "" || result.Reason[0:4] != "sudo" {
		// Check that the reason is about sudo, not rm -rf
		if result.Reason != "sudo is not allowed. If it is required, ask the user to run it manually." {
			t.Errorf("expected sudo reason, got: %s", result.Reason)
		}
	}
}

func TestUnknownToolApproved(t *testing.T) {
	ctx := makeCtx("UnknownTool", map[string]interface{}{})
	result := EvaluateRules(ctx)
	if result.Decision != hookproto.DecisionApprove {
		t.Errorf("expected approve for unknown tool, got %s", result.Decision)
	}
}

// ---------------------------------------------------------------------------
// Task 38.1.2: R06 whitespace normalization tests (CC 2.1.98)
// ---------------------------------------------------------------------------

func TestR06_PushForceMultipleSpaces(t *testing.T) {
	// "git  push  --force" with multiple spaces should still be denied
	ctx := makeCtx("Bash", map[string]interface{}{"command": "git  push  --force"})
	result := EvaluateRules(ctx)
	if result.Decision != hookproto.DecisionDeny {
		t.Errorf("expected deny for multi-space force push, got %s", result.Decision)
	}
}

func TestR06_PushForceTabs(t *testing.T) {
	// "git\tpush\t-f" with tab separators should still be denied
	ctx := makeCtx("Bash", map[string]interface{}{"command": "git\tpush\t-f"})
	result := EvaluateRules(ctx)
	if result.Decision != hookproto.DecisionDeny {
		t.Errorf("expected deny for tab-separated force push, got %s", result.Decision)
	}
}

func TestR06_PushForceWithLeaseSpaces(t *testing.T) {
	// "git push   --force-with-lease" with extra spaces should still be denied
	ctx := makeCtx("Bash", map[string]interface{}{"command": "git push   --force-with-lease"})
	result := EvaluateRules(ctx)
	if result.Decision != hookproto.DecisionDeny {
		t.Errorf("expected deny for force-with-lease with extra spaces, got %s", result.Decision)
	}
}

// ---------------------------------------------------------------------------
// Phase 62.1.5: wrapper bypass coverage for R06/R11/R12
//
// CC 2.1.113 hardened deny rules to match `env`/`sudo`/`watch` wrappers.
// These tests verify that Harness guardrails behave the same for the three
// commonly-used wrappers, so that `env FOO=1 git push --force` (etc.) cannot
// be used to slip past force-push / reset-hard / protected-push deny.
//
// Note: when wrapped by `sudo`, R01 (sudo block) fires first and the test
// observes Deny via R01 rather than the target rule. That is still the
// intended security posture — the deny chain catches the wrapper.
// ---------------------------------------------------------------------------

// R06 wrapper bypass: env / sudo / watch must not let force-push through.
func TestR06_WrappedByEnv(t *testing.T) {
	ctx := makeCtx("Bash", map[string]interface{}{
		"command": "env GIT_SSL_NO_VERIFY=1 git push --force origin main",
	})
	result := EvaluateRules(ctx)
	if result.Decision != hookproto.DecisionDeny {
		t.Errorf("expected deny for env-wrapped force push, got %s", result.Decision)
	}
}

func TestR06_WrappedBySudo(t *testing.T) {
	// R01 fires first for sudo, but the deny posture is enforced.
	ctx := makeCtx("Bash", map[string]interface{}{
		"command": "sudo git push --force origin main",
	})
	result := EvaluateRules(ctx)
	if result.Decision != hookproto.DecisionDeny {
		t.Errorf("expected deny for sudo-wrapped force push, got %s", result.Decision)
	}
}

func TestR06_WrappedByWatch(t *testing.T) {
	ctx := makeCtx("Bash", map[string]interface{}{
		"command": "watch -n 5 git push --force origin main",
	})
	result := EvaluateRules(ctx)
	if result.Decision != hookproto.DecisionDeny {
		t.Errorf("expected deny for watch-wrapped force push, got %s", result.Decision)
	}
}

// R11 wrapper bypass: env / sudo / watch must not let reset --hard main through.
func TestR11_WrappedByEnv(t *testing.T) {
	ctx := makeCtx("Bash", map[string]interface{}{
		"command": "env GIT_DIR=.git git reset --hard main",
	})
	result := EvaluateRules(ctx)
	if result.Decision != hookproto.DecisionDeny {
		t.Errorf("expected deny for env-wrapped reset --hard main, got %s", result.Decision)
	}
}

func TestR11_WrappedBySudo(t *testing.T) {
	// R01 fires first for sudo; the deny posture is enforced.
	ctx := makeCtx("Bash", map[string]interface{}{
		"command": "sudo git reset --hard main",
	})
	result := EvaluateRules(ctx)
	if result.Decision != hookproto.DecisionDeny {
		t.Errorf("expected deny for sudo-wrapped reset --hard main, got %s", result.Decision)
	}
}

func TestR11_WrappedByWatch(t *testing.T) {
	ctx := makeCtx("Bash", map[string]interface{}{
		"command": "watch -n 30 git reset --hard origin/main",
	})
	result := EvaluateRules(ctx)
	if result.Decision != hookproto.DecisionDeny {
		t.Errorf("expected deny for watch-wrapped reset --hard origin/main, got %s", result.Decision)
	}
}

// R12 wrapper bypass: env / sudo / watch must not let direct push to main through.
// Default policy is `ask`; for env / watch tests we set `deny` policy explicitly
// so that the wrapper bypass coverage is exercised against the strongest
// configuration. For the sudo case R01 fires first.
func TestR12_WrappedByEnv(t *testing.T) {
	ctx := makeCtx("Bash", map[string]interface{}{
		"command": "env LANG=C git push origin main",
	})
	ctx.ProtectedBranchPushPolicy = "deny"
	result := EvaluateRules(ctx)
	if result.Decision != hookproto.DecisionDeny {
		t.Errorf("expected deny for env-wrapped push to main with deny policy, got %s", result.Decision)
	}
}

func TestR12_WrappedBySudo(t *testing.T) {
	// R01 fires first for sudo; the deny posture is enforced regardless of policy.
	ctx := makeCtx("Bash", map[string]interface{}{
		"command": "sudo git push origin main",
	})
	result := EvaluateRules(ctx)
	if result.Decision != hookproto.DecisionDeny {
		t.Errorf("expected deny for sudo-wrapped push to main, got %s", result.Decision)
	}
}

func TestR12_WrappedByWatch(t *testing.T) {
	ctx := makeCtx("Bash", map[string]interface{}{
		"command": "watch -n 60 git push origin main",
	})
	ctx.ProtectedBranchPushPolicy = "deny"
	result := EvaluateRules(ctx)
	if result.Decision != hookproto.DecisionDeny {
		t.Errorf("expected deny for watch-wrapped push to main with deny policy, got %s", result.Decision)
	}
}
