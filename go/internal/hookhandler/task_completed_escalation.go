package hookhandler

// task_completed_escalation.go - Test failure escalation and Fix Proposal management

import (
	"bufio"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"strings"
)

// qualityGateEntry is each task entry in task-quality-gate.json.
type qualityGateEntry struct {
	FailureCount int    `json:"failure_count"`
	LastAction   string `json:"last_action"`
	UpdatedAt    string `json:"updated_at"`
}

// fixProposal is a single-line entry in pending-fix-proposals.jsonl.
type fixProposal struct {
	SourceTaskID      string `json:"source_task_id"`
	FixTaskID         string `json:"fix_task_id"`
	TaskSubject       string `json:"task_subject"`
	ProposalSubject   string `json:"proposal_subject"`
	FailureCategory   string `json:"failure_category"`
	RecommendedAction string `json:"recommended_action"`
	DoD               string `json:"dod"`
	Depends           string `json:"depends"`
	CreatedAt         string `json:"created_at"`
	Status            string `json:"status"`
}

// testResultFile is the schema for .claude/state/test-result.json.
type testResultFile struct {
	Status  string `json:"status"`
	Command string `json:"command"`
	Output  string `json:"output"`
}

// checkTestResultAndEscalate checks the test result and manages the failure count.
// Also returns failCount when testOK=false.
func (h *taskCompletedHandler) checkTestResultAndEscalate(taskID, taskSubject, teammateName, ts string) (testOK bool, failCount int) {
	resultFile := h.stateDir + "/test-result.json"

	// Treat as success if the result file is missing (projects without tests)
	if _, err := os.Stat(resultFile); err != nil {
		return true, 0
	}

	data, err := os.ReadFile(resultFile)
	if err != nil {
		return true, 0
	}
	var result testResultFile
	if err := json.Unmarshal(data, &result); err != nil {
		return true, 0
	}

	if result.Status != "failed" {
		// Success or timeout: reset failure count
		h.updateFailureCount(taskID, "reset", ts)
		return true, 0
	}

	// Test failure
	failCount = h.updateFailureCount(taskID, "increment", ts)

	// Record failure to timeline
	h.appendTimeline(timelineEntry{
		Event:        "test_result_failed",
		Teammate:     teammateName,
		TaskID:       taskID,
		Subject:      taskSubject,
		Timestamp:    ts,
		FailureCount: fmt.Sprintf("%d", failCount),
	})

	return false, failCount
}

// updateFailureCount updates the per-task failure count in quality-gate.json.
// Returns the new count value.
func (h *taskCompletedHandler) updateFailureCount(taskID, action, ts string) int {
	gatePath := h.stateDir + "/task-quality-gate.json"

	// Load existing data
	existing := make(map[string]qualityGateEntry)
	if data, err := os.ReadFile(gatePath); err == nil {
		// Symlink check
		if info, err := os.Lstat(gatePath); err == nil && info.Mode()&os.ModeSymlink == 0 {
			_ = json.Unmarshal(data, &existing)
		}
	}

	entry := existing[taskID]
	if action == "increment" {
		entry.FailureCount++
	} else {
		entry.FailureCount = 0
	}
	entry.LastAction = action
	entry.UpdatedAt = ts
	existing[taskID] = entry

	// Write back to file (reject symlinks)
	if info, err := os.Lstat(gatePath); err == nil && info.Mode()&os.ModeSymlink != 0 {
		return entry.FailureCount
	}

	data, err := json.MarshalIndent(existing, "", "  ")
	if err == nil {
		tmpPath := gatePath + ".tmp"
		if err := os.WriteFile(tmpPath, append(data, '\n'), 0o644); err == nil {
			os.Rename(tmpPath, gatePath) //nolint:errcheck
		}
	}

	return entry.FailureCount
}

// buildFixTaskID generates a fix task ID from the source task ID.
// e.g. "26.1" → "26.1.fix", "26.1.fix" → "26.1.fix2", "26.1.fix2" → "26.1.fix3"
func buildFixTaskID(sourceTaskID string) string {
	// .fix{N} pattern
	if idx := strings.LastIndex(sourceTaskID, ".fix"); idx >= 0 {
		suffix := sourceTaskID[idx+4:]
		base := sourceTaskID[:idx]
		if suffix == "" {
			return base + ".fix2"
		}
		var n int
		if _, err := fmt.Sscanf(suffix, "%d", &n); err == nil {
			return fmt.Sprintf("%s.fix%d", base, n+1)
		}
	}
	return sourceTaskID + ".fix"
}

// classifyFailure classifies the failure category and recommended action from test output.
func classifyFailure(output string) (category, action string) {
	lower := strings.ToLower(output)
	switch {
	case containsAny(lower, "syntax", "syntaxerror", "parse error", "unexpected token"):
		return "syntax_error", "Fix the syntax error. Check the code grammar."
	case containsAny(lower, "cannot find module", "module not found", "import.*error", "modulenotfounderror"):
		return "import_error", "Fix the module/import error. Check your dependencies (npm install / pip install)."
	case containsAny(lower, "type.*error", "typeerror", "is not assignable", "property.*does not exist"):
		return "type_error", "Fix the type error. Check for mismatches between type definitions and implementation."
	case containsAny(lower, "assertion", "assertionerror", "expect.*received", "tobe", "toequal", "fail", "failed"):
		return "assertion_error", "Test assertion failed. Check the diff between expected and actual values."
	case containsAny(lower, "timeout", "etimedout", "timed out"):
		return "timeout", "A timeout occurred. Check async processing and network dependencies."
	case containsAny(lower, "permission", "eacces", "eperm", "access denied"):
		return "permission_error", "A permission error occurred. Check file permissions."
	default:
		return "runtime_error", "A runtime error occurred. Review the test output in detail."
	}
}

