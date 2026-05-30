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

// TestAutoBroadcast_FileMode0600 covers Phase 85.1.7 fix S1: broadcast.md
// must be owner-only (0o600) so "who edited what + when" does not leak to
// other local users on shared hosts. The Phase 85 lease lock files use the
// same floor (session_lease.go:25-30), and broadcast.md actually carries
// more detail than a lock file.
func TestAutoBroadcast_FileMode0600(t *testing.T) {
	dir := t.TempDir()
	t.Chdir(dir)
	t.Setenv("HARNESS_PROJECT_ROOT", dir)

	input := `{"session_id":"sess-mode","cwd":"` + dir + `","tool_input":{"file_path":"go/foo.go"}}`
	var out bytes.Buffer
	if err := HandleSessionAutoBroadcast(strings.NewReader(input), &out); err != nil {
		t.Fatalf("handler: %v", err)
	}

	sessionsDir := filepath.Join(dir, ".claude", "sessions")
	dirInfo, err := os.Stat(sessionsDir)
	if err != nil {
		t.Fatalf("sessions dir not created: %v", err)
	}
	if got := dirInfo.Mode().Perm(); got != 0o700 {
		t.Errorf("sessions dir mode = %o, want 0o700", got)
	}

	bcastInfo, err := os.Stat(filepath.Join(sessionsDir, "broadcast.md"))
	if err != nil {
		t.Fatalf("broadcast.md not created: %v", err)
	}
	if got := bcastInfo.Mode().Perm(); got != 0o600 {
		t.Errorf("broadcast.md mode = %o, want 0o600", got)
	}
}

// TestAutoBroadcast_SkipSensitivePaths covers Phase 85.1.7 fix S2: paths
// that obviously carry secrets, per-developer SSOT, or client-identifying
// names must not cross sessions through broadcast.md. The check is
// conservative (only the obvious leaks) — full coverage is the Phase 65.3
// redaction contract's job.
func TestAutoBroadcast_SkipSensitivePaths(t *testing.T) {
	cases := []struct {
		name     string
		filePath string
	}{
		{"env_dotfile", ".env"},
		{"env_with_suffix", ".env.local"},
		{"key_extension", "deploy/server.key"},
		{"pem_extension", "certs/intermediate.pem"},
		{"secrets_segment", "config/secrets/db_password.txt"},
		{"claude_memory_segment", ".claude/memory/decisions.md"},
		{"ssh_segment", "home/.ssh/id_ed25519"},
		{"clients_segment", "engagements/clients/acme/proposal.md"},
		{"credentials_segment", "ops/credentials/aws.json"},
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
			if result.HookSpecificOutput.AdditionalContext != "" {
				t.Errorf("expected silent skip for %s, got %q",
					tc.filePath, result.HookSpecificOutput.AdditionalContext)
			}
			// broadcast.md must NOT exist for sensitive paths
			if _, err := os.Stat(filepath.Join(dir, ".claude", "sessions", "broadcast.md")); err == nil {
				t.Errorf("broadcast.md should not exist for sensitive path %s", tc.filePath)
			}
		})
	}
}

