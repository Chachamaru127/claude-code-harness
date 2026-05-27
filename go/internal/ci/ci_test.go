package ci

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// ---------------------------------------------------------------------------
// CIStatusHandler テスト
// ---------------------------------------------------------------------------

func TestIsPushOrPRCommand(t *testing.T) {
	tests := []struct {
		cmd  string
		want bool
	}{
		{"git push origin main", true},
		{"git push --force-with-lease", true},
		{"gh pr create --title foo", true},
		{"gh pr merge 123", true},
		{"gh pr edit 123", true},
		{"gh workflow run ci.yml", true},
		{"npm test", false},
		{"go build ./...", false},
		{"git commit -m 'fix'", false},
		{"git status", false},
		{"", false},
	}

	for _, tt := range tests {
		got := isPushOrPRCommand(tt.cmd)
		if got != tt.want {
			t.Errorf("isPushOrPRCommand(%q) = %v, want %v", tt.cmd, got, tt.want)
		}
	}
}

func TestIsFailureConclusion(t *testing.T) {
	tests := []struct {
		conclusion string
		want       bool
	}{
		{"failure", true},
		{"timed_out", true},
		{"cancelled", true},
		{"success", false},
		{"skipped", false},
		{"neutral", false},
		{"", false},
	}

	for _, tt := range tests {
		got := isFailureConclusion(tt.conclusion)
		if got != tt.want {
			t.Errorf("isFailureConclusion(%q) = %v, want %v", tt.conclusion, got, tt.want)
		}
	}
}

func TestCIStatusHandler_Handle_NoPayload(t *testing.T) {
	h := &CIStatusHandler{}
	var out bytes.Buffer

	err := h.Handle(strings.NewReader(""), &out)
	if err != nil {
		t.Fatalf("Handle() error = %v", err)
	}

	var resp approveResponse
	if err := json.Unmarshal(out.Bytes(), &resp); err != nil {
		t.Fatalf("unmarshal response: %v", err)
	}
	if resp.Decision != "approve" {
		t.Errorf("Decision = %q, want approve", resp.Decision)
	}
	if !strings.Contains(resp.Reason, "no payload") {
		t.Errorf("Reason = %q, want 'no payload'", resp.Reason)
	}
}

func TestCIStatusHandler_Handle_NotPushCommand(t *testing.T) {
	h := &CIStatusHandler{}
	var out bytes.Buffer

	inp := `{"tool_name":"Bash","tool_input":{"command":"npm test"},"cwd":"/tmp"}`
	err := h.Handle(strings.NewReader(inp), &out)
	if err != nil {
		t.Fatalf("Handle() error = %v", err)
	}

	var resp approveResponse
	if err := json.Unmarshal(out.Bytes(), &resp); err != nil {
		t.Fatalf("unmarshal response: %v", err)
	}
	if resp.Decision != "approve" {
		t.Errorf("Decision = %q, want approve", resp.Decision)
	}
	if !strings.Contains(resp.Reason, "not a push/PR command") {
		t.Errorf("Reason = %q, want 'not a push/PR command'", resp.Reason)
	}
}

func TestCIStatusHandler_Handle_PushCommand(t *testing.T) {
	dir := t.TempDir()
	h := &CIStatusHandler{
		StateDir: dir,
		GHCmd:    "false", // gh コマンドが失敗するようにして非同期チェックをスキップ
		nowFunc:  func() string { return "2026-04-05T00:00:00Z" },
	}
	var out bytes.Buffer

	inp := `{"tool_name":"Bash","tool_input":{"command":"git push origin main"},"cwd":"/tmp"}`
	err := h.Handle(strings.NewReader(inp), &out)
	if err != nil {
		t.Fatalf("Handle() error = %v", err)
	}

	var resp approveResponse
	if err := json.Unmarshal(out.Bytes(), &resp); err != nil {
		t.Fatalf("unmarshal response: %v", err)
	}
	if resp.Decision != "approve" {
		t.Errorf("Decision = %q, want approve", resp.Decision)
	}
	if !strings.Contains(resp.Reason, "CI monitoring started") {
		t.Errorf("Reason = %q, want 'CI monitoring started'", resp.Reason)
	}
}

