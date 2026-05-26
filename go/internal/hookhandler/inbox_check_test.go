package hookhandler

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func TestHandleInboxCheck_EmptyInbox(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("HARNESS_PROJECT_ROOT", dir)

	// Create broadcast.md so the handler proceeds past the early-exit check.
	sessionsDir := filepath.Join(dir, ".claude", "sessions")
	if err := os.MkdirAll(sessionsDir, 0o755); err != nil {
		t.Fatal(err)
	}
	broadcastPath := filepath.Join(sessionsDir, "broadcast.md")
	if err := os.WriteFile(broadcastPath, []byte("hello"), 0o644); err != nil {
		t.Fatal(err)
	}

	// No inbox file → expect silent (no output).
	var out bytes.Buffer
	if err := HandleInboxCheck(strings.NewReader("{}"), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if out.Len() != 0 {
		t.Errorf("expected no output for empty inbox, got: %s", out.String())
	}
}

func TestHandleInboxCheck_WithUnreadMessages(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("HARNESS_PROJECT_ROOT", dir)

	sessionsDir := filepath.Join(dir, ".claude", "sessions")
	stateDir := filepath.Join(dir, ".claude", "state")
	if err := os.MkdirAll(sessionsDir, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(stateDir, 0o755); err != nil {
		t.Fatal(err)
	}

	// broadcast.md must exist.
	broadcastPath := filepath.Join(sessionsDir, "broadcast.md")
	if err := os.WriteFile(broadcastPath, []byte("exists"), 0o644); err != nil {
		t.Fatal(err)
	}

	// Write two unread messages to inbox JSONL.
	inboxPath := filepath.Join(stateDir, "session-inbox.jsonl")
	content := `{"read":false,"msg":"message one"}` + "\n" +
		`{"read":false,"msg":"message two"}` + "\n"
	if err := os.WriteFile(inboxPath, []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}

	var out bytes.Buffer
	if err := HandleInboxCheck(strings.NewReader("{}"), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if out.Len() == 0 {
		t.Fatal("expected output for unread messages, got nothing")
	}

	var result map[string]interface{}
	if err := json.Unmarshal(out.Bytes(), &result); err != nil {
		t.Fatalf("output is not valid JSON: %v\noutput: %s", err, out.String())
	}

	hso, ok := result["hookSpecificOutput"].(map[string]interface{})
	if !ok {
		t.Fatalf("missing hookSpecificOutput field")
	}
	if hso["hookEventName"] != "PreToolUse" {
		t.Errorf("hookEventName = %v, want PreToolUse", hso["hookEventName"])
	}
	if hso["permissionDecision"] != "allow" {
		t.Errorf("permissionDecision = %v, want allow", hso["permissionDecision"])
	}
	ctx, _ := hso["additionalContext"].(string)
	if !strings.Contains(ctx, "message one") {
		t.Errorf("additionalContext does not contain expected message: %s", ctx)
	}
}

func TestHandleInboxCheck_Throttle(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("HARNESS_PROJECT_ROOT", dir)

	sessionsDir := filepath.Join(dir, ".claude", "sessions")
	stateDir := filepath.Join(dir, ".claude", "state")
	if err := os.MkdirAll(sessionsDir, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(stateDir, 0o755); err != nil {
		t.Fatal(err)
	}

	// broadcast.md must exist.
	if err := os.WriteFile(filepath.Join(sessionsDir, "broadcast.md"), []byte("x"), 0o644); err != nil {
		t.Fatal(err)
	}

	// Write an unread message.
	inboxPath := filepath.Join(stateDir, "session-inbox.jsonl")
	if err := os.WriteFile(inboxPath, []byte(`{"read":false,"msg":"hello"}`+"\n"), 0o644); err != nil {
		t.Fatal(err)
	}

	// Write a recent last-check timestamp (now − 1 minute → within throttle window).
	recent := time.Now().Add(-1 * time.Minute).Unix()
	checkFile := filepath.Join(sessionsDir, ".last_inbox_check")
	tsStr := fmt.Sprintf("%d", recent)
	if err := os.WriteFile(checkFile, []byte(tsStr+"\n"), 0o644); err != nil {
		t.Fatal(err)
	}

	var out bytes.Buffer
	if err := HandleInboxCheck(strings.NewReader("{}"), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	// Within throttle window → expect no output.
	if out.Len() != 0 {
		t.Errorf("expected no output within throttle window, got: %s", out.String())
	}
}

func TestHandleInboxCheck_ReadMessages_Filtered(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("HARNESS_PROJECT_ROOT", dir)

	sessionsDir := filepath.Join(dir, ".claude", "sessions")
	stateDir := filepath.Join(dir, ".claude", "state")
	os.MkdirAll(sessionsDir, 0o755)                                              //nolint:errcheck
	os.MkdirAll(stateDir, 0o755)                                                 //nolint:errcheck
	os.WriteFile(filepath.Join(sessionsDir, "broadcast.md"), []byte("x"), 0o644) //nolint:errcheck

	// Mix of read and unread messages.
	inboxPath := filepath.Join(stateDir, "session-inbox.jsonl")
	content := `{"read":true,"msg":"already read"}` + "\n" +
		`{"read":false,"msg":"unread msg"}` + "\n"
	os.WriteFile(inboxPath, []byte(content), 0o644) //nolint:errcheck

	var out bytes.Buffer
	HandleInboxCheck(strings.NewReader("{}"), &out) //nolint:errcheck

	if out.Len() == 0 {
		t.Fatal("expected output for unread message")
	}
	outStr := out.String()
	if strings.Contains(outStr, "already read") {
		t.Error("output should not contain already-read messages")
	}
	if !strings.Contains(outStr, "unread msg") {
		t.Error("output should contain unread message")
	}
}

func TestNoBroadcastFile_NoOutput(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("HARNESS_PROJECT_ROOT", dir)

	// No broadcast.md → early exit, no output.
	var out bytes.Buffer
	if err := HandleInboxCheck(strings.NewReader("{}"), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if out.Len() != 0 {
		t.Errorf("expected no output when broadcast.md absent, got: %s", out.String())
	}
}

func TestReadBroadcastMessages_MarkdownFormat(t *testing.T) {
	dir := t.TempDir()
	broadcastPath := filepath.Join(dir, "broadcast.md")

	// Markdown format generated by the bash version session-inbox-check.sh
	content := "## 2026-04-09T12:00:00Z [abc123456def]\nhello from session A\n\n## 2026-04-09T12:05:00Z [xyz789012abc]\nupdate: task completed\n"
	if err := os.WriteFile(broadcastPath, []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}

	msgs, err := readBroadcastMessages(broadcastPath, 5)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(msgs) != 2 {
		t.Fatalf("expected 2 messages, got %d: %v", len(msgs), msgs)
	}
	if !strings.Contains(msgs[0], "hello from session A") {
		t.Errorf("message 0 should contain 'hello from session A', got: %s", msgs[0])
	}
	if !strings.Contains(msgs[1], "update: task completed") {
		t.Errorf("message 1 should contain 'update: task completed', got: %s", msgs[1])
	}
	// Timestamp should include full date to avoid showing old notifications as today's
	if !strings.Contains(msgs[0], "[2026-04-09 12:00]") {
		t.Errorf("message 0 should contain full date timestamp, got: %s", msgs[0])
	}
}

func TestReadBroadcastMessages_MaxCount(t *testing.T) {
	dir := t.TempDir()
	broadcastPath := filepath.Join(dir, "broadcast.md")

	// More than 5 messages
	var content string
	for i := 0; i < 8; i++ {
		content += fmt.Sprintf("## 2026-04-09T12:0%dZ [sender%d]\nmessage %d\n\n", i, i, i)
	}
	if err := os.WriteFile(broadcastPath, []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}

	msgs, err := readBroadcastMessages(broadcastPath, 5)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(msgs) > 5 {
		t.Errorf("expected at most 5 messages, got %d", len(msgs))
	}
}

func TestHandleInboxCheck_BroadcastMdSource(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("HARNESS_PROJECT_ROOT", dir)

	sessionsDir := filepath.Join(dir, ".claude", "sessions")
	if err := os.MkdirAll(sessionsDir, 0o755); err != nil {
		t.Fatal(err)
	}

	// Write a message to broadcast.md (same source as the bash version)
	broadcastPath := filepath.Join(sessionsDir, "broadcast.md")
	content := "## 2026-04-09T10:30:00Z [remote-session-a1]\nplease check the CI status\n"
	if err := os.WriteFile(broadcastPath, []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}

	var out bytes.Buffer
	if err := HandleInboxCheck(strings.NewReader("{}"), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if out.Len() == 0 {
		t.Fatal("expected output for broadcast.md message, got nothing")
	}
	outStr := out.String()
	if !strings.Contains(outStr, "CI status") {
		t.Errorf("output should contain 'CI status', got: %s", outStr)
	}
}

// TestHandleInboxCheck_SessionSpecificReadState verifies session-specific read state management.
// Checks that already-read messages are not shown again on subsequent checks.
func TestHandleInboxCheck_SessionSpecificReadState(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("HARNESS_PROJECT_ROOT", dir)

	sessionsDir := filepath.Join(dir, ".claude", "sessions")
	if err := os.MkdirAll(sessionsDir, 0o755); err != nil {
		t.Fatal(err)
	}

	broadcastPath := filepath.Join(sessionsDir, "broadcast.md")
	content := "## 2026-04-09T10:00:00Z [session-a]\nold message\n"
	if err := os.WriteFile(broadcastPath, []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}

	sessionID := "test-session-123"

	// Set the last-read timestamp to after the message (treated as already read)
	updateLastInboxRead(sessionsDir, sessionID)

	// Pass JSON containing the session ID
	inp := fmt.Sprintf(`{"session_id":%q}`, sessionID)
	var out bytes.Buffer
	if err := HandleInboxCheck(strings.NewReader(inp), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	// Already read, so nothing should be shown
	if out.Len() != 0 {
		outStr := out.String()
		if strings.Contains(outStr, "old message") {
			t.Errorf("already-read message should not appear again, got: %s", outStr)
		}
	}
}

// TestHandleInboxCheck_NewMessagesAfterLastRead verifies that only messages newer than the last-read timestamp are shown.
func TestHandleInboxCheck_NewMessagesAfterLastRead(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("HARNESS_PROJECT_ROOT", dir)

	sessionsDir := filepath.Join(dir, ".claude", "sessions")
	if err := os.MkdirAll(sessionsDir, 0o755); err != nil {
		t.Fatal(err)
	}

	// broadcast.md containing both an old message and a new message
	broadcastPath := filepath.Join(sessionsDir, "broadcast.md")
	content := "## 2020-01-01T00:00:00Z [session-a]\nold message\n\n## 2030-12-31T23:59:59Z [session-b]\nnew message\n"
	if err := os.WriteFile(broadcastPath, []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}

	sessionID := "test-session-456"
	// Set last-read to 2025 → 2020 message is already read, 2030 message is unread
	lastReadFile := lastInboxReadFile(sessionsDir, sessionID)
	if err := os.WriteFile(lastReadFile, []byte("2025-01-01T00:00:00Z\n"), 0o644); err != nil {
		t.Fatal(err)
	}

	inp := fmt.Sprintf(`{"session_id":%q}`, sessionID)
	var out bytes.Buffer
	if err := HandleInboxCheck(strings.NewReader(inp), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if out.Len() == 0 {
		t.Fatal("expected output for new message, got nothing")
	}
	outStr := out.String()
	if strings.Contains(outStr, "old message") {
		t.Errorf("old (read) message should not appear, got: %s", outStr)
	}
	if !strings.Contains(outStr, "new message") {
		t.Errorf("new (unread) message should appear, got: %s", outStr)
	}
}

// TestLastInboxReadFile verifies that the session-specific file path is correctly generated.
func TestLastInboxReadFile(t *testing.T) {
	got := lastInboxReadFile("/sessions", "abc123")
	want := "/sessions/.last_inbox_read_abc123"
	if got != want {
		t.Errorf("lastInboxReadFile() = %q, want %q", got, want)
	}
}

// TestLastInboxReadFile_EmptySessionID verifies that "unknown" is used for an empty session ID.
func TestLastInboxReadFile_EmptySessionID(t *testing.T) {
	got := lastInboxReadFile("/sessions", "")
	want := "/sessions/.last_inbox_read_unknown"
	if got != want {
		t.Errorf("lastInboxReadFile() = %q, want %q", got, want)
	}
}

// TestHandleInboxCheck_AutoMarksDisplayedBroadcast verifies that after a message is displayed,
// the last-read file (.last_inbox_read_*) is updated with the maximum timestamp of the displayed broadcasts.
func TestHandleInboxCheck_AutoMarksDisplayedBroadcast(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("HARNESS_PROJECT_ROOT", dir)

	sessionsDir := filepath.Join(dir, ".claude", "sessions")
	if err := os.MkdirAll(sessionsDir, 0o755); err != nil {
		t.Fatal(err)
	}

	// Write a message to broadcast.md
	broadcastPath := filepath.Join(sessionsDir, "broadcast.md")
	content := "## 2026-04-09T10:00:00Z [remote-session]\nhello, please review\n"
	if err := os.WriteFile(broadcastPath, []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}

	sessionID := "test-no-auto-mark"
	inp := fmt.Sprintf(`{"session_id":%q}`, sessionID)

	var out bytes.Buffer
	if err := HandleInboxCheck(strings.NewReader(inp), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	// Verify that the message was displayed
	if out.Len() == 0 {
		t.Fatal("expected output for message, got nothing")
	}
	if !strings.Contains(out.String(), "[2026-04-09 10:00]") {
		t.Fatalf("expected date-bearing timestamp in output, got: %s", out.String())
	}

	// Verify that the last-read file is created with the maximum displayed broadcast timestamp.
	readFile := lastInboxReadFile(sessionsDir, sessionID)
	data, err := os.ReadFile(readFile)
	if err != nil {
		t.Fatalf("last-read file should be created after display: %v", err)
	}
	if got := strings.TrimSpace(string(data)); got != "2026-04-09T10:00:00Z" {
		t.Fatalf("last-read timestamp = %q, want displayed broadcast timestamp", got)
	}

	// Even on the next check after the throttle window, the same stale broadcast should not be shown again.
	checkFile := filepath.Join(sessionsDir, ".last_inbox_check")
	if err := os.WriteFile(checkFile, []byte("0\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	var second bytes.Buffer
	if err := HandleInboxCheck(strings.NewReader(inp), &second); err != nil {
		t.Fatalf("unexpected error on second check: %v", err)
	}
	if strings.Contains(second.String(), "hello, please review") {
		t.Fatalf("displayed broadcast should not be repeated after auto-mark: %s", second.String())
	}
}
