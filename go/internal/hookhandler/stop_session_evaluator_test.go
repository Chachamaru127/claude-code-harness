package hookhandler

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// assertStopOK は出力 JSON の ok フィールドを検証するヘルパー。
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

func assertStopBlocked(t *testing.T, output string, wantReasonParts ...string) {
	t.Helper()
	output = strings.TrimSpace(output)
	if output == "" {
		t.Fatal("expected JSON output, got empty")
	}
	var resp map[string]interface{}
	if err := json.Unmarshal([]byte(output), &resp); err != nil {
		t.Fatalf("invalid JSON output: %v\noutput: %s", err, output)
	}
	if got, _ := resp["decision"].(string); got != "block" {
		t.Fatalf("decision = %q, want block\noutput: %s", got, output)
	}
	reason, _ := resp["reason"].(string)
	if reason == "" {
		t.Fatalf("blocking response must include a reason\noutput: %s", output)
	}
	for _, part := range wantReasonParts {
		if !strings.Contains(reason, part) {
			t.Errorf("reason %q does not contain %q", reason, part)
		}
	}
}

func TestStopSessionEvaluator_EmptyInput(t *testing.T) {
	// Empty input itself is allowed when the isolated project has no WIP task.
	h := &StopSessionEvaluatorHandler{ProjectRoot: t.TempDir()}
	var out bytes.Buffer
	if err := h.Handle(strings.NewReader(""), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	assertStopOK(t, out.String(), true)
}

func TestStopSessionEvaluator_NoStateFile(t *testing.T) {
	// session.json が存在しない場合は ok: true
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

func TestStopSessionEvaluator_StoppedStateDoesNotBypassWIP(t *testing.T) {
	dir := t.TempDir()
	stateDir := filepath.Join(dir, ".claude", "state")
	if err := os.MkdirAll(stateDir, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(stateDir, "session.json"), []byte(`{"state":"stopped"}`), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dir, "Plans.md"), []byte("| 1 | impl foo | DoD | - | cc:WIP |\n"), 0o644); err != nil {
		t.Fatal(err)
	}

	h := &StopSessionEvaluatorHandler{ProjectRoot: dir}
	var out bytes.Buffer
	if err := h.Handle(strings.NewReader(`{}`), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	assertStopBlocked(t, out.String(), "WIP", "1")
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

	// session.json に last_message_length と last_message_hash が書き込まれているか確認
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
	// 平文メッセージが保存されていないことを確認
	content := string(data)
	if strings.Contains(content, "Hello from assistant") {
		t.Error("session.json should not contain the raw message")
	}
}

func TestStopSessionEvaluator_WIPTasksBlock(t *testing.T) {
	dir := t.TempDir()
	stateDir := filepath.Join(dir, ".claude", "state")
	if err := os.MkdirAll(stateDir, 0o755); err != nil {
		t.Fatal(err)
	}
	stateFile := filepath.Join(stateDir, "session.json")
	if err := os.WriteFile(stateFile, []byte(`{"state":"active"}`), 0o644); err != nil {
		t.Fatal(err)
	}

	// Plans.md に cc:WIP タスクを含める
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

	assertStopBlocked(t, out.String(), "WIP", "2")
}

func TestStopSessionEvaluator_WIPBlocksWithoutSessionState(t *testing.T) {
	dir := t.TempDir()
	if err := os.WriteFile(filepath.Join(dir, "Plans.md"), []byte("| 1 | impl foo | DoD | - | cc:WIP |\n"), 0o644); err != nil {
		t.Fatal(err)
	}

	h := &StopSessionEvaluatorHandler{ProjectRoot: dir}
	var out bytes.Buffer
	if err := h.Handle(strings.NewReader(`{}`), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	assertStopBlocked(t, out.String(), "WIP", "1")
}

func TestStopSessionEvaluator_WIPBlocksWithMalformedSessionState(t *testing.T) {
	dir := t.TempDir()
	stateDir := filepath.Join(dir, ".claude", "state")
	if err := os.MkdirAll(stateDir, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(stateDir, "session.json"), []byte(`{invalid`), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dir, "Plans.md"), []byte("| 1 | impl foo | DoD | - | cc:WIP |\n"), 0o644); err != nil {
		t.Fatal(err)
	}

	h := &StopSessionEvaluatorHandler{ProjectRoot: dir}
	var out bytes.Buffer
	if err := h.Handle(strings.NewReader(`{}`), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	assertStopBlocked(t, out.String(), "WIP", "1")
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

	// WIP なし
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

func TestStopSessionEvaluator_WIPMentionOutsideStatusDoesNotBlock(t *testing.T) {
	dir := t.TempDir()
	stateDir := filepath.Join(dir, ".claude", "state")
	if err := os.MkdirAll(stateDir, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(stateDir, "session.json"), []byte(`{"state":"active"}`), 0o644); err != nil {
		t.Fatal(err)
	}
	plansContent := "| 1 | Make Stop block during `cc:WIP` | DoD | - | cc:完了 |\n"
	if err := os.WriteFile(filepath.Join(dir, "Plans.md"), []byte(plansContent), 0o644); err != nil {
		t.Fatal(err)
	}

	h := &StopSessionEvaluatorHandler{ProjectRoot: dir}
	var out bytes.Buffer
	if err := h.Handle(strings.NewReader(`{}`), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	assertStopOK(t, out.String(), true)

	var resp stopSessionResponse
	if err := json.Unmarshal([]byte(strings.TrimSpace(out.String())), &resp); err != nil {
		t.Fatalf("invalid JSON: %v", err)
	}
	if resp.SystemMessage != "" {
		t.Errorf("completed task title must not trigger WIP warning, got: %q", resp.SystemMessage)
	}
}

func TestStopSessionEvaluator_WIPMarkerFormats(t *testing.T) {
	tests := []struct {
		name    string
		content string
		want    int
	}{
		{
			name:    "canonical lowercase table status",
			content: "| 1 | active | DoD | - | cc:wip |\n",
			want:    1,
		},
		{
			name:    "backticked table status with metadata",
			content: "| 1 | active | DoD | - | `cc:wip [owner:worker]` |\n",
			want:    1,
		},
		{
			name: "canonical and legacy heading tasks",
			content: "#### H-1: canonical heading `cc:wip`\n\n" +
				"#### H-2: legacy heading `cc:WIP [owner:worker]`\n",
			want: 2,
		},
		{
			name: "completed task titles and prose are not WIP",
			content: "This prose mentions cc:wip but is not a task.\n" +
				"| 1 | Explain `cc:wip` behavior | DoD | - | cc:done |\n" +
				"#### H-3: Explain legacy `cc:WIP` behavior `cc:done`\n",
			want: 0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			dir := t.TempDir()
			if err := os.WriteFile(filepath.Join(dir, "Plans.md"), []byte(tt.content), 0o644); err != nil {
				t.Fatal(err)
			}
			h := &StopSessionEvaluatorHandler{ProjectRoot: dir}
			if got := h.countWIPTasks(dir); got != tt.want {
				t.Fatalf("countWIPTasks() = %d, want %d\nPlans.md:\n%s", got, tt.want, tt.content)
			}
		})
	}
}

func TestStopSessionEvaluator_StopHookActiveProgressPolicy(t *testing.T) {
	dir := t.TempDir()
	plansPath := filepath.Join(dir, "Plans.md")
	writePlans := func(status string) {
		t.Helper()
		content := "| 1 | active task | DoD | - | " + status + " |\n"
		if err := os.WriteFile(plansPath, []byte(content), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	run := func(payload string) string {
		t.Helper()
		h := &StopSessionEvaluatorHandler{ProjectRoot: dir}
		var out bytes.Buffer
		if err := h.Handle(strings.NewReader(payload), &out); err != nil {
			t.Fatalf("Handle: %v", err)
		}
		return out.String()
	}

	writePlans("cc:wip")
	assertStopBlocked(t, run(`{"stop_hook_active":false}`), "WIP", "1")
	assertStopBlocked(t, run(`{"stop_hook_active":true}`), "cc:done", "blocked")

	writePlans("cc:done")
	assertStopOK(t, run(`{"stop_hook_active":true}`), true)
}
