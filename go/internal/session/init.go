// Package session implements session lifecycle handlers for Claude Code Harness.
//
// Each handler corresponds to a shell script that was previously used:
//   - Init      → scripts/session-init.sh
//   - Cleanup   → scripts/session-cleanup.sh
//   - Monitor   → scripts/session-monitor.sh
//   - Summary   → scripts/session-summary.sh
//
// Handlers read hook JSON from stdin and write the appropriate response to stdout.
package session

import (
	"bufio"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"time"
)

// ---------------------------------------------------------------------------
// InitHandler
// ---------------------------------------------------------------------------

// InitHandler is the SessionStart hook handler.
// Ports the main functionality of session-init.sh to Go:
//  1. Lightweight initialization for subagents
//  2. Session JSON initialization (session.json)
//  3. Task count from Plans.md
//  4. JSON response including additionalContext
//
// Shell version: scripts/session-init.sh
type InitHandler struct {
	// StateDir is the path to the .claude/state directory. Inferred from cwd if empty.
	StateDir string
	// PlansFile is the path to Plans.md. Defaults to projectRoot/Plans.md if empty.
	PlansFile string
}

// initInput is the stdin JSON for the SessionStart hook.
type initInput struct {
	SessionID string `json:"session_id,omitempty"`
	AgentType string `json:"agent_type,omitempty"`
	CWD       string `json:"cwd,omitempty"`
}

// sessionJSON is the schema for session.json (minimal).
type sessionJSON struct {
	SessionID   string `json:"session_id"`
	State       string `json:"state"`
	StartedAt   string `json:"started_at"`
	UpdatedAt   string `json:"updated_at"`
	EventSeq    int    `json:"event_seq"`
	LastEventID string `json:"last_event_id"`
}

// initResponse is the JSON output for the SessionStart hook.
type initResponse struct {
	HookSpecificOutput initHookOutput `json:"hookSpecificOutput"`
}

type initHookOutput struct {
	HookEventName     string `json:"hookEventName"`
	AdditionalContext string `json:"additionalContext"`
}

// Handle reads the SessionStart payload from stdin,
// performs session initialization, and writes a JSON including additionalContext to stdout.
func (h *InitHandler) Handle(r io.Reader, w io.Writer) error {
	data, _ := io.ReadAll(r)

	var inp initInput
	if len(data) > 0 {
		_ = json.Unmarshal(data, &inp)
	}

	// Lightweight initialization for subagents (skip session.json operations)
	if inp.AgentType == "subagent" {
		return writeJSON(w, initResponse{
			HookSpecificOutput: initHookOutput{
				HookEventName:     "SessionStart",
				AdditionalContext: "[subagent] lightweight initialization complete",
			},
		})
	}

	// Resolve project root and state directory
	projectRoot := resolveProjectRoot(inp.CWD)
	stateDir := h.StateDir
	if stateDir == "" {
		stateDir = filepath.Join(projectRoot, ".claude", "state")
	}

	// Create state directory (with symlink check)
	if err := ensureStateDir(stateDir); err != nil {
		// Continue even on error (banner and Plans info will still be output)
		_ = err
	}

	// session.json を初期化（存在しないか停止状態の場合）
	_ = h.initSessionFile(stateDir)

	// session-skills-used.json をリセット
	skillsUsedFile := filepath.Join(stateDir, "session-skills-used.json")
	now := time.Now().UTC().Format(time.RFC3339)
	_ = writeFileAtomic(skillsUsedFile, []byte(fmt.Sprintf(`{"used":[],"session_start":%q}`, now)+"\n"), 0600)

	// Clear SSOT sync flag
	_ = os.Remove(filepath.Join(stateDir, ".ssot-synced-this-session"))
	// Clear work warning flags
	_ = os.Remove(filepath.Join(stateDir, ".work-review-warned"))
	_ = os.Remove(filepath.Join(stateDir, ".ultrawork-review-warned"))

	// Plans.md task count
	plansFile := h.PlansFile
	if plansFile == "" {
		plansFile = filepath.Join(projectRoot, "Plans.md")
	}
	plansInfo := buildPlansInfo(plansFile)

	// Append marker legend
	context := buildAdditionalContext(plansInfo)

	return writeJSON(w, initResponse{
		HookSpecificOutput: initHookOutput{
			HookEventName:     "SessionStart",
			AdditionalContext: context,
		},
	})
}

