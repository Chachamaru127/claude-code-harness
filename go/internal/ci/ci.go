// Package ci provides CI status checking and evidence collection functionality.
//
// The CI status checker is called from the PostToolUse (Bash) hook and
// asynchronously checks CI status after git push / gh pr commands.
//
// The evidence collector saves test results and build logs
// to .claude/state/evidence/.
//
// Shell versions:
//   - scripts/hook-handlers/ci-status-checker.sh
//   - scripts/evidence/common.sh
package ci

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

// ---------------------------------------------------------------------------
// Common types
// ---------------------------------------------------------------------------

// HookInput is the hook JSON received from stdin by the CI status checker.
type HookInput struct {
	ToolName     string                 `json:"tool_name,omitempty"`
	ToolInput    map[string]interface{} `json:"tool_input,omitempty"`
	ToolResponse map[string]interface{} `json:"tool_response,omitempty"`
	CWD          string                 `json:"cwd,omitempty"`
	SessionID    string                 `json:"session_id,omitempty"`
}

// CIRun is one entry from gh run list.
type CIRun struct {
	Status     string `json:"status"`
	Conclusion string `json:"conclusion"`
	Name       string `json:"name"`
	URL        string `json:"url"`
}

// CIStatusRecord is the schema for .claude/state/ci-status.json.
type CIStatusRecord struct {
	Timestamp      string `json:"timestamp"`
	TriggerCommand string `json:"trigger_command"`
	Status         string `json:"status"`
	Conclusion     string `json:"conclusion"`
}

// signalEntry is an entry appended to breezing-signals.jsonl.
type signalEntry struct {
	Signal         string `json:"signal"`
	Timestamp      string `json:"timestamp"`
	Conclusion     string `json:"conclusion"`
	TriggerCommand string `json:"trigger_command"`
}

// approveResponse is the hook approve response.
type approveResponse struct {
	Decision          string `json:"decision"`
	Reason            string `json:"reason,omitempty"`
	AdditionalContext string `json:"additionalContext,omitempty"`
}

// ---------------------------------------------------------------------------
// CIStatusHandler — hook ci-status
// ---------------------------------------------------------------------------

// CIStatusHandler is the handler that checks CI status in the PostToolUse hook.
// It receives JSON from stdin and, when a push/PR command is detected,
// starts a CI check in the background.
type CIStatusHandler struct {
	// StateDir is the destination for state files. Auto-resolved if empty.
	StateDir string
	// GHCmd is the path to the gh command. Uses "gh" if empty.
	GHCmd string
	// nowFunc is a time injection function for testing.
	nowFunc func() string
}

// Handle reads a PostToolUse payload from stdin,
// starts a CI check, and returns an approve response.
func (h *CIStatusHandler) Handle(r io.Reader, w io.Writer) error {
	data, err := io.ReadAll(r)
	if err != nil || len(data) == 0 {
		return h.writeApprove(w, "ci-status: no payload", "")
	}

	var inp HookInput
	if err := json.Unmarshal(data, &inp); err != nil {
		return h.writeApprove(w, "ci-status: parse error", "")
	}

	// Get the Bash command
	bashCmd := h.extractBashCommand(inp)
	if !isPushOrPRCommand(bashCmd) {
		return h.writeApprove(w, "ci-status: not a push/PR command", "")
	}

	// Ensure the state directory exists
	stateDir := h.resolveStateDir(inp.CWD)
	if err := ensureDir(stateDir); err != nil {
		return h.writeApprove(w, "ci-status: state dir error", "")
	}

	// Start CI check in the background (do not block the hook)
	go h.checkCIAsync(stateDir, bashCmd)

	// Inject additionalContext if there is a recent CI failure signal
	additionalCtx := h.buildFailureContext(stateDir, bashCmd)

	return h.writeApprove(w, "ci-status: push/PR detected, CI monitoring started", additionalCtx)
}

// extractBashCommand retrieves the Bash command string from a HookInput.
func (h *CIStatusHandler) extractBashCommand(inp HookInput) string {
	if inp.ToolInput == nil {
		return ""
	}
	cmd, _ := inp.ToolInput["command"].(string)
	return cmd
}

// isPushOrPRCommand determines whether the command is a git push / gh pr command.
func isPushOrPRCommand(cmd string) bool {
	patterns := []string{
		"git push",
		"gh pr create",
		"gh pr merge",
		"gh pr edit",
		"gh workflow run",
	}
	for _, p := range patterns {
		if strings.Contains(cmd, p) {
			return true
		}
	}
	return false
}

// resolveStateDir returns the .claude/state path from the project root.
func (h *CIStatusHandler) resolveStateDir(cwd string) string {
	if h.StateDir != "" {
		return h.StateDir
	}

	root := cwd
	if root == "" {
		root, _ = os.Getwd()
	}
	return filepath.Join(root, ".claude", "state")
}