// TestAutoBroadcast_SubdirectoryStillReachesPeer covers Phase 85.1.7 fix
// S3: when the hook fires from a subdirectory (e.g. cwd is /repo/go/ but
// editing go/foo.go), the broadcast must still land at the project root
// .claude/sessions/broadcast.md so inbox-check (which uses git toplevel)
// can read it. Before the fix this was a silent producer/consumer
// mismatch that broke cross-session coordination from any subdir.
func TestAutoBroadcast_SubdirectoryStillReachesPeer(t *testing.T) {
	root := t.TempDir()
	subdir := filepath.Join(root, "go", "internal")
	if err := os.MkdirAll(subdir, 0o700); err != nil {
		t.Fatalf("setup mkdir: %v", err)
	}
	// Set HARNESS_PROJECT_ROOT explicitly so resolveProjectRoot anchors
	// on root regardless of whether $TMPDIR happens to be inside a git
	// tree.
	t.Setenv("HARNESS_PROJECT_ROOT", root)
	t.Chdir(subdir) // hook fires from subdir

	input := `{"session_id":"sess-subdir","cwd":"` + subdir + `","tool_input":{"file_path":"foo.go"}}`
	var out bytes.Buffer
	if err := HandleSessionAutoBroadcast(strings.NewReader(input), &out); err != nil {
		t.Fatalf("handler: %v", err)
	}

	rootBroadcast := filepath.Join(root, ".claude", "sessions", "broadcast.md")
	if _, err := os.Stat(rootBroadcast); err != nil {
		t.Fatalf("broadcast.md should land at project root, missing: %v", err)
	}

	subdirBroadcast := filepath.Join(subdir, ".claude", "sessions", "broadcast.md")
	if _, err := os.Stat(subdirBroadcast); err == nil {
		t.Errorf("broadcast.md unexpectedly written under subdir at %s", subdirBroadcast)
	}
}

// TestRotateBroadcastMD covers Phase 85.1.7 fix C1: when broadcast.md
// exceeds maxEntries headers, rotation truncates to the trailing
// keepEntries entries, atomically, preserving the most recent entries
// so inbox-check still surfaces fresh peer activity.
func TestRotateBroadcastMD(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "broadcast.md")

	// Build a synthetic file with 10 entries, then rotate to keep 4.
	var content bytes.Buffer
	for i := 0; i < 10; i++ {
		content.WriteString("\n## 2026-05-30T00:00:0")
		content.WriteString(string(rune('0' + i%10)))
		content.WriteString("Z [peer-")
		content.WriteString(string(rune('A' + i)))
		content.WriteString("]\n📁 `go/file")
		content.WriteString(string(rune('0' + i%10)))
		content.WriteString(".go` matched\n")
	}
	if err := os.WriteFile(path, content.Bytes(), 0o600); err != nil {
		t.Fatalf("setup write: %v", err)
	}

	if err := rotateBroadcastMD(path, 8, 4); err != nil {
		t.Fatalf("rotate: %v", err)
	}

	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("read after rotate: %v", err)
	}
	body := string(data)

	// Verify only the last 4 entries survived (peer-G/H/I/J for i=6..9).
	for _, want := range []string{"peer-G", "peer-H", "peer-I", "peer-J"} {
		if !strings.Contains(body, want) {
			t.Errorf("rotation lost trailing entry %s; body: %s", want, body)
		}
	}
	// Older entries must have been dropped.
	for _, gone := range []string{"peer-A", "peer-B", "peer-C", "peer-D", "peer-E", "peer-F"} {
		if strings.Contains(body, gone) {
			t.Errorf("rotation kept old entry %s; body: %s", gone, body)
		}
	}

	// Verify the file mode is 0o600 (rotation must preserve the Phase 85
	// security floor, not regress to default 0644 on rewrite).
	info, err := os.Stat(path)
	if err != nil {
		t.Fatalf("stat after rotate: %v", err)
	}
	if got := info.Mode().Perm(); got != 0o600 {
		t.Errorf("rotated broadcast.md mode = %o, want 0o600", got)
	}
}

// TestRotateBroadcastMD_NoOpUnderThreshold proves rotation is a no-op
// when the entry count fits within maxEntries — important because the
// rotation runs after every successful append and the common case is
// "well under the cap, do not rewrite".
func TestRotateBroadcastMD_NoOpUnderThreshold(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "broadcast.md")
	original := "\n## 2026-05-30T00:00:00Z [peer-X]\n📁 `go/foo.go` matched\n"
	if err := os.WriteFile(path, []byte(original), 0o600); err != nil {
		t.Fatalf("setup: %v", err)
	}
	if err := rotateBroadcastMD(path, 8, 4); err != nil {
		t.Fatalf("rotate: %v", err)
	}
	data, _ := os.ReadFile(path)
	if string(data) != original {
		t.Errorf("rotation modified file under threshold; got:\n%s\nwant:\n%s",
			string(data), original)
	}
}
