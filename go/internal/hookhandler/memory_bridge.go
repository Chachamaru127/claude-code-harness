package hookhandler

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"time"
)

// MemoryBridgeClient handles HTTP communication with the harness-mem daemon.
// Operates fail-silent when harness-mem is not running; only the JSONL log is recorded.
type MemoryBridgeClient struct {
	// HTTPClient is for DI in tests. When nil, a default client with a 2s timeout is used.
	HTTPClient *http.Client
	// BaseURL is a test override. When empty, it is constructed from environment variables.
	BaseURL string
}

// defaultMemBridgeClient is the package-level default instance.
var defaultMemBridgeClient = &MemoryBridgeClient{}

// memoryBridgeEvent represents a dispatched memory bridge event written to the
// event log. Actual MCP calls are deferred to future implementation.
type memoryBridgeEvent struct {
	Event     string `json:"event"`
	SessionID string `json:"session_id,omitempty"`
	CWD       string `json:"cwd,omitempty"`
	Timestamp string `json:"timestamp"`
}

// memoryBridgeInput is the minimal JSON payload expected on stdin.
type memoryBridgeInput struct {
	SessionID     string `json:"session_id"`
	CWD           string `json:"cwd"`
	HookEventName string `json:"hook_event_name"`
}

// validTargets lists the recognised dispatch targets.
var validTargets = map[string]bool{
	"session-start": true,
	"user-prompt":   true,
	"post-tool-use": true,
	"stop":          true,
	"codex-notify":  true,
}

// bridgeToEventType maps hook target names to harness-mem event_type values.
var bridgeToEventType = map[string]string{
	"session-start": "session_start",
	"user-prompt":   "user_prompt",
	"post-tool-use": "tool_use",
	"codex-notify":  "checkpoint",
	// "stop" uses /v1/sessions/finalize and is therefore not included in this map.
}

// --- harness-mem API request types ---

type harnessMemEvent struct {
	Platform        string   `json:"platform"`
	Project         string   `json:"project"`
	SessionID       string   `json:"session_id"`
	EventType       string   `json:"event_type"`
	TS              string   `json:"ts,omitempty"`
	SchemaVersion   string   `json:"schema_version,omitempty"`
	ObservationType string   `json:"observation_type,omitempty"`
	TaskID          string   `json:"task_id,omitempty"`
	RubricID        string   `json:"rubric_id,omitempty"`
	RewardScore     *float64 `json:"reward_score,omitempty"`
	Verdict         string   `json:"verdict,omitempty"`
	PrivacyTags     []string `json:"privacy_tags,omitempty"`
	EvidenceRefs    []string `json:"evidence_refs,omitempty"`
}

type harnessMemRecordRequest struct {
	Event harnessMemEvent `json:"event"`
}

type harnessMemFinalizeRequest struct {
	SessionID string `json:"session_id"`
	Platform  string `json:"platform,omitempty"`
	Project   string `json:"project,omitempty"`
}

// HandleMemoryBridge ports scripts/hook-handlers/memory-bridge.sh.
//
// Dispatches one of the five known event targets (session-start, user-prompt,
// post-tool-use, stop, codex-notify). If harness-mem is running on localhost,
// events are also POSTed to the HTTP API. Unknown targets exit 0 (fail-open).
func HandleMemoryBridge(in io.Reader, out io.Writer) error {
	return defaultMemBridgeClient.Handle(in, out)
}

// Handle processes a memory bridge event: validates the target, writes the
// JSONL log, POSTs to harness-mem (best-effort), and returns approve.
func (c *MemoryBridgeClient) Handle(in io.Reader, out io.Writer) error {
	data, err := io.ReadAll(in)
	if err != nil {
		return approveMemoryBridge(out, "")
	}

	var input memoryBridgeInput
	if jsonErr := json.Unmarshal(data, &input); jsonErr != nil {
		return approveMemoryBridge(out, "")
	}

	target := input.HookEventName
	if !validTargets[target] {
		// Unknown target: log to stderr (matching bash `echo ... >&2; exit 0`)
		fmt.Fprintf(os.Stderr, "[claude-code-harness] unknown memory bridge target: %s\n", target)
		return approveMemoryBridge(out, target)
	}

	// Log the event (always, regardless of harness-mem availability).
	if logErr := logMemoryBridgeEvent(target, input.SessionID, input.CWD); logErr != nil {
		// Non-fatal: the hook must not block on log failures.
		fmt.Fprintf(os.Stderr, "[claude-code-harness] memory-bridge log error: %v\n", logErr)
	}

	// POST to harness-mem (best-effort, sync with 2s timeout).
	// K-1.2: validate before sending to long-term memory.
	if err := validateBridgeInput(input); err != nil {
		fmt.Fprintf(os.Stderr, "[claude-code-harness] memory-bridge validation failed: %v\n", err)
	} else {
		c.postToHarnessMem(target, input)
	}

	return approveMemoryBridge(out, target)
}

// validateBridgeInput performs minimal schema validation before POSTing to harness-mem.
// Prevents invalid events from being promoted to long-term memory (K-1.2: audit before saving memory).
func validateBridgeInput(input memoryBridgeInput) error {
	if input.SessionID == "" {
		return fmt.Errorf("session_id is required")
	}
	if len(input.SessionID) > 256 {
		return fmt.Errorf("session_id too long (%d chars, max 256)", len(input.SessionID))
	}
	if input.CWD == "" {
		return fmt.Errorf("cwd is required")
	}
	return nil
}

