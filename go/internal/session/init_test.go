package session

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestInitHandler_Subagent(t *testing.T) {
	// Lightweight initialization for subagents
	h := &InitHandler{}
	inp := `{"agent_type":"subagent","session_id":"cc-123"}`
	var out bytes.Buffer
	err := h.Handle(strings.NewReader(inp), &out)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	var resp initResponse
	if err := json.Unmarshal(bytes.TrimRight(out.Bytes(), "\n"), &resp); err != nil {
		t.Fatalf("invalid JSON output: %v\nraw: %s", err, out.String())
	}
	if resp.HookSpecificOutput.HookEventName != "SessionStart" {
		t.Errorf("expected HookEventName=SessionStart, got %q", resp.HookSpecificOutput.HookEventName)
	}
	if !strings.Contains(resp.HookSpecificOutput.AdditionalContext, "subagent") {
		t.Errorf("expected subagent context, got %q", resp.HookSpecificOutput.AdditionalContext)
	}
}

func TestInitHandler_NewSession(t *testing.T) {
	dir := t.TempDir()
	stateDir := filepath.Join(dir, "state")

	// Plans.md なし
	h := &InitHandler{
		StateDir:  stateDir,
		PlansFile: filepath.Join(dir, "Plans.md"),
	}

	inp := `{"session_id":"cc-456","agent_type":"","cwd":"` + dir + `"}`
	var out bytes.Buffer
	err := h.Handle(strings.NewReader(inp), &out)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	var resp initResponse
	if err := json.Unmarshal(bytes.TrimRight(out.Bytes(), "\n"), &resp); err != nil {
		t.Fatalf("invalid JSON output: %v\nraw: %s", err, out.String())
	}
	if resp.HookSpecificOutput.HookEventName != "SessionStart" {
		t.Errorf("expected HookEventName=SessionStart, got %q", resp.HookSpecificOutput.HookEventName)
	}
	if !strings.Contains(resp.HookSpecificOutput.AdditionalContext, "Plans.md") {
		t.Errorf("expected Plans.md info in context, got %q", resp.HookSpecificOutput.AdditionalContext)
	}
	// Verify that the marker legend is included
	if !strings.Contains(resp.HookSpecificOutput.AdditionalContext, "cc:TODO") {
		t.Errorf("expected marker legend in context")
	}

	// session.json が作成されたか確認
	sessionFile := filepath.Join(stateDir, "session.json")
	if _, err := os.Stat(sessionFile); err != nil {
		t.Errorf("session.json not created: %v", err)
	}
}

func TestInitHandler_WithPlans(t *testing.T) {
	dir := t.TempDir()
	stateDir := filepath.Join(dir, "state")
	plansFile := filepath.Join(dir, "Plans.md")

	// Plans.md を作成
	content := `# Plans
| Task | Status |
|------|--------|
| task1 | cc:WIP |
| task2 | cc:TODO |
| task3 | cc:TODO |
| task4 | pm:依頼中 |
`
	if err := os.WriteFile(plansFile, []byte(content), 0644); err != nil {
		t.Fatal(err)
	}

	h := &InitHandler{
		StateDir:  stateDir,
		PlansFile: plansFile,
	}

	var out bytes.Buffer
	err := h.Handle(strings.NewReader(`{"cwd":"`+dir+`"}`), &out)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	var resp initResponse
	if err := json.Unmarshal(bytes.TrimRight(out.Bytes(), "\n"), &resp); err != nil {
		t.Fatalf("invalid JSON output: %v\nraw: %s", err, out.String())
	}

	ctx := resp.HookSpecificOutput.AdditionalContext
	// WIP=1 (cc:WIP) + pm:依頼中=1 → in-progress 2
	// TODO=2
	if !strings.Contains(ctx, "in-progress 2") {
		t.Errorf("expected in-progress 2 in context, got %q", ctx)
	}
	if !strings.Contains(ctx, "pending 2") {
		t.Errorf("expected pending 2 in context, got %q", ctx)
	}
}

func TestInitHandler_SymlinkSessionFile(t *testing.T) {
	// Symlink causes a security error (error is ignored and a response is still returned)
	dir := t.TempDir()
	stateDir := filepath.Join(dir, "state")
	if err := os.MkdirAll(stateDir, 0700); err != nil {
		t.Fatal(err)
	}

	// session.json をシンボリックリンクにする
	realFile := filepath.Join(dir, "real-session.json")
	if err := os.WriteFile(realFile, []byte(`{}`), 0600); err != nil {
		t.Fatal(err)
	}
	sessionLink := filepath.Join(stateDir, "session.json")
	if err := os.Symlink(realFile, sessionLink); err != nil {
		t.Skip("symlink creation not supported")
	}

	h := &InitHandler{
		StateDir:  stateDir,
		PlansFile: filepath.Join(dir, "Plans.md"),
	}

	var out bytes.Buffer
	// Should not return an error; a response is returned
	err := h.Handle(strings.NewReader(`{}`), &out)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	// Response must be valid JSON
	var resp initResponse
	if json.Unmarshal(bytes.TrimRight(out.Bytes(), "\n"), &resp) != nil {
		t.Errorf("invalid JSON output: %s", out.String())
	}
}

func TestInitHandler_EmptyInput(t *testing.T) {
	dir := t.TempDir()
	h := &InitHandler{
		StateDir:  filepath.Join(dir, "state"),
		PlansFile: filepath.Join(dir, "Plans.md"),
	}

	var out bytes.Buffer
	err := h.Handle(strings.NewReader(""), &out)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	var resp initResponse
	if json.Unmarshal(bytes.TrimRight(out.Bytes(), "\n"), &resp) != nil {
		t.Errorf("invalid JSON output: %s", out.String())
	}
	if resp.HookSpecificOutput.HookEventName != "SessionStart" {
		t.Errorf("expected HookEventName=SessionStart")
	}
}

func TestCountMatches(t *testing.T) {
	dir := t.TempDir()
	f := filepath.Join(dir, "test.md")
	content := "line1 cc:WIP\nline2 cc:TODO\nline3 pm:依頼中\nline4 cursor:依頼中\nline5 cc:完了\n"
	if err := os.WriteFile(f, []byte(content), 0644); err != nil {
		t.Fatal(err)
	}

	tests := []struct {
		patterns []string
		want     int
	}{
		{[]string{"cc:WIP"}, 1},
		{[]string{"cc:TODO"}, 1},
		{[]string{"pm:依頼中", "cursor:依頼中"}, 2},
		{[]string{"cc:WIP", "pm:依頼中", "cursor:依頼中"}, 3},
		{[]string{"cc:完了"}, 1},
		{[]string{"nonexistent"}, 0},
	}

	for _, tt := range tests {
		got := countMatches(f, tt.patterns...)
		if got != tt.want {
			t.Errorf("countMatches(%v) = %d, want %d", tt.patterns, got, tt.want)
		}
	}
}
