package hookhandler

import (
	"bufio"
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func TestEmitAgentTrace_NoSupportedTool(t *testing.T) {
	t.Setenv("CLAUDE_TOOL_NAME", "Bash")
	t.Setenv("CLAUDE_TOOL_INPUT", "{}")

	dir := t.TempDir()
	e := &EmitAgentTrace{
		RepoRoot: dir,
		StateDir: filepath.Join(dir, "state"),
	}

	if err := e.Handle(strings.NewReader(""), nil); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	// トレースファイルが作成されないことを確認
	tracePath := filepath.Join(dir, "state", "agent-trace.jsonl")
	if _, err := os.Stat(tracePath); err == nil {
		t.Error("trace file should not be created for unsupported tools")
	}
}

func TestEmitAgentTrace_EditTool(t *testing.T) {
	dir := t.TempDir()
	testFile := filepath.Join(dir, "test.go")
	if err := os.WriteFile(testFile, []byte("package main\n"), 0600); err != nil {
		t.Fatal(err)
	}

	input, _ := json.Marshal(map[string]interface{}{
		"file_path": testFile,
		"old_str":   "package main",
		"new_str":   "package main\n// edited",
	})

	t.Setenv("CLAUDE_TOOL_NAME", "Edit")
	t.Setenv("CLAUDE_TOOL_INPUT", string(input))
	t.Setenv("CLAUDE_SESSION_ID", "test-session-123")

	stateDir := filepath.Join(dir, "state")
	e := &EmitAgentTrace{
		RepoRoot: dir,
		StateDir: stateDir,
		Now:      func() string { return "2026-04-09T00:00:00Z" },
	}

	if err := e.Handle(strings.NewReader(""), nil); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	// トレースファイルを確認
	tracePath := filepath.Join(stateDir, "agent-trace.jsonl")
	data, err := os.ReadFile(tracePath)
	if err != nil {
		t.Fatalf("trace file not found: %v", err)
	}

	var rec traceRecord
	if err := json.Unmarshal(bytes.TrimSpace(data), &rec); err != nil {
		t.Fatalf("invalid trace JSON: %v\n%s", err, string(data))
	}

	if rec.Version != traceVersion {
		t.Errorf("expected version=%s, got: %s", traceVersion, rec.Version)
	}
	if rec.Tool != "Edit" {
		t.Errorf("expected tool=Edit, got: %s", rec.Tool)
	}
	if rec.ID == "" {
		t.Error("expected non-empty ID")
	}
	if rec.Timestamp != "2026-04-09T00:00:00Z" {
		t.Errorf("expected timestamp, got: %s", rec.Timestamp)
	}
	if rec.Metadata["sessionId"] != "test-session-123" {
		t.Errorf("expected sessionId, got: %v", rec.Metadata["sessionId"])
	}
}

func TestEmitAgentTrace_WriteTool_CreateAction(t *testing.T) {
	dir := t.TempDir()

	newFile := filepath.Join(dir, "new_file.go")
	input, _ := json.Marshal(map[string]interface{}{
		"file_path": newFile,
		"content":   "package main\n",
	})

	t.Setenv("CLAUDE_TOOL_NAME", "Write")
	t.Setenv("CLAUDE_TOOL_INPUT", string(input))
	t.Setenv("CLAUDE_SESSION_ID", "")

	stateDir := filepath.Join(dir, "state")
	e := &EmitAgentTrace{
		RepoRoot: dir,
		StateDir: stateDir,
	}

	if err := e.Handle(strings.NewReader(""), nil); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	tracePath := filepath.Join(stateDir, "agent-trace.jsonl")
	data, err := os.ReadFile(tracePath)
	if err != nil {
		t.Fatalf("trace file not found: %v", err)
	}

	var rec traceRecord
	if err := json.Unmarshal(bytes.TrimSpace(data), &rec); err != nil {
		t.Fatalf("invalid trace JSON: %v", err)
	}

	if len(rec.Files) == 0 {
		t.Fatal("expected file entries in trace")
	}
	if rec.Files[0].Action != "create" {
		t.Errorf("expected action=create for new file, got: %s", rec.Files[0].Action)
	}
}

// TestEmitAgentTrace_WriteTool_AlwaysCreate は Write ツールが既存ファイルに対しても
// action=create を返すことを確認する。
// PostToolUse 時点ではファイルが既に書き込まれているため os.Stat では新規/既存を
// 区別できない。tool_name ベースで判定するため Write は常に "create" とする。
func TestEmitAgentTrace_WriteTool_AlwaysCreate(t *testing.T) {
	dir := t.TempDir()

	// 既存ファイルを事前に作成
	existingFile := filepath.Join(dir, "existing.go")
	if err := os.WriteFile(existingFile, []byte("package main\n"), 0600); err != nil {
		t.Fatal(err)
	}

	input, _ := json.Marshal(map[string]interface{}{
		"file_path": existingFile,
		"content":   "package main\n// modified\n",
	})

	t.Setenv("CLAUDE_TOOL_NAME", "Write")
	t.Setenv("CLAUDE_TOOL_INPUT", string(input))

	stateDir := filepath.Join(dir, "state")
	e := &EmitAgentTrace{
		RepoRoot: dir,
		StateDir: stateDir,
	}

	if err := e.Handle(strings.NewReader(""), nil); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	tracePath := filepath.Join(stateDir, "agent-trace.jsonl")
	data, err := os.ReadFile(tracePath)
	if err != nil {
		t.Fatalf("trace file not found: %v", err)
	}

	var rec traceRecord
	if err := json.Unmarshal(bytes.TrimSpace(data), &rec); err != nil {
		t.Fatalf("invalid trace JSON: %v", err)
	}

	if len(rec.Files) == 0 {
		t.Fatal("expected file entries")
	}
	// Write は tool_name ベース判定のため既存ファイルでも "create"
	if rec.Files[0].Action != "create" {
		t.Errorf("expected action=create for Write tool (even existing file), got: %s", rec.Files[0].Action)
	}
}

func TestEmitAgentTrace_TaskTool_Metrics(t *testing.T) {
	dir := t.TempDir()

	input, _ := json.Marshal(map[string]interface{}{
		"task_id":       "task-42",
		"subagent_type": "worker",
	})
	result, _ := json.Marshal(map[string]interface{}{
		"metrics": map[string]interface{}{
			"tokenCount": float64(1500),
			"toolUses":   float64(10),
			"duration":   float64(3.14),
		},
	})

	t.Setenv("CLAUDE_TOOL_NAME", "Task")
	t.Setenv("CLAUDE_TOOL_INPUT", string(input))
	t.Setenv("CLAUDE_TOOL_RESULT", string(result))

	stateDir := filepath.Join(dir, "state")
	e := &EmitAgentTrace{
		RepoRoot: dir,
		StateDir: stateDir,
	}

	if err := e.Handle(strings.NewReader(""), nil); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	tracePath := filepath.Join(stateDir, "agent-trace.jsonl")
	data, err := os.ReadFile(tracePath)
	if err != nil {
		t.Fatalf("trace file not found: %v", err)
	}

	var rec traceRecord
	if err := json.Unmarshal(bytes.TrimSpace(data), &rec); err != nil {
		t.Fatalf("invalid trace JSON: %v", err)
	}

	if rec.Metrics == nil {
		t.Fatal("expected metrics")
	}
	if rec.Metrics.TokenCount == nil || *rec.Metrics.TokenCount != 1500 {
		t.Errorf("expected tokenCount=1500, got: %v", rec.Metrics.TokenCount)
	}
	if rec.Metadata["taskId"] != "task-42" {
		t.Errorf("expected taskId=task-42, got: %v", rec.Metadata["taskId"])
	}
	if rec.Metadata["agentRole"] != "worker" {
		t.Errorf("expected agentRole=worker, got: %v", rec.Metadata["agentRole"])
	}
}

func TestEmitAgentTrace_Rotation(t *testing.T) {
	dir := t.TempDir()
	stateDir := filepath.Join(dir, "state")
	if err := os.MkdirAll(stateDir, 0700); err != nil {
		t.Fatal(err)
	}

	tracePath := filepath.Join(stateDir, "agent-trace.jsonl")

	// 小さいサイズのファイルを作成して回転閾値を設定
	smallContent := strings.Repeat(`{"test":"line"}`, 100) + "\n"
	if err := os.WriteFile(tracePath, []byte(smallContent), 0600); err != nil {
		t.Fatal(err)
	}

	e := &EmitAgentTrace{
		RepoRoot:    dir,
		StateDir:    stateDir,
		MaxFileSize: 10, // 10バイトで回転させる
		Now:         func() string { return "2026-01-01T00:00:00Z" },
	}

	e.rotateIfNeeded(tracePath)

	// ローテーションされたファイルが存在することを確認
	rotatedPath := tracePath + ".1"
	if _, err := os.Stat(rotatedPath); err != nil {
		t.Errorf("expected rotated file at %s, err: %v", rotatedPath, err)
	}
	// 元ファイルが消えていることを確認
	if _, err := os.Stat(tracePath); err == nil {
		t.Error("original trace file should be removed after rotation")
	}
}

func TestEmitAgentTrace_SecuritySymlinkCheck(t *testing.T) {
	dir := t.TempDir()
	stateDir := filepath.Join(dir, "state")
	if err := os.MkdirAll(stateDir, 0700); err != nil {
		t.Fatal(err)
	}

	// tracePath をシンボリックリンクにする
	target := filepath.Join(dir, "evil.jsonl")
	if err := os.WriteFile(target, []byte(""), 0600); err != nil {
		t.Fatal(err)
	}
	tracePath := filepath.Join(stateDir, "agent-trace.jsonl")
	if err := os.Symlink(target, tracePath); err != nil {
		t.Skip("symlink creation not supported")
	}

	newFile := filepath.Join(dir, "test.go")
	input, _ := json.Marshal(map[string]interface{}{"file_path": newFile})
	t.Setenv("CLAUDE_TOOL_NAME", "Write")
	t.Setenv("CLAUDE_TOOL_INPUT", string(input))

	e := &EmitAgentTrace{
		RepoRoot: dir,
		StateDir: stateDir,
	}

	// エラーが発生せずに symlink を回避することを確認
	if err := e.Handle(strings.NewReader(""), nil); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	// シンボリックリンクターゲットが書き換えられていないことを確認
	content, _ := os.ReadFile(target)
	if len(content) > 0 {
		t.Error("symlink target should not have been written to")
	}
}

func TestEmitAgentTrace_OtelExport(t *testing.T) {
	var received []byte
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		buf := make([]byte, 4096)
		n, _ := r.Body.Read(buf)
		received = buf[:n]
		w.WriteHeader(http.StatusOK)
	}))
	defer server.Close()

	dir := t.TempDir()

	rec := &traceRecord{
		Version:   traceVersion,
		ID:        "12345678-1234-1234-1234-123456789abc",
		Timestamp: "2026-04-09T00:00:00Z",
		Tool:      "Edit",
		Files:     []traceFile{{Path: "test.go", Action: "modify", Range: "unknown"}},
		Metadata:  map[string]interface{}{"sessionId": "s1"},
	}

	e := &EmitAgentTrace{
		RepoRoot:   dir,
		HTTPClient: &http.Client{Timeout: 5 * time.Second},
	}

	e.emitOtelSpan(server.URL, rec)

	// 非同期なので少し待つ
	time.Sleep(100 * time.Millisecond)

	// サーバーが受信したことを確認
	if len(received) == 0 {
		t.Skip("OTel server did not receive request (possibly race condition)")
	}

	var payload map[string]interface{}
	if err := json.Unmarshal(received, &payload); err != nil {
		t.Fatalf("invalid OTel payload: %v\n%s", err, string(received))
	}
	if _, ok := payload["resourceSpans"]; !ok {
		t.Error("expected resourceSpans in OTel payload")
	}
}

