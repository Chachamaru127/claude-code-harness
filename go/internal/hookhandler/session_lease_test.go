package hookhandler

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"
)

// fakeGitCommonDir builds a writable directory tree that emulates the
// layout `git rev-parse --git-common-dir` would describe: a .git directory
// under a repo root. Returning the common dir's parent (= repo root) lets
// LeaseConfig.GitCommonDir bypass the real `git` invocation entirely, so
// tests do not depend on the host's git binary or repo state.
func fakeGitCommonDir(t *testing.T) (commonDir, repoRoot string) {
	t.Helper()
	repoRoot = t.TempDir()
	commonDir = filepath.Join(repoRoot, ".git")
	if err := os.MkdirAll(commonDir, 0o755); err != nil {
		t.Fatal(err)
	}
	return commonDir, repoRoot
}

func newLeaseCfg(t *testing.T, sessionID string) (LeaseConfig, string) {
	t.Helper()
	commonDir, repoRoot := fakeGitCommonDir(t)
	cfg := LeaseConfig{
		RepoRoot:     repoRoot,
		GitCommonDir: commonDir,
		SessionID:    sessionID,
		LiveSessions: map[string]struct{}{sessionID: {}},
	}
	return cfg, repoRoot
}

// TestLeaseAcquire_Healthy is the happy-path acquire: a fresh store
// produces a Status of Acquired and the on-disk lock file records the
// caller's session id.
func TestLeaseAcquire_Healthy(t *testing.T) {
	cfg, repoRoot := newLeaseCfg(t, "sess-healthy")
	res, err := AcquireLease("go/foo.go", cfg)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if res.Status != StatusAcquired {
		t.Fatalf("status = %v, want StatusAcquired", res.Status)
	}
	store := filepath.Join(repoRoot, ".claude", "sessions", "leases")
	entries, _ := os.ReadDir(store)
	if len(entries) != 1 {
		t.Fatalf("expected 1 lock file, got %d", len(entries))
	}
	if filepath.Ext(entries[0].Name()) != ".lock" {
		t.Errorf("lock filename should end in .lock, got %s", entries[0].Name())
	}
	if len(entries[0].Name()) != 64+len(".lock") {
		// sha256 is 64 hex chars; the filename is exactly that hash plus
		// the .lock extension. A different length means the key
		// derivation drifted from leaseKey.
		t.Errorf("lock filename should be 64 hex + .lock, got %d chars: %q",
			len(entries[0].Name()), entries[0].Name())
	}
}

// TestLeaseAcquire_HeldByOther covers the conflict case: a peer session
// holds the lock and the caller must receive StatusHeldByOther with the
// peer's identity populated, never silently overwrite.
func TestLeaseAcquire_HeldByOther(t *testing.T) {
	cfg, _ := newLeaseCfg(t, "sess-a")
	if _, err := AcquireLease("go/foo.go", cfg); err != nil {
		t.Fatalf("first acquire failed: %v", err)
	}

	cfgB := cfg
	cfgB.SessionID = "sess-b"
	cfgB.LiveSessions = map[string]struct{}{
		"sess-a": {}, // sess-a still alive — so the lock is NOT stale
		"sess-b": {},
	}
	res, err := AcquireLease("go/foo.go", cfgB)
	if err != nil {
		t.Fatalf("second acquire returned error: %v", err)
	}
	if res.Status != StatusHeldByOther {
		t.Errorf("status = %v, want StatusHeldByOther", res.Status)
	}
	if res.Holder == nil || res.Holder.SessionID != "sess-a" {
		t.Errorf("holder should be sess-a, got %#v", res.Holder)
	}
}

