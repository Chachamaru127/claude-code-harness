package hookhandler

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"testing"
)

func TestHandleSessionAutoBroadcast_NoInput(t *testing.T) {
	var out bytes.Buffer
	err := HandleSessionAutoBroadcast(strings.NewReader(""), &out)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	var result postToolOutput
	if jsonErr := json.Unmarshal(out.Bytes(), &result); jsonErr != nil {
		t.Fatalf("invalid JSON output: %v, raw: %s", jsonErr, out.String())
	}
	if result.HookSpecificOutput.HookEventName != "PostToolUse" {
		t.Errorf("expected hookEventName=PostToolUse, got %q", result.HookSpecificOutput.HookEventName)
	}
	if result.HookSpecificOutput.AdditionalContext != "" {
		t.Errorf("expected empty additionalContext, got %q", result.HookSpecificOutput.AdditionalContext)
	}
}

func TestHandleSessionAutoBroadcast_NoFilePath(t *testing.T) {
	input := `{"tool_input":{}}`
	var out bytes.Buffer
	err := HandleSessionAutoBroadcast(strings.NewReader(input), &out)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	var result postToolOutput
	if jsonErr := json.Unmarshal(out.Bytes(), &result); jsonErr != nil {
		t.Fatalf("invalid JSON output: %v", jsonErr)
	}
	if result.HookSpecificOutput.AdditionalContext != "" {
		t.Errorf("expected empty context for no file_path, got %q", result.HookSpecificOutput.AdditionalContext)
	}
}

func TestHandleSessionAutoBroadcast_StaleCWDNoBroadcast(t *testing.T) {
	tmpDir := t.TempDir()
	origDir, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	if err := os.Chdir(tmpDir); err != nil {
		t.Fatal(err)
	}
	defer os.Chdir(origDir)

	staleCWD := filepath.Join(tmpDir, "deleted-worktree")
	input := `{"cwd":` + strconv.Quote(staleCWD) + `,"tool_input":{"file_path":"src/api/users.ts"}}`
	var out bytes.Buffer
	if handlerErr := HandleSessionAutoBroadcast(strings.NewReader(input), &out); handlerErr != nil {
		t.Fatalf("unexpected error: %v", handlerErr)
	}

	var result postToolOutput
	if jsonErr := json.Unmarshal(out.Bytes(), &result); jsonErr != nil {
		t.Fatalf("invalid JSON output: %v", jsonErr)
	}
	if result.HookSpecificOutput.AdditionalContext != "" {
		t.Errorf("expected empty context for stale cwd, got %q", result.HookSpecificOutput.AdditionalContext)
	}
	if _, statErr := os.Stat(filepath.Join(".claude", "sessions", "broadcast.md")); !os.IsNotExist(statErr) {
		t.Fatalf("stale cwd should not create broadcast.md, stat err: %v", statErr)
	}
}

func TestHandleSessionAutoBroadcast_NoPatternMatch(t *testing.T) {
	input := `{"tool_input":{"file_path":"src/utils/helper.go"}}`
	var out bytes.Buffer
	err := HandleSessionAutoBroadcast(strings.NewReader(input), &out)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	var result postToolOutput
	if jsonErr := json.Unmarshal(out.Bytes(), &result); jsonErr != nil {
		t.Fatalf("invalid JSON output: %v", jsonErr)
	}
	if result.HookSpecificOutput.AdditionalContext != "" {
		t.Errorf("expected empty context for non-matching file, got %q", result.HookSpecificOutput.AdditionalContext)
	}
}

