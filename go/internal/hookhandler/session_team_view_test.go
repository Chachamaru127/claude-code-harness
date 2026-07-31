package hookhandler

import (
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"testing"
	"time"
)

func seedGitRepoTeamView(t *testing.T) string {
	t.Helper()
	return initGitRepoForPresence(t)
}

func writeSessionJSON(t *testing.T, projectRoot, sessionID string) {
	t.Helper()
	stateDir := filepath.Join(projectRoot, ".claude", "state")
	if err := os.MkdirAll(stateDir, 0o755); err != nil {
		t.Fatal(err)
	}
	body := `{"session_id":"` + sessionID + `"}`
	if err := os.WriteFile(filepath.Join(stateDir, "session.json"), []byte(body), 0o644); err != nil {
		t.Fatal(err)
	}
}

func writeActiveJSONOnly(t *testing.T, projectRoot, sessionID string, lastSeen time.Time) {
	t.Helper()
	sessionsDir := filepath.Join(projectRoot, ".claude", "sessions")
	if err := os.MkdirAll(sessionsDir, 0o755); err != nil {
		t.Fatal(err)
	}
	short := sessionID
	if len(short) > 12 {
		short = short[:12]
	}
	sessions := map[string]ActiveSession{
		sessionID: {
			ShortID:  short,
			LastSeen: lastSeen.Unix(),
			PID:      strconv.Itoa(os.Getpid()),
			Status:   "active",
		},
	}
	if err := writeActiveJSON(filepath.Join(sessionsDir, "active.json"), sessions); err != nil {
		t.Fatal(err)
	}
}

func touchFreshPresence(t *testing.T, projectRoot, sessionID string, body []byte) {
	t.Helper()
	dir := sharedLiveSessionsDirFromRoot(projectRoot)
	if err := os.MkdirAll(dir, presenceDirMode); err != nil {
		t.Fatal(err)
	}
	path := filepath.Join(dir, sessionID)
	if err := os.WriteFile(path, body, presenceFileMode); err != nil {
		t.Fatal(err)
	}
	now := time.Now()
	if err := os.Chtimes(path, now, now); err != nil {
		t.Fatal(err)
	}
}

// TestSessionTeamView_ListIncludesActiveJSONOnlySession expects roster-only
// sessions (no shared presence file) in team list — same union as lease isStale.
func TestSessionTeamView_ListIncludesActiveJSONOnlySession(t *testing.T) {
	dir := seedGitRepoTeamView(t)
	const sessionID = "sess-active-json-only"
	now := time.Now()
	writeActiveJSONOnly(t, dir, sessionID, now)

	out := FormatSessionTeamList(dir, now)
	if !strings.Contains(out, sessionID) {
		t.Fatalf("list must include active.json-only session %q:\n%s", sessionID, out)
	}
	short := sessionID
	if len(short) > 12 {
		short = short[:12]
	}
	if !strings.Contains(out, short) {
		t.Fatalf("label must use short_id fallback %q:\n%s", short, out)
	}
}

// TestSessionTeamView_DeclareListClearRoundTrip pins declare → list → clear.
func TestSessionTeamView_DeclareListClearRoundTrip(t *testing.T) {
	dir := seedGitRepoTeamView(t)
	const sessionID = "sess-team-roundtrip"
	writeSessionJSON(t, dir, sessionID)
	t.Setenv("HARNESS_PROJECT_ROOT", dir)

	if err := SessionDeclareTask(dir, sessionID, "121.4"); err != nil {
		t.Fatalf("declare: %v", err)
	}

	out := FormatSessionTeamList(dir, time.Now())
	if !strings.Contains(out, "121.4") {
		t.Fatalf("list after declare must include task 121.4:\n%s", out)
	}
	if !strings.Contains(out, sessionID) {
		t.Fatalf("list must include session_id column value:\n%s", out)
	}

	if err := SessionDeclareClear(dir, sessionID); err != nil {
		t.Fatalf("clear: %v", err)
	}
	outAfter := FormatSessionTeamList(dir, time.Now())
	for _, line := range strings.Split(outAfter, "\n") {
		if strings.Contains(line, "121.4") {
			t.Fatalf("task must be gone after clear, got line: %q\nfull:\n%s", line, outAfter)
		}
	}
}

