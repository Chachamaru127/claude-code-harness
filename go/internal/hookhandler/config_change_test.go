package hookhandler

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestHandleConfigChange_EmptyInput(t *testing.T) {
	var out bytes.Buffer
	err := HandleConfigChange(strings.NewReader(""), &out)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	var result okOutput
	if jsonErr := json.Unmarshal(out.Bytes(), &result); jsonErr != nil {
		t.Fatalf("invalid JSON output: %v, raw: %s", jsonErr, out.String())
	}
	if !result.OK {
		t.Error("expected ok=true for empty input")
	}
}

func TestHandleConfigChange_NoBreezingState(t *testing.T) {
	tmpDir := t.TempDir()

	// Set PROJECT_ROOT to the temporary directory.
	t.Setenv("PROJECT_ROOT", tmpDir)

	input := `{"file_path":"/some/project/.eslintrc.json","change_type":"modified"}`
	var out bytes.Buffer
	err := HandleConfigChange(strings.NewReader(input), &out)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	var result okOutput
	if jsonErr := json.Unmarshal(out.Bytes(), &result); jsonErr != nil {
		t.Fatalf("invalid JSON output: %v", jsonErr)
	}
	if !result.OK {
		t.Error("expected ok=true when breezing is not active")
	}

	// The timeline file should not be created.
	timelineFile := filepath.Join(tmpDir, ".claude", "state", "breezing-timeline.jsonl")
	if _, statErr := os.Stat(timelineFile); statErr == nil {
		t.Error("timeline file should not be created when breezing is not active")
	}
}

func TestHandleConfigChange_BreezingInactive(t *testing.T) {
	tmpDir := t.TempDir()
	t.Setenv("PROJECT_ROOT", tmpDir)

	// Create breezing.json (inactive status).
	stateDir := filepath.Join(tmpDir, ".claude", "state")
	if mkdirErr := os.MkdirAll(stateDir, 0o755); mkdirErr != nil {
		t.Fatal(mkdirErr)
	}
	if writeErr := os.WriteFile(
		filepath.Join(stateDir, "breezing.json"),
		[]byte(`{"status":"inactive"}`),
		0o644,
	); writeErr != nil {
		t.Fatal(writeErr)
	}

	input := `{"file_path":"tsconfig.json","change_type":"modified"}`
	var out bytes.Buffer
	err := HandleConfigChange(strings.NewReader(input), &out)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	var result okOutput
	if jsonErr := json.Unmarshal(out.Bytes(), &result); jsonErr != nil {
		t.Fatalf("invalid JSON output: %v", jsonErr)
	}
	if !result.OK {
		t.Error("expected ok=true")
	}

	// The timeline should not be recorded.
	timelineFile := filepath.Join(stateDir, "breezing-timeline.jsonl")
	if _, statErr := os.Stat(timelineFile); statErr == nil {
		t.Error("timeline file should not be created when breezing is inactive")
	}
}

func TestHandleConfigChange_BreezingActive(t *testing.T) {
	tmpDir := t.TempDir()
	t.Setenv("PROJECT_ROOT", tmpDir)

	stateDir := filepath.Join(tmpDir, ".claude", "state")
	if mkdirErr := os.MkdirAll(stateDir, 0o755); mkdirErr != nil {
		t.Fatal(mkdirErr)
	}

	// Set breezing.json to active status.
	if writeErr := os.WriteFile(
		filepath.Join(stateDir, "breezing.json"),
		[]byte(`{"status":"active"}`),
		0o644,
	); writeErr != nil {
		t.Fatal(writeErr)
	}

	input := `{"file_path":"/home/user/project/.eslintrc.json","change_type":"modified"}`
	var out bytes.Buffer
	err := HandleConfigChange(strings.NewReader(input), &out)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	var result okOutput
	if jsonErr := json.Unmarshal(out.Bytes(), &result); jsonErr != nil {
		t.Fatalf("invalid JSON output: %v", jsonErr)
	}
	if !result.OK {
		t.Error("expected ok=true when breezing is active")
	}

	// The timeline file should have been created.
	timelineFile := filepath.Join(stateDir, "breezing-timeline.jsonl")
	data, readErr := os.ReadFile(timelineFile)
	if readErr != nil {
		t.Fatalf("timeline file should be created when breezing is active: %v", readErr)
	}

	// Parse the first line of the JSONL file.
	lines := strings.Split(strings.TrimSpace(string(data)), "\n")
	if len(lines) == 0 {
		t.Fatal("timeline file is empty")
	}

	var entry map[string]string
	if jsonErr := json.Unmarshal([]byte(lines[0]), &entry); jsonErr != nil {
		t.Fatalf("invalid JSONL entry: %v, raw: %s", jsonErr, lines[0])
	}

	if entry["type"] != "config_change" {
		t.Errorf("expected type=config_change, got %q", entry["type"])
	}
	if entry["change_type"] != "modified" {
		t.Errorf("expected change_type=modified, got %q", entry["change_type"])
	}
	if entry["timestamp"] == "" {
		t.Error("expected non-empty timestamp")
	}
}