// TestLeaseAcquire_ReentrantSameSession allows the same session to acquire
// the same path twice (acquire-acquire is treated as refresh). This is the
// realistic case where PreToolUse fires twice on the same file inside one
// session — a strict mutex would deadlock the session against itself.
func TestLeaseAcquire_ReentrantSameSession(t *testing.T) {
	cfg, _ := newLeaseCfg(t, "sess-re")
	if _, err := AcquireLease("go/bar.go", cfg); err != nil {
		t.Fatalf("first acquire: %v", err)
	}
	res, err := AcquireLease("go/bar.go", cfg)
	if err != nil {
		t.Fatalf("re-acquire returned error: %v", err)
	}
	if res.Status != StatusAcquired {
		t.Errorf("re-acquire by same session should be StatusAcquired, got %v", res.Status)
	}
}

// TestLeaseAcquire_ConcurrentSameFile is the race regression test
// mandated by Phase 85.1.4 DoD (f). Spawn N goroutines that all attempt
// to acquire the same path through a sync.Barrier — only one must
// succeed. Run under `go test -race` to surface any non-atomic write or
// missing happens-before relationship.
func TestLeaseAcquire_ConcurrentSameFile(t *testing.T) {
	const N = 16
	commonDir, repoRoot := fakeGitCommonDir(t)
	var acquired int64
	var heldByOther int64
	var unavailable int64

	var wg sync.WaitGroup
	start := make(chan struct{})
	for i := 0; i < N; i++ {
		wg.Add(1)
		go func(idx int) {
			defer wg.Done()
			cfg := LeaseConfig{
				RepoRoot:     repoRoot,
				GitCommonDir: commonDir,
				SessionID:    fmt.Sprintf("sess-%d", idx),
				LiveSessions: map[string]struct{}{},
			}
			// All sessions are recorded as alive so no liveness-based
			// reclaim races; the test isolates the O_CREAT|O_EXCL
			// guarantee.
			for j := 0; j < N; j++ {
				cfg.LiveSessions[fmt.Sprintf("sess-%d", j)] = struct{}{}
			}
			<-start
			res, err := AcquireLease("go/contended.go", cfg)
			if err != nil {
				t.Errorf("goroutine %d: unexpected error: %v", idx, err)
				return
			}
			switch res.Status {
			case StatusAcquired:
				atomic.AddInt64(&acquired, 1)
			case StatusHeldByOther:
				atomic.AddInt64(&heldByOther, 1)
			case StatusUnavailable:
				atomic.AddInt64(&unavailable, 1)
			}
		}(i)
	}
	close(start)
	wg.Wait()

	if got := atomic.LoadInt64(&acquired); got != 1 {
		t.Errorf("exactly one goroutine must acquire, got %d", got)
	}
	if got := atomic.LoadInt64(&heldByOther); got != N-1 {
		t.Errorf("N-1 goroutines must observe StatusHeldByOther, got %d (unavailable=%d)",
			got, atomic.LoadInt64(&unavailable))
	}
}

// TestLeaseRelease_OnlyOwner verifies the safety invariant that release
// cannot be used to drop a peer's lease. A misbehaving session id must not
// be able to clobber a sibling's lock by calling ReleaseLease against the
// same path with a different session id.
func TestLeaseRelease_OnlyOwner(t *testing.T) {
	cfg, repoRoot := newLeaseCfg(t, "sess-owner")
	if _, err := AcquireLease("api/secret.go", cfg); err != nil {
		t.Fatalf("acquire: %v", err)
	}
	cfgIntruder := cfg
	cfgIntruder.SessionID = "sess-intruder"
	if err := ReleaseLease("api/secret.go", cfgIntruder); err != nil {
		t.Fatalf("intruder release returned error: %v", err)
	}
	// Lock must still exist.
	store := filepath.Join(repoRoot, ".claude", "sessions", "leases")
	entries, _ := os.ReadDir(store)
	if len(entries) != 1 {
		t.Errorf("lock must survive a non-owner release; got %d entries", len(entries))
	}

	// Owner can release.
	if err := ReleaseLease("api/secret.go", cfg); err != nil {
		t.Fatalf("owner release: %v", err)
	}
	entries, _ = os.ReadDir(store)
	if len(entries) != 0 {
		t.Errorf("lock should be gone after owner release; got %d entries", len(entries))
	}
}

