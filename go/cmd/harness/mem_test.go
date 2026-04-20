package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
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

func TestRunMemHealth_DaemonUnreachable(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	defer withStubbedDaemonProbe(t, func() error { return fmt.Errorf("connection refused") })()

	// ファイルは揃っているが daemon probe が失敗するケース
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

// TestRunMemHealth_NotConfigured は harness-mem 未インストール環境を想定する。
// `~/.claude-mem/` が無い = opt-in 未使用 なので、壊れている扱い (unhealthy) では
// なく監視対象外 (healthy + reason="not-configured") として扱う。
// これにより MonitorHandler 側の `⚠️ harness-mem unhealthy` 警告が
// harness-mem を使っていないユーザーのセッションで誤発火しない。
func TestRunMemHealth_NotConfigured(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
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

func TestRunMemHealth_Corrupted(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)

	// ~/.claude-mem/ は存在するが settings.json も supervisor.json もない
	claudeMem := filepath.Join(home, ".claude-mem")
	if err := os.MkdirAll(claudeMem, 0700); err != nil {
		t.Fatal(err)
	}
	// config ファイルは作成しない

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

// captureMemHealth は runMemHealth の stdout と exit code を文字列で返す。
// 内部関数のためシグネチャを直接呼ぶ。
func captureMemHealth() (string, int) {
	result, code := runMemHealthCheck()
	data, _ := json.Marshal(result)
	return string(data), code
}
