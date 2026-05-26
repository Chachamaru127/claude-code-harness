package hookhandler

// notification_handler.go
// Go port of notification-handler.sh.
//
// Records Notification events (permission_prompt, idle_prompt, auth_success, etc.)
// to .claude/state/notification-events.jsonl.
// The notification handler never blocks (always approves).

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"time"
)

// notificationInput is the stdin JSON for Notification hooks.
type notificationInput struct {
	NotificationType string `json:"notification_type"`
	Type             string `json:"type"`
	Matcher          string `json:"matcher"`
	SessionID        string `json:"session_id"`
	AgentType        string `json:"agent_type"`
}

// notificationLogEntry is a single entry in notification-events.jsonl.
type notificationLogEntry struct {
	Event            string `json:"event"`
	NotificationType string `json:"notification_type"`
	SessionID        string `json:"session_id"`
	AgentType        string `json:"agent_type"`
	Timestamp        string `json:"timestamp"`
}

// HandleNotification is the Go port of notification-handler.sh.
//
// Called on Notification hooks, it records notification events to
// .claude/state/notification-events.jsonl.
// The notification handler always returns approve (non-blocking).
func HandleNotification(in io.Reader, out io.Writer) error {
	data, err := io.ReadAll(in)
	if err != nil || len(strings.TrimSpace(string(data))) == 0 {
		// No input: normal exit (equivalent to exit 0).
		return nil
	}

	var input notificationInput
	if jsonErr := json.Unmarshal(data, &input); jsonErr != nil {
		// Pass through even on parse failure (notification handler does not block).
		return nil
	}

	// Resolve notification_type (fallback to type / matcher).
	notificationType := input.NotificationType
	if notificationType == "" {
		notificationType = input.Type
	}
	if notificationType == "" {
		notificationType = input.Matcher
	}

	// Ensure the state directory exists.
	stateDir := resolveNotificationStateDir()
	if mkErr := ensureNotificationStateDir(stateDir); mkErr != nil {
		// Pass through even if directory creation fails.
		return nil
	}

	// Write to JSONL.
	logFile := filepath.Join(stateDir, "notification-events.jsonl")
	entry := notificationLogEntry{
		Event:            "notification",
		NotificationType: notificationType,
		SessionID:        input.SessionID,
		AgentType:        input.AgentType,
		Timestamp:        time.Now().UTC().Format(time.RFC3339),
	}
	if logErr := appendNotificationLog(logFile, entry); logErr != nil {
		// Ignore log write failures.
		_ = logErr
	}

	// Breezing バックグラウンド Worker に関する重要通知を stderr に出力（デバッグ用）
	if notificationType == "permission_prompt" && input.AgentType != "" {
		fmt.Fprintf(os.Stderr, "Notification: permission_prompt for agent_type=%s\n", input.AgentType)
	}
	if notificationType == "elicitation_dialog" && input.AgentType != "" {
		fmt.Fprintf(os.Stderr,
			"Notification: elicitation_dialog for agent_type=%s (auto-skipped in background)\n",
			input.AgentType)
	}

	// terminalSequence 出力 (CC 2.1.141+, opt-in via HARNESS_TERMINAL_NOTIFY)
	// permission_prompt / elicitation_dialog のように operator の注意を喚起したい通知では
	// Claude Code が controlling terminal なしでも desktop 通知 / window title / bell を発火できる。
	// 詳細: .claude/rules/hooks-2.1.139-plus.md
	if title, body, ok := notificationTerminalTitleBody(notificationType, input.AgentType); ok {
		seq := BuildTerminalSequence(title, body)
		if seq != "" {
			resp := map[string]interface{}{
				"decision":         "approve",
				"reason":           "notification logged",
				"terminalSequence": seq,
			}
			if writeErr := writeJSON(out, resp); writeErr != nil {
				return writeErr
			}
			return nil
		}
	}

	// 通知ハンドラは常に正常終了（approve）
	return nil
}

