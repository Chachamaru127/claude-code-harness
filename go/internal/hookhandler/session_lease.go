package hookhandler

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

// defaultLeaseTTL is the maximum age a lease entry may have before the
// staleness logic considers reclaim. 60 minutes is the floor where a heavy
// breezing Worker edit-test cycle on large files still completes inside the
// window. Reclaim still requires the AND with the liveness check, so a
// genuinely live session 60 min into an edit will not be evicted — the
// staleness window only fires when active.json also confirms the holder is
// gone.
const defaultLeaseTTL = 60 * time.Minute

// lockFileMode is the unix mode bits of a per-file lock. 0o600 keeps the
// lock contents (which include the holder PID and the repo-relative path of
// the file being edited) readable only by the owning user. The Phase 85
// Security review surfaced that 0o644 would leak who-edits-what to other
// users on a shared host, so 0o600 is the security floor.
const lockFileMode os.FileMode = 0o600

// leaseDirMode is the unix mode bits of the leases/ directory itself. 0o700
// matches the lock-file mode so a peer user cannot enumerate the directory
// even if they cannot read individual locks.
const leaseDirMode os.FileMode = 0o700

// LeaseHolder is the JSON shape persisted in <key>.lock. We persist the
// repo-relative path even though it's hashed in the filename so a human
// reading the lock store can identify which file is held. HolderPID is
// recorded for debugging only (admin can `cat <lock>` to see which
// process held it); the acquire logic intentionally does NOT compare PIDs
// because re-entrant acquires by the same SessionID — including
// crash-restart cases where the new process has a different PID — are
// treated as legitimate refresh. The session id is the single identity
// authority.
type LeaseHolder struct {
	SessionID        string `json:"session_id"`
	HolderPID        int    `json:"holder_pid"`
	AcquiredAt       int64  `json:"acquired_at"`
	RepoRelativePath string `json:"repo_relative_path"`
}

// LeaseStatus describes the tri-state result of an acquire attempt:
//
//   - StatusAcquired: lease is now held by the calling session.
//   - StatusHeldByOther: another session holds a live lease; Holder is set.
//   - StatusUnavailable: the lease layer cannot be reached (no git common
//     dir, unwritable lease store, etc.). Per the Session Coordination
//     Contract this is fail-open: callers must allow the edit to proceed
//     without surfacing a warning.
type LeaseStatus int

const (
	StatusAcquired LeaseStatus = iota
	StatusHeldByOther
	StatusUnavailable
)

// LeaseResult is the structured result of AcquireLease.
type LeaseResult struct {
	Status LeaseStatus
	Reason string       // populated for StatusUnavailable to aid Monitor health output
	Holder *LeaseHolder // populated for StatusHeldByOther
}

// LeaseConfig holds the parameters AcquireLease and CheckLease consume. The
// struct exists so tests can inject a fake clock, override the TTL, and
// pre-seed the live-session set without reaching into globals.
type LeaseConfig struct {
	// RepoRoot is the project root used to derive the repo-relative path.
	// Empty means use resolveProjectRoot().
	RepoRoot string
	// GitCommonDir overrides the resolution of `git --git-common-dir`. Tests
	// set this to a TempDir to avoid touching the real .git.
	GitCommonDir string
	// SessionID identifies the caller; the corresponding entry must be
	// present in LiveSessions for the staleness check to treat the holder
	// as alive.
	SessionID string
	// LiveSessions is the set of currently-alive session ids (typically
	// derived from active.json). nil means "do not perform the liveness
	// half of the AND condition", which forces staleness to rely on TTL
	// alone — used by callers that have no active.json yet.
	LiveSessions map[string]struct{}
	// TTL is the maximum lease age before reclaim becomes possible. Zero
	// means defaultLeaseTTL.
	TTL time.Duration
	// Now is the clock injection point for tests. Zero means time.Now().
	Now func() time.Time
}

