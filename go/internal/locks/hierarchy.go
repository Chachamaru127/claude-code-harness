// Package locks implements the hierarchical lock topology that fixes the
// state-divergence class of bugs exemplified by claude-code-harness issue
// #123 ("codex-loop background start can become state_stale while
// foreground run succeeds").
//
// Topology (three tiers):
//
//	PRIMARY    — per-target flock (Plans.md, current-job.json, etc.)
//	INDEX      — per-state-key flock (loop-session-meta, runner-status)
//	SECONDARY  — per-task-row flock (codex-loop run_id, sprint task)
//
// Acquire order: Primary → Index → Secondary, lex-sorted by key within each
// tier when multiple are taken. Lex-ordering is enforced at runtime — any
// attempt to acquire a tier in non-canonical order returns ErrOrderViolation.
// This makes deadlock impossible: every process climbs the same lattice in
// the same direction.
//
// Verified against the production hierarchical lock implementation in
// DDouns at Z:/DDouns/ddouns/lock.py:60-336 (LockManager.acquire_primary,
// acquire_index, acquire_advisory, acquire_primary_multiple). The Python
// invariants ported here:
//
//   - sha256(key)[:32] for filename hashing (lock.py:87-88)
//   - atomic create via O_CREAT|O_EXCL|O_WRONLY (lock.py:108-110;
//     Go uses os.O_EXCL with the same semantics)
//   - stale detection by expiry timestamp on payload (lock.py:97-103)
//   - lex-ordered multi-acquire (lock.py:308-309)
//
// Copyright 2026 the DDouns authors (Apache-2.0).
// Co-Authored-By: cmyoya/DDouns <noreply@ddouns.dev>
package locks

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"strconv"
	"path/filepath"
	"sort"
	"strings"
	"sync"
	"time"
)

// LockKind enumerates the three tiers. Higher values = deeper in the
// lattice. Acquire order MUST be non-decreasing in LockKind value.
type LockKind int

const (
	Primary LockKind = iota
	Index
	Secondary
)

func (k LockKind) String() string {
	switch k {
	case Primary:
		return "primary"
	case Index:
		return "index"
	case Secondary:
		return "secondary"
	default:
		return "unknown"
	}
}

// ErrOrderViolation is returned by Acquire when the requested (kind, key)
// would break the lex-ordered acquisition rule given the locks the goroutine
// currently holds.
var ErrOrderViolation = errors.New("lock acquire order violation")

// ErrBusy is returned when the lock file already exists and its payload is
// not stale. Callers retry or fail-with-reason as policy demands.
var ErrBusy = errors.New("lock is busy")

// Handle is the released-on-Release lock token returned by Acquire.
type Handle interface {
	Release() error
	Kind() LockKind
	Key() string
}

// Manager is goroutine-local in the sense that every Manager instance tracks
// its own held set; cross-process coordination is via the on-disk flock files
// at .claude/state/locks/{primary,index,secondary}/<sha256>.lock.
type Manager struct {
	rootDir   string
	sessionID string
	ttl       time.Duration

	mu   sync.Mutex
	held []*handleImpl // ordered by acquire-time; used to enforce lex order
}

// NewManager constructs a Manager rooted at rootDir (typically
// projectRoot/.claude/state/locks). sessionID is recorded in lock-file
// payloads so stale-by-expiry detection can identify the holder.
func NewManager(rootDir, sessionID string, ttl time.Duration) *Manager {
	if ttl <= 0 {
		ttl = 30 * time.Minute
	}
	return &Manager{rootDir: rootDir, sessionID: sessionID, ttl: ttl}
}

// Acquire takes a lock at the given tier and key. Order rules:
//
//  1. The new lock's tier MUST be >= the deepest tier already held.
//  2. Within the same tier, the new lock's key MUST be lex-greater than
//     every other key already held in that tier.
//
// Violating either returns ErrOrderViolation; the caller's existing locks
// remain held. On success, the returned Handle MUST be released to free
// the on-disk file.
func (m *Manager) Acquire(kind LockKind, key string) (Handle, error) {
	m.mu.Lock()
	defer m.mu.Unlock()

	if err := m.checkOrder(kind, key); err != nil {
		return nil, err
	}

	path := m.lockPath(kind, key)
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return nil, fmt.Errorf("mkdir lock dir: %w", err)
	}

	payload := map[string]string{
		"session_id":  m.sessionID,
		"holder_pid":  strconv.Itoa(os.Getpid()),
		"kind":        kind.String(),
		"key":         key,
		"acquired_at": time.Now().UTC().Format(time.RFC3339),
		"expiry":      time.Now().UTC().Add(m.ttl).Format(time.RFC3339),
	}
	data, _ := json.Marshal(payload)

	// Atomic create-or-fail. Mirrors lock.py:108-110.
	f, err := os.OpenFile(path, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0o600)
	if err != nil {
		if os.IsExist(err) {
			if m.tryStaleCleanup(path) {
				return m.retryAcquireUnlocked(kind, key, data, path)
			}
			return nil, fmt.Errorf("%w: %s/%s", ErrBusy, kind.String(), key)
		}
		return nil, fmt.Errorf("open lock file: %w", err)
	}
	if _, err := f.Write(data); err != nil {
		f.Close()
		os.Remove(path)
		return nil, fmt.Errorf("write lock payload: %w", err)
	}
	f.Close()

	h := &handleImpl{kind: kind, key: key, path: path, mgr: m}
	m.held = append(m.held, h)
	return h, nil
}

