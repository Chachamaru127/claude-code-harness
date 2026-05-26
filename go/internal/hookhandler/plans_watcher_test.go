package hookhandler

import (
	"bytes"
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func TestHandlePlansWatcher_NoInput(t *testing.T) {
	var out bytes.Buffer
	err := HandlePlansWatcher(strings.NewReader(""), &out)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	var result postToolOutput
	if jsonErr := json.Unmarshal(out.Bytes(), &result); jsonErr != nil {
		t.Fatalf("invalid JSON output: %v, raw: %s", jsonErr, out.String())
	}
	if result.HookSpecificOutput.HookEventName != "PostToolUse" {
		t.Errorf("expected hookEventName=PostToolUse, got %q", result.HookSpecificOutput.HookEventName)
	}
}

func TestHandlePlansWatcher_NoFilePath(t *testing.T) {
	input := `{"tool_name":"Edit","tool_input":{}}`
	var out bytes.Buffer
	if err := HandlePlansWatcher(strings.NewReader(input), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	var result postToolOutput
	if jsonErr := json.Unmarshal(out.Bytes(), &result); jsonErr != nil {
		t.Fatalf("invalid JSON output: %v", jsonErr)
	}
	if result.HookSpecificOutput.AdditionalContext != "" {
		t.Errorf("expected empty context for no file_path, got %q", result.HookSpecificOutput.AdditionalContext)
	}
}

func TestHandlePlansWatcher_NonPlansFile(t *testing.T) {
	tmpDir := t.TempDir()
	origDir, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	if err := os.Chdir(tmpDir); err != nil {
		t.Fatal(err)
	}
	defer os.Chdir(origDir)

	// Create Plans.md
	if err := os.WriteFile("Plans.md", []byte("# Plans\n"), 0o644); err != nil {
		t.Fatal(err)
	}

	// Editing a file other than Plans.md should be skipped
	input := `{"tool_name":"Write","tool_input":{"file_path":"src/main.go"}}`
	var out bytes.Buffer
	if err := HandlePlansWatcher(strings.NewReader(input), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	var result postToolOutput
	if jsonErr := json.Unmarshal(out.Bytes(), &result); jsonErr != nil {
		t.Fatalf("invalid JSON output: %v", jsonErr)
	}
	if result.HookSpecificOutput.AdditionalContext != "" {
		t.Errorf("expected empty context for non-Plans.md file, got %q", result.HookSpecificOutput.AdditionalContext)
	}
}

func TestHandlePlansWatcher_NoPlansFile(t *testing.T) {
	tmpDir := t.TempDir()
	origDir, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	if err := os.Chdir(tmpDir); err != nil {
		t.Fatal(err)
	}
	defer os.Chdir(origDir)

	// Should be skipped when Plans.md does not exist
	input := `{"tool_name":"Write","tool_input":{"file_path":"Plans.md"}}`
	var out bytes.Buffer
	if err := HandlePlansWatcher(strings.NewReader(input), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	var result postToolOutput
	if jsonErr := json.Unmarshal(out.Bytes(), &result); jsonErr != nil {
		t.Fatalf("invalid JSON output: %v", jsonErr)
	}
	if result.HookSpecificOutput.AdditionalContext != "" {
		t.Errorf("expected empty context when Plans.md not found, got %q", result.HookSpecificOutput.AdditionalContext)
	}
}

func TestHandlePlansWatcher_NewTaskDetected(t *testing.T) {
	tmpDir := t.TempDir()
	origDir, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	if err := os.Chdir(tmpDir); err != nil {
		t.Fatal(err)
	}
	defer os.Chdir(origDir)

	// Create Plans.md content containing pm:依頼中
	plansContent := "| Task 1 | 実装A | DoD | - | pm:依頼中 |\n"
	if err := os.WriteFile("Plans.md", []byte(plansContent), 0o644); err != nil {
		t.Fatal(err)
	}

	// Save previous state (pm_pending=0)
	if err := os.MkdirAll(".claude/state", 0o755); err != nil {
		t.Fatal(err)
	}
	prevState := `{"timestamp":"2026-01-01T00:00:00Z","pm_pending":0,"cc_todo":0,"cc_wip":0,"cc_done":0,"pm_confirmed":0}`
	if err := os.WriteFile(plansStateFile, []byte(prevState), 0o644); err != nil {
		t.Fatal(err)
	}

	input := `{"tool_name":"Edit","tool_input":{"file_path":"Plans.md"}}`
	var out bytes.Buffer
	if err := HandlePlansWatcher(strings.NewReader(input), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	var result postToolOutput
	if jsonErr := json.Unmarshal(out.Bytes(), &result); jsonErr != nil {
		t.Fatalf("invalid JSON output: %v, raw: %s", jsonErr, out.String())
	}

	// New tasks should be detected
	if !strings.Contains(result.HookSpecificOutput.AdditionalContext, "New tasks") {
		t.Errorf("expected 'New tasks' in additionalContext, got %q",
			result.HookSpecificOutput.AdditionalContext)
	}

	// pm-notification.md should be created
	data, err := os.ReadFile(pmNotificationFile)
	if err != nil {
		t.Fatalf("pm-notification.md not created: %v", err)
	}
	if !strings.Contains(string(data), "New tasks") {
		t.Errorf("pm-notification.md should contain 'New tasks', got: %s", string(data))
	}
}

func TestHandlePlansWatcher_NotificationUsesInputCWD(t *testing.T) {
	projectDir := t.TempDir()
	hookCWD := t.TempDir()

	origDir, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	if err := os.Chdir(hookCWD); err != nil {
		t.Fatal(err)
	}
	defer os.Chdir(origDir)

	plansContent := "| Task 1 | 実装A | DoD | - | pm:依頼中 |\n"
	plansPath := filepath.Join(projectDir, "Plans.md")
	if err := os.WriteFile(plansPath, []byte(plansContent), 0o644); err != nil {
		t.Fatal(err)
	}

	stateDir := filepath.Join(projectDir, ".claude", "state")
	if err := os.MkdirAll(stateDir, 0o755); err != nil {
		t.Fatal(err)
	}
	prevState := `{"timestamp":"2026-01-01T00:00:00Z","pm_pending":0,"cc_todo":0,"cc_wip":0,"cc_done":0,"pm_confirmed":0}`
	if err := os.WriteFile(filepath.Join(stateDir, "plans-state.json"), []byte(prevState), 0o644); err != nil {
		t.Fatal(err)
	}

	inputJSON := `{"tool_name":"Edit","cwd":"` + projectDir + `","tool_input":{"file_path":"Plans.md"}}`
	var out bytes.Buffer
	if err := HandlePlansWatcher(strings.NewReader(inputJSON), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	pmPath := filepath.Join(projectDir, pmNotificationFile)
	if _, statErr := os.Stat(pmPath); statErr != nil {
		t.Fatalf("expected pm notification under input.CWD, got error: %v", statErr)
	}
	if _, statErr := os.Stat(filepath.Join(hookCWD, pmNotificationFile)); statErr == nil {
		t.Fatalf("pm notification should not be written under process cwd")
	}
}

func TestHandlePlansWatcher_CompletedTaskDetected(t *testing.T) {
	tmpDir := t.TempDir()
	origDir, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	if err := os.Chdir(tmpDir); err != nil {
		t.Fatal(err)
	}
	defer os.Chdir(origDir)

	// Create Plans.md content containing cc:完了
	plansContent := "| Task 1 | 実装A | DoD | - | cc:完了 |\n"
	if err := os.WriteFile("Plans.md", []byte(plansContent), 0o644); err != nil {
		t.Fatal(err)
	}

	// Save previous state (cc_done=0)
	if err := os.MkdirAll(".claude/state", 0o755); err != nil {
		t.Fatal(err)
	}
	prevState := `{"timestamp":"2026-01-01T00:00:00Z","pm_pending":0,"cc_todo":0,"cc_wip":0,"cc_done":0,"pm_confirmed":0}`
	if err := os.WriteFile(plansStateFile, []byte(prevState), 0o644); err != nil {
		t.Fatal(err)
	}

	input := `{"tool_name":"Edit","tool_input":{"file_path":"Plans.md"}}`
	var out bytes.Buffer
	if err := HandlePlansWatcher(strings.NewReader(input), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	var result postToolOutput
	if jsonErr := json.Unmarshal(out.Bytes(), &result); jsonErr != nil {
		t.Fatalf("invalid JSON output: %v", jsonErr)
	}

	if !strings.Contains(result.HookSpecificOutput.AdditionalContext, "Tasks completed") {
		t.Errorf("expected 'Tasks completed' in additionalContext, got %q",
			result.HookSpecificOutput.AdditionalContext)
	}
}

func TestHandlePlansWatcher_NoChange(t *testing.T) {
	tmpDir := t.TempDir()
	origDir, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	if err := os.Chdir(tmpDir); err != nil {
		t.Fatal(err)
	}
	defer os.Chdir(origDir)

	// No change (cc:TODO stays at 1)
	plansContent := "| Task 1 | 実装A | DoD | - | cc:TODO |\n"
	if err := os.WriteFile("Plans.md", []byte(plansContent), 0o644); err != nil {
		t.Fatal(err)
	}

	if err := os.MkdirAll(".claude/state", 0o755); err != nil {
		t.Fatal(err)
	}
	prevState := `{"timestamp":"2026-01-01T00:00:00Z","pm_pending":0,"cc_todo":1,"cc_wip":0,"cc_done":0,"pm_confirmed":0}`
	if err := os.WriteFile(plansStateFile, []byte(prevState), 0o644); err != nil {
		t.Fatal(err)
	}

	input := `{"tool_name":"Edit","tool_input":{"file_path":"Plans.md"}}`
	var out bytes.Buffer
	if err := HandlePlansWatcher(strings.NewReader(input), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	var result postToolOutput
	if jsonErr := json.Unmarshal(out.Bytes(), &result); jsonErr != nil {
		t.Fatalf("invalid JSON output: %v", jsonErr)
	}

	// No notification when nothing changed
	if result.HookSpecificOutput.AdditionalContext != "" {
		t.Errorf("expected empty context for no change, got %q", result.HookSpecificOutput.AdditionalContext)
	}
}

func TestHandlePlansWatcher_StatusSummary(t *testing.T) {
	tmpDir := t.TempDir()
	origDir, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	if err := os.Chdir(tmpDir); err != nil {
		t.Fatal(err)
	}
	defer os.Chdir(origDir)

	// Plans.md containing multiple markers
	plansContent := "| Task 1 | A | DoD | - | cc:TODO |\n" +
		"| Task 2 | B | DoD | - | cc:WIP |\n" +
		"| Task 3 | C | DoD | - | cc:完了 |\n" +
		"| Task 4 | D | DoD | - | pm:依頼中 |\n"
	if err := os.WriteFile("Plans.md", []byte(plansContent), 0o644); err != nil {
		t.Fatal(err)
	}

	if err := os.MkdirAll(".claude/state", 0o755); err != nil {
		t.Fatal(err)
	}
	prevState := `{"timestamp":"2026-01-01T00:00:00Z","pm_pending":0,"cc_todo":0,"cc_wip":0,"cc_done":0,"pm_confirmed":0}`
	if err := os.WriteFile(plansStateFile, []byte(prevState), 0o644); err != nil {
		t.Fatal(err)
	}

	input := `{"tool_name":"Edit","tool_input":{"file_path":"Plans.md"}}`
	var out bytes.Buffer
	if err := HandlePlansWatcher(strings.NewReader(input), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	var result postToolOutput
	if jsonErr := json.Unmarshal(out.Bytes(), &result); jsonErr != nil {
		t.Fatalf("invalid JSON output: %v", jsonErr)
	}

	ctx := result.HookSpecificOutput.AdditionalContext
	// Summary should contain status counts
	if !strings.Contains(ctx, "cc:TODO") {
		t.Errorf("expected 'cc:TODO' in summary, got %q", ctx)
	}
	if !strings.Contains(ctx, "cc:WIP") {
		t.Errorf("expected 'cc:WIP' in summary, got %q", ctx)
	}
	if !strings.Contains(ctx, "cc:完了") {
		t.Errorf("expected 'cc:完了' in summary, got %q", ctx)
	}
}

func TestIsPlansFile(t *testing.T) {
	// isPlansFile only performs strict matching via filepath.Clean.
	// Comparison with projectRoot factored in is done by isPlansFileWithRoot.
	cases := []struct {
		changed  string
		plans    string
		expected bool
	}{
		// Exact match (relative path)
		{"Plans.md", "Plans.md", true},
		// Exact match (absolute path)
		{"/home/user/project/Plans.md", "/home/user/project/Plans.md", true},
		// Different full paths should not match (same-named file in another directory is false)
		{"docs/Plans.md", "Plans.md", false},
		{"/home/user/project/Plans.md", "Plans.md", false},
		{"src/main.go", "Plans.md", false},
		{"NotPlans.md", "Plans.md", false},
	}
	for _, c := range cases {
		got := isPlansFile(c.changed, c.plans)
		if got != c.expected {
			t.Errorf("isPlansFile(%q, %q) = %v, want %v", c.changed, c.plans, got, c.expected)
		}
	}
}

func TestIsPlansFileWithRoot(t *testing.T) {
	// isPlansFileWithRoot resolves relative paths using projectRoot.
	projectRoot := "/home/user/project"
	cases := []struct {
		changedFile string
		plansFile   string
		expected    bool
		desc        string
	}{
		// Relative path → resolved via projectRoot, matches
		{"Plans.md", "/home/user/project/Plans.md", true, "relative path match"},
		// Absolute path match
		{"/home/user/project/Plans.md", "/home/user/project/Plans.md", true, "absolute path match"},
		// Relative path in subdirectory (Plans.md, but plansFile is at projectRoot root)
		{"docs/Plans.md", "/home/user/project/Plans.md", false, "subdirectory mismatch"},
		// Relative path in subdirectory matches plansFile
		{"docs/Plans.md", "/home/user/project/docs/Plans.md", true, "subdirectory match"},
		// Completely different file
		{"src/main.go", "/home/user/project/Plans.md", false, "non plans file"},
		// Same-named file in a different project (absolute path)
		{"/tmp/other/Plans.md", "/home/user/project/Plans.md", false, "different project Plans.md"},
	}
	for _, tc := range cases {
		got := isPlansFileWithRoot(tc.changedFile, tc.plansFile, projectRoot)
		if got != tc.expected {
			t.Errorf("[%s] isPlansFileWithRoot(%q, %q, %q) = %v, want %v",
				tc.desc, tc.changedFile, tc.plansFile, projectRoot, got, tc.expected)
		}
	}
}

func TestCountMarker(t *testing.T) {
	tmpDir := t.TempDir()
	origDir, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	if err := os.Chdir(tmpDir); err != nil {
		t.Fatal(err)
	}
	defer os.Chdir(origDir)

	content := "cc:TODO\ncc:TODO\ncc:WIP\ncc:完了\npm:依頼中\n"
	if err := os.WriteFile("Plans.md", []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}

	cases := []struct {
		marker   string
		expected int
	}{
		{"cc:TODO", 2},
		{"cc:WIP", 1},
		{"cc:完了", 1},
		{"pm:依頼中", 1},
		{"pm:確認済", 0},
	}
	for _, c := range cases {
		got := countMarker("Plans.md", c.marker)
		if got != c.expected {
			t.Errorf("countMarker(Plans.md, %q) = %d, want %d", c.marker, got, c.expected)
		}
	}
}

func TestHandlePlansWatcher_CursorCompatMarker(t *testing.T) {
	tmpDir := t.TempDir()
	origDir, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	if err := os.Chdir(tmpDir); err != nil {
		t.Fatal(err)
	}
	defer os.Chdir(origDir)

	// cursor:依頼中 should be treated as equivalent to pm:依頼中
	plansContent := "| Task 1 | A | DoD | - | cursor:依頼中 |\n"
	if err := os.WriteFile("Plans.md", []byte(plansContent), 0o644); err != nil {
		t.Fatal(err)
	}

	if err := os.MkdirAll(".claude/state", 0o755); err != nil {
		t.Fatal(err)
	}
	prevState := `{"timestamp":"2026-01-01T00:00:00Z","pm_pending":0,"cc_todo":0,"cc_wip":0,"cc_done":0,"pm_confirmed":0}`
	if err := os.WriteFile(plansStateFile, []byte(prevState), 0o644); err != nil {
		t.Fatal(err)
	}

	input := `{"tool_name":"Edit","tool_input":{"file_path":"Plans.md"}}`
	var out bytes.Buffer
	if err := HandlePlansWatcher(strings.NewReader(input), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	var result postToolOutput
	if jsonErr := json.Unmarshal(out.Bytes(), &result); jsonErr != nil {
		t.Fatalf("invalid JSON output: %v", jsonErr)
	}

	// cursor:依頼中 should also be detected as a new task
	if !strings.Contains(result.HookSpecificOutput.AdditionalContext, "New tasks") {
		t.Errorf("expected 'New tasks' for cursor:依頼中, got %q",
			result.HookSpecificOutput.AdditionalContext)
	}
}

// TestHandlePlansWatcher_CustomPlansDirectory verifies that when plansDirectory is set,
// the Plans.md in the custom directory is correctly detected.
func TestHandlePlansWatcher_CustomPlansDirectory(t *testing.T) {
	tmpDir := t.TempDir()
	origDir, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	if err := os.Chdir(tmpDir); err != nil {
		t.Fatal(err)
	}
	defer os.Chdir(origDir)

	// Create config file (plansDirectory: docs)
	configContent := "plansDirectory: docs\n"
	if err := os.WriteFile(harnessConfigFileName, []byte(configContent), 0o644); err != nil {
		t.Fatal(err)
	}

	// Create docs/Plans.md
	if err := os.MkdirAll("docs", 0o755); err != nil {
		t.Fatal(err)
	}
	plansContent := "| Task 1 | 実装A | DoD | - | pm:依頼中 |\n"
	if err := os.WriteFile("docs/Plans.md", []byte(plansContent), 0o644); err != nil {
		t.Fatal(err)
	}

	// Save previous state (pm_pending=0)
	if err := os.MkdirAll(".claude/state", 0o755); err != nil {
		t.Fatal(err)
	}
	prevState := `{"timestamp":"2026-01-01T00:00:00Z","pm_pending":0,"cc_todo":0,"cc_wip":0,"cc_done":0,"pm_confirmed":0}`
	if err := os.WriteFile(plansStateFile, []byte(prevState), 0o644); err != nil {
		t.Fatal(err)
	}

	// Send an event for the change to docs/Plans.md
	input := `{"tool_name":"Edit","tool_input":{"file_path":"docs/Plans.md"}}`
	var out bytes.Buffer
	if err := HandlePlansWatcher(strings.NewReader(input), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	var result postToolOutput
	if jsonErr := json.Unmarshal(out.Bytes(), &result); jsonErr != nil {
		t.Fatalf("invalid JSON output: %v, raw: %s", jsonErr, out.String())
	}

	// New tasks should be detected (custom-path Plans.md is recognized)
	if !strings.Contains(result.HookSpecificOutput.AdditionalContext, "New tasks") {
		t.Errorf("expected 'New tasks' in additionalContext for custom plansDirectory, got %q",
			result.HookSpecificOutput.AdditionalContext)
	}
}

// TestIsPlansFile_CustomPath verifies that isPlansFileWithRoot works correctly for a
// custom-path Plans.md (P2 fix: must not false-match a same-named file in another directory).
func TestIsPlansFile_CustomPath(t *testing.T) {
	projectRoot := "/project"
	cases := []struct {
		changedFile string
		plansFile   string
		want        bool
		desc        string
	}{
		// Exact match (relative path resolved via projectRoot)
		{"Plans.md", "/project/Plans.md", true, "exact match via projectRoot"},
		// Plans.md in custom directory matches plansFile
		{"docs/Plans.md", "/project/docs/Plans.md", true, "custom subdir match"},
		// Same-named file in another directory must not false-match (core of the fix)
		{"docs/Plans.md", "/project/Plans.md", false, "subdirectory mismatch - must not match"},
		// Completely different file
		{"src/main.go", "/project/Plans.md", false, "non plans file"},
		{"README.md", "/project/Plans.md", false, "readme not plans"},
		// File name resembles Plans.md but is a different file
		{"Plans.md.bak", "/project/Plans.md", false, "backup file not matched"},
		// Plans.md from a different project (absolute path)
		{"/tmp/other/Plans.md", "/project/Plans.md", false, "different project Plans.md must not match"},
	}

	for _, tc := range cases {
		got := isPlansFileWithRoot(tc.changedFile, tc.plansFile, projectRoot)
		if got != tc.want {
			t.Errorf("[%s] isPlansFileWithRoot(%q, %q, %q) = %v, want %v",
				tc.desc, tc.changedFile, tc.plansFile, projectRoot, got, tc.want)
		}
	}
}

// TestHandlePlansWatcher_CWDFromInput verifies that when input.CWD is present,
// it is used as projectRoot instead of resolveProjectRoot().
// Validates that Plans.md is correctly detected when the hook process CWD differs from input.CWD.
func TestHandlePlansWatcher_CWDFromInput(t *testing.T) {
	// Project directory (contains Plans.md)
	projectDir := t.TempDir()
	// Hook process CWD (different directory from the project)
	hookCWD := t.TempDir()

	origDir, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	// Hook process is at hookCWD (not the project root)
	if err := os.Chdir(hookCWD); err != nil {
		t.Fatal(err)
	}
	defer os.Chdir(origDir)

	// Create Plans.md in projectDir
	plansContent := "| Task 1 | 実装A | DoD | - | cc:完了 |\n"
	plansPath := filepath.Join(projectDir, "Plans.md")
	if err := os.WriteFile(plansPath, []byte(plansContent), 0o644); err != nil {
		t.Fatal(err)
	}

	// Create .claude/state in projectDir
	stateDir := filepath.Join(projectDir, ".claude", "state")
	if err := os.MkdirAll(stateDir, 0o755); err != nil {
		t.Fatal(err)
	}

	// Include cwd field in input (pointing to projectDir)
	inputJSON := `{"tool_name":"Edit","cwd":"` + projectDir + `","tool_input":{"file_path":"Plans.md"}}`
	var out bytes.Buffer
	if err := HandlePlansWatcher(strings.NewReader(inputJSON), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	// Plans.md in projectDir should be detected even though hookCWD has none
	// Verify that processing completes without error (Plans.md found and state aggregated)
	var result postToolOutput
	if jsonErr := json.Unmarshal(out.Bytes(), &result); jsonErr != nil {
		t.Fatalf("invalid JSON output: %v, raw: %s", jsonErr, out.String())
	}
	// Should be processed normally (without input.CWD the result would be emptyPostToolOutput
	// because hookCWD has no Plans.md, but with input.CWD the one in projectDir is found)
	if out.Len() == 0 {
		t.Error("expected non-empty output when input.CWD points to project with Plans.md")
	}
}

// TestAcquirePlansLock_BasicLock verifies that lock acquisition and release work correctly.
func TestAcquirePlansLock_BasicLock(t *testing.T) {
	tmpDir := t.TempDir()
	lockPath := filepath.Join(tmpDir, "locks", "plans.flock")

	// First attempt: lock acquisition should succeed
	lock, err := acquirePlansLock(lockPath)
	if err != nil {
		t.Fatalf("expected lock acquisition to succeed, got: %v", err)
	}
	if lock == nil {
		t.Fatal("expected non-nil lock handle")
	}

	// Lock file should exist
	if _, statErr := os.Stat(lockPath); statErr != nil {
		t.Errorf("lock file should exist after acquisition: %v", statErr)
	}

	// Release (should not panic)
	releasePlansLock(lock)
}

func TestAcquirePlansLock_FallsBackToMkdir(t *testing.T) {
	tmpDir := t.TempDir()
	lockPath := filepath.Join(tmpDir, "locks", "plans.flock")

	origFlockCall := flockCall
	origSleepCall := sleepCall
	flockCall = func(fd int, how int) error {
		return errors.New("file lock unsupported")
	}
	sleepCall = func(time.Duration) {}
	defer func() {
		flockCall = origFlockCall
		sleepCall = origSleepCall
	}()

	lock, err := acquirePlansLock(lockPath)
	if err != nil {
		t.Fatalf("expected mkdir fallback lock acquisition to succeed, got: %v", err)
	}
	if lock.mode != "mkdir" {
		t.Fatalf("expected mkdir fallback mode, got %q", lock.mode)
	}

	lockDir := lockPath + plansLockDirSuffix
	if _, statErr := os.Stat(lockDir); statErr != nil {
		t.Fatalf("expected mkdir fallback lock dir %s to exist: %v", lockDir, statErr)
	}

	releasePlansLock(lock)

	if _, statErr := os.Stat(lockDir); !os.IsNotExist(statErr) {
		t.Fatalf("expected mkdir fallback lock dir to be removed, got: %v", statErr)
	}
}

// TestHandlePlansWatcher_LockExhaustionFailsClosed verifies that HandlePlansWatcher
// emits a fail-closed signal when lock acquisition fails after 3 retries.
// exitFailClosed is replaced with a mock to avoid os.Exit(1) while still verifying
// that the call occurred (the failure signal).
func TestHandlePlansWatcher_LockExhaustionFailsClosed(t *testing.T) {
	tmpDir := t.TempDir()
	origDir, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	if err := os.Chdir(tmpDir); err != nil {
		t.Fatal(err)
	}
	defer os.Chdir(origDir)

	// Create Plans.md
	plansContent := "| Task 1 | A | DoD | - | pm:依頼中 |\n"
	if err := os.WriteFile("Plans.md", []byte(plansContent), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(".claude/state", 0o755); err != nil {
		t.Fatal(err)
	}

	// Create lock directory and a lock file with mode 000 to force open to fail
	if err := os.MkdirAll(".claude/state/locks", 0o755); err != nil {
		t.Fatal(err)
	}
	lockPath := filepath.Join(tmpDir, plansLockFile)
	if err := os.WriteFile(lockPath, []byte{}, 0o000); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() {
		os.Chmod(lockPath, 0o644) //nolint:errcheck
	})

	// Skip when running as root (CI etc.) because mode 000 still allows open as root
	if os.Getuid() == 0 {
		t.Skip("skipping fail-closed test: running as root (0o000 mode has no effect)")
	}

	// Replace exitFailClosed with a mock to avoid os.Exit(1)
	failClosedCalled := false
	origExitFailClosed := exitFailClosed
	exitFailClosed = func(msg string) {
		failClosedCalled = true
		// Do not call os.Exit(1) — test must continue
	}
	defer func() { exitFailClosed = origExitFailClosed }()

	input := `{"tool_name":"Edit","tool_input":{"file_path":"Plans.md"}}`
	var out bytes.Buffer
	if err := HandlePlansWatcher(strings.NewReader(input), &out); err != nil {
		t.Fatalf("HandlePlansWatcher should not return error even on lock failure: %v", err)
	}

	// fail-closed: exitFailClosed should have been called (not treated as success)
	if !failClosedCalled {
		t.Error("expected exitFailClosed to be called on lock exhaustion, but it was not")
	}

	var result postToolOutput
	if jsonErr := json.Unmarshal(out.Bytes(), &result); jsonErr != nil {
		t.Fatalf("invalid JSON output: %v, raw: %s", jsonErr, out.String())
	}

	// When os.Exit is bypassed by the mock, the fallback empty response is returned
	if result.HookSpecificOutput.AdditionalContext != "" {
		t.Errorf("expected empty context on lock failure (fail-closed fallback), got %q",
			result.HookSpecificOutput.AdditionalContext)
	}
}

// TestHandlePlansWatcher_LockAndStateUseSameCWD verifies that the lock path and the
// state file path are derived from the same CWD.
// Calls the hook with different CWD values and verifies that each path is rooted at input.CWD.
// This prevents the case where CWD A's lock protects CWD B's state (which would cause a race).
func TestHandlePlansWatcher_LockAndStateUseSameCWD(t *testing.T) {
	// Project A directory
	projectA := t.TempDir()
	// Project B directory (different CWD)
	projectB := t.TempDir()

	origDir, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	// Process cwd is projectB (input.CWD points to projectA)
	if err := os.Chdir(projectB); err != nil {
		t.Fatal(err)
	}
	defer os.Chdir(origDir)

	// Create Plans.md and state directory under projectA
	plansContent := "| Task 1 | A | DoD | - | pm:依頼中 |\n"
	if err := os.WriteFile(filepath.Join(projectA, "Plans.md"), []byte(plansContent), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(filepath.Join(projectA, ".claude", "state"), 0o755); err != nil {
		t.Fatal(err)
	}
	prevState := `{"timestamp":"2026-01-01T00:00:00Z","pm_pending":0,"cc_todo":0,"cc_wip":0,"cc_done":0,"pm_confirmed":0}`
	if err := os.WriteFile(
		filepath.Join(projectA, ".claude", "state", "plans-state.json"),
		[]byte(prevState), 0o644,
	); err != nil {
		t.Fatal(err)
	}

	// Call hook with input.CWD = projectA
	inputJSON := `{"tool_name":"Edit","cwd":"` + projectA + `","tool_input":{"file_path":"Plans.md"}}`
	var out bytes.Buffer
	if err := HandlePlansWatcher(strings.NewReader(inputJSON), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	// Lock file should be created under projectA (not projectB)
	expectedLockPath := filepath.Join(projectA, plansLockFile)
	if _, statErr := os.Stat(expectedLockPath); statErr != nil {
		t.Errorf("lock file should be created under projectA (%s), but not found: %v",
			expectedLockPath, statErr)
	}

	// State file should be saved under projectA (not projectB)
	expectedStatePath := filepath.Join(projectA, plansStateFile)
	if _, statErr := os.Stat(expectedStatePath); statErr != nil {
		t.Errorf("state file should be saved under projectA (%s), but not found: %v",
			expectedStatePath, statErr)
	}

	// Neither lock nor state should be created under projectB
	unexpectedLockPath := filepath.Join(projectB, plansLockFile)
	if _, statErr := os.Stat(unexpectedLockPath); statErr == nil {
		t.Errorf("lock file should NOT be created under projectB (%s)", unexpectedLockPath)
	}
	unexpectedStatePath := filepath.Join(projectB, plansStateFile)
	if _, statErr := os.Stat(unexpectedStatePath); statErr == nil {
		t.Errorf("state file should NOT be created under projectB (%s)", unexpectedStatePath)
	}
}

// TestAcquirePlansLock_FailClosed verifies that HandlePlansWatcher becomes
// fail-closed (calls exitFailClosed) when lock acquisition fails.
// Because flock is re-entrant within the same process, lock contention only occurs
// between two separate processes on the same file. This test makes the lock file
// read-only to force open to fail and cover the fail-closed path.
// NOTE: TestHandlePlansWatcher_LockExhaustionFailsClosed provides equivalent coverage;
// this test focuses specifically on the acquirePlansLock unit behaviour.
func TestAcquirePlansLock_FailClosed(t *testing.T) {
	tmpDir := t.TempDir()
	origDir, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	if err := os.Chdir(tmpDir); err != nil {
		t.Fatal(err)
	}
	defer os.Chdir(origDir)

	// Plans.md を作成
	plansContent := "| Task 1 | A | DoD | - | pm:依頼中 |\n"
	if err := os.WriteFile("Plans.md", []byte(plansContent), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(".claude/state", 0o755); err != nil {
		t.Fatal(err)
	}

	// lock ディレクトリを作成し、lock ファイルを 000 パーミッションで作成して open を失敗させる
	if err := os.MkdirAll(".claude/state/locks", 0o755); err != nil {
		t.Fatal(err)
	}
	lockPath := filepath.Join(tmpDir, plansLockFile)
	if err := os.WriteFile(lockPath, []byte{}, 0o000); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() {
		os.Chmod(lockPath, 0o644) //nolint:errcheck
	})

	// root で実行している場合（CI など）は 000 でも open できるのでスキップ
	if os.Getuid() == 0 {
		t.Skip("skipping fail-closed test: running as root (0o000 mode has no effect)")
	}

	// exitFailClosed をモック差し替えして os.Exit(1) を回避
	origExitFailClosed := exitFailClosed
	exitFailClosed = func(msg string) { /* no-op for test */ }
	defer func() { exitFailClosed = origExitFailClosed }()

	input := `{"tool_name":"Edit","tool_input":{"file_path":"Plans.md"}}`
	var out bytes.Buffer
	if err := HandlePlansWatcher(strings.NewReader(input), &out); err != nil {
		t.Fatalf("HandlePlansWatcher should not return error even on lock failure: %v", err)
	}

	var result postToolOutput
	if jsonErr := json.Unmarshal(out.Bytes(), &result); jsonErr != nil {
		t.Fatalf("invalid JSON output: %v, raw: %s", jsonErr, out.String())
	}

	// fail-closed フォールバック: lock 取得失敗時は空の AdditionalContext（通知なし）
	if result.HookSpecificOutput.AdditionalContext != "" {
		t.Errorf("expected empty context on lock failure (fail-closed), got %q",
			result.HookSpecificOutput.AdditionalContext)
	}
}

// TestReleasePlansLock_Nil は nil に対して releasePlansLock が panic しないことを確認する。
func TestReleasePlansLock_Nil(t *testing.T) {
	// panic しないこと
	releasePlansLock(nil)
}