func TestHandleSessionAutoBroadcast_MatchesSrcAPI(t *testing.T) {
	// Move to a temporary directory for testing
	tmpDir := t.TempDir()
	origDir, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	if err := os.Chdir(tmpDir); err != nil {
		t.Fatal(err)
	}
	defer os.Chdir(origDir)

	input := `{"tool_input":{"file_path":"src/api/users.ts"}}`
	var out bytes.Buffer
	handlerErr := HandleSessionAutoBroadcast(strings.NewReader(input), &out)
	if handlerErr != nil {
		t.Fatalf("unexpected error: %v", handlerErr)
	}

	var result postToolOutput
	if jsonErr := json.Unmarshal(out.Bytes(), &result); jsonErr != nil {
		t.Fatalf("invalid JSON output: %v, raw: %s", jsonErr, out.String())
	}

	// additionalContext should contain the file name
	if !strings.Contains(result.HookSpecificOutput.AdditionalContext, "users.ts") {
		t.Errorf("expected additionalContext to contain 'users.ts', got %q",
			result.HookSpecificOutput.AdditionalContext)
	}
	if !strings.Contains(result.HookSpecificOutput.AdditionalContext, "auto-broadcast") {
		t.Errorf("expected additionalContext to contain 'auto-broadcast', got %q",
			result.HookSpecificOutput.AdditionalContext)
	}

	// broadcast.md should be created under .claude/sessions/
	// (same location that inbox_check reads: .claude/sessions/broadcast.md)
	broadcastFile := filepath.Join(".claude", "sessions", "broadcast.md")
	data, readErr := os.ReadFile(broadcastFile)
	if readErr != nil {
		t.Fatalf("broadcast.md not created at .claude/sessions/broadcast.md: %v", readErr)
	}
	if !strings.Contains(string(data), "src/api/users.ts") {
		t.Errorf("broadcast.md should contain file path, got: %s", string(data))
	}
	// Header format should be compatible with the inbox_check parser: ## <timestamp> [<sender>]
	// Falls back to [unknown] when there is no session_id
	if !strings.Contains(string(data), "[unknown]") {
		t.Errorf("broadcast.md should contain sender tag [unknown] (no session_id), got: %s", string(data))
	}
}

func TestHandleSessionAutoBroadcast_MatchesSchemaPrisma(t *testing.T) {
	tmpDir := t.TempDir()
	origDir, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	if err := os.Chdir(tmpDir); err != nil {
		t.Fatal(err)
	}
	defer os.Chdir(origDir)

	input := `{"tool_input":{"file_path":"prisma/schema.prisma"}}`
	var out bytes.Buffer
	if handlerErr := HandleSessionAutoBroadcast(strings.NewReader(input), &out); handlerErr != nil {
		t.Fatalf("unexpected error: %v", handlerErr)
	}

	var result postToolOutput
	if jsonErr := json.Unmarshal(out.Bytes(), &result); jsonErr != nil {
		t.Fatalf("invalid JSON output: %v", jsonErr)
	}
	if !strings.Contains(result.HookSpecificOutput.AdditionalContext, "schema.prisma") {
		t.Errorf("expected file name in additionalContext, got %q",
			result.HookSpecificOutput.AdditionalContext)
	}
}

func TestHandleSessionAutoBroadcast_MatchesPathField(t *testing.T) {
	tmpDir := t.TempDir()
	origDir, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	if err := os.Chdir(tmpDir); err != nil {
		t.Fatal(err)
	}
	defer os.Chdir(origDir)

	// Use the path field instead of file_path
	input := `{"tool_input":{"path":"src/types/user.ts"}}`
	var out bytes.Buffer
	if handlerErr := HandleSessionAutoBroadcast(strings.NewReader(input), &out); handlerErr != nil {
		t.Fatalf("unexpected error: %v", handlerErr)
	}

	var result postToolOutput
	if jsonErr := json.Unmarshal(out.Bytes(), &result); jsonErr != nil {
		t.Fatalf("invalid JSON output: %v", jsonErr)
	}
	if !strings.Contains(result.HookSpecificOutput.AdditionalContext, "user.ts") {
		t.Errorf("expected 'user.ts' in additionalContext, got %q",
			result.HookSpecificOutput.AdditionalContext)
	}
}

func TestHandleSessionAutoBroadcast_DisabledByConfig(t *testing.T) {
	tmpDir := t.TempDir()
	origDir, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	if err := os.Chdir(tmpDir); err != nil {
		t.Fatal(err)
	}
	defer os.Chdir(origDir)

	// Disable via config file
	configDir := filepath.Join(".claude", "sessions")
	if mkdirErr := os.MkdirAll(configDir, 0o755); mkdirErr != nil {
		t.Fatal(mkdirErr)
	}
	if writeErr := os.WriteFile(
		filepath.Join(configDir, "auto-broadcast.json"),
		[]byte(`{"enabled":false}`),
		0o644,
	); writeErr != nil {
		t.Fatal(writeErr)
	}

	input := `{"tool_input":{"file_path":"src/api/users.ts"}}`
	var out bytes.Buffer
	if handlerErr := HandleSessionAutoBroadcast(strings.NewReader(input), &out); handlerErr != nil {
		t.Fatalf("unexpected error: %v", handlerErr)
	}

	var result postToolOutput
	if jsonErr := json.Unmarshal(out.Bytes(), &result); jsonErr != nil {
		t.Fatalf("invalid JSON output: %v", jsonErr)
	}
	// No additional context when disabled
	if result.HookSpecificOutput.AdditionalContext != "" {
		t.Errorf("expected empty context when disabled, got %q",
			result.HookSpecificOutput.AdditionalContext)
	}
}

