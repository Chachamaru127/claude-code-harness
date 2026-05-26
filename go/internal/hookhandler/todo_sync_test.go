package hookhandler

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestTodoSyncHandler_EmptyInput(t *testing.T) {
	h := &TodoSyncHandler{ProjectRoot: t.TempDir()}

	var out bytes.Buffer
	err := h.Handle(strings.NewReader(""), &out)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	// Empty input produces no output
	if out.Len() != 0 {
		t.Errorf("expected no output, got %q", out.String())
	}
}

func TestTodoSyncHandler_NotTodoWrite(t *testing.T) {
	h := &TodoSyncHandler{ProjectRoot: t.TempDir()}

	input := `{"tool_name":"Read","tool_input":{"file_path":"Plans.md"}}`

	var out bytes.Buffer
	err := h.Handle(strings.NewReader(input), &out)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	// Tools other than TodoWrite are skipped
	if out.Len() != 0 {
		t.Errorf("expected no output for non-TodoWrite tool, got %q", out.String())
	}
}

func TestTodoSyncHandler_EmptyTodos(t *testing.T) {
	h := &TodoSyncHandler{ProjectRoot: t.TempDir()}

	input := `{"tool_name":"TodoWrite","tool_input":{"todos":[]}}`

	var out bytes.Buffer
	err := h.Handle(strings.NewReader(input), &out)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	// Empty todos produce no output
	if out.Len() != 0 {
		t.Errorf("expected no output for empty todos, got %q", out.String())
	}
}

