package guardrail

import (
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
// R12: deny direct push to protected branch (upgraded from warn in c101efc8)
// ---------------------------------------------------------------------------

func TestR12_PushToMain(t *testing.T) {
	ctx := makeCtx("Bash", map[string]interface{}{"command": "git push origin main"})
	result := EvaluateRules(ctx)
	if result.Decision != hookproto.DecisionDeny {
		t.Errorf("expected deny, got %s", result.Decision)
	}
	if result.Reason == "" {
		t.Error("expected deny reason for push to main")
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
	if result.Decision != hookproto.DecisionDeny {
		t.Errorf("expected deny, got %s", result.Decision)
	}
	if result.Reason == "" {
		t.Error("expected deny reason for refspec push to main")
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
		if result.Reason != "sudo の使用は禁止されています。必要な場合はユーザーに手動実行を依頼してください。" {
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
