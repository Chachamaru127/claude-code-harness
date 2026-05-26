package event

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
)

// NotificationHandler is the Notification hook handler.
// Fires when Claude Code issues a notification, and records the event to a JSONL log.
//
// Shell version: scripts/hook-handlers/notification-handler.sh
type NotificationHandler struct {
	// StateDir is the destination for log files.
	// If empty, uses ResolveStateDir(projectRoot).
	StateDir string
}

// notificationInput is the stdin JSON for the Notification hook.
type notificationInput struct {
	NotificationType string `json:"notification_type,omitempty"`
	Type             string `json:"type,omitempty"`
	Matcher          string `json:"matcher,omitempty"`
	SessionID        string `json:"session_id,omitempty"`
	AgentType        string `json:"agent_type,omitempty"`
	CWD              string `json:"cwd,omitempty"`
}

// notificationLogEntry is the entry written to notification-events.jsonl.
type notificationLogEntry struct {
	Event            string `json:"event"`
	NotificationType string `json:"notification_type"`
	SessionID        string `json:"session_id"`
	AgentType        string `json:"agent_type"`
	Timestamp        string `json:"timestamp"`
}

// Handle reads a Notification payload from stdin,
// records it to the log, and returns nothing to stdout.
// Errors are ignored and processing continues (to avoid impacting Breezing background operation).
func (h *NotificationHandler) Handle(r io.Reader, w io.Writer) error {
	data, err := io.ReadAll(r)
	if err != nil || len(data) == 0 {
		return nil
	}

	var inp notificationInput
	if err := json.Unmarshal(data, &inp); err != nil {
		return nil
	}

	// Normalize notification_type (the same information may appear in multiple fields)
	notificationType := inp.NotificationType
	if notificationType == "" {
		notificationType = inp.Type
	}
	if notificationType == "" {
		notificationType = inp.Matcher
	}

	// Determine the state directory
	projectRoot := inp.CWD
	if projectRoot == "" {
		projectRoot = resolveProjectRoot(data)
	}

	stateDir := h.StateDir
	if stateDir == "" {
		stateDir = ResolveStateDir(projectRoot)
	}

	if err := EnsureStateDir(stateDir); err != nil {
		return nil
	}

	logFile := filepath.Join(stateDir, "notification-events.jsonl")
	if isSymlink(logFile) {
		return nil
	}

	entry := notificationLogEntry{
		Event:            "notification",
		NotificationType: notificationType,
		SessionID:        inp.SessionID,
		AgentType:        inp.AgentType,
		Timestamp:        Now(),
	}

	h.appendLog(logFile, entry)

	// Detect important notifications for Breezing background Workers.
	// No output to stdout (log recording only).
	h.handleBreezingNotifications(notificationType, inp.AgentType)

	// Notification hook requires no output (approve is implicit)
	_ = w
	return nil
}

// appendLog appends one entry to the notification log.
func (h *NotificationHandler) appendLog(path string, entry notificationLogEntry) {
	data, err := json.Marshal(entry)
	if err != nil {
		return
	}

	f, err := os.OpenFile(path, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0600)
	if err != nil {
		return
	}
	defer f.Close()
	_, _ = fmt.Fprintf(f, "%s\n", data)

	RotateJSONL(path)
}

// handleBreezingNotifications outputs important notifications for Breezing
// background Workers to stderr (for debugging and observability).
func (h *NotificationHandler) handleBreezingNotifications(notificationType, agentType string) {
	if agentType == "" {
		return
	}

	switch notificationType {
	case "permission_prompt":
		// Worker cannot respond to permission dialogs
		fmt.Fprintf(os.Stderr,
			"Notification: permission_prompt for agent_type=%s\n", agentType)
	case "elicitation_dialog":
		// Input request from MCP server (v2.1.76+)
		// Background Workers cannot respond to Elicitation forms
		fmt.Fprintf(os.Stderr,
			"Notification: elicitation_dialog for agent_type=%s (auto-skipped in background)\n",
			agentType)
	}
}
