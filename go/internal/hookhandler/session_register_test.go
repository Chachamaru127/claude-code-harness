package hookhandler

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

// TestRegisterHealth_NotConfigured covers the tri-state "not-configured"
// arm from active-watching-test-policy.md: SessionStart fires without a
// session_id (e.g., a bootstrap fallback path) and we must neither create
// state nor surface a warning. The hook is opt-in, so absence == silence.
func TestRegisterHealth_NotConfigured(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("HARNESS_PROJECT_ROOT", dir)

	if err := HandleSessionRegister(strings.NewReader(`{}`), nil); err != nil {
		t.Errorf("not-configured path must not return error: %v", err)
	}
	activeFile := filepath.Join(dir, ".claude", "sessions", "active.json")
	if _, err := os.Stat(activeFile); !os.IsNotExist(err) {
		t.Errorf("active.json must not be created when session_id is empty, stat err=%v", err)
	}
}

// TestRegisterHealth_Healthy covers the happy path: a valid SessionStart
// produces an entry whose shape matches scripts/session-register.sh's
// active.json schema (short_id 12 chars, status=active, positive
// last_seen, non-empty pid). The contract is exercised via the public
// JSON, not by reaching into internals, so a future bash-only consumer
// of active.json remains compatible.
func TestRegisterHealth_Healthy(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("HARNESS_PROJECT_ROOT", dir)

	if err := HandleSessionRegister(strings.NewReader(`{"session_id":"test-session-abc123def456"}`), nil); err != nil {
		t.Fatalf("healthy register returned error: %v", err)
	}

	activeFile := filepath.Join(dir, ".claude", "sessions", "active.json")
	data, err := os.ReadFile(activeFile)
	if err != nil {
		t.Fatalf("active.json should be created on healthy register: %v", err)
	}

	var sessions map[string]ActiveSession
	if err := json.Unmarshal(data, &sessions); err != nil {
		t.Fatalf("active.json is not valid JSON: %v\nraw=%s", err, data)
	}

	s, ok := sessions["test-session-abc123def456"]
	if !ok {
		t.Fatalf("session_id missing from active.json; raw=%s", data)
	}
	if s.ShortID != "test-session" {
		t.Errorf("short_id should be the 12-char session_id prefix, got %q", s.ShortID)
	}
	if s.Status != "active" {
		t.Errorf("status should be %q, got %q", "active", s.Status)
	}
	if s.PID == "" {
		t.Error("pid must be set; empty pid means the writer skipped recording it")
	}
	if s.LastSeen <= 0 {
		t.Errorf("last_seen should be a positive epoch, got %d", s.LastSeen)
	}
}

// TestRegisterHealth_Corrupted covers the tri-state "corrupted" arm: a
// preexisting active.json that fails JSON parse must not crash the
// SessionStart chain. Per active-watching-test-policy.md the handler
// silently recovers — the next healthy register rebuilds the file.
func TestRegisterHealth_Corrupted(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("HARNESS_PROJECT_ROOT", dir)

	sessionsDir := filepath.Join(dir, ".claude", "sessions")
	if err := os.MkdirAll(sessionsDir, 0o755); err != nil {
		t.Fatal(err)
	}
	activeFile := filepath.Join(sessionsDir, "active.json")
	if err := os.WriteFile(activeFile, []byte("{not valid json"), 0o644); err != nil {
		t.Fatal(err)
	}

	if err := HandleSessionRegister(strings.NewReader(`{"session_id":"recovery-session"}`), nil); err != nil {
		t.Fatalf("corrupted state should not propagate an error: %v", err)
	}

	data, err := os.ReadFile(activeFile)
	if err != nil {
		t.Fatalf("active.json should still exist after recovery: %v", err)
	}
	var sessions map[string]ActiveSession
	if err := json.Unmarshal(data, &sessions); err != nil {
		t.Errorf("active.json should be repaired to valid JSON, got error %v\nraw=%s", err, data)
	}
	if _, ok := sessions["recovery-session"]; !ok {
		t.Errorf("recovery register entry should be present after corruption: %s", data)
	}
}

