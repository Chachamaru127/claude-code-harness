package hookhandler

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

// autoTestRunnerInput is the stdin JSON passed from the PostToolUse hook.
type autoTestRunnerInput struct {
	ToolName  string `json:"tool_name"`
	CWD       string `json:"cwd"`
	ToolInput struct {
		FilePath string `json:"file_path"`
	} `json:"tool_input"`
	ToolResponse struct {
		FilePath string `json:"filePath"`
	} `json:"tool_response"`
}

// autoTestResult is written to .claude/state/test-result.json.
type autoTestResult struct {
	Timestamp   string `json:"timestamp"`
	ChangedFile string `json:"changed_file"`
	Command     string `json:"command"`
	Status      string `json:"status"`
	ExitCode    int    `json:"exit_code"`
	Output      string `json:"output"`
}

// autoTestRecommendation is written to .claude/state/test-recommendation.json.
type autoTestRecommendation struct {
	Timestamp      string `json:"timestamp"`
	ChangedFile    string `json:"changed_file"`
	TestCommand    string `json:"test_command"`
	RelatedTest    string `json:"related_test"`
	Recommendation string `json:"recommendation"`
}

// autoTestHookOutput is the hookSpecificOutput with an additionalContext field.
type autoTestHookOutput struct {
	HookSpecificOutput struct {
		HookEventName     string `json:"hookEventName"`
		AdditionalContext string `json:"additionalContext"`
	} `json:"hookSpecificOutput"`
}

// sourceFileExtensions lists file extensions that require test execution.
var sourceFileExtensions = []string{
	".ts", ".tsx", ".js", ".jsx", ".py", ".go", ".rs",
}

// excludedDirs lists directory prefixes excluded from test runs.
var excludedDirs = []string{
	"node_modules/",
	"dist/",
	"build/",
	".next/",
}

// excludedExtensions lists file extensions excluded from test runs.
var excludedExtensions = []string{
	".md", ".json", ".yml", ".yaml", ".lock",
}

// HandleAutoTestRunner is a Go port of auto-test-runner.sh.
//
// On PostToolUse Write/Edit events it detects source file changes,
// auto-detects the test framework, and runs tests.
//
// Modes:
//   - HARNESS_AUTO_TEST=run → actually runs tests and reports via additionalContext
//   - default (recommend)  → records a test recommendation in .claude/state/
func HandleAutoTestRunner(in io.Reader, out io.Writer) error {
	data, err := io.ReadAll(in)
	if err != nil || len(bytes.TrimSpace(data)) == 0 {
		return emptyPostToolOutput(out)
	}

	var input autoTestRunnerInput
	if err := json.Unmarshal(data, &input); err != nil {
		return emptyPostToolOutput(out)
	}

	// Get the changed file.
	changedFile := input.ToolInput.FilePath
	if changedFile == "" {
		changedFile = input.ToolResponse.FilePath
	}
	if changedFile == "" {
		return emptyPostToolOutput(out)
	}

	// Normalize to a project-relative path.
	changedFile = normalizePathSeparators(changedFile)
	if input.CWD != "" {
		cwd := normalizePathSeparators(input.CWD)
		changedFile = makeRelativePath(changedFile, cwd)
	}

	// Determine the project root (CWD or current directory).
	projectRoot := input.CWD
	if projectRoot == "" {
		projectRoot, _ = os.Getwd()
	}

	// Determine whether tests need to be run.
	if !shouldRunTests(changedFile) {
		return emptyPostToolOutput(out)
	}

	// Detect the test command.
	testCmd := detectTestCommand(projectRoot)
	if testCmd == "" {
		return emptyPostToolOutput(out)
	}

	// Detect related test files (P2 fix: pass projectRoot).
	relatedTest := findRelatedTests(changedFile, projectRoot)

	stateDir := filepath.Join(projectRoot, ".claude", "state")
	if err := os.MkdirAll(stateDir, 0o755); err != nil {
		return emptyPostToolOutput(out)
	}

	// If HARNESS_AUTO_TEST=run, actually run the tests.
	if os.Getenv("HARNESS_AUTO_TEST") == "run" {
		return runTestsAndReport(out, projectRoot, stateDir, changedFile, testCmd, relatedTest)
	}

	// Default: recommend mode.
	return writeTestRecommendation(out, stateDir, changedFile, testCmd, relatedTest)
}

// shouldRunTests reports whether the file requires a test run.
func shouldRunTests(file string) bool {
	if file == "" {
		return false
	}

	// Excluded directory check.
	for _, dir := range excludedDirs {
		if strings.HasPrefix(file, dir) {
			return false
		}
	}

	// Excluded extension check.
	for _, ext := range excludedExtensions {
		if strings.HasSuffix(file, ext) {
			return false
		}
	}

	// .gitignore
	if file == ".gitignore" {
		return false
	}

	// Changes to test files themselves.
	if strings.Contains(file, ".test.") || strings.Contains(file, ".spec.") || strings.Contains(file, "__tests__") {
		return true
	}

	// Changes to source code files.
	for _, ext := range sourceFileExtensions {
		if strings.HasSuffix(file, ext) {
			return true
		}
	}

	return false
}

