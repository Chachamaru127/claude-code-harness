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

// instructionsLoadedInput is the stdin JSON passed to instructions-loaded.sh.
type instructionsLoadedInput struct {
	SessionID     string `json:"session_id"`
	CWD           string `json:"cwd"`
	AgentID       string `json:"agent_id"`
	AgentType     string `json:"agent_type"`
	HookEventName string `json:"hook_event_name"`
	EventName     string `json:"event_name"`
}

// approveOutput is the {"decision":"approve","reason":"..."} response.
type approveOutput struct {
	Decision string `json:"decision"`
	Reason   string `json:"reason"`
}

// HandleInstructionsLoaded is the Go port of instructions-loaded.sh.
//
// Called on InstructionsLoaded events, it performs the following:
// 1. Records the event to .claude/state/instructions-loaded.jsonl
// 2. Lightly validates the presence of hooks.json
//
// Always returns {"decision":"approve",...} (non-blocking).
func HandleInstructionsLoaded(in io.Reader, out io.Writer) error {
	// Read JSON from stdin.
	data, err := io.ReadAll(in)
	if err != nil {
		return writeJSON(out, approveOutput{
			Decision: "approve",
			Reason:   "InstructionsLoaded: read error",
		})
	}

	payload := strings.TrimSpace(string(data))
	if payload == "" {
		return writeJSON(out, approveOutput{
			Decision: "approve",
			Reason:   "InstructionsLoaded: no payload",
		})
	}

	// Parse the payload.
	var input instructionsLoadedInput
	if jsonErr := json.Unmarshal([]byte(payload), &input); jsonErr != nil {
		return writeJSON(out, approveOutput{
			Decision: "approve",
			Reason:   "InstructionsLoaded: parse error",
		})
	}

	// Resolve PROJECT_ROOT (CWD field takes priority, then env var, then pwd).
	projectRoot := input.CWD
	if projectRoot == "" {
		projectRoot = os.Getenv("PROJECT_ROOT")
	}
	if projectRoot == "" {
		cwd, cwdErr := os.Getwd()
		if cwdErr == nil {
			projectRoot = cwd
		}
	}

	// Resolve event_name (hook_event_name takes priority, event_name as fallback).
	eventName := input.HookEventName
	if eventName == "" {
		eventName = input.EventName
	}
	if eventName == "" {
		eventName = "InstructionsLoaded"
	}

	// Record the event to .claude/state/instructions-loaded.jsonl.
	stateDir := filepath.Join(projectRoot, ".claude", "state")
	logFile := filepath.Join(stateDir, "instructions-loaded.jsonl")

	if mkdirErr := os.MkdirAll(stateDir, 0o755); mkdirErr == nil {
		ts := time.Now().UTC().Format(time.RFC3339)
		event := map[string]string{
			"event":      eventName,
			"timestamp":  ts,
			"session_id": input.SessionID,
			"agent_id":   input.AgentID,
			"agent_type": input.AgentType,
			"cwd":        projectRoot,
		}
		if eventData, marshalErr := json.Marshal(event); marshalErr == nil {
			f, openErr := os.OpenFile(logFile, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o644)
			if openErr == nil {
				fmt.Fprintf(f, "%s\n", eventData)
				f.Close()
			}
		}
	}

	// Lightly validate the presence of hooks.json.
	hooksFound := fileExists(filepath.Join(projectRoot, "hooks", "hooks.json")) ||
		fileExists(filepath.Join(projectRoot, ".claude-plugin", "hooks.json"))

	if !hooksFound {
		return writeJSON(out, approveOutput{
			Decision: "approve",
			Reason:   "InstructionsLoaded: hooks.json not found in project root",
		})
	}

	return writeJSON(out, approveOutput{
		Decision: "approve",
		Reason:   "InstructionsLoaded tracked",
	})
}
