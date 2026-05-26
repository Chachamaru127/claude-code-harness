// Package hookhandler implements Go ports of the bash hook handler scripts.
package hookhandler

import (
	"bufio"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"regexp"
	"strconv"
	"strings"
	"time"
)

// CheckInterval is the minimum duration between inbox checks (5 minutes).
const CheckInterval = 5 * time.Minute

// broadcastMsgRe matches broadcast.md message headers.
// Format: ## 2026-04-09T12:34:56Z [sender-prefix]
var broadcastMsgRe = regexp.MustCompile(`^## (\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z) \[([^\]]+)\]`)

// inboxLine represents a single line parsed from session-inbox.jsonl.
// Kept for backward compatibility in case inbox JSONL is present.
type inboxLine struct {
	Read bool   `json:"read"`
	Msg  string `json:"msg"`
}

type broadcastMessage struct {
	Line      string
	Timestamp time.Time
}

// inboxCheckInput is the stdin JSON payload for PreToolUse hooks.
type inboxCheckInput struct {
	SessionID string `json:"session_id"`
	CWD       string `json:"cwd"`
}

// preToolAllowOutput matches the hookSpecificOutput format for PreToolUse.
type preToolAllowOutput struct {
	HookSpecificOutput struct {
		HookEventName      string `json:"hookEventName"`
		PermissionDecision string `json:"permissionDecision"`
		AdditionalContext  string `json:"additionalContext,omitempty"`
	} `json:"hookSpecificOutput"`
}

// HandleInboxCheck ports pretooluse-inbox-check.sh.
//
// Reads .claude/sessions/broadcast.md (same source as the bash version),
// filters messages newer than the session's last-read timestamp, and if there
// are any injects them as additionalContext. A 5-minute throttle is enforced
// via .claude/sessions/.last_inbox_check.
//
// Session-specific read state is stored in
// .claude/sessions/.last_inbox_read_<session_id> — mirroring the bash
// version's get_last_read_file() logic.
func HandleInboxCheck(in io.Reader, out io.Writer) error {
	// Read stdin to extract session_id.
	data, _ := io.ReadAll(in)

	var inp inboxCheckInput
	_ = json.Unmarshal(data, &inp)

	// Resolve project root from CWD or environment, same pattern as bash script.
	projectRoot := resolveProjectRoot()

	sessionsDir := projectRoot + "/.claude/sessions"
	checkIntervalFile := sessionsDir + "/.last_inbox_check"
	broadcastFile := sessionsDir + "/broadcast.md"

	// Throttle: exit 0 (no output) if last check was < 5 minutes ago.
	if !throttleAllowed(checkIntervalFile) {
		return nil
	}

	// Update the last-check timestamp.
	if err := os.MkdirAll(sessionsDir, 0o755); err == nil {
		now := strconv.FormatInt(time.Now().Unix(), 10)
		_ = os.WriteFile(checkIntervalFile, []byte(now+"\n"), 0o644)
	}

	// If broadcast.md does not exist, nothing to do.
	if _, err := os.Stat(broadcastFile); os.IsNotExist(err) {
		return nil
	}

	// Determine session-specific last-read timestamp (bash: .last_read_<session_id>).
	lastReadTime := lastInboxReadTime(sessionsDir, inp.SessionID)

	// Read messages from broadcast.md newer than lastReadTime.
	// Pass session_id to filter out broadcasts from the current session.
	broadcastMessages, err := readBroadcastMessagesSinceDetailed(broadcastFile, 5, lastReadTime, inp.SessionID)
	messages := broadcastMessageLines(broadcastMessages)
	if err != nil || len(messages) == 0 {
		// Fallback: try session-inbox.jsonl for backward compatibility.
		inboxFile := projectRoot + "/.claude/state/session-inbox.jsonl"
		messages, _ = readUnreadMessages(inboxFile, 5)
		if len(messages) == 0 {
			return nil
		}
	}

	if len(broadcastMessages) > 0 {
		updateLastInboxReadTo(sessionsDir, inp.SessionID, newestBroadcastTimestamp(broadcastMessages))
	}

	// Build additionalContext string.
	ctx := fmt.Sprintf("📨 Messages from other sessions (%d):\n---\n%s\n---",
		len(messages), strings.Join(messages, "\n"))

	output := preToolAllowOutput{}
	output.HookSpecificOutput.HookEventName = "PreToolUse"
	output.HookSpecificOutput.PermissionDecision = "allow"
	output.HookSpecificOutput.AdditionalContext = ctx

	outData, err := json.Marshal(output)
	if err != nil {
		return fmt.Errorf("marshaling output: %w", err)
	}
	_, err = fmt.Fprintf(out, "%s\n", outData)
	return err
}

// lastInboxReadFile returns the session-specific last-read timestamp file path.
// Equivalent to get_last_read_file() in the bash version session-inbox-check.sh.
func lastInboxReadFile(sessionsDir, sessionID string) string {
	if sessionID == "" {
		sessionID = "unknown"
	}
	return sessionsDir + "/.last_inbox_read_" + sessionID
}

// lastInboxReadTime returns the session-specific last-read timestamp.
// Returns time.Time{} (zero) if the file does not exist.
func lastInboxReadTime(sessionsDir, sessionID string) time.Time {
	f := lastInboxReadFile(sessionsDir, sessionID)
	raw, err := os.ReadFile(f)
	if err != nil {
		return time.Time{}
	}
	ts := strings.TrimSpace(string(raw))
	t, err := time.Parse("2006-01-02T15:04:05Z", ts)
	if err != nil {
		return time.Time{}
	}
	return t
}