// AcquireLease attempts to claim the lease for repoRelativePath. Returns
// StatusAcquired when the lock file was successfully created, StatusHeldByOther
// when a live lease blocks it (Holder populated), or StatusUnavailable when
// the lease layer cannot be reached (Reason populated). Errors are reserved
// for programmer mistakes (invalid input); environmental issues collapse to
// StatusUnavailable so the hook chain stays fail-open.
func AcquireLease(repoRelativePath string, cfg LeaseConfig) (LeaseResult, error) {
	if cfg.SessionID == "" {
		return LeaseResult{}, errors.New("AcquireLease: SessionID is required")
	}
	if strings.TrimSpace(repoRelativePath) == "" {
		return LeaseResult{}, errors.New("AcquireLease: repoRelativePath is required")
	}

	storeDir, reason := leaseStore(cfg)
	if storeDir == "" {
		return LeaseResult{Status: StatusUnavailable, Reason: reason}, nil
	}

	if err := os.MkdirAll(storeDir, leaseDirMode); err != nil {
		return LeaseResult{Status: StatusUnavailable, Reason: "mkdir-failed"}, nil
	}

	key := leaseKey(repoRelativePath)
	lockPath := filepath.Join(storeDir, key+".lock")

	now := nowFunc(cfg.Now)()
	holder := LeaseHolder{
		SessionID:        cfg.SessionID,
		HolderPID:        os.Getpid(),
		AcquiredAt:       now.Unix(),
		RepoRelativePath: repoRelativePath,
	}

	// Atomic acquire path: O_CREAT|O_EXCL ensures we create or fail.
	if err := writeLockAtomic(lockPath, holder); err == nil {
		return LeaseResult{Status: StatusAcquired}, nil
	} else if !errors.Is(err, os.ErrExist) {
		return LeaseResult{Status: StatusUnavailable, Reason: "write-failed"}, nil
	}

	// Slow path: lock already exists. Read it, decide stale-or-live.
	existing, readErr := readLock(lockPath)
	if readErr != nil {
		// Corrupted (or transiently absent during a peer's rename window)
		// lock — reclaim is the recovery per active-watching-test-policy.
		// Run inside the reclaim mutex so two corruption-recoverers
		// cannot both win, and re-check the lock state inside the mutex
		// because a peer may have completed a valid write in the window
		// between our outer readLock and our mutex acquire.
		var acquired bool
		var peerLock LeaseHolder
		_ = withReclaimMutex(storeDir, func() error {
			if current, err := readLock(lockPath); err == nil {
				// Peer wrote a valid lock — we were not racing
				// corruption, just timing. Surface peer's identity so
				// the caller can return HeldByOther instead of the
				// less-specific Unavailable.
				peerLock = current
				return os.ErrExist
			}
			if err := reclaimLock(lockPath, holder); err != nil {
				return err
			}
			acquired = true
			return nil
		})
		if acquired {
			return LeaseResult{Status: StatusAcquired}, nil
		}
		if peerLock.SessionID != "" {
			return LeaseResult{Status: StatusHeldByOther, Holder: &peerLock}, nil
		}
		return LeaseResult{Status: StatusUnavailable, Reason: "corrupted"}, nil
	}

	if existing.SessionID == cfg.SessionID {
		// Re-entrant acquire — refresh the timestamp and treat as success.
		// The mutex is held briefly only here because the re-entrant path
		// is also subject to peer-reclaim races: a peer could observe our
		// own old lock as stale while we refresh.
		var acquired bool
		mutexErr := withReclaimMutex(storeDir, func() error {
			// Re-verify still our lock inside the mutex.
			current, err := readLock(lockPath)
			if err != nil {
				return err
			}
			if current.SessionID != cfg.SessionID {
				existing = current
				return os.ErrExist
			}
			if err := reclaimLock(lockPath, holder); err != nil {
				return err
			}
			acquired = true
			return nil
		})
		if acquired {
			return LeaseResult{Status: StatusAcquired}, nil
		}
		if errors.Is(mutexErr, os.ErrExist) {
			return LeaseResult{Status: StatusHeldByOther, Holder: &existing}, nil
		}
		return LeaseResult{Status: StatusUnavailable, Reason: "refresh-failed"}, nil
	}

	if isStale(existing, cfg, now) {
		// Slow path: enter the per-store reclaim mutex, re-validate
		// inside (a peer may have already reclaimed), and swap.
		var acquired bool
		mutexErr := withReclaimMutex(storeDir, func() error {
			current, err := readLock(lockPath)
			if err != nil {
				// Lock vanished — fall through to a fresh create.
				if err := writeLockAtomic(lockPath, holder); err != nil {
					return err
				}
				acquired = true
				return nil
			}
			// Has another reclaimer already replaced it with a fresh
			// lock? If so, surface as HeldByOther.
			if !isStale(current, cfg, nowFunc(cfg.Now)()) {
				existing = current
				return os.ErrExist
			}
			if err := reclaimLock(lockPath, holder); err != nil {
				return err
			}
			acquired = true
			return nil
		})
		if acquired {
			return LeaseResult{Status: StatusAcquired}, nil
		}
		_ = mutexErr
		return LeaseResult{Status: StatusHeldByOther, Holder: &existing}, nil
	}

	return LeaseResult{Status: StatusHeldByOther, Holder: &existing}, nil
}

