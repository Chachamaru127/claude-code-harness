package main

import (
	"os"
	"os/exec"
	"strings"
	"testing"
)

// TestRunCodexLoop_Archived verifies that codex-loop exits non-zero and prints
// the archived/unsupported message. Uses subprocess pattern because the
// function calls os.Exit.
func TestRunCodexLoop_Archived(t *testing.T) {
	if os.Getenv("HARNESS_TEST_SUBPROCESS") == "1" {
		runCodexLoop([]string{"status"})
		return
	}
	cmd := exec.Command(os.Args[0], "-test.run=TestRunCodexLoop_Archived")
	cmd.Env = append(os.Environ(), "HARNESS_TEST_SUBPROCESS=1")
	out, err := cmd.CombinedOutput()
	if err == nil {
		t.Fatal("expected non-zero exit code, got zero")
	}
	output := string(out)
	if !strings.Contains(output, "archived") {
		t.Errorf("expected 'archived' in output, got: %s", output)
	}
	if !strings.Contains(output, "Company AI Harness v1") {
		t.Errorf("expected 'Company AI Harness v1' in output, got: %s", output)
	}
}