func TestTodoSyncHandler_CountsInOutput(t *testing.T) {
	dir := t.TempDir()
	// Create Plans.md so the handler does not skip
	if err := os.WriteFile(filepath.Join(dir, "Plans.md"), []byte("# Plans\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	h := &TodoSyncHandler{ProjectRoot: dir}

	input := `{"tool_name":"TodoWrite","tool_input":{"todos":[
		{"status":"pending"},
		{"status":"pending"},
		{"status":"in_progress"},
		{"status":"completed"}
	]}}`

	var out bytes.Buffer
	err := h.Handle(strings.NewReader(input), &out)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	// Verify the additionalContext in the JSON output
	type hookOutput struct {
		AdditionalContext string `json:"additionalContext"`
	}
	type output struct {
		HookSpecificOutput hookOutput `json:"hookSpecificOutput"`
	}
	var result output
	if err := json.Unmarshal(bytes.TrimRight(out.Bytes(), "\n"), &result); err != nil {
		t.Fatalf("invalid JSON: %s", out.String())
	}

	ctx := result.HookSpecificOutput.AdditionalContext
	if !strings.Contains(ctx, "TODO=2") {
		t.Errorf("expected TODO=2 in context, got %q", ctx)
	}
	if !strings.Contains(ctx, "WIP=1") {
		t.Errorf("expected WIP=1 in context, got %q", ctx)
	}
	if !strings.Contains(ctx, "done=1") {
		t.Errorf("expected done=1 in context, got %q", ctx)
	}
}

func TestTodoSyncHandler_SavesSyncState(t *testing.T) {
	dir := t.TempDir()
	// Create Plans.md so the handler does not skip
	if err := os.WriteFile(filepath.Join(dir, "Plans.md"), []byte("# Plans\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	h := &TodoSyncHandler{ProjectRoot: dir}

	input := `{"tool_name":"TodoWrite","tool_input":{"todos":[
		{"status":"pending"},
		{"status":"completed"}
	]}}`

	var out bytes.Buffer
	_ = h.Handle(strings.NewReader(input), &out)

	// Verify that the state file was created
	stateFile := filepath.Join(dir, ".claude", "state", todoSyncStateFile)
	data, err := os.ReadFile(stateFile)
	if err != nil {
		t.Fatalf("sync state file not created: %v", err)
	}

	var state struct {
		SyncedAt string     `json:"synced_at"`
		Todos    []todoItem `json:"todos"`
	}
	if err := json.Unmarshal(data, &state); err != nil {
		t.Fatalf("invalid state file JSON: %s", string(data))
	}
	if state.SyncedAt == "" {
		t.Errorf("expected synced_at to be set")
	}
	if len(state.Todos) != 2 {
		t.Errorf("expected 2 todos in state, got %d", len(state.Todos))
	}
}

func TestTodoSyncHandler_AppendsEventLog(t *testing.T) {
	dir := t.TempDir()
	// Create Plans.md so the handler does not skip
	if err := os.WriteFile(filepath.Join(dir, "Plans.md"), []byte("# Plans\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	h := &TodoSyncHandler{ProjectRoot: dir}

	stateDir := filepath.Join(dir, ".claude", "state")
	_ = os.MkdirAll(stateDir, 0700)

	// Pre-create session.events.jsonl (appended only when it exists)
	eventLog := filepath.Join(stateDir, "session.events.jsonl")
	_ = os.WriteFile(eventLog, []byte(""), 0600)

	input := `{"tool_name":"TodoWrite","tool_input":{"todos":[
		{"status":"pending"},
		{"status":"completed"}
	]}}`

	var out bytes.Buffer
	_ = h.Handle(strings.NewReader(input), &out)

	// Verify that the event was appended to the event log
	data, err := os.ReadFile(eventLog)
	if err != nil {
		t.Fatalf("event log not found: %v", err)
	}

	var event struct {
		Type string `json:"type"`
		Data struct {
			Pending   int `json:"pending"`
			Completed int `json:"completed"`
		} `json:"data"`
	}
	if err := json.Unmarshal(bytes.TrimRight(data, "\n"), &event); err != nil {
		t.Fatalf("invalid event JSON: %s", string(data))
	}
	if event.Type != "todo.sync" {
		t.Errorf("expected event type=todo.sync, got %q", event.Type)
	}
	if event.Data.Pending != 1 {
		t.Errorf("expected pending=1, got %d", event.Data.Pending)
	}
	if event.Data.Completed != 1 {
		t.Errorf("expected completed=1, got %d", event.Data.Completed)
	}
}

func TestTodoSyncHandler_NoEventLog_NoError(t *testing.T) {
	dir := t.TempDir()
	// Create Plans.md so the handler does not skip
	if err := os.WriteFile(filepath.Join(dir, "Plans.md"), []byte("# Plans\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	h := &TodoSyncHandler{ProjectRoot: dir}

	// When session.events.jsonl does not exist, skip gracefully (no error)
	input := `{"tool_name":"TodoWrite","tool_input":{"todos":[
		{"status":"completed"}
	]}}`

	var out bytes.Buffer
	err := h.Handle(strings.NewReader(input), &out)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
}

func TestTodoSyncHandler_WorkModeWarning_AllComplete(t *testing.T) {
	dir := t.TempDir()
	// Create Plans.md so the handler does not skip
	if err := os.WriteFile(filepath.Join(dir, "Plans.md"), []byte("# Plans\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	h := &TodoSyncHandler{ProjectRoot: dir}

	stateDir := filepath.Join(dir, ".claude", "state")
	_ = os.MkdirAll(stateDir, 0700)

	// Create work-active.json (review_status=pending)
	workFile := filepath.Join(stateDir, "work-active.json")
	_ = os.WriteFile(workFile, []byte(`{"review_status":"pending"}`), 0600)

	// All tasks complete (pending=0, in_progress=0, completed>0)
	input := `{"tool_name":"TodoWrite","tool_input":{"todos":[
		{"status":"completed"},
		{"status":"completed"}
	]}}`

	var out bytes.Buffer
	_ = h.Handle(strings.NewReader(input), &out)

	type hookOutput struct {
		AdditionalContext string `json:"additionalContext"`
	}
	type output struct {
		HookSpecificOutput hookOutput `json:"hookSpecificOutput"`
	}
	var result output
	_ = json.Unmarshal(bytes.TrimRight(out.Bytes(), "\n"), &result)

	ctx := result.HookSpecificOutput.AdditionalContext
	if !strings.Contains(ctx, "harness-review") {
		t.Errorf("expected harness-review warning in context, got %q", ctx)
	}
}

func TestTodoSyncHandler_WorkModeWarning_ReviewPassed(t *testing.T) {
	dir := t.TempDir()
	// Create Plans.md so the handler does not skip
	if err := os.WriteFile(filepath.Join(dir, "Plans.md"), []byte("# Plans\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	h := &TodoSyncHandler{ProjectRoot: dir}

	stateDir := filepath.Join(dir, ".claude", "state")
	_ = os.MkdirAll(stateDir, 0700)

	// No warning when review_status=passed
	workFile := filepath.Join(stateDir, "work-active.json")
	_ = os.WriteFile(workFile, []byte(`{"review_status":"passed"}`), 0600)

	input := `{"tool_name":"TodoWrite","tool_input":{"todos":[
		{"status":"completed"}
	]}}`

	var out bytes.Buffer
	_ = h.Handle(strings.NewReader(input), &out)

	type hookOutput struct {
		AdditionalContext string `json:"additionalContext"`
	}
	type output struct {
		HookSpecificOutput hookOutput `json:"hookSpecificOutput"`
	}
	var result output
	_ = json.Unmarshal(bytes.TrimRight(out.Bytes(), "\n"), &result)

	ctx := result.HookSpecificOutput.AdditionalContext
	if strings.Contains(ctx, "harness-review") {
		t.Errorf("expected no warning when review_status=passed, got %q", ctx)
	}
}

func TestTodoSyncHandler_WorkModeWarning_StillHasPending(t *testing.T) {
	dir := t.TempDir()
	// Create Plans.md so the handler does not skip
	if err := os.WriteFile(filepath.Join(dir, "Plans.md"), []byte("# Plans\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	h := &TodoSyncHandler{ProjectRoot: dir}

	stateDir := filepath.Join(dir, ".claude", "state")
	_ = os.MkdirAll(stateDir, 0700)

	workFile := filepath.Join(stateDir, "work-active.json")
	_ = os.WriteFile(workFile, []byte(`{"review_status":"pending"}`), 0600)

	// No warning when there are pending tasks
	input := `{"tool_name":"TodoWrite","tool_input":{"todos":[
		{"status":"pending"},
		{"status":"completed"}
	]}}`

	var out bytes.Buffer
	_ = h.Handle(strings.NewReader(input), &out)

	type hookOutput struct {
		AdditionalContext string `json:"additionalContext"`
	}
	type output struct {
		HookSpecificOutput hookOutput `json:"hookSpecificOutput"`
	}
	var result output
	_ = json.Unmarshal(bytes.TrimRight(out.Bytes(), "\n"), &result)

	ctx := result.HookSpecificOutput.AdditionalContext
	if strings.Contains(ctx, "harness-review") {
		t.Errorf("expected no warning with pending todos, got %q", ctx)
	}
}

// TestTodoSyncHandler_SkipWhenNoPlansFile verifies that when Plans.md does not exist
// the handler skips without producing output (matches bash version behaviour).
func TestTodoSyncHandler_SkipWhenNoPlansFile(t *testing.T) {
	dir := t.TempDir()
	// Intentionally do not create Plans.md
	h := &TodoSyncHandler{ProjectRoot: dir}

	input := `{"tool_name":"TodoWrite","tool_input":{"todos":[
		{"status":"pending"},
		{"status":"completed"}
	]}}`

	var out bytes.Buffer
	err := h.Handle(strings.NewReader(input), &out)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	// When Plans.md is absent, skip without any output
	if out.Len() != 0 {
		t.Errorf("expected no output when Plans.md does not exist, got: %s", out.String())
	}
}

// TestTodoSyncHandler_UsesResolveProjectRoot verifies that when ProjectRoot is empty,
// resolveProjectRoot() is used and the HARNESS_PROJECT_ROOT env variable is consulted.
// If os.Getwd() were used instead, .claude/state would not be found when cwd != project root,
// and no state file would be written — this test validates the resolution.
func TestTodoSyncHandler_UsesResolveProjectRoot(t *testing.T) {
	dir := t.TempDir()
	// Set HARNESS_PROJECT_ROOT (resolveProjectRoot uses this with highest priority)
	t.Setenv("HARNESS_PROJECT_ROOT", dir)

	// Create Plans.md
	if err := os.WriteFile(filepath.Join(dir, "Plans.md"), []byte("# Plans\n"), 0o644); err != nil {
		t.Fatal(err)
	}

	// Leave ProjectRoot empty to route through resolveProjectRoot()
	h := &TodoSyncHandler{ProjectRoot: ""}

	input := `{"tool_name":"TodoWrite","tool_input":{"todos":[
		{"status":"pending"},
		{"status":"completed"}
	]}}`

	var out bytes.Buffer
	if err := h.Handle(strings.NewReader(input), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	// Processing should succeed and produce output (dir was resolved by resolveProjectRoot)
	if out.Len() == 0 {
		t.Errorf("expected output when HARNESS_PROJECT_ROOT is set, got none")
	}

	// State file should be created under HARNESS_PROJECT_ROOT
	stateFile := filepath.Join(dir, ".claude", "state", todoSyncStateFile)
	if _, err := os.Stat(stateFile); err != nil {
		t.Errorf("sync state file should be created at %s: %v", stateFile, err)
	}
}

// TestTodoSyncHandler_CustomPlansDirectory verifies that when plansDirectory is configured,
// processing succeeds when Plans.md exists in the custom directory.
func TestTodoSyncHandler_CustomPlansDirectory(t *testing.T) {
	dir := t.TempDir()

	// Create config file (plansDirectory: work)
	configContent := "plansDirectory: work\n"
	if err := os.WriteFile(filepath.Join(dir, harnessConfigFileName), []byte(configContent), 0o644); err != nil {
		t.Fatal(err)
	}

	// Create work/Plans.md
	workDir := filepath.Join(dir, "work")
	if err := os.MkdirAll(workDir, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(workDir, "Plans.md"), []byte("# Plans\n"), 0o644); err != nil {
		t.Fatal(err)
	}

	h := &TodoSyncHandler{ProjectRoot: dir}

	input := `{"tool_name":"TodoWrite","tool_input":{"todos":[
		{"status":"pending"},
		{"status":"completed"}
	]}}`

	var out bytes.Buffer
	if err := h.Handle(strings.NewReader(input), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	// Processing should succeed and produce output (Plans.md exists in the custom dir)
	if out.Len() == 0 {
		t.Errorf("expected output when custom-dir Plans.md exists, got none")
	}
}
