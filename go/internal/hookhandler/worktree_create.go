package hookhandler

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"time"
)

// worktreeInput is the stdin JSON payload for the WorktreeCreate hook.
type worktreeInput struct {
	SessionID     string `json:"session_id"`
	CWD           string `json:"cwd"`
	HookEventName string `json:"hook_event_name"`
}

// worktreeInfo is written to .claude/state/worktree-info.json.
type worktreeInfo struct {
	WorkerID  string `json:"worker_id"`
	CreatedAt string `json:"created_at"`
	CWD       string `json:"cwd"`
}

// HandleWorktreeCreate ports scripts/hook-handlers/worktree-create.sh.
//
// On WorktreeCreate events it:
//  1. Creates .claude/state/ inside the worktree (cwd).
//  2. Writes worktree-info.json with worker_id, created_at, and cwd.
func HandleWorktreeCreate(in io.Reader, out io.Writer) error {
	data, err := io.ReadAll(in)
	if err != nil || len(data) == 0 {
		return writeWorktreeApprove(out, "WorktreeCreate: no payload")
	}

	var input worktreeInput
	if jsonErr := json.Unmarshal(data, &input); jsonErr != nil {
		return writeWorktreeApprove(out, "WorktreeCreate: no payload")
	}

	cwd, reason, ok := normalizeWorktreeCreateCWD(input.CWD)
	if !ok {
		return writeWorktreeApprove(out, reason)
	}

	stateDir := worktreeStateDir(cwd)
	if mkErr := os.MkdirAll(stateDir, 0o755); mkErr != nil {
		// Non-fatal: log and continue.
		fmt.Fprintf(os.Stderr, "[claude-code-harness] worktree-create: mkdir %s: %v\n", stateDir, mkErr)
	}

	info := worktreeInfo{
		WorkerID:  input.SessionID,
		CreatedAt: time.Now().UTC().Format(time.RFC3339),
		CWD:       cwd,
	}
	infoData, err := json.Marshal(info)
	if err == nil {
		infoPath := filepath.Join(stateDir, "worktree-info.json")
		_ = os.WriteFile(infoPath, append(infoData, '\n'), 0o644)
	}

	return writeWorktreeApprove(out, "WorktreeCreate: initialized worktree state")
}

func normalizeWorktreeCreateCWD(raw string) (string, string, bool) {
	cwd := strings.TrimSpace(raw)
	if cwd == "" {
		return "", "WorktreeCreate: no cwd", false
	}
	if looksLikeHookDecisionJSON(cwd) {
		return "", "WorktreeCreate: invalid cwd", false
	}
	return cwd, "", true
}

func worktreeStateDir(cwd string) string {
	return filepath.Join(cwd, ".claude", "state")
}

func looksLikeHookDecisionJSON(value string) bool {
	trimmed := strings.TrimSpace(value)
	if !strings.HasPrefix(trimmed, "{") {
		return false
	}

	var payload map[string]json.RawMessage
	if err := json.Unmarshal([]byte(trimmed), &payload); err != nil {
		return false
	}
	_, hasDecision := payload["decision"]
	_, hasReason := payload["reason"]
	return hasDecision && hasReason
}

// writeWorktreeApprove writes the standard approve decision JSON.
func writeWorktreeApprove(out io.Writer, reason string) error {
	resp := map[string]string{"decision": "approve", "reason": reason}
	data, err := json.Marshal(resp)
	if err != nil {
		return err
	}
	_, err = fmt.Fprintf(out, "%s\n", data)
	return err
}
