package hookhandler

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"time"
)

// TodoSyncHandler is a PostToolUse hook handler (TodoWrite ↔ Plans.md synchronisation).
// It parses TodoWrite contents, records status counts, and appends to the event log.
// When all tasks are complete in work-mode, it emits an additional warning.
//
// Shell version: scripts/todo-sync.sh
type TodoSyncHandler struct {
	// ProjectRoot is the path to the project root. Falls back to cwd when empty.
	ProjectRoot string
}

// todoSyncInput is the stdin JSON for the PostToolUse hook.
type todoSyncInput struct {
	ToolName  string        `json:"tool_name"`
	ToolInput todoWriteBody `json:"tool_input"`
}

// todoWriteBody is the tool_input for the TodoWrite tool.
type todoWriteBody struct {
	Todos []todoItem `json:"todos"`
}

// todoItem is a single entry in TodoWrite.
type todoItem struct {
	Status string `json:"status"`
}

// todoSyncStateFile is the filename where the sync state is stored.
const todoSyncStateFile = "todo-sync-state.json"

// Handle reads the payload from stdin, then records and notifies TodoWrite state.
func (h *TodoSyncHandler) Handle(r io.Reader, w io.Writer) error {
	data, _ := io.ReadAll(r)

	if len(data) == 0 {
		return nil
	}

	var inp todoSyncInput
	if err := json.Unmarshal(data, &inp); err != nil {
		return nil
	}

	// Skip tools other than TodoWrite
	if inp.ToolName != "TodoWrite" {
		return nil
	}

	todos := inp.ToolInput.Todos
	if len(todos) == 0 {
		return nil
	}

	// Determine the project root.
	// Using resolveProjectRoot() instead of os.Getwd() ensures that
	// .claude/state is resolved correctly even when run from a monorepo subdirectory
	// (supports git rev-parse --show-toplevel).
	projectRoot := h.ProjectRoot
	if projectRoot == "" {
		projectRoot = resolveProjectRoot()
	}

	// Skip when Plans.md does not exist (matches bash version behaviour)
	if resolvePlansPath(projectRoot) == "" {
		return nil
	}

	stateDir := filepath.Join(projectRoot, ".claude", "state")
	_ = os.MkdirAll(stateDir, 0700)

	// Aggregate counts
	var pending, inProgress, done int
	for _, t := range todos {
		switch t.Status {
		case "pending":
			pending++
		case "in_progress":
			inProgress++
		case "completed":
			done++
		}
	}

	// Save sync state file
	h.saveSyncState(stateDir, todos)

	// Append to event log
	h.appendEventLog(stateDir, pending, inProgress, done)

	// Check work-mode warning
	workWarning := h.checkWorkModeWarning(stateDir, pending, inProgress, done)

	// Output sync info as additionalContext
	ctx := fmt.Sprintf("[TodoSync] synced with Plans.md: TODO=%d, WIP=%d, done=%d%s",
		pending, inProgress, done, workWarning)

	return writeTodoSyncOutput(w, ctx)
}

// saveSyncState saves the todos state to a JSON file.
func (h *TodoSyncHandler) saveSyncState(stateDir string, todos []todoItem) {
	type syncState struct {
		SyncedAt string     `json:"synced_at"`
		Todos    []todoItem `json:"todos"`
	}
	state := syncState{
		SyncedAt: time.Now().UTC().Format(time.RFC3339),
		Todos:    todos,
	}
	data, err := json.MarshalIndent(state, "", "  ")
	if err != nil {
		return
	}
	_ = os.WriteFile(filepath.Join(stateDir, todoSyncStateFile), data, 0600)
}

// appendEventLog appends a sync event to the event-log JSONL file.
// Appends only when session.events.jsonl already exists (matches bash behaviour).
func (h *TodoSyncHandler) appendEventLog(stateDir string, pending, inProgress, done int) {
	eventLog := filepath.Join(stateDir, "session.events.jsonl")

	// Append only when the file exists, same as bash
	if _, err := os.Stat(eventLog); err != nil {
		return
	}

	type eventData struct {
		Pending    int `json:"pending"`
		InProgress int `json:"in_progress"`
		Completed  int `json:"completed"`
	}
	type event struct {
		Type string    `json:"type"`
		Ts   string    `json:"ts"`
		Data eventData `json:"data"`
	}
	ev := event{
		Type: "todo.sync",
		Ts:   time.Now().UTC().Format(time.RFC3339),
		Data: eventData{
			Pending:    pending,
			InProgress: inProgress,
			Completed:  done,
		},
	}
	line, err := json.Marshal(ev)
	if err != nil {
		return
	}

	f, err := os.OpenFile(eventLog, os.O_APPEND|os.O_WRONLY, 0600)
	if err != nil {
		return
	}
	defer f.Close()
	_, _ = fmt.Fprintf(f, "%s\n", line)
}

// checkWorkModeWarning returns a warning string when all tasks are complete and work-mode is active.
func (h *TodoSyncHandler) checkWorkModeWarning(stateDir string, pending, inProgress, done int) string {
	// Skip unless all tasks are complete (pending=0, in_progress=0, completed>0)
	if pending != 0 || inProgress != 0 || done == 0 {
		return ""
	}

	// Check for the presence of work-active.json or ultrawork-active.json
	workFile := filepath.Join(stateDir, "work-active.json")
	if _, err := os.Stat(workFile); err != nil {
		workFile = filepath.Join(stateDir, "ultrawork-active.json")
		if _, err2 := os.Stat(workFile); err2 != nil {
			return ""
		}
	}

	// Check review_status
	data, err := os.ReadFile(workFile)
	if err != nil {
		return ""
	}
	var state struct {
		ReviewStatus string `json:"review_status"`
	}
	if err := json.Unmarshal(data, &state); err != nil {
		return ""
	}

	if state.ReviewStatus == "passed" {
		return ""
	}

	return fmt.Sprintf("\n\n⚠️ **pre-work-completion check**: review_status=%s\n→ Obtain APPROVE from /harness-review before completing the work",
		state.ReviewStatus)
}

// writeTodoSyncOutput writes the additionalContext as JSON to w.
func writeTodoSyncOutput(w io.Writer, ctx string) error {
	type hookOutput struct {
		AdditionalContext string `json:"additionalContext"`
	}
	type output struct {
		HookSpecificOutput hookOutput `json:"hookSpecificOutput"`
	}
	out := output{
		HookSpecificOutput: hookOutput{AdditionalContext: ctx},
	}
	data, err := json.Marshal(out)
	if err != nil {
		return fmt.Errorf("marshaling JSON: %w", err)
	}
	_, err = fmt.Fprintf(w, "%s\n", data)
	return err
}
