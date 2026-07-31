package main

import (
	"bytes"
	"encoding/json"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

func TestEvaluatePreCompact_BlocksMatchingLoopSession(t *testing.T) {
	dir := t.TempDir()
	lockDir := filepath.Join(dir, ".claude", "state", "locks", "loop-session.lock.d")
	if err := os.MkdirAll(lockDir, 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(lockDir, "meta.json"), []byte(`{"session_id":"sess-worker"}`), 0600); err != nil {
		t.Fatal(err)
	}

	input := `{"session_id":"sess-worker","cwd":"` + dir + `","agent_type":"worker"}`
	var out bytes.Buffer
	exitCode, err := evaluatePreCompact(strings.NewReader(input), &out)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if exitCode != 2 {
		t.Fatalf("expected exit code 2, got %d", exitCode)
	}

	var decision preCompactDecision
	if err := json.Unmarshal(bytes.TrimSpace(out.Bytes()), &decision); err != nil {
		t.Fatalf("invalid JSON output: %v", err)
	}
	if decision.Decision != "block" {
		t.Fatalf("expected decision=block, got %q", decision.Decision)
	}
}

func TestEvaluatePreCompact_AllowsReviewer(t *testing.T) {
	dir := t.TempDir()
	input := `{"session_id":"sess-reviewer","cwd":"` + dir + `","agent_type":"reviewer"}`
	var out bytes.Buffer
	exitCode, err := evaluatePreCompact(strings.NewReader(input), &out)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if exitCode != 0 {
		t.Fatalf("expected exit code 0, got %d", exitCode)
	}
	if out.Len() != 0 {
		t.Fatalf("expected no output, got %q", out.String())
	}
}

func TestEvaluatePreCompact_AutoCommitsDirtyPlans(t *testing.T) {
	dir := t.TempDir()
	runGit(t, dir, "init")
	runGit(t, dir, "config", "user.name", "Harness Test")
	runGit(t, dir, "config", "user.email", "harness@example.com")

	plansPath := filepath.Join(dir, "Plans.md")
	if err := os.WriteFile(plansPath, []byte("initial\n"), 0600); err != nil {
		t.Fatal(err)
	}
	runGit(t, dir, "add", "Plans.md")
	runGit(t, dir, "commit", "-m", "test: add plans")

	if err := os.WriteFile(plansPath, []byte("dirty\n"), 0600); err != nil {
		t.Fatal(err)
	}

	input := `{"session_id":"sess-main","cwd":"` + dir + `"}`
	var out bytes.Buffer
	exitCode, err := evaluatePreCompact(strings.NewReader(input), &out)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if exitCode != 0 {
		t.Fatalf("expected exit code 0, got %d; output: %s", exitCode, out.String())
	}

	var cont struct {
		Continue bool   `json:"continue"`
		Message  string `json:"message"`
	}
	if err := json.Unmarshal(bytes.TrimSpace(out.Bytes()), &cont); err != nil {
		t.Fatalf("invalid JSON output: %v", err)
	}
	if !cont.Continue {
		t.Fatalf("expected continue=true, got %q", out.String())
	}
	if !strings.Contains(cont.Message, "auto-committed") {
		t.Fatalf("expected auto-commit message, got %q", cont.Message)
	}

	if isPlansDirty(dir, plansPath) {
		t.Fatal("Plans.md should be clean after auto-commit")
	}

	logOut := runGitOutput(t, dir, "log", "-1", "--oneline")
	if !strings.Contains(logOut, "chore(plans): auto-checkpoint before compaction") {
		t.Fatalf("expected auto-checkpoint commit message, got %q", logOut)
	}
}

func TestEvaluatePreCompact_AutoCommitDoesNotSweepOtherFiles(t *testing.T) {
	dir := t.TempDir()
	runGit(t, dir, "init")
	runGit(t, dir, "config", "user.name", "Harness Test")
	runGit(t, dir, "config", "user.email", "harness@example.com")

	plansPath := filepath.Join(dir, "Plans.md")
	otherPath := filepath.Join(dir, "other.txt")
	if err := os.WriteFile(plansPath, []byte("plans v1\n"), 0600); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(otherPath, []byte("other v1\n"), 0600); err != nil {
		t.Fatal(err)
	}
	runGit(t, dir, "add", "Plans.md", "other.txt")
	runGit(t, dir, "commit", "-m", "test: initial")

	if err := os.WriteFile(plansPath, []byte("plans dirty\n"), 0600); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(otherPath, []byte("other dirty\n"), 0600); err != nil {
		t.Fatal(err)
	}
	stagedPath := filepath.Join(dir, "staged-only.txt")
	if err := os.WriteFile(stagedPath, []byte("staged\n"), 0600); err != nil {
		t.Fatal(err)
	}
	runGit(t, dir, "add", "staged-only.txt")

	input := `{"session_id":"sess-main","cwd":"` + dir + `"}`
	var out bytes.Buffer
	exitCode, err := evaluatePreCompact(strings.NewReader(input), &out)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if exitCode != 0 {
		t.Fatalf("expected exit code 0, got %d; output: %s", exitCode, out.String())
	}

	statusOut := runGitOutput(t, dir, "status", "--short")
	if !strings.Contains(statusOut, "other.txt") {
		t.Fatalf("other.txt should remain dirty, status:\n%s", statusOut)
	}
	if !strings.Contains(statusOut, "staged-only.txt") {
		t.Fatalf("staged-only.txt should remain staged, status:\n%s", statusOut)
	}
	if strings.Contains(statusOut, "Plans.md") {
		t.Fatalf("Plans.md should be clean, status:\n%s", statusOut)
	}
}

func TestEvaluatePreCompact_AutoCommitFailureBlocks(t *testing.T) {
	dir := t.TempDir()
	isolateGitIdentity(t, dir)
	runGit(t, dir, "init")

	plansPath := filepath.Join(dir, "Plans.md")
	if err := os.WriteFile(plansPath, []byte("initial\n"), 0600); err != nil {
		t.Fatal(err)
	}
	runGit(t, dir, "add", "Plans.md")
	runGit(t, dir, "-c", "user.name=Harness Test", "-c", "user.email=harness@example.com", "commit", "-m", "test: add plans")

	if err := os.WriteFile(plansPath, []byte("dirty\n"), 0600); err != nil {
		t.Fatal(err)
	}

	input := `{"session_id":"sess-main","cwd":"` + dir + `"}`
	var out bytes.Buffer
	exitCode, err := evaluatePreCompact(strings.NewReader(input), &out)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if exitCode != 2 {
		t.Fatalf("expected exit code 2, got %d; output: %s", exitCode, out.String())
	}

	var decision preCompactDecision
	if err := json.Unmarshal(bytes.TrimSpace(out.Bytes()), &decision); err != nil {
		t.Fatalf("invalid JSON output: %v", err)
	}
	if decision.Decision != "block" {
		t.Fatalf("expected decision=block, got %q", decision.Decision)
	}
	if !strings.Contains(decision.Reason, "Plans.md has uncommitted edits") {
		t.Fatalf("expected original context in reason, got %q", decision.Reason)
	}
	if !strings.Contains(decision.Reason, "auto-commit failed") {
		t.Fatalf("expected auto-commit failure hint in reason, got %q", decision.Reason)
	}
}

func TestEvaluatePreCompact_BlocksDirtyPlansWhenOptOut(t *testing.T) {
	dir := t.TempDir()
	runGit(t, dir, "init")
	runGit(t, dir, "config", "user.name", "Harness Test")
	runGit(t, dir, "config", "user.email", "harness@example.com")

	configPath := filepath.Join(dir, ".claude-code-harness.config.yaml")
	if err := os.WriteFile(configPath, []byte("precompactAutoCommit: false\n"), 0600); err != nil {
		t.Fatal(err)
	}

	plansPath := filepath.Join(dir, "Plans.md")
	if err := os.WriteFile(plansPath, []byte("initial\n"), 0600); err != nil {
		t.Fatal(err)
	}
	runGit(t, dir, "add", "Plans.md")
	runGit(t, dir, "commit", "-m", "test: add plans")

	if err := os.WriteFile(plansPath, []byte("dirty\n"), 0600); err != nil {
		t.Fatal(err)
	}

	input := `{"session_id":"sess-main","cwd":"` + dir + `"}`
	var out bytes.Buffer
	exitCode, err := evaluatePreCompact(strings.NewReader(input), &out)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if exitCode != 2 {
		t.Fatalf("expected exit code 2, got %d", exitCode)
	}
	if !strings.Contains(out.String(), "Plans.md") {
		t.Fatalf("expected Plans.md warning, got %q", out.String())
	}
}

func runGit(t *testing.T, dir string, args ...string) {
	t.Helper()
	cmd := exec.Command("git", args...)
	cmd.Dir = dir
	out, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("git %v failed: %v\n%s", args, err, string(out))
	}
}

