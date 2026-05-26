package hookhandler

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestHandlePermissionDenied_EmptyInput(t *testing.T) {
	var out bytes.Buffer
	err := HandlePermissionDenied(strings.NewReader(""), &out)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	// Empty input returns nil (no output)
	if out.Len() != 0 {
		t.Errorf("expected no output for empty input, got %q", out.String())
	}
}

func TestHandlePermissionDenied_InvalidJSON(t *testing.T) {
	var out bytes.Buffer
	err := HandlePermissionDenied(strings.NewReader("{bad json}"), &out)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	// Returns approve even on parse failure
	var resp permissionDeniedApproveResponse
	if jsonErr := json.Unmarshal(out.Bytes(), &resp); jsonErr != nil {
		t.Fatalf("invalid JSON output: %v, raw: %s", jsonErr, out.String())
	}
	if resp.Decision != "approve" {
		t.Errorf("expected decision=approve, got %q", resp.Decision)
	}
}

func TestHandlePermissionDenied_NonWorkerAgent(t *testing.T) {
	tmpDir := t.TempDir()
	origDir, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	if err := os.Chdir(tmpDir); err != nil {
		t.Fatal(err)
	}
	defer os.Chdir(origDir)

	t.Setenv("PROJECT_ROOT", tmpDir)
	t.Setenv("CLAUDE_PLUGIN_DATA", "")

	input := `{"tool":"Bash","denied_reason":"not allowed","session_id":"s1","agent_id":"a1","agent_type":"lead"}`
	var out bytes.Buffer
	if err := HandlePermissionDenied(strings.NewReader(input), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	// Non-Workers return approve
	var resp permissionDeniedApproveResponse
	if jsonErr := json.Unmarshal(out.Bytes(), &resp); jsonErr != nil {
		t.Fatalf("invalid JSON output: %v, raw: %s", jsonErr, out.String())
	}
	if resp.Decision != "approve" {
		t.Errorf("expected decision=approve for non-worker agent, got %q", resp.Decision)
	}
}

func TestHandlePermissionDenied_WorkerAgent(t *testing.T) {
	tmpDir := t.TempDir()
	origDir, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	if err := os.Chdir(tmpDir); err != nil {
		t.Fatal(err)
	}
	defer os.Chdir(origDir)

	t.Setenv("PROJECT_ROOT", tmpDir)
	t.Setenv("CLAUDE_PLUGIN_DATA", "")

	input := `{"tool":"Write","denied_reason":"auto mode blocked","session_id":"s2","agent_id":"w1","agent_type":"worker"}`
	var out bytes.Buffer
	if err := HandlePermissionDenied(strings.NewReader(input), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	// Workers return retry=true + systemMessage
	var resp permissionDeniedRetryResponse
	if jsonErr := json.Unmarshal(out.Bytes(), &resp); jsonErr != nil {
		t.Fatalf("invalid JSON output: %v, raw: %s", jsonErr, out.String())
	}
	if !resp.Retry {
		t.Error("expected retry=true for worker agent")
	}
	if !strings.Contains(resp.SystemMessage, "Write") {
		t.Errorf("expected systemMessage to contain tool name 'Write', got %q", resp.SystemMessage)
	}
	if !strings.Contains(resp.SystemMessage, "auto mode") {
		t.Errorf("expected systemMessage to contain denied_reason, got %q", resp.SystemMessage)
	}
}

func TestHandlePermissionDenied_TaskWorkerAgent(t *testing.T) {
	tmpDir := t.TempDir()
	origDir, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	if err := os.Chdir(tmpDir); err != nil {
		t.Fatal(err)
	}
	defer os.Chdir(origDir)

	t.Setenv("PROJECT_ROOT", tmpDir)
	t.Setenv("CLAUDE_PLUGIN_DATA", "")

	input := `{"tool":"Edit","denied_reason":"blocked","session_id":"s3","agent_id":"w2","agent_type":"task-worker"}`
	var out bytes.Buffer
	if err := HandlePermissionDenied(strings.NewReader(input), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	var resp permissionDeniedRetryResponse
	if jsonErr := json.Unmarshal(out.Bytes(), &resp); jsonErr != nil {
		t.Fatalf("invalid JSON output: %v, raw: %s", jsonErr, out.String())
	}
	if !resp.Retry {
		t.Error("expected retry=true for task-worker agent")
	}
}

func TestHandlePermissionDenied_SuffixWorkerAgent(t *testing.T) {
	tmpDir := t.TempDir()
	origDir, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	if err := os.Chdir(tmpDir); err != nil {
		t.Fatal(err)
	}
	defer os.Chdir(origDir)

	t.Setenv("PROJECT_ROOT", tmpDir)
	t.Setenv("CLAUDE_PLUGIN_DATA", "")

	// agent_type with ":worker" suffix
	input := `{"tool":"Bash","denied_reason":"denied","session_id":"s4","agent_id":"w3","agent_type":"claude-code-harness:worker"}`
	var out bytes.Buffer
	if err := HandlePermissionDenied(strings.NewReader(input), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	var resp permissionDeniedRetryResponse
	if jsonErr := json.Unmarshal(out.Bytes(), &resp); jsonErr != nil {
		t.Fatalf("invalid JSON output: %v, raw: %s", jsonErr, out.String())
	}
	if !resp.Retry {
		t.Error("expected retry=true for :worker suffix agent_type")
	}
}

func TestHandlePermissionDenied_LogsToJSONL(t *testing.T) {
	tmpDir := t.TempDir()
	origDir, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	if err := os.Chdir(tmpDir); err != nil {
		t.Fatal(err)
	}
	defer os.Chdir(origDir)

	t.Setenv("PROJECT_ROOT", tmpDir)
	t.Setenv("CLAUDE_PLUGIN_DATA", "")

	input := `{"tool":"Write","denied_reason":"test reason","session_id":"sess-log","agent_id":"agent-log","agent_type":"lead"}`
	var out bytes.Buffer
	if err := HandlePermissionDenied(strings.NewReader(input), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	// JSONL log should be created
	logFile := filepath.Join(tmpDir, ".claude", "state", "permission-denied-events.jsonl")
	data, readErr := os.ReadFile(logFile)
	if readErr != nil {
		t.Fatalf("log file not created: %v", readErr)
	}

	var entry permissionDeniedLogEntry
	if jsonErr := json.Unmarshal(bytes.TrimSpace(data), &entry); jsonErr != nil {
		t.Fatalf("invalid JSONL entry: %v, raw: %s", jsonErr, string(data))
	}

	if entry.Event != "permission_denied" {
		t.Errorf("expected event=permission_denied, got %q", entry.Event)
	}
	if entry.Tool != "Write" {
		t.Errorf("expected tool=Write, got %q", entry.Tool)
	}
	if entry.Reason != "test reason" {
		t.Errorf("expected reason='test reason', got %q", entry.Reason)
	}
	if entry.SessionID != "sess-log" {
		t.Errorf("expected session_id=sess-log, got %q", entry.SessionID)
	}
	if entry.AgentID != "agent-log" {
		t.Errorf("expected agent_id=agent-log, got %q", entry.AgentID)
	}
}

func TestHandlePermissionDenied_ToolNameFallback(t *testing.T) {
	tmpDir := t.TempDir()
	origDir, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	if err := os.Chdir(tmpDir); err != nil {
		t.Fatal(err)
	}
	defer os.Chdir(origDir)

	t.Setenv("PROJECT_ROOT", tmpDir)
	t.Setenv("CLAUDE_PLUGIN_DATA", "")

	// Uses tool_name instead of tool
	input := `{"tool_name":"Read","denied_reason":"reason","session_id":"s5","agent_id":"a5","agent_type":"lead"}`
	var out bytes.Buffer
	if err := HandlePermissionDenied(strings.NewReader(input), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	logFile := filepath.Join(tmpDir, ".claude", "state", "permission-denied-events.jsonl")
	data, readErr := os.ReadFile(logFile)
	if readErr != nil {
		t.Fatalf("log file not created: %v", readErr)
	}

	var entry permissionDeniedLogEntry
	if jsonErr := json.Unmarshal(bytes.TrimSpace(data), &entry); jsonErr != nil {
		t.Fatalf("invalid JSONL entry: %v", jsonErr)
	}
	if entry.Tool != "Read" {
		t.Errorf("expected tool=Read (from tool_name), got %q", entry.Tool)
	}
}

func TestIsWorkerAgentType(t *testing.T) {
	cases := []struct {
		agentType string
		expected  bool
	}{
		{"worker", true},
		{"task-worker", true},
		{"claude-code-harness:worker", true},
		{"my-plugin:worker", true},
		{"lead", false},
		{"reviewer", false},
		{"", false},
		{"worker-extra", false}, // prefix, not suffix
		{"myworker", false},     // no exact match
	}

	for _, tc := range cases {
		got := isWorkerAgentType(tc.agentType)
		if got != tc.expected {
			t.Errorf("isWorkerAgentType(%q) = %v, want %v", tc.agentType, got, tc.expected)
		}
	}
}