// containsAny checks whether text contains any of the candidates.
func containsAny(text string, candidates ...string) bool {
	for _, c := range candidates {
		if strings.Contains(text, c) {
			return true
		}
	}
	return false
}

// emitEscalationResponse outputs the 3-strike escalation response.
func (h *taskCompletedHandler) emitEscalationResponse(out io.Writer, taskID, taskSubject string, failCount int) error {
	ts := utcNow()

	// Load test output
	var lastCmd, lastOutput string
	resultFile := h.stateDir + "/test-result.json"
	if data, err := os.ReadFile(resultFile); err == nil {
		var result testResultFile
		if json.Unmarshal(data, &result) == nil {
			lastCmd = result.Command
			lastOutput = limitLines(result.Output, 20)
		}
	}

	category, action := classifyFailure(lastOutput)

	// Output escalation report to stderr
	fmt.Fprintf(os.Stderr, "\n==========================================\n")
	fmt.Fprintf(os.Stderr, "[ESCALATION] 3 consecutive failures detected - stopping auto-fix loop\n")
	fmt.Fprintf(os.Stderr, "==========================================\n")
	fmt.Fprintf(os.Stderr, "  Task ID         : %s\n", taskID)
	fmt.Fprintf(os.Stderr, "  Task name       : %s\n", taskSubject)
	fmt.Fprintf(os.Stderr, "  Consecutive fail: %d\n", failCount)
	fmt.Fprintf(os.Stderr, "  Detected at     : %s\n", ts)
	fmt.Fprintf(os.Stderr, "------------------------------------------\n")
	fmt.Fprintf(os.Stderr, "  [Failure category]\n  Category        : %s\n\n", category)
	fmt.Fprintf(os.Stderr, "  [Recommended action]\n  %s\n\n", action)
	if lastCmd != "" {
		fmt.Fprintf(os.Stderr, "  [Last command executed]\n  %s\n\n", lastCmd)
	}
	if lastOutput != "" {
		fmt.Fprintf(os.Stderr, "  [Test output (max 20 lines)]\n")
		scanner := bufio.NewScanner(strings.NewReader(lastOutput))
		for scanner.Scan() {
			fmt.Fprintf(os.Stderr, "    %s\n", scanner.Text())
		}
		fmt.Fprintln(os.Stderr)
	}
	fmt.Fprintf(os.Stderr, "==========================================\n\n")

	// Append escalation record to timeline
	h.appendTimeline(timelineEntry{
		Event:        "escalation_triggered",
		TaskID:       taskID,
		Subject:      taskSubject,
		Timestamp:    ts,
		FailureCount: fmt.Sprintf("%d", failCount),
	})

	// Generate and save Fix Proposal
	fixTaskID := buildFixTaskID(taskID)
	proposalSubject := sanitizeInlineText("fix: " + taskSubject + " - " + category)
	dod := sanitizeInlineText("Resolve failure category (" + category + ") and ensure recent tests/CI pass")

	proposal := fixProposal{
		SourceTaskID:      taskID,
		FixTaskID:         fixTaskID,
		TaskSubject:       taskSubject,
		ProposalSubject:   proposalSubject,
		FailureCategory:   category,
		RecommendedAction: action,
		DoD:               dod,
		Depends:           taskID,
		CreatedAt:         ts,
		Status:            "pending",
	}

	proposalSaved := h.upsertFixProposal(proposal)

	fixMessage := fmt.Sprintf("[FIX PROPOSAL] Task %s failed 3 times consecutively.\nProposal: %s — %s\nDoD: %s\nApprove: approve fix %s\nReject: reject fix %s",
		taskID, fixTaskID, proposalSubject, dod, taskID, taskID)
	if !proposalSaved {
		fixMessage += "\nWarning: failed to save proposal. Please add it to Plans.md manually."
	}

	return writeJSON(out, map[string]string{
		"decision":      "approve",
		"reason":        "TaskCompleted: 3-strike escalation triggered - fix proposal queued",
		"systemMessage": fixMessage,
	})
}

// upsertFixProposal adds or updates a proposal in pending-fix-proposals.jsonl.
// Replaces any existing entry with the same source_task_id.
func (h *taskCompletedHandler) upsertFixProposal(proposal fixProposal) bool {
	// Symlink check
	if info, err := os.Lstat(h.pendingFixFile); err == nil && info.Mode()&os.ModeSymlink != 0 {
		return false
	}
	if info, err := os.Lstat(h.stateDir); err == nil && info.Mode()&os.ModeSymlink != 0 {
		return false
	}

	// Load existing entries (excluding the same source_task_id)
	var rows []fixProposal
	if f, err := os.Open(h.pendingFixFile); err == nil {
		scanner := bufio.NewScanner(f)
		for scanner.Scan() {
			line := strings.TrimSpace(scanner.Text())
			if line == "" {
				continue
			}
			var row fixProposal
			if err := json.Unmarshal([]byte(line), &row); err != nil {
				continue
			}
			if row.SourceTaskID != proposal.SourceTaskID {
				rows = append(rows, row)
			}
		}
		f.Close()
	}
	rows = append(rows, proposal)

	// Write back to file
	if err := os.MkdirAll(h.stateDir, 0o700); err != nil {
		return false
	}

	var buf []byte
	for _, row := range rows {
		data, err := json.Marshal(row)
		if err != nil {
			continue
		}
		buf = append(buf, data...)
		buf = append(buf, '\n')
	}

	if err := os.WriteFile(h.pendingFixFile, buf, 0o644); err != nil {
		return false
	}
	return true
}
