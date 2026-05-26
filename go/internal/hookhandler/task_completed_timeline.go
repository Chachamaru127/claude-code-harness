package hookhandler

// task_completed_timeline.go - Timeline recording and Breezing signal management

import (
	"bufio"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"
)

// timelineEntry is a single-line entry in breezing-timeline.jsonl.
type timelineEntry struct {
	Event        string `json:"event"`
	Teammate     string `json:"teammate"`
	TaskID       string `json:"task_id"`
	Subject      string `json:"subject"`
	Description  string `json:"description,omitempty"`
	AgentID      string `json:"agent_id,omitempty"`
	AgentType    string `json:"agent_type,omitempty"`
	Timestamp    string `json:"timestamp"`
	FailureCount string `json:"failure_count,omitempty"`
}

// signalEntry is a single-line entry in breezing-signals.jsonl.
type signalEntry struct {
	Signal    string `json:"signal"`
	SessionID string `json:"session_id"`
	Completed string `json:"completed"`
	Total     string `json:"total"`
	Timestamp string `json:"timestamp"`
}

// breezingActiveJSON is the schema for breezing-active.json (required fields only).
type breezingActiveJSON struct {
	SessionID string `json:"session_id"`
	Batching  *struct {
		Batches []struct {
			Status  string   `json:"status"`
			TaskIDs []string `json:"task_ids"`
		} `json:"batches"`
	} `json:"batching"`
	PlansMDMapping map[string]json.RawMessage `json:"plans_md_mapping"`
}

// utcNow returns the current time in RFC3339 UTC format.
func utcNow() string {
	return time.Now().UTC().Format(time.RFC3339)
}

// sanitizeInlineText removes newlines, pipes, and consecutive spaces.
func sanitizeInlineText(s string) string {
	s = strings.ReplaceAll(s, "\n", " ")
	s = strings.ReplaceAll(s, "|", " ")
	for strings.Contains(s, "  ") {
		s = strings.ReplaceAll(s, "  ", " ")
	}
	return s
}

// appendTimeline appends an entry to the timeline file and rotates when over 500 lines.
func (h *taskCompletedHandler) appendTimeline(entry timelineEntry) {
	data, err := json.Marshal(entry)
	if err != nil {
		fmt.Fprintf(os.Stderr, "[task-completed] marshal timeline entry: %v\n", err)
		return
	}

	f, err := os.OpenFile(h.timelineFile, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o644)
	if err != nil {
		fmt.Fprintf(os.Stderr, "[task-completed] open timeline: %v\n", err)
		return
	}
	fmt.Fprintf(f, "%s\n", data)
	f.Close()

	_ = rotateJSONL(h.timelineFile, 500, 400)
}

// updateBreezingSignals manages Breezing session signals (50%/60%/complete).
// Returns totalTasks and completedCount.
func (h *taskCompletedHandler) updateBreezingSignals(taskID, ts string) (totalTasks, completedCount int) {
	activeFile := filepath.Join(h.stateDir, "breezing-active.json")
	if _, err := os.Stat(activeFile); err != nil {
		return 0, 0
	}

	// Read breezing-active.json
	raw, err := os.ReadFile(activeFile)
	if err != nil {
		return 0, 0
	}
	var active breezingActiveJSON
	if err := json.Unmarshal(raw, &active); err != nil {
		return 0, 0
	}

	sessionID := active.SessionID

	// Get batch ID list and total task count
	var batchIDs []string
	if active.Batching != nil {
		for _, batch := range active.Batching.Batches {
			if batch.Status == "in_progress" {
				batchIDs = batch.TaskIDs
				totalTasks = len(batchIDs)
				break
			}
		}
	}
	// Use plans_md_mapping keys when batch information is absent
	if totalTasks == 0 && len(active.PlansMDMapping) > 0 {
		for k := range active.PlansMDMapping {
			batchIDs = append(batchIDs, k)
		}
		totalTasks = len(batchIDs)
	}

	// Count completed tasks from the timeline
	completedCount = h.countCompleted(batchIDs)

	signalsFile := filepath.Join(h.stateDir, "breezing-signals.jsonl")

	// 50% completion signal (HALF > 1 guard: not needed for batch sizes 1-2)
	if totalTasks > 0 {
		half := (totalTasks + 1) / 2
		if completedCount >= half && half > 1 {
			if !signalExists(signalsFile, "partial_review_recommended", sessionID) {
				appendSignal(signalsFile, signalEntry{
					Signal:    "partial_review_recommended",
					SessionID: sessionID,
					Completed: fmt.Sprintf("%d", completedCount),
					Total:     fmt.Sprintf("%d", totalTasks),
					Timestamp: ts,
				})
			}
		}

		// 60% completion signal (ceiling calculation)
		sixtyPct := (totalTasks*60 + 99) / 100
		if sixtyPct > 0 && completedCount >= sixtyPct {
			if !signalExists(signalsFile, "next_batch_recommended", sessionID) {
				appendSignal(signalsFile, signalEntry{
					Signal:    "next_batch_recommended",
					SessionID: sessionID,
					Completed: fmt.Sprintf("%d", completedCount),
					Total:     fmt.Sprintf("%d", totalTasks),
					Timestamp: ts,
				})
			}
		}
	}

	return totalTasks, completedCount
}

// countCompleted counts the number of completed items for the given batch IDs from the timeline.
func (h *taskCompletedHandler) countCompleted(batchIDs []string) int {
	if _, err := os.Stat(h.timelineFile); err != nil {
		return 0
	}

	f, err := os.Open(h.timelineFile)
	if err != nil {
		return 0
	}
	defer f.Close()

	// Convert batch IDs to a set
	idSet := make(map[string]bool, len(batchIDs))
	for _, id := range batchIDs {
		idSet[strings.TrimSpace(id)] = true
	}

	// Scan timeline and confirm completion for each batch ID (max 1 count per ID)
	found := make(map[string]bool)
	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" {
			continue
		}
		var entry timelineEntry
		if err := json.Unmarshal([]byte(line), &entry); err != nil {
			continue
		}
		if entry.Event == "task_completed" && idSet[entry.TaskID] {
			found[entry.TaskID] = true
		}
	}
	return len(found)
}

// signalExists checks whether the specified signal has already been recorded in the session scope.
func signalExists(signalsFile, sigType, sessionID string) bool {
	f, err := os.Open(signalsFile)
	if err != nil {
		return false
	}
	defer f.Close()

	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" {
			continue
		}
		if !strings.Contains(line, `"`+sigType+`"`) {
			continue
		}
		if sessionID == "" || strings.Contains(line, `"`+sessionID+`"`) {
			return true
		}
	}
	return false
}

// appendSignal appends a signal to breezing-signals.jsonl.
func appendSignal(signalsFile string, entry signalEntry) {
	data, err := json.Marshal(entry)
	if err != nil {
		return
	}
	f, err := os.OpenFile(signalsFile, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o644)
	if err != nil {
		return
	}
	defer f.Close()
	fmt.Fprintf(f, "%s\n", data)
}
