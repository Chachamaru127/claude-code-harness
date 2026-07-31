package hookhandler

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func initGitRepoForPresence(t *testing.T) string {
	t.Helper()
	dir := t.TempDir()
	cmd := exec.Command("git", "init", "-q")
	cmd.Dir = dir
	if out, err := cmd.CombinedOutput(); err != nil {
		t.Fatalf("git init: %s: %v", out, err)
	}
	for _, args := range [][]string{
		{"config", "user.email", "test@test"},
		{"config", "user.name", "test"},
	} {
		cmd := exec.Command("git", args...)
		cmd.Dir = dir
		if out, err := cmd.CombinedOutput(); err != nil {
			t.Fatalf("git %v: %s: %v", args, out, err)
		}
	}
	return dir
}

func presencePath(t *testing.T, projectRoot, sessionID string) string {
	t.Helper()
	dir := sharedLiveSessionsDirFromRoot(projectRoot)
	if dir == "" {
		t.Fatal("sharedLiveSessionsDirFromRoot returned empty")
	}
	return filepath.Join(dir, sessionID)
}

// TestSharedPresence_RegisterCreatesFile pins the writer: SessionStart must
// touch a 0600 presence file under the git-common-dir parent's live-sessions/.
func TestSharedPresence_RegisterCreatesFile(t *testing.T) {
	dir := initGitRepoForPresence(t)
	t.Setenv("HARNESS_PROJECT_ROOT", dir)

	const sessionID = "sess-presence-register"
	if err := HandleSessionRegister(strings.NewReader(`{"session_id":"`+sessionID+`"}`), nil); err != nil {
		t.Fatalf("register: %v", err)
	}

	path := presencePath(t, dir, sessionID)
	info, err := os.Stat(path)
	if err != nil {
		t.Fatalf("presence file should exist: %v", err)
	}
	if mode := info.Mode().Perm(); mode != presenceFileMode {
		t.Errorf("presence file mode = %o, want %o", mode, presenceFileMode)
	}
}

// TestSharedPresence_UnregisterRemovesOwnFile ensures Stop deletes only the
// caller's presence file and leaves peers untouched.
func TestSharedPresence_UnregisterRemovesOwnFile(t *testing.T) {
	dir := initGitRepoForPresence(t)
	t.Setenv("HARNESS_PROJECT_ROOT", dir)

	const self = "sess-presence-self"
	const peer = "sess-presence-peer"

	if err := HandleSessionRegister(strings.NewReader(`{"session_id":"`+self+`"}`), nil); err != nil {
		t.Fatal(err)
	}
	if err := HandleSessionRegister(strings.NewReader(`{"session_id":"`+peer+`"}`), nil); err != nil {
		t.Fatal(err)
	}

	if err := HandleSessionUnregister(strings.NewReader(`{"session_id":"`+self+`"}`), nil); err != nil {
		t.Fatal(err)
	}

	if _, err := os.Stat(presencePath(t, dir, self)); !os.IsNotExist(err) {
		t.Errorf("own presence file should be removed, stat err=%v", err)
	}
	if _, err := os.Stat(presencePath(t, dir, peer)); err != nil {
		t.Errorf("peer presence file must remain: %v", err)
	}
}

// TestSharedPresence_PruneStale removes presence files older than 24h during
// register, except the current session's file.
func TestSharedPresence_PruneStale(t *testing.T) {
	dir := initGitRepoForPresence(t)
	t.Setenv("HARNESS_PROJECT_ROOT", dir)

	liveDir := sharedLiveSessionsDirFromRoot(dir)
	if err := os.MkdirAll(liveDir, presenceDirMode); err != nil {
		t.Fatal(err)
	}
	staleID := "sess-presence-stale"
	stalePath := filepath.Join(liveDir, staleID)
	if err := os.WriteFile(stalePath, nil, presenceFileMode); err != nil {
		t.Fatal(err)
	}
	old := time.Now().Add(-25 * time.Hour)
	if err := os.Chtimes(stalePath, old, old); err != nil {
		t.Fatal(err)
	}

	const freshRegister = "sess-presence-fresh-register"
	if err := HandleSessionRegister(strings.NewReader(`{"session_id":"`+freshRegister+`"}`), nil); err != nil {
		t.Fatal(err)
	}

	if _, err := os.Stat(stalePath); !os.IsNotExist(err) {
		t.Errorf("stale presence file should be pruned, stat err=%v", err)
	}
	if _, err := os.Stat(presencePath(t, dir, freshRegister)); err != nil {
		t.Errorf("fresh register presence must exist: %v", err)
	}
}

