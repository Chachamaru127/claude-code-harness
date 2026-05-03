package hookhandler

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"testing"
)

func TestHandleWorktreeCreate_EmptyInput(t *testing.T) {
	var out bytes.Buffer
	if err := HandleWorktreeCreate(strings.NewReader(""), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	assertWorktreeApprove(t, out.String(), "WorktreeCreate: no payload")
}

func TestHandleWorktreeCreate_InvalidJSON(t *testing.T) {
	var out bytes.Buffer
	if err := HandleWorktreeCreate(strings.NewReader("not json"), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	assertWorktreeApprove(t, out.String(), "WorktreeCreate: no payload")
}

func TestHandleWorktreeCreate_NoCWD(t *testing.T) {
	var out bytes.Buffer
	payload := `{"session_id":"s1","cwd":""}`
	if err := HandleWorktreeCreate(strings.NewReader(payload), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	assertWorktreeApprove(t, out.String(), "WorktreeCreate: no cwd")
}

func TestHandleWorktreeCreate_RejectsHookDecisionAsCWD(t *testing.T) {
	dir := t.TempDir()
	originalWD, err := os.Getwd()
	if err != nil {
		t.Fatalf("getwd: %v", err)
	}
	if err := os.Chdir(dir); err != nil {
		t.Fatalf("chdir temp: %v", err)
	}
	t.Cleanup(func() {
		_ = os.Chdir(originalWD)
	})

	var out bytes.Buffer
	badCWD := `{"decision":"approve","reason":"WorktreeCreate: initialized worktree state"}`
	payload := `{"session_id":"worker-json","cwd":` + strconv.Quote(badCWD) + `}`
	if err := HandleWorktreeCreate(strings.NewReader(payload), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	assertWorktreeApprove(t, out.String(), "WorktreeCreate: invalid cwd")
	if _, err := os.Stat(filepath.Join(dir, badCWD)); !os.IsNotExist(err) {
		t.Fatalf("hook decision JSON was treated as a directory: stat err=%v", err)
	}
}

func TestHandleWorktreeCreate_CreatesStateDir(t *testing.T) {
	dir := t.TempDir()

	var out bytes.Buffer
	payload := `{"session_id":"worker-123","cwd":"` + dir + `"}`
	if err := HandleWorktreeCreate(strings.NewReader(payload), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	assertWorktreeApprove(t, out.String(), "WorktreeCreate: initialized worktree state")

	// .claude/state/ must be created.
	stateDir := filepath.Join(dir, ".claude", "state")
	if info, err := os.Stat(stateDir); err != nil || !info.IsDir() {
		t.Errorf(".claude/state/ was not created at %s", stateDir)
	}
}

func TestHandleWorktreeCreate_WritesWorktreeInfo(t *testing.T) {
	dir := t.TempDir()

	var out bytes.Buffer
	payload := `{"session_id":"worker-xyz","cwd":"` + dir + `"}`
	if err := HandleWorktreeCreate(strings.NewReader(payload), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	infoPath := filepath.Join(dir, ".claude", "state", "worktree-info.json")
	data, err := os.ReadFile(infoPath)
	if err != nil {
		t.Fatalf("worktree-info.json not created: %v", err)
	}

	var info worktreeInfo
	if err := json.Unmarshal(bytes.TrimSpace(data), &info); err != nil {
		t.Fatalf("worktree-info.json is not valid JSON: %v\n%s", err, data)
	}

	if info.WorkerID != "worker-xyz" {
		t.Errorf("WorkerID = %q, want worker-xyz", info.WorkerID)
	}
	if info.CWD != dir {
		t.Errorf("CWD = %q, want %q", info.CWD, dir)
	}
	if info.CreatedAt == "" {
		t.Error("CreatedAt is empty")
	}
}

func TestHandleWorktreeCreate_Idempotent(t *testing.T) {
	dir := t.TempDir()

	// Run twice — second call should not fail even though state dir already exists.
	for i := 0; i < 2; i++ {
		var out bytes.Buffer
		payload := `{"session_id":"s","cwd":"` + dir + `"}`
		if err := HandleWorktreeCreate(strings.NewReader(payload), &out); err != nil {
			t.Fatalf("call %d: unexpected error: %v", i+1, err)
		}
		assertWorktreeApprove(t, out.String(), "WorktreeCreate: initialized worktree state")
	}
}

func TestWorktreeStateDir_UsesPlatformJoin(t *testing.T) {
	dir := filepath.Join("repo", "worker-a")
	got := worktreeStateDir(dir)
	want := filepath.Join(dir, ".claude", "state")
	if got != want {
		t.Fatalf("worktreeStateDir() = %q, want %q", got, want)
	}
}

// assertWorktreeApprove verifies the output is a valid JSON approve response
// with the expected reason.
func assertWorktreeApprove(t *testing.T, output, expectedReason string) {
	t.Helper()
	output = strings.TrimSpace(output)
	if output == "" {
		t.Fatal("expected approve JSON, got empty output")
	}
	var resp map[string]string
	if err := json.Unmarshal([]byte(output), &resp); err != nil {
		t.Fatalf("output is not valid JSON: %v\noutput: %s", err, output)
	}
	if resp["decision"] != "approve" {
		t.Errorf("decision = %q, want approve", resp["decision"])
	}
	if expectedReason != "" && resp["reason"] != expectedReason {
		t.Errorf("reason = %q, want %q", resp["reason"], expectedReason)
	}
}