func TestHandleConfigChange_BreezingRunning(t *testing.T) {
	tmpDir := t.TempDir()
	t.Setenv("PROJECT_ROOT", tmpDir)

	stateDir := filepath.Join(tmpDir, ".claude", "state")
	if mkdirErr := os.MkdirAll(stateDir, 0o755); mkdirErr != nil {
		t.Fatal(mkdirErr)
	}

	// Should also be recorded when status is running.
	if writeErr := os.WriteFile(
		filepath.Join(stateDir, "breezing.json"),
		[]byte(`{"status":"running"}`),
		0o644,
	); writeErr != nil {
		t.Fatal(writeErr)
	}

	input := `{"file_path":"package.json","change_type":"created"}`
	var out bytes.Buffer
	err := HandleConfigChange(strings.NewReader(input), &out)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	timelineFile := filepath.Join(stateDir, "breezing-timeline.jsonl")
	data, readErr := os.ReadFile(timelineFile)
	if readErr != nil {
		t.Fatalf("timeline file should be created: %v", readErr)
	}
	if !strings.Contains(string(data), "config_change") {
		t.Errorf("expected config_change in timeline, got: %s", string(data))
	}
}

func TestHandleConfigChange_DefaultChangeType(t *testing.T) {
	tmpDir := t.TempDir()
	t.Setenv("PROJECT_ROOT", tmpDir)

	stateDir := filepath.Join(tmpDir, ".claude", "state")
	if mkdirErr := os.MkdirAll(stateDir, 0o755); mkdirErr != nil {
		t.Fatal(mkdirErr)
	}
	if writeErr := os.WriteFile(
		filepath.Join(stateDir, "breezing.json"),
		[]byte(`{"status":"active"}`),
		0o644,
	); writeErr != nil {
		t.Fatal(writeErr)
	}

	// When change_type is omitted, it should default to "modified".
	input := `{"file_path":"config.json"}`
	var out bytes.Buffer
	if err := HandleConfigChange(strings.NewReader(input), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	timelineFile := filepath.Join(stateDir, "breezing-timeline.jsonl")
	data, readErr := os.ReadFile(timelineFile)
	if readErr != nil {
		t.Fatalf("timeline file not created: %v", readErr)
	}

	var entry map[string]string
	if jsonErr := json.Unmarshal([]byte(strings.TrimSpace(string(data))), &entry); jsonErr != nil {
		t.Fatalf("invalid JSONL: %v", jsonErr)
	}
	if entry["change_type"] != "modified" {
		t.Errorf("expected default change_type=modified, got %q", entry["change_type"])
	}
}

func TestHandleConfigChange_ProjectRootRelativePath(t *testing.T) {
	tmpDir := t.TempDir()
	t.Setenv("PROJECT_ROOT", tmpDir)

	stateDir := filepath.Join(tmpDir, ".claude", "state")
	if mkdirErr := os.MkdirAll(stateDir, 0o755); mkdirErr != nil {
		t.Fatal(mkdirErr)
	}
	if writeErr := os.WriteFile(
		filepath.Join(stateDir, "breezing.json"),
		[]byte(`{"status":"active"}`),
		0o644,
	); writeErr != nil {
		t.Fatal(writeErr)
	}

	// Absolute path containing PROJECT_ROOT → should be normalised to a relative path.
	absolutePath := filepath.Join(tmpDir, ".eslintrc.json")
	input, _ := json.Marshal(map[string]string{
		"file_path":   absolutePath,
		"change_type": "modified",
	})

	var out bytes.Buffer
	if err := HandleConfigChange(bytes.NewReader(input), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	timelineFile := filepath.Join(stateDir, "breezing-timeline.jsonl")
	data, readErr := os.ReadFile(timelineFile)
	if readErr != nil {
		t.Fatalf("timeline file not created: %v", readErr)
	}

	// A relative path, not an absolute path, should be recorded.
	var entry map[string]string
	if jsonErr := json.Unmarshal([]byte(strings.TrimSpace(string(data))), &entry); jsonErr != nil {
		t.Fatalf("invalid JSONL: %v", jsonErr)
	}
	if strings.HasPrefix(entry["file_path"], tmpDir) {
		t.Errorf("file_path should be relative, got absolute: %q", entry["file_path"])
	}
	if entry["file_path"] != ".eslintrc.json" {
		t.Errorf("expected relative path '.eslintrc.json', got %q", entry["file_path"])
	}
}