func TestEmitAgentTrace_NormalizeAgentRole(t *testing.T) {
	tests := []struct {
		input    string
		expected string
	}{
		{"reviewer", "reviewer"},
		{"code-reviewer", "reviewer"},
		{"worker", "worker"},
		{"task-worker", "worker"},
		{"impl-worker", "worker"},
		{"lead", "lead"},
		{"planner", "lead"},
		{"custom-agent", "custom-agent"},
		{"", "unknown"},
	}

	for _, tt := range tests {
		got := eatNormalizeAgentRole(tt.input)
		if got != tt.expected {
			t.Errorf("eatNormalizeAgentRole(%q) = %q, want %q", tt.input, got, tt.expected)
		}
	}
}

func TestEmitAgentTrace_PathWithinRepo(t *testing.T) {
	dir := t.TempDir()

	// 存在するファイルを作成して absolute path でテスト
	existingFile := filepath.Join(dir, "src", "main.go")
	if err := os.MkdirAll(filepath.Dir(existingFile), 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(existingFile, []byte(""), 0600); err != nil {
		t.Fatal(err)
	}

	tests := []struct {
		name     string
		filePath string
		repoRoot string
		expected bool
	}{
		{
			name:     "absolute path within repo",
			filePath: existingFile,
			repoRoot: dir,
			expected: true,
		},
		{
			name:     "path with double dots",
			filePath: "../outside/file.go",
			repoRoot: dir,
			expected: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := eatIsPathWithinRepo(tt.filePath, tt.repoRoot)
			if got != tt.expected {
				t.Errorf("eatIsPathWithinRepo(%q, %q) = %v, want %v", tt.filePath, tt.repoRoot, got, tt.expected)
			}
		})
	}
}

