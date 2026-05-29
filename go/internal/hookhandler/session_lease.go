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
// staleness logic considers reclaim. A 30-minute default is long enough to
// cover the heaviest Worker edit cycle while short enough that a crashed
// session never blocks a sibling forever (combined with the session-id
// liveness check, the practical worst case is 30 min after the session id
// drops out of active.json).
const defaultLeaseTTL = 30 * time.Minute

// LeaseHolder is the JSON shape persisted in <key>.lock. We persist the
// repo-relative path even though it's hashed in the filename so a human
// reading the lock store can identify which file is held.
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

	if err := os.MkdirAll(storeDir, 0o755); err != nil {
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
		// Corrupted lock — reclaim is the recovery per
		// active-watching-test-policy.md. One attempt only.
		if err := reclaimLock(lockPath, holder); err == nil {
			return LeaseResult{Status: StatusAcquired}, nil
		}
		return LeaseResult{Status: StatusUnavailable, Reason: "corrupted"}, nil
	}

	if existing.SessionID == cfg.SessionID {
		// Re-entrant acquire — refresh the timestamp and treat as success.
		if err := reclaimLock(lockPath, holder); err == nil {
			return LeaseResult{Status: StatusAcquired}, nil
		}
		return LeaseResult{Status: StatusUnavailable, Reason: "refresh-failed"}, nil
	}

	if isStale(existing, cfg, now) {
		if err := reclaimLock(lockPath, holder); err == nil {
			return LeaseResult{Status: StatusAcquired}, nil
		}
		// Reclaim raced with another acquirer — treat as held by other.
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

// writeLockAtomic creates the lock file with O_CREAT|O_EXCL so two
// concurrent acquirers cannot both succeed. The fsync via Sync ensures the
// lock contents are durable before the function returns — without this a
// crash between Write and Close could leave a zero-byte lock that the next
// caller sees as "corrupted" rather than "absent".
func writeLockAtomic(path string, holder LeaseHolder) error {
	data, err := json.MarshalIndent(holder, "", "  ")
	if err != nil {
		return err
	}
	data = append(data, '\n')
	f, err := os.OpenFile(path, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0o644)
	if err != nil {
		return err
	}
	defer f.Close()
	if _, err := f.Write(data); err != nil {
		_ = os.Remove(path)
		return err
	}
	if err := f.Sync(); err != nil {
		// Best-effort durability; the rest of the contract still holds.
		_ = err
	}
	return nil
}

// reclaimLock is the recovery path for stale or corrupted leases: write to a
// temp file under the same directory and rename over the existing lock. The
// rename is the atomicity guarantee — a sibling that opens the lock at any
// moment sees either the old contents or the new, never a partial mix.
func reclaimLock(path string, holder LeaseHolder) error {
	data, err := json.MarshalIndent(holder, "", "  ")
	if err != nil {
		return err
	}
	data = append(data, '\n')
	tmp := path + ".tmp." + fmt.Sprintf("%d", time.Now().UnixNano())
	if err := os.WriteFile(tmp, data, 0o644); err != nil {
		return err
	}
	return os.Rename(tmp, path)
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
// the staleness check can apply the liveness half of the AND. Missing,
// unreadable, or unparseable active.json files return an empty set — that
// downgrades the contract to TTL-only, which is the documented "no liveness
// signal" fallback.
func LoadLiveSessionsFromActiveJSON(repoRoot string) map[string]struct{} {
	if repoRoot == "" {
		repoRoot = resolveProjectRoot()
	}
	path := filepath.Join(repoRoot, ".claude", "sessions", "active.json")
	sessions := readActiveJSON(path)
	set := make(map[string]struct{}, len(sessions))
	for id := range sessions {
		set[id] = struct{}{}
	}
	return set
}