// TestLeaseReclaim_StaleByTTL covers the AND condition: a lease that is
// both past its TTL AND held by a session id that is no longer in the
// live set must be reclaimable. The same test verifies the symmetric
// safety condition: a still-live peer (not in live set, but within TTL)
// is NOT reclaimable.
func TestLeaseReclaim_StaleByTTL(t *testing.T) {
	commonDir, repoRoot := fakeGitCommonDir(t)
	store := filepath.Join(repoRoot, ".claude", "sessions", "leases")
	if err := os.MkdirAll(store, 0o755); err != nil {
		t.Fatal(err)
	}
	path := "go/contested.go"
	lockPath := filepath.Join(store, leaseKey(path)+".lock")

	// Seed the store with a lock from a session that is now dead and
	// whose age exceeds the default TTL.
	deadHolder := LeaseHolder{
		SessionID:        "sess-dead",
		HolderPID:        99999,
		AcquiredAt:       time.Now().Add(-2 * defaultLeaseTTL).Unix(),
		RepoRelativePath: path,
	}
	raw, _ := json.MarshalIndent(deadHolder, "", "  ")
	if err := os.WriteFile(lockPath, raw, 0o644); err != nil {
		t.Fatal(err)
	}

	freshCfg := LeaseConfig{
		RepoRoot:     repoRoot,
		GitCommonDir: commonDir,
		SessionID:    "sess-fresh",
		LiveSessions: map[string]struct{}{"sess-fresh": {}}, // sess-dead is absent — dead
	}
	res, err := AcquireLease(path, freshCfg)
	if err != nil {
		t.Fatalf("acquire: %v", err)
	}
	if res.Status != StatusAcquired {
		t.Errorf("stale dead-session lease should be reclaimable; got %v (holder=%#v)",
			res.Status, res.Holder)
	}

	// Symmetric safety: re-seed but mark sess-dead as alive in the live
	// set even though its lease is TTL-expired. The AND condition fails
	// (liveness half is true) so reclaim must NOT happen.
	if err := os.WriteFile(lockPath, raw, 0o644); err != nil {
		t.Fatal(err)
	}
	resBlocked, _ := AcquireLease(path, LeaseConfig{
		RepoRoot:     repoRoot,
		GitCommonDir: commonDir,
		SessionID:    "sess-fresh-2",
		LiveSessions: map[string]struct{}{"sess-fresh-2": {}, "sess-dead": {}},
	})
	if resBlocked.Status != StatusHeldByOther {
		t.Errorf("TTL-expired but still-live session must NOT be reclaimed; got %v",
			resBlocked.Status)
	}
}

// TestLeaseKey_Traversal proves the path-traversal defense by construction:
// hostile path inputs (../, absolute paths, unicode, oversized strings)
// produce a key that is always 64 hex chars and lives directly inside the
// leases directory. There is no escape path because the key never includes
// any byte from the input.
func TestLeaseKey_Traversal(t *testing.T) {
	hostile := []string{
		"../../../etc/passwd",
		"/etc/shadow",
		"../" + string(make([]byte, 1024)),
		"こんにちは/秘密.txt",
		strings.Repeat("A", 4096),
	}
	for _, p := range hostile {
		key := leaseKey(p)
		if len(key) != 64 {
			t.Errorf("key for %q must be 64 hex chars, got %d", p, len(key))
		}
		// The key must be purely lowercase hex — no slashes, no dots.
		for _, ch := range key {
			ok := (ch >= '0' && ch <= '9') || (ch >= 'a' && ch <= 'f')
			if !ok {
				t.Errorf("key for %q contains non-hex char %q; full key=%s", p, ch, key)
				break
			}
		}
	}
}