// ReleaseLease releases the lease only when the caller is the recorded
// holder. A mismatched session id leaves the lock in place to prevent a
// confused session from clobbering a sibling's hold. Returns nil on
// successful release, on no-op (lock absent or held by other), and when the
// lease layer is unavailable; only programmer errors propagate.
func ReleaseLease(repoRelativePath string, cfg LeaseConfig) error {
	if cfg.SessionID == "" {
		return errors.New("ReleaseLease: SessionID is required")
	}
	storeDir, _ := leaseStore(cfg)
	if storeDir == "" {
		return nil
	}
	lockPath := filepath.Join(storeDir, leaseKey(repoRelativePath)+".lock")

	existing, err := readLock(lockPath)
	if err != nil {
		// Lock missing or corrupted — nothing safe to remove.
		return nil
	}
	if existing.SessionID != cfg.SessionID {
		// A peer holds the lock — never delete another session's lease.
		return nil
	}
	return os.Remove(lockPath)
}

// CheckLease is the read-only inspection used by PostToolUse to decide
// whether a peer holds a live lease before deciding to surface the conflict
// feedback. The tri-state contract applies: StatusUnavailable is silent,
// StatusHeldByOther populates Holder, StatusAcquired means the lock file is
// absent (so the path is free).
func CheckLease(repoRelativePath string, cfg LeaseConfig) LeaseResult {
	storeDir, reason := leaseStore(cfg)
	if storeDir == "" {
		return LeaseResult{Status: StatusUnavailable, Reason: reason}
	}
	lockPath := filepath.Join(storeDir, leaseKey(repoRelativePath)+".lock")
	existing, err := readLock(lockPath)
	if err != nil {
		if errors.Is(err, os.ErrNotExist) {
			return LeaseResult{Status: StatusAcquired}
		}
		return LeaseResult{Status: StatusUnavailable, Reason: "corrupted"}
	}
	if isStale(existing, cfg, nowFunc(cfg.Now)()) {
		// Stale leases are reported as free; the next AcquireLease cleans
		// them up. This avoids surfacing a misleading "held by X" warning
		// in the conflict feedback for a dead session.
		return LeaseResult{Status: StatusAcquired}
	}
	if existing.SessionID == cfg.SessionID {
		// Our own lease — treat as acquired for the caller's purposes.
		return LeaseResult{Status: StatusAcquired}
	}
	return LeaseResult{Status: StatusHeldByOther, Holder: &existing}
}

// --- helpers ---

// leaseKey returns the sha256 hex of the input. Using a hash deliberately
// makes the on-disk filename non-reversible, which closes the path-traversal
// attack surface entirely (a hostile path token can never produce a key
// outside the leases directory because the key is always 64 hex chars).
func leaseKey(repoRelativePath string) string {
	sum := sha256.Sum256([]byte(repoRelativePath))
	return hex.EncodeToString(sum[:])
}

// leaseStore resolves the directory all leases live under. It is rooted at
// git --git-common-dir's parent so every worktree of the same repo sees the
// same store, which is the only way file-level coordination between
// breezing's parallel worktree Workers can ever succeed. Returns ("",
// reason) when the resolution fails; the caller maps that to
// StatusUnavailable.
func leaseStore(cfg LeaseConfig) (string, string) {
	commonDir := cfg.GitCommonDir
	if commonDir == "" {
		root := cfg.RepoRoot
		if root == "" {
			root = resolveProjectRoot()
		}
		cmd := exec.Command("git", "rev-parse", "--git-common-dir")
		cmd.Dir = root
		out, err := cmd.Output()
		if err != nil {
			return "", "not-configured"
		}
		commonDir = strings.TrimSpace(string(out))
		if commonDir == "" {
			return "", "not-configured"
		}
		// `git rev-parse --git-common-dir` returns a path relative to cwd
		// when the cwd is the repo root. Make it absolute so the store
		// path is stable across worktrees that resolve to the same
		// physical .git directory.
		if !filepath.IsAbs(commonDir) {
			commonDir = filepath.Join(root, commonDir)
		}
	}
	// Use the .git directory's parent so we land at the repo root, then
	// reuse the .claude/sessions/ subtree the rest of the coordination
	// state already lives under.
	repoRoot := filepath.Dir(commonDir)
	return filepath.Join(repoRoot, ".claude", "sessions", "leases"), ""
}