// notificationTerminalTitleBody は terminalSequence に使う title/body を notification_type から組み立てる。
// 既知の type 以外は ok=false を返し、terminalSequence は emit されない。
func notificationTerminalTitleBody(notificationType, agentType string) (string, string, bool) {
	agent := agentType
	if agent == "" {
		agent = "main"
	}
	switch notificationType {
	case "permission_prompt":
		return "Claude Code: permission prompt", agent + " waiting for approval", true
	case "elicitation_dialog":
		return "Claude Code: elicitation", agent + " MCP elicitation", true
	case "idle_prompt":
		return "Claude Code: idle", "session idle", true
	case "auth_success":
		return "Claude Code: auth success", "", true
	default:
		return "", "", false
	}
}

// resolveNotificationStateDir は環境変数を考慮してステートディレクトリを返す。
// CLAUDE_PLUGIN_DATA が設定されている場合はプロジェクトスコープに切り替える。
func resolveNotificationStateDir() string {
	pluginData := os.Getenv("CLAUDE_PLUGIN_DATA")
	if pluginData != "" {
		projectRoot := os.Getenv("PROJECT_ROOT")
		if projectRoot == "" {
			cwd, err := os.Getwd()
			if err == nil {
				projectRoot = cwd
			}
		}
		hash := shortHashNotification(projectRoot)
		return filepath.Join(pluginData, "projects", hash)
	}

	projectRoot := os.Getenv("PROJECT_ROOT")
	if projectRoot == "" {
		cwd, err := os.Getwd()
		if err == nil {
			projectRoot = cwd
		}
	}
	return filepath.Join(projectRoot, ".claude", "state")
}

// ensureNotificationStateDir はディレクトリを作成し、シンボリックリンクを拒否する。
func ensureNotificationStateDir(stateDir string) error {
	parent := filepath.Dir(stateDir)

	// シンボリックリンクチェック（セキュリティ）
	if isSymlink(parent) || isSymlink(stateDir) {
		return fmt.Errorf("symlinked state path refused: %s", stateDir)
	}

	if mkErr := os.MkdirAll(stateDir, 0o700); mkErr != nil {
		return fmt.Errorf("mkdir state dir: %w", mkErr)
	}

	// 作成後も検証
	info, statErr := os.Lstat(stateDir)
	if statErr != nil {
		return fmt.Errorf("stat state dir: %w", statErr)
	}
	if info.Mode()&os.ModeSymlink != 0 {
		return fmt.Errorf("state dir is symlink: %s", stateDir)
	}
	return nil
}

// appendNotificationLog は JSONL ファイルに1エントリ追記し、ローテーションする。
func appendNotificationLog(logFile string, entry notificationLogEntry) error {
	// シンボリックリンクチェック
	if isSymlink(logFile) {
		return fmt.Errorf("symlinked log file refused: %s", logFile)
	}

	entryJSON, err := json.Marshal(entry)
	if err != nil {
		return fmt.Errorf("marshal log entry: %w", err)
	}

	f, err := os.OpenFile(logFile, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o644)
	if err != nil {
		return fmt.Errorf("open log file: %w", err)
	}
	defer f.Close()

	if _, writeErr := fmt.Fprintf(f, "%s\n", entryJSON); writeErr != nil {
		return fmt.Errorf("write log entry: %w", writeErr)
	}

	// ローテーション: 500行超なら400行に切り詰め
	return rotateJSONL(logFile, 500, 400)
}

// shortHashNotification はプロジェクトルートパスの短縮ハッシュ（12文字）を返す。
// bash の shasum -a 256 | cut -c1-12 と同等。
func shortHashNotification(input string) string {
	if input == "" {
		return "default"
	}
	// 簡易ハッシュ: FNV-1a ベース（外部依存なし）
	var h uint64 = 14695981039346656037
	for i := 0; i < len(input); i++ {
		h ^= uint64(input[i])
		h *= 1099511628211
	}
	return fmt.Sprintf("%012x", h&0xffffffffffff)
}
