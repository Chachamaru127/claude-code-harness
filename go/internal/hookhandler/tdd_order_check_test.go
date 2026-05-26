package hookhandler

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// tddOutput is a struct for parsing the tddApproveOutput JSON in tests.
type tddOutput struct {
	Decision      string `json:"decision"`
	Reason        string `json:"reason"`
	SystemMessage string `json:"systemMessage"`
}

func parseTDDOutput(t *testing.T, out *bytes.Buffer) tddOutput {
	t.Helper()
	var result tddOutput
	if err := json.Unmarshal(out.Bytes(), &result); err != nil {
		t.Fatalf("invalid JSON output: %v, raw: %s", err, out.String())
	}
	return result
}

func TestHandleTDDOrderCheck_NoInput(t *testing.T) {
	var out bytes.Buffer
	err := HandleTDDOrderCheck(strings.NewReader(""), &out)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	result := parseTDDOutput(t, &out)
	if result.Decision != "approve" {
		t.Errorf("expected decision=approve, got %q", result.Decision)
	}
	if result.SystemMessage != "" {
		t.Errorf("expected empty systemMessage for empty input, got %q", result.SystemMessage)
	}
}

func TestHandleTDDOrderCheck_NoFilePath(t *testing.T) {
	input := `{"tool_name":"Write","tool_input":{}}`
	var out bytes.Buffer
	if err := HandleTDDOrderCheck(strings.NewReader(input), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	result := parseTDDOutput(t, &out)
	if result.SystemMessage != "" {
		t.Errorf("expected empty systemMessage for no file_path, got %q", result.SystemMessage)
	}
}

func TestHandleTDDOrderCheck_TestFileSkipped(t *testing.T) {
	// Edits to test files are skipped
	cases := []string{
		"src/main.test.ts",
		"src/main.spec.tsx",
		"pkg/util_test.go",
		"tests/test_main.py",
		"src/__tests__/helper.ts",
	}
	for _, filePath := range cases {
		input := `{"tool_name":"Write","tool_input":{"file_path":"` + filePath + `"}}`
		var out bytes.Buffer
		if err := HandleTDDOrderCheck(strings.NewReader(input), &out); err != nil {
			t.Fatalf("unexpected error for %s: %v", filePath, err)
		}
		result := parseTDDOutput(t, &out)
		if result.SystemMessage != "" {
			t.Errorf("expected no warning for test file %s, got %q", filePath, result.SystemMessage)
		}
	}
}

func TestHandleTDDOrderCheck_NonSourceFileSkipped(t *testing.T) {
	// Non-source files are skipped
	cases := []string{
		"README.md",
		"Plans.md",
		"config.yaml",
		"Makefile",
	}
	for _, filePath := range cases {
		input := `{"tool_name":"Write","tool_input":{"file_path":"` + filePath + `"}}`
		var out bytes.Buffer
		if err := HandleTDDOrderCheck(strings.NewReader(input), &out); err != nil {
			t.Fatalf("unexpected error for %s: %v", filePath, err)
		}
		result := parseTDDOutput(t, &out)
		if result.SystemMessage != "" {
			t.Errorf("expected no warning for non-source file %s, got %q", filePath, result.SystemMessage)
		}
	}
}

func TestHandleTDDOrderCheck_NoWIPTask(t *testing.T) {
	tmpDir := t.TempDir()
	origDir, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	if err := os.Chdir(tmpDir); err != nil {
		t.Fatal(err)
	}
	defer os.Chdir(origDir)

	// Skip when Plans.md has no cc:WIP
	if err := os.WriteFile("Plans.md", []byte("| Task | Implement | DoD | - | cc:TODO |\n"), 0o644); err != nil {
		t.Fatal(err)
	}

	input := `{"tool_name":"Write","tool_input":{"file_path":"src/main.ts"}}`
	var out bytes.Buffer
	if err := HandleTDDOrderCheck(strings.NewReader(input), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	result := parseTDDOutput(t, &out)
	if result.SystemMessage != "" {
		t.Errorf("expected no warning when no WIP task, got %q", result.SystemMessage)
	}
}

func TestHandleTDDOrderCheck_SkipTDDMarker(t *testing.T) {
	tmpDir := t.TempDir()
	origDir, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	if err := os.Chdir(tmpDir); err != nil {
		t.Fatal(err)
	}
	defer os.Chdir(origDir)

	// Skip when a [skip:tdd] marker is present
	plansContent := "| Task | Implement [skip:tdd] | DoD | - | cc:WIP |\n"
	if err := os.WriteFile("Plans.md", []byte(plansContent), 0o644); err != nil {
		t.Fatal(err)
	}

	input := `{"tool_name":"Write","tool_input":{"file_path":"src/main.ts"}}`
	var out bytes.Buffer
	if err := HandleTDDOrderCheck(strings.NewReader(input), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	result := parseTDDOutput(t, &out)
	if result.SystemMessage != "" {
		t.Errorf("expected no warning with [skip:tdd] marker, got %q", result.SystemMessage)
	}
}

func TestHandleTDDOrderCheck_WarningEmitted(t *testing.T) {
	tmpDir := t.TempDir()
	origDir, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	if err := os.Chdir(tmpDir); err != nil {
		t.Fatal(err)
	}
	defer os.Chdir(origDir)

	// WIP task present, no test edited, no [skip:tdd] → warning should be emitted
	if err := os.WriteFile("Plans.md", []byte("| Task | Implement | DoD | - | cc:WIP |\n"), 0o644); err != nil {
		t.Fatal(err)
	}

	input := `{"tool_name":"Write","tool_input":{"file_path":"src/main.ts"}}`
	var out bytes.Buffer
	if err := HandleTDDOrderCheck(strings.NewReader(input), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	result := parseTDDOutput(t, &out)

	// Warning should be emitted
	if result.SystemMessage == "" {
		t.Error("expected warning systemMessage, got empty")
	}
	if !strings.Contains(result.SystemMessage, "TDD") {
		t.Errorf("expected 'TDD' in systemMessage, got %q", result.SystemMessage)
	}
	// Should be approve, not block
	if result.Decision != "approve" {
		t.Errorf("expected decision=approve (not block), got %q", result.Decision)
	}
}

func TestHandleTDDOrderCheck_WarningLocaleDefaultEnglish(t *testing.T) {
	t.Setenv("CLAUDE_CODE_HARNESS_LANG", "")
	t.Setenv("HARNESS_PROJECT_ROOT", "")
	t.Setenv("PROJECT_ROOT", "")

	result := runTDDWarningForLocaleTest(t, "")
	if result.Decision != "approve" {
		t.Fatalf("decision = %q, want approve", result.Decision)
	}
	if !strings.Contains(result.SystemMessage, "TDD is enabled by default") {
		t.Fatalf("default systemMessage should be English, got %q", result.SystemMessage)
	}
	if strings.Contains(result.SystemMessage, "テストを先に") {
		t.Fatalf("default systemMessage should not be Japanese, got %q", result.SystemMessage)
	}
}

func TestHandleTDDOrderCheck_WarningLocaleJapaneseEnv(t *testing.T) {
	t.Setenv("CLAUDE_CODE_HARNESS_LANG", "ja")
	t.Setenv("HARNESS_PROJECT_ROOT", "")
	t.Setenv("PROJECT_ROOT", "")

	result := runTDDWarningForLocaleTest(t, "")
	if result.Decision != "approve" {
		t.Fatalf("decision = %q, want approve", result.Decision)
	}
	if !strings.Contains(result.SystemMessage, "TDD はデフォルトで有効です") {
		t.Fatalf("ja env systemMessage should be Japanese, got %q", result.SystemMessage)
	}
}

func TestHandleTDDOrderCheck_WarningLocaleJapaneseConfig(t *testing.T) {
	t.Setenv("CLAUDE_CODE_HARNESS_LANG", "en")
	t.Setenv("HARNESS_PROJECT_ROOT", "")
	t.Setenv("PROJECT_ROOT", "")

	result := runTDDWarningForLocaleTest(t, "i18n:\n  language: ja\n")
	if !strings.Contains(result.SystemMessage, "TDD はデフォルトで有効です") {
		t.Fatalf("config ja systemMessage should be Japanese, got %q", result.SystemMessage)
	}
}

func runTDDWarningForLocaleTest(t *testing.T, config string) tddOutput {
	t.Helper()
	tmpDir := t.TempDir()
	origDir, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	if err := os.Chdir(tmpDir); err != nil {
		t.Fatal(err)
	}
	defer os.Chdir(origDir)

	if config != "" {
		if err := os.WriteFile(harnessConfigFileName, []byte(config), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	if err := os.WriteFile("Plans.md", []byte("| Task | Implement | DoD | - | cc:WIP |\n"), 0o644); err != nil {
		t.Fatal(err)
	}

	input := `{"tool_name":"Write","tool_input":{"file_path":"src/main.ts"}}`
	var out bytes.Buffer
	if err := HandleTDDOrderCheck(strings.NewReader(input), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	return parseTDDOutput(t, &out)
}

func TestHandleTDDOrderCheck_TestAlreadyEdited(t *testing.T) {
	tmpDir := t.TempDir()
	origDir, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	if err := os.Chdir(tmpDir); err != nil {
		t.Fatal(err)
	}
	defer os.Chdir(origDir)

	// WIP task present, test file already recorded in session-changes.json
	if err := os.WriteFile("Plans.md", []byte("| Task | Implement | DoD | - | cc:WIP |\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(".claude/state", 0o755); err != nil {
		t.Fatal(err)
	}
	// Put a test file record into session-changes.json
	sessionContent := `{"files":["src/main.test.ts","src/main.ts"]}`
	if err := os.WriteFile(sessionChangesFile, []byte(sessionContent), 0o644); err != nil {
		t.Fatal(err)
	}

	input := `{"tool_name":"Write","tool_input":{"file_path":"src/main.ts"}}`
	var out bytes.Buffer
	if err := HandleTDDOrderCheck(strings.NewReader(input), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	result := parseTDDOutput(t, &out)
	if result.SystemMessage != "" {
		t.Errorf("expected no warning when test already edited, got %q", result.SystemMessage)
	}
}

func TestHandleTDDOrderCheck_TestAlreadyInChangedFiles(t *testing.T) {
	tmpDir := t.TempDir()
	origDir, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	if err := os.Chdir(tmpDir); err != nil {
		t.Fatal(err)
	}
	defer os.Chdir(origDir)

	// WIP task present, test file record present in changed-files.jsonl
	if err := os.WriteFile("Plans.md", []byte("| Task | Implement | DoD | - | cc:WIP |\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(".claude/state", 0o755); err != nil {
		t.Fatal(err)
	}
	// Put a test file record into changed-files.jsonl
	testEntry := `{"file":"src/main.test.ts","action":"Write","timestamp":"2026-04-09T00:00:00Z","important":true}` + "\n"
	if err := os.WriteFile(changedFilesPath, []byte(testEntry), 0o644); err != nil {
		t.Fatal(err)
	}

	input := `{"tool_name":"Write","tool_input":{"file_path":"src/main.ts"}}`
	var out bytes.Buffer
	if err := HandleTDDOrderCheck(strings.NewReader(input), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	result := parseTDDOutput(t, &out)
	if result.SystemMessage != "" {
		t.Errorf("expected no warning when test in changed-files.jsonl, got %q", result.SystemMessage)
	}
}

func TestIsTestFilePath(t *testing.T) {
	testCases := []struct {
		path     string
		expected bool
	}{
		{"src/main.test.ts", true},
		{"src/main.spec.tsx", true},
		{"pkg/util_test.go", true},
		{"tests/test_main.py", true},
		{"src/__tests__/helper.ts", true},
		{"src/main.ts", false},
		{"src/main.go", false},
		{"src/main.py", false},
		{"src/main.tsx", false},
	}
	for _, c := range testCases {
		got := isTestFilePath(c.path)
		if got != c.expected {
			t.Errorf("isTestFilePath(%q) = %v, want %v", c.path, got, c.expected)
		}
	}
}

func TestIsSourceFilePath(t *testing.T) {
	sourceCases := []struct {
		path     string
		expected bool
	}{
		{"src/main.ts", true},
		{"src/main.tsx", true},
		{"src/main.js", true},
		{"src/main.jsx", true},
		{"src/main.py", true},
		{"src/main.go", true},
		{"src/main.test.ts", false},
		{"src/main.spec.js", false},
		{"pkg/util_test.go", false},
		{"README.md", false},
		{"config.yaml", false},
	}
	for _, c := range sourceCases {
		got := isSourceFilePath(c.path)
		if got != c.expected {
			t.Errorf("isSourceFilePath(%q) = %v, want %v", c.path, got, c.expected)
		}
	}
}

func TestFindCorrespondingTestFile(t *testing.T) {
	cases := []struct {
		filePath string
		expected string
	}{
		{"src/main.ts", "src/main.test.ts"},
		{"src/components/App.tsx", "src/components/App.test.tsx"},
		{"lib/util.js", "lib/util.test.js"},
		{"pkg/main.go", "pkg/main_test.go"},
		{"src/helper.py", "src/test_helper.py"},
	}
	for _, c := range cases {
		got := findCorrespondingTestFile(c.filePath)
		if got != c.expected {
			t.Errorf("findCorrespondingTestFile(%q) = %q, want %q", c.filePath, got, c.expected)
		}
	}
}

// TestHasActiveWIPTask_CustomPlansDirectory verifies that when plansDirectory is configured,
// WIP tasks are detected from Plans.md in the custom directory (P3 fix).
func TestHasActiveWIPTask_CustomPlansDirectory(t *testing.T) {
	dir := t.TempDir()

	// Set plansDirectory: docs in the config file
	configContent := "plansDirectory: docs\n"
	if err := os.WriteFile(filepath.Join(dir, harnessConfigFileName), []byte(configContent), 0o644); err != nil {
		t.Fatal(err)
	}

	// Place Plans.md containing cc:WIP in the docs/ directory
	docsDir := filepath.Join(dir, "docs")
	if err := os.MkdirAll(docsDir, 0o755); err != nil {
		t.Fatal(err)
	}
	plansContent := "| 1 | Task | DoD | none | `cc:WIP` |\n"
	if err := os.WriteFile(filepath.Join(docsDir, "Plans.md"), []byte(plansContent), 0o644); err != nil {
		t.Fatal(err)
	}

	got := hasActiveWIPTask(dir)
	if !got {
		t.Error("expected hasActiveWIPTask=true for WIP task in custom plansDirectory, got false")
	}
}

// TestHasActiveWIPTask_CustomPlansDirectory_NoWIP verifies that false is returned
// when Plans.md in the custom directory does not contain cc:WIP.
func TestHasActiveWIPTask_CustomPlansDirectory_NoWIP(t *testing.T) {
	dir := t.TempDir()

	configContent := "plansDirectory: docs\n"
	if err := os.WriteFile(filepath.Join(dir, harnessConfigFileName), []byte(configContent), 0o644); err != nil {
		t.Fatal(err)
	}

	docsDir := filepath.Join(dir, "docs")
	if err := os.MkdirAll(docsDir, 0o755); err != nil {
		t.Fatal(err)
	}
	plansContent := "| 1 | Task | DoD | none | `cc:TODO` |\n"
	if err := os.WriteFile(filepath.Join(docsDir, "Plans.md"), []byte(plansContent), 0o644); err != nil {
		t.Fatal(err)
	}

	got := hasActiveWIPTask(dir)
	if got {
		t.Error("expected hasActiveWIPTask=false when no WIP task in custom plansDirectory, got true")
	}
}

// TestHasActiveWIPTask_NoPlansFile verifies that false is returned when Plans.md does not exist.
func TestHasActiveWIPTask_NoPlansFile(t *testing.T) {
	dir := t.TempDir()
	// Intentionally do not create Plans.md

	got := hasActiveWIPTask(dir)
	if got {
		t.Error("expected hasActiveWIPTask=false when Plans.md does not exist, got true")
	}
}
