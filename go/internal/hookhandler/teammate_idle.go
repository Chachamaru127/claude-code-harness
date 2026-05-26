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

// teammateIdleInput is the stdin JSON payload for the TeammateIdle hook.
type teammateIdleInput struct {
	TeammateeName string `json:"teammate_name"`
	AgentName     string `json:"agent_name"`
	TeamName      string `json:"team_name"`
	AgentID       string `json:"agent_id"`
	AgentType     string `json:"agent_type"`
	Continue      *bool  `json:"continue"`
	StopReason    string `json:"stopReason"`
	StopReasonAlt string `json:"stop_reason"`
}

// teammateIdleLogEntry is the entry recorded in breezing-timeline.jsonl.
type teammateIdleLogEntry struct {
	Event     string `json:"event"`
	Teammate  string `json:"teammate"`
	Team      string `json:"team"`
	AgentID   string `json:"agent_id"`
	AgentType string `json:"agent_type"`
	Timestamp string `json:"timestamp"`
}

// teammateIdleApprove is the approve response.
type teammateIdleApprove struct {
	Decision string `json:"decision"`
	Reason   string `json:"reason"`
}

// teammateIdleStop is the stop response.
type teammateIdleStop struct {
	Continue   bool   `json:"continue"`
	StopReason string `json:"stopReason"`
}

// timelineRotateMaxLines is the rotation threshold for the JSONL file.
const timelineRotateMaxLines = 500

// timelineRotateKeepLines is the number of lines to retain after rotation.
const timelineRotateKeepLines = 400

// dedupWindowSeconds is the deduplication window (in seconds) for the same agent.
const dedupWindowSeconds = 5

// HandleTeammateIdle is a Go port of teammate-idle.sh.
//
// Processing TeammateIdle events:
//  1. Read the stdin JSON payload
//  2. 5-second dedup (suppress consecutive firings for the same agent_id)
//  3. Record idle state in breezing-timeline.jsonl
//  4. Send a stop signal when continue:false or stop_reason is present
//  5. Otherwise return approve
func HandleTeammateIdle(in io.Reader, out io.Writer) error {
	data, err := io.ReadAll(in)
	if err != nil || len(strings.TrimSpace(string(data))) == 0 {
		return writeTeammateIdleApprove(out, "TeammateIdle: no payload")
	}

	var input teammateIdleInput
	if err := json.Unmarshal(data, &input); err != nil {
		return writeTeammateIdleApprove(out, "TeammateIdle: no payload")
	}

	// Retrieve teammate_name or agent_name
	teammateName := input.TeammateeName
	if teammateName == "" {
		teammateName = input.AgentName
	}

	// Normalize stop_reason
	stopReason := input.StopReason
	if stopReason == "" {
		stopReason = input.StopReasonAlt
	}

	// continue flag
	hookContinue := true // default: continue
	if input.Continue != nil {
		hookContinue = *input.Continue
	}

	// Retrieve project root
	projectRoot := os.Getenv("PROJECT_ROOT")
	if projectRoot == "" {
		if cwd, err := os.Getwd(); err == nil {
			projectRoot = cwd
		}
	}

	// State directory and timeline file
	stateDir := filepath.Join(projectRoot, ".claude", "state")
	if err := os.MkdirAll(stateDir, 0o700); err != nil {
		// Ignore error (continue)
		fmt.Fprintf(os.Stderr, "[claude-code-harness] teammate-idle: mkdir %s: %v\n", stateDir, err)
	}
	timelineFile := filepath.Join(stateDir, "breezing-timeline.jsonl")

	// === Deduplication (skip idle events for the same teammate within 5 seconds) ===
	dedupKey := teammateName
	if dedupKey == "" {
		dedupKey = input.AgentID
	}

	if dedupKey != "" {
		if shouldSkip := checkTeammateIdleDedup(timelineFile, dedupKey); shouldSkip {
			return writeTeammateIdleApprove(out, "TeammateIdle dedup: skipped")
		}
	}

	// === Timeline recording ===
	ts := time.Now().UTC().Format(time.RFC3339)
	logEntry := teammateIdleLogEntry{
		Event:     "teammate_idle",
		Teammate:  teammateName,
		Team:      input.TeamName,
		AgentID:   input.AgentID,
		AgentType: input.AgentType,
		Timestamp: ts,
	}
	if entryData, err := json.Marshal(logEntry); err == nil {
		appendToJSONL(timelineFile, entryData)
		_ = rotateJSONL(timelineFile, timelineRotateMaxLines, timelineRotateKeepLines)
	}

	// === Response ===
	// Send a stop signal when continue:false or stop_reason is present
	if !hookContinue || stopReason != "" {
		finalStopReason := stopReason
		if finalStopReason == "" {
			finalStopReason = "TeammateIdle requested stop"
		}
		return writeTeammateIdleStop(out, finalStopReason)
	}

	return writeTeammateIdleApprove(out, "TeammateIdle tracked")
}

// checkTeammateIdleDedup checks whether a new idle event for the same agent falls within
// dedupWindowSeconds of the last one. Corresponds to the deduplication logic in teammate-idle.sh.
func checkTeammateIdleDedup(timelineFile, dedupKey string) bool {
	data, err := os.ReadFile(timelineFile)
	if err != nil {
		return false // No file — do not skip
	}

	// Scan JSONL in reverse to find the last idle event for the same teammate
	lines := strings.Split(strings.TrimSpace(string(data)), "\n")
	for i := len(lines) - 1; i >= 0; i-- {
		line := strings.TrimSpace(lines[i])
		if line == "" {
			continue
		}

		// Look for a "teammate_idle" event line that contains the dedupKey
		if !strings.Contains(line, `"teammate_idle"`) {
			continue
		}
		if !strings.Contains(line, dedupKey) {
			continue
		}

		var entry teammateIdleLogEntry
		if err := json.Unmarshal([]byte(line), &entry); err != nil {
			continue
		}

		// Verify that the teammate name or agent ID matches
		if entry.Teammate != dedupKey && entry.AgentID != dedupKey {
			continue
		}

		// Parse the timestamp and check whether it is within 5 seconds
		lastTime, err := time.Parse(time.RFC3339, entry.Timestamp)
		if err != nil {
			continue
		}

		elapsed := time.Since(lastTime)
		if elapsed < dedupWindowSeconds*time.Second {
			return true // Skip
		}
		return false // More than 5 seconds have elapsed — do not skip
	}

	return false
}

// writeTeammateIdleApprove writes an approve response.
func writeTeammateIdleApprove(out io.Writer, reason string) error {
	resp := teammateIdleApprove{
		Decision: "approve",
		Reason:   reason,
	}
	return writeJSON(out, resp)
}

// writeTeammateIdleStop writes a stop-signal response.
func writeTeammateIdleStop(out io.Writer, stopReason string) error {
	resp := teammateIdleStop{
		Continue:   false,
		StopReason: stopReason,
	}
	return writeJSON(out, resp)
}
