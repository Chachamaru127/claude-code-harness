package hookhandler

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"
	"time"
)

// CIStatusCheckerHandler is the PostToolUse (Bash) hook handler for CI status checking.
// Detects git push / gh pr commands and checks CI status synchronously.
// Assumes an async: true hook (CC keeps the process alive for up to 600 s); the runner is
// invoked as a blocking call rather than in a goroutine.
// On CI failure, recommends the /ci skill via additionalContext.
//
// Shell version: scripts/hook-handlers/ci-status-checker.sh
type CIStatusCheckerHandler struct {
	// ProjectRoot is the path to the project root. Falls back to cwd when empty.
	ProjectRoot string

	// GHCommand is the path to the gh command (for testing). Searched on PATH when empty.
	GHCommand string

	// AsyncRunner is the function that runs the CI check (mock for testing).
	// When nil, the default synchronous blocking implementation is used.
	AsyncRunner func(projectRoot, stateDir, bashCmd, ghCommand string)
}

// ciStatusInput is the input for the PostToolUse hook.
type ciStatusInput struct {
	ToolName  string `json:"tool_name"`
	ToolInput struct {
		Command string `json:"command"`
	} `json:"tool_input"`
	ToolResponse struct {
		ExitCode  *int   `json:"exit_code"`
		ExitCode2 *int   `json:"exitCode"`
		Output    string `json:"output"`
		Stdout    string `json:"stdout"`
	} `json:"tool_response"`
}

// ciStatusResponse is the response for the CIStatusChecker hook.
type ciStatusResponse struct {
	Decision          string `json:"decision"`
	Reason            string `json:"reason"`
	AdditionalContext string `json:"additionalContext,omitempty"`
}

// ciRunEntry represents one entry from gh run list.
type ciRunEntry struct {
	Status     string `json:"status"`
	Conclusion string `json:"conclusion"`
	Name       string `json:"name"`
	URL        string `json:"url"`
}

// pushOrPRCommandRe is the regular expression that detects git push / gh pr / gh workflow run.
var pushOrPRCommandRe = regexp.MustCompile(`(?:^|[\s;|&])(git\s+push|gh\s+pr\s+(?:create|merge|edit)|gh\s+workflow\s+run)`)

// Handle reads the payload from stdin, detects push/PR commands, and starts CI monitoring.
func (h *CIStatusCheckerHandler) Handle(r io.Reader, w io.Writer) error {
	data, err := io.ReadAll(r)
	if err != nil || len(data) == 0 {
		return writeCIJSON(w, ciStatusResponse{
			Decision: "approve",
			Reason:   "ci-status-checker: no payload",
		})
	}

	var input ciStatusInput
	if err := json.Unmarshal(data, &input); err != nil {
		return writeCIJSON(w, ciStatusResponse{
			Decision: "approve",
			Reason:   "ci-status-checker: parse error",
		})
	}

	bashCmd := input.ToolInput.Command

	// Skip if not a git push / gh pr command.
	if !isPushOrPRCommand(bashCmd) {
		return writeCIJSON(w, ciStatusResponse{
			Decision: "approve",
			Reason:   "ci-status-checker: not a push/PR command",
		})
	}

	// Skip when the gh command is not available.
	ghCmd := h.resolveGHCommand()
	if ghCmd == "" {
		return writeCIJSON(w, ciStatusResponse{
			Decision: "approve",
			Reason:   "ci-status-checker: gh command not found",
		})
	}

	projectRoot := h.ProjectRoot
	if projectRoot == "" {
		projectRoot, _ = os.Getwd()
	}

	stateDir := filepath.Join(projectRoot, ".claude", "state")
	_ = os.MkdirAll(stateDir, 0700)

	// Check for a recent CI failure signal (before running the runner).
	additionalContext := h.checkRecentCIFailure(stateDir, bashCmd)

	// Write the response to stdout first (CC keeps the process alive for async: true hooks).
	var writeErr error
	if additionalContext != "" {
		writeErr = writeCIJSON(w, ciStatusResponse{
			Decision:          "approve",
			Reason:            "ci-status-checker: push/PR detected, CI failure context injected",
			AdditionalContext: additionalContext,
		})
	} else {
		writeErr = writeCIJSON(w, ciStatusResponse{
			Decision: "approve",
			Reason:   "ci-status-checker: push/PR detected, CI monitoring started",
		})
	}
	if writeErr != nil {
		return writeErr
	}

	// After writing the response, poll CI status synchronously (blocking).
	// Because this is an async: true hook, CC keeps the process alive for up to 600 s.
	// No goroutine needed — this eliminates the risk of being killed on process exit.
	runner := h.AsyncRunner
	if runner == nil {
		runner = defaultCIRunner
	}
	runner(projectRoot, stateDir, bashCmd, ghCmd)
	return nil
}

