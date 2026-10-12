package hookhandler

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
	"time"

	"github.com/Chachamaru127/claude-code-harness/go/internal/gitport"
	"github.com/Chachamaru127/claude-code-harness/go/internal/writinglint"
)

// All three directories differ; the process runs in an unrelated Git repo.
func statePathFixture(t *testing.T, claudeRoot bool) (root, inputCWD, processCWD string) {
	t.Helper()
	for _, name := range []string{"HARNESS_PROJECT_ROOT", "PROJECT_ROOT", "CLAUDE_PROJECT_DIR"} {
		t.Setenv(name, "")
	}
	root, processCWD = t.TempDir(), t.TempDir()
	for _, dir := range []*string{&root, &processCWD} {
		real, err := filepath.EvalSymlinks(*dir)
		if err != nil {
			t.Fatal(err)
		}
		*dir = real
		if err := gitport.Run(*dir, "init"); err != nil {
			t.Fatal(err)
		}
	}
	inputCWD = filepath.Join(root, "sub")
	if err := os.MkdirAll(inputCWD, 0o755); err != nil {
		t.Fatal(err)
	}
	old, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	if err := os.Chdir(processCWD); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() {
		if err := os.Chdir(old); err != nil {
			t.Error(err)
		}
	})
	if claudeRoot {
		t.Setenv("CLAUDE_PROJECT_DIR", root)
	}
	return
}

func statePathWrite(t *testing.T, path, content string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}
}

func statePathPayload(t *testing.T, cwd, file string) string {
	t.Helper()
	payload, err := json.Marshal(map[string]interface{}{
		"cwd": cwd, "session_id": "state-path-session", "tool_name": "Edit",
		"last_assistant_message": "done", "tool_input": map[string]string{"file_path": file},
	})
	if err != nil {
		t.Fatal(err)
	}
	return string(payload)
}

func assertStateOnlyAtRoot(t *testing.T, root, inputCWD, processCWD string, paths ...string) {
	t.Helper()
	for _, path := range paths {
		if _, err := os.Stat(filepath.Join(root, path)); err != nil {
			t.Errorf("project state %s: %v", path, err)
		}
	}
	for _, dir := range []string{inputCWD, processCWD} {
		if _, err := os.Stat(filepath.Join(dir, ".claude", "state")); !os.IsNotExist(err) {
			t.Errorf("state leaked to %s: %v", dir, err)
		}
	}
}

func TestHookStatePaths_TrackAndReaders(t *testing.T) {
	for _, claudeRoot := range []bool{false, true} {
		name := "input-git-root"
		if claudeRoot {
			name = "claude-project-dir"
		}
		t.Run(name, func(t *testing.T) {
			root, inputCWD, processCWD := statePathFixture(t, claudeRoot)
			file := filepath.Join(inputCWD, "notes.test.md")
			statePathWrite(t, file, "以下に示します。")
			// Absolute and input-relative paths must deduplicate into one entry.
			for _, path := range []string{file, "notes.test.md"} {
				var out bytes.Buffer
				if err := HandleTrackChanges(strings.NewReader(statePathPayload(t, inputCWD, path)), &out); err != nil {
					t.Fatal(err)
				}
			}
			assertStateOnlyAtRoot(t, root, inputCWD, processCWD, changedFilesPath)
			data, err := os.ReadFile(filepath.Join(root, changedFilesPath))
			if err != nil {
				t.Fatal(err)
			}
			if lines := strings.Count(string(data), "\n"); lines != 1 {
				t.Fatalf("dedup wrote %d lines, want 1: %s", lines, data)
			}
			want := []string{"sub/notes.test.md"}
			if got := loadTouchedFilesForStop(root, "state-path-session"); !reflect.DeepEqual(got, want) {
				t.Fatalf("Stop reader = %v, want %v", got, want)
			}
			statePathWrite(t, filepath.Join(root, "Plans.md"), "| Task 1 | Implement | DoD | - | cc:WIP |\n")
			var testEdit bytes.Buffer
			if err := HandleTrackChanges(strings.NewReader(statePathPayload(t, inputCWD, "main_test.go")), &testEdit); err != nil {
				t.Fatal(err)
			}
			var tdd bytes.Buffer
			if err := HandleTDDOrderCheck(strings.NewReader(statePathPayload(t, inputCWD, "main.go")), &tdd); err != nil {
				t.Fatal(err)
			}
			if got := parseTDDOutput(t, &tdd); got.SystemMessage != "" {
				t.Fatalf("TDD missed root log: %s", tdd.String())
			}
			statePathWrite(t, filepath.Join(root, "Plans.md"), "| Task 1 | Implement | DoD | - | cc:完了 |\n")
			statePathWrite(t, filepath.Join(root, ".claude/state/active-task.json"), `{"task":"Task 1"}`)
			statePathWrite(t, filepath.Join(root, ".claude/state/contracts/Task 1.sprint-contract.json"), `{"task":{"declared_scope":["sub/notes.test.md"]}}`)
			statePathWrite(t, filepath.Join(root, ".claude/state/session.json"), `{}`)
			payload := statePathPayload(t, inputCWD, "")
			var stop bytes.Buffer
			if err := (&StopSessionEvaluatorHandler{}).Handle(strings.NewReader(payload), &stop); err != nil {
				t.Fatal(err)
			}
			var response stopSessionResponse
			if err := json.Unmarshal(stop.Bytes(), &response); err != nil {
				t.Fatal(err)
			}
			if !response.OK || response.SystemMessage != "" {
				t.Fatalf("Stop missed written scope: %s", stop.String())
			}
			session, err := os.ReadFile(filepath.Join(root, ".claude/state/session.json"))
			if err != nil || !strings.Contains(string(session), "last_message_hash") {
				t.Fatalf("Stop wrote to wrong root: %s, %v", session, err)
			}
			writeStopWritingLintConfig(t, root)
			t.Setenv(writinglint.EnvDictPath, writeStopWritingLintDictFixture(t, root))
			var lint bytes.Buffer
			if err := (&StopWritingLintHandler{}).Handle(strings.NewReader(payload), &lint); err != nil {
				t.Fatal(err)
			}
			assertStopBlocked(t, lint.String(), want[0])
			t.Log("writer, dedup, TDD and both Stop readers share the project root")
		})
	}
}