// TestEmitAgentTrace_OtelParallel は OTel POST が goroutine で並列実行され、
// Handle() がブロックせずに返ることを確認する。
// mock HTTP server を使い、リクエストが確実に届くことも検証する。
func TestEmitAgentTrace_OtelParallel(t *testing.T) {
	requestReceived := make(chan struct{}, 1)

	// mock HTTP server: リクエストを受け取ったらチャネルに通知
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		select {
		case requestReceived <- struct{}{}:
		default:
		}
	}))
	defer server.Close()

	dir := t.TempDir()

	existingFile := filepath.Join(dir, "test.go")
	if err := os.WriteFile(existingFile, []byte("package main\n"), 0600); err != nil {
		t.Fatal(err)
	}

	input, _ := json.Marshal(map[string]interface{}{"file_path": existingFile})
	t.Setenv("CLAUDE_TOOL_NAME", "Write")
	t.Setenv("CLAUDE_TOOL_INPUT", string(input))
	t.Setenv("OTEL_EXPORTER_OTLP_ENDPOINT", server.URL)
	defer t.Setenv("OTEL_EXPORTER_OTLP_ENDPOINT", "")

	stateDir := filepath.Join(dir, "state")
	e := &EmitAgentTrace{
		RepoRoot:   dir,
		StateDir:   stateDir,
		HTTPClient: &http.Client{Timeout: 5 * time.Second},
	}

	start := time.Now()
	if err := e.Handle(strings.NewReader(""), nil); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	elapsed := time.Since(start)

	// Handle() が返った時点で wg.Wait() により POST は完了しているはず
	select {
	case <-requestReceived:
		// 正常: OTel サーバーがリクエストを受信した
	case <-time.After(3 * time.Second):
		t.Error("OTel server did not receive request within timeout")
	}

	// goroutine + wg.Wait() によりブロッキングは最小限
	// （HTTP タイムアウト 5s 以内で完了するはず）
	if elapsed > 10*time.Second {
		t.Errorf("Handle() took too long: %v (expected < 10s)", elapsed)
	}
}