// isPushOrPRCommand reports whether bashCmd contains a push or PR command.
func isPushOrPRCommand(cmd string) bool {
	return pushOrPRCommandRe.MatchString(cmd)
}

// resolveGHCommand returns the path to the gh command, or an empty string if not found.
func (h *CIStatusCheckerHandler) resolveGHCommand() string {
	if h.GHCommand != "" {
		if _, err := os.Stat(h.GHCommand); err == nil {
			return h.GHCommand
		}
		return ""
	}
	path, err := exec.LookPath("gh")
	if err != nil {
		return ""
	}
	return path
}

// checkRecentCIFailure checks for a recent ci_failure_detected signal and returns a message.
func (h *CIStatusCheckerHandler) checkRecentCIFailure(stateDir, bashCmd string) string {
	signalsFile := filepath.Join(stateDir, "breezing-signals.jsonl")

	f, err := os.Open(signalsFile)
	if err != nil {
		return ""
	}
	defer f.Close()

	// Look for the last ci_failure_detected signal.
	var lastFailureLine string
	buf := make([]byte, 1<<20) // maximum 1 MB
	n, _ := f.Read(buf)
	content := string(buf[:n])

	for _, line := range strings.Split(content, "\n") {
		if strings.Contains(line, `"ci_failure_detected"`) {
			lastFailureLine = line
		}
	}

	if lastFailureLine == "" {
		return ""
	}

	var sig map[string]interface{}
	if err := json.Unmarshal([]byte(lastFailureLine), &sig); err != nil {
		return ""
	}

	conclusion, _ := sig["conclusion"].(string)
	return fmt.Sprintf(
		"[CI failure detected]\nCI status: %s\nTrigger command: %s\n\nRecommended action: spawn /breezing or the ci-cd-fixer agent to automatically remediate the CI failure.\n  Example: ask ci-cd-fixer \"CI has failed. Please check the logs and fix it.\"",
		conclusion, bashCmd,
	)
}

// defaultCIRunner polls with gh run list and writes the result to the signals file.
// Runs synchronously (blocking), assuming an async: true hook.
// Because CC keeps async: true hook processes alive for up to 600 s,
// maxWait is set to 120 s to wait long enough for GitHub Actions to complete.
// (With the previous 25 s, only 2 polls were possible at 10 s intervals,
// causing monitoring to end before most CI runs finished.)
func defaultCIRunner(projectRoot, stateDir, bashCmd, ghCmd string) {
	const maxWait = 120 * time.Second
	const pollInterval = 10 * time.Second

	ciStatusFile := filepath.Join(stateDir, "ci-status.json")
	signalsFile := filepath.Join(stateDir, "breezing-signals.jsonl")

	deadline := time.Now().Add(maxWait)
	for time.Now().Before(deadline) {
		time.Sleep(pollInterval)

		out, err := exec.Command(ghCmd, "run", "list", "--limit", "1", "--json", "status,conclusion,name,url").Output()
		if err != nil || len(out) == 0 {
			continue
		}

		var runs []ciRunEntry
		if err := json.Unmarshal(out, &runs); err != nil || len(runs) == 0 {
			continue
		}

		run := runs[0]
		if run.Status != "completed" {
			continue
		}

		// Record the result.
		statusData, _ := json.Marshal(map[string]string{
			"timestamp":       time.Now().UTC().Format(time.RFC3339),
			"trigger_command": bashCmd,
			"status":          run.Status,
			"conclusion":      run.Conclusion,
		})
		_ = os.WriteFile(ciStatusFile, statusData, 0600)

		// Append to the signals file on CI failure.
		if run.Conclusion == "failure" || run.Conclusion == "timed_out" || run.Conclusion == "cancelled" {
			sig, _ := json.Marshal(map[string]string{
				"signal":          "ci_failure_detected",
				"timestamp":       time.Now().UTC().Format(time.RFC3339),
				"conclusion":      run.Conclusion,
				"trigger_command": bashCmd,
			})
			f, err := os.OpenFile(signalsFile, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0600)
			if err == nil {
				_, _ = f.Write(sig)
				_, _ = f.Write([]byte("\n"))
				f.Close()
			}
		}

		return
	}
}

// writeCIJSON writes v as JSON to w.
func writeCIJSON(w io.Writer, v interface{}) error {
	data, err := json.Marshal(v)
	if err != nil {
		return fmt.Errorf("marshaling JSON: %w", err)
	}
	_, err = fmt.Fprintf(w, "%s\n", data)
	return err
}