// checkCIAsync polls gh run list to check CI status.
// Runs as a background goroutine.
func (h *CIStatusHandler) checkCIAsync(stateDir, triggerCmd string) {
	ghCmd := h.GHCmd
	if ghCmd == "" {
		ghCmd = "gh"
	}

	// Check that the gh command exists
	if _, err := exec.LookPath(ghCmd); err != nil {
		return
	}

	maxWait := 60 * time.Second
	pollInterval := 10 * time.Second
	deadline := time.Now().Add(maxWait)

	for time.Now().Before(deadline) {
		time.Sleep(pollInterval)

		runs, err := h.fetchLatestRun(ghCmd)
		if err != nil || len(runs) == 0 {
			continue
		}

		run := runs[0]
		if run.Status != "completed" {
			continue
		}

		// Record the result
		h.writeCIStatus(stateDir, triggerCmd, run.Status, run.Conclusion)

		// Write a signal if it failed
		if isFailureConclusion(run.Conclusion) {
			h.writeFailureSignal(stateDir, triggerCmd, run.Conclusion)
		}
		return
	}
}

// fetchLatestRun runs gh run list --limit 1 and returns the results.
func (h *CIStatusHandler) fetchLatestRun(ghCmd string) ([]CIRun, error) {
	// #nosec G204 — ghCmd は "gh" または設定値（テスト用モック）のみ
	out, err := exec.Command(ghCmd, "run", "list", "--limit", "1", "--json", "status,conclusion,name,url").Output()
	if err != nil {
		return nil, fmt.Errorf("gh run list: %w", err)
	}

	var runs []CIRun
	if err := json.Unmarshal(out, &runs); err != nil {
		return nil, fmt.Errorf("parsing gh output: %w", err)
	}
	return runs, nil
}

// isFailureConclusion returns whether the CI result is a failure.
func isFailureConclusion(conclusion string) bool {
	switch conclusion {
	case "failure", "timed_out", "cancelled":
		return true
	}
	return false
}

// writeCIStatus saves the CI status to ci-status.json.
func (h *CIStatusHandler) writeCIStatus(stateDir, triggerCmd, status, conclusion string) {
	rec := CIStatusRecord{
		Timestamp:      h.now(),
		TriggerCommand: triggerCmd,
		Status:         status,
		Conclusion:     conclusion,
	}
	data, err := json.Marshal(rec)
	if err != nil {
		return
	}

	path := filepath.Join(stateDir, "ci-status.json")
	if isSymlink(path) {
		return
	}
	_ = os.WriteFile(path, append(data, '\n'), 0600)
}

// writeFailureSignal appends a CI failure signal to breezing-signals.jsonl.
func (h *CIStatusHandler) writeFailureSignal(stateDir, triggerCmd, conclusion string) {
	entry := signalEntry{
		Signal:         "ci_failure_detected",
		Timestamp:      h.now(),
		Conclusion:     conclusion,
		TriggerCommand: triggerCmd,
	}
	data, err := json.Marshal(entry)
	if err != nil {
		return
	}

	path := filepath.Join(stateDir, "breezing-signals.jsonl")
	if isSymlink(path) || isSymlink(path+".tmp") {
		return
	}

	f, err := os.OpenFile(path, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0600)
	if err != nil {
		return
	}
	defer f.Close()
	_, _ = fmt.Fprintf(f, "%s\n", data)
}

// buildFailureContext checks for recent CI failure signals and returns additionalContext.
func (h *CIStatusHandler) buildFailureContext(stateDir, bashCmd string) string {
	signalsFile := filepath.Join(stateDir, "breezing-signals.jsonl")
	if isSymlink(signalsFile) {
		return ""
	}

	data, err := os.ReadFile(signalsFile)
	if err != nil {
		return ""
	}

	// Search from the end for ci_failure_detected
	lines := splitLines(data)
	for i := len(lines) - 1; i >= 0; i-- {
		line := lines[i]
		if !strings.Contains(line, `"ci_failure_detected"`) {
			continue
		}

		var sig signalEntry
		if err := json.Unmarshal([]byte(line), &sig); err != nil {
			continue
		}

		return fmt.Sprintf(
			"[CI failure detected]\nCI status: %s\nTrigger command: %s\n\n"+
				"Recommended action: spawn /breezing or a ci-cd-fixer agent to automatically repair the CI failure.\n"+
				"  Example: ask ci-cd-fixer \"CI failed. Please check the logs and fix the issue.\"",
			sig.Conclusion, bashCmd,
		)
	}
	return ""
}

// writeApprove writes an approve response to w.
func (h *CIStatusHandler) writeApprove(w io.Writer, reason, additionalCtx string) error {
	resp := approveResponse{
		Decision:          "approve",
		Reason:            reason,
		AdditionalContext: additionalCtx,
	}
	data, err := json.Marshal(resp)
	if err != nil {
		return err
	}
	_, err = fmt.Fprintf(w, "%s\n", data)
	return err
}

