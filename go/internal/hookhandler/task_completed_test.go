package hookhandler

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// --- Helpers ---

func setupTaskCompletedHandler(t *testing.T) (*taskCompletedHandler, string) {
	t.Helper()
	dir := t.TempDir()
	stateDir := filepath.Join(dir, ".claude", "state")
	if err := os.MkdirAll(stateDir, 0o700); err != nil {
		t.Fatal(err)
	}
	h := &taskCompletedHandler{
		projectRoot:    dir,
		stateDir:       stateDir,
		timelineFile:   filepath.Join(stateDir, "breezing-timeline.jsonl"),
		pendingFixFile: filepath.Join(stateDir, "pending-fix-proposals.jsonl"),
		finalizeMarker: filepath.Join(stateDir, "harness-mem-finalize-work-completed.json"),
	}
	return h, dir
}

// --- HandleTaskCompleted ---

func TestHandleTaskCompleted_NoPayload(t *testing.T) {
	var out bytes.Buffer
	err := HandleTaskCompleted(strings.NewReader(""), &out)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	var resp map[string]string
	if err := json.NewDecoder(&out).Decode(&resp); err != nil {
		t.Fatalf("invalid JSON: %v", err)
	}
	if resp["decision"] != "approve" {
		t.Errorf("want approve, got %q", resp["decision"])
	}
}

func TestHandleTaskCompleted_BasicApprove(t *testing.T) {
	dir := t.TempDir()
	input := fmt.Sprintf(`{
		"teammate_name": "worker-1",
		"task_id": "T1",
		"task_subject": "implement feature",
		"cwd": "%s"
	}`, dir)

	var out bytes.Buffer
	err := HandleTaskCompleted(strings.NewReader(input), &out)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	var resp map[string]string
	if err := json.NewDecoder(&out).Decode(&resp); err != nil {
		t.Fatalf("invalid JSON: %v", err)
	}
	if resp["decision"] != "approve" {
		t.Errorf("want approve, got %q", resp["decision"])
	}
}

func TestHandleTaskCompleted_StopRequested(t *testing.T) {
	dir := t.TempDir()
	input := fmt.Sprintf(`{
		"teammate_name": "worker-1",
		"task_id": "T1",
		"task_subject": "done",
		"continue": false,
		"stopReason": "user requested stop",
		"cwd": "%s"
	}`, dir)

	var out bytes.Buffer
	err := HandleTaskCompleted(strings.NewReader(input), &out)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	var resp map[string]interface{}
	if err := json.NewDecoder(&out).Decode(&resp); err != nil {
		t.Fatalf("invalid JSON: %v", err)
	}
	if resp["continue"] != false {
		t.Errorf("want continue=false, got %v", resp["continue"])
	}
}

// TestHandleTaskCompleted_TerminalSequenceEmit verifies that the terminalSequence field
// is added to the TaskCompleted response when HARNESS_TERMINAL_NOTIFY=osc9 is set (CC 2.1.141+ Phase 69).
func TestHandleTaskCompleted_TerminalSequenceEmit(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("HARNESS_TERMINAL_NOTIFY", "osc9")

	input := fmt.Sprintf(`{
		"teammate_name": "worker-1",
		"task_id": "T1",
		"task_subject": "implement feature",
		"cwd": "%s"
	}`, dir)

	var out bytes.Buffer
	err := HandleTaskCompleted(strings.NewReader(input), &out)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	var resp map[string]interface{}
	if err := json.NewDecoder(&out).Decode(&resp); err != nil {
		t.Fatalf("invalid JSON: %v", err)
	}
	if resp["decision"] != "approve" {
		t.Errorf("want approve, got %v", resp["decision"])
	}
	seq, ok := resp["terminalSequence"].(string)
	if !ok || seq == "" {
		t.Fatalf("expected non-empty terminalSequence, got %v (type %T)", resp["terminalSequence"], resp["terminalSequence"])
	}
	// OSC 9 sequence (ESC ]9; <text> BEL)
	if !strings.HasPrefix(seq, "\x1b]9;") || !strings.HasSuffix(seq, "\x07") {
		t.Errorf("terminalSequence not OSC 9 shape: %q", seq)
	}
}

