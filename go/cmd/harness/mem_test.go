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

// memHealthResult は runMemHealth が返す JSON のスキーマ（テスト用）。
type memHealthResult struct {
	Healthy bool   `json:"healthy"`
	Reason  string `json:"reason"`
}

// withStubbedDaemonProbe は daemonProbe を一時的に差し替えるテストヘルパー。
// 戻り値の restore を defer で呼ぶと元の実装に戻る。
func withStubbedDaemonProbe(t *testing.T, stub func() error) func() {
	t.Helper()
	orig := daemonProbe
	daemonProbe = stub
	return func() { daemonProbe = orig }
}

func TestRunMemHealth_Healthy(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("HARNESS_MEM_HOME", "")
	defer withStubbedDaemonProbe(t, func() error { return nil })()

	// ~/.claude-mem/ と settings.json を作成
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

func TestRunMemHealth_ClaudeMemOnly(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("HARNESS_MEM_HOME", "")
	defer withStubbedDaemonProbe(t, func() error { return fmt.Errorf("connection refused") })()

	// Issue #363: claude-mem の settings.json だけでは harness-mem 未設定なので healthy を期待する。
	claudeMem := filepath.Join(home, ".claude-mem")
	if err := os.MkdirAll(claudeMem, 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(claudeMem, "settings.json"), []byte(`{}`), 0600); err != nil {
		t.Fatal(err)
	}

	out, exitCode := captureMemHealth()
	if exitCode != 0 {
		t.Fatalf("expected exit 0 for claude-mem only, got %d; output: %s", exitCode, out)
	}

	var result memHealthResult
	if err := json.Unmarshal([]byte(out), &result); err != nil {
		t.Fatalf("invalid JSON output: %v\nraw: %s", err, out)
	}
	if !result.Healthy {
		t.Errorf("expected healthy=true for claude-mem only")
	}
	if result.Reason != "not-configured" {
		t.Errorf("expected reason=not-configured, got %q", result.Reason)
	}
}

// TestRunMemHealth_NotConfigured は harness-mem 未インストール環境を想定する。
// `~/.claude-mem/` が無い = opt-in 未使用 なので、壊れている扱い (unhealthy) では
// なく監視対象外 (healthy + reason="not-configured") として扱う。
// これにより MonitorHandler 側の `⚠️ harness-mem unhealthy` 警告が
// harness-mem を使っていないユーザーのセッションで誤発火しない。
func TestRunMemHealth_NotConfigured(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("HARNESS_MEM_HOME", "")
	// ~/.claude-mem/ を作成しない (harness-mem 未インストール状態)

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

func TestRunMemHealth_EmptyClaudeMemNotConfigured(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("HARNESS_MEM_HOME", "")

	// ~/.claude-mem/ は存在するが settings.json も supervisor.json もない
	claudeMem := filepath.Join(home, ".claude-mem")
	if err := os.MkdirAll(claudeMem, 0700); err != nil {
		t.Fatal(err)
	}
	// Issue #363: 空の .claude-mem は harness-mem の破損を示さないので not-configured を期待する。

	out, exitCode := captureMemHealth()
	if exitCode != 0 {
		t.Fatalf("expected exit 0 for not-configured, got %d; output: %s", exitCode, out)
	}

	var result memHealthResult
	if err := json.Unmarshal([]byte(out), &result); err != nil {
		t.Fatalf("invalid JSON output: %v\nraw: %s", err, out)
	}
	if !result.Healthy {
		t.Errorf("expected healthy=true")
	}
	if result.Reason != "not-configured" {
		t.Errorf("expected reason=not-configured, got %q", result.Reason)
	}
}

func TestRunMemHealth_HomeDetection(t *testing.T) {
	tests := []struct {
		name         string
		explicitHome string
		dirs         []string
		files        []string
		wantReason   string
		wantProbes   int
	}{
		{name: "claude-settings", files: []string{".claude-mem/settings.json"}, wantReason: "not-configured"},
		{name: "claude-supervisor", files: []string{".claude-mem/supervisor.json"}, wantReason: "not-configured"},
		{name: "claude-both", files: []string{".claude-mem/settings.json", ".claude-mem/supervisor.json"}, wantReason: "not-configured"},
		{name: "legacy-config", files: []string{".claude-mem/config.json"}, wantProbes: 1},
		{name: "legacy-runtime", files: []string{".claude-mem/runtime/harness-mem/scripts/harness-mem"}, wantProbes: 1},
		{name: "legacy-db", files: []string{".claude-mem/harness-mem.db"}, wantProbes: 1},
		{name: "modern-empty", dirs: []string{".harness-mem"}, files: []string{".claude-mem/config.json"}, wantReason: "not-configured"},
		{name: "modern-config", files: []string{".harness-mem/config.json"}, wantProbes: 1},
		{name: "modern-runtime", files: []string{".harness-mem/runtime/harness-mem/scripts/harness-mem"}, wantProbes: 1},
		{name: "modern-db", files: []string{".harness-mem/harness-mem.db"}, wantProbes: 1},
		{name: "explicit-empty", explicitHome: "custom", dirs: []string{"custom"}, files: []string{".harness-mem/config.json", ".claude-mem/config.json"}, wantReason: "not-configured"},
		{name: "explicit-config", explicitHome: "custom", files: []string{"custom/config.json"}, wantProbes: 1},
		{name: "explicit-claude-settings", explicitHome: ".claude-mem", files: []string{".claude-mem/settings.json"}, wantProbes: 1},
		{name: "explicit-claude-empty", explicitHome: ".claude-mem", dirs: []string{".claude-mem"}, wantReason: "corrupted"},
		{name: "explicit-missing-legacy-settings", explicitHome: "missing", files: []string{".claude-mem/settings.json"}, wantProbes: 1},
		{name: "explicit-missing-legacy-empty", explicitHome: "missing", dirs: []string{".claude-mem"}, wantReason: "corrupted"},
		{name: "explicit-missing-no-legacy", explicitHome: "missing", wantReason: "not-configured"},
	}
	for _, tt := range tests {
		for _, reachable := range []bool{false, true} {
			t.Run(fmt.Sprintf("%s/reachable=%t", tt.name, reachable), func(t *testing.T) {
				home := t.TempDir()
				t.Setenv("HOME", home)
				t.Setenv("HARNESS_MEM_HOME", "")
				if tt.explicitHome != "" {
					t.Setenv("HARNESS_MEM_HOME", filepath.Join(home, tt.explicitHome))
				}
				for _, dir := range tt.dirs {
					if err := os.MkdirAll(filepath.Join(home, dir), 0700); err != nil {
						t.Fatal(err)
					}
				}
				for _, file := range tt.files {
					path := filepath.Join(home, file)
					if err := os.MkdirAll(filepath.Dir(path), 0700); err != nil {
						t.Fatal(err)
					}
					if err := os.WriteFile(path, []byte(`{}`), 0600); err != nil {
						t.Fatal(err)
					}
				}
				probes := 0
				defer withStubbedDaemonProbe(t, func() error {
					probes++
					if !reachable {
						return fmt.Errorf("connection refused")
					}
					return nil
				})()
				wantReason := tt.wantReason
				if tt.wantProbes > 0 && !reachable {
					wantReason = "daemon-unreachable"
				}
				wantHealthy := wantReason == "" || wantReason == "not-configured"
				wantCode := 0
				if !wantHealthy {
					wantCode = 1
				}
				var stdout, stderr bytes.Buffer
				code := runMemCommand([]string{"health"}, &stdout, &stderr)
				var result memHealthResult
				if err := json.Unmarshal(stdout.Bytes(), &result); err != nil {
					t.Fatalf("invalid JSON output: %v; raw: %s", err, stdout.String())
				}
				t.Logf("output=%s exit=%d probes=%d", strings.TrimSpace(stdout.String()), code, probes)
				if code != wantCode || result.Healthy != wantHealthy || result.Reason != wantReason || probes != tt.wantProbes {
					t.Fatalf("got exit=%d result=%+v probes=%d; want exit=%d healthy=%t reason=%q probes=%d", code, result, probes, wantCode, wantHealthy, wantReason, tt.wantProbes)
				}
			})
		}
	}
}

// captureMemHealth は runMemHealth の stdout と exit code を文字列で返す。
// 内部関数のためシグネチャを直接呼ぶ。
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
