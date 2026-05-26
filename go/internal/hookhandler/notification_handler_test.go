package hookhandler

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestHandleNotification_EmptyInput(t *testing.T) {
	var out bytes.Buffer
	err := HandleNotification(strings.NewReader(""), &out)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	// Notification handler produces no output for empty input
	if out.Len() != 0 {
		t.Errorf("expected no output for empty input, got %q", out.String())
	}
}

func TestHandleNotification_InvalidJSON(t *testing.T) {
	var out bytes.Buffer
	err := HandleNotification(strings.NewReader("{invalid json}"), &out)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	// No output even on parse failure (normal exit)
	if out.Len() != 0 {
		t.Errorf("expected no output for invalid JSON, got %q", out.String())
	}
}

func TestHandleNotification_BasicEvent(t *testing.T) {
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

	input := `{"notification_type":"auth_success","session_id":"sess-001","agent_type":"worker"}`
	var out bytes.Buffer
	if err := HandleNotification(strings.NewReader(input), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	// JSONL log should be created
	logFile := filepath.Join(tmpDir, ".claude", "state", "notification-events.jsonl")
	data, readErr := os.ReadFile(logFile)
	if readErr != nil {
		t.Fatalf("log file not created: %v", readErr)
	}

	var entry notificationLogEntry
	if jsonErr := json.Unmarshal(bytes.TrimSpace(data), &entry); jsonErr != nil {
		t.Fatalf("invalid JSONL entry: %v, raw: %s", jsonErr, string(data))
	}

	if entry.Event != "notification" {
		t.Errorf("expected event=notification, got %q", entry.Event)
	}
	if entry.NotificationType != "auth_success" {
		t.Errorf("expected notification_type=auth_success, got %q", entry.NotificationType)
	}
	if entry.SessionID != "sess-001" {
		t.Errorf("expected session_id=sess-001, got %q", entry.SessionID)
	}
	if entry.AgentType != "worker" {
		t.Errorf("expected agent_type=worker, got %q", entry.AgentType)
	}
	if entry.Timestamp == "" {
		t.Error("expected non-empty timestamp")
	}
}

func TestHandleNotification_TypeFallback(t *testing.T) {
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

	// Falls back to type field when notification_type is absent
	input := `{"type":"idle_prompt","session_id":"sess-002"}`
	var out bytes.Buffer
	if err := HandleNotification(strings.NewReader(input), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	logFile := filepath.Join(tmpDir, ".claude", "state", "notification-events.jsonl")
	data, readErr := os.ReadFile(logFile)
	if readErr != nil {
		t.Fatalf("log file not created: %v", readErr)
	}

	var entry notificationLogEntry
	if jsonErr := json.Unmarshal(bytes.TrimSpace(data), &entry); jsonErr != nil {
		t.Fatalf("invalid JSONL entry: %v", jsonErr)
	}
	if entry.NotificationType != "idle_prompt" {
		t.Errorf("expected notification_type=idle_prompt (from type field), got %q", entry.NotificationType)
	}
}

func TestHandleNotification_MatcherFallback(t *testing.T) {
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

	// Falls back to matcher field when neither notification_type nor type is present
	input := `{"matcher":"permission_prompt","session_id":"sess-003","agent_type":"task-worker"}`
	var out bytes.Buffer
	if err := HandleNotification(strings.NewReader(input), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	logFile := filepath.Join(tmpDir, ".claude", "state", "notification-events.jsonl")
	data, readErr := os.ReadFile(logFile)
	if readErr != nil {
		t.Fatalf("log file not created: %v", readErr)
	}

	var entry notificationLogEntry
	if jsonErr := json.Unmarshal(bytes.TrimSpace(data), &entry); jsonErr != nil {
		t.Fatalf("invalid JSONL entry: %v", jsonErr)
	}
	if entry.NotificationType != "permission_prompt" {
		t.Errorf("expected notification_type=permission_prompt (from matcher), got %q", entry.NotificationType)
	}
}

func TestHandleNotification_RotatesAtLimit(t *testing.T) {
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

	// Write 501 dummy entries to the log file
	stateDir := filepath.Join(tmpDir, ".claude", "state")
	if err := os.MkdirAll(stateDir, 0o700); err != nil {
		t.Fatal(err)
	}
	logFile := filepath.Join(stateDir, "notification-events.jsonl")
	f, err := os.Create(logFile)
	if err != nil {
		t.Fatal(err)
	}
	for i := 0; i < 501; i++ {
		f.WriteString(`{"event":"notification","notification_type":"dummy"}` + "\n")
	}
	f.Close()

	input := `{"notification_type":"auth_success","session_id":"sess-rotate"}`
	var out bytes.Buffer
	if err := HandleNotification(strings.NewReader(input), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	data, readErr := os.ReadFile(logFile)
	if readErr != nil {
		t.Fatalf("log file not found: %v", readErr)
	}
	lines := strings.Split(strings.TrimRight(string(data), "\n"), "\n")
	// Should be 401 lines (400 kept + 1 new entry)
	if len(lines) > 401 {
		t.Errorf("expected ≤401 lines after rotation, got %d", len(lines))
	}
}

func TestHandleNotification_NoOutput(t *testing.T) {
	// Notification handler writes nothing to stdout when HARNESS_TERMINAL_NOTIFY is unset
	// (backward-compatibility test for opt-in behaviour)
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
	t.Setenv("HARNESS_TERMINAL_NOTIFY", "")

	input := `{"notification_type":"auth_success","session_id":"sess-out"}`
	var out bytes.Buffer
	if err := HandleNotification(strings.NewReader(input), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	// Nothing should be written to stdout (equivalent to bash exit 0)
	if out.Len() != 0 {
		t.Errorf("notification handler should produce no stdout output when env unset, got %q", out.String())
	}
}

// TestHandleNotification_TerminalSequenceEmit verifies that when
// HARNESS_TERMINAL_NOTIFY=osc9 and a permission_prompt is received,
// a JSON response containing terminalSequence is emitted (CC 2.1.141+ Phase 69).
func TestHandleNotification_TerminalSequenceEmit(t *testing.T) {
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
	t.Setenv("HARNESS_TERMINAL_NOTIFY", "osc9")

	input := `{"notification_type":"permission_prompt","agent_type":"worker","session_id":"s1"}`
	var out bytes.Buffer
	if err := HandleNotification(strings.NewReader(input), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if out.Len() == 0 {
		t.Fatal("expected JSON output when HARNESS_TERMINAL_NOTIFY=osc9 + permission_prompt, got none")
	}

	var resp map[string]interface{}
	if jsonErr := json.Unmarshal(out.Bytes(), &resp); jsonErr != nil {
		t.Fatalf("invalid JSON output: %v, raw=%q", jsonErr, out.String())
	}

	if resp["decision"] != "approve" {
		t.Errorf("expected decision=approve, got %v", resp["decision"])
	}
	seq, ok := resp["terminalSequence"].(string)
	if !ok || seq == "" {
		t.Errorf("expected terminalSequence string in response, got %v (type %T)", resp["terminalSequence"], resp["terminalSequence"])
	}
	// OSC 9 sequence has the form ESC ]9; ... BEL
	if !strings.HasPrefix(seq, "\x1b]9;") || !strings.HasSuffix(seq, "\x07") {
		t.Errorf("terminalSequence does not match OSC 9 shape: %q", seq)
	}
}

// TestHandleNotification_TerminalSequence_UnknownType verifies that
// an unknown notification_type does not emit a terminalSequence.
func TestHandleNotification_TerminalSequence_UnknownType(t *testing.T) {
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
	t.Setenv("HARNESS_TERMINAL_NOTIFY", "osc9")

	input := `{"notification_type":"unknown_xyz","session_id":"s1"}`
	var out bytes.Buffer
	if err := HandleNotification(strings.NewReader(input), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	// Unknown type should be silent
	if out.Len() != 0 {
		t.Errorf("unknown notification_type should not emit terminalSequence, got %q", out.String())
	}
}

// TestHandleNotification_TerminalSequence_AllTypes verifies that
// all four known types (permission_prompt / elicitation_dialog / idle_prompt / auth_success)
// emit a terminalSequence.
func TestHandleNotification_TerminalSequence_AllTypes(t *testing.T) {
	knownTypes := []string{"permission_prompt", "elicitation_dialog", "idle_prompt", "auth_success"}
	for _, nt := range knownTypes {
		t.Run(nt, func(t *testing.T) {
			tmpDir := t.TempDir()
			origDir, _ := os.Getwd()
			if err := os.Chdir(tmpDir); err != nil {
				t.Fatal(err)
			}
			defer os.Chdir(origDir)
			t.Setenv("PROJECT_ROOT", tmpDir)
			t.Setenv("CLAUDE_PLUGIN_DATA", "")
			t.Setenv("HARNESS_TERMINAL_NOTIFY", "osc9")

			input := `{"notification_type":"` + nt + `","agent_type":"worker"}`
			var out bytes.Buffer
			if err := HandleNotification(strings.NewReader(input), &out); err != nil {
				t.Fatalf("err: %v", err)
			}
			if out.Len() == 0 {
				t.Fatalf("expected terminalSequence for %s, got nothing", nt)
			}
			var resp map[string]interface{}
			if err := json.Unmarshal(out.Bytes(), &resp); err != nil {
				t.Fatalf("invalid JSON: %v", err)
			}
			if _, ok := resp["terminalSequence"]; !ok {
				t.Errorf("type=%s: terminalSequence missing", nt)
			}
		})
	}
}