// writeLockAtomic creates the lock file so that the visible target path is
// ONLY observable with complete, valid JSON contents. We use POSIX link(2)
// for the atomicity: write the full holder data into a uniquely-named tmp
// file in the same directory, then os.Link the tmp onto the target. link(2)
// returns EEXIST atomically if the target already exists, which is the
// same "create-only" semantic that O_CREAT|O_EXCL provided — but unlike the
// O_CREAT|O_EXCL+Write sequence, link(2) only makes the path visible AFTER
// the data is on disk. A peer reading the path mid-create never sees an
// empty or partial lock.
//
// The Phase 85 adversarial review's reclaim race fix exposed why this
// matters: under O_CREAT|O_EXCL+Write, a peer that observed EEXIST and
// then read an empty file (because the writer had not Write()d yet) would
// see "corrupted" and trigger the reclaim recovery path, which under
// reclaim's Rename-based atomicity would move the half-finished lock to a
// dead-suffix and let the peer win — resulting in two callers both
// returning StatusAcquired. Switching the create to link(2) closes that
// window entirely because the visible path is never half-written.
func writeLockAtomic(path string, holder LeaseHolder) error {
	data, err := json.MarshalIndent(holder, "", "  ")
	if err != nil {
		return err
	}
	data = append(data, '\n')

	dir := filepath.Dir(path)
	tmp, err := os.CreateTemp(dir, filepath.Base(path)+".tmp-*")
	if err != nil {
		return err
	}
	tmpPath := tmp.Name()
	// Best-effort cleanup of the tmp file regardless of which path we take
	// out. If Link succeeded the tmp link count drops to 1 and Remove just
	// unlinks our local handle, not the visible path.
	defer os.Remove(tmpPath)

	if _, err := tmp.Write(data); err != nil {
		tmp.Close()
		return err
	}
	if err := tmp.Sync(); err != nil {
		// Best-effort durability; the rest of the contract still holds.
		_ = err
	}
	if err := tmp.Close(); err != nil {
		return err
	}
	// CreateTemp gives the file a 0o600 mode on most platforms, but be
	// explicit to defend against umask quirks. The owner-only mode is the
	// Phase 85 Security floor (lockFileMode).
	if err := os.Chmod(tmpPath, lockFileMode); err != nil {
		return err
	}

	// POSIX link(2) atomic create: if `path` already exists, returns
	// EEXIST without modifying anything. If it does not exist, the link
	// is created with the tmp's inode (complete data).
	if err := os.Link(tmpPath, path); err != nil {
		if os.IsExist(err) {
			return os.ErrExist
		}
		return err
	}
	return nil
}

// reclaimMutexRetryDelay is the wait between mkdir-mutex acquire attempts in
// the slow path. Microsecond granularity keeps the worst-case wait short
// (~100ms even at 1000 retries) while avoiding a busy spin that would burn
// CPU on contended hosts.
const reclaimMutexRetryDelay = 100 * time.Microsecond
const reclaimMutexMaxRetries = 1000

// withReclaimMutex serializes the slow path of AcquireLease on a per-
// lease-store basis. The mutex is a directory created via os.Mkdir's POSIX
// atomic primitive (mkdir(2) is the canonical CAS in POSIX filesystems);
// fast-path acquires never enter this mutex, so the perf cost is paid only
// on the rare reclaim path.
//
// Why a coarse mutex instead of a smarter per-path lock: the slow path's
// hazard is a TOCTOU between "read existing", "decide it's stale", and
// "rename away". Two concurrent reclaimers cannot agree on which inode is
// "the stale one" because POSIX rename(2) takes whatever is currently at
// the path. The mutex closes this by serializing the entire decide+swap
// sequence, so a second reclaimer always re-reads inside the mutex and
// observes the fresh lock the first reclaimer just wrote. No coarse mutex
// would be needed if POSIX had renameat2(RENAME_EXCHANGE), but that is
// Linux-only, and the Phase 85 contract is cross-platform.
func withReclaimMutex(storeDir string, fn func() error) error {
	mutexPath := filepath.Join(storeDir, ".reclaim.mu")
	for i := 0; i < reclaimMutexMaxRetries; i++ {
		err := os.Mkdir(mutexPath, leaseDirMode)
		if err == nil {
			defer os.Remove(mutexPath)
			return fn()
		}
		if !os.IsExist(err) {
			return err
		}
		time.Sleep(reclaimMutexRetryDelay)
	}
	return errors.New("withReclaimMutex: could not acquire reclaim mutex")
}