func runGitOutput(t *testing.T, dir string, args ...string) string {
	t.Helper()
	cmd := exec.Command("git", args...)
	cmd.Dir = dir
	out, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("git %v failed: %v\n%s", args, err, string(out))
	}
	return string(out)
}

// isolateGitIdentity prevents git subprocesses from inheriting the developer's
// global user.name/user.email so auto-commit failure fixtures are deterministic.
func isolateGitIdentity(t *testing.T, dir string) {
	t.Helper()
	emptyGlobal := filepath.Join(dir, "empty-global.gitconfig")
	if err := os.WriteFile(emptyGlobal, []byte("[user]\n\tname = \n\temail = \n"), 0600); err != nil {
		t.Fatal(err)
	}
	t.Setenv("GIT_CONFIG_GLOBAL", emptyGlobal)
	t.Setenv("GIT_CONFIG_SYSTEM", "/dev/null")
}

// TestResolvePreCompactRoot_WalksUpFromSubdir guards against the regression
// where CC launched from a repository subdirectory would search for
// .claude/state/locks/ and Plans.md inside that subdir instead of the
// repository root, causing PreCompact protection to silently no-op for
// monorepo or subpackage layouts.
func TestResolvePreCompactRoot_WalksUpFromSubdir(t *testing.T) {
	repoRoot := t.TempDir()
	runGit(t, repoRoot, "init", "-q")
	subdir := filepath.Join(repoRoot, "packages", "api")
	if err := os.MkdirAll(subdir, 0o755); err != nil {
		t.Fatalf("mkdir subdir: %v", err)
	}

	got := resolvePreCompactRoot(subdir)

	// macOS prepends /private to t.TempDir(); compare via filepath.EvalSymlinks
	wantResolved, _ := filepath.EvalSymlinks(repoRoot)
	gotResolved, _ := filepath.EvalSymlinks(got)
	if gotResolved != wantResolved {
		t.Errorf("resolvePreCompactRoot(subdir) = %q (resolved %q), want repo root %q (resolved %q)",
			got, gotResolved, repoRoot, wantResolved)
	}
}