// TestSessionTeamView_LabelFallbackShortID shows short_id when label absent.
func TestSessionTeamView_LabelFallbackShortID(t *testing.T) {
	dir := seedGitRepoTeamView(t)
	const sessionID = "sess-label-fallback-xx"
	short := sessionID
	if len(short) > 12 {
		short = short[:12]
	}
	touchFreshPresence(t, dir, sessionID, nil)

	out := FormatSessionTeamList(dir, time.Now())
	if !strings.Contains(out, short) {
		t.Fatalf("label fallback must show short_id %q:\n%s", short, out)
	}
}

// TestSessionTeamView_TaskReverseLookupGrep simulates operator grep by task id.
func TestSessionTeamView_TaskReverseLookupGrep(t *testing.T) {
	dir := seedGitRepoTeamView(t)
	const sessionID = "sess-reverse-lookup"
	writeSessionJSON(t, dir, sessionID)
	t.Setenv("HARNESS_PROJECT_ROOT", dir)

	if err := SessionDeclareTask(dir, sessionID, "121.4"); err != nil {
		t.Fatal(err)
	}
	out := FormatSessionTeamList(dir, time.Now())
	var matched string
	for _, line := range strings.Split(out, "\n") {
		if strings.Contains(line, "121.4") {
			matched = line
			break
		}
	}
	if matched == "" {
		t.Fatalf("grep 121.4 found no line:\n%s", out)
	}
	if !strings.Contains(matched, sessionID) {
		t.Fatalf("matched line must identify session %q: %q", sessionID, matched)
	}
}

// TestSharedPresence_JSONContentSameLivenessAsEmpty ensures file content does not
// change mtime-based liveness (Phase 120 contract).
func TestSharedPresence_JSONContentSameLivenessAsEmpty(t *testing.T) {
	const sessionID = "sess-json-liveness"
	dir := initGitRepoForPresence(t)
	commonDir, ok := resolveGitCommonDir(dir)
	if !ok {
		t.Fatal("git common dir")
	}
	cfg := LeaseConfig{RepoRoot: dir, GitCommonDir: commonDir, SessionID: "other"}
	now := time.Now()

	liveDir := sharedLiveSessionsDirFromRoot(dir)
	if err := os.MkdirAll(liveDir, presenceDirMode); err != nil {
		t.Fatal(err)
	}

	emptyPath := filepath.Join(liveDir, sessionID+"-empty")
	if err := os.WriteFile(emptyPath, nil, presenceFileMode); err != nil {
		t.Fatal(err)
	}
	if err := os.Chtimes(emptyPath, now, now); err != nil {
		t.Fatal(err)
	}

	jsonBody := []byte(`{"label":"x","task":"121.4","since":"2020-01-01T00:00:00Z"}`)
	jsonPath := filepath.Join(liveDir, sessionID+"-json")
	if err := os.WriteFile(jsonPath, jsonBody, presenceFileMode); err != nil {
		t.Fatal(err)
	}
	if err := os.Chtimes(jsonPath, now, now); err != nil {
		t.Fatal(err)
	}

	emptyAlive := isHolderAliveViaSharedPresence(sessionID+"-empty", cfg, now)
	jsonAlive := isHolderAliveViaSharedPresence(sessionID+"-json", cfg, now)
	if emptyAlive != jsonAlive {
		t.Fatalf("liveness must not depend on content: empty=%v json=%v", emptyAlive, jsonAlive)
	}
	if !emptyAlive {
		t.Fatal("expected both fresh presence files to be live")
	}
}