func TestCIStatusHandler_Handle_PushWithFailureSignal(t *testing.T) {
	dir := t.TempDir()

	// 既存の失敗シグナルを書いておく
	signalsFile := filepath.Join(dir, "breezing-signals.jsonl")
	signalData := `{"signal":"ci_failure_detected","timestamp":"2026-04-05T00:00:00Z","conclusion":"failure","trigger_command":"git push origin main"}` + "\n"
	if err := os.WriteFile(signalsFile, []byte(signalData), 0600); err != nil {
		t.Fatalf("write signals file: %v", err)
	}

	h := &CIStatusHandler{
		StateDir: dir,
		GHCmd:    "false",
		nowFunc:  func() string { return "2026-04-05T00:01:00Z" },
	}
	var out bytes.Buffer

	inp := `{"tool_name":"Bash","tool_input":{"command":"git push origin main"},"cwd":"/tmp"}`
	err := h.Handle(strings.NewReader(inp), &out)
	if err != nil {
		t.Fatalf("Handle() error = %v", err)
	}

	var resp approveResponse
	if err := json.Unmarshal(out.Bytes(), &resp); err != nil {
		t.Fatalf("unmarshal response: %v", err)
	}
	if resp.Decision != "approve" {
		t.Errorf("Decision = %q, want approve", resp.Decision)
	}
	// additionalContext に CI 失敗メッセージが含まれること
	if !strings.Contains(resp.AdditionalContext, "CI 失敗を検知しました") {
		t.Errorf("AdditionalContext should mention CI failure, got: %q", resp.AdditionalContext)
	}
	if !strings.Contains(resp.AdditionalContext, "failure") {
		t.Errorf("AdditionalContext should mention conclusion, got: %q", resp.AdditionalContext)
	}
}

func TestCIStatusHandler_WriteCIStatus(t *testing.T) {
	dir := t.TempDir()
	h := &CIStatusHandler{
		nowFunc: func() string { return "2026-04-05T00:00:00Z" },
	}

	h.writeCIStatus(dir, "git push origin main", "completed", "success")

	data, err := os.ReadFile(filepath.Join(dir, "ci-status.json"))
	if err != nil {
		t.Fatalf("reading ci-status.json: %v", err)
	}

	var rec CIStatusRecord
	if err := json.Unmarshal(bytes.TrimSpace(data), &rec); err != nil {
		t.Fatalf("unmarshal ci-status.json: %v", err)
	}
	if rec.Timestamp != "2026-04-05T00:00:00Z" {
		t.Errorf("Timestamp = %q, want 2026-04-05T00:00:00Z", rec.Timestamp)
	}
	if rec.TriggerCommand != "git push origin main" {
		t.Errorf("TriggerCommand = %q, want 'git push origin main'", rec.TriggerCommand)
	}
	if rec.Status != "completed" {
		t.Errorf("Status = %q, want completed", rec.Status)
	}
	if rec.Conclusion != "success" {
		t.Errorf("Conclusion = %q, want success", rec.Conclusion)
	}
}

func TestCIStatusHandler_WriteFailureSignal(t *testing.T) {
	dir := t.TempDir()
	h := &CIStatusHandler{
		nowFunc: func() string { return "2026-04-05T00:00:00Z" },
	}

	h.writeFailureSignal(dir, "git push origin main", "failure")

	data, err := os.ReadFile(filepath.Join(dir, "breezing-signals.jsonl"))
	if err != nil {
		t.Fatalf("reading breezing-signals.jsonl: %v", err)
	}

	var sig signalEntry
	if err := json.Unmarshal(bytes.TrimSpace(data), &sig); err != nil {
		t.Fatalf("unmarshal signal entry: %v", err)
	}
	if sig.Signal != "ci_failure_detected" {
		t.Errorf("Signal = %q, want ci_failure_detected", sig.Signal)
	}
	if sig.Conclusion != "failure" {
		t.Errorf("Conclusion = %q, want failure", sig.Conclusion)
	}
}