func TestHookStatePaths_TDDSessionChanges(t *testing.T) {
	root, inputCWD, processCWD := statePathFixture(t, false)
	statePathWrite(t, filepath.Join(root, "Plans.md"), "| Task 1 | Implement | DoD | - | cc:WIP |\n")
	payload := statePathPayload(t, inputCWD, "main.go")
	var before bytes.Buffer
	if err := HandleTDDOrderCheck(strings.NewReader(payload), &before); err != nil {
		t.Fatal(err)
	}
	if got := parseTDDOutput(t, &before); got.SystemMessage == "" {
		t.Fatal("expected reminder before test edit")
	}
	statePathWrite(t, filepath.Join(root, sessionChangesFile), `["sub/main_test.go"]`)
	var after bytes.Buffer
	if err := HandleTDDOrderCheck(strings.NewReader(payload), &after); err != nil {
		t.Fatal(err)
	}
	if got := parseTDDOutput(t, &after); got.SystemMessage != "" {
		t.Fatalf("TDD missed root session state: %s", after.String())
	}
	assertStateOnlyAtRoot(t, root, inputCWD, processCWD, sessionChangesFile)
}

func TestHookStatePaths_PlansWatcher(t *testing.T) {
	for _, claudeRoot := range []bool{false, true} {
		name := "input-git-root"
		if claudeRoot {
			name = "claude-project-dir"
		}
		t.Run(name, func(t *testing.T) {
			root, inputCWD, processCWD := statePathFixture(t, claudeRoot)
			path := filepath.Join(root, "Plans.md")
			statePathWrite(t, path, "| Task 1 | Implement | DoD | - | cc:完了 |\n")
			for _, file := range []string{path, "../Plans.md"} {
				var out bytes.Buffer
				if err := HandlePlansWatcher(strings.NewReader(statePathPayload(t, inputCWD, file)), &out); err != nil {
					t.Fatal(err)
				}
			}
			assertStateOnlyAtRoot(t, root, inputCWD, processCWD, plansStateFile, plansLockFile, pmNotificationFile, cursorNotificationFile)
			data, err := os.ReadFile(filepath.Join(root, plansStateFile))
			if err != nil {
				t.Fatal(err)
			}
			var state plansState
			if err := json.Unmarshal(data, &state); err != nil {
				t.Fatal(err)
			}
			if state.CcDone != 1 {
				t.Fatalf("state = %+v, want one completed task", state)
			}
		})
	}
}