// TestSessionUnregister_RemovesEntry covers the Stop hook contract: an
// entry that was registered must be hard-deleted from active.json so peers
// scanning for live coordination state see the truth immediately.
func TestSessionUnregister_RemovesEntry(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("HARNESS_PROJECT_ROOT", dir)

	payload := `{"session_id":"to-remove"}`
	if err := HandleSessionRegister(strings.NewReader(payload), nil); err != nil {
		t.Fatalf("register failed: %v", err)
	}
	if err := HandleSessionUnregister(strings.NewReader(payload), nil); err != nil {
		t.Fatalf("unregister failed: %v", err)
	}

	activeFile := filepath.Join(dir, ".claude", "sessions", "active.json")
	data, err := os.ReadFile(activeFile)
	if err != nil {
		t.Fatalf("active.json should still exist after unregister: %v", err)
	}
	var sessions map[string]ActiveSession
	if err := json.Unmarshal(data, &sessions); err != nil {
		t.Fatalf("invalid JSON after unregister: %v\n%s", err, data)
	}
	if _, ok := sessions["to-remove"]; ok {
		t.Errorf("entry should be removed by Unregister, got: %s", data)
	}
}

// TestRegister_StaleCleanup covers the bounded-growth invariant: entries
// older than registerStaleCutoff (24h) must be pruned during the next
// register write so active.json does not accumulate the long tail of
// crashed sessions that never ran Stop.
func TestRegister_StaleCleanup(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("HARNESS_PROJECT_ROOT", dir)

	sessionsDir := filepath.Join(dir, ".claude", "sessions")
	if err := os.MkdirAll(sessionsDir, 0o755); err != nil {
		t.Fatal(err)
	}
	activeFile := filepath.Join(sessionsDir, "active.json")

	now := time.Now().Unix()
	seed := map[string]ActiveSession{
		"stale-session": {ShortID: "stale-sessio", LastSeen: now - 26*3600, PID: "1", Status: "active"},
		"fresh-session": {ShortID: "fresh-sessio", LastSeen: now - 60, PID: "2", Status: "active"},
	}
	out, _ := json.MarshalIndent(seed, "", "  ")
	if err := os.WriteFile(activeFile, out, 0o644); err != nil {
		t.Fatal(err)
	}

	if err := HandleSessionRegister(strings.NewReader(`{"session_id":"new-session"}`), nil); err != nil {
		t.Fatalf("register failed: %v", err)
	}

	data, _ := os.ReadFile(activeFile)
	var sessions map[string]ActiveSession
	_ = json.Unmarshal(data, &sessions)

	if _, ok := sessions["stale-session"]; ok {
		t.Errorf("stale entry (>24h) should have been pruned, got: %s", data)
	}
	if _, ok := sessions["fresh-session"]; !ok {
		t.Errorf("fresh entry (<24h) must be preserved, got: %s", data)
	}
	if _, ok := sessions["new-session"]; !ok {
		t.Errorf("newly registered session must be present, got: %s", data)
	}
}

// TestUnregister_NoActiveJsonNoError covers a second not-configured arm:
// Stop fires before any register ever ran (e.g., a session that aborted
// mid-startup). The handler must not error and must not create state.
func TestUnregister_NoActiveJsonNoError(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("HARNESS_PROJECT_ROOT", dir)
	if err := HandleSessionUnregister(strings.NewReader(`{"session_id":"never-registered"}`), nil); err != nil {
		t.Errorf("unregister without prior active.json must not error: %v", err)
	}
	activeFile := filepath.Join(dir, ".claude", "sessions", "active.json")
	if _, err := os.Stat(activeFile); !os.IsNotExist(err) {
		t.Errorf("unregister must not create active.json out of nowhere, stat err=%v", err)
	}
}