func TestHandleSessionAutoBroadcast_SessionIDInHeader(t *testing.T) {
	tmpDir := t.TempDir()
	origDir, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	if err := os.Chdir(tmpDir); err != nil {
		t.Fatal(err)
	}
	defer os.Chdir(origDir) //nolint:errcheck

	// Input containing session_id
	input := `{"session_id":"abcdef1234567890","tool_input":{"file_path":"src/api/orders.ts"}}`
	var out bytes.Buffer
	if handlerErr := HandleSessionAutoBroadcast(strings.NewReader(input), &out); handlerErr != nil {
		t.Fatalf("unexpected error: %v", handlerErr)
	}

	// Verify that the broadcast.md header contains the first 12 characters of session_id
	broadcastFile := filepath.Join(".claude", "sessions", "broadcast.md")
	data, readErr := os.ReadFile(broadcastFile)
	if readErr != nil {
		t.Fatalf("broadcast.md not created: %v", readErr)
	}
	content := string(data)
	// Should use [abcdef123456] (first 12 chars) rather than [auto-broadcast]
	if strings.Contains(content, "[auto-broadcast]") {
		t.Errorf("header should NOT use [auto-broadcast] when session_id is set, got: %s", content)
	}
	if !strings.Contains(content, "[abcdef123456]") {
		t.Errorf("header should contain session_id prefix [abcdef123456], got: %s", content)
	}
}

func TestHandleSessionAutoBroadcast_EmptySessionIDFallback(t *testing.T) {
	tmpDir := t.TempDir()
	origDir, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	if err := os.Chdir(tmpDir); err != nil {
		t.Fatal(err)
	}
	defer os.Chdir(origDir) //nolint:errcheck

	// No session_id (fallback: [unknown])
	input := `{"tool_input":{"file_path":"src/api/items.ts"}}`
	var out bytes.Buffer
	if handlerErr := HandleSessionAutoBroadcast(strings.NewReader(input), &out); handlerErr != nil {
		t.Fatalf("unexpected error: %v", handlerErr)
	}

	broadcastFile := filepath.Join(".claude", "sessions", "broadcast.md")
	data, readErr := os.ReadFile(broadcastFile)
	if readErr != nil {
		t.Fatalf("broadcast.md not created: %v", readErr)
	}
	content := string(data)
	if !strings.Contains(content, "[unknown]") {
		t.Errorf("header should contain [unknown] when session_id is empty, got: %s", content)
	}
}

func TestHandleSessionAutoBroadcast_CustomPattern(t *testing.T) {
	tmpDir := t.TempDir()
	origDir, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	if err := os.Chdir(tmpDir); err != nil {
		t.Fatal(err)
	}
	defer os.Chdir(origDir)

	// Configure custom pattern
	configDir := filepath.Join(".claude", "sessions")
	if mkdirErr := os.MkdirAll(configDir, 0o755); mkdirErr != nil {
		t.Fatal(mkdirErr)
	}
	if writeErr := os.WriteFile(
		filepath.Join(configDir, "auto-broadcast.json"),
		[]byte(`{"enabled":true,"patterns":["custom/contracts/"]}`),
		0o644,
	); writeErr != nil {
		t.Fatal(writeErr)
	}

	input := `{"tool_input":{"file_path":"custom/contracts/order.ts"}}`
	var out bytes.Buffer
	if handlerErr := HandleSessionAutoBroadcast(strings.NewReader(input), &out); handlerErr != nil {
		t.Fatalf("unexpected error: %v", handlerErr)
	}

	var result postToolOutput
	if jsonErr := json.Unmarshal(out.Bytes(), &result); jsonErr != nil {
		t.Fatalf("invalid JSON output: %v", jsonErr)
	}
	if !strings.Contains(result.HookSpecificOutput.AdditionalContext, "order.ts") {
		t.Errorf("expected 'order.ts' in additionalContext (custom pattern), got %q",
			result.HookSpecificOutput.AdditionalContext)
	}
}