// initSessionFile initializes session.json.
// Does nothing if the existing file is in an active state (initialized/running/working).
func (h *InitHandler) initSessionFile(stateDir string) error {
	sessionFile := filepath.Join(stateDir, "session.json")

	if isSymlink(sessionFile) {
		return fmt.Errorf("security: symlinked session file: %s", sessionFile)
	}

	// Check the state of any existing file
	if data, err := os.ReadFile(sessionFile); err == nil {
		var s sessionJSON
		if json.Unmarshal(data, &s) == nil {
			// Keep as-is for states other than stopped/completed/failed
			switch s.State {
			case "stopped", "completed", "failed":
				// New initialization required
			default:
				return nil
			}
		}
	}

	// New session initialization
	now := time.Now().UTC().Format(time.RFC3339)
	sessionID := fmt.Sprintf("session-%d", time.Now().Unix())
	s := sessionJSON{
		SessionID:   sessionID,
		State:       "initialized",
		StartedAt:   now,
		UpdatedAt:   now,
		EventSeq:    0,
		LastEventID: "",
	}

	data, err := json.MarshalIndent(s, "", "  ")
	if err != nil {
		return err
	}

	return writeFileAtomic(sessionFile, append(data, '\n'), 0600)
}

// buildPlansInfo reads Plans.md and returns an info string with the WIP/TODO counts.
func buildPlansInfo(plansFile string) string {
	if _, err := os.Stat(plansFile); err != nil {
		return "Plans.md: not found"
	}

	wipCount := countMatches(plansFile, "cc:WIP", "pm:依頼中", "cursor:依頼中")
	todoCount := countMatches(plansFile, "cc:TODO")

	return fmt.Sprintf("Plans.md: in-progress %d / pending %d", wipCount, todoCount)
}

// buildAdditionalContext builds the additionalContext for session initialization.
func buildAdditionalContext(plansInfo string) string {
	var sb strings.Builder
	sb.WriteString("# [claude-code-harness] Session Initialization\n\n")
	sb.WriteString(plansInfo + "\n")
	sb.WriteString("\n## Marker Legend\n")
	sb.WriteString("| Marker | State | Description |\n")
	sb.WriteString("|--------|-------|-------------|\n")
	sb.WriteString("| `cc:TODO` | Pending | Scheduled for execution by Impl (Claude Code) |\n")
	sb.WriteString("| `cc:WIP` | In Progress | Currently being implemented by Impl |\n")
	sb.WriteString("| `cc:blocked` | Blocked | Waiting on a dependent task |\n")
	sb.WriteString("| `pm:依頼中` | Requested by PM | Used in 2-Agent workflows |\n")
	sb.WriteString("\n> **Compatibility**: `cursor:依頼中` / `cursor:確認済` are treated as synonyms for `pm:*`.\n")
	return sb.String()
}

// ---------------------------------------------------------------------------
// Utilities (package-private)
// ---------------------------------------------------------------------------

// writeJSON writes v as JSON to w.
func writeJSON(w io.Writer, v interface{}) error {
	data, err := json.Marshal(v)
	if err != nil {
		return fmt.Errorf("marshaling JSON: %w", err)
	}
	_, err = fmt.Fprintf(w, "%s\n", data)
	return err
}

// resolveProjectRoot infers the project root from the CWD field or environment variables.
func resolveProjectRoot(cwd string) string {
	if cwd != "" {
		return cwd
	}
	if r := os.Getenv("HARNESS_PROJECT_ROOT"); r != "" {
		return r
	}
	if r := os.Getenv("PROJECT_ROOT"); r != "" {
		return r
	}
	root, _ := os.Getwd()
	return root
}

// ensureStateDir creates the state directory.
// Returns an error if the path is a symlink.
func ensureStateDir(stateDir string) error {
	parent := filepath.Dir(stateDir)
	if isSymlink(parent) || isSymlink(stateDir) {
		return fmt.Errorf("security: symlinked state path refused: %s", stateDir)
	}
	return os.MkdirAll(stateDir, 0700)
}

// isSymlink returns whether the given path is a symbolic link.
func isSymlink(path string) bool {
	fi, err := os.Lstat(path)
	if err != nil {
		return false
	}
	return fi.Mode()&os.ModeSymlink != 0
}

// countMatches returns the total number of lines containing any of the given patterns.
func countMatches(filePath string, patterns ...string) int {
	f, err := os.Open(filePath)
	if err != nil {
		return 0
	}
	defer f.Close()

	count := 0
	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		line := scanner.Text()
		for _, p := range patterns {
			if strings.Contains(line, p) {
				count++
				break
			}
		}
	}
	return count
}

// writeFileAtomic atomically writes a file via a temporary file.
func writeFileAtomic(path string, data []byte, perm os.FileMode) error {
	if isSymlink(path) {
		return fmt.Errorf("security: symlinked file refused: %s", path)
	}
	tmp := path + ".tmp"
	if err := os.WriteFile(tmp, data, perm); err != nil {
		return err
	}
	return os.Rename(tmp, path)
}
