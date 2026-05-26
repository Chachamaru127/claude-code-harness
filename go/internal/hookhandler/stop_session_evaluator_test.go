package hookhandler

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// assertStopOK is a helper that validates the ok field of the output JSON.
func assertStopOK(t *testing.T, output string, wantOK bool) {
	t.Helper()
	output = strings.TrimSpace(output)
	if output == "" {
		t.Fatal("expected JSON output, got empty")
	}
	var resp stopSessionResponse
	if err := json.Unmarshal([]byte(output), &resp); err != nil {
		t.Fatalf("invalid JSON output: %v\noutput: %s", err, output)
	}
	if resp.OK != wantOK {
		t.Errorf("ok = %v, want %v", resp.OK, wantOK)
	}
}

func TestStopSessionEvaluator_EmptyInput(t *testing.T) {
	h := &StopSessionEvaluatorHandler{}
	var out bytes.Buffer
	if err := h.Handle(strings.NewReader(""), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	assertStopOK(t, out.String(), true)
}

func TestStopSessionEvaluator_NoStateFile(t *testing.T) {
	// Should return ok: true when session.json does not exist
	dir := t.TempDir()
	h := &StopSessionEvaluatorHandler{ProjectRoot: dir}
	var out bytes.Buffer
	if err := h.Handle(strings.NewReader(`{}`), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	assertStopOK(t, out.String(), true)
}

func TestStopSessionEvaluator_StoppedState(t *testing.T) {
	dir := t.TempDir()
	stateDir := filepath.Join(dir, ".claude", "state")
	if err := os.MkdirAll(stateDir, 0o755); err != nil {
		t.Fatal(err)
	}
	stateFile := filepath.Join(stateDir, "session.json")
	if err := os.WriteFile(stateFile, []byte(`{"state":"stopped"}`), 0o644); err != nil {
		t.Fatal(err)
	}

	h := &StopSessionEvaluatorHandler{ProjectRoot: dir}
	var out bytes.Buffer
	if err := h.Handle(strings.NewReader(`{}`), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	assertStopOK(t, out.String(), true)
}

func TestStopSessionEvaluator_RecordsLastMessage(t *testing.T) {
	dir := t.TempDir()
	stateDir := filepath.Join(dir, ".claude", "state")
	if err := os.MkdirAll(stateDir, 0o755); err != nil {
		t.Fatal(err)
	}
	stateFile := filepath.Join(stateDir, "session.json")
	if err := os.WriteFile(stateFile, []byte(`{"state":"active"}`), 0o644); err != nil {
		t.Fatal(err)
	}

	h := &StopSessionEvaluatorHandler{ProjectRoot: dir}
	payload := `{"last_assistant_message": "Hello from assistant"}`
	var out bytes.Buffer
	if err := h.Handle(strings.NewReader(payload), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	assertStopOK(t, out.String(), true)

	// Verify that last_message_length and last_message_hash were written to session.json
	data, err := os.ReadFile(stateFile)
	if err != nil {
		t.Fatalf("session.json not readable: %v", err)
	}
	var m map[string]interface{}
	if err := json.Unmarshal(data, &m); err != nil {
		t.Fatalf("session.json is not valid JSON: %v", err)
	}
	if _, ok := m["last_message_length"]; !ok {
		t.Error("session.json missing last_message_length")
	}
	if _, ok := m["last_message_hash"]; !ok {
		t.Error("session.json missing last_message_hash")
	}
	// Verify that the plain-text message was not stored
	content := string(data)
	if strings.Contains(content, "Hello from assistant") {
		t.Error("session.json should not contain the raw message")
	}
}

func TestStopSessionEvaluator_WIPTasksWarning(t *testing.T) {
	dir := t.TempDir()
	stateDir := filepath.Join(dir, ".claude", "state")
	if err := os.MkdirAll(stateDir, 0o755); err != nil {
		t.Fatal(err)
	}
	stateFile := filepath.Join(stateDir, "session.json")
	if err := os.WriteFile(stateFile, []byte(`{"state":"active"}`), 0o644); err != nil {
		t.Fatal(err)
	}

	// Include cc:WIP tasks in Plans.md
	plansContent := `| 1 | impl foo | DoD | - | cc:WIP |
| 2 | impl bar | DoD | - | cc:WIP |
| 3 | impl baz | DoD | - | cc:完了 |
`
	if err := os.WriteFile(filepath.Join(dir, "Plans.md"), []byte(plansContent), 0o644); err != nil {
		t.Fatal(err)
	}

	h := &StopSessionEvaluatorHandler{ProjectRoot: dir}
	var out bytes.Buffer
	if err := h.Handle(strings.NewReader(`{}`), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	output := strings.TrimSpace(out.String())
	var resp stopSessionResponse
	if err := json.Unmarshal([]byte(output), &resp); err != nil {
		t.Fatalf("invalid JSON: %v\noutput: %s", err, output)
	}
	// Should not block (ok: true)
	if !resp.OK {
		t.Errorf("ok = false, want true (WIP should not block stop)")
	}
	// systemMessage should contain a warning
	if !strings.Contains(resp.SystemMessage, "WIP") {
		t.Errorf("systemMessage %q does not contain 'WIP'", resp.SystemMessage)
	}
	if !strings.Contains(resp.SystemMessage, "2") {
		t.Errorf("systemMessage %q does not mention WIP count 2", resp.SystemMessage)
	}
}

func TestStopSessionEvaluator_NoWIPTasksNoWarning(t *testing.T) {
	dir := t.TempDir()
	stateDir := filepath.Join(dir, ".claude", "state")
	if err := os.MkdirAll(stateDir, 0o755); err != nil {
		t.Fatal(err)
	}
	stateFile := filepath.Join(stateDir, "session.json")
	if err := os.WriteFile(stateFile, []byte(`{"state":"active"}`), 0o644); err != nil {
		t.Fatal(err)
	}

	// No WIP tasks
	plansContent := `| 1 | done task | DoD | - | cc:完了 |`
	if err := os.WriteFile(filepath.Join(dir, "Plans.md"), []byte(plansContent), 0o644); err != nil {
		t.Fatal(err)
	}

	h := &StopSessionEvaluatorHandler{ProjectRoot: dir}
	var out bytes.Buffer
	if err := h.Handle(strings.NewReader(`{}`), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	var resp stopSessionResponse
	if err := json.Unmarshal([]byte(strings.TrimSpace(out.String())), &resp); err != nil {
		t.Fatalf("invalid JSON: %v", err)
	}
	if !resp.OK {
		t.Error("ok = false, want true")
	}
	if resp.SystemMessage != "" {
		t.Errorf("systemMessage should be empty, got: %q", resp.SystemMessage)
	}
}