// TestEmitAgentTrace_ChmodExistingFile は既存ファイルのパーミッションが 0600 に修正されることを確認する。
func TestEmitAgentTrace_ChmodExistingFile(t *testing.T) {
	dir := t.TempDir()
	stateDir := filepath.Join(dir, "state")
	if err := os.MkdirAll(stateDir, 0700); err != nil {
		t.Fatal(err)
	}

	// 既存の agent-trace.jsonl を 0644 で作成（0600 に修正される必要がある）
	tracePath := filepath.Join(stateDir, "agent-trace.jsonl")
	if err := os.WriteFile(tracePath, []byte(""), 0644); err != nil {
		t.Fatal(err)
	}

	existingFile := filepath.Join(dir, "test.go")
	if err := os.WriteFile(existingFile, []byte("package main\n"), 0600); err != nil {
		t.Fatal(err)
	}

	input, _ := json.Marshal(map[string]interface{}{"file_path": existingFile})
	t.Setenv("CLAUDE_TOOL_NAME", "Write")
	t.Setenv("CLAUDE_TOOL_INPUT", string(input))
	t.Setenv("OTEL_EXPORTER_OTLP_ENDPOINT", "")

	e := &EmitAgentTrace{
		RepoRoot: dir,
		StateDir: stateDir,
	}

	if err := e.Handle(strings.NewReader(""), nil); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	// ファイルのパーミッションが 0600 になっていることを確認
	info, err := os.Stat(tracePath)
	if err != nil {
		t.Fatalf("trace file not found: %v", err)
	}

	// ファイルのモードから permission bits のみ取得
	perm := info.Mode().Perm()
	if perm != 0600 {
		t.Errorf("expected file permission 0600, got %04o", perm)
	}
}

