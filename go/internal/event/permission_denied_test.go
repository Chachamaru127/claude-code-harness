package event

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestPermissionDeniedHandler_EmptyInput(t *testing.T) {
	dir := t.TempDir()
	h := &PermissionDeniedHandler{StateDir: dir}

	var buf bytes.Buffer
	if err := h.Handle(strings.NewReader(""), &buf); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	// Empty input produces no output
	if buf.Len() != 0 {
		t.Errorf("expected empty output for empty input, got: %s", buf.String())
	}
}

func TestPermissionDeniedHandler_NonWorkerApprove(t *testing.T) {
	dir := t.TempDir()
	h := &PermissionDeniedHandler{StateDir: dir}

	input := `{
		"tool": "Bash",
		"denied_reason": "git push not allowed",
		"session_id": "sess-1",
		"agent_id": "agent-1",
		"agent_type": "reviewer"
	}`
	var buf bytes.Buffer
	if err := h.Handle(strings.NewReader(input), &buf); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	var resp ApproveResponse
	if err := json.Unmarshal(bytes.TrimSpace(buf.Bytes()), &resp); err != nil {
		t.Fatalf("invalid JSON output: %v\n%s", err, buf.String())
	}
	if resp.Decision != "approve" {
		t.Errorf("expected approve for non-worker, got: %s", resp.Decision)
	}
}

func TestPermissionDeniedHandler_WorkerRetry(t *testing.T) {
	dir := t.TempDir()
	h := &PermissionDeniedHandler{StateDir: dir}

	input := `{
		"tool": "Bash",
		"denied_reason": "rm -rf not allowed",
		"session_id": "sess-2",
		"agent_id": "agent-2",
		"agent_type": "worker"
	}`
	var buf bytes.Buffer
	if err := h.Handle(strings.NewReader(input), &buf); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	var resp RetryResponse
	if err := json.Unmarshal(bytes.TrimSpace(buf.Bytes()), &resp); err != nil {
		t.Fatalf("invalid JSON output: %v\n%s", err, buf.String())
	}
	if !resp.Retry {
		t.Error("expected retry=true for worker")
	}
	if resp.SystemMessage == "" {
		t.Error("expected systemMessage for worker")
	}
	if !strings.Contains(resp.SystemMessage, "Bash") {
		t.Errorf("expected tool name in system message, got: %s", resp.SystemMessage)
	}
}

func TestPermissionDeniedHandler_TaskWorkerRetry(t *testing.T) {
	dir := t.TempDir()
	h := &PermissionDeniedHandler{StateDir: dir}

	input := `{
		"tool_name": "Edit",
		"denied_reason": "file write blocked",
		"agent_type": "task-worker"
	}`
	var buf bytes.Buffer
	if err := h.Handle(strings.NewReader(input), &buf); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	var resp RetryResponse
	if err := json.Unmarshal(bytes.TrimSpace(buf.Bytes()), &resp); err != nil {
		t.Fatalf("invalid JSON output: %v\n%s", err, buf.String())
	}
	if !resp.Retry {
		t.Errorf("expected retry=true for task-worker, got retry=%v", resp.Retry)
	}
}

func TestPermissionDeniedHandler_SuffixWorkerRetry(t *testing.T) {
	dir := t.TempDir()
	h := &PermissionDeniedHandler{StateDir: dir}

	// ":worker" suffix
	input := `{
		"tool": "Write",
		"denied_reason": "blocked",
		"agent_type": "breezing:worker"
	}`
	var buf bytes.Buffer
	if err := h.Handle(strings.NewReader(input), &buf); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	var resp RetryResponse
	if err := json.Unmarshal(bytes.TrimSpace(buf.Bytes()), &resp); err != nil {
		t.Fatalf("invalid JSON output: %v\n%s", err, buf.String())
	}
	if !resp.Retry {
		t.Errorf("expected retry=true for :worker suffix, got retry=%v", resp.Retry)
	}
}

func TestPermissionDeniedHandler_LogsEvent(t *testing.T) {
	dir := t.TempDir()
	h := &PermissionDeniedHandler{StateDir: dir}

	input := `{
		"tool": "Bash",
		"denied_reason": "forbidden command",
		"session_id": "sess-log",
		"agent_id": "agent-log",
		"agent_type": "reviewer"
	}`
	var buf bytes.Buffer
	_ = h.Handle(strings.NewReader(input), &buf)

	logFile := filepath.Join(dir, "permission-denied.jsonl")
	data, err := os.ReadFile(logFile)
	if err != nil {
		t.Fatalf("expected log file, got error: %v", err)
	}

	var entry permissionDeniedLogEntry
	if err := json.Unmarshal(bytes.TrimSpace(data), &entry); err != nil {
		t.Fatalf("invalid log entry: %v\n%s", err, string(data))
	}
	if entry.Event != "permission_denied" {
		t.Errorf("expected event=permission_denied, got: %s", entry.Event)
	}
	if entry.Tool != "Bash" {
		t.Errorf("expected tool=Bash, got: %s", entry.Tool)
	}
	if entry.Reason != "forbidden command" {
		t.Errorf("expected reason=forbidden command, got: %s", entry.Reason)
	}
	if entry.SessionID != "sess-log" {
		t.Errorf("expected session_id=sess-log, got: %s", entry.SessionID)
	}
}

func TestPermissionDeniedHandler_ToolNameFallback(t *testing.T) {
	dir := t.TempDir()
	h := &PermissionDeniedHandler{StateDir: dir}

	// Using the tool_name (snake_case) field
	input := `{"tool_name": "Glob", "denied_reason": "blocked", "agent_type": "solo"}`
	var buf bytes.Buffer
	if err := h.Handle(strings.NewReader(input), &buf); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	logFile := filepath.Join(dir, "permission-denied.jsonl")
	data, err := os.ReadFile(logFile)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(string(data), "Glob") {
		t.Errorf("expected 'Glob' in log, got: %s", string(data))
	}
}
