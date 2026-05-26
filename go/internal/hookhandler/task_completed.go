package hookhandler

// task_completed.go - Go port of task-completed.sh (entry point)
//
// TaskCompleted event (team mode) handler.
// Records task completion to the timeline and handles Breezing state management,
// test failure escalation, and harness-mem finalize.
//
// Original script: scripts/hook-handlers/task-completed.sh

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
)

// taskCompletedInput is the stdin JSON for the TaskCompleted hook.
type taskCompletedInput struct {
	TeammateName    string `json:"teammate_name"`
	AgentName       string `json:"agent_name"`
	TaskID          string `json:"task_id"`
	TaskSubject     string `json:"task_subject"`
	Subject         string `json:"subject"`
	TaskDescription string `json:"task_description"`
	Description     string `json:"description"`
	AgentID         string `json:"agent_id"`
	AgentType       string `json:"agent_type"`
	Continue        *bool  `json:"continue"`
	StopReason      string `json:"stopReason"`
	StopReasonSnake string `json:"stop_reason"`
	CWD             string `json:"cwd"`
	ProjectRoot     string `json:"project_root"`
}

// taskCompletedHandler holds all state for task-completed.
type taskCompletedHandler struct {
	projectRoot    string
	stateDir       string
	timelineFile   string
	pendingFixFile string
	finalizeMarker string
	// plansPath is the resolved path to Plans.md (respecting plansDirectory setting).
	// Empty if it does not exist.
	plansPath string
}

// HandleTaskCompleted is the Go port entry point for task-completed.sh.
func HandleTaskCompleted(in io.Reader, out io.Writer) error {
	data, err := io.ReadAll(in)
	if err != nil || len(data) == 0 {
		return writeJSON(out, approveResponse("TaskCompleted: no payload"))
	}

	var input taskCompletedInput
	if err := json.Unmarshal(data, &input); err != nil {
		return writeJSON(out, approveResponse("TaskCompleted: invalid payload"))
	}

	// Determine project root
	projectRoot := input.ProjectRoot
	if projectRoot == "" {
		projectRoot = input.CWD
	}
	if projectRoot == "" {
		projectRoot, _ = os.Getwd()
	}

	h := &taskCompletedHandler{
		projectRoot:    projectRoot,
		stateDir:       filepath.Join(projectRoot, ".claude", "state"),
		timelineFile:   filepath.Join(projectRoot, ".claude", "state", "breezing-timeline.jsonl"),
		pendingFixFile: filepath.Join(projectRoot, ".claude", "state", "pending-fix-proposals.jsonl"),
		finalizeMarker: filepath.Join(projectRoot, ".claude", "state", "harness-mem-finalize-work-completed.json"),
		// Resolve Plans.md path respecting plansDirectory in config
		plansPath: resolvePlansPath(projectRoot),
	}

	return h.handle(input, data, out)
}

func (h *taskCompletedHandler) handle(input taskCompletedInput, rawData []byte, out io.Writer) error {
	// Normalize fields
	teammateName := firstNonEmpty(input.TeammateName, input.AgentName)
	taskID := input.TaskID
	taskSubject := firstNonEmpty(input.TaskSubject, input.Subject)
	taskDesc := input.TaskDescription
	if taskDesc == "" {
		taskDesc = input.Description
	}
	if len(taskDesc) > 100 {
		taskDesc = taskDesc[:100]
	}
	agentID := input.AgentID
	agentType := input.AgentType

	stopReason := firstNonEmpty(input.StopReason, input.StopReasonSnake)
	requestContinue := true // Default: continue
	if input.Continue != nil {
		requestContinue = *input.Continue
	}

	ts := utcNow()

	// Create state directory
	if err := os.MkdirAll(h.stateDir, 0o700); err != nil {
		fmt.Fprintf(os.Stderr, "[task-completed] mkdir: %v\n", err)
	}

	// Record to timeline
	h.appendTimeline(timelineEntry{
		Event:       "task_completed",
		Teammate:    teammateName,
		TaskID:      taskID,
		Subject:     taskSubject,
		Description: taskDesc,
		AgentID:     agentID,
		AgentType:   agentType,
		Timestamp:   ts,
	})

	// Generate Breezing signals
	totalTasks, completedCount := h.updateBreezingSignals(taskID, ts)

	// Check test result
	testOK, failCount := h.checkTestResultAndEscalate(taskID, taskSubject, teammateName, ts)
	if !testOK {
		if failCount >= 3 {
			// 3-strike escalation
			return h.emitEscalationResponse(out, taskID, taskSubject, failCount)
		}
		return writeJSON(out, map[string]string{
			"decision": "block",
			"reason":   "TaskCompleted: test result shows failure - escalation required",
		})
	}

	// Webhook notification (synchronous, 5-second timeout)
	h.fireWebhook(rawData)

	// title / body for terminalSequence (CC 2.1.141+, opt-in via HARNESS_TERMINAL_NOTIFY).
	// Details: .claude/rules/hooks-2.1.139-plus.md
	tsTitle, tsBody := taskCompletedTerminalTitleBody(taskSubject, completedCount, totalTasks)
	tsSeq := BuildTerminalSequence(tsTitle, tsBody)

	// Determine whether to stop
	if !requestContinue || stopReason != "" {
		finalReason := stopReason
		if finalReason == "" {
			finalReason = "TaskCompleted requested stop"
		}
		resp := map[string]interface{}{
			"continue":   false,
			"stopReason": finalReason,
		}
		if tsSeq != "" {
			resp["terminalSequence"] = tsSeq
		}
		return writeJSON(out, resp)
	}

	// Determine if all tasks are complete
	if totalTasks > 0 && completedCount >= totalTasks {
		h.maybeFinalizeHarnessMem(ts)
		resp := map[string]interface{}{
			"continue":   false,
			"stopReason": "all_tasks_completed",
		}
		if tsSeq != "" {
			resp["terminalSequence"] = tsSeq
		}
		return writeJSON(out, resp)
	}

	// Approval response with progress summary
	if totalTasks > 0 && taskSubject != "" {
		progressMsg := fmt.Sprintf("Progress: Task %d/%d completed — %q", completedCount, totalTasks, taskSubject)
		resp := map[string]interface{}{
			"decision":      "approve",
			"reason":        "TaskCompleted tracked",
			"systemMessage": progressMsg,
		}
		if tsSeq != "" {
			resp["terminalSequence"] = tsSeq
		}
		return writeJSON(out, resp)
	}

	resp := map[string]interface{}{
		"decision": "approve",
		"reason":   "TaskCompleted tracked",
	}
	if tsSeq != "" {
		resp["terminalSequence"] = tsSeq
	}
	return writeJSON(out, resp)
}

// taskCompletedTerminalTitleBody assembles the terminalSequence title/body for TaskCompleted notifications.
// Includes a count in the body when progress information is available.
func taskCompletedTerminalTitleBody(taskSubject string, completed, total int) (string, string) {
	title := "Claude Code: task completed"
	if taskSubject != "" {
		title = "Claude Code: " + taskSubject
	}
	body := ""
	if total > 0 {
		body = fmt.Sprintf("%d/%d completed", completed, total)
	}
	return title, body
}

// approveResponse returns a standard approval response.
func approveResponse(reason string) map[string]string {
	return map[string]string{
		"decision": "approve",
		"reason":   reason,
	}
}
