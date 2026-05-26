// Package hookhandler implements Go ports of the Harness hook handler scripts.
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

// autoBroadcastPatterns is the list of patterns targeted for auto-broadcast.
// Corresponds to AUTO_BROADCAST_PATTERNS in session-auto-broadcast.sh.
var autoBroadcastPatterns = []string{
	"src/api/",
	"src/types/",
	"src/interfaces/",
	"api/",
	"types/",
	"schema.prisma",
	"openapi",
	"swagger",
	".graphql",
}

// autoBroadcastInput is the stdin JSON passed to session-auto-broadcast.sh.
type autoBroadcastInput struct {
	SessionID string `json:"session_id"`
	CWD       string `json:"cwd"`
	ToolInput struct {
		FilePath string `json:"file_path"`
		Path     string `json:"path"`
	} `json:"tool_input"`
}

// autoBroadcastConfig is the configuration from .claude/sessions/auto-broadcast.json.
type autoBroadcastConfig struct {
	Enabled  *bool    `json:"enabled"`
	Patterns []string `json:"patterns"`
}

// postToolOutput is the response format for the PostToolUse hook.
type postToolOutput struct {
	HookSpecificOutput struct {
		HookEventName     string `json:"hookEventName"`
		AdditionalContext string `json:"additionalContext"`
	} `json:"hookSpecificOutput"`
}

// emptyPostToolOutput returns a PostToolUse response with no additional context.
func emptyPostToolOutput(w io.Writer) error {
	out := postToolOutput{}
	out.HookSpecificOutput.HookEventName = "PostToolUse"
	out.HookSpecificOutput.AdditionalContext = ""
	return writeJSON(w, out)
}

// HandleSessionAutoBroadcast is a Go port of session-auto-broadcast.sh.
//
// Called on PostToolUse Write/Edit events; writes important file changes
// as teammate notifications to .claude/sessions/broadcast.md.
// By writing to the same broadcast.md that inbox_check reads,
// the producer/consumer paths are kept consistent.
//
// Target patterns: src/api/, src/types/, src/interfaces/, api/, types/,
// schema.prisma, openapi, swagger, .graphql
func HandleSessionAutoBroadcast(in io.Reader, out io.Writer) error {
	// Read JSON from stdin
	data, err := io.ReadAll(in)
	if err != nil {
		return emptyPostToolOutput(out)
	}

	// Return empty response if there is no input
	if len(strings.TrimSpace(string(data))) == 0 {
		return emptyPostToolOutput(out)
	}

	var input autoBroadcastInput
	if err := json.Unmarshal(data, &input); err != nil {
		return emptyPostToolOutput(out)
	}

	if input.CWD != "" {
		info, statErr := os.Stat(input.CWD)
		if statErr != nil || !info.IsDir() {
			return emptyPostToolOutput(out)
		}
	}

	// Obtain file_path or path
	filePath := input.ToolInput.FilePath
	if filePath == "" {
		filePath = input.ToolInput.Path
	}

	// Exit if there is no file path
	if filePath == "" {
		return emptyPostToolOutput(out)
	}

	// Load the configuration file
	configFile := ".claude/sessions/auto-broadcast.json"
	enabled := true
	var customPatterns []string

	if cfgData, cfgErr := os.ReadFile(configFile); cfgErr == nil {
		var cfg autoBroadcastConfig
		if jsonErr := json.Unmarshal(cfgData, &cfg); jsonErr == nil {
			if cfg.Enabled != nil {
				enabled = *cfg.Enabled
			}
			customPatterns = cfg.Patterns
		}
	}

	// Exit if auto-broadcast is disabled
	if !enabled {
		return emptyPostToolOutput(out)
	}

	// Pattern matching (built-in patterns)
	matchedPattern := ""
	for _, pattern := range autoBroadcastPatterns {
		if strings.Contains(filePath, pattern) {
			matchedPattern = pattern
			break
		}
	}

	// Also check custom patterns
	if matchedPattern == "" {
		for _, pattern := range customPatterns {
			if pattern != "" && strings.Contains(filePath, pattern) {
				matchedPattern = pattern
				break
			}
		}
	}

	// Return empty response if no pattern matches
	if matchedPattern == "" {
		return emptyPostToolOutput(out)
	}

	// Execute broadcast: write to .claude/state/broadcast.md
	fileName := filepath.Base(filePath)
	if broadcastErr := writeBroadcastNotification(filePath, matchedPattern, input.SessionID); broadcastErr != nil {
		// Write failure is ignored (return empty response as fallback)
		return emptyPostToolOutput(out)
	}

	// Output the notification message
	o := postToolOutput{}
	o.HookSpecificOutput.HookEventName = "PostToolUse"
	o.HookSpecificOutput.AdditionalContext = fmt.Sprintf(
		"auto-broadcast: notified other sessions of change to %s", fileName,
	)
	return writeJSON(out, o)
}

// writeBroadcastNotification writes a teammate notification to .claude/sessions/broadcast.md.
// Writes to the same .claude/sessions/broadcast.md file that inbox_check reads.
// Header format: ## <RFC3339 timestamp> [<session_id_prefix_8chars>]
// This conforms to the format expected by the inbox_check broadcastMsgRe parser.
// Using sessionID as the sender allows inbox_check to filter out messages
// from the current session (consistent with bash version behavior).
func writeBroadcastNotification(filePath, matchedPattern, sessionID string) error {
	sessionsDir := ".claude/sessions"
	if err := os.MkdirAll(sessionsDir, 0o755); err != nil {
		return fmt.Errorf("mkdir sessions dir: %w", err)
	}

	broadcastFile := filepath.Join(sessionsDir, "broadcast.md")

	// Sender tag: use the first 12 characters of session_id (length matches bash version).
	// Falls back to "unknown" if empty (consistent with bash version behavior).
	senderTag := sessionID
	if senderTag == "" {
		senderTag = "unknown"
	} else if len(senderTag) > 12 {
		senderTag = senderTag[:12]
	}

	// Header format: ## <timestamp> [<session_id_prefix>]
	// Matches the format expected by the session-inbox-check.sh parser.
	ts := time.Now().UTC().Format("2006-01-02T15:04:05Z")
	entry := fmt.Sprintf("\n## %s [%s]\n📁 `%s` was changed: matched pattern '%s'\n",
		ts, senderTag, filePath, matchedPattern)

	f, err := os.OpenFile(broadcastFile, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o644)
	if err != nil {
		return fmt.Errorf("open broadcast file: %w", err)
	}
	defer f.Close()

	if _, err := f.WriteString(entry); err != nil {
		return fmt.Errorf("write broadcast entry: %w", err)
	}
	return nil
}
