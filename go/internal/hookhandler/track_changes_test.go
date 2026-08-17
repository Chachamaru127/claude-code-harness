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

	// JSONL ファイルが作成されること
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

	// Windows バックスラッシュを含むパス
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
	// バックスラッシュがスラッシュに変換されること
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

	// CWD 付きの絶対パスを相対パスに変換する
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
	// 絶対パスが相対パスに変換されること
	if entry.File != "src/main.go" {
		t.Errorf("expected relative path src/main.go, got %q", entry.File)
	}
}

// Regression (Phase 134 finding): the recorded entry must carry session_id
// from the PostToolUse payload so Stop-time consumers can scope
// "files touched this session" reads to the writing session.
func TestHandleTrackChanges_RecordsSessionID(t *testing.T) {
	tmpDir := t.TempDir()
	origDir, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	if err := os.Chdir(tmpDir); err != nil {
		t.Fatal(err)
	}
	defer os.Chdir(origDir)

	input := `{"tool_name":"Write","session_id":"s1","tool_input":{"file_path":"src/main.go"}}`
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
		t.Fatalf("invalid JSONL entry: %v, raw: %s", err, data)
	}
	if entry.SessionID != "s1" {
		t.Errorf("expected session_id=s1, got %q", entry.SessionID)
	}
}

// Regression (advisor-flagged blind spot): dedup must be scoped per session.
// Without this, session B's write of a file session A already recorded
// within the 2h window would be silently dropped, leaving B's own edit
// invisible to B's own Stop gate (defeating the session filter added for
// the Phase 134 finding).
func TestHandleTrackChanges_DedupIsPerSession(t *testing.T) {
	tmpDir := t.TempDir()
	origDir, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	if err := os.Chdir(tmpDir); err != nil {
		t.Fatal(err)
	}
	defer os.Chdir(origDir)

	// Session A records notes.md.
	inputA := `{"tool_name":"Write","session_id":"s-A","tool_input":{"file_path":"notes.md"}}`
	var outA bytes.Buffer
	if err := HandleTrackChanges(strings.NewReader(inputA), &outA); err != nil {
		t.Fatalf("session A call error: %v", err)
	}

	// Session B records the SAME file within the dedup window: must NOT be
	// suppressed, because it is a different session.
	inputB := `{"tool_name":"Write","session_id":"s-B","tool_input":{"file_path":"notes.md"}}`
	var outB bytes.Buffer
	if err := HandleTrackChanges(strings.NewReader(inputB), &outB); err != nil {
		t.Fatalf("session B call error: %v", err)
	}

	data, err := os.ReadFile(changedFilesPath)
	if err != nil {
		t.Fatalf("changed-files.jsonl not found: %v", err)
	}
	lines := strings.Split(strings.TrimSpace(string(data)), "\n")
	if len(lines) != 2 {
		t.Fatalf("expected 2 entries (one per session), got %d lines: %s", len(lines), data)
	}

	// Session A records notes.md again within the window: must be
	// suppressed (same-session dedup still works).
	var outA2 bytes.Buffer
	if err := HandleTrackChanges(strings.NewReader(inputA), &outA2); err != nil {
		t.Fatalf("session A second call error: %v", err)
	}
	data2, err := os.ReadFile(changedFilesPath)
	if err != nil {
		t.Fatal(err)
	}
	lines2 := strings.Split(strings.TrimSpace(string(data2)), "\n")
	if len(lines2) != 2 {
		t.Fatalf("expected same-session repeat to dedup (still 2 lines), got %d lines: %s", len(lines2), data2)
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

	// 最初の記録
	input := `{"tool_name":"Write","tool_input":{"file_path":"src/main.go"}}`
	var out bytes.Buffer
	if err := HandleTrackChanges(strings.NewReader(input), &out); err != nil {
		t.Fatalf("first call error: %v", err)
	}

	// 2回目は dedup でスキップされること
	out.Reset()
	if err := HandleTrackChanges(strings.NewReader(input), &out); err != nil {
		t.Fatalf("second call error: %v", err)
	}

	data, err := os.ReadFile(changedFilesPath)
	if err != nil {
		t.Fatalf("changed-files.jsonl not found: %v", err)
	}

	lines := strings.Split(strings.TrimSpace(string(data)), "\n")
	// 2回目はスキップされるので1行のみ
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

	// tool_response.filePath を使うケース
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

	// stateディレクトリを作成
	if err := os.MkdirAll(filepath.Dir(changedFilesPath), 0o755); err != nil {
		t.Fatal(err)
	}

	// maxLines+10 行のファイルを作成
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
