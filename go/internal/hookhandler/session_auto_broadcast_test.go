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
	// Use .txt so neither the API/schema substring patterns nor the
	// Phase 85.1.6 extension rule (.go/.md/.sh) fire. Previously the
	// test used "helper.go" which became a match once the extension
	// rule was added; the rename keeps the original no-match intent
	// without weakening either rule's coverage.
	input := `{"tool_input":{"file_path":"src/utils/helper.txt"}}`
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
	// テスト用の一時ディレクトリに移動
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

	// additionalContext にファイル名が含まれること
	if !strings.Contains(result.HookSpecificOutput.AdditionalContext, "users.ts") {
		t.Errorf("expected additionalContext to contain 'users.ts', got %q",
			result.HookSpecificOutput.AdditionalContext)
	}
	if !strings.Contains(result.HookSpecificOutput.AdditionalContext, "自動ブロードキャスト") {
		t.Errorf("expected additionalContext to contain '自動ブロードキャスト', got %q",
			result.HookSpecificOutput.AdditionalContext)
	}

	// broadcast.md が .claude/sessions/ に作成されていること
	// （inbox_check が読む場所と同じ: .claude/sessions/broadcast.md）
	broadcastFile := filepath.Join(".claude", "sessions", "broadcast.md")
	data, readErr := os.ReadFile(broadcastFile)
	if readErr != nil {
		t.Fatalf("broadcast.md not created at .claude/sessions/broadcast.md: %v", readErr)
	}
	if !strings.Contains(string(data), "src/api/users.ts") {
		t.Errorf("broadcast.md should contain file path, got: %s", string(data))
	}
	// ヘッダーフォーマットが inbox_check パーサーと互換であること: ## <timestamp> [<sender>]
	// session_id なしの場合は [unknown] にフォールバックする
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

	// file_path の代わりに path フィールドを使う
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

	// 設定ファイルで無効化
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
	// 無効な場合は追加コンテキストなし
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

	// session_id を含む入力
	input := `{"session_id":"abcdef1234567890","tool_input":{"file_path":"src/api/orders.ts"}}`
	var out bytes.Buffer
	if handlerErr := HandleSessionAutoBroadcast(strings.NewReader(input), &out); handlerErr != nil {
		t.Fatalf("unexpected error: %v", handlerErr)
	}

	// broadcast.md のヘッダーに session_id の先頭 12 文字が含まれることを確認
	broadcastFile := filepath.Join(".claude", "sessions", "broadcast.md")
	data, readErr := os.ReadFile(broadcastFile)
	if readErr != nil {
		t.Fatalf("broadcast.md not created: %v", readErr)
	}
	content := string(data)
	// [auto-broadcast] ではなく [abcdef123456]（先頭12文字）が使われるはず
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

	// session_id なし（フォールバック: [unknown]）
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

	// カスタムパターンを設定
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

// TestAutoBroadcast_FiresOnNormalEdit covers the Phase 85.1.6 revival: a
// plain Go-file edit (no src/api/, no schema.prisma) must produce a
// broadcast entry. Before the extension rule was added this test would
// fail because the file path matched none of the API/schema substring
// patterns and the handler silently no-op'd, which is why broadcast.md
// had been dead since 2026-02 on repos like claude-code-harness itself.
func TestAutoBroadcast_FiresOnNormalEdit(t *testing.T) {
	dir := t.TempDir()
	t.Chdir(dir)
	t.Setenv("HARNESS_PROJECT_ROOT", dir)

	input := `{"session_id":"sess-revival","cwd":"` + dir + `","tool_input":{"file_path":"go/internal/foo.go"}}`
	var out bytes.Buffer
	if err := HandleSessionAutoBroadcast(strings.NewReader(input), &out); err != nil {
		t.Fatalf("handler: %v", err)
	}

	var result postToolOutput
	if err := json.Unmarshal(out.Bytes(), &result); err != nil {
		t.Fatalf("invalid JSON: %v, raw: %s", err, out.String())
	}
	if !strings.Contains(result.HookSpecificOutput.AdditionalContext, "foo.go") {
		t.Errorf("expected foo.go in additionalContext, got %q",
			result.HookSpecificOutput.AdditionalContext)
	}
	if !strings.Contains(result.HookSpecificOutput.AdditionalContext, "自動ブロードキャスト") {
		t.Errorf("expected broadcast notice, got %q",
			result.HookSpecificOutput.AdditionalContext)
	}

	broadcastFile := filepath.Join(dir, ".claude", "sessions", "broadcast.md")
	data, err := os.ReadFile(broadcastFile)
	if err != nil {
		t.Fatalf("broadcast.md not created: %v", err)
	}
	if !strings.Contains(string(data), "go/internal/foo.go") {
		t.Errorf("broadcast.md missing file path; got: %s", data)
	}
	// The "*<ext>" label proves the extension rule fired (not a substring
	// match). Without this the test would also pass under the old code
	// when called with a substring-matching path.
	if !strings.Contains(string(data), "*.go") {
		t.Errorf("expected '*.go' label (extension rule), got: %s", data)
	}
}

