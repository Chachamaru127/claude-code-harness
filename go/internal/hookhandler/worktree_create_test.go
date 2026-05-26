package hookhandler

import (
	"bytes"
	"encoding/json"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"testing"
)

// initTestRepo creates a throwaway git repo with one commit and returns its path.
func initTestRepo(t *testing.T) string {
	t.Helper()
	dir := t.TempDir()

	run := func(args ...string) {
		cmd := exec.Command(args[0], args[1:]...)
		cmd.Dir = dir
		cmd.Env = append(os.Environ(),
			"GIT_AUTHOR_NAME=test", "GIT_AUTHOR_EMAIL=test@test",
			"GIT_COMMITTER_NAME=test", "GIT_COMMITTER_EMAIL=test@test",
		)
		if out, err := cmd.CombinedOutput(); err != nil {
			t.Fatalf("%v: %s: %v", args, out, err)
		}
	}

	run("git", "init", "-q")
	run("git", "config", "user.email", "test@test")
	run("git", "config", "user.name", "test")
	if err := os.WriteFile(filepath.Join(dir, "README"), []byte("seed\n"), 0o644); err != nil {
		t.Fatalf("seed file: %v", err)
	}
	run("git", "add", "README")
	run("git", "commit", "-q", "-m", "seed")
	return dir
}

