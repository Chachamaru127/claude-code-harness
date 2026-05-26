package hookhandler

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"strings"
	"time"
)

// elicitationInput is the stdin JSON payload for the Elicitation hook.
type elicitationInput struct {
	MCPServerName string `json:"mcp_server_name"`
	ServerName    string `json:"server_name"`
	Matcher       string `json:"matcher"`
	ElicitationID string `json:"elicitation_id"`
	ID            string `json:"id"`
	Message       string `json:"message"`
}

// elicitationLogEntry is the entry written to elicitation-events.jsonl.
type elicitationLogEntry struct {
	Event           string `json:"event"`
	MCPServer       string `json:"mcp_server"`
	ElicitationID   string `json:"elicitation_id"`
	Message         string `json:"message"`
	BreezingSession string `json:"breezing_session"`
	Timestamp       string `json:"timestamp"`
}

// elicitationDecision is the response for the Elicitation hook.
type elicitationDecision struct {
	Decision string `json:"decision"`
	Reason   string `json:"reason"`
}

// ElicitationHandler is the Go port of scripts/hook-handlers/elicitation-handler.sh.
//
// On Elicitation events it logs the MCP elicitation request, then automatically
// skips (deny) for Breezing Workers (background, no UI) and passes through
// (allow) for normal sessions.
//
// Logs are written to .claude/state/elicitation-events.jsonl.
type ElicitationHandler struct {
	// ProjectRoot is the path to the project root. Resolved from env vars/CWD when empty.
	ProjectRoot string
	// HarnessMemClient is the DI for harness-mem integration in tests. Uses the default client when nil.
	HarnessMemClient *MemoryBridgeClient
}

// Handle processes the Elicitation hook.
func (h *ElicitationHandler) Handle(in io.Reader, out io.Writer) error {
	data, err := io.ReadAll(in)
	if err != nil || len(strings.TrimSpace(string(data))) == 0 {
		return writeJSON(out, elicitationDecision{
			Decision: "approve",
			Reason:   "Elicitation: no payload",
		})
	}

	var input elicitationInput
	if jsonErr := json.Unmarshal(data, &input); jsonErr != nil {
		return writeJSON(out, elicitationDecision{
			Decision: "approve",
			Reason:   "Elicitation: no payload",
		})
	}

	// Normalise fields (equivalent to the // fallback in the bash version).
	mcpServer := firstNonEmpty(input.MCPServerName, input.ServerName, input.Matcher)
	elicitationID := firstNonEmpty(input.ElicitationID, input.ID)
	message := input.Message

	// Resolve the project root.
	projectRoot := h.ProjectRoot
	if projectRoot == "" {
		projectRoot = resolveProjectRoot()
	}
	stateDir := projectRoot + "/.claude/state"
	logFile := stateDir + "/elicitation-events.jsonl"

	// Log the event.
	if err := os.MkdirAll(stateDir, 0o700); err == nil {
		ts := time.Now().UTC().Format(time.RFC3339)
		breezingSession := os.Getenv("HARNESS_BREEZING_SESSION_ID")
		entry := elicitationLogEntry{
			Event:           "elicitation",
			MCPServer:       mcpServer,
			ElicitationID:   elicitationID,
			Message:         message,
			BreezingSession: breezingSession,
			Timestamp:       ts,
		}
		if lineData, merr := json.Marshal(entry); merr == nil {
			f, ferr := os.OpenFile(logFile, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o644)
			if ferr == nil {
				fmt.Fprintf(f, "%s\n", lineData)
				f.Close()
				_ = rotateJSONL(logFile, 500, 400)
			}
		}
	}

	event := newElicitationRequestEvent(mcpServer, elicitationID, message)
	if _, err := appendElicitationEvent(projectRoot, event); err == nil {
		client := h.HarnessMemClient
		if client == nil {
			client = defaultMemBridgeClient
		}
		client.postElicitationEvent(projectRoot, event)
	}

	// During a Breezing session, auto-skip (background Workers cannot interact with the UI).
	breezingSession := os.Getenv("HARNESS_BREEZING_SESSION_ID")
	if breezingSession != "" {
		reason := fmt.Sprintf(
			"Breezing session (%s): background agent cannot interact with elicitation UI",
			breezingSession,
		)
		return writeJSON(out, elicitationDecision{
			Decision: "deny",
			Reason:   reason,
		})
	}

	// Normal session: pass through (user responds interactively).
	return writeJSON(out, elicitationDecision{
		Decision: "approve",
		Reason:   "Elicitation: forwarding to user",
	})
}