// TestLeaseHealth_NotConfigured covers the tri-state silent arm: when the
// repo has no git common dir, AcquireLease must report StatusUnavailable
// with a reason matching the active-watching-test-policy enum, and never
// create a lease directory. The hook chain stays fail-open: the caller
// allows the edit.
func TestLeaseHealth_NotConfigured(t *testing.T) {
	noGit := t.TempDir() // no .git directory inside
	cfg := LeaseConfig{
		RepoRoot:  noGit,
		SessionID: "sess-no-git",
	}
	res, err := AcquireLease("go/x.go", cfg)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if res.Status != StatusUnavailable {
		t.Errorf("no-git env should yield StatusUnavailable, got %v", res.Status)
	}
	if res.Reason != "not-configured" {
		t.Errorf("reason should be %q, got %q", "not-configured", res.Reason)
	}
	if _, err := os.Stat(filepath.Join(noGit, ".claude")); err == nil {
		t.Errorf("not-configured arm must NOT create .claude/ as a side effect")
	}
}

// TestLeaseHealth_Corrupted covers the recovery arm: a pre-existing lock
// file whose contents do not parse as JSON must be reclaimed by the next
// healthy acquire, not propagate as an error to the caller. The session
// chain stays alive.
func TestLeaseHealth_Corrupted(t *testing.T) {
	cfg, repoRoot := newLeaseCfg(t, "sess-recover")
	store := filepath.Join(repoRoot, ".claude", "sessions", "leases")
	if err := os.MkdirAll(store, 0o755); err != nil {
		t.Fatal(err)
	}
	lockPath := filepath.Join(store, leaseKey("go/recover.go")+".lock")
	if err := os.WriteFile(lockPath, []byte("{this is not json"), 0o644); err != nil {
		t.Fatal(err)
	}
	res, err := AcquireLease("go/recover.go", cfg)
	if err != nil {
		t.Fatalf("corrupted recover returned error: %v", err)
	}
	if res.Status != StatusAcquired {
		t.Errorf("corrupted lock must be reclaimed; got %v", res.Status)
	}
	// File must now contain valid JSON owned by the new session.
	raw, _ := os.ReadFile(lockPath)
	var holder LeaseHolder
	if err := json.Unmarshal(raw, &holder); err != nil {
		t.Errorf("recovered lock must be valid JSON: %v\n%s", err, raw)
	}
	if holder.SessionID != "sess-recover" {
		t.Errorf("recovered lock should be owned by sess-recover, got %q", holder.SessionID)
	}
}

// TestLeaseHealth_HolderUnreachable verifies the tri-state pattern when
// the on-disk lock references a session id that does not appear in the
// live set AND the TTL has expired (the AND condition). Treating that as
// stale instead of "holder unreachable" is the documented behavior; the
// reason exists at the LeaseResult level only for the Unavailable arm.
// This test pins that distinction so a future refactor does not confuse
// dead-holder reclaim with a true unavailable signal.
func TestLeaseHealth_HolderUnreachable(t *testing.T) {
	commonDir, repoRoot := fakeGitCommonDir(t)
	store := filepath.Join(repoRoot, ".claude", "sessions", "leases")
	if err := os.MkdirAll(store, 0o755); err != nil {
		t.Fatal(err)
	}
	path := "go/unreachable.go"
	deadHolder := LeaseHolder{
		SessionID:        "sess-disappeared",
		HolderPID:        424242,
		AcquiredAt:       time.Now().Add(-90 * time.Minute).Unix(),
		RepoRelativePath: path,
	}
	raw, _ := json.MarshalIndent(deadHolder, "", "  ")
	_ = os.WriteFile(filepath.Join(store, leaseKey(path)+".lock"), raw, 0o644)

	res := CheckLease(path, LeaseConfig{
		RepoRoot:     repoRoot,
		GitCommonDir: commonDir,
		SessionID:    "sess-observer",
		LiveSessions: map[string]struct{}{"sess-observer": {}}, // sess-disappeared not present
	})
	if res.Status != StatusAcquired {
		t.Errorf("CheckLease should report a dead holder's lease as free; got %v (holder=%#v)",
			res.Status, res.Holder)
	}
}

