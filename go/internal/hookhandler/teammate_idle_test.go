package hookhandler

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

// assertTeammateIdleApprove is a helper that validates an approve response.
func assertTeammateIdleApprove(t *testing.T, output, wantReason string) {
	t.Helper()
	output = strings.TrimSpace(output)
	if output == "" {
		t.Fatal("expected JSON output, got empty")
	}
	var resp map[string]string
	if err := json.Unmarshal([]byte(output), &resp); err != nil {
		t.Fatalf("output is not valid JSON: %v\noutput: %s", err, output)
	}
	if resp["decision"] != "approve" {
		t.Errorf("decision = %q, want approve", resp["decision"])
	}
	if wantReason != "" && !strings.Contains(resp["reason"], wantReason) {
		t.Errorf("reason = %q, want to contain %q", resp["reason"], wantReason)
	}
}

// assertTeammateIdleStop is a helper that validates a stop response.
func assertTeammateIdleStop(t *testing.T, output, wantStopReason string) {
	t.Helper()
	output = strings.TrimSpace(output)
	if output == "" {
		t.Fatal("expected JSON output, got empty")
	}
	var resp map[string]interface{}
	if err := json.Unmarshal([]byte(output), &resp); err != nil {
		t.Fatalf("output is not valid JSON: %v\noutput: %s", err, output)
	}
	cont, ok := resp["continue"].(bool)
	if !ok || cont {
		t.Errorf("continue = %v, want false", resp["continue"])
	}
	stopReason, _ := resp["stopReason"].(string)
	if wantStopReason != "" && !strings.Contains(stopReason, wantStopReason) {
		t.Errorf("stopReason = %q, want to contain %q", stopReason, wantStopReason)
	}
}