func TestHookStatePaths_Setup(t *testing.T) {
	root, inputCWD, processCWD := statePathFixture(t, false)
	t.Setenv("CLAUDE_PLUGIN_ROOT", root)
	t.Setenv("CLAUDE_CODE_HARNESS_MEM_AUTO_SETUP", "0")
	payload := statePathPayload(t, inputCWD, "")
	var init bytes.Buffer
	if err := HandleSetupHookInit(strings.NewReader(payload), &init); err != nil {
		t.Fatal(err)
	}
	assertStateOnlyAtRoot(t, root, inputCWD, processCWD, ".claude/state")
	old := filepath.Join(root, ".claude/state/sessions/session-old.json")
	statePathWrite(t, old, `{}`)
	cutoff := time.Now().AddDate(0, 0, -8)
	if err := os.Chtimes(old, cutoff, cutoff); err != nil {
		t.Fatal(err)
	}
	tmp := filepath.Join(root, ".claude/state/nested/cleanup.tmp")
	statePathWrite(t, tmp, "temporary")
	statePathWrite(t, filepath.Join(root, ".claude/state/sessions/session-new.json"), `{}`)
	var maintenance bytes.Buffer
	if err := HandleSetupHookMaintenance(strings.NewReader(payload), &maintenance); err != nil {
		t.Fatal(err)
	}
	for _, path := range []string{old, tmp} {
		if _, err := os.Stat(path); !os.IsNotExist(err) {
			t.Errorf("maintenance missed %s: %v", path, err)
		}
	}
	assertStateOnlyAtRoot(t, root, inputCWD, processCWD, ".claude/state/sessions/session-new.json")
}

func TestHookStatePaths_EnvironmentPriority(t *testing.T) {
	root, inputCWD, processCWD := statePathFixture(t, false)
	harnessRoot, projectRoot, claudeRoot := t.TempDir(), t.TempDir(), t.TempDir()
	cases := []struct{ name, harness, project, claude, want string }{
		{"harness wins", harnessRoot, projectRoot, claudeRoot, harnessRoot},
		{"project wins over claude", "", projectRoot, claudeRoot, projectRoot},
		{"claude wins over input and process git", "", "", claudeRoot, claudeRoot},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			t.Setenv("HARNESS_PROJECT_ROOT", tc.harness)
			t.Setenv("PROJECT_ROOT", tc.project)
			t.Setenv("CLAUDE_PROJECT_DIR", tc.claude)
			var out bytes.Buffer
			if err := HandleTrackChanges(strings.NewReader(statePathPayload(t, inputCWD, "main.go")), &out); err != nil {
				t.Fatal(err)
			}
			if _, err := os.Stat(filepath.Join(tc.want, changedFilesPath)); err != nil {
				t.Fatalf("priority selected wrong root: %v", err)
			}
			for _, dir := range []string{root, inputCWD, processCWD} {
				if _, err := os.Stat(filepath.Join(dir, ".claude/state")); !os.IsNotExist(err) {
					t.Fatalf("state leaked to %s: %v", dir, err)
				}
			}
		})
	}
}

func TestHookStatePaths_RootFallbacks(t *testing.T) {
	root, inputCWD, processCWD := statePathFixture(t, false)
	standalone := t.TempDir()
	for _, tc := range []struct{ name, cwd, want string }{
		{"input git root", inputCWD, root},
		{"non-git input wins over process git", standalone, standalone},
		{"missing input uses process git", "", processCWD},
		{"nonexistent input uses process git", filepath.Join(standalone, "absent"), processCWD},
	} {
		t.Run(tc.name, func(t *testing.T) {
			if got := resolveProjectRoot(tc.cwd); got != tc.want {
				t.Fatalf("resolveProjectRoot(%q) = %q, want %q", tc.cwd, got, tc.want)
			}
		})
	}
	if err := os.Chdir(inputCWD); err != nil {
		t.Fatal(err)
	}
	// Hooks lacking an input cwd must still record root-relative file names.
	var out bytes.Buffer
	if err := HandleTrackChanges(strings.NewReader(statePathPayload(t, "", "main.go")), &out); err != nil {
		t.Fatal(err)
	}
	if got := loadTouchedFilesForStop(root, "state-path-session"); !reflect.DeepEqual(got, []string{"sub/main.go"}) {
		t.Fatalf("process subdirectory record = %v, want sub/main.go", got)
	}
	assertStateOnlyAtRoot(t, root, inputCWD, processCWD, changedFilesPath)
}
