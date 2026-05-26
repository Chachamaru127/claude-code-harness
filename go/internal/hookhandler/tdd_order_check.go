package hookhandler

import (
	"encoding/json"
	"io"
	"os"
	"path/filepath"
	"regexp"
	"strings"
)

// tddCheckInput is the stdin JSON passed to tdd-order-check.sh.
type tddCheckInput struct {
	ToolName  string `json:"tool_name"`
	ToolInput struct {
		FilePath string `json:"file_path"`
	} `json:"tool_input"`
}

// tddApproveOutput is the approval response format for PreToolUse / PostToolUse hooks.
// tdd-order-check.sh does not block; it emits a warning via systemMessage.
type tddApproveOutput struct {
	Decision      string `json:"decision"`
	Reason        string `json:"reason"`
	SystemMessage string `json:"systemMessage,omitempty"`
}

// sourceFileExts is the source file extension pattern subject to TDD checks.
var sourceFileExts = regexp.MustCompile(`\.(ts|tsx|js|jsx|py|go)$`)

// testFilePatterns is the list of regular expression patterns used to identify test files.
var testFilePatterns = []*regexp.Regexp{
	regexp.MustCompile(`\.(test|spec)\.(ts|tsx|js|jsx)$`),
	regexp.MustCompile(`_test\.go$`),
	regexp.MustCompile(`test_.*\.py$`),
	regexp.MustCompile(`__tests__/`),
	regexp.MustCompile(`/tests?/`),
}

// tddSkipMarkerRe is the pattern to detect the [skip:tdd] + cc:WIP combination in Plans.md.
var tddSkipMarkerRe = regexp.MustCompile(`\[skip:tdd\].*cc:WIP|cc:WIP.*\[skip:tdd\]`)

// sessionChangesFile is the file path that records files edited during the session.
const sessionChangesFile = ".claude/state/session-changes.json"

func tddWarningMessage(locale string) string {
	return localizedHarnessMessage(locale,
		"TDD is enabled by default. Write the test first when possible.\n\n"+
			"You edited an implementation file, but the corresponding test file has not been edited yet.\n\n"+
			"Recommended: create or update a test file (*.test.ts, *.spec.ts, *_test.go, test_*.py) before implementing the source change.\n\n"+
			"To skip this reminder, add a [skip:tdd] marker to the relevant task in Plans.md.\n\n"+
			"This is a warning only; it does not block the tool call.",
		"TDD はデフォルトで有効です。テストを先に書くことを推奨します。\n\n"+
			"現在、本体ファイルを編集しましたが、対応するテストファイルがまだ編集されていません。\n\n"+
			"推奨: テストファイル（*.test.ts, *.spec.ts, *_test.go, test_*.py）を先に作成してから、本体を実装してください。\n\n"+
			"スキップする場合は Plans.md の該当タスクに [skip:tdd] マーカーを追加してください。\n\n"+
			"これは警告であり、ブロックはしません。")
}

// HandleTDDOrderCheck is a Go port of tdd-order-check.sh.
//
// Called on PostToolUse Write/Edit events, it detects whether an implementation
// file was edited before the corresponding test file.
//
// Behavior:
//   - When a source file (.ts, .js, .tsx, .jsx, .py, .go) is edited
//   - A cc:WIP task exists in Plans.md
//   - No [skip:tdd] marker is present
//   - No test file has been edited during the session
//     → warns via systemMessage about TDD order recommendation (does not block)
func HandleTDDOrderCheck(in io.Reader, out io.Writer) error {
	data, err := io.ReadAll(in)
	if err != nil {
		return writeTDDApprove(out, "")
	}

	if len(strings.TrimSpace(string(data))) == 0 {
		return writeTDDApprove(out, "")
	}

	var input tddCheckInput
	if err := json.Unmarshal(data, &input); err != nil {
		return writeTDDApprove(out, "")
	}

	filePath := input.ToolInput.FilePath
	if filePath == "" {
		return writeTDDApprove(out, "")
	}

	// Skip test files themselves
	if isTestFilePath(filePath) {
		return writeTDDApprove(out, "")
	}

	// Skip if not a source file
	if !isSourceFilePath(filePath) {
		return writeTDDApprove(out, "")
	}

	// Skip if no cc:WIP task exists
	projectRoot := resolveProjectRoot()
	if !hasActiveWIPTask(projectRoot) {
		return writeTDDApprove(out, "")
	}

	// Skip if [skip:tdd] marker is present
	if isTDDSkipped(projectRoot) {
		return writeTDDApprove(out, "")
	}

	// Skip if a test file was already edited during the session
	if testEditedThisSession() {
		return writeTDDApprove(out, "")
	}

	// Emit warning (does not block)
	return writeTDDApprove(out, tddWarningMessage(resolveHarnessLocale(projectRoot)))
}