// detectTestCommand auto-detects the test command from the project root.
//
// Detection priority (P2 fix: JS frameworks → Python → Rust → Go,
// pytest detection via tests/ applies only when no package.json is present):
//  1. vitest.config.* → npx vitest run --reporter=verbose
//  2. jest.config.* → npx jest --verbose
//  3. package.json jest key / scripts.test containing jest → npx jest --verbose
//  4. package.json scripts.test (npm test fallback) → npm test
//  5. pytest.ini → pytest -v
//  6. pyproject.toml [tool.pytest] → pytest -v
//  7. tests/ directory (only when no package.json) → pytest -v
//  8. Cargo.toml → cargo test
//  9. go.mod → go test ./...
func detectTestCommand(projectRoot string) string {
	// vitest
	vitestConfigs := []string{
		"vitest.config.ts", "vitest.config.js", "vitest.config.mts", "vitest.config.mjs",
	}
	for _, cfg := range vitestConfigs {
		if autoTestFileExists(filepath.Join(projectRoot, cfg)) {
			return "npx vitest run --reporter=verbose"
		}
	}

	// jest: detection via config file (no false positives).
	jestConfigs := []string{
		"jest.config.ts", "jest.config.js", "jest.config.mjs", "jest.config.cjs",
	}
	for _, cfg := range jestConfigs {
		if autoTestFileExists(filepath.Join(projectRoot, cfg)) {
			return "npx jest --verbose"
		}
	}

	// Detect JS/Node projects that have a package.json.
	// Check package.json first to handle jest detection and the npm test fallback together,
	// and to prevent false pytest detection (P2) for tests/ directories.
	pkgPath := filepath.Join(projectRoot, "package.json")
	hasPkgJSON := autoTestFileExists(pkgPath)
	if hasPkgJSON {
		content, err := os.ReadFile(pkgPath)
		if err == nil {
			// jest: detect via JSON parse of package.json.
			// Treat as Jest only when a top-level "jest" key exists as an object,
			// or when scripts.test contains the string "jest".
			// Prevents false positives from dependency package names like @types/jest or jest-junit.
			if hasJestConfig(content) {
				return "npx jest --verbose"
			}
			// npm test fallback.
			if hasNpmTestScript(content) {
				return "npm test"
			}
		}
	}

	// pytest-family frameworks: return only when the pytest binary is on PATH.
	// Even if a framework config file exists, the command cannot run without an install,
	// so check with LookPath first.
	if _, pytestErr := exec.LookPath("pytest"); pytestErr == nil {
		// pytest.ini
		if autoTestFileExists(filepath.Join(projectRoot, "pytest.ini")) {
			return "pytest -v"
		}
		// pyproject.toml [tool.pytest]
		pyprojectPath := filepath.Join(projectRoot, "pyproject.toml")
		if autoTestFileExists(pyprojectPath) {
			content, err := os.ReadFile(pyprojectPath)
			if err == nil && bytes.Contains(content, []byte("[tool.pytest")) {
				return "pytest -v"
			}
		}
		// Python project with a tests/ directory but no config file.
		// Do not apply to JS projects that have package.json.
		if !hasPkgJSON {
			if autoTestFileExists(filepath.Join(projectRoot, "tests")) {
				if info, err := os.Stat(filepath.Join(projectRoot, "tests")); err == nil && info.IsDir() {
					return "pytest -v"
				}
			}
		}
	}

	// Rust project with Cargo.toml.
	if autoTestFileExists(filepath.Join(projectRoot, "Cargo.toml")) {
		return "cargo test"
	}

	// go test: check whether go.mod exists.
	if autoTestFileExists(filepath.Join(projectRoot, "go.mod")) {
		return "go test ./..."
	}

	return ""
}

// hasJestConfig checks via JSON parsing whether Jest is configured in the package.json content.
//
// Returns true when any of the following hold:
//   - A top-level "jest" key exists as an object (Jest configuration object).
//   - The value of scripts.test contains the string "jest".
//
// Prevents false positives that would occur with a plain string search on
// dependency package names such as @types/jest or jest-junit.
func hasJestConfig(content []byte) bool {
	var pkg map[string]json.RawMessage
	if err := json.Unmarshal(content, &pkg); err != nil {
		return false
	}

	// Check whether a "jest" key exists as a top-level object.
	if jestRaw, ok := pkg["jest"]; ok {
		// Check whether the value is an object (Jest configuration).
		var jestObj map[string]json.RawMessage
		if json.Unmarshal(jestRaw, &jestObj) == nil {
			return true
		}
	}

	// Check whether scripts.test contains "jest".
	scriptsRaw, ok := pkg["scripts"]
	if !ok {
		return false
	}
	var scripts map[string]interface{}
	if err := json.Unmarshal(scriptsRaw, &scripts); err != nil {
		return false
	}
	if testVal, ok := scripts["test"]; ok {
		if testStr, ok := testVal.(string); ok && strings.Contains(testStr, "jest") {
			return true
		}
	}

	return false
}

