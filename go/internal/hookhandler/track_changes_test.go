package hookhandler

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func TestHandleTrackChanges_NoInput(t *testing.T) {
	var out bytes.Buffer
	err := HandleTrackChanges(strings.NewReader(""), &out)
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

func TestHandleTrackChanges_NoFilePath(t *testing.T) {
	input := `{"tool_name":"Write","tool_input":{}}`
	var out bytes.Buffer
	err := HandleTrackChanges(strings.NewReader(input), &out)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	var result postToolOutput
	if jsonErr := json.Unmarshal(out.Bytes(), &result); jsonErr != nil {
		t.Fatalf("invalid JSON output: %v", jsonErr)
	}
}

func TestHandleTrackChanges_RecordsEntry(t *testing.T) {
	tmpDir := t.TempDir()
	origDir, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	if err := os.Chdir(tmpDir); err != nil {
		t.Fatal(err)
	}
	defer os.Chdir(origDir)

	input := `{"tool_name":"Write","tool_input":{"file_path":"src/main.go"}}`
	var out bytes.Buffer
	if err := HandleTrackChanges(strings.NewReader(input), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	// The JSONL file should be created
	data, err := os.ReadFile(changedFilesPath)
	if err != nil {
		t.Fatalf("changed-files.jsonl not created: %v", err)
	}

	var entry changedFileEntry
	if err := json.Unmarshal([]byte(strings.TrimSpace(string(data))), &entry); err != nil {
		t.Fatalf("invalid JSONL entry: %v, raw: %s", err, data)
	}
	if entry.File != "src/main.go" {
		t.Errorf("expected file=src/main.go, got %q", entry.File)
	}
	if entry.Action != "Write" {
		t.Errorf("expected action=Write, got %q", entry.Action)
	}
	if entry.Important {
		t.Errorf("expected important=false for src/main.go")
	}
}

func TestHandleTrackChanges_ImportantFile_Plans(t *testing.T) {
	tmpDir := t.TempDir()
	origDir, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	if err := os.Chdir(tmpDir); err != nil {
		t.Fatal(err)
	}
	defer os.Chdir(origDir)

	input := `{"tool_name":"Edit","tool_input":{"file_path":"Plans.md"}}`
	var out bytes.Buffer
	if err := HandleTrackChanges(strings.NewReader(input), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	data, err := os.ReadFile(changedFilesPath)
	if err != nil {
		t.Fatalf("changed-files.jsonl not created: %v", err)
	}

	var entry changedFileEntry
	if err := json.Unmarshal([]byte(strings.TrimSpace(string(data))), &entry); err != nil {
		t.Fatalf("invalid JSONL entry: %v", err)
	}
	if !entry.Important {
		t.Errorf("expected important=true for Plans.md")
	}
}

func TestHandleTrackChanges_ImportantFile_TestFile(t *testing.T) {
	tmpDir := t.TempDir()
	origDir, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	if err := os.Chdir(tmpDir); err != nil {
		t.Fatal(err)
	}
	defer os.Chdir(origDir)

	input := `{"tool_name":"Write","tool_input":{"file_path":"src/main.test.ts"}}`
	var out bytes.Buffer
	if err := HandleTrackChanges(strings.NewReader(input), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	data, err := os.ReadFile(changedFilesPath)
	if err != nil {
		t.Fatalf("changed-files.jsonl not created: %v", err)
	}

	var entry changedFileEntry
	if err := json.Unmarshal([]byte(strings.TrimSpace(string(data))), &entry); err != nil {
		t.Fatalf("invalid JSONL entry: %v", err)
	}
	if !entry.Important {
		t.Errorf("expected important=true for *.test.ts file")
	}
}

func TestHandleTrackChanges_WindowsPathNormalization(t *testing.T) {
	tmpDir := t.TempDir()
	origDir, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	if err := os.Chdir(tmpDir); err != nil {
		t.Fatal(err)
	}
	defer os.Chdir(origDir)

	// Path containing Windows backslashes
	input := `{"tool_name":"Write","tool_input":{"file_path":"src\\components\\App.tsx"}}`
	var out bytes.Buffer
	if err := HandleTrackChanges(strings.NewReader(input), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	data, err := os.ReadFile(changedFilesPath)
	if err != nil {
		t.Fatalf("changed-files.jsonl not created: %v", err)
	}

	var entry changedFileEntry
	if err := json.Unmarshal([]byte(strings.TrimSpace(string(data))), &entry); err != nil {
		t.Fatalf("invalid JSONL entry: %v", err)
	}
	// Backslashes should be converted to forward slashes
	if strings.Contains(entry.File, "\\") {
		t.Errorf("expected backslashes to be normalized, got %q", entry.File)
	}
}

func TestHandleTrackChanges_CWDRelativePath(t *testing.T) {
	tmpDir := t.TempDir()
	origDir, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	if err := os.Chdir(tmpDir); err != nil {
		t.Fatal(err)
	}
	defer os.Chdir(origDir)

	// Convert an absolute path with CWD to a relative path
	input := `{"tool_name":"Write","cwd":"/home/user/project","tool_input":{"file_path":"/home/user/project/src/main.go"}}`
	var out bytes.Buffer
	if err := HandleTrackChanges(strings.NewReader(input), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	data, err := os.ReadFile(changedFilesPath)
	if err != nil {
		t.Fatalf("changed-files.jsonl not created: %v", err)
	}

	var entry changedFileEntry
	if err := json.Unmarshal([]byte(strings.TrimSpace(string(data))), &entry); err != nil {
		t.Fatalf("invalid JSONL entry: %v", err)
	}
	// The absolute path should be converted to a relative path
	if entry.File != "src/main.go" {
		t.Errorf("expected relative path src/main.go, got %q", entry.File)
	}
}

func TestHandleTrackChanges_DedupWithin2Hours(t *testing.T) {
	tmpDir := t.TempDir()
	origDir, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	if err := os.Chdir(tmpDir); err != nil {
		t.Fatal(err)
	}
	defer os.Chdir(origDir)

	// First recording
	input := `{"tool_name":"Write","tool_input":{"file_path":"src/main.go"}}`
	var out bytes.Buffer
	if err := HandleTrackChanges(strings.NewReader(input), &out); err != nil {
		t.Fatalf("first call error: %v", err)
	}

	// Second call should be skipped by dedup
	out.Reset()
	if err := HandleTrackChanges(strings.NewReader(input), &out); err != nil {
		t.Fatalf("second call error: %v", err)
	}

	data, err := os.ReadFile(changedFilesPath)
	if err != nil {
		t.Fatalf("changed-files.jsonl not found: %v", err)
	}

	lines := strings.Split(strings.TrimSpace(string(data)), "\n")
	// The second call is skipped, so only 1 line should remain
	if len(lines) != 1 {
		t.Errorf("expected 1 line (dedup), got %d lines: %s", len(lines), data)
	}
}

func TestHandleTrackChanges_ToolResponseFilePath(t *testing.T) {
	tmpDir := t.TempDir()
	origDir, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	if err := os.Chdir(tmpDir); err != nil {
		t.Fatal(err)
	}
	defer os.Chdir(origDir)

	// Case using tool_response.filePath
	input := `{"tool_name":"Task","tool_response":{"filePath":"output/result.go"}}`
	var out bytes.Buffer
	if err := HandleTrackChanges(strings.NewReader(input), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	data, err := os.ReadFile(changedFilesPath)
	if err != nil {
		t.Fatalf("changed-files.jsonl not created: %v", err)
	}

	var entry changedFileEntry
	if err := json.Unmarshal([]byte(strings.TrimSpace(string(data))), &entry); err != nil {
		t.Fatalf("invalid JSONL entry: %v", err)
	}
	if entry.File != "output/result.go" {
		t.Errorf("expected file=output/result.go, got %q", entry.File)
	}
}

func TestRotateIfNeeded(t *testing.T) {
	tmpDir := t.TempDir()
	origDir, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	if err := os.Chdir(tmpDir); err != nil {
		t.Fatal(err)
	}
	defer os.Chdir(origDir)

	// Create the state directory
	if err := os.MkdirAll(filepath.Dir(changedFilesPath), 0o755); err != nil {
		t.Fatal(err)
	}

	// Create a file with maxLines+10 lines
	f, err := os.Create(changedFilesPath)
	if err != nil {
		t.Fatal(err)
	}
	total := trackChangesMaxLines + 10
	for i := range total {
		ts := time.Now().Add(-time.Duration(total-i) * time.Hour * 3).UTC().Format(time.RFC3339)
		entry := changedFileEntry{File: "file.go", Action: "Write", Timestamp: ts}
		b, _ := json.Marshal(entry)
		fmt.Fprintf(f, "%s\n", b)
	}
	f.Close()

	if err := rotateIfNeeded(changedFilesPath, trackChangesMaxLines); err != nil {
		t.Fatalf("rotateIfNeeded error: %v", err)
	}

	data, err := os.ReadFile(changedFilesPath)
	if err != nil {
		t.Fatal(err)
	}
	lines := strings.Split(strings.TrimSpace(string(data)), "\n")
	if len(lines) != trackChangesMaxLines {
		t.Errorf("expected %d lines after rotation, got %d", trackChangesMaxLines, len(lines))
	}
}

func TestNormalizePathSeparators(t *testing.T) {
	cases := []struct {
		input    string
		expected string
	}{
		{"src\\main.go", "src/main.go"},
		{"src/main.go", "src/main.go"},
		{"C:\\Users\\foo\\project\\src\\main.go", "C:/Users/foo/project/src/main.go"},
	}
	for _, c := range cases {
		got := normalizePathSeparators(c.input)
		if got != c.expected {
			t.Errorf("normalizePathSeparators(%q) = %q, want %q", c.input, got, c.expected)
		}
	}
}

func TestMakeRelativePath(t *testing.T) {
	cases := []struct {
		filePath string
		cwd      string
		expected string
	}{
		{"/home/user/project/src/main.go", "/home/user/project", "src/main.go"},
		{"/home/user/project/Plans.md", "/home/user/project/", "Plans.md"},
		{"/other/path/file.go", "/home/user/project", "/other/path/file.go"},
		{"src/main.go", "/home/user/project", "src/main.go"},
	}
	for _, c := range cases {
		got := makeRelativePath(c.filePath, c.cwd)
		if got != c.expected {
			t.Errorf("makeRelativePath(%q, %q) = %q, want %q", c.filePath, c.cwd, got, c.expected)
		}
	}
}
