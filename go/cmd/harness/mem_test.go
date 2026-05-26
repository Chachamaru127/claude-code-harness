package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// memHealthResult is the JSON schema returned by runMemHealth (for tests).
type memHealthResult struct {
	Healthy bool   `json:"healthy"`
	Reason  string `json:"reason"`
}

// withStubbedDaemonProbe is a test helper that temporarily replaces daemonProbe.
// Call the returned restore function via defer to revert to the original implementation.
func withStubbedDaemonProbe(t *testing.T, stub func() error) func() {
	t.Helper()
	orig := daemonProbe
	daemonProbe = stub
	return func() { daemonProbe = orig }
}

func TestRunMemHealth_Healthy(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	defer withStubbedDaemonProbe(t, func() error { return nil })()

	// Create ~/.claude-mem/ and settings.json
	claudeMem := filepath.Join(home, ".claude-mem")
	if err := os.MkdirAll(claudeMem, 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(claudeMem, "settings.json"), []byte(`{}`), 0600); err != nil {
		t.Fatal(err)
	}

	out, exitCode := captureMemHealth()
	if exitCode != 0 {
		t.Fatalf("expected exit 0 for healthy, got %d; output: %s", exitCode, out)
	}

	var result memHealthResult
	if err := json.Unmarshal([]byte(out), &result); err != nil {
		t.Fatalf("invalid JSON output: %v\nraw: %s", err, out)
	}
	if !result.Healthy {
		t.Errorf("expected healthy=true, got false (reason: %s)", result.Reason)
	}
}

func TestRunMemHealth_DaemonUnreachable(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	defer withStubbedDaemonProbe(t, func() error { return fmt.Errorf("connection refused") })()

	// Files are in place but the daemon probe fails
	claudeMem := filepath.Join(home, ".claude-mem")
	if err := os.MkdirAll(claudeMem, 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(claudeMem, "settings.json"), []byte(`{}`), 0600); err != nil {
		t.Fatal(err)
	}

	out, exitCode := captureMemHealth()
	if exitCode == 0 {
		t.Fatalf("expected non-zero exit when daemon unreachable, got 0; output: %s", out)
	}

	var result memHealthResult
	if err := json.Unmarshal([]byte(out), &result); err != nil {
		t.Fatalf("invalid JSON output: %v\nraw: %s", err, out)
	}
	if result.Healthy {
		t.Errorf("expected healthy=false when daemon unreachable")
	}
	if result.Reason != "daemon-unreachable" {
		t.Errorf("expected reason=daemon-unreachable, got %q", result.Reason)
	}
}

// TestRunMemHealth_NotConfigured assumes an environment where harness-mem is not installed.
// `~/.claude-mem/` absent means opt-in is unused, so the state is treated as
// not monitored (healthy + reason="not-configured") rather than broken (unhealthy).
// This prevents the MonitorHandler `⚠️ harness-mem unhealthy` warning from
// firing spuriously in sessions where harness-mem is not used.
func TestRunMemHealth_NotConfigured(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	// Do not create ~/.claude-mem/ (harness-mem not installed)

	out, exitCode := captureMemHealth()
	if exitCode != 0 {
		t.Fatalf("expected exit 0 for not-configured (opt-in not used), got %d; output: %s", exitCode, out)
	}

	var result memHealthResult
	if err := json.Unmarshal([]byte(out), &result); err != nil {
		t.Fatalf("invalid JSON output: %v\nraw: %s", err, out)
	}
	if !result.Healthy {
		t.Errorf("expected healthy=true for not-configured (monitor exclusion), got false")
	}
	if result.Reason != "not-configured" {
		t.Errorf("expected reason=not-configured, got %q", result.Reason)
	}
}

func TestRunMemStatus_NotInstalled(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("HARNESS_MEM_DISABLE_PATH_LOOKUP", "1")

	var stdout, stderr bytes.Buffer
	code := runMemCommand([]string{"status", "--json"}, &stdout, &stderr)
	if code != 0 {
		t.Fatalf("status should not fail when companion is absent, code=%d stderr=%s", code, stderr.String())
	}
	var result map[string]interface{}
	if err := json.Unmarshal(stdout.Bytes(), &result); err != nil {
		t.Fatalf("status output is not JSON: %v\n%s", err, stdout.String())
	}
	if result["status"] != "not_configured" {
		t.Fatalf("status = %v, want not_configured", result["status"])
	}
}

func TestRunMemLifecycle_FakeHarnessMem(t *testing.T) {
	fake, logPath := writeFakeHarnessMem(t, `healthy`)
	t.Setenv("HARNESS_MEM_CLI", fake)

	tests := []struct {
		name string
		args []string
	}{
		{"doctor", []string{"doctor", "--json"}},
		{"update", []string{"update"}},
		{"off", []string{"off"}},
		{"purge", []string{"purge", "--confirm-purge"}},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			var stdout, stderr bytes.Buffer
			code := runMemCommand(tt.args, &stdout, &stderr)
			if code != 0 {
				t.Fatalf("%v failed with code=%d stdout=%s stderr=%s", tt.args, code, stdout.String(), stderr.String())
			}
		})
	}

	logData, err := os.ReadFile(logPath)
	if err != nil {
		t.Fatal(err)
	}
	logText := string(logData)
	for _, want := range []string{
		"doctor --json --platform codex,claude",
		"update",
		"recall off",
		"uninstall --platform codex,claude --purge-db",
	} {
		if !strings.Contains(logText, want) {
			t.Fatalf("fake harness-mem log missing %q\nlog:\n%s", want, logText)
		}
	}
}