// writeTDDApprove writes an approve response.
// If systemMessage is empty, approves without a warning.
func writeTDDApprove(out io.Writer, systemMessage string) error {
	o := tddApproveOutput{
		Decision: "approve",
		Reason:   "TDD reminder",
	}
	if systemMessage != "" {
		o.SystemMessage = systemMessage
	}
	data, err := json.Marshal(o)
	if err != nil {
		return err
	}
	_, err = out.Write(append(data, '\n'))
	return err
}

// isTestFilePath reports whether a file path refers to a test file.
// Patterns: *.test.ts, *.spec.ts, *_test.go, test_*.py, __tests__/, /tests?/
func isTestFilePath(filePath string) bool {
	for _, re := range testFilePatterns {
		if re.MatchString(filePath) {
			return true
		}
	}
	return false
}

// isSourceFilePath reports whether a file path refers to a source file.
// Covers .ts, .tsx, .js, .jsx, .py, .go — excluding test files.
func isSourceFilePath(filePath string) bool {
	return sourceFileExts.MatchString(filePath) && !isTestFilePath(filePath)
}

// hasActiveWIPTask reports whether a cc:WIP task exists in Plans.md.
// If projectRoot is empty, resolveProjectRoot() is used to determine the current directory.
// Returns false when resolvePlansPath returns an empty string (Plans.md does not exist).
func hasActiveWIPTask(projectRoot string) bool {
	if projectRoot == "" {
		projectRoot = resolveProjectRoot()
	}
	plansPath := resolvePlansPath(projectRoot)
	if plansPath == "" {
		return false
	}
	data, err := os.ReadFile(plansPath)
	if err != nil {
		return false
	}
	return strings.Contains(string(data), "cc:WIP")
}

// isTDDSkipped reports whether the cc:WIP task in Plans.md has a [skip:tdd] marker.
// If projectRoot is empty, resolveProjectRoot() is used to determine the current directory.
// Returns false when resolvePlansPath returns an empty string (Plans.md does not exist).
func isTDDSkipped(projectRoot string) bool {
	if projectRoot == "" {
		projectRoot = resolveProjectRoot()
	}
	plansPath := resolvePlansPath(projectRoot)
	if plansPath == "" {
		return false
	}
	data, err := os.ReadFile(plansPath)
	if err != nil {
		return false
	}
	return tddSkipMarkerRe.Match(data)
}

// testEditedThisSession reports whether a test file was edited during the session.
// Reads .claude/state/session-changes.json (returns false if the file does not exist).
func testEditedThisSession() bool {
	data, err := os.ReadFile(sessionChangesFile)
	if err != nil {
		// If session-changes.json is absent, also check changed-files.jsonl
		return testEditedInChangedFiles()
	}
	content := string(data)
	return strings.Contains(content, ".test.") ||
		strings.Contains(content, ".spec.") ||
		strings.Contains(content, "_test.") ||
		strings.Contains(content, "test_") ||
		strings.Contains(content, "__tests__")
}

// testEditedInChangedFiles reads .claude/state/changed-files.jsonl to check
// whether a test file was edited during the session.
func testEditedInChangedFiles() bool {
	data, err := os.ReadFile(changedFilesPath)
	if err != nil {
		return false
	}

	lines := strings.Split(string(data), "\n")
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}
		var entry changedFileEntry
		if err := json.Unmarshal([]byte(line), &entry); err != nil {
			continue
		}
		if isTestFilePath(entry.File) {
			return true
		}
	}
	return false
}

// findCorrespondingTestFile infers the test file path that corresponds to an implementation file.
// Example: src/main.ts → src/main.test.ts
func findCorrespondingTestFile(filePath string) string {
	ext := filepath.Ext(filePath)
	base := strings.TrimSuffix(filePath, ext)

	switch ext {
	case ".ts", ".tsx":
		return base + ".test" + ext
	case ".js", ".jsx":
		return base + ".test" + ext
	case ".go":
		return base + "_test.go"
	case ".py":
		dir := filepath.Dir(filePath)
		name := filepath.Base(filePath)
		return filepath.Join(dir, "test_"+name)
	}
	return ""
}
