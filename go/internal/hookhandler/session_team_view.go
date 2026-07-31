package hookhandler

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"
)

// PresenceCard is optional JSON stored in a shared presence file. Content must
// never affect liveness (filename + mtime only).
type PresenceCard struct {
	Label string `json:"label,omitempty"`
	Task  string `json:"task,omitempty"`
	Since string `json:"since,omitempty"`
}

// ParsePresenceCardBody decodes presence file bytes fail-open.
func ParsePresenceCardBody(data []byte) PresenceCard {
	var card PresenceCard
	if len(data) == 0 {
		return card
	}
	_ = json.Unmarshal(data, &card)
	return card
}

func encodePresenceCard(card PresenceCard) []byte {
	trimmed := PresenceCard{
		Label: strings.TrimSpace(card.Label),
		Task:  strings.TrimSpace(card.Task),
		Since: strings.TrimSpace(card.Since),
	}
	if trimmed.Label == "" && trimmed.Task == "" && trimmed.Since == "" {
		return nil
	}
	out, err := json.Marshal(trimmed)
	if err != nil {
		return nil
	}
	return out
}

func sessionShortID(sessionID string) string {
	if len(sessionID) > 12 {
		return sessionID[:12]
	}
	return sessionID
}

func displayLabel(card PresenceCard, sessionID string) string {
	if l := strings.TrimSpace(card.Label); l != "" {
		return l
	}
	return sessionShortID(sessionID)
}

func formatElapsedSince(sinceRFC3339 string, now time.Time) string {
	sinceRFC3339 = strings.TrimSpace(sinceRFC3339)
	if sinceRFC3339 == "" {
		return ""
	}
	ts, err := time.Parse(time.RFC3339, sinceRFC3339)
	if err != nil {
		return ""
	}
	d := now.Sub(ts)
	if d < 0 {
		d = 0
	}
	if d < time.Minute {
		return fmt.Sprintf("%ds", int(d.Seconds()))
	}
	if d < time.Hour {
		return fmt.Sprintf("%dm", int(d.Minutes()))
	}
	if d < 24*time.Hour {
		return fmt.Sprintf("%dh", int(d.Hours()))
	}
	return fmt.Sprintf("%dd", int(d.Hours()/24))
}

// ReadLocalSessionID reads .claude/state/session.json (fail-open).
func ReadLocalSessionID(projectRoot string) string {
	if projectRoot == "" {
		projectRoot = resolveProjectRoot()
	}
	path := filepath.Join(projectRoot, ".claude", "state", "session.json")
	data, err := os.ReadFile(path)
	if err != nil {
		return ""
	}
	var st struct {
		SessionID string `json:"session_id"`
	}
	if err := json.Unmarshal(data, &st); err != nil {
		return ""
	}
	return strings.TrimSpace(st.SessionID)
}

func writeOwnPresenceCard(projectRoot, sessionID string, card PresenceCard) error {
	if !validPresenceSessionID(sessionID) {
		return fmt.Errorf("invalid session id")
	}
	dir := sharedLiveSessionsDirFromRoot(projectRoot)
	if dir == "" {
		return fmt.Errorf("shared live-sessions dir unavailable")
	}
	if err := os.MkdirAll(dir, presenceDirMode); err != nil {
		return err
	}
	path := filepath.Join(dir, sessionID)
	body := encodePresenceCard(card)
	now := time.Now()
	if err := os.WriteFile(path, body, presenceFileMode); err != nil {
		return err
	}
	return os.Chtimes(path, now, now)
}

func readOwnPresenceCard(projectRoot, sessionID string) PresenceCard {
	if !validPresenceSessionID(sessionID) {
		return PresenceCard{}
	}
	dir := sharedLiveSessionsDirFromRoot(projectRoot)
	if dir == "" {
		return PresenceCard{}
	}
	data, err := os.ReadFile(filepath.Join(dir, sessionID))
	if err != nil {
		return PresenceCard{}
	}
	return ParsePresenceCardBody(data)
}

// SessionDeclareTask sets task + since on the caller's presence file.
func SessionDeclareTask(projectRoot, sessionID, taskID string) error {
	taskID = strings.TrimSpace(taskID)
	if taskID == "" {
		return fmt.Errorf("task id required")
	}
	card := readOwnPresenceCard(projectRoot, sessionID)
	if card.Label == "" {
		card.Label = strings.TrimSpace(os.Getenv("HARNESS_SESSION_LABEL"))
	}
	card.Task = taskID
	card.Since = time.Now().UTC().Format(time.RFC3339)
	return writeOwnPresenceCard(projectRoot, sessionID, card)
}

// SessionDeclareClear removes task/since from the caller's presence file.
func SessionDeclareClear(projectRoot, sessionID string) error {
	card := readOwnPresenceCard(projectRoot, sessionID)
	card.Task = ""
	card.Since = ""
	if card.Label == "" {
		card.Label = strings.TrimSpace(os.Getenv("HARNESS_SESSION_LABEL"))
	}
	return writeOwnPresenceCard(projectRoot, sessionID, card)
}

// FormatSessionTeamList renders a tab-separated team view (grep-friendly task column).
// Live rows are the union of shared presence files and the worktree-local
// active.json roster (same survival set as lease isStale), with presence winning
// on duplicates.
func FormatSessionTeamList(projectRoot string, now time.Time) string {
	if projectRoot == "" {
		projectRoot = resolveProjectRoot()
	}
	var b strings.Builder
	b.WriteString("session_id\tlabel\ttask\tsince\telapsed\n")
	seen := make(map[string]struct{})
	cutoff := now.Add(-registerStaleCutoff)

	dir := sharedLiveSessionsDirFromRoot(projectRoot)
	if dir != "" {
		entries, err := os.ReadDir(dir)
		if err == nil {
			for _, ent := range entries {
				if ent.IsDir() {
					continue
				}
				name := ent.Name()
				if !validPresenceSessionID(name) {
					continue
				}
				info, err := ent.Info()
				if err != nil || info.ModTime().Before(cutoff) {
					continue
				}
				seen[name] = struct{}{}
				data, _ := os.ReadFile(filepath.Join(dir, name))
				card := ParsePresenceCardBody(data)
				label := displayLabel(card, name)
				elapsed := formatElapsedSince(card.Since, now)
				fmt.Fprintf(&b, "%s\t%s\t%s\t%s\t%s\n", name, label, card.Task, card.Since, elapsed)
			}
		}
	}

	activePath := filepath.Join(projectRoot, ".claude", "sessions", "active.json")
	sessions := readActiveJSON(activePath)
	lastSeenCutoff := now.Unix() - int64(registerStaleCutoff.Seconds())
	var rosterOnly []string
	for id, s := range sessions {
		if _, listed := seen[id]; listed {
			continue
		}
		if !validPresenceSessionID(id) {
			continue
		}
		if s.LastSeen < lastSeenCutoff {
			continue
		}
		rosterOnly = append(rosterOnly, id)
	}
	sort.Strings(rosterOnly)
	for _, id := range rosterOnly {
		label := sessionShortID(id)
		fmt.Fprintf(&b, "%s\t%s\t\t\t\n", id, label)
	}
	return b.String()
}

// presenceBodyForNewFile builds optional JSON for a newly created presence file.
func presenceBodyForNewFile(label string) []byte {
	label = strings.TrimSpace(label)
	if label == "" {
		return nil
	}
	return encodePresenceCard(PresenceCard{Label: label})
}
