package integrate

import (
	"context"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

func TestIntegrate_CallableNotProse(t *testing.T) {
	var _ func(context.Context, Options) (Result, error) = Integrate
}

type passScriptRunner struct{}

func (passScriptRunner) Run(_ string, _ string, _ ...string) (int, string) {
	return 0, "ok"
}

type failScriptRunner struct{}

func (failScriptRunner) Run(_ string, _ string, _ ...string) (int, string) {
	return 1, "floor gate blocked"
}

func runGit(t *testing.T, dir string, args ...string) string {
	t.Helper()
	cmd := exec.Command("git", args...)
	cmd.Dir = dir
	// CI runners have no EDITOR/TERM; keep rebase --continue non-interactive.
	cmd.Env = append(os.Environ(), "GIT_EDITOR=true")
	out, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("git %v: %v\n%s", args, err, out)
	}
	return strings.TrimSpace(string(out))
}

func runGitAllowFail(dir string, args ...string) (string, error) {
	cmd := exec.Command("git", args...)
	cmd.Dir = dir
	cmd.Env = append(os.Environ(), "GIT_EDITOR=true")
	out, err := cmd.CombinedOutput()
	return strings.TrimSpace(string(out)), err
}

func initRepo(t *testing.T) string {
	t.Helper()
	dir := t.TempDir()
	runGit(t, dir, "init", "-b", "trunk")
	runGit(t, dir, "config", "user.email", "test@example.com")
	runGit(t, dir, "config", "user.name", "Test User")
	runGit(t, dir, "config", "rerere.enabled", "true")
	runGit(t, dir, "config", "rerere.autoupdate", "true")
	if err := os.WriteFile(filepath.Join(dir, "README.md"), []byte("root\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dir, ".gitignore"), []byte(".claude/state/\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	runGit(t, dir, "add", "README.md", ".gitignore")
	runGit(t, dir, "commit", "-m", "init")
	return dir
}

func createTaskBranch(t *testing.T, dir, branch, filename, content string) {
	t.Helper()
	runGit(t, dir, "checkout", "trunk")
	runGit(t, dir, "checkout", "-b", branch)
	if err := os.WriteFile(filepath.Join(dir, filename), []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}
	runGit(t, dir, "add", filename)
	runGit(t, dir, "commit", "-m", "task "+branch)
}

func TestIntegrate_HappyPath_ThreeSequentialTasks(t *testing.T) {
	dir := initRepo(t)
	createTaskBranch(t, dir, "task/1", "task1.txt", "one\n")
	createTaskBranch(t, dir, "task/2", "task2.txt", "two\n")
	createTaskBranch(t, dir, "task/3", "task3.txt", "three\n")

	var ledger []IntegrationRecord
	branches := []string{"task/1", "task/2", "task/3"}
	ctx := context.Background()

	for i, branch := range branches {
		res, err := Integrate(ctx, Options{
			RepoRoot:     dir,
			TrunkBranch:  "trunk",
			TaskBranch:   branch,
			Sequence:     i + 1,
			ScriptRunner: passScriptRunner{},
			LedgerWriter: func(rec IntegrationRecord) {
				ledger = append(ledger, rec)
			},
		})
		if err != nil {
			t.Fatalf("seq=%d: %v", i+1, err)
		}
		if res.Record.CommitSHA == "" {
			t.Fatalf("seq=%d: empty commit SHA", i+1)
		}
		if !res.FloorReport.Passed {
			t.Fatalf("seq=%d: floor gate failed: %+v", i+1, res.FloorReport)
		}
	}

	if len(ledger) != 3 {
		t.Fatalf("ledger calls = %d, want 3", len(ledger))
	}
	for i, rec := range ledger {
		if rec.CommitSHA == "" {
			t.Fatalf("ledger[%d]: empty commit SHA", i)
		}
	}
}

func TestIntegrate_RereReplay_SharedFileConflict(t *testing.T) {
	dir := initRepo(t)
	shared := filepath.Join(dir, "SHARED.md")
	if err := os.WriteFile(shared, []byte("base\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	runGit(t, dir, "add", "SHARED.md")
	runGit(t, dir, "commit", "-m", "add shared")

	// T1: base -> T1 line, integrate cleanly.
	runGit(t, dir, "checkout", "-b", "task/t1")
	if err := os.WriteFile(shared, []byte("T1 line\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	runGit(t, dir, "add", "SHARED.md")
	runGit(t, dir, "commit", "-m", "t1 change")

	ctx := context.Background()
	_, err := Integrate(ctx, Options{
		RepoRoot:     dir,
		TrunkBranch:  "trunk",
		TaskBranch:   "task/t1",
		Sequence:     1,
		ScriptRunner: passScriptRunner{},
	})
	if err != nil {
		t.Fatalf("integrate t1: %v", err)
	}

	// T2: forked from pre-T1 trunk (base line), changed to T2 line.
	trunkBase := runGit(t, dir, "rev-parse", "trunk~1")
	runGit(t, dir, "checkout", "-b", "task/t2", trunkBase)
	if err := os.WriteFile(shared, []byte("T2 line\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	runGit(t, dir, "add", "SHARED.md")
	runGit(t, dir, "commit", "-m", "t2 change")

	// Pre-record rerere resolution by completing one rebase, then rewinding the branch.
	runGit(t, dir, "checkout", "task/t2")
	t2SHA := runGit(t, dir, "rev-parse", "HEAD")
	if _, err := runGitAllowFail(dir, "rebase", "trunk"); err == nil {
		t.Fatal("expected rebase conflict")
	}
	if err := os.WriteFile(shared, []byte("T1 line\nT2 line\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	runGit(t, dir, "add", "SHARED.md")
	runGit(t, dir, "rebase", "--continue")
	runGit(t, dir, "checkout", "trunk")
	runGit(t, dir, "branch", "-f", "task/t2", t2SHA)

	res, err := Integrate(ctx, Options{
		RepoRoot:     dir,
		TrunkBranch:  "trunk",
		TaskBranch:   "task/t2",
		Sequence:     2,
		ScriptRunner: passScriptRunner{},
	})
	if err != nil {
		t.Fatalf("integrate t2: %v", err)
	}
	if !res.Record.RereResolved {
		t.Fatal("expected RereResolved=true after rerere replay")
	}
	got, err := os.ReadFile(shared)
	if err != nil {
		t.Fatal(err)
	}
	want := "T1 line\nT2 line\n"
	if string(got) != want {
		t.Fatalf("SHARED.md = %q, want %q", string(got), want)
	}
}

func TestIntegrate_FloorGateFail_AbortsCherryPick(t *testing.T) {
	dir := initRepo(t)
	createTaskBranch(t, dir, "task/fail", "fail.txt", "blocked\n")

	_, err := Integrate(context.Background(), Options{
		RepoRoot:     dir,
		TrunkBranch:  "trunk",
		TaskBranch:   "task/fail",
		Sequence:     1,
		ScriptRunner: failScriptRunner{},
	})
	if err == nil {
		t.Fatal("expected error when floor gate fails")
	}

	status := runGit(t, dir, "status", "--porcelain")
	if status != "" {
		t.Fatalf("working tree not clean after abort: %q", status)
	}
}

func TestIntegrate_LedgerOrder(t *testing.T) {
	dir := initRepo(t)
	createTaskBranch(t, dir, "task/a", "a.txt", "a\n")
	createTaskBranch(t, dir, "task/b", "b.txt", "b\n")
	createTaskBranch(t, dir, "task/c", "c.txt", "c\n")

	var sequences []int
	branches := []string{"task/a", "task/b", "task/c"}
	ctx := context.Background()

	for i, branch := range branches {
		_, err := Integrate(ctx, Options{
			RepoRoot:     dir,
			TrunkBranch:  "trunk",
			TaskBranch:   branch,
			Sequence:     i + 1,
			ScriptRunner: passScriptRunner{},
			LedgerWriter: func(rec IntegrationRecord) {
				sequences = append(sequences, rec.Sequence)
			},
		})
		if err != nil {
			t.Fatalf("seq=%d: %v", i+1, err)
		}
	}

	want := []int{1, 2, 3}
	if len(sequences) != len(want) {
		t.Fatalf("ledger sequences = %v, want %v", sequences, want)
	}
	for i := range want {
		if sequences[i] != want[i] {
			t.Fatalf("ledger order = %v, want %v", sequences, want)
		}
	}
}