// TestLease_Worktree pins the Phase 85.1.4 worktree-share invariant: two
// LeaseConfig instances that target the same GitCommonDir but live under
// different worktree paths must see exactly the same lease store. If a
// future refactor accidentally roots the store at the per-worktree
// .claude/ instead of the shared git-common-dir, this test fails.
func TestLease_Worktree(t *testing.T) {
	commonDir, repoRoot := fakeGitCommonDir(t)

	// Main checkout acquires.
	mainCfg := LeaseConfig{
		RepoRoot:     repoRoot,
		GitCommonDir: commonDir,
		SessionID:    "sess-main",
		LiveSessions: map[string]struct{}{"sess-main": {}, "sess-wt": {}},
	}
	if r, err := AcquireLease("go/shared.go", mainCfg); err != nil || r.Status != StatusAcquired {
		t.Fatalf("main acquire failed: status=%v err=%v", r.Status, err)
	}

	// Worktree checkout — same GitCommonDir, different physical RepoRoot.
	worktreePath := t.TempDir()
	worktreeCfg := LeaseConfig{
		RepoRoot:     worktreePath,
		GitCommonDir: commonDir,
		SessionID:    "sess-wt",
		LiveSessions: mainCfg.LiveSessions,
	}
	res, err := AcquireLease("go/shared.go", worktreeCfg)
	if err != nil {
		t.Fatalf("worktree acquire returned error: %v", err)
	}
	if res.Status != StatusHeldByOther {
		t.Errorf("worktree must observe the main checkout's lease (shared store); got %v",
			res.Status)
	}
	if res.Holder == nil || res.Holder.SessionID != "sess-main" {
		t.Errorf("holder should be sess-main, got %#v", res.Holder)
	}
}

// TestLeaseReclaim_ConcurrentSlowPath is the Phase 85.1.4 adversarial-review
// regression for the slow-path race the Workflow surfaced. Sixteen goroutines
// all see the SAME stale lock and all pass the isStale AND condition. The
// pre-fix reclaimLock used "tmp + rename" and would let two callers both
// succeed — the test pins the new "unlink + O_CREAT|O_EXCL" guarantee that
// exactly ONE wins the reclaim and N-1 receive StatusHeldByOther.
func TestLeaseReclaim_ConcurrentSlowPath(t *testing.T) {
	const N = 16
	commonDir, repoRoot := fakeGitCommonDir(t)
	store := filepath.Join(repoRoot, ".claude", "sessions", "leases")
	if err := os.MkdirAll(store, leaseDirMode); err != nil {
		t.Fatal(err)
	}
	path := "go/contested-reclaim.go"
	lockPath := filepath.Join(store, leaseKey(path)+".lock")

	// Seed the slow path: a stale lock from a session that is NOT in any
	// caller's LiveSessions set. Every goroutine will pass the AND
	// condition and attempt reclaim simultaneously.
	deadHolder := LeaseHolder{
		SessionID:        "sess-dead",
		HolderPID:        99999,
		AcquiredAt:       time.Now().Add(-2 * defaultLeaseTTL).Unix(),
		RepoRelativePath: path,
	}
	raw, _ := json.MarshalIndent(deadHolder, "", "  ")
	if err := os.WriteFile(lockPath, raw, lockFileMode); err != nil {
		t.Fatal(err)
	}

	var acquired int64
	var heldByOther int64
	var wg sync.WaitGroup
	start := make(chan struct{})
	for i := 0; i < N; i++ {
		wg.Add(1)
		go func(idx int) {
			defer wg.Done()
			cfg := LeaseConfig{
				RepoRoot:     repoRoot,
				GitCommonDir: commonDir,
				SessionID:    fmt.Sprintf("sess-recl-%d", idx),
				LiveSessions: map[string]struct{}{},
			}
			for j := 0; j < N; j++ {
				cfg.LiveSessions[fmt.Sprintf("sess-recl-%d", j)] = struct{}{}
			}
			// sess-dead intentionally absent — every caller sees the
			// AND condition (TTL expired AND holder not alive) as true.
			<-start
			res, err := AcquireLease(path, cfg)
			if err != nil {
				t.Errorf("goroutine %d: unexpected error: %v", idx, err)
				return
			}
			switch res.Status {
			case StatusAcquired:
				atomic.AddInt64(&acquired, 1)
			case StatusHeldByOther:
				atomic.AddInt64(&heldByOther, 1)
			}
		}(i)
	}
	close(start)
	wg.Wait()

	if got := atomic.LoadInt64(&acquired); got != 1 {
		t.Errorf("slow-path reclaim must yield exactly 1 Acquired, got %d (heldByOther=%d)",
			got, atomic.LoadInt64(&heldByOther))
	}
	if got := atomic.LoadInt64(&heldByOther); got != N-1 {
		t.Errorf("slow-path reclaim must yield N-1 HeldByOther, got %d", got)
	}
}