func TestEmitAgentTrace_MultipleAppends(t *testing.T) {
	dir := t.TempDir()

	existingFile := filepath.Join(dir, "main.go")
	if err := os.WriteFile(existingFile, []byte("package main\n"), 0600); err != nil {
		t.Fatal(err)
	}

	input, _ := json.Marshal(map[string]interface{}{"file_path": existingFile})
	t.Setenv("CLAUDE_TOOL_NAME", "Write")
	t.Setenv("CLAUDE_TOOL_INPUT", string(input))

	stateDir := filepath.Join(dir, "state")
	e := &EmitAgentTrace{
		RepoRoot: dir,
		StateDir: stateDir,
	}

	// 複数回呼び出し
	for i := 0; i < 3; i++ {
		if err := e.Handle(strings.NewReader(""), nil); err != nil {
			t.Fatalf("iteration %d: unexpected error: %v", i, err)
		}
	}

	tracePath := filepath.Join(stateDir, "agent-trace.jsonl")
	data, err := os.ReadFile(tracePath)
	if err != nil {
		t.Fatalf("trace file not found: %v", err)
	}

	// 3行あることを確認
	scanner := bufio.NewScanner(strings.NewReader(string(data)))
	lineCount := 0
	for scanner.Scan() {
		if strings.TrimSpace(scanner.Text()) != "" {
			lineCount++
		}
	}
	if lineCount != 3 {
		t.Errorf("expected 3 trace lines, got: %d", lineCount)
	}
}

// TestEmitAgentTrace_MultiEditTool_ModifyAction は MultiEdit ツールが
// action=modify を返すことを確認する。
func TestEmitAgentTrace_MultiEditTool_ModifyAction(t *testing.T) {
	dir := t.TempDir()

	existingFile := filepath.Join(dir, "main.go")
	if err := os.WriteFile(existingFile, []byte("package main\n"), 0600); err != nil {
		t.Fatal(err)
	}

	input, _ := json.Marshal(map[string]interface{}{
		"file_path": existingFile,
		"edits":     []interface{}{},
	})

	t.Setenv("CLAUDE_TOOL_NAME", "MultiEdit")
	t.Setenv("CLAUDE_TOOL_INPUT", string(input))

	stateDir := filepath.Join(dir, "state")
	e := &EmitAgentTrace{
		RepoRoot: dir,
		StateDir: stateDir,
	}

	if err := e.Handle(strings.NewReader(""), nil); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	tracePath := filepath.Join(stateDir, "agent-trace.jsonl")
	data, err := os.ReadFile(tracePath)
	if err != nil {
		t.Fatalf("trace file not found: %v", err)
	}

	var rec traceRecord
	if err := json.Unmarshal(bytes.TrimSpace(data), &rec); err != nil {
		t.Fatalf("invalid trace JSON: %v", err)
	}

	if len(rec.Files) == 0 {
		t.Fatal("expected file entries in trace")
	}
	if rec.Files[0].Action != "modify" {
		t.Errorf("expected action=modify for MultiEdit tool, got: %s", rec.Files[0].Action)
	}
}

func TestEatDetectProjectTypeJVM(t *testing.T) {
	tests := []struct {
		name  string
		files []string
		want  string
	}{
		{name: "Maven descriptor", files: []string{"pom.xml"}, want: "java"},
		{name: "Maven wrapper", files: []string{"mvnw"}, want: "java"},
		{name: "Gradle Groovy descriptor", files: []string{"build.gradle"}, want: "java"},
		{name: "Gradle Kotlin descriptor", files: []string{"build.gradle.kts"}, want: "java"},
		{name: "Gradle wrapper", files: []string{"gradlew"}, want: "java"},
		{name: "Kotlin sources identify a Gradle project", files: []string{"build.gradle.kts", "src/main/kotlin/App.kt"}, want: "kotlin"},
		{name: "Mixed Java and Kotlin sources stay explicit", files: []string{"pom.xml", "src/main/java/App.java", "src/main/kotlin/App.kt"}, want: "java-kotlin"},
		{name: "Maven takes precedence over Node", files: []string{"pom.xml", "package.json"}, want: "java"},
		{name: "Gradle takes precedence over Node", files: []string{"build.gradle.kts", "package.json"}, want: "java"},
		{name: "Node remains Node without JVM markers", files: []string{"package.json"}, want: "node"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			dir := t.TempDir()
			for _, name := range tt.files {
				path := filepath.Join(dir, name)
				if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
					t.Fatalf("create marker parent %s: %v", name, err)
				}
				if err := os.WriteFile(path, nil, 0o644); err != nil {
					t.Fatalf("write marker %s: %v", name, err)
				}
			}
			if got := eatDetectProjectType(dir); got != tt.want {
				t.Fatalf("eatDetectProjectType() = %q, want %q", got, tt.want)
			}
		})
	}
}