func TestRunMemSetup_DoctorRedRunsSetup(t *testing.T) {
	fake, logPath := writeFakeHarnessMem(t, `red`)
	t.Setenv("HARNESS_MEM_CLI", fake)

	var stdout, stderr bytes.Buffer
	code := runMemCommand([]string{"setup"}, &stdout, &stderr)
	if code != 0 {
		t.Fatalf("setup failed with code=%d stdout=%s stderr=%s", code, stdout.String(), stderr.String())
	}

	logData, err := os.ReadFile(logPath)
	if err != nil {
		t.Fatal(err)
	}
	logText := string(logData)
	if !strings.Contains(logText, "doctor --json --platform codex,claude --skip-version-check") {
		t.Fatalf("setup should inspect doctor before setup\nlog:\n%s", logText)
	}
	if !strings.Contains(logText, "setup --platform codex,claude --skip-quality --auto-update enable") {
		t.Fatalf("setup should run noninteractive managed setup\nlog:\n%s", logText)
	}
}

func TestRunMemStatus_InvalidDoctorJSON(t *testing.T) {
	fake, _ := writeFakeHarnessMem(t, `broken-json`)
	t.Setenv("HARNESS_MEM_CLI", fake)

	var stdout, stderr bytes.Buffer
	code := runMemCommand([]string{"status", "--json"}, &stdout, &stderr)
	if code == 0 {
		t.Fatalf("status should fail when doctor JSON is broken; stdout=%s stderr=%s", stdout.String(), stderr.String())
	}
	var result map[string]interface{}
	if err := json.Unmarshal(stdout.Bytes(), &result); err != nil {
		t.Fatalf("status broken-json output should still be JSON: %v\n%s", err, stdout.String())
	}
	if result["status"] != "unknown" {
		t.Fatalf("status = %v, want unknown", result["status"])
	}
}

func TestRunMemPurgeRequiresConfirmation(t *testing.T) {
	fake, _ := writeFakeHarnessMem(t, `healthy`)
	t.Setenv("HARNESS_MEM_CLI", fake)

	var stdout, stderr bytes.Buffer
	code := runMemCommand([]string{"purge"}, &stdout, &stderr)
	if code == 0 {
		t.Fatalf("purge without confirmation should fail")
	}
	if !strings.Contains(stderr.String(), "--confirm-purge") {
		t.Fatalf("purge error should mention --confirm-purge, got: %s", stderr.String())
	}
}

func TestRunMemHealth_Corrupted(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)

	// ~/.claude-mem/ exists but neither settings.json nor supervisor.json is present
	claudeMem := filepath.Join(home, ".claude-mem")
	if err := os.MkdirAll(claudeMem, 0700); err != nil {
		t.Fatal(err)
	}
	// Do not create any config files

	out, exitCode := captureMemHealth()
	if exitCode == 0 {
		t.Fatalf("expected non-zero exit for corrupted, got 0; output: %s", out)
	}

	var result memHealthResult
	if err := json.Unmarshal([]byte(out), &result); err != nil {
		t.Fatalf("invalid JSON output: %v\nraw: %s", err, out)
	}
	if result.Healthy {
		t.Errorf("expected healthy=false")
	}
	if result.Reason != "corrupted" {
		t.Errorf("expected reason=corrupted, got %q", result.Reason)
	}
}

// captureMemHealth returns the stdout and exit code of runMemHealth as strings.
// Calls the internal function directly since it is not exported.
func captureMemHealth() (string, int) {
	result, code := runMemHealthCheck()
	data, _ := json.Marshal(result)
	return string(data), code
}

func writeFakeHarnessMem(t *testing.T, mode string) (string, string) {
	t.Helper()
	dir := t.TempDir()
	logPath := filepath.Join(dir, "calls.log")
	scriptPath := filepath.Join(dir, "harness-mem")
	script := fmt.Sprintf(`#!/bin/sh
set -eu
printf '%%s\n' "$*" >> %q
cmd="${1:-}"
shift || true
case "$cmd" in
  doctor)
    case %q in
      healthy)
        printf '%%s\n' '{"status":"healthy","all_green":true,"failed_count":0,"checked_count":1,"timestamp":"2026-05-05T00:00:00Z","checks":[],"fix_command":"harness-mem doctor --fix","backend_mode":"local","contract_version":"claude-harness-companion.v1","harness_mem_version":"0.0.0-test"}'
        ;;
      red)
        printf '%%s\n' '{"status":"unhealthy","all_green":false,"failed_count":1,"checked_count":1,"timestamp":"2026-05-05T00:00:00Z","checks":[{"name":"codex_wiring","status":"missing","fix":"harness-mem setup --platform codex"}],"fix_command":"harness-mem doctor --fix","backend_mode":"local","contract_version":"claude-harness-companion.v1","harness_mem_version":"0.0.0-test"}'
        ;;
      broken-json)
        printf 'not-json\n'
        ;;
    esac
    ;;
  setup|update|recall|uninstall)
    printf '%%s-ok\n' "$cmd"
    ;;
  *)
    printf 'unknown command: %%s\n' "$cmd" >&2
    exit 2
    ;;
esac
`, logPath, mode)
	if err := os.WriteFile(scriptPath, []byte(script), 0o755); err != nil {
		t.Fatal(err)
	}
	return scriptPath, logPath
}
