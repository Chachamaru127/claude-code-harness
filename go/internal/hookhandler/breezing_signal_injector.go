package hookhandler

import (
	"bufio"
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"time"
)

// BreezingSignalInjectorHandler is the UserPromptSubmit hook handler (breezing signal injection).
// Reads unconsumed signals from breezing-signals.jsonl and injects them as a systemMessage.
// Skipped when Breezing is not active.
//
// Shell version: scripts/hook-handlers/breezing-signal-injector.sh
type BreezingSignalInjectorHandler struct {
	// ProjectRoot is the path to the project root. Falls back to cwd when empty.
	ProjectRoot string
}

// breezingSignal represents one line in breezing-signals.jsonl.
type breezingSignal struct {
	Signal         string  `json:"signal"`
	Type           string  `json:"type"`
	Timestamp      string  `json:"timestamp"`
	ConsumedAt     *string `json:"consumed_at"`
	Conclusion     string  `json:"conclusion"`
	TriggerCommand string  `json:"trigger_command"`
	Reason         string  `json:"reason"`
	TaskID         string  `json:"task_id"`
}

// injectorResponse is the response for the BreezingSignalInjector hook.
type injectorResponse struct {
	SystemMessage string `json:"systemMessage,omitempty"`
}

// Handle reads (and discards) the payload from stdin and injects
// breezing signals as a systemMessage.
func (h *BreezingSignalInjectorHandler) Handle(r io.Reader, w io.Writer) error {
	// Discard stdin — this handler does not use the input.
	_, _ = io.ReadAll(r)

	projectRoot := h.ProjectRoot
	if projectRoot == "" {
		projectRoot, _ = os.Getwd()
	}

	stateDir := filepath.Join(projectRoot, ".claude", "state")
	activeFile := filepath.Join(stateDir, "breezing-active.json")
	signalsFile := filepath.Join(stateDir, "breezing-signals.jsonl")

	// Check whether a breezing session is active.
	if _, err := os.Stat(activeFile); os.IsNotExist(err) {
		// Outside a breezing session — skip (no output = equivalent to exit 0).
		return nil
	}

	// Check whether the signals file exists.
	if _, err := os.Stat(signalsFile); os.IsNotExist(err) {
		return nil
	}

	// Read unconsumed signals.
	unconsumedSignals, err := h.readUnconsumedSignals(signalsFile)
	if err != nil || len(unconsumedSignals) == 0 {
		return nil
	}

	// Format signals into message strings.
	var messageParts []string
	for _, sig := range unconsumedSignals {
		msg := h.formatSignalMessage(sig)
		if msg != "" {
			messageParts = append(messageParts, msg)
		}
	}

	if len(messageParts) == 0 {
		return nil
	}

	// Set consumed_at to mark the signals as consumed.
	_ = h.markSignalsConsumed(signalsFile)

	header := fmt.Sprintf("[breezing-signal-injector] %d unconsumed signal(s):\n", len(unconsumedSignals))
	fullMessage := header + strings.Join(messageParts, "")

	resp := injectorResponse{SystemMessage: fullMessage}
	return writeInjectorJSON(w, resp)
}

// readUnconsumedSignals returns signals from the JSONL file whose consumed_at is null.
func (h *BreezingSignalInjectorHandler) readUnconsumedSignals(signalsFile string) ([]breezingSignal, error) {
	f, err := os.Open(signalsFile)
	if err != nil {
		return nil, err
	}
	defer f.Close()

	var result []breezingSignal
	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" {
			continue
		}

		var sig breezingSignal
		if err := json.Unmarshal([]byte(line), &sig); err != nil {
			continue
		}

		if sig.ConsumedAt == nil {
			result = append(result, sig)
		}
	}
	return result, scanner.Err()
}

// formatSignalMessage converts a signal into a message string.
func (h *BreezingSignalInjectorHandler) formatSignalMessage(sig breezingSignal) string {
	signalType := sig.Signal
	if signalType == "" {
		signalType = sig.Type
	}
	if signalType == "" {
		signalType = "unknown"
	}

	switch signalType {
	case "ci_failure_detected":
		conclusion := sig.Conclusion
		if conclusion == "" {
			conclusion = "unknown"
		}
		triggerCmd := sig.TriggerCommand
		return fmt.Sprintf(
			"[SIGNAL:ci_failure_detected] CI failed (%s). Trigger: %s. Consider using the ci-cd-fixer agent for automatic remediation.\n",
			conclusion, triggerCmd,
		)
	case "retake_requested":
		return fmt.Sprintf(
			"[SIGNAL:retake_requested] Redo requested for task #%s. Reason: %s\n",
			sig.TaskID, sig.Reason,
		)
	case "reviewer_approved":
		return fmt.Sprintf(
			"[SIGNAL:reviewer_approved] Task #%s was approved by the reviewer.\n",
			sig.TaskID,
		)
	case "escalation_required":
		return fmt.Sprintf(
			"[SIGNAL:escalation_required] Escalation required for task #%s. Reason: %s\n",
			sig.TaskID, sig.Reason,
		)
	default:
		raw, _ := json.Marshal(sig)
		return fmt.Sprintf("[SIGNAL:%s] %s\n", signalType, string(raw))
	}
}

// markSignalsConsumed overwrites signalsFile, setting consumed_at on all unconsumed signals.
// Locking is achieved via an atomic directory-creation operation.
func (h *BreezingSignalInjectorHandler) markSignalsConsumed(signalsFile string) error {
	stateDir := filepath.Dir(signalsFile)
	lockDir := filepath.Join(stateDir, ".breezing-signals.lock")

	// Acquire the lock (maximum 2 seconds, 100 ms polling).
	const maxRetries = 20
	acquired := false
	for i := 0; i < maxRetries; i++ {
		if err := os.Mkdir(lockDir, 0700); err == nil {
			acquired = true
			break
		}
		time.Sleep(100 * time.Millisecond)
	}
	if !acquired {
		return fmt.Errorf("could not acquire lock")
	}
	defer func() { _ = os.Remove(lockDir) }()

	// Read the file, add consumed_at, and rewrite it.
	f, err := os.Open(signalsFile)
	if err != nil {
		return err
	}

	consumedTS := time.Now().UTC().Format(time.RFC3339)
	var newLines bytes.Buffer
	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" {
			continue
		}

		var sig map[string]interface{}
		if err := json.Unmarshal([]byte(line), &sig); err != nil {
			newLines.WriteString(line + "\n")
			continue
		}

		// Stamp entries whose consumed_at is null.
		if sig["consumed_at"] == nil {
			sig["consumed_at"] = consumedTS
		}

		updated, err := json.Marshal(sig)
		if err != nil {
			newLines.WriteString(line + "\n")
			continue
		}
		newLines.Write(updated)
		newLines.WriteByte('\n')
	}
	f.Close()

	if err := scanner.Err(); err != nil {
		return err
	}

	return os.WriteFile(signalsFile, newLines.Bytes(), 0600)
}

// writeInjectorJSON writes v as JSON to w.
func writeInjectorJSON(w io.Writer, v interface{}) error {
	data, err := json.Marshal(v)
	if err != nil {
		return fmt.Errorf("marshaling JSON: %w", err)
	}
	_, err = fmt.Fprintf(w, "%s\n", data)
	return err
}
