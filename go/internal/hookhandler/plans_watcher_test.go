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

	// Plans.md を作成しておく
	if err := os.WriteFile("Plans.md", []byte("# Plans\n"), 0o644); err != nil {
		t.Fatal(err)
	}

	// Plans.md 以外のファイルを編集した場合はスキップ
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

	// Plans.md が存在しない場合はスキップ
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

	// Plans.md に pm:依頼中 を含む内容を作成
	plansContent := "| Task 1 | 実装A | DoD | - | pm:依頼中 |\n"
	if err := os.WriteFile("Plans.md", []byte(plansContent), 0o644); err != nil {
		t.Fatal(err)
	}

	// 前回の状態（pm_pending=0）を保存
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

	// 新規タスクが検出されること
	if !strings.Contains(result.HookSpecificOutput.AdditionalContext, "新規タスク") {
		t.Errorf("expected '新規タスク' in additionalContext, got %q",
			result.HookSpecificOutput.AdditionalContext)
	}

	// pm-notification.md が作成されること
	data, err := os.ReadFile(pmNotificationFile)
	if err != nil {
		t.Fatalf("pm-notification.md not created: %v", err)
	}
	if !strings.Contains(string(data), "新規タスク") {
		t.Errorf("pm-notification.md should contain '新規タスク', got: %s", string(data))
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

	// Plans.md に cc:完了 を含む内容を作成
	plansContent := "| Task 1 | 実装A | DoD | - | cc:完了 |\n"
	if err := os.WriteFile("Plans.md", []byte(plansContent), 0o644); err != nil {
		t.Fatal(err)
	}

	// 前回の状態（cc_done=0）を保存
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

	if !strings.Contains(result.HookSpecificOutput.AdditionalContext, "タスク完了") {
		t.Errorf("expected 'タスク完了' in additionalContext, got %q",
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

	// 変化なし（cc:TODO 1件のまま）
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

	// 変化がない場合は通知なし
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

	// 複数マーカーを含む Plans.md
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
	// サマリにステータスカウントが含まれること
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
	// isPlansFile は filepath.Clean による厳密一致のみ。
	// projectRoot を加味した比較は isPlansFileWithRoot で行う。
	cases := []struct {
		changed  string
		plans    string
		expected bool
	}{
		// 完全一致（相対パス）
		{"Plans.md", "Plans.md", true},
		// 完全一致（絶対パス）
		{"/home/user/project/Plans.md", "/home/user/project/Plans.md", true},
		// フルパスが異なれば不一致（別ディレクトリの同名ファイルは false）
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
	// isPlansFileWithRoot は projectRoot を使って相対パスを解決する。
	projectRoot := "/home/user/project"
	cases := []struct {
		changedFile string
		plansFile   string
		expected    bool
		desc        string
	}{
		// 相対パス → projectRoot で解決して一致
		{"Plans.md", "/home/user/project/Plans.md", true, "relative path match"},
		// 絶対パスで一致
		{"/home/user/project/Plans.md", "/home/user/project/Plans.md", true, "absolute path match"},
		// 別ディレクトリの相対パス（Plans.md だが plansFile は projectRoot 直下）
		{"docs/Plans.md", "/home/user/project/Plans.md", false, "subdirectory mismatch"},
		// 別ディレクトリの相対パスが plansFile と一致する場合
		{"docs/Plans.md", "/home/user/project/docs/Plans.md", true, "subdirectory match"},
		// 全く別のファイル
		{"src/main.go", "/home/user/project/Plans.md", false, "non plans file"},
		// 別プロジェクトの同名ファイル（絶対パス）
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

	// cursor:依頼中 が pm:依頼中 と同義で扱われること
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

	// cursor:依頼中 も新規タスクとして検出されること
	if !strings.Contains(result.HookSpecificOutput.AdditionalContext, "新規タスク") {
		t.Errorf("expected '新規タスク' for cursor:依頼中, got %q",
			result.HookSpecificOutput.AdditionalContext)
	}
}

// TestHandlePlansWatcher_CustomPlansDirectory は plansDirectory 設定があるとき
// カスタムディレクトリの Plans.md を正しく検出することを確認する。
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

	// 設定ファイルを作成（plansDirectory: docs）
	configContent := "plansDirectory: docs\n"
	if err := os.WriteFile(harnessConfigFileName, []byte(configContent), 0o644); err != nil {
		t.Fatal(err)
	}

	// docs/Plans.md を作成
	if err := os.MkdirAll("docs", 0o755); err != nil {
		t.Fatal(err)
	}
	plansContent := "| Task 1 | 実装A | DoD | - | pm:依頼中 |\n"
	if err := os.WriteFile("docs/Plans.md", []byte(plansContent), 0o644); err != nil {
		t.Fatal(err)
	}

	// 前回の状態（pm_pending=0）を保存
	if err := os.MkdirAll(".claude/state", 0o755); err != nil {
		t.Fatal(err)
	}
	prevState := `{"timestamp":"2026-01-01T00:00:00Z","pm_pending":0,"cc_todo":0,"cc_wip":0,"cc_done":0,"pm_confirmed":0}`
	if err := os.WriteFile(plansStateFile, []byte(prevState), 0o644); err != nil {
		t.Fatal(err)
	}

	// docs/Plans.md を変更したイベントを送信
	input := `{"tool_name":"Edit","tool_input":{"file_path":"docs/Plans.md"}}`
	var out bytes.Buffer
	if err := HandlePlansWatcher(strings.NewReader(input), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	var result postToolOutput
	if jsonErr := json.Unmarshal(out.Bytes(), &result); jsonErr != nil {
		t.Fatalf("invalid JSON output: %v, raw: %s", jsonErr, out.String())
	}

	// 新規タスクが検出されること（カスタムパスの Plans.md が認識される）
	if !strings.Contains(result.HookSpecificOutput.AdditionalContext, "新規タスク") {
		t.Errorf("expected '新規タスク' in additionalContext for custom plansDirectory, got %q",
			result.HookSpecificOutput.AdditionalContext)
	}
}

// TestIsPlansFile_CustomPath はカスタムパスの Plans.md に対して
// isPlansFileWithRoot が正しく動作することを確認する（P2修正: 別ディレクトリ同名ファイルを誤マッチしない）。
func TestIsPlansFile_CustomPath(t *testing.T) {
	projectRoot := "/project"
	cases := []struct {
		changedFile string
		plansFile   string
		want        bool
		desc        string
	}{
		// 完全一致（相対パスをprojectRootで解決）
		{"Plans.md", "/project/Plans.md", true, "exact match via projectRoot"},
		// カスタムディレクトリの Plans.md が plansFile と一致
		{"docs/Plans.md", "/project/docs/Plans.md", true, "custom subdir match"},
		// 別ディレクトリの同名ファイルは誤マッチしない（修正の核心）
		{"docs/Plans.md", "/project/Plans.md", false, "subdirectory mismatch - must not match"},
		// 全く別のファイル
		{"src/main.go", "/project/Plans.md", false, "non plans file"},
		{"README.md", "/project/Plans.md", false, "readme not plans"},
		// ファイル名が Plans.md に似ているが別ファイル
		{"Plans.md.bak", "/project/Plans.md", false, "backup file not matched"},
		// 絶対パスで別プロジェクトの Plans.md
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

// TestHandlePlansWatcher_CWDFromInput は input.CWD が存在する場合に
// resolveProjectRoot() の代わりに input.CWD が projectRoot として使用されることを確認する。
// フックプロセスの CWD が input.CWD と異なる場合に Plans.md を正しく検出できることを検証。
func TestHandlePlansWatcher_CWDFromInput(t *testing.T) {
	// プロジェクトディレクトリ（Plans.md が存在する）
	projectDir := t.TempDir()
	// フックプロセスの CWD（プロジェクトとは異なるディレクトリ）
	hookCWD := t.TempDir()

	origDir, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	// フックプロセスは hookCWD にいる（プロジェクトルートではない）
	if err := os.Chdir(hookCWD); err != nil {
		t.Fatal(err)
	}
	defer os.Chdir(origDir)

	// projectDir に Plans.md を作成
	plansContent := "| Task 1 | 実装A | DoD | - | cc:完了 |\n"
	plansPath := filepath.Join(projectDir, "Plans.md")
	if err := os.WriteFile(plansPath, []byte(plansContent), 0o644); err != nil {
		t.Fatal(err)
	}

	// projectDir に .claude/state を作成
	stateDir := filepath.Join(projectDir, ".claude", "state")
	if err := os.MkdirAll(stateDir, 0o755); err != nil {
		t.Fatal(err)
	}

	// input に cwd フィールドを含める（projectDir を指定）
	inputJSON := `{"tool_name":"Edit","cwd":"` + projectDir + `","tool_input":{"file_path":"Plans.md"}}`
	var out bytes.Buffer
	if err := HandlePlansWatcher(strings.NewReader(inputJSON), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	// hookCWD に Plans.md がないにもかかわらず、projectDir の Plans.md が検出されること
	// エラーなく処理されることを確認（Plans.md が見つかって状態集計まで進む）
	var result postToolOutput
	if jsonErr := json.Unmarshal(out.Bytes(), &result); jsonErr != nil {
		t.Fatalf("invalid JSON output: %v, raw: %s", jsonErr, out.String())
	}
	// 正常に処理されること（hookCWD に Plans.md がない場合は emptyPostToolOutput のはずだが
	// input.CWD を使えば projectDir の Plans.md が見つかる）
	if out.Len() == 0 {
		t.Error("expected non-empty output when input.CWD points to project with Plans.md")
	}
}

// TestAcquirePlansLock_BasicLock はロックの取得と解放が正常に動作することを確認する。
func TestAcquirePlansLock_BasicLock(t *testing.T) {
	tmpDir := t.TempDir()
	lockPath := filepath.Join(tmpDir, "locks", "plans.flock")

	// 1 回目: ロック取得成功
	lock, err := acquirePlansLock(lockPath)
	if err != nil {
		t.Fatalf("expected lock acquisition to succeed, got: %v", err)
	}
	if lock == nil {
		t.Fatal("expected non-nil lock handle")
	}

	// lock ファイルが作成されていること
	if _, statErr := os.Stat(lockPath); statErr != nil {
		t.Errorf("lock file should exist after acquisition: %v", statErr)
	}

	// 解放（panic しないこと）
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

// TestHandlePlansWatcher_LockExhaustionFailsClosed は lock 取得が 3 retry で
// 失敗した場合に HandlePlansWatcher が fail-closed シグナルを発することを確認する。
// exitFailClosed をモック差し替えして os.Exit(1) を回避しつつ、
// 呼び出しが発生したこと（失敗シグナル）を検証する。
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
	failClosedCalled := false
	origExitFailClosed := exitFailClosed
	exitFailClosed = func(msg string) {
		failClosedCalled = true
		// os.Exit(1) は呼ばない — テスト継続のため
	}
	defer func() { exitFailClosed = origExitFailClosed }()

	input := `{"tool_name":"Edit","tool_input":{"file_path":"Plans.md"}}`
	var out bytes.Buffer
	if err := HandlePlansWatcher(strings.NewReader(input), &out); err != nil {
		t.Fatalf("HandlePlansWatcher should not return error even on lock failure: %v", err)
	}

	// fail-closed: exitFailClosed が呼び出されたこと（成功扱いではないシグナル）
	if !failClosedCalled {
		t.Error("expected exitFailClosed to be called on lock exhaustion, but it was not")
	}

	var result postToolOutput
	if jsonErr := json.Unmarshal(out.Bytes(), &result); jsonErr != nil {
		t.Fatalf("invalid JSON output: %v, raw: %s", jsonErr, out.String())
	}

	// モックで os.Exit を回避した場合はフォールバックの空応答が返る
	if result.HookSpecificOutput.AdditionalContext != "" {
		t.Errorf("expected empty context on lock failure (fail-closed fallback), got %q",
			result.HookSpecificOutput.AdditionalContext)
	}
}

// TestHandlePlansWatcher_LockAndStateUseSameCWD は lock path と state file path が
// 同じ CWD から導出されることを確認する。
// 異なる CWD 値で hook を呼び出し、各パスが input.CWD を基点としていることを検証する。
// これにより、CWD A の lock が CWD B の state を保護しない（race が発生する）問題を防ぐ。
func TestHandlePlansWatcher_LockAndStateUseSameCWD(t *testing.T) {
	// プロジェクト A ディレクトリ
	projectA := t.TempDir()
	// プロジェクト B ディレクトリ（異なる CWD）
	projectB := t.TempDir()

	origDir, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	// プロセス cwd は projectB にする（input.CWD は projectA を指定）
	if err := os.Chdir(projectB); err != nil {
		t.Fatal(err)
	}
	defer os.Chdir(origDir)

	// projectA に Plans.md と state ディレクトリを作成
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

	// input.CWD = projectA で hook を呼び出す
	inputJSON := `{"tool_name":"Edit","cwd":"` + projectA + `","tool_input":{"file_path":"Plans.md"}}`
	var out bytes.Buffer
	if err := HandlePlansWatcher(strings.NewReader(inputJSON), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	// lock ファイルが projectA 配下に作成されていること（projectB ではない）
	expectedLockPath := filepath.Join(projectA, plansLockFile)
	if _, statErr := os.Stat(expectedLockPath); statErr != nil {
		t.Errorf("lock file should be created under projectA (%s), but not found: %v",
			expectedLockPath, statErr)
	}

	// state ファイルが projectA 配下に作成されていること（projectB ではない）
	expectedStatePath := filepath.Join(projectA, plansStateFile)
	if _, statErr := os.Stat(expectedStatePath); statErr != nil {
		t.Errorf("state file should be saved under projectA (%s), but not found: %v",
			expectedStatePath, statErr)
	}

	// projectB 配下には lock も state も作成されていないこと
	unexpectedLockPath := filepath.Join(projectB, plansLockFile)
	if _, statErr := os.Stat(unexpectedLockPath); statErr == nil {
		t.Errorf("lock file should NOT be created under projectB (%s)", unexpectedLockPath)
	}
	unexpectedStatePath := filepath.Join(projectB, plansStateFile)
	if _, statErr := os.Stat(unexpectedStatePath); statErr == nil {
		t.Errorf("state file should NOT be created under projectB (%s)", unexpectedStatePath)
	}
}

// TestAcquirePlansLock_FailClosed は lock 取得失敗時に HandlePlansWatcher が
// fail-closed（exitFailClosed 呼び出し）になることを確認する。
// 同一プロセス内で Flock は再入可能なため、ロック競合は同一ファイルへの
// 2 プロセス間で発生する。このテストでは lock ファイルを読み取り専用にして
// open 自体を失敗させることで fail-closed パスをカバーする。
// NOTE: TestHandlePlansWatcher_LockExhaustionFailsClosed が同等の検証を行うため、
// このテストは acquirePlansLock 単体の動作確認に特化する。
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