func TestHandleTeammateIdle_EmptyInput(t *testing.T) {
	var out bytes.Buffer
	if err := HandleTeammateIdle(strings.NewReader(""), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	assertTeammateIdleApprove(t, out.String(), "no payload")
}

func TestHandleTeammateIdle_InvalidJSON(t *testing.T) {
	var out bytes.Buffer
	if err := HandleTeammateIdle(strings.NewReader("not json"), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	assertTeammateIdleApprove(t, out.String(), "no payload")
}

func TestHandleTeammateIdle_BasicApprove(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("PROJECT_ROOT", dir)

	payload := `{"teammate_name":"worker-1","team_name":"breezing","agent_id":"agent-abc","agent_type":"worker"}`
	var out bytes.Buffer
	if err := HandleTeammateIdle(strings.NewReader(payload), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	assertTeammateIdleApprove(t, out.String(), "TeammateIdle tracked")
}

func TestHandleTeammateIdle_WritesTimeline(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("PROJECT_ROOT", dir)

	payload := `{"teammate_name":"worker-1","team_name":"team-a","agent_id":"agent-1","agent_type":"worker"}`
	var out bytes.Buffer
	if err := HandleTeammateIdle(strings.NewReader(payload), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	// Verify that the timeline file was created
	timelineFile := filepath.Join(dir, ".claude", "state", "breezing-timeline.jsonl")
	data, err := os.ReadFile(timelineFile)
	if err != nil {
		t.Fatalf("timeline file not created: %v", err)
	}

	if !strings.Contains(string(data), "teammate_idle") {
		t.Errorf("timeline does not contain teammate_idle event\ncontents: %s", data)
	}
	if !strings.Contains(string(data), "worker-1") {
		t.Errorf("timeline does not contain teammate name\ncontents: %s", data)
	}
	if !strings.Contains(string(data), "team-a") {
		t.Errorf("timeline does not contain team name\ncontents: %s", data)
	}
}

func TestHandleTeammateIdle_StopWhenContinueFalse(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("PROJECT_ROOT", dir)

	payload := `{"teammate_name":"worker-1","continue":false}`
	var out bytes.Buffer
	if err := HandleTeammateIdle(strings.NewReader(payload), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	assertTeammateIdleStop(t, out.String(), "TeammateIdle requested stop")
}

func TestHandleTeammateIdle_StopWithReason(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("PROJECT_ROOT", dir)

	payload := `{"teammate_name":"worker-1","continue":false,"stopReason":"task completed"}`
	var out bytes.Buffer
	if err := HandleTeammateIdle(strings.NewReader(payload), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	assertTeammateIdleStop(t, out.String(), "task completed")
}

func TestHandleTeammateIdle_StopWithStopReason(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("PROJECT_ROOT", dir)

	// stop_reason field (alias)
	payload := `{"teammate_name":"worker-1","stop_reason":"error occurred"}`
	var out bytes.Buffer
	if err := HandleTeammateIdle(strings.NewReader(payload), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	assertTeammateIdleStop(t, out.String(), "error occurred")
}

func TestHandleTeammateIdle_DedupSkip(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("PROJECT_ROOT", dir)

	// First call
	payload := `{"teammate_name":"worker-1","team_name":"team-a","agent_id":"agent-1"}`
	var out1 bytes.Buffer
	if err := HandleTeammateIdle(strings.NewReader(payload), &out1); err != nil {
		t.Fatalf("first call: unexpected error: %v", err)
	}
	assertTeammateIdleApprove(t, out1.String(), "TeammateIdle tracked")

	// Second call (within 5 seconds) → skipped by dedup
	var out2 bytes.Buffer
	if err := HandleTeammateIdle(strings.NewReader(payload), &out2); err != nil {
		t.Fatalf("second call: unexpected error: %v", err)
	}
	assertTeammateIdleApprove(t, out2.String(), "dedup: skipped")
}

func TestHandleTeammateIdle_DedupAfterWindow(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("PROJECT_ROOT", dir)

	// Manually write an old timeline entry (10 seconds ago)
	stateDir := filepath.Join(dir, ".claude", "state")
	_ = os.MkdirAll(stateDir, 0o755)
	timelineFile := filepath.Join(stateDir, "breezing-timeline.jsonl")

	oldEntry := teammateIdleLogEntry{
		Event:     "teammate_idle",
		Teammate:  "worker-old",
		Team:      "team-a",
		AgentID:   "agent-old",
		Timestamp: time.Now().Add(-10 * time.Second).UTC().Format(time.RFC3339),
	}
	entryData, _ := json.Marshal(oldEntry)
	_ = os.WriteFile(timelineFile, append(entryData, '\n'), 0o644)

	// Call with the same teammate → more than 5 seconds elapsed, so do not skip
	payload := `{"teammate_name":"worker-old","team_name":"team-a","agent_id":"agent-old"}`
	var out bytes.Buffer
	if err := HandleTeammateIdle(strings.NewReader(payload), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	assertTeammateIdleApprove(t, out.String(), "TeammateIdle tracked")
}

func TestHandleTeammateIdle_AgentNameFallback(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("PROJECT_ROOT", dir)

	// agent_name field (alternative to teammate_name)
	payload := `{"agent_name":"reviewer-1","team_name":"team-b"}`
	var out bytes.Buffer
	if err := HandleTeammateIdle(strings.NewReader(payload), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	assertTeammateIdleApprove(t, out.String(), "TeammateIdle tracked")

	timelineFile := filepath.Join(dir, ".claude", "state", "breezing-timeline.jsonl")
	data, _ := os.ReadFile(timelineFile)
	if !strings.Contains(string(data), "reviewer-1") {
		t.Errorf("timeline should contain agent_name fallback\ncontents: %s", data)
	}
}

func TestRotateJSONL_BelowThreshold(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "test.jsonl")

	// File with 10 lines
	var lines []string
	for i := 0; i < 10; i++ {
		lines = append(lines, `{"n":`+string(rune('0'+i))+`}`)
	}
	content := strings.Join(lines, "\n") + "\n"
	_ = os.WriteFile(path, []byte(content), 0o644)

	_ = rotateJSONL(path, 500, 400)

	data, _ := os.ReadFile(path)
	got := strings.Count(strings.TrimRight(string(data), "\n"), "\n") + 1
	if got != 10 {
		t.Errorf("expected 10 lines after rotation (below threshold), got %d", got)
	}
}

func TestRotateJSONL_AboveThreshold(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "test.jsonl")

	// Create a file with 600 lines
	var lines []string
	for i := 0; i < 600; i++ {
		lines = append(lines, `{"n":`+string([]byte{byte('a' + i%26)})+`}`)
	}
	content := strings.Join(lines, "\n") + "\n"
	_ = os.WriteFile(path, []byte(content), 0o644)

	_ = rotateJSONL(path, 500, 400)

	data, _ := os.ReadFile(path)
	trimmed := strings.TrimRight(string(data), "\n")
	got := len(strings.Split(trimmed, "\n"))
	if got != 400 {
		t.Errorf("expected 400 lines after rotation, got %d", got)
	}
}

func TestCheckTeammateIdleDedup_NoFile(t *testing.T) {
	result := checkTeammateIdleDedup("/nonexistent/timeline.jsonl", "worker-1")
	if result {
		t.Error("should not skip when file does not exist")
	}
}

func TestCheckTeammateIdleDedup_RecentEntry(t *testing.T) {
	dir := t.TempDir()
	timelineFile := filepath.Join(dir, "timeline.jsonl")

	// Write a recent entry
	entry := teammateIdleLogEntry{
		Event:     "teammate_idle",
		Teammate:  "worker-1",
		Timestamp: time.Now().UTC().Format(time.RFC3339),
	}
	data, _ := json.Marshal(entry)
	_ = os.WriteFile(timelineFile, append(data, '\n'), 0o644)

	result := checkTeammateIdleDedup(timelineFile, "worker-1")
	if !result {
		t.Error("should skip when recent entry exists within 5 seconds")
	}
}

func TestCheckTeammateIdleDedup_OldEntry(t *testing.T) {
	dir := t.TempDir()
	timelineFile := filepath.Join(dir, "timeline.jsonl")

	// Write an old entry (10 seconds ago)
	entry := teammateIdleLogEntry{
		Event:     "teammate_idle",
		Teammate:  "worker-1",
		Timestamp: time.Now().Add(-10 * time.Second).UTC().Format(time.RFC3339),
	}
	data, _ := json.Marshal(entry)
	_ = os.WriteFile(timelineFile, append(data, '\n'), 0o644)

	result := checkTeammateIdleDedup(timelineFile, "worker-1")
	if result {
		t.Error("should not skip when entry is older than 5 seconds")
	}
}
