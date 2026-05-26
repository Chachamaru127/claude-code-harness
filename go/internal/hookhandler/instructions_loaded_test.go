package hookhandler

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestHandleInstructionsLoaded_EmptyInput(t *testing.T) {
	var out bytes.Buffer
	err := HandleInstructionsLoaded(strings.NewReader(""), &out)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	var result approveOutput
	if jsonErr := json.Unmarshal(out.Bytes(), &result); jsonErr != nil {
		t.Fatalf("invalid JSON output: %v, raw: %s", jsonErr, out.String())
	}
	if result.Decision != "approve" {
		t.Errorf("expected decision=approve, got %q", result.Decision)
	}
	if result.Reason != "InstructionsLoaded: no payload" {
		t.Errorf("expected no payload reason, got %q", result.Reason)
	}
}

func TestHandleInstructionsLoaded_TracksEvent(t *testing.T) {
	tmpDir := t.TempDir()

	// Prepare hooks.json
	hooksDir := filepath.Join(tmpDir, "hooks")
	if mkdirErr := os.MkdirAll(hooksDir, 0o755); mkdirErr != nil {
		t.Fatal(mkdirErr)
	}
	if writeErr := os.WriteFile(
		filepath.Join(hooksDir, "hooks.json"),
		[]byte(`{}`),
		0o644,
	); writeErr != nil {
		t.Fatal(writeErr)
	}

	input := map[string]string{
		"session_id":      "sess-001",
		"cwd":             tmpDir,
		"agent_id":        "agent-xyz",
		"agent_type":      "worker",
		"hook_event_name": "InstructionsLoaded",
	}
	inputData, _ := json.Marshal(input)

	var out bytes.Buffer
	err := HandleInstructionsLoaded(bytes.NewReader(inputData), &out)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	var result approveOutput
	if jsonErr := json.Unmarshal(out.Bytes(), &result); jsonErr != nil {
		t.Fatalf("invalid JSON output: %v, raw: %s", jsonErr, out.String())
	}
	if result.Decision != "approve" {
		t.Errorf("expected decision=approve, got %q", result.Decision)
	}
	if result.Reason != "InstructionsLoaded tracked" {
		t.Errorf("expected 'InstructionsLoaded tracked', got %q", result.Reason)
	}

	// Should be recorded in instructions-loaded.jsonl, not session-events.jsonl
	logFile := filepath.Join(tmpDir, ".claude", "state", "instructions-loaded.jsonl")
	data, readErr := os.ReadFile(logFile)
	if readErr != nil {
		t.Fatalf("log file not created: %v", readErr)
	}

	var entry map[string]string
	if jsonErr := json.Unmarshal([]byte(strings.TrimSpace(string(data))), &entry); jsonErr != nil {
		t.Fatalf("invalid JSONL entry: %v, raw: %s", jsonErr, string(data))
	}

	if entry["event"] != "InstructionsLoaded" {
		t.Errorf("expected event=InstructionsLoaded, got %q", entry["event"])
	}
	if entry["session_id"] != "sess-001" {
		t.Errorf("expected session_id=sess-001, got %q", entry["session_id"])
	}
	if entry["agent_id"] != "agent-xyz" {
		t.Errorf("expected agent_id=agent-xyz, got %q", entry["agent_id"])
	}
	if entry["agent_type"] != "worker" {
		t.Errorf("expected agent_type=worker, got %q", entry["agent_type"])
	}
	if entry["timestamp"] == "" {
		t.Error("expected non-empty timestamp")
	}
}

func TestHandleInstructionsLoaded_HooksNotFound(t *testing.T) {
	tmpDir := t.TempDir()
	// Do not create hooks.json

	input := map[string]string{
		"session_id": "sess-002",
		"cwd":        tmpDir,
	}
	inputData, _ := json.Marshal(input)

	var out bytes.Buffer
	err := HandleInstructionsLoaded(bytes.NewReader(inputData), &out)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	var result approveOutput
	if jsonErr := json.Unmarshal(out.Bytes(), &result); jsonErr != nil {
		t.Fatalf("invalid JSON output: %v", jsonErr)
	}
	if result.Decision != "approve" {
		t.Errorf("expected decision=approve, got %q", result.Decision)
	}
	if !strings.Contains(result.Reason, "hooks.json not found") {
		t.Errorf("expected reason to contain 'hooks.json not found', got %q", result.Reason)
	}
}

