package policy

import (
	"strings"
	"testing"

	"github.com/Chachamaru127/claude-code-harness/go/pkg/hookproto"
)

func ctxWithDenyList(toolName string, toolInput map[string]interface{}, deny []string) hookproto.RuleContext {
	ctx := makeCtx(toolName, toolInput)
	ctx.ProtectedPathDenyList = deny
	return ctx
}

// ---------------------------------------------------------------------------
// R16: configured protected path deny (paths.protected)
// ---------------------------------------------------------------------------

func TestR16_DeniesWriteUnderProtectedDir(t *testing.T) {
	ctx := ctxWithDenyList("Write",
		map[string]interface{}{"file_path": "/project/infra/main.tf"},
		[]string{"infra/"})
	res := EvaluateRules(ctx)
	if res.Decision != hookproto.DecisionDeny {
		t.Fatalf("expected deny, got %s (%s)", res.Decision, res.Reason)
	}
	if !strings.Contains(res.Reason, "paths.protected") {
		t.Errorf("reason should reference paths.protected, got %q", res.Reason)
	}
}

func TestR16_DeniesExactFileDeclaration(t *testing.T) {
	ctx := ctxWithDenyList("Edit",
		map[string]interface{}{"file_path": "/project/config/prod.yaml"},
		[]string{"config/prod.yaml"})
	if res := EvaluateRules(ctx); res.Decision != hookproto.DecisionDeny {
		t.Fatalf("expected deny for exact file, got %s", res.Decision)
	}
}

func TestR16_DeclarationWithoutSlashMatchesSubtree(t *testing.T) {
	ctx := ctxWithDenyList("Write",
		map[string]interface{}{"file_path": "/project/generated/api.ts"},
		[]string{"generated"})
	if res := EvaluateRules(ctx); res.Decision != hookproto.DecisionDeny {
		t.Fatalf("expected deny for subtree, got %s", res.Decision)
	}
}

func TestR16_AllowsUnprotectedPath(t *testing.T) {
	ctx := ctxWithDenyList("Write",
		map[string]interface{}{"file_path": "/project/src/app.ts"},
		[]string{"infra/", "generated/"})
	if res := EvaluateRules(ctx); res.Decision != hookproto.DecisionApprove {
		t.Fatalf("expected approve for unprotected path, got %s (%s)", res.Decision, res.Reason)
	}
}

func TestR16_GlobDeclarationMatches(t *testing.T) {
	ctx := ctxWithDenyList("Write",
		map[string]interface{}{"file_path": "/project/.env.local"},
		[]string{".env.*"})
	if res := EvaluateRules(ctx); res.Decision != hookproto.DecisionDeny {
		t.Fatalf("expected deny for glob declaration, got %s (%s)", res.Decision, res.Reason)
	}
}

func TestR16_GlobDeclarationMatchesNestedBasename(t *testing.T) {
	ctx := ctxWithDenyList("Write",
		map[string]interface{}{"file_path": "/project/config/.env.prod"},
		[]string{".env.*"})
	if res := EvaluateRules(ctx); res.Decision != hookproto.DecisionDeny {
		t.Fatalf("expected deny for nested glob basename, got %s", res.Decision)
	}
}

func TestR16_NoDenyListIsNoop(t *testing.T) {
	ctx := makeCtx("Write", map[string]interface{}{"file_path": "/project/infra/main.tf"})
	if res := EvaluateRules(ctx); res.Decision != hookproto.DecisionApprove {
		t.Fatalf("expected approve with empty deny list, got %s", res.Decision)
	}
}

func TestR16_PrefixIsBoundaryAware(t *testing.T) {
	// "infra" must not match "infrastructure/..." — only the exact segment.
	ctx := ctxWithDenyList("Write",
		map[string]interface{}{"file_path": "/project/infrastructure/main.tf"},
		[]string{"infra"})
	if res := EvaluateRules(ctx); res.Decision != hookproto.DecisionApprove {
		t.Fatalf("expected approve (no false prefix match), got %s", res.Decision)
	}
}

func TestR16_WriteOutsideProjectNotMatched(t *testing.T) {
	// Outside-project writes are governed by R04, not R16. R16 must not match
	// a project-relative declaration against a path outside the root.
	ctx := ctxWithDenyList("Write",
		map[string]interface{}{"file_path": "/elsewhere/infra/main.tf"},
		[]string{"infra/"})
	res := EvaluateRules(ctx)
	// R04 asks for confirmation on outside-project writes; the key assertion is
	// that R16 did not produce its deny reason.
	if strings.Contains(res.Reason, "paths.protected") {
		t.Fatalf("R16 should not match outside-project path, got %q", res.Reason)
	}
}

// ---------------------------------------------------------------------------
// R11/R12: config-driven protected branches (git.protected_branches)
// ---------------------------------------------------------------------------

func ctxWithBranches(command string, branches []string) hookproto.RuleContext {
	ctx := makeCtx("Bash", map[string]interface{}{"command": command})
	ctx.ProtectedBranches = branches
	return ctx
}

func TestR12_ConfiguredBranchAsked(t *testing.T) {
	ctx := ctxWithBranches("git push origin production", []string{"production"})
	if res := EvaluateRules(ctx); res.Decision != hookproto.DecisionAsk {
		t.Fatalf("expected ask for configured protected branch push, got %s", res.Decision)
	}
}

func TestR12_UnconfiguredBranchNotAsked(t *testing.T) {
	ctx := ctxWithBranches("git push origin production", nil)
	if res := EvaluateRules(ctx); res.Decision != hookproto.DecisionApprove {
		t.Fatalf("expected approve when 'production' is not configured, got %s", res.Decision)
	}
}

func TestR12_DefaultBranchesStillAsked(t *testing.T) {
	ctx := ctxWithBranches("git push origin main", nil)
	if res := EvaluateRules(ctx); res.Decision != hookproto.DecisionAsk {
		t.Fatalf("expected ask for default protected branch main, got %s", res.Decision)
	}
}

func TestR11_ConfiguredBranchResetHardDenied(t *testing.T) {
	ctx := ctxWithBranches("git reset --hard production", []string{"production"})
	if res := EvaluateRules(ctx); res.Decision != hookproto.DecisionDeny {
		t.Fatalf("expected deny for reset --hard on configured branch, got %s", res.Decision)
	}
}

func TestR11_UnconfiguredBranchResetHardAllowed(t *testing.T) {
	ctx := ctxWithBranches("git reset --hard feature-x", []string{"production"})
	if res := EvaluateRules(ctx); res.Decision != hookproto.DecisionApprove {
		t.Fatalf("expected approve for reset --hard on non-protected branch, got %s", res.Decision)
	}
}