// reclaimLock is the recovery path for stale or corrupted leases. It MUST
// be called while holding the per-store reclaim mutex (withReclaimMutex).
// Without the mutex, two concurrent reclaimers can both pass an earlier
// isStale check, each invoke Rename(path, dead.<X>) on whatever happens to
// be at the path at the moment, and end up both succeeding — the second
// silently renames the first reclaimer's freshly-acquired lock away and
// creates its own. The Phase 85 adversarial review surfaced this exact
// scenario, and TestLeaseReclaim_ConcurrentSlowPath proves it.
//
// Inside the mutex, the sequence is:
//   1. Rename the existing lock to a unique dead-suffix path. With the
//      mutex held, this rename only ever runs while no other reclaimer is
//      operating on the same store.
//   2. Create the new lock via writeLockAtomic (POSIX link(2) atomic).
//   3. Best-effort cleanup of the dead-named file.
//
// Callers MUST re-validate staleness inside the mutex if they want to
// avoid acting on stale knowledge — see AcquireLease's slow path.
func reclaimLock(path string, holder LeaseHolder) error {
	deadPath := fmt.Sprintf("%s.dead.%d.%s", path, time.Now().UnixNano(), holder.SessionID)
	if err := os.Rename(path, deadPath); err != nil {
		return err
	}
	if err := writeLockAtomic(path, holder); err != nil {
		return err
	}
	_ = os.Remove(deadPath)
	return nil
}

// readLock returns the lease holder recorded at path, or an error wrapping
// os.ErrNotExist when the file is absent. Corrupted (unparseable) locks
// surface as a non-nil error that is NOT os.ErrNotExist, which lets the
// caller distinguish "no lock" from "broken lock" and apply the recovery
// path of active-watching-test-policy.md.
func readLock(path string) (LeaseHolder, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return LeaseHolder{}, err
	}
	var h LeaseHolder
	if err := json.Unmarshal(data, &h); err != nil {
		return LeaseHolder{}, fmt.Errorf("readLock: corrupted lock at %s: %w", path, err)
	}
	if h.SessionID == "" {
		return LeaseHolder{}, fmt.Errorf("readLock: missing session_id at %s", path)
	}
	return h, nil
}

// isStale evaluates the AND condition that defines a reclaimable lease:
// the TTL has expired AND the holder session id is absent from the live
// session set. Either half on its own is intentionally insufficient — TTL
// alone would reclaim a long-running edit session, and liveness alone would
// allow a freshly-crashed session to be evicted before the user has a
// chance to notice. Combining the two narrows reclaim to the genuine
// dead-session case.
func isStale(h LeaseHolder, cfg LeaseConfig, now time.Time) bool {
	ttl := cfg.TTL
	if ttl <= 0 {
		ttl = defaultLeaseTTL
	}
	age := now.Sub(time.Unix(h.AcquiredAt, 0))
	if age < ttl {
		return false
	}
	if cfg.LiveSessions == nil {
		// No liveness signal available — fall back to TTL-only. This is
		// the safer half of the AND for callers that cannot read
		// active.json yet (early bootstrap).
		return true
	}
	_, alive := cfg.LiveSessions[h.SessionID]
	return !alive
}

// nowFunc collapses the optional clock injection into a uniform call site.
func nowFunc(injected func() time.Time) func() time.Time {
	if injected != nil {
		return injected
	}
	return time.Now
}

// LoadLiveSessionsFromActiveJSON reads active.json and returns a set of
// currently-registered session ids. Callers wire this into LeaseConfig so
// the staleness check can apply the liveness half of the AND.
//
// Missing, unreadable, unparseable, OR EMPTY active.json files return nil.
// The Phase 85 adversarial review surfaced a subtle hole: returning an
// empty non-nil map would make every session id appear "dead" in the AND
// condition, which combined with TTL expiry would silently reclaim a
// healthy peer's lock whenever active.json was momentarily empty (e.g.
// during register-write atomicity, after corruption, or before the first
// SessionStart of the day). Returning nil makes isStale fall back to its
// documented TTL-only semantics, which never reclaims faster than the TTL
// window. The nil sentinel is the safer half of the AND.
func LoadLiveSessionsFromActiveJSON(repoRoot string) map[string]struct{} {
	if repoRoot == "" {
		repoRoot = resolveProjectRoot()
	}
	path := filepath.Join(repoRoot, ".claude", "sessions", "active.json")
	sessions := readActiveJSON(path)
	if len(sessions) == 0 {
		return nil
	}
	set := make(map[string]struct{}, len(sessions))
	for id := range sessions {
		set[id] = struct{}{}
	}
	return set
}