// TestHandleTaskCompleted_NoTerminalSequence_WhenEnvUnset verifies that terminalSequence is not
// added when HARNESS_TERMINAL_NOTIFY is unset (preserving existing behavior).
func TestHandleTaskCompleted_NoTerminalSequence_WhenEnvUnset(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("HARNESS_TERMINAL_NOTIFY", "")

	input := fmt.Sprintf(`{
		"teammate_name": "worker-1",
		"task_id": "T1",
		"task_subject": "implement",
		"cwd": "%s"
	}`, dir)

	var out bytes.Buffer
	err := HandleTaskCompleted(strings.NewReader(input), &out)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	var resp map[string]interface{}
	if err := json.NewDecoder(&out).Decode(&resp); err != nil {
		t.Fatalf("invalid JSON: %v", err)
	}
	if _, has := resp["terminalSequence"]; has {
		t.Errorf("env unset should NOT add terminalSequence, got: %+v", resp)
	}
}

// --- appendTimeline ---

func TestAppendTimeline_CreatesFile(t *testing.T) {
	h, _ := setupTaskCompletedHandler(t)
	h.appendTimeline(timelineEntry{
		Event:     "task_completed",
		Teammate:  "worker",
		TaskID:    "T1",
		Subject:   "test task",
		Timestamp: "2026-01-01T00:00:00Z",
	})

	data, err := os.ReadFile(h.timelineFile)
	if err != nil {
		t.Fatalf("timeline file not created: %v", err)
	}
	var entry timelineEntry
	if err := json.Unmarshal(bytes.TrimSpace(data), &entry); err != nil {
		t.Fatalf("invalid JSON: %v", err)
	}
	if entry.TaskID != "T1" {
		t.Errorf("want T1, got %q", entry.TaskID)
	}
}

func TestRotateJSONLFile(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "test.jsonl")

	// Write 550 lines
	f, _ := os.Create(path)
	for i := range 550 {
		fmt.Fprintf(f, `{"n":%d}`+"\n", i)
	}
	f.Close()

	_ = rotateJSONL(path, 500, 400)

	content, _ := os.ReadFile(path)
	lines := strings.Split(strings.TrimSpace(string(content)), "\n")
	if len(lines) != 400 {
		t.Errorf("want 400 lines, got %d", len(lines))
	}
	// Last line should be the original 549th entry
	var last map[string]int
	if err := json.Unmarshal([]byte(lines[len(lines)-1]), &last); err != nil {
		t.Fatalf("invalid JSON in last line: %v", err)
	}
	if last["n"] != 549 {
		t.Errorf("want n=549, got %d", last["n"])
	}
}

func TestRotateJSONLFile_NoRotationNeeded(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "test.jsonl")

	f, _ := os.Create(path)
	for i := range 100 {
		fmt.Fprintf(f, `{"n":%d}`+"\n", i)
	}
	f.Close()

	_ = rotateJSONL(path, 500, 400)

	content, _ := os.ReadFile(path)
	lines := strings.Split(strings.TrimSpace(string(content)), "\n")
	if len(lines) != 100 {
		t.Errorf("want 100 lines, got %d", len(lines))
	}
}

// --- countCompleted ---

func TestCountCompleted(t *testing.T) {
	h, _ := setupTaskCompletedHandler(t)

	// Record 2 tasks to the timeline
	for _, id := range []string{"T1", "T2"} {
		h.appendTimeline(timelineEntry{
			Event:     "task_completed",
			TaskID:    id,
			Timestamp: "2026-01-01T00:00:00Z",
		})
	}
	// T3 is not yet complete

	count := h.countCompleted([]string{"T1", "T2", "T3"})
	if count != 2 {
		t.Errorf("want 2, got %d", count)
	}
}