func TestHandleInstructionsLoaded_HooksInPluginDir(t *testing.T) {
	tmpDir := t.TempDir()

	// Prepare .claude-plugin/hooks.json (alternative path)
	pluginDir := filepath.Join(tmpDir, ".claude-plugin")
	if mkdirErr := os.MkdirAll(pluginDir, 0o755); mkdirErr != nil {
		t.Fatal(mkdirErr)
	}
	if writeErr := os.WriteFile(
		filepath.Join(pluginDir, "hooks.json"),
		[]byte(`{}`),
		0o644,
	); writeErr != nil {
		t.Fatal(writeErr)
	}

	input := map[string]string{
		"session_id":      "sess-003",
		"cwd":             tmpDir,
		"hook_event_name": "InstructionsLoaded",
	}
	inputData, _ := json.Marshal(input)

	var out bytes.Buffer
	err := HandleInstructionsLoaded(bytes.NewReader(inputData), &out)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	var result approveOutput
	if jsonErr := json.Unmarshal(out.Bytes(), &result); jsonErr != nil {
		t.Fatalf("invalid JSON output: %v", jsonErr)
	}
	// Should return tracked when .claude-plugin/hooks.json is found
	if result.Reason != "InstructionsLoaded tracked" {
		t.Errorf("expected 'InstructionsLoaded tracked', got %q", result.Reason)
	}
}

func TestHandleInstructionsLoaded_EventNameFallback(t *testing.T) {
	tmpDir := t.TempDir()

	// Prepare hooks.json
	hooksDir := filepath.Join(tmpDir, "hooks")
	if mkdirErr := os.MkdirAll(hooksDir, 0o755); mkdirErr != nil {
		t.Fatal(mkdirErr)
	}
	if writeErr := os.WriteFile(
		filepath.Join(hooksDir, "hooks.json"),
		[]byte(`{}`),
		0o644,
	); writeErr != nil {
		t.Fatal(writeErr)
	}

	// Use event_name instead of hook_event_name
	input := map[string]string{
		"session_id": "sess-004",
		"cwd":        tmpDir,
		"event_name": "InstructionsLoaded",
	}
	inputData, _ := json.Marshal(input)

	var out bytes.Buffer
	err := HandleInstructionsLoaded(bytes.NewReader(inputData), &out)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	var result approveOutput
	if jsonErr := json.Unmarshal(out.Bytes(), &result); jsonErr != nil {
		t.Fatalf("invalid JSON output: %v", jsonErr)
	}
	if result.Decision != "approve" {
		t.Errorf("expected decision=approve, got %q", result.Decision)
	}

	// The event name in JSONL should be obtained via fallback
	logFile := filepath.Join(tmpDir, ".claude", "state", "instructions-loaded.jsonl")
	data, readErr := os.ReadFile(logFile)
	if readErr != nil {
		t.Fatalf("log file not created: %v", readErr)
	}
	var entry map[string]string
	if jsonErr := json.Unmarshal([]byte(strings.TrimSpace(string(data))), &entry); jsonErr != nil {
		t.Fatalf("invalid JSONL entry: %v", jsonErr)
	}
	if entry["event"] != "InstructionsLoaded" {
		t.Errorf("expected event=InstructionsLoaded via fallback, got %q", entry["event"])
	}
}

func TestHandleInstructionsLoaded_MultipleEvents(t *testing.T) {
	tmpDir := t.TempDir()

	hooksDir := filepath.Join(tmpDir, "hooks")
	if mkdirErr := os.MkdirAll(hooksDir, 0o755); mkdirErr != nil {
		t.Fatal(mkdirErr)
	}
	if writeErr := os.WriteFile(
		filepath.Join(hooksDir, "hooks.json"),
		[]byte(`{}`),
		0o644,
	); writeErr != nil {
		t.Fatal(writeErr)
	}

	// Multiple calls should append multiple lines to the JSONL file
	for i := 0; i < 3; i++ {
		input := map[string]string{
			"session_id":      "sess-005",
			"cwd":             tmpDir,
			"hook_event_name": "InstructionsLoaded",
		}
		inputData, _ := json.Marshal(input)
		var out bytes.Buffer
		if err := HandleInstructionsLoaded(bytes.NewReader(inputData), &out); err != nil {
			t.Fatalf("call %d: unexpected error: %v", i, err)
		}
	}

	logFile := filepath.Join(tmpDir, ".claude", "state", "instructions-loaded.jsonl")
	data, readErr := os.ReadFile(logFile)
	if readErr != nil {
		t.Fatalf("log file not created: %v", readErr)
	}

	lines := strings.Split(strings.TrimSpace(string(data)), "\n")
	if len(lines) != 3 {
		t.Errorf("expected 3 JSONL lines, got %d: %s", len(lines), string(data))
	}
}
