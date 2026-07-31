package main

import (
	"bytes"
	"context"
	"encoding/json"
	"io"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/Chachamaru127/claude-code-harness/go/internal/livemsg"
)

func TestInboxCheck_SilentWhenZeroUnread(t *testing.T) {
	missing := filepath.Join(t.TempDir(), "no-such-livemsg.db")
	out, code := runInboxCheckCapture([]string{
		"--team", "team-a",
		"--agent", "agent-1",
		"--db", missing,
	})
	if code != 0 {
		t.Fatalf("expected exit 0, got %d", code)
	}
	if strings.TrimSpace(out) != "" {
		t.Fatalf("zero unread must produce no stdout (silent hook), got: %q", out)
	}
}

func TestInboxCheck_StopTurnDeliveryE2E(t *testing.T) {
	team := "team-hotl"
	recipient := "session-recipient-abc"
	sender := "human-operator"
	dbPath := filepath.Join(t.TempDir(), "livemsg.db")

	store, err := livemsg.Open(dbPath)
	if err != nil {
		t.Fatalf("Open: %v", err)
	}
	body := "HOTL nudge: please sync with peer"
	if _, err := store.Send(context.Background(), team, sender, recipient, "nudge", body); err != nil {
		t.Fatalf("Send: %v", err)
	}
	store.Close()

	// Session B (recipient) at Stop turn boundary: stdin carries session_id; no --agent flag.
	var stdout bytes.Buffer
	var stderr bytes.Buffer
	stdin := strings.NewReader(`{"session_id":"` + recipient + `","cwd":"/tmp"}`)
	code := runInboxCheckCommandWithStdin([]string{"--team", team, "--db", dbPath}, stdin, &stdout, &stderr)
	if code != 0 {
		t.Fatalf("exit %d stderr=%q", code, stderr.String())
	}
	raw := stdout.String()
	if strings.TrimSpace(raw) == "" {
		t.Fatal("expected delivery JSON when unread > 0")
	}

	var result inboxCheckOutput
	if err := json.Unmarshal(stdout.Bytes(), &result); err != nil {
		t.Fatalf("JSON: %v raw=%q", err, raw)
	}
	if result.Unread != 1 {
		t.Fatalf("unread = %d, want 1", result.Unread)
	}
	if result.InjectContext == "" || !strings.Contains(result.InjectContext, "not instructions") {
		t.Fatalf("inject_context must include non-instruction disclaimer, got: %q", result.InjectContext)
	}
	if !strings.Contains(result.InjectContext, body) {
		t.Fatalf("inject_context must include sanitized body, got: %q", result.InjectContext)
	}

	// Second Stop boundary: already read → silent.
	var stdout2 bytes.Buffer
	code2 := runInboxCheckCommandWithStdin([]string{"--team", team, "--db", dbPath}, strings.NewReader(`{"session_id":"`+recipient+`"}`), &stdout2, &stderr)
	if code2 != 0 {
		t.Fatalf("second check exit %d", code2)
	}
	if strings.TrimSpace(stdout2.String()) != "" {
		t.Fatalf("after mark-read, Stop check must be silent, got: %q", stdout2.String())
	}
}

// TestInboxCheck_FromEnvStdinSessionIDFallback covers codex/cursor generated hooks:
// `inbox check --from-env` with no livemsg/breezing env, stdin carries session_id.
func TestInboxCheck_FromEnvStdinSessionIDFallback(t *testing.T) {
	t.Setenv("HARNESS_LIVEMSG_TEAM", "")
	t.Setenv("HARNESS_LIVEMSG_AGENT", "")
	t.Setenv("BREEZING_SESSION_ID", "")
	t.Setenv("BREEZING_ROLE", "")

	team := "default"
	sessionID := "standalone-session-122-2"
	dbPath := seedInboxDB(t, team, "peer", sessionID, 1)

	var stdout, stderr bytes.Buffer
	stdin := strings.NewReader(`{"session_id":"` + sessionID + `"}`)
	code := runInboxCheckCommandWithStdin([]string{"--from-env", "--db", dbPath}, stdin, &stdout, &stderr)
	if code != 0 {
		t.Fatalf("exit %d stderr=%q", code, stderr.String())
	}
	raw := strings.TrimSpace(stdout.String())
	if raw == "" {
		t.Fatalf("expected delivery JSON when unread > 0; stderr=%q", stderr.String())
	}
	var result inboxCheckOutput
	if err := json.Unmarshal([]byte(raw), &result); err != nil {
		t.Fatalf("JSON: %v raw=%q", err, raw)
	}
	if result.Team != team || result.Agent != sessionID {
		t.Fatalf("identity: team=%q agent=%q, want team=%q agent=%q", result.Team, result.Agent, team, sessionID)
	}
	if result.Unread != 1 {
		t.Fatalf("unread = %d, want 1", result.Unread)
	}
}

func runInboxCheckCommandWithStdin(args []string, stdin io.Reader, stdout, stderr io.Writer) int {
	oldStdin := os.Stdin
	r, w, err := os.Pipe()
	if err != nil {
		panic(err)
	}
	os.Stdin = r
	go func() {
		_, _ = io.Copy(w, stdin)
		w.Close()
	}()
	defer func() { os.Stdin = oldStdin }()
	return runInboxCheckCommand(args, stdout, stderr)
}

func TestClaudeHooksJSON_StopWiresLivemsgInboxCheck(t *testing.T) {
	repoRoot := filepath.Clean(filepath.Join("..", "..", ".."))
	for _, rel := range []string{"hooks/hooks.json", ".claude-plugin/hooks.json"} {
		path := filepath.Join(repoRoot, rel)
		data, err := os.ReadFile(path)
		if err != nil {
			t.Fatalf("read %s: %v", rel, err)
		}
		var doc struct {
			Hooks struct {
				Stop []struct {
					Hooks []struct {
						Command string `json:"command"`
					} `json:"hooks"`
				} `json:"Stop"`
			} `json:"hooks"`
		}
		if err := json.Unmarshal(data, &doc); err != nil {
			t.Fatalf("%s: JSON: %v", rel, err)
		}
		found := false
		for _, group := range doc.Hooks.Stop {
			for _, h := range group.Hooks {
				if strings.Contains(h.Command, "inbox check") && strings.Contains(h.Command, "HARNESS_LIVEMSG_TEAM") {
					found = true
					break
				}
			}
		}
		if !found {
			t.Fatalf("%s: Stop hook must wire livemsg inbox check with env-resolvable team", rel)
		}
		if strings.Contains(string(data), "inbox monitor") {
			t.Fatalf("%s: inbox monitor must not be wired by default (opt-in only)", rel)
		}
	}
}