// TestLeaseStaleness_EmptyActiveJsonFallsBack pins the adversarial-review
// finding that an empty `{}` active.json must NOT collapse every session
// id into the "dead" half of the AND condition. The fixed
// LoadLiveSessionsFromActiveJSON returns nil for empty input, which makes
// isStale fall back to TTL-only — the safer half of the AND.
func TestLeaseStaleness_EmptyActiveJsonFallsBack(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("HARNESS_PROJECT_ROOT", dir)

	sessionsDir := filepath.Join(dir, ".claude", "sessions")
	if err := os.MkdirAll(sessionsDir, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(sessionsDir, "active.json"), []byte("{}"), 0o644); err != nil {
		t.Fatal(err)
	}

	live := LoadLiveSessionsFromActiveJSON(dir)
	if live != nil {
		t.Errorf("empty active.json must return nil to disable the liveness half of the AND, got %v", live)
	}
}

// TestLeaseLock_FileMode pins the Phase 85.1.4 Security floor: lock files
// and the leases directory must be owner-only (0o600 / 0o700) so peer unix
// users cannot enumerate who-edits-what on a shared host. A future refactor
// that re-introduces 0o644/0o755 will fail this test.
func TestLeaseLock_FileMode(t *testing.T) {
	cfg, repoRoot := newLeaseCfg(t, "sess-mode")
	if _, err := AcquireLease("api/perm.go", cfg); err != nil {
		t.Fatalf("acquire: %v", err)
	}
	store := filepath.Join(repoRoot, ".claude", "sessions", "leases")
	storeInfo, err := os.Stat(store)
	if err != nil {
		t.Fatalf("stat store: %v", err)
	}
	if mode := storeInfo.Mode().Perm(); mode != leaseDirMode {
		t.Errorf("leases/ dir mode = %o, want %o", mode, leaseDirMode)
	}
	entries, _ := os.ReadDir(store)
	if len(entries) != 1 {
		t.Fatalf("expected 1 lock entry, got %d", len(entries))
	}
	lockInfo, err := os.Stat(filepath.Join(store, entries[0].Name()))
	if err != nil {
		t.Fatalf("stat lock: %v", err)
	}
	if mode := lockInfo.Mode().Perm(); mode != lockFileMode {
		t.Errorf("lock file mode = %o, want %o", mode, lockFileMode)
	}
}

// TestLoadLiveSessionsFromActiveJSON is the integration glue: it confirms
// that the helper that bridges register and lease actually returns the
// session ids written by HandleSessionRegister, so a future change to the
// active.json schema cannot silently break the AND condition's liveness
// half.
func TestLoadLiveSessionsFromActiveJSON(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("HARNESS_PROJECT_ROOT", dir)

	if err := HandleSessionRegister(strings.NewReader(`{"session_id":"alive-1"}`), nil); err != nil {
		t.Fatal(err)
	}
	if err := HandleSessionRegister(strings.NewReader(`{"session_id":"alive-2"}`), nil); err != nil {
		t.Fatal(err)
	}

	set := LoadLiveSessionsFromActiveJSON(dir)
	if _, ok := set["alive-1"]; !ok {
		t.Errorf("alive-1 should be in the live set; got %v", set)
	}
	if _, ok := set["alive-2"]; !ok {
		t.Errorf("alive-2 should be in the live set; got %v", set)
	}
}

