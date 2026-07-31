package main

import (
	"bytes"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

func runSessionCapture(t *testing.T, args []string) (stdout string, code int) {
	t.Helper()
	var out bytes.Buffer
	var errOut bytes.Buffer
	code = runSessionCommand(args, &out, &errOut)
	return out.String(), code
}

func initGitRepoForCLI(t *testing.T, dir string) {
	t.Helper()
	cmd := exec.Command("git", "init", "-q")
	cmd.Dir = dir
	if out, err := cmd.CombinedOutput(); err != nil {
		t.Fatalf("git init: %s: %v", out, err)
	}
	for _, args := range [][]string{
		{"config", "user.email", "test@test"},
		{"config", "user.name", "test"},
	} {
		cmd := exec.Command("git", args...)
		cmd.Dir = dir
		if out, err := cmd.CombinedOutput(); err != nil {
			t.Fatalf("git %v: %s: %v", args, out, err)
		}
	}
}

func TestSessionCLI_DeclareListClearRoundTrip(t *testing.T) {
	dir := t.TempDir()
	initGitRepoForCLI(t, dir)
	const sessionID = "sess-cli-roundtrip"
	stateDir := filepath.Join(dir, ".claude", "state")
	if err := os.MkdirAll(stateDir, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(stateDir, "session.json"), []byte(`{"session_id":"`+sessionID+`"}`), 0o644); err != nil {
		t.Fatal(err)
	}
	t.Setenv("HARNESS_PROJECT_ROOT", dir)

	_, code := runSessionCapture(t, []string{"declare", "--task", "121.4"})
	if code != 0 {
		t.Fatalf("declare exit %d", code)
	}

	listOut, code := runSessionCapture(t, []string{"list"})
	if code != 0 {
		t.Fatalf("list exit %d", code)
	}
	if !strings.Contains(listOut, "121.4") || !strings.Contains(listOut, sessionID) {
		t.Fatalf("list missing task/session:\n%s", listOut)
	}

	_, code = runSessionCapture(t, []string{"declare", "--clear"})
	if code != 0 {
		t.Fatalf("clear exit %d", code)
	}
	listAfter, _ := runSessionCapture(t, []string{"list"})
	if strings.Contains(listAfter, "121.4") {
		t.Fatalf("task still listed after clear:\n%s", listAfter)
	}
}