// TestAutoBroadcast_FiresOnMarkdownAndShell verifies the extension list
// covers .md and .sh too, not just .go. These are the other common edit
// targets in Harness work (Plans.md, CLAUDE.md, scripts/*.sh).
func TestAutoBroadcast_FiresOnMarkdownAndShell(t *testing.T) {
	cases := []struct {
		name     string
		filePath string
		wantBase string
	}{
		{"markdown", "Plans.md", "Plans.md"},
		{"shell", "scripts/release.sh", "release.sh"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			dir := t.TempDir()
			t.Chdir(dir)
			t.Setenv("HARNESS_PROJECT_ROOT", dir)

			input := `{"session_id":"sess-` + tc.name + `","cwd":"` + dir + `","tool_input":{"file_path":"` + tc.filePath + `"}}`
			var out bytes.Buffer
			if err := HandleSessionAutoBroadcast(strings.NewReader(input), &out); err != nil {
				t.Fatalf("handler: %v", err)
			}
			var result postToolOutput
			if err := json.Unmarshal(out.Bytes(), &result); err != nil {
				t.Fatalf("invalid JSON: %v", err)
			}
			if !strings.Contains(result.HookSpecificOutput.AdditionalContext, tc.wantBase) {
				t.Errorf("expected %q in additionalContext, got %q",
					tc.wantBase, result.HookSpecificOutput.AdditionalContext)
			}
		})
	}
}

// TestAutoBroadcast_ExtensionRuleAvoidsFalsePositive guards the
// filepath.Ext-vs-strings.Contains choice. A path like "go-tooling.txt"
// contains "go" but its extension is ".txt" — it must NOT broadcast.
// Without this check, a substring-based extension rule would silently
// match anything containing ".go" as a path token.
func TestAutoBroadcast_ExtensionRuleAvoidsFalsePositive(t *testing.T) {
	dir := t.TempDir()
	t.Chdir(dir)
	t.Setenv("HARNESS_PROJECT_ROOT", dir)

	input := `{"session_id":"sess-fp","cwd":"` + dir + `","tool_input":{"file_path":"docs/go-tooling.txt"}}`
	var out bytes.Buffer
	if err := HandleSessionAutoBroadcast(strings.NewReader(input), &out); err != nil {
		t.Fatalf("handler: %v", err)
	}
	var result postToolOutput
	if err := json.Unmarshal(out.Bytes(), &result); err != nil {
		t.Fatalf("invalid JSON: %v", err)
	}
	if result.HookSpecificOutput.AdditionalContext != "" {
		t.Errorf("expected NO broadcast for .txt file, got %q",
			result.HookSpecificOutput.AdditionalContext)
	}
	if _, err := os.Stat(filepath.Join(dir, ".claude", "sessions", "broadcast.md")); err == nil {
		t.Errorf("broadcast.md should not exist for .txt file")
	}
}

// TestInboxCheck_InjectsAfterRevival is the Phase 85.1.6 chain test:
// after the extension rule fires for peer A's .go edit, peer B's
// PreToolUse inbox-check must surface that broadcast as additionalContext.
// Before the revival this chain was dead because no .go edit ever produced
// a broadcast for inbox-check to read.
func TestInboxCheck_InjectsAfterRevival(t *testing.T) {
	dir := t.TempDir()
	t.Chdir(dir)
	t.Setenv("HARNESS_PROJECT_ROOT", dir)

	// Step 1: peer A's broadcast for a .go edit.
	bPayload := `{"session_id":"peer-A","cwd":"` + dir + `","tool_input":{"file_path":"go/internal/lease.go"}}`
	var bOut bytes.Buffer
	if err := HandleSessionAutoBroadcast(strings.NewReader(bPayload), &bOut); err != nil {
		t.Fatalf("broadcast: %v", err)
	}
	broadcastFile := filepath.Join(dir, ".claude", "sessions", "broadcast.md")
	if _, err := os.Stat(broadcastFile); err != nil {
		t.Fatalf("broadcast.md not created — revival broken before step 2: %v", err)
	}

	// Step 2: peer B's inbox-check.
	iPayload := `{"session_id":"peer-B","cwd":"` + dir + `"}`
	var iOut bytes.Buffer
	if err := HandleInboxCheck(strings.NewReader(iPayload), &iOut); err != nil {
		t.Fatalf("inbox-check: %v", err)
	}
	body := iOut.String()
	if body == "" {
		t.Fatal("inbox-check produced no output — chain still dead")
	}
	if !strings.Contains(body, "additionalContext") {
		t.Fatalf("inbox-check missing additionalContext: %s", body)
	}
	// The Phase 85.1.2 injection-safe context wraps the disclaimer and
	// uses only structured fields. The sanitized path must show up; the
	// peer's session_id prefix (peer-A) must show up; the free-text
	// broadcast line (pattern '*.go' explanation) must NOT.
	if !strings.Contains(body, "lease.go") {
		t.Fatalf("inbox-check did not surface peer A's file: %s", body)
	}
	if !strings.Contains(body, "peer-A") {
		t.Fatalf("inbox-check did not surface peer A's session prefix: %s", body)
	}
	if strings.Contains(body, "*.go") {
		t.Fatalf("inbox-check leaked raw broadcast pattern label into model context (injection risk): %s", body)
	}
}