// ---------------------------------------------------------------------------
// EvidenceCollector テスト
// ---------------------------------------------------------------------------

func TestEvidenceCollector_Collect_Basic(t *testing.T) {
	dir := t.TempDir()
	c := &EvidenceCollector{
		nowFunc: func() string { return "2026-04-05T00:00:00Z" },
	}

	result := c.Collect(CollectOptions{
		ProjectRoot: dir,
		Label:       "test-run",
		Content:     "all tests passed\ncount: 42",
	})

	if result.Error != "" {
		t.Fatalf("Collect() error = %q", result.Error)
	}
	if result.Label != "test-run" {
		t.Errorf("Label = %q, want test-run", result.Label)
	}
	if result.SavedPath == "" {
		t.Error("SavedPath should not be empty")
	}

	// ファイルが存在して内容が正しいことを確認
	data, err := os.ReadFile(result.SavedPath)
	if err != nil {
		t.Fatalf("reading saved file: %v", err)
	}
	if string(data) != "all tests passed\ncount: 42" {
		t.Errorf("file content = %q, want 'all tests passed\\ncount: 42'", string(data))
	}

	// ディレクトリ構造を確認
	expectedDir := filepath.Join(dir, ".claude", "state", "evidence", "test-run")
	if !strings.HasPrefix(result.SavedPath, expectedDir) {
		t.Errorf("SavedPath %q should be under %q", result.SavedPath, expectedDir)
	}
}

func TestEvidenceCollector_Collect_DefaultLabel(t *testing.T) {
	dir := t.TempDir()
	c := &EvidenceCollector{
		nowFunc: func() string { return "2026-04-05T00:00:00Z" },
	}

	result := c.Collect(CollectOptions{
		ProjectRoot: dir,
		Content:     "some log output",
	})

	if result.Error != "" {
		t.Fatalf("Collect() error = %q", result.Error)
	}
	if result.Label != "general" {
		t.Errorf("Label = %q, want general", result.Label)
	}
}

func TestEvidenceCollector_Collect_RejectsTraversalLabel(t *testing.T) {
	parent := t.TempDir()
	dir := filepath.Join(parent, "project")
	if err := os.MkdirAll(dir, 0o755); err != nil {
		t.Fatal(err)
	}
	outside := filepath.Join(parent, "outside")
	c := &EvidenceCollector{
		nowFunc: func() string { return "2026-04-05T00:00:00Z" },
	}

	labels := []string{
		"../outside",
		"../../../../outside",
		"/tmp/outside",
		"nested/label",
		`nested\label`,
		".",
		"..",
		"label with spaces",
	}

	for _, label := range labels {
		result := c.Collect(CollectOptions{
			ProjectRoot: dir,
			Label:       label,
			Content:     "content",
		})
		if result.Error == "" {
			t.Fatalf("Collect() with label %q succeeded; want security error", label)
		}
		if !strings.Contains(result.Error, "invalid evidence label") {
			t.Fatalf("Collect() error = %q, want invalid evidence label", result.Error)
		}
	}
	if _, err := os.Stat(outside); !os.IsNotExist(err) {
		t.Fatalf("traversal label created outside path %q, stat err=%v", outside, err)
	}
}

func TestEvidenceCollector_Collect_NoContent(t *testing.T) {
	dir := t.TempDir()
	c := &EvidenceCollector{}

	result := c.Collect(CollectOptions{
		ProjectRoot: dir,
		Label:       "test",
	})

	if result.Error == "" {
		t.Error("Expected error for empty content")
	}
	if !strings.Contains(result.Error, "no content") {
		t.Errorf("Error = %q, want 'no content'", result.Error)
	}
}