// TestSharedPresence_InvalidSessionIDSkipsWrite ensures non-conforming ids do
// not create files under live-sessions/.
func TestSharedPresence_InvalidSessionIDSkipsWrite(t *testing.T) {
	dir := initGitRepoForPresence(t)
	t.Setenv("HARNESS_PROJECT_ROOT", dir)

	const badID = "weird$$name"
	if err := HandleSessionRegister(strings.NewReader(`{"session_id":"`+badID+`"}`), nil); err != nil {
		t.Fatal(err)
	}

	liveDir := sharedLiveSessionsDirFromRoot(dir)
	if liveDir == "" {
		t.Fatal("expected live-sessions dir resolution")
	}
	if _, err := os.Stat(filepath.Join(liveDir, badID)); !os.IsNotExist(err) {
		t.Errorf("invalid session id must not create a presence file, stat err=%v", err)
	}
}

// TestSharedPresence_CoexistsWithActiveJSON confirms a normal checkout keeps
// worktree-local active.json and shared presence independent (single active.json
// entry per register, no duplicate keys).
func TestSharedPresence_CoexistsWithActiveJSON(t *testing.T) {
	dir := initGitRepoForPresence(t)
	t.Setenv("HARNESS_PROJECT_ROOT", dir)

	const sessionID = "sess-coexist-active"
	if err := HandleSessionRegister(strings.NewReader(`{"session_id":"`+sessionID+`"}`), nil); err != nil {
		t.Fatal(err)
	}

	activeFile := filepath.Join(dir, ".claude", "sessions", "active.json")
	if _, err := os.Stat(activeFile); err != nil {
		t.Fatalf("active.json must exist: %v", err)
	}
	if _, err := os.Stat(presencePath(t, dir, sessionID)); err != nil {
		t.Fatalf("presence file must exist alongside active.json: %v", err)
	}

	if err := HandleSessionRegister(strings.NewReader(`{"session_id":"`+sessionID+`"}`), nil); err != nil {
		t.Fatal(err)
	}
	data, err := os.ReadFile(activeFile)
	if err != nil {
		t.Fatal(err)
	}
	if strings.Count(string(data), sessionID) != 1 {
		t.Errorf("active.json must contain exactly one entry for session id, got: %s", data)
	}
}

// TestIsStale_NilLiveSessionsHonorsSharedPresence pins that shared presence is
// consulted even when the worktree-local roster is nil (missing/corrupt
// active.json): TTL-expired lock + fresh presence for the holder must not
// reclaim.
func TestIsStale_NilLiveSessionsHonorsSharedPresence(t *testing.T) {
	const (
		holder  = "sess-holder-nil-roster"
		caller  = "sess-caller-nil-roster"
		relPath = "go/nil-roster-presence.go"
	)
	dir := initGitRepoForPresence(t)
	commonDir, ok := resolveGitCommonDir(dir)
	if !ok {
		t.Fatal("resolveGitCommonDir failed")
	}
	seedTTLExpiredLock(t, commonDir, holder, relPath)
	plantSharedPresenceFile(t, dir, holder)

	cfg := LeaseConfig{
		RepoRoot:     dir,
		GitCommonDir: commonDir,
		SessionID:    caller,
		LiveSessions: nil,
	}
	res, err := AcquireLease(relPath, cfg)
	if err != nil {
		t.Fatalf("AcquireLease: %v", err)
	}
	if res.Status != StatusHeldByOther {
		t.Fatalf("status = %v, want StatusHeldByOther when holder has fresh shared presence but LiveSessions is nil; holder=%#v",
			res.Status, res.Holder)
	}
	if res.Holder == nil || res.Holder.SessionID != holder {
		t.Fatalf("holder = %#v, want session %q", res.Holder, holder)
	}
}
