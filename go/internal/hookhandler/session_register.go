package hookhandler

import (
	"encoding/json"
	"io"
	"os"
	"path/filepath"
	"strconv"
	"time"
)

// registerStaleCutoff matches scripts/session-register.sh: entries older than
// 24h are pruned from active.json so the file does not grow unbounded as
// sessions come and go.
const registerStaleCutoff = 24 * time.Hour

// ActiveSession mirrors the on-disk schema of .claude/sessions/active.json
// that scripts/session-register.sh has been writing since the bash era.
// The shape is preserved verbatim so peers, manual `cat active.json`
// inspection, and the bash version of register can coexist.
type ActiveSession struct {
	ShortID  string `json:"short_id"`
	LastSeen int64  `json:"last_seen"`
	PID      string `json:"pid"`
	Status   string `json:"status"`
}

// registerInput is the stdin JSON payload shared by SessionStart and Stop
// hooks; only session_id is required for register/unregister logic.
type registerInput struct {
	SessionID string `json:"session_id"`
	CWD       string `json:"cwd"`
}

// HandleSessionRegister adds the current session to active.json on
// SessionStart. The file format mirrors scripts/session-register.sh so peer
// readers (bash, future Go consumers) interpret it identically. Stale
// entries (last_seen older than 24h) are pruned during the same write so
// the file stays bounded.
//
// The handler is fail-open per the Phase 81 / Session Coordination
// Contract: missing session_id, an unwritable sessions directory, or a
// corrupted active.json all silently no-op rather than blocking the
// SessionStart hook. The tri-state policy (not-configured / unreachable
// / corrupted / healthy) is enforced at this layer so Monitor never has
// to second-guess the writer.
func HandleSessionRegister(in io.Reader, _ io.Writer) error {
	data, _ := io.ReadAll(in)
	var inp registerInput
	_ = json.Unmarshal(data, &inp)
	if inp.SessionID == "" {
		// not-configured: SessionStart fired without an id; nothing to
		// record, no warning to emit.
		return nil
	}

	sessionsDir := filepath.Join(resolveProjectRoot(), ".claude", "sessions")
	if err := os.MkdirAll(sessionsDir, 0o755); err != nil {
		return nil
	}
	activeFile := filepath.Join(sessionsDir, "active.json")

	sessions := readActiveJSON(activeFile)
	now := time.Now().Unix()

	short := inp.SessionID
	if len(short) > 12 {
		short = short[:12]
	}
	sessions[inp.SessionID] = ActiveSession{
		ShortID:  short,
		LastSeen: now,
		PID:      strconv.Itoa(os.Getpid()),
		Status:   "active",
	}

	cutoff := now - int64(registerStaleCutoff.Seconds())
	for id, s := range sessions {
		if s.LastSeen < cutoff {
			delete(sessions, id)
		}
	}

	_ = writeActiveJSON(activeFile, sessions)
	return nil
}

// HandleSessionUnregister removes the session from active.json on Stop.
// We hard-delete (rather than mark "ended") so peers that scan active.json
// for live coordination state see an immediate, race-free truth: if the
// entry is present the session is alive enough to register again on the
// next SessionStart.
//
// Like HandleSessionRegister this is fail-open: missing session_id,
// missing active.json, or a corrupted file all no-op without emitting
// errors that would surface in the Stop hook chain.
func HandleSessionUnregister(in io.Reader, _ io.Writer) error {
	data, _ := io.ReadAll(in)
	var inp registerInput
	_ = json.Unmarshal(data, &inp)
	if inp.SessionID == "" {
		return nil
	}

	sessionsDir := filepath.Join(resolveProjectRoot(), ".claude", "sessions")
	activeFile := filepath.Join(sessionsDir, "active.json")
	if _, err := os.Stat(activeFile); err != nil {
		// not-configured: no register has ever run; nothing to release.
		return nil
	}

	sessions := readActiveJSON(activeFile)
	if _, ok := sessions[inp.SessionID]; !ok {
		return nil
	}
	delete(sessions, inp.SessionID)
	_ = writeActiveJSON(activeFile, sessions)
	return nil
}

// readActiveJSON returns the current active.json contents as a map. A
// missing or corrupted file yields an empty map: callers can then add the
// new entry and write it back, which is the corrupted-state recovery
// described in active-watching-test-policy.md (the next healthy register
// rebuilds the file).
func readActiveJSON(path string) map[string]ActiveSession {
	sessions := map[string]ActiveSession{}
	data, err := os.ReadFile(path)
	if err != nil {
		return sessions
	}
	if err := json.Unmarshal(data, &sessions); err != nil {
		// Corrupted file — start fresh rather than crash the SessionStart
		// chain. The healthy register that follows will rebuild it.
		return map[string]ActiveSession{}
	}
	return sessions
}

// writeActiveJSON serializes the map and writes it via tmp-file + rename
// for atomicity, mirroring scripts/session-register.sh's `mktemp`+`mv`
// pattern so a peer reader never sees a half-written file.
func writeActiveJSON(path string, sessions map[string]ActiveSession) error {
	out, err := json.MarshalIndent(sessions, "", "  ")
	if err != nil {
		return err
	}
	out = append(out, '\n')
	tmp := path + ".tmp." + strconv.FormatInt(time.Now().UnixNano(), 10)
	if err := os.WriteFile(tmp, out, 0o644); err != nil {
		return err
	}
	return os.Rename(tmp, path)
}
