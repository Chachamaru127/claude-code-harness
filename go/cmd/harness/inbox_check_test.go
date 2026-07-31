package main

import (
	"bytes"
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/Chachamaru127/claude-code-harness/go/internal/livemsg"
)

func seedInboxDB(t *testing.T, team, from, to string, count int) string {
	t.Helper()
	dir := t.TempDir()
	dbPath := filepath.Join(dir, "livemsg.db")
	store, err := livemsg.Open(dbPath)
	if err != nil {
		t.Fatalf("Open: %v", err)
	}
	defer store.Close()

	ctx := context.Background()
	for i := 0; i < count; i++ {
		subject := "subj"
		body := "body"
		if _, err := store.Send(ctx, team, from, to, subject, body); err != nil {
			t.Fatalf("Send #%d: %v", i, err)
		}
	}
	return dbPath
}

func runInboxCheckCapture(args []string) (string, int) {
	var stdout bytes.Buffer
	var stderr bytes.Buffer
	code := runInboxCheckCommand(args, &stdout, &stderr)
	return stdout.String(), code
}

func TestInboxCheck_EmptyDB(t *testing.T) {
	missing := filepath.Join(t.TempDir(), "no-such-livemsg.db")
	out, code := runInboxCheckCapture([]string{
		"--team", "team-a",
		"--agent", "agent-1",
		"--db", missing,
	})
	if code != 0 {
		t.Fatalf("expected exit 0 for missing DB (fail-open), got %d; stderr path ok", code)
	}
	if strings.TrimSpace(out) != "" {
		t.Fatalf("zero unread must be silent on stdout, got: %q", out)
	}
}

// TestInboxCheck_GeneratedDeliveryCommandForm exercises the exact argument shape
// that Phase 105.9 generated delivery hooks emit: `inbox check --team X --agent Y`
// with NO --db. Before the fix this hit the "--db is required" path (fail-open,
// exit 0, error on stderr, no valid JSON). Now it must resolve a default db,
// succeed with valid empty JSON, and never print the "--db is required" error.
func TestInboxCheck_GeneratedDeliveryCommandForm(t *testing.T) {
	// Point the default resolver at an empty temp project so no real db exists.
	t.Setenv("CLAUDE_PLUGIN_DATA", t.TempDir())
	t.Setenv("HARNESS_LIVEMSG_TEAM", "team-a")
	t.Setenv("HARNESS_LIVEMSG_AGENT", "agent-1")

	var stdout, stderr bytes.Buffer
	code := runInboxCheckCommand([]string{"--from-env"}, &stdout, &stderr)
	if code != 0 {
		t.Fatalf("generated command form should exit 0, got %d; stderr=%q", code, stderr.String())
	}
	if strings.Contains(stderr.String(), "--db is required") {
		t.Fatalf("generated command form must not hit the --db-required error path; stderr=%q", stderr.String())
	}
	if strings.TrimSpace(stdout.String()) != "" {
		t.Fatalf("generated delivery form with empty inbox must be silent, got: %q", stdout.String())
	}
}

func TestInboxCheck_FromEnvReadsLivemsgInbox(t *testing.T) {
	team := "team-smoke"
	agent := "agent-smoke"
	dbPath := seedInboxDB(t, team, "peer", agent, 1)
	t.Setenv("HARNESS_LIVEMSG_TEAM", team)
	t.Setenv("HARNESS_LIVEMSG_AGENT", agent)

	out, code := runInboxCheckCapture([]string{"--from-env", "--db", dbPath})
	if code != 0 {
		t.Fatalf("exit = %d, want 0", code)
	}
	var result inboxCheckOutput
	if err := json.Unmarshal([]byte(out), &result); err != nil {
		t.Fatalf("JSON: %v", err)
	}
	if result.Team != team || result.Agent != agent {
		t.Fatalf("identity not resolved: %+v", result)
	}
	if result.Unread != 1 {
		t.Fatalf("unread = %d, want 1", result.Unread)
	}
}

func TestInboxCheck_ReadsAndMarksRead(t *testing.T) {
	team := "team-a"
	agent := "agent-2"
	dbPath := seedInboxDB(t, team, "agent-1", agent, 2)

	args := []string{"--team", team, "--agent", agent, "--db", dbPath}

	out1, code1 := runInboxCheckCapture(args)
	if code1 != 0 {
		t.Fatalf("first check exit = %d, want 0", code1)
	}
	var first inboxCheckOutput
	if err := json.Unmarshal([]byte(out1), &first); err != nil {
		t.Fatalf("first JSON: %v\nraw: %s", err, out1)
	}
	if first.Unread != 2 {
		t.Fatalf("first unread = %d, want 2", first.Unread)
	}
	if len(first.Messages) != 2 {
		t.Fatalf("first messages len = %d, want 2", len(first.Messages))
	}

	out2, code2 := runInboxCheckCapture(args)
	if code2 != 0 {
		t.Fatalf("second check exit = %d, want 0", code2)
	}
	if strings.TrimSpace(out2) != "" {
		t.Fatalf("second check with zero unread must be silent, got: %q", out2)
	}
}

func copyDBFile(t *testing.T, src string) string {
	t.Helper()
	data, err := os.ReadFile(src)
	if err != nil {
		t.Fatalf("ReadFile: %v", err)
	}
	dst := filepath.Join(t.TempDir(), "livemsg-copy.db")
	if err := os.WriteFile(dst, data, 0o644); err != nil {
		t.Fatalf("WriteFile: %v", err)
	}
	return dst
}

func TestInboxCheck_StableJSONOrder(t *testing.T) {
	team := "team-a"
	agent := "agent-2"
	src := seedInboxDB(t, team, "agent-1", agent, 2)

	runOnCopy := func() string {
		dbPath := copyDBFile(t, src)
		args := []string{"--team", team, "--agent", agent, "--db", dbPath}
		out, code := runInboxCheckCapture(args)
		if code != 0 {
			t.Fatalf("check exit = %d", code)
		}
		return out
	}

	a := runOnCopy()
	b := runOnCopy()
	if a != b {
		t.Errorf("inbox check JSON not bytes-identical:\nfirst:\n%s\nsecond:\n%s", a, b)
	}
}
