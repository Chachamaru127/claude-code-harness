package hookhandler

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"strings"
	"time"
)

// elicitationResultInput is the stdin JSON payload for the ElicitationResult hook.
type elicitationResultInput struct {
	MCPServerName string `json:"mcp_server_name"`
	ServerName    string `json:"server_name"`
	Matcher       string `json:"matcher"`
	ElicitationID string `json:"elicitation_id"`
	ID            string `json:"id"`
	ResultStatus  string `json:"result_status"`
	Status        string `json:"status"`
}

// elicitationResultLogEntry is the entry appended to elicitation-events.jsonl.
type elicitationResultLogEntry struct {
	Event         string `json:"event"`
	MCPServer     string `json:"mcp_server"`
	ElicitationID string `json:"elicitation_id"`
	ResultStatus  string `json:"result_status"`
	Timestamp     string `json:"timestamp"`
}

// ElicitationResultHandler is the Go port of scripts/hook-handlers/elicitation-result.sh.
//
// Receives ElicitationResult events and performs lightweight logging only.
// Results are appended to .claude/state/elicitation-events.jsonl.
// Always returns approve.
type ElicitationResultHandler struct {
	// ProjectRoot is the path to the project root. Resolved from env vars/CWD when empty.
	ProjectRoot string
	// HarnessMemClient is the DI for harness-mem integration in tests. Uses the default client when nil.
	HarnessMemClient *MemoryBridgeClient
}

// Handle は ElicitationResult フックを処理する。
func (h *ElicitationResultHandler) Handle(in io.Reader, out io.Writer) error {
	data, err := io.ReadAll(in)
	if err != nil || len(strings.TrimSpace(string(data))) == 0 {
		return writeJSON(out, elicitationDecision{
			Decision: "approve",
			Reason:   "ElicitationResult: no payload",
		})
	}

	var input elicitationResultInput
	if jsonErr := json.Unmarshal(data, &input); jsonErr != nil {
		return writeJSON(out, elicitationDecision{
			Decision: "approve",
			Reason:   "ElicitationResult: no payload",
		})
	}

	// フィールド正規化
	mcpServer := firstNonEmpty(input.MCPServerName, input.ServerName, input.Matcher)
	elicitationID := firstNonEmpty(input.ElicitationID, input.ID)
	resultStatus := firstNonEmpty(input.ResultStatus, input.Status)

	// プロジェクトルート解決
	projectRoot := h.ProjectRoot
	if projectRoot == "" {
		projectRoot = resolveProjectRoot()
	}
	stateDir := projectRoot + "/.claude/state"
	logFile := stateDir + "/elicitation-events.jsonl"

	// ログ記録
	if err := os.MkdirAll(stateDir, 0o700); err == nil {
		ts := time.Now().UTC().Format(time.RFC3339)
		entry := elicitationResultLogEntry{
			Event:         "elicitation_result",
			MCPServer:     mcpServer,
			ElicitationID: elicitationID,
			ResultStatus:  resultStatus,
			Timestamp:     ts,
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

	event := newElicitationResultEvent(mcpServer, elicitationID, resultStatus)
	if _, err := appendElicitationEvent(projectRoot, event); err == nil {
		client := h.HarnessMemClient
		if client == nil {
			client = defaultMemBridgeClient
		}
		client.postElicitationEvent(projectRoot, event)
	}

	// 常に approve
	return writeJSON(out, elicitationDecision{
		Decision: "approve",
		Reason:   "ElicitationResult tracked",
	})
}