func TestCountCompleted_NoDuplication(t *testing.T) {
	h, _ := setupTaskCompletedHandler(t)

	// Record the same task twice
	for range 2 {
		h.appendTimeline(timelineEntry{
			Event:     "task_completed",
			TaskID:    "T1",
			Timestamp: "2026-01-01T00:00:00Z",
		})
	}

	// Should count only once even for the same ID
	count := h.countCompleted([]string{"T1"})
	if count != 1 {
		t.Errorf("want 1 (dedup), got %d", count)
	}
}

// --- signalExists / appendSignal ---

func TestSignalExists_NotFound(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "signals.jsonl")
	if signalExists(path, "partial_review_recommended", "sess1") {
		t.Error("want false for non-existent file")
	}
}

func TestSignalExists_Found(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "signals.jsonl")
	appendSignal(path, signalEntry{
		Signal:    "partial_review_recommended",
		SessionID: "sess1",
		Completed: "5",
		Total:     "10",
		Timestamp: "2026-01-01T00:00:00Z",
	})
	if !signalExists(path, "partial_review_recommended", "sess1") {
		t.Error("want true")
	}
}

func TestSignalExists_DifferentSession(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "signals.jsonl")
	appendSignal(path, signalEntry{
		Signal:    "partial_review_recommended",
		SessionID: "sess1",
		Completed: "5",
		Total:     "10",
		Timestamp: "2026-01-01T00:00:00Z",
	})
	// sess2 is a different session → not found
	if signalExists(path, "partial_review_recommended", "sess2") {
		t.Error("want false for different session")
	}
}

// --- buildFixTaskID ---

func TestBuildFixTaskID(t *testing.T) {
	cases := []struct {
		input string
		want  string
	}{
		{"26.1", "26.1.fix"},
		{"26.1.fix", "26.1.fix2"},
		{"26.1.fix2", "26.1.fix3"},
		{"26.1.fix10", "26.1.fix11"},
	}
	for _, tc := range cases {
		got := buildFixTaskID(tc.input)
		if got != tc.want {
			t.Errorf("buildFixTaskID(%q) = %q, want %q", tc.input, got, tc.want)
		}
	}
}

// --- classifyFailure ---

func TestClassifyFailure(t *testing.T) {
	cases := []struct {
		output  string
		wantCat string
	}{
		{"SyntaxError: unexpected token", "syntax_error"},
		{"cannot find module 'foo'", "import_error"},
		{"TypeError: is not assignable to type", "type_error"},
		{"AssertionError: expected 1 to equal 2", "assertion_error"},
		{"timeout after 30000ms", "timeout"},
		{"EACCES: permission denied", "permission_error"},
		{"some unknown error occurred", "runtime_error"},
	}
	for _, tc := range cases {
		cat, _ := classifyFailure(tc.output)
		if cat != tc.wantCat {
			t.Errorf("classifyFailure(%q) category = %q, want %q", tc.output, cat, tc.wantCat)
		}
	}
}

// --- updateFailureCount ---

func TestUpdateFailureCount_IncrementAndReset(t *testing.T) {
	h, _ := setupTaskCompletedHandler(t)
	ts := "2026-01-01T00:00:00Z"

	count1 := h.updateFailureCount("T1", "increment", ts)
	if count1 != 1 {
		t.Errorf("want 1, got %d", count1)
	}

	count2 := h.updateFailureCount("T1", "increment", ts)
	if count2 != 2 {
		t.Errorf("want 2, got %d", count2)
	}

	count3 := h.updateFailureCount("T1", "reset", ts)
	if count3 != 0 {
		t.Errorf("want 0 after reset, got %d", count3)
	}
}

// --- upsertFixProposal ---