// updateLastInboxRead updates the session-specific last-read timestamp to the current time.
// Equivalent to mark_as_read() in the bash version session-inbox-check.sh.
func updateLastInboxRead(sessionsDir, sessionID string) {
	updateLastInboxReadTo(sessionsDir, sessionID, time.Now().UTC())
}

func updateLastInboxReadTo(sessionsDir, sessionID string, ts time.Time) {
	f := lastInboxReadFile(sessionsDir, sessionID)
	if ts.IsZero() {
		ts = time.Now().UTC()
	}
	_ = os.WriteFile(f, []byte(ts.UTC().Format("2006-01-02T15:04:05Z")+"\n"), 0o644)
}

// readBroadcastMessagesSince reads up to maxCount messages from broadcast.md that are newer than since.
// If since is zero, all messages are returned (equivalent to first-time read).
func readBroadcastMessagesSince(path string, maxCount int, since time.Time, currentSessionID string) ([]string, error) {
	msgs, err := readBroadcastMessagesSinceDetailed(path, maxCount, since, currentSessionID)
	return broadcastMessageLines(msgs), err
}

func readBroadcastMessagesSinceDetailed(path string, maxCount int, since time.Time, currentSessionID string) ([]broadcastMessage, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()

	// Self-session filter prefix (12 characters).
	// Same length as senderTag in session_auto_broadcast.go (12 characters, matching the bash version).
	selfPrefix := ""
	if len(currentSessionID) >= 12 {
		selfPrefix = currentSessionID[:12]
	} else {
		selfPrefix = currentSessionID
	}

	var msgs []broadcastMessage
	var currentTimestamp, currentSender, currentContent string
	inMessage := false

	flush := func() {
		if !inMessage || currentContent == "" || len(msgs) >= maxCount {
			return
		}
		// Skip broadcasts sent by the current session (prevent self-echo).
		if selfPrefix != "" && currentSender == selfPrefix {
			return
		}
		// Parse the timestamp.
		msgTime, parseErr := time.Parse("2006-01-02T15:04:05Z", currentTimestamp)
		if parseErr == nil && !since.IsZero() && !msgTime.After(since) {
			// Skip messages at or before since.
			return
		}
		ts := currentTimestamp
		if parseErr == nil {
			ts = msgTime.UTC().Format("2006-01-02 15:04")
		}
		msgs = append(msgs, broadcastMessage{
			Line:      fmt.Sprintf("[%s] %s: %s", ts, currentSender, currentContent),
			Timestamp: msgTime,
		})
	}

	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		line := scanner.Text()

		if m := broadcastMsgRe.FindStringSubmatch(line); m != nil {
			flush()
			currentTimestamp = m[1]
			currentSender = m[2]
			currentContent = ""
			inMessage = true
			continue
		}

		if inMessage && strings.TrimSpace(line) != "" {
			currentContent = strings.TrimSpace(line)
		}
	}
	flush()

	return msgs, scanner.Err()
}

func broadcastMessageLines(messages []broadcastMessage) []string {
	lines := make([]string, 0, len(messages))
	for _, msg := range messages {
		lines = append(lines, msg.Line)
	}
	return lines
}

func newestBroadcastTimestamp(messages []broadcastMessage) time.Time {
	var newest time.Time
	for _, msg := range messages {
		if msg.Timestamp.After(newest) {
			newest = msg.Timestamp
		}
	}
	return newest
}

// throttleAllowed returns true when enough time has passed since the last check.
func throttleAllowed(checkIntervalFile string) bool {
	data, err := os.ReadFile(checkIntervalFile)
	if err != nil {
		// File doesn't exist yet — first check is always allowed.
		return true
	}
	raw := strings.TrimSpace(string(data))
	lastCheck, err := strconv.ParseInt(raw, 10, 64)
	if err != nil {
		return true
	}
	elapsed := time.Since(time.Unix(lastCheck, 0))
	return elapsed >= CheckInterval
}

// readBroadcastMessages reads up to maxCount messages from broadcast.md.
// Backward-compatible wrapper around readBroadcastMessagesSince with zero since
// (returns all messages regardless of timestamp). No self-session filtering.
func readBroadcastMessages(path string, maxCount int) ([]string, error) {
	return readBroadcastMessagesSince(path, maxCount, time.Time{}, "")
}

// readUnreadMessages reads up to maxCount unread messages from a JSONL inbox
// file. Each line is expected to be a JSON object; lines that are not valid
// JSON are treated as raw text messages. Lines starting with '[' are treated
// as pre-formatted message lines (matching the bash grep pattern).
func readUnreadMessages(path string, maxCount int) ([]string, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()

	var msgs []string
	scanner := bufio.NewScanner(f)
	for scanner.Scan() && len(msgs) < maxCount {
		line := scanner.Text()
		if line == "" {
			continue
		}
		// Try to parse as JSON to check read status.
		var entry inboxLine
		if jsonErr := json.Unmarshal([]byte(line), &entry); jsonErr == nil {
			if !entry.Read && entry.Msg != "" {
				msgs = append(msgs, entry.Msg)
			}
			continue
		}
		// Fallback: treat lines beginning with '[' as unread messages (bash compat).
		if strings.HasPrefix(line, "[") {
			msgs = append(msgs, line)
		}
	}
	return msgs, scanner.Err()
}