// hasNpmTestScript checks whether scripts.test is defined in the package.json content.
func hasNpmTestScript(content []byte) bool {
	var pkg map[string]json.RawMessage
	if err := json.Unmarshal(content, &pkg); err != nil {
		return false
	}
	scriptsRaw, ok := pkg["scripts"]
	if !ok {
		return false
	}
	var scripts map[string]interface{}
	if err := json.Unmarshal(scriptsRaw, &scripts); err != nil {
		return false
	}
	testVal, ok := scripts["test"]
	if !ok {
		return false
	}
	// Exclude empty strings and npm init placeholders even when the "test" key exists.
	testStr, ok := testVal.(string)
	if !ok || strings.TrimSpace(testStr) == "" {
		return false
	}
	// Do not treat the default value generated by npm init as a real test script.
	if strings.Contains(testStr, "Error: no test specified") {
		return false
	}
	return true
}

// findRelatedTests finds the test file corresponding to the changed file.
//
// P2 fix: accepts projectRoot; when the file is a relative path,
// uses filepath.Join(projectRoot, file) as the base for locating test files.
// This ensures correct test detection even when the harness binary is launched
// from outside the repository root.
func findRelatedTests(file, projectRoot string) string {
	// When file is not an absolute path, join with projectRoot to obtain an
	// absolute path to use as the pattern base.
	absFile := file
	if !filepath.IsAbs(file) && projectRoot != "" {
		absFile = filepath.Join(projectRoot, file)
	}

	ext := filepath.Ext(absFile)
	basename := strings.TrimSuffix(absFile, ext)
	dirname := filepath.Dir(absFile)
	baseName := filepath.Base(basename)

	patterns := []string{
		basename + ".test.ts",
		basename + ".test.tsx",
		basename + ".test.js",
		basename + ".test.jsx",
		basename + ".spec.ts",
		basename + ".spec.tsx",
		basename + ".spec.js",
		basename + ".spec.jsx",
		filepath.Join(dirname, "__tests__", baseName+".test.ts"),
		filepath.Join(dirname, "__tests__", baseName+".test.tsx"),
		filepath.Join(dirname, "test_"+baseName+".py"),
		basename + "_test.go",
	}

	for _, pattern := range patterns {
		if autoTestFileExists(pattern) {
			return pattern
		}
	}
	return ""
}

// buildExecCommand returns the execution command, branching on how each test
// runner accepts file arguments.
//
// P1 fix: `go test` does not accept `-- <file>` arguments, so branch per runner.
//
//   - go test    : go test ./path/to/pkg/... (converted to a package path)
//   - pytest     : pytest path/to/test_file.py
//   - cargo test : cargo test (no file argument)
//   - jest/vitest: npx jest -- path/to/test.ts / npx vitest run -- path/to/test.ts
//   - npm test   : npm test (no file argument)
func buildExecCommand(testCmd, relatedTest, projectRoot string) string {
	if relatedTest == "" {
		return testCmd
	}

	switch {
	case strings.HasPrefix(testCmd, "go test"):
		// go test takes a <package path> argument.
		// When relatedTest is an absolute path, convert it back to a relative path from
		// projectRoot before turning it into a package path.
		rel := relatedTest
		if filepath.IsAbs(relatedTest) && projectRoot != "" {
			if r, err := filepath.Rel(projectRoot, relatedTest); err == nil {
				rel = r
			}
		}
		// Build the package path for the directory that contains the _test.go file.
		// Example: internal/foo/bar_test.go → go test ./internal/foo/...
		pkgDir := filepath.Dir(rel)
		return "go test ./" + filepath.ToSlash(pkgDir) + "/..."

	case strings.HasPrefix(testCmd, "pytest"):
		// pytest accepts a file path directly as an argument.
		return testCmd + " " + relatedTest

	case strings.HasPrefix(testCmd, "cargo test"):
		// cargo test does not support per-file specification; run without a file argument.
		return testCmd

	case strings.HasPrefix(testCmd, "npx jest"),
		strings.HasPrefix(testCmd, "npx vitest"):
		// jest/vitest can narrow down test files with the `-- <file>` form.
		return testCmd + " -- " + relatedTest

	case strings.HasPrefix(testCmd, "npm test"):
		// The file-specification interface for npm test is undefined; run without a file argument.
		return testCmd

	default:
		// For unknown runners, fall back to the safe side with no file argument.
		return testCmd
	}
}