func TestUpsertFixProposal_CreateAndUpdate(t *testing.T) {
	h, _ := setupTaskCompletedHandler(t)

	proposal := fixProposal{
		SourceTaskID:    "T1",
		FixTaskID:       "T1.fix",
		ProposalSubject: "fix: T1 - assertion_error",
		Status:          "pending",
	}
	if !h.upsertFixProposal(proposal) {
		t.Fatal("want true")
	}

	// Update with the same source_task_id
	proposal2 := fixProposal{
		SourceTaskID:    "T1",
		FixTaskID:       "T1.fix2",
		ProposalSubject: "fix: T1 - runtime_error",
		Status:          "pending",
	}
	if !h.upsertFixProposal(proposal2) {
		t.Fatal("want true")
	}

	// Only the most recent entry should exist in the file
	data, err := os.ReadFile(h.pendingFixFile)
	if err != nil {
		t.Fatalf("read: %v", err)
	}
	lines := strings.Split(strings.TrimSpace(string(data)), "\n")
	if len(lines) != 1 {
		t.Errorf("want 1 line, got %d", len(lines))
	}
	var got fixProposal
	if err := json.Unmarshal([]byte(lines[0]), &got); err != nil {
		t.Fatalf("invalid JSON: %v", err)
	}
	if got.FixTaskID != "T1.fix2" {
		t.Errorf("want T1.fix2, got %q", got.FixTaskID)
	}
}

// --- sanitizeInlineText ---

func TestSanitizeInlineText(t *testing.T) {
	input := "hello\nworld|foo  bar"
	got := sanitizeInlineText(input)
	if strings.Contains(got, "\n") || strings.Contains(got, "|") {
		t.Errorf("sanitizeInlineText failed: %q", got)
	}
}

// --- finalizeMarkerExistsForSession ---

func TestFinalizeMarkerExistsForSession(t *testing.T) {
	h, _ := setupTaskCompletedHandler(t)

	// No marker → false
	if h.finalizeMarkerExistsForSession("sess1") {
		t.Error("want false (no marker)")
	}

	// Write marker
	h.writeFinalizeMarker("sess1", "my-project", "2026-01-01T00:00:00Z")

	// Correct session → true
	if !h.finalizeMarkerExistsForSession("sess1") {
		t.Error("want true")
	}

	// Different session → false
	if h.finalizeMarkerExistsForSession("sess2") {
		t.Error("want false (different session)")
	}
}

// --- lastPathComponent ---

func TestLastPathComponent(t *testing.T) {
	cases := []struct {
		input string
		want  string
	}{
		{"/home/user/project", "project"},
		{"/home/user/project/", "project"},
		{"project", "project"},
		{"/", ""},
	}
	for _, tc := range cases {
		got := lastPathComponent(tc.input)
		if got != tc.want {
			t.Errorf("lastPathComponent(%q) = %q, want %q", tc.input, got, tc.want)
		}
	}
}

// TestWriteFinalizeMarker_StateDirSymlink verifies that writeFinalizeMarker
// refuses to write when stateDir is a symbolic link.
func TestWriteFinalizeMarker_StateDirSymlink(t *testing.T) {
	dir := t.TempDir()

	// The actual directory that will serve as stateDir
	realStateDir := filepath.Join(dir, "real-state")
	if err := os.MkdirAll(realStateDir, 0o700); err != nil {
		t.Fatal(err)
	}

	// Create a symbolic link pointing to stateDir
	symlinkStateDir := filepath.Join(dir, "symlink-state")
	if err := os.Symlink(realStateDir, symlinkStateDir); err != nil {
		t.Skip("symlink creation not supported on this platform")
	}

	finalizeMarker := filepath.Join(symlinkStateDir, "finalize-marker.json")
	h := &taskCompletedHandler{
		stateDir:       symlinkStateDir,
		finalizeMarker: finalizeMarker,
		projectRoot:    dir,
	}

	// stateDir is a symlink → writeFinalizeMarker should not write anything
	h.writeFinalizeMarker("sess1", "my-project", "2026-01-01T00:00:00Z")

	if _, err := os.Stat(finalizeMarker); err == nil {
		t.Error("writeFinalizeMarker should not write when stateDir is a symlink")
	}
}