func TestEvidenceCollector_Collect_FromFile(t *testing.T) {
	dir := t.TempDir()

	// 収集元ファイルを作成
	srcFile := filepath.Join(dir, "build.log")
	if err := os.WriteFile(srcFile, []byte("build output here"), 0600); err != nil {
		t.Fatalf("write source file: %v", err)
	}

	c := &EvidenceCollector{
		nowFunc: func() string { return "2026-04-05T00:00:00Z" },
	}

	result := c.Collect(CollectOptions{
		ProjectRoot: dir,
		Label:       "build",
		ContentFile: srcFile,
	})

	if result.Error != "" {
		t.Fatalf("Collect() error = %q", result.Error)
	}

	data, err := os.ReadFile(result.SavedPath)
	if err != nil {
		t.Fatalf("reading saved file: %v", err)
	}
	if string(data) != "build output here" {
		t.Errorf("file content = %q, want 'build output here'", string(data))
	}
}

func TestEvidenceCollector_Collect_FromFileNotFound(t *testing.T) {
	dir := t.TempDir()
	c := &EvidenceCollector{}

	result := c.Collect(CollectOptions{
		ProjectRoot: dir,
		Label:       "test",
		ContentFile: filepath.Join(dir, "nonexistent.log"),
	})

	if result.Error == "" {
		t.Error("Expected error for nonexistent file")
	}
}

func TestEvidenceCollector_CollectFromStdin(t *testing.T) {
	dir := t.TempDir()
	c := &EvidenceCollector{
		nowFunc: func() string { return "2026-04-05T00:00:00Z" },
	}

	var out bytes.Buffer
	err := c.CollectFromStdin(
		strings.NewReader("stdin content"),
		&out,
		CollectOptions{
			ProjectRoot: dir,
			Label:       "stdin-test",
		},
	)
	if err != nil {
		t.Fatalf("CollectFromStdin() error = %v", err)
	}

	var result CollectResult
	if err := json.Unmarshal(out.Bytes(), &result); err != nil {
		t.Fatalf("unmarshal result: %v", err)
	}
	if result.Error != "" {
		t.Errorf("result error = %q", result.Error)
	}
	if result.SavedPath == "" {
		t.Error("SavedPath should not be empty")
	}
}

func TestEvidenceCollector_CollectFromStdin_RejectsTraversalLabel(t *testing.T) {
	dir := t.TempDir()
	c := &EvidenceCollector{
		nowFunc: func() string { return "2026-04-05T00:00:00Z" },
	}

	var out bytes.Buffer
	err := c.CollectFromStdin(
		strings.NewReader("stdin content"),
		&out,
		CollectOptions{
			ProjectRoot: dir,
			Label:       "../outside",
		},
	)
	if err == nil {
		t.Fatal("CollectFromStdin() error = nil, want invalid evidence label error")
	}
	if !strings.Contains(err.Error(), "invalid evidence label") {
		t.Fatalf("CollectFromStdin() error = %q, want invalid evidence label", err)
	}

	var result CollectResult
	if err := json.Unmarshal(out.Bytes(), &result); err != nil {
		t.Fatalf("unmarshal result: %v", err)
	}
	if !strings.Contains(result.Error, "invalid evidence label") {
		t.Fatalf("result error = %q, want invalid evidence label", result.Error)
	}
	if result.SavedPath != "" {
		t.Fatalf("SavedPath = %q, want empty", result.SavedPath)
	}
}

// ---------------------------------------------------------------------------
// ユーティリティ テスト
// ---------------------------------------------------------------------------

func TestSplitLines(t *testing.T) {
	tests := []struct {
		input string
		want  []string
	}{
		{"a\nb\nc", []string{"a", "b", "c"}},
		{"a\n\nb\n", []string{"a", "b"}},
		{"", []string(nil)},
		{"single", []string{"single"}},
		{"json1\njson2\n", []string{"json1", "json2"}},
	}

	for _, tt := range tests {
		got := splitLines([]byte(tt.input))
		if len(got) != len(tt.want) {
			t.Errorf("splitLines(%q) = %v, want %v", tt.input, got, tt.want)
			continue
		}
		for i := range got {
			if got[i] != tt.want[i] {
				t.Errorf("splitLines(%q)[%d] = %q, want %q", tt.input, i, got[i], tt.want[i])
			}
		}
	}
}