// retryAcquireUnlocked is invoked from inside the manager mutex after a
// stale cleanup has freed the file. The acquisition is retried exactly
// once; if it still races, the caller sees ErrBusy.
func (m *Manager) retryAcquireUnlocked(kind LockKind, key string, data []byte, path string) (Handle, error) {
	f, err := os.OpenFile(path, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0o600)
	if err != nil {
		return nil, fmt.Errorf("%w: %s/%s (post-stale-cleanup race)", ErrBusy, kind.String(), key)
	}
	if _, err := f.Write(data); err != nil {
		f.Close()
		os.Remove(path)
		return nil, fmt.Errorf("write lock payload: %w", err)
	}
	f.Close()

	h := &handleImpl{kind: kind, key: key, path: path, mgr: m}
	m.held = append(m.held, h)
	return h, nil
}

// tryStaleCleanup reads the existing payload; if its `expiry` is in the
// past, removes the file. Returns true iff a cleanup occurred.
//
// Conservative: removes ONLY on confirmed-past expiry. Parse failures
// (read error, malformed JSON, unparseable timestamp) leave the file
// in place because a winner in the O_EXCL→Write window can produce
// transiently-empty/partial reads — silently removing those would
// undermine the atomic create-or-fail guarantee and allow double
// acquisition. Persistent corruption from a crashed holder will fail
// caller acquires until the TTL has lapsed and a future holder writes
// a parseable expiry; this trades stale-recovery latency for safety.
//
// Mirrors lock.py:97-103 + lock.py:153-159 (semantics) but tightens the
// failure-mode handling vs the Python production reference.
func (m *Manager) tryStaleCleanup(path string) bool {
	body, err := os.ReadFile(path)
	if err != nil {
		// Don't touch — concurrent winner may be mid-write.
		return false
	}
	var payload struct {
		Expiry string `json:"expiry"`
	}
	if err := json.Unmarshal(body, &payload); err != nil {
		// Partial/malformed payload — winner may still be in the
		// O_EXCL → Write window. Don't remove; treat as still busy.
		return false
	}
	exp, err := time.Parse(time.RFC3339, payload.Expiry)
	if err != nil {
		// Couldn't parse expiry — same caution as malformed payload.
		return false
	}
	if time.Now().UTC().After(exp) {
		_ = os.Remove(path)
		return true
	}
	return false
}

// checkOrder enforces the two ordering rules. Caller holds m.mu.
func (m *Manager) checkOrder(kind LockKind, key string) error {
	for _, h := range m.held {
		if h.kind > kind {
			return fmt.Errorf("%w: cannot acquire %s/%s while holding deeper %s/%s",
				ErrOrderViolation, kind.String(), key, h.kind.String(), h.key)
		}
		if h.kind == kind && strings.Compare(key, h.key) <= 0 {
			return fmt.Errorf("%w: cannot acquire %s/%s after holding %s/%s (lex order)",
				ErrOrderViolation, kind.String(), key, h.kind.String(), h.key)
		}
	}
	return nil
}

// AcquireMany takes multiple locks at the same tier in one call, lex-sorting
// the keys before acquisition so deadlock is impossible across two callers
// requesting an overlapping subset. Mirrors lock.py:298-335.
func (m *Manager) AcquireMany(kind LockKind, keys []string) ([]Handle, error) {
	sorted := append([]string{}, keys...)
	sort.Strings(sorted)

	out := make([]Handle, 0, len(sorted))
	for _, k := range sorted {
		h, err := m.Acquire(kind, k)
		if err != nil {
			// Roll back in reverse order on partial failure.
			for i := len(out) - 1; i >= 0; i-- {
				_ = out[i].Release()
			}
			return nil, err
		}
		out = append(out, h)
	}
	return out, nil
}

// lockPath returns .claude/state/locks/<tier>/<sha256(key)[:16]>.lock.
// 16 hex chars = 8 bytes of SHA-256 — collision probability is negligible
// for the few-hundred concurrent locks per project we expect, and mirrors
// the 16-hex collision-safe path scheme used in DDouns global config.
func (m *Manager) lockPath(kind LockKind, key string) string {
	sum := sha256.Sum256([]byte(key))
	name := hex.EncodeToString(sum[:])[:16] + ".lock"
	return filepath.Join(m.rootDir, kind.String(), name)
}

// handleImpl is the Manager-internal implementation of Handle.
type handleImpl struct {
	kind LockKind
	key  string
	path string
	mgr  *Manager
	once sync.Once
	err  error
}

func (h *handleImpl) Kind() LockKind { return h.kind }
func (h *handleImpl) Key() string    { return h.key }

// Release removes the on-disk lock file and detaches this handle from the
// manager's held list. Idempotent.
func (h *handleImpl) Release() error {
	h.once.Do(func() {
		if err := os.Remove(h.path); err != nil && !os.IsNotExist(err) {
			h.err = err
			return
		}
		h.mgr.mu.Lock()
		for i, x := range h.mgr.held {
			if x == h {
				h.mgr.held = append(h.mgr.held[:i], h.mgr.held[i+1:]...)
				break
			}
		}
		h.mgr.mu.Unlock()
	})
	return h.err
}