// postToHarnessMem HTTP POSTs an event to the harness-mem daemon.
// Connection failures, timeouts, and error responses are all silently ignored (stderr log only).
// In environments where harness-mem is not running, returns immediately with a connection refused error.
func (c *MemoryBridgeClient) postToHarnessMem(target string, input memoryBridgeInput) {
	baseURL := c.BaseURL
	if baseURL == "" {
		host := os.Getenv("HARNESS_MEM_HOST")
		if host == "" {
			host = "127.0.0.1"
		}
		port := os.Getenv("HARNESS_MEM_PORT")
		if port == "" {
			port = "37888"
		}
		baseURL = "http://" + host + ":" + port
	}

	project := filepath.Base(input.CWD)
	if project == "" || project == "." || project == "/" {
		project = "unknown"
	}

	var (
		url     string
		payload interface{}
	)

	if target == "stop" {
		url = baseURL + "/v1/sessions/finalize"
		payload = harnessMemFinalizeRequest{
			SessionID: input.SessionID,
			Platform:  "claude",
			Project:   project,
		}
	} else {
		url = baseURL + "/v1/events/record"
		eventType := bridgeToEventType[target]
		if eventType == "" {
			eventType = target // fallback (should not happen for valid targets)
		}
		payload = harnessMemRecordRequest{
			Event: harnessMemEvent{
				Platform:  "claude",
				Project:   project,
				SessionID: input.SessionID,
				EventType: eventType,
				TS:        time.Now().UTC().Format(time.RFC3339),
			},
		}
	}

	body, err := json.Marshal(payload)
	if err != nil {
		return
	}

	client := c.HTTPClient
	if client == nil {
		client = &http.Client{Timeout: 2 * time.Second}
	}

	req, err := http.NewRequest("POST", url, bytes.NewReader(body))
	if err != nil {
		return
	}
	req.Header.Set("Content-Type", "application/json")

	if token := os.Getenv("HARNESS_MEM_ADMIN_TOKEN"); token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}

	resp, err := client.Do(req)
	if err != nil {
		// Connection refused, timeout, etc. — expected when harness-mem is not running.
		fmt.Fprintf(os.Stderr, "[claude-code-harness] harness-mem POST failed (target=%s): %v\n", target, err)
		return
	}
	defer resp.Body.Close()

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		fmt.Fprintf(os.Stderr, "[claude-code-harness] harness-mem HTTP %d for %s\n", resp.StatusCode, target)
	}
}

// postElicitationEvent forwards elicitation-event.v1 through the public
// harness-mem HTTP contract only. It never reads harness-mem storage and it
// silently falls back to the local ledger when the daemon is absent or old.
func (c *MemoryBridgeClient) postElicitationEvent(projectRoot string, event ElicitationEvent) {
	baseURL := c.BaseURL
	if baseURL == "" {
		host := os.Getenv("HARNESS_MEM_HOST")
		if host == "" {
			host = "127.0.0.1"
		}
		port := os.Getenv("HARNESS_MEM_PORT")
		if port == "" {
			port = "37888"
		}
		baseURL = "http://" + host + ":" + port
	}

	project := filepath.Base(projectRoot)
	if project == "" || project == "." || project == "/" {
		project = "unknown"
	}

	payload := harnessMemRecordRequest{
		Event: harnessMemEvent{
			Platform:        "claude",
			Project:         project,
			SessionID:       event.RunID,
			EventType:       "elicitation_event",
			TS:              event.Timestamp,
			SchemaVersion:   event.SchemaVersion,
			ObservationType: event.EventKind,
			TaskID:          event.TaskID,
			RubricID:        event.RubricID,
			RewardScore:     event.RewardScore,
			Verdict:         event.Verdict,
			PrivacyTags:     event.PrivacyTags,
			EvidenceRefs:    event.EvidenceRefs,
		},
	}

	body, err := json.Marshal(payload)
	if err != nil {
		return
	}

	client := c.HTTPClient
	if client == nil {
		client = &http.Client{Timeout: 2 * time.Second}
	}

	req, err := http.NewRequest("POST", baseURL+"/v1/events/record", bytes.NewReader(body))
	if err != nil {
		return
	}
	req.Header.Set("Content-Type", "application/json")
	if token := os.Getenv("HARNESS_MEM_ADMIN_TOKEN"); token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}

	resp, err := client.Do(req)
	if err != nil {
		return
	}
	defer resp.Body.Close()
}

// approveMemoryBridge writes the standard approve response.
func approveMemoryBridge(out io.Writer, target string) error {
	reason := "memory-bridge: ok"
	if target != "" && validTargets[target] {
		reason = fmt.Sprintf("memory-bridge: %s dispatched", target)
	}
	resp := map[string]string{"decision": "approve", "reason": reason}
	data, err := json.Marshal(resp)
	if err != nil {
		return err
	}
	_, err = fmt.Fprintf(out, "%s\n", data)
	return err
}

// logMemoryBridgeEvent appends an event entry to the memory bridge event log.
// The log file is created at .claude/state/memory-bridge-events.jsonl.
func logMemoryBridgeEvent(event, sessionID, cwd string) error {
	projectRoot := resolveProjectRoot()
	stateDir := projectRoot + "/.claude/state"
	if err := os.MkdirAll(stateDir, 0o755); err != nil {
		return err
	}

	entry := memoryBridgeEvent{
		Event:     event,
		SessionID: sessionID,
		CWD:       cwd,
		Timestamp: time.Now().UTC().Format(time.RFC3339),
	}
	data, err := json.Marshal(entry)
	if err != nil {
		return err
	}

	logPath := stateDir + "/memory-bridge-events.jsonl"
	f, err := os.OpenFile(logPath, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o644)
	if err != nil {
		return err
	}
	defer f.Close()

	_, err = fmt.Fprintf(f, "%s\n", data)
	return err
}
