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

// configChangeInput is the stdin JSON passed to config-change.sh.
// Payload for the ConfigChange event.
type configChangeInput struct {
	FilePath   string `json:"file_path"`
	ChangeType string `json:"change_type"`
}

// breezingState is the structure of .claude/state/breezing.json.
type breezingState struct {
	Status string `json:"status"`
}

// okOutput is a {"ok":true} response.
type okOutput struct {
	OK bool `json:"ok"`
}

// HandleConfigChange is the Go port of config-change.sh.
//
// Called on ConfigChange events, it records to .claude/state/breezing-timeline.jsonl
// only when Breezing is active.
// Always returns {"ok":true} (does not block Stop).
func HandleConfigChange(in io.Reader, out io.Writer) error {
	// Read JSON from stdin (size limit 64 KB).
	lr := io.LimitReader(in, 65536)
	data, err := io.ReadAll(lr)
	if err != nil {
		return writeJSON(out, okOutput{OK: true})
	}

	payload := strings.TrimSpace(string(data))
	if payload == "" {
		return writeJSON(out, okOutput{OK: true})
	}

	// Resolve PROJECT_ROOT (environment variable takes priority, falls back to cwd).
	projectRoot := os.Getenv("PROJECT_ROOT")
	if projectRoot == "" {
		cwd, cwdErr := os.Getwd()
		if cwdErr != nil {
			return writeJSON(out, okOutput{OK: true})
		}
		projectRoot = cwd
	}

	// Check whether breezing is active.
	breezingStateFile := filepath.Join(projectRoot, ".claude", "state", "breezing.json")
	if !isBreezingActive(breezingStateFile) {
		return writeJSON(out, okOutput{OK: true})
	}

	// Parse the payload.
	var input configChangeInput
	if jsonErr := json.Unmarshal([]byte(payload), &input); jsonErr != nil {
		// Return ok even on parse failure.
		return writeJSON(out, okOutput{OK: true})
	}

	// Normalise file_path to a repository-relative path (hides usernames etc.).
	// Using filepath.Rel also handles Windows path separators (\).
	rawPath := input.FilePath
	if rawPath == "" {
		rawPath = "unknown"
	}
	relPath := rawPath
	if rawPath != "unknown" && projectRoot != "" {
		if rel, relErr := filepath.Rel(projectRoot, rawPath); relErr == nil {
			relPath = rel
		}
	}

	changeType := input.ChangeType
	if changeType == "" {
		changeType = "modified"
	}

	ts := time.Now().UTC().Format(time.RFC3339)

	// Record to the timeline.
	timelineFile := filepath.Join(projectRoot, ".claude", "state", "breezing-timeline.jsonl")
	if mkdirErr := os.MkdirAll(filepath.Dir(timelineFile), 0o755); mkdirErr == nil {
		event := map[string]string{
			"type":        "config_change",
			"timestamp":   ts,
			"file_path":   relPath,
			"change_type": changeType,
		}
		if eventData, marshalErr := json.Marshal(event); marshalErr == nil {
			f, openErr := os.OpenFile(timelineFile, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o644)
			if openErr == nil {
				fmt.Fprintf(f, "%s\n", eventData)
				f.Close()
			}
		}
	}

	return writeJSON(out, okOutput{OK: true})
}

// isBreezingActive reads breezing.json and checks whether status is active or running.
func isBreezingActive(stateFile string) bool {
	data, err := os.ReadFile(stateFile)
	if err != nil {
		return false
	}
	var state breezingState
	if err := json.Unmarshal(data, &state); err != nil {
		return false
	}
	return state.Status == "active" || state.Status == "running"
}
