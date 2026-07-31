// Package auditlog records guardrail and runtime-floor decisions without
// persisting raw commands or file paths.
package auditlog

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/Chachamaru127/claude-code-harness/go/pkg/hookproto"
)

const (
	schemaVersion = "guardrail-fire.v1"
	auditLogPath  = ".claude/state/audit/guardrail-fires.jsonl"
)

type guardrailFire struct {
	SchemaVersion string `json:"schema_version"`
	Timestamp     string `json:"ts"`
	Host          string `json:"host,omitempty"`
	Tool          string `json:"tool"`
	RuleID        string `json:"rule_id"`
	Category      string `json:"category,omitempty"`
	Decision      string `json:"decision"`
	CommandSHA256 string `json:"command_sha256,omitempty"`
	CommandLen    *int   `json:"command_len,omitempty"`
}

// Record appends one decision to the project audit log. Every filesystem and
// serialization failure is intentionally ignored so observability cannot alter
// the guardrail decision.
func Record(projectRoot string, input hookproto.HookInput, result hookproto.HookResult) {
	decision, ok := auditDecision(result)
	if !ok {
		return
	}

	entry := guardrailFire{
		SchemaVersion: schemaVersion,
		Timestamp:     time.Now().UTC().Format(time.RFC3339),
		Host:          input.Host,
		Tool:          input.ToolName,
		RuleID:        result.RuleID,
		Decision:      decision,
	}

	entry.Category = runtimeFloorCategory(result.RuleID)
	if !isSensitiveCategory(entry.Category) {
		if subject := auditSubject(input); subject != "" {
			sum := sha256.Sum256([]byte(subject))
			entry.CommandSHA256 = hex.EncodeToString(sum[:])
			commandLen := len([]byte(subject))
			entry.CommandLen = &commandLen
		}
	}

	line, err := json.Marshal(entry)
	if err != nil {
		return
	}

	logFile := filepath.Join(projectRoot, filepath.FromSlash(auditLogPath))
	if err := os.MkdirAll(filepath.Dir(logFile), 0o700); err != nil {
		return
	}

	_ = WithFileLock(logFile+".lock", func() error {
		file, err := os.OpenFile(logFile, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0o600)
		if err != nil {
			return err
		}
		defer file.Close()

		line = append(line, '\n')
		_, err = file.Write(line)
		return err
	})
}

func auditDecision(result hookproto.HookResult) (string, bool) {
	switch result.Decision {
	case hookproto.DecisionDeny:
		return "deny", true
	case hookproto.DecisionAsk:
		return "ask", true
	case hookproto.DecisionDefer:
		return "defer", true
	case hookproto.DecisionApprove:
		if result.SystemMessage != "" {
			return "warn", true
		}
	}
	return "", false
}

func runtimeFloorCategory(ruleID string) string {
	const prefix = "RUNTIME_FLOOR:"
	if !strings.HasPrefix(ruleID, prefix) {
		return ""
	}
	return strings.TrimPrefix(ruleID, prefix)
}

func isSensitiveCategory(category string) bool {
	return category == "secret-read" || category == "money-billing"
}

func auditSubject(input hookproto.HookInput) string {
	if command, ok := input.ToolInput["command"].(string); ok {
		return command
	}
	if filePath, ok := input.ToolInput["file_path"].(string); ok {
		return filePath
	}
	return ""
}