// now returns the current time in ISO 8601 UTC format.
func (h *CIStatusHandler) now() string {
	if h.nowFunc != nil {
		return h.nowFunc()
	}
	return time.Now().UTC().Format(time.RFC3339)
}

// ---------------------------------------------------------------------------
// EvidenceCollector — evidence collect
// ---------------------------------------------------------------------------

// CollectOptions holds options for evidence collection.
type CollectOptions struct {
	// ProjectRoot is the project root directory.
	ProjectRoot string
	// Label is the label for the evidence (e.g. "test-run", "build").
	Label string
	// Content is the content string to save.
	Content string
	// ContentFile is the source file path (used instead of Content).
	ContentFile string
}

// CollectResult is the result of evidence collection.
type CollectResult struct {
	// SavedPath is the destination path.
	SavedPath string
	// Label is the label used.
	Label string
	// Timestamp is the collection time.
	Timestamp string
	// Error is an error message (empty if no error).
	Error string
}

// EvidenceCollector collects and saves evidence.
type EvidenceCollector struct {
	// nowFunc is a time injection function for testing.
	nowFunc func() string
}

// Collect saves content to .claude/state/evidence/{label}/{timestamp}.txt.
func (c *EvidenceCollector) Collect(opts CollectOptions) CollectResult {
	ts := c.now()

	label := opts.Label
	if label == "" {
		label = "general"
	}

	// Get the content
	content := opts.Content
	if content == "" && opts.ContentFile != "" {
		data, err := os.ReadFile(opts.ContentFile)
		if err != nil {
			return CollectResult{
				Label:     label,
				Timestamp: ts,
				Error:     fmt.Sprintf("reading content file: %v", err),
			}
		}
		content = string(data)
	}

	if content == "" {
		return CollectResult{
			Label:     label,
			Timestamp: ts,
			Error:     "no content to collect",
		}
	}

	// Create the destination directory
	root := opts.ProjectRoot
	if root == "" {
		root, _ = os.Getwd()
	}

	evidenceDir := filepath.Join(root, ".claude", "state", "evidence", label)
	if err := ensureDir(evidenceDir); err != nil {
		return CollectResult{
			Label:     label,
			Timestamp: ts,
			Error:     fmt.Sprintf("creating evidence dir: %v", err),
		}
	}

	// Use timestamp as filename (replace colons with hyphens to make it filename-safe)
	safeTS := strings.ReplaceAll(ts, ":", "-")
	filename := fmt.Sprintf("%s.txt", safeTS)
	savePath := filepath.Join(evidenceDir, filename)

	if isSymlink(savePath) {
		return CollectResult{
			Label:     label,
			Timestamp: ts,
			Error:     "security: symlinked evidence path refused",
		}
	}

	if err := os.WriteFile(savePath, []byte(content), 0600); err != nil {
		return CollectResult{
			Label:     label,
			Timestamp: ts,
			Error:     fmt.Sprintf("writing evidence file: %v", err),
		}
	}

	return CollectResult{
		SavedPath: savePath,
		Label:     label,
		Timestamp: ts,
	}
}

// CollectFromStdin reads content from stdin and saves it as evidence.
func (c *EvidenceCollector) CollectFromStdin(r io.Reader, w io.Writer, opts CollectOptions) error {
	data, err := io.ReadAll(r)
	if err != nil {
		return fmt.Errorf("reading stdin: %w", err)
	}

	opts.Content = string(data)
	result := c.Collect(opts)

	return json.NewEncoder(w).Encode(result)
}

// now returns the current time in ISO 8601 UTC format.
func (c *EvidenceCollector) now() string {
	if c.nowFunc != nil {
		return c.nowFunc()
	}
	return time.Now().UTC().Format(time.RFC3339)
}

// ---------------------------------------------------------------------------
// Utilities
// ---------------------------------------------------------------------------

// ensureDir creates a directory.
func ensureDir(dir string) error {
	return os.MkdirAll(dir, 0700)
}

// isSymlink returns whether the path is a symbolic link.
func isSymlink(path string) bool {
	fi, err := os.Lstat(path)
	if err != nil {
		return false
	}
	return fi.Mode()&os.ModeSymlink != 0
}

// splitLines splits by newline and excludes empty lines.
func splitLines(data []byte) []string {
	var lines []string
	start := 0
	for i, b := range data {
		if b == '\n' {
			line := string(data[start:i])
			if line != "" {
				lines = append(lines, line)
			}
			start = i + 1
		}
	}
	if start < len(data) {
		line := string(data[start:])
		if line != "" {
			lines = append(lines, line)
		}
	}
	return lines
}