// runTestsAndReport runs the tests, records the result, and reports via additionalContext.
func runTestsAndReport(out io.Writer, projectRoot, stateDir, changedFile, testCmd, relatedTest string) error {
	// Determine the execution command (P1 fix: branch file argument per runner).
	execCmd := buildExecCommand(testCmd, relatedTest, projectRoot)

	ts := time.Now().UTC().Format(time.RFC3339)

	// Run tests with a timeout (maximum 60 seconds).
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()

	cmd := exec.CommandContext(ctx, "bash", "-c", execCmd) //nolint:gosec
	cmd.Dir = projectRoot

	var buf bytes.Buffer
	cmd.Stdout = &buf
	cmd.Stderr = &buf

	runErr := cmd.Run()
	exitCode := 0
	status := "passed"

	if ctx.Err() == context.DeadlineExceeded {
		exitCode = 124
		status = "timeout"
	} else if runErr != nil {
		if exitErr, ok := runErr.(*exec.ExitError); ok {
			exitCode = exitErr.ExitCode()
		} else {
			exitCode = 1
		}
		status = "failed"
	}

	// Limit output to a maximum of 200 lines.
	output := limitLines(buf.String(), 200)

	// Write the result as JSON.
	resultPath := filepath.Join(stateDir, "test-result.json")
	result := autoTestResult{
		Timestamp:   ts,
		ChangedFile: changedFile,
		Command:     execCmd,
		Status:      status,
		ExitCode:    exitCode,
		Output:      output,
	}
	if err := autoTestWriteJSONFile(resultPath, result); err != nil {
		fmt.Fprintf(os.Stderr, "[auto-test-runner] write result: %v\n", err)
	}

	// Build the additionalContext message.
	var contextMsg string
	outputSnippet := limitLines(output, 30)

	switch status {
	case "passed":
		contextMsg = fmt.Sprintf("[Auto Test Runner] Tests passed\nCommand: %s\nFile: %s\nStatus: PASSED (exit=0)",
			testCmd, changedFile)
	case "timeout":
		contextMsg = fmt.Sprintf("[Auto Test Runner] Tests timed out (60s)\nCommand: %s\nFile: %s\nStatus: TIMEOUT\n\nOutput:\n%s",
			testCmd, changedFile, outputSnippet)
	default:
		contextMsg = fmt.Sprintf("[Auto Test Runner] Tests failed\nCommand: %s\nFile: %s\nStatus: FAILED (exit=%d)\n\nOutput:\n%s\n\nFix the implementation to make the tests pass.",
			testCmd, changedFile, exitCode, outputSnippet)
	}

	var hookOut autoTestHookOutput
	hookOut.HookSpecificOutput.HookEventName = "PostToolUse"
	hookOut.HookSpecificOutput.AdditionalContext = contextMsg

	return json.NewEncoder(out).Encode(hookOut)
}

// writeTestRecommendation records a test recommendation (recommend mode).
func writeTestRecommendation(out io.Writer, stateDir, changedFile, testCmd, relatedTest string) error {
	ts := time.Now().UTC().Format(time.RFC3339)
	recPath := filepath.Join(stateDir, "test-recommendation.json")
	rec := autoTestRecommendation{
		Timestamp:      ts,
		ChangedFile:    changedFile,
		TestCommand:    testCmd,
		RelatedTest:    relatedTest,
		Recommendation: "Running tests is recommended",
	}
	if err := autoTestWriteJSONFile(recPath, rec); err != nil {
		fmt.Fprintf(os.Stderr, "[auto-test-runner] write recommendation: %v\n", err)
	}

	// In recommend mode, return an empty PostToolUse output.
	return emptyPostToolOutput(out)
}

// autoTestFileExists reports whether the file at path exists.
func autoTestFileExists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}

// limitLines limits text to a maximum of n lines.
func limitLines(text string, n int) string {
	scanner := bufio.NewScanner(strings.NewReader(text))
	var lines []string
	for scanner.Scan() {
		lines = append(lines, scanner.Text())
		if len(lines) >= n {
			break
		}
	}
	return strings.Join(lines, "\n")
}

// autoTestWriteJSONFile JSON-encodes v and writes it to the file at path.
func autoTestWriteJSONFile(path string, v interface{}) error {
	data, err := json.MarshalIndent(v, "", "  ")
	if err != nil {
		return fmt.Errorf("marshal: %w", err)
	}
	if err := os.WriteFile(path, append(data, '\n'), 0o644); err != nil {
		return fmt.Errorf("write: %w", err)
	}
	return nil
}