func TestHandleWorktreeCreate_EmptyInput_EmitsNothing(t *testing.T) {
	var out bytes.Buffer
	if err := HandleWorktreeCreate(strings.NewReader(""), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if strings.TrimSpace(out.String()) != "" {
		t.Fatalf("expected empty stdout, got %q", out.String())
	}
}

func TestHandleWorktreeCreate_InvalidJSON_EmitsNothing(t *testing.T) {
	var out bytes.Buffer
	if err := HandleWorktreeCreate(strings.NewReader("not json"), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if strings.TrimSpace(out.String()) != "" {
		t.Fatalf("expected empty stdout, got %q", out.String())
	}
}

func TestHandleWorktreeCreate_NoCWD_EmitsNothing(t *testing.T) {
	var out bytes.Buffer
	if err := HandleWorktreeCreate(strings.NewReader(`{"session_id":"s1","cwd":""}`), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if strings.TrimSpace(out.String()) != "" {
		t.Fatalf("expected empty stdout, got %q", out.String())
	}
}

// The legacy decision-JSON-as-cwd bug must never be treated as a path.
func TestHandleWorktreeCreate_RejectsHookDecisionAsCWD(t *testing.T) {
	var out bytes.Buffer
	badCWD := `{"decision":"approve","reason":"WorktreeCreate: initialized worktree state"}`
	payload := `{"session_id":"worker-json","cwd":` + strconv.Quote(badCWD) + `}`
	if err := HandleWorktreeCreate(strings.NewReader(payload), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if strings.TrimSpace(out.String()) != "" {
		t.Fatalf("decision JSON cwd produced output %q", out.String())
	}
	if _, err := os.Stat(badCWD); !os.IsNotExist(err) {
		t.Fatalf("hook decision JSON was treated as a directory: stat err=%v", err)
	}
}

// Contract: with a valid repo cwd, the hook creates a worktree and prints ONLY
// its path on stdout (not a JSON object).
func TestHandleWorktreeCreate_CreatesWorktreeAndPrintsPath(t *testing.T) {
	repo := initTestRepo(t)

	var out bytes.Buffer
	payload := `{"session_id":"worker-123","cwd":` + strconv.Quote(repo) + `}`
	if err := HandleWorktreeCreate(strings.NewReader(payload), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	printed := strings.TrimSpace(out.String())
	if printed == "" {
		t.Fatal("expected a worktree path on stdout, got empty")
	}
	if strings.HasPrefix(printed, "{") {
		t.Fatalf("stdout must be a path, not JSON: %q", printed)
	}

	info, err := os.Stat(printed)
	if err != nil || !info.IsDir() {
		t.Fatalf("printed path is not a directory: %q (err=%v)", printed, err)
	}
	if !isGitWorktree(printed) {
		t.Fatalf("printed path is not a git worktree: %q", printed)
	}

	stateDir := filepath.Join(printed, ".claude", "state")
	if si, err := os.Stat(stateDir); err != nil || !si.IsDir() {
		t.Errorf(".claude/state/ not created at %s", stateDir)
	}
}

func TestHandleWorktreeCreate_WritesWorktreeInfo(t *testing.T) {
	repo := initTestRepo(t)

	var out bytes.Buffer
	payload := `{"session_id":"worker-xyz","cwd":` + strconv.Quote(repo) + `}`
	if err := HandleWorktreeCreate(strings.NewReader(payload), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	worktreePath := strings.TrimSpace(out.String())

	infoPath := filepath.Join(worktreePath, ".claude", "state", "worktree-info.json")
	data, err := os.ReadFile(infoPath)
	if err != nil {
		t.Fatalf("worktree-info.json not created: %v", err)
	}
	var info worktreeInfo
	if err := json.Unmarshal(bytes.TrimSpace(data), &info); err != nil {
		t.Fatalf("worktree-info.json invalid JSON: %v\n%s", err, data)
	}
	if info.WorkerID != "worker-xyz" {
		t.Errorf("WorkerID = %q, want worker-xyz", info.WorkerID)
	}
	if info.CWD != worktreePath {
		t.Errorf("CWD = %q, want %q", info.CWD, worktreePath)
	}
	if info.CreatedAt == "" {
		t.Error("CreatedAt is empty")
	}
}

// Idempotency: a second call for the same session reuses the existing worktree
// and prints the same path without failing.
func TestHandleWorktreeCreate_Idempotent(t *testing.T) {
	repo := initTestRepo(t)
	payload := `{"session_id":"s-idem","cwd":` + strconv.Quote(repo) + `}`

	var first bytes.Buffer
	if err := HandleWorktreeCreate(strings.NewReader(payload), &first); err != nil {
		t.Fatalf("call 1: %v", err)
	}
	firstPath := strings.TrimSpace(first.String())
	if firstPath == "" {
		t.Fatal("call 1 produced no path")
	}

	var second bytes.Buffer
	if err := HandleWorktreeCreate(strings.NewReader(payload), &second); err != nil {
		t.Fatalf("call 2: %v", err)
	}
	secondPath := strings.TrimSpace(second.String())
	if secondPath != firstPath {
		t.Fatalf("idempotency broken: %q != %q", secondPath, firstPath)
	}
	if !isGitWorktree(secondPath) {
		t.Fatalf("reused path is not a worktree: %q", secondPath)
	}
}

// An explicit worktree path in tool_input is honored.
func TestHandleWorktreeCreate_HonorsToolInputPath(t *testing.T) {
	repo := initTestRepo(t)
	want := filepath.Join(repo, "custom-wt")

	payload := `{"session_id":"s","cwd":` + strconv.Quote(repo) +
		`,"tool_input":{"worktreePath":` + strconv.Quote(want) + `}}`
	var out bytes.Buffer
	if err := HandleWorktreeCreate(strings.NewReader(payload), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	got := strings.TrimSpace(out.String())
	if got != want {
		t.Fatalf("path = %q, want %q", got, want)
	}
	if !isGitWorktree(got) {
		t.Fatalf("not a worktree: %q", got)
	}
}

func TestSanitizeWorktreeSlug(t *testing.T) {
	cases := map[string]string{
		"worker/abc.def": "worker-abc-def",
		"  spaced  ":      "spaced",
		"a:b\\c":          "a-b-c",
		"":                "",
	}
	for in, want := range cases {
		if got := sanitizeWorktreeSlug(in); got != want {
			t.Errorf("sanitizeWorktreeSlug(%q) = %q, want %q", in, got, want)
		}
	}
}
