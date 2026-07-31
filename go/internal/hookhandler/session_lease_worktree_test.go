package hookhandler

import (
	"encoding/json"
	"os"
	"os/exec"
	"path/filepath"
	"testing"
	"time"
)

// runGitIn runs git in dir with a fixed test identity (local config only).
func runGitIn(t *testing.T, dir string, args ...string) {
	t.Helper()
	cmd := exec.Command("git", args...)
	cmd.Dir = dir
	cmd.Env = append(os.Environ(),
		"GIT_AUTHOR_NAME=test", "GIT_AUTHOR_EMAIL=test@test",
		"GIT_COMMITTER_NAME=test", "GIT_COMMITTER_EMAIL=test@test",
	)
	if out, err := cmd.CombinedOutput(); err != nil {
		t.Fatalf("git %v in %s: %s: %v", args, dir, out, err)
	}
}

// initMainRepoAndLinkedWorktree creates a real git repo with one commit and a
// linked worktree so leaseHookRepoFromCWD exercises worktree .git pointer files.
func initMainRepoAndLinkedWorktree(t *testing.T) (mainRoot, worktreeRoot string) {
	t.Helper()
	base := t.TempDir()
	mainRoot = filepath.Join(base, "main")
	if err := os.MkdirAll(mainRoot, 0o755); err != nil {
		t.Fatal(err)
	}
	runGitIn(t, mainRoot, "init", "-q")
	runGitIn(t, mainRoot, "config", "user.email", "test@test")
	runGitIn(t, mainRoot, "config", "user.name", "test")
	if err := os.WriteFile(filepath.Join(mainRoot, "README"), []byte("seed\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	runGitIn(t, mainRoot, "add", "README")
	runGitIn(t, mainRoot, "commit", "-q", "-m", "seed")
	worktreeRoot = filepath.Join(base, "wt")
	runGitIn(t, mainRoot, "worktree", "add", "-q", worktreeRoot, "-b", "parallel")
	return mainRoot, worktreeRoot
}

// leaseCfgFromHookCWD mirrors HandlePostToolUseFileLease / HandlePreToolUseFileLease.
func leaseCfgFromHookCWD(t *testing.T, cwd, sessionID string) LeaseConfig {
	t.Helper()
	repoRoot, gitCommonDir, ok := leaseHookRepoFromCWD(cwd)
	if !ok {
		t.Fatal("leaseHookRepoFromCWD: cwd is not inside a git repo")
	}
	return LeaseConfig{
		RepoRoot:     repoRoot,
		GitCommonDir: gitCommonDir,
		SessionID:    sessionID,
		LiveSessions: LoadLiveSessionsFromActiveJSON(repoRoot),
	}
}

func seedTTLExpiredLock(t *testing.T, gitCommonDir, holderSession, relPath string) {
	t.Helper()
	cfg := LeaseConfig{GitCommonDir: gitCommonDir}
	storeDir, reason := leaseStore(cfg)
	if storeDir == "" {
		t.Fatalf("leaseStore: %s", reason)
	}
	if err := os.MkdirAll(storeDir, leaseDirMode); err != nil {
		t.Fatal(err)
	}
	lockPath := filepath.Join(storeDir, leaseKey(relPath)+".lock")
	holder := LeaseHolder{
		SessionID:        holderSession,
		HolderPID:        4242,
		AcquiredAt:       time.Now().Add(-2 * defaultLeaseTTL).Unix(),
		RepoRelativePath: relPath,
	}
	raw, err := json.MarshalIndent(holder, "", "  ")
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(lockPath, raw, lockFileMode); err != nil {
		t.Fatal(err)
	}
}

func plantSharedPresenceFile(t *testing.T, mainRoot, sessionID string) {
	t.Helper()
	dir := filepath.Join(mainRoot, ".claude", "sessions", "live-sessions")
	if err := os.MkdirAll(dir, 0o700); err != nil {
		t.Fatal(err)
	}
	presencePath := filepath.Join(dir, sessionID)
	if err := os.WriteFile(presencePath, nil, 0o600); err != nil {
		t.Fatal(err)
	}
	now := time.Now()
	if err := os.Chtimes(presencePath, now, now); err != nil {
		t.Fatal(err)
	}
}

func writeWorktreeActiveJSON(t *testing.T, worktreeRoot string, sessionIDs ...string) {
	t.Helper()
	sessionsDir := filepath.Join(worktreeRoot, ".claude", "sessions")
	if err := os.MkdirAll(sessionsDir, 0o755); err != nil {
		t.Fatal(err)
	}
	now := time.Now().Unix()
	body := make(map[string]ActiveSession, len(sessionIDs))
	for _, id := range sessionIDs {
		short := id
		if len(short) > 12 {
			short = short[:12]
		}
		body[id] = ActiveSession{
			ShortID:  short,
			LastSeen: now,
			PID:      "1",
			Status:   "active",
		}
	}
	raw, err := json.Marshal(body)
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(sessionsDir, "active.json"), raw, 0o644); err != nil {
		t.Fatal(err)
	}
}

// TestLeaseStaleness_SharedPresenceHealthy is RED until Task 120.2 merges shared
// live-sessions presence into the liveness union. Holder A is alive only via a
// presence file on the main checkout; the linked worktree's active.json omits A.
func TestLeaseStaleness_SharedPresenceHealthy(t *testing.T) {
	const (
		sessionA = "sess-holder-worktree-a"
		sessionB = "sess-observer-worktree-b"
		relPath  = "go/cross-wt.go"
	)
	mainRoot, worktreeRoot := initMainRepoAndLinkedWorktree(t)

	_, gitCommonDir, ok := leaseHookRepoFromCWD(mainRoot)
	if !ok {
		t.Fatal("main checkout git resolution failed")
	}
	seedTTLExpiredLock(t, gitCommonDir, sessionA, relPath)
	plantSharedPresenceFile(t, mainRoot, sessionA)

	// Worktree-local roster: B only — A is intentionally absent (the bug scenario).
	writeWorktreeActiveJSON(t, worktreeRoot, sessionB)

	cfg := leaseCfgFromHookCWD(t, worktreeRoot, sessionB)
	res, err := AcquireLease(relPath, cfg)
	if err != nil {
		t.Fatalf("AcquireLease: %v", err)
	}
	if res.Status != StatusHeldByOther {
		t.Fatalf("status = %v, want StatusHeldByOther (shared presence must keep holder A alive); holder=%#v",
			res.Status, res.Holder)
	}
	if res.Holder == nil || res.Holder.SessionID != sessionA {
		t.Fatalf("holder = %#v, want session %q", res.Holder, sessionA)
	}

	check := CheckLease(relPath, cfg)
	if check.Status != StatusHeldByOther {
		t.Errorf("CheckLease status = %v, want StatusHeldByOther", check.Status)
	}
}

// TestLeaseStaleness_BothRostersAbsentReclaims pins reclaim when neither shared
// presence nor worktree-local active.json lists the TTL-expired holder.
func TestLeaseStaleness_BothRostersAbsentReclaims(t *testing.T) {
	const (
		sessionDead = "sess-dead-cross-wt"
		sessionB    = "sess-reclaimer-b"
		relPath     = "go/reclaim-both-absent.go"
	)
	mainRoot, worktreeRoot := initMainRepoAndLinkedWorktree(t)

	_, gitCommonDir, ok := leaseHookRepoFromCWD(mainRoot)
	if !ok {
		t.Fatal("main checkout git resolution failed")
	}
	seedTTLExpiredLock(t, gitCommonDir, sessionDead, relPath)
	// No live-sessions/ tree and sessionDead omitted from worktree active.json.
	writeWorktreeActiveJSON(t, worktreeRoot, sessionB)

	cfg := leaseCfgFromHookCWD(t, worktreeRoot, sessionB)
	res, err := AcquireLease(relPath, cfg)
	if err != nil {
		t.Fatalf("AcquireLease: %v", err)
	}
	if res.Status != StatusAcquired {
		t.Fatalf("status = %v, want StatusAcquired (both rosters absent ⇒ reclaim); holder=%#v",
			res.Status, res.Holder)
	}
}

// TestSharedPresence_NotConfigured: shared live-sessions dir absent ⇒ same
// TTL-only liveness fallback as today (reclaim when holder not in local active.json).
func TestSharedPresence_NotConfigured(t *testing.T) {
	const (
		sessionDead = "sess-dead-not-configured"
		sessionB    = "sess-b-not-configured"
		relPath     = "go/not-configured-presence.go"
	)
	mainRoot, worktreeRoot := initMainRepoAndLinkedWorktree(t)

	if _, err := os.Stat(filepath.Join(mainRoot, ".claude", "sessions", "live-sessions")); err == nil {
		t.Fatal("live-sessions must be absent for not-configured arm")
	}

	_, gitCommonDir, ok := leaseHookRepoFromCWD(mainRoot)
	if !ok {
		t.Fatal("main checkout git resolution failed")
	}
	seedTTLExpiredLock(t, gitCommonDir, sessionDead, relPath)
	writeWorktreeActiveJSON(t, worktreeRoot, sessionB)

	cfg := leaseCfgFromHookCWD(t, worktreeRoot, sessionB)
	res, err := AcquireLease(relPath, cfg)
	if err != nil {
		t.Fatalf("AcquireLease: %v", err)
	}
	if res.Status != StatusAcquired {
		t.Fatalf("not-configured shared presence must fall back to local-only reclaim; status=%v holder=%#v",
			res.Status, res.Holder)
	}
}

// TestSharedPresence_Corrupted: junk filenames under live-sessions/ must not
// count as live sessions; TTL-expired absent holder remains reclaimable.
func TestSharedPresence_Corrupted(t *testing.T) {
	const (
		sessionDead = "sess-dead-corrupted-presence"
		sessionB    = "sess-b-corrupted-presence"
		relPath     = "go/corrupted-presence.go"
	)
	mainRoot, worktreeRoot := initMainRepoAndLinkedWorktree(t)

	presenceDir := filepath.Join(mainRoot, ".claude", "sessions", "live-sessions")
	if err := os.MkdirAll(presenceDir, 0o700); err != nil {
		t.Fatal(err)
	}
	// Not a plausible session id — future loader must skip without crashing.
	if err := os.WriteFile(filepath.Join(presenceDir, "weird$$name"), []byte("junk"), 0o600); err != nil {
		t.Fatal(err)
	}

	_, gitCommonDir, ok := leaseHookRepoFromCWD(mainRoot)
	if !ok {
		t.Fatal("main checkout git resolution failed")
	}
	seedTTLExpiredLock(t, gitCommonDir, sessionDead, relPath)
	writeWorktreeActiveJSON(t, worktreeRoot, sessionB)

	cfg := leaseCfgFromHookCWD(t, worktreeRoot, sessionB)
	res, err := AcquireLease(relPath, cfg)
	if err != nil {
		t.Fatalf("AcquireLease: %v", err)
	}
	if res.Status != StatusAcquired {
		t.Fatalf("corrupted presence entries must not block reclaim; status=%v holder=%#v",
			res.Status, res.Holder)
	}
}
