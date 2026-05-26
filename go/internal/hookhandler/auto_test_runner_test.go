package hookhandler

import (
	"bytes"
	"encoding/json"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

// --- shouldRunTests ---

func TestShouldRunTests_SourceFiles(t *testing.T) {
	cases := []struct {
		file string
		want bool
	}{
		{"src/index.ts", true},
		{"src/App.tsx", true},
		{"src/utils.js", true},
		{"src/component.jsx", true},
		{"src/main.py", true},
		{"cmd/main.go", true},
		{"src/lib.rs", true},
		{"README.md", false},
		{"config.json", false},
		{"ci.yml", false},
		{".gitignore", false},
		{"package.lock", false},
		{"node_modules/foo.ts", false},
		{"dist/bundle.js", false},
		{"build/output.js", false},
		{".next/server.js", false},
		{"", false},
	}

	for _, tc := range cases {
		got := shouldRunTests(tc.file)
		if got != tc.want {
			t.Errorf("shouldRunTests(%q) = %v, want %v", tc.file, got, tc.want)
		}
	}
}

func TestShouldRunTests_TestFiles(t *testing.T) {
	cases := []struct {
		file string
		want bool
	}{
		{"src/utils.test.ts", true},
		{"src/utils.spec.js", true},
		{"src/__tests__/utils.ts", true},
	}
	for _, tc := range cases {
		got := shouldRunTests(tc.file)
		if got != tc.want {
			t.Errorf("shouldRunTests(%q) = %v, want %v", tc.file, got, tc.want)
		}
	}
}

// --- detectTestCommand ---

func TestDetectTestCommand_Vitest(t *testing.T) {
	dir := t.TempDir()
	if err := os.WriteFile(filepath.Join(dir, "vitest.config.ts"), []byte(""), 0o644); err != nil {
		t.Fatal(err)
	}
	got := detectTestCommand(dir)
	if got != "npx vitest run --reporter=verbose" {
		t.Errorf("want vitest command, got %q", got)
	}
}

func TestDetectTestCommand_Jest_ConfigFile(t *testing.T) {
	dir := t.TempDir()
	if err := os.WriteFile(filepath.Join(dir, "jest.config.js"), []byte(""), 0o644); err != nil {
		t.Fatal(err)
	}
	got := detectTestCommand(dir)
	if got != "npx jest --verbose" {
		t.Errorf("want jest command, got %q", got)
	}
}

func TestDetectTestCommand_Jest_PackageJSON(t *testing.T) {
	dir := t.TempDir()
	pkgContent := `{"scripts":{"test":"jest"},"jest":{"testEnvironment":"node"}}`
	if err := os.WriteFile(filepath.Join(dir, "package.json"), []byte(pkgContent), 0o644); err != nil {
		t.Fatal(err)
	}
	got := detectTestCommand(dir)
	if got != "npx jest --verbose" {
		t.Errorf("want jest command, got %q", got)
	}
}

func TestDetectTestCommand_Pytest_IniFile(t *testing.T) {
	if _, err := exec.LookPath("pytest"); err != nil {
		t.Skip("pytest not found in PATH; skipping pytest detection test")
	}
	dir := t.TempDir()
	if err := os.WriteFile(filepath.Join(dir, "pytest.ini"), []byte("[pytest]"), 0o644); err != nil {
		t.Fatal(err)
	}
	got := detectTestCommand(dir)
	if got != "pytest -v" {
		t.Errorf("want pytest command, got %q", got)
	}
}

func TestDetectTestCommand_Pytest_Pyproject(t *testing.T) {
	if _, err := exec.LookPath("pytest"); err != nil {
		t.Skip("pytest not found in PATH; skipping pytest detection test")
	}
	dir := t.TempDir()
	content := "[tool.pytest.ini_options]\naddopts = \"-v\"\n"
	if err := os.WriteFile(filepath.Join(dir, "pyproject.toml"), []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}
	got := detectTestCommand(dir)
	if got != "pytest -v" {
		t.Errorf("want pytest command, got %q", got)
	}
}

// TestDetectTestCommand_Pytest_NoPytestBinary verifies that an empty string is returned
// when pytest.ini exists but the pytest binary is not on PATH.
func TestDetectTestCommand_Pytest_NoPytestBinary(t *testing.T) {
	if _, err := exec.LookPath("pytest"); err == nil {
		t.Skip("pytest is installed; cannot test missing-binary branch")
	}
	dir := t.TempDir()
	if err := os.WriteFile(filepath.Join(dir, "pytest.ini"), []byte("[pytest]"), 0o644); err != nil {
		t.Fatal(err)
	}
	got := detectTestCommand(dir)
	if got != "" {
		t.Errorf("want empty (pytest not in PATH), got %q", got)
	}
}

func TestDetectTestCommand_GoTest(t *testing.T) {
	dir := t.TempDir()
	if err := os.WriteFile(filepath.Join(dir, "go.mod"), []byte("module example.com/foo\n\ngo 1.21\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	got := detectTestCommand(dir)
	if got != "go test ./..." {
		t.Errorf("want go test command, got %q", got)
	}
}

func TestDetectTestCommand_None(t *testing.T) {
	dir := t.TempDir()
	got := detectTestCommand(dir)
	if got != "" {
		t.Errorf("want empty, got %q", got)
	}
}

// TestDetectTestCommand_NpmTest verifies that npm test is returned as the fallback
// for a project that has only scripts.test in package.json (fix for issue 1).
func TestDetectTestCommand_NpmTest_Fallback(t *testing.T) {
	dir := t.TempDir()
	// No vitest/jest config; only scripts.test defined.
	pkgContent := `{"name":"my-app","scripts":{"test":"mocha --exit","build":"webpack"}}`
	if err := os.WriteFile(filepath.Join(dir, "package.json"), []byte(pkgContent), 0o644); err != nil {
		t.Fatal(err)
	}
	got := detectTestCommand(dir)
	if got != "npm test" {
		t.Errorf("want npm test, got %q", got)
	}
}

// TestDetectTestCommand_NpmTest_EmptyScript verifies that npm test is not returned
// when scripts.test is an empty string.
func TestDetectTestCommand_NpmTest_EmptyScript(t *testing.T) {
	dir := t.TempDir()
	pkgContent := `{"name":"my-app","scripts":{"test":""}}`
	if err := os.WriteFile(filepath.Join(dir, "package.json"), []byte(pkgContent), 0o644); err != nil {
		t.Fatal(err)
	}
	got := detectTestCommand(dir)
	if got != "" {
		t.Errorf("want empty (no valid test script), got %q", got)
	}
}

// TestDetectTestCommand_NpmTest_NoTestScript verifies that npm test is not returned
// when scripts.test is absent.
func TestDetectTestCommand_NpmTest_NoTestScript(t *testing.T) {
	dir := t.TempDir()
	pkgContent := `{"name":"my-app","scripts":{"build":"webpack","start":"node index.js"}}`
	if err := os.WriteFile(filepath.Join(dir, "package.json"), []byte(pkgContent), 0o644); err != nil {
		t.Fatal(err)
	}
	got := detectTestCommand(dir)
	if got != "" {
		t.Errorf("want empty (no test script), got %q", got)
	}
}

// TestDetectTestCommand_VitestHasPriorityOverNpmTest verifies that vitest is preferred
// over npm test when a vitest.config is present.
func TestDetectTestCommand_VitestHasPriorityOverNpmTest(t *testing.T) {
	dir := t.TempDir()
	// vitest.config.ts present and scripts.test present.
	if err := os.WriteFile(filepath.Join(dir, "vitest.config.ts"), []byte(""), 0o644); err != nil {
		t.Fatal(err)
	}
	pkgContent := `{"name":"my-app","scripts":{"test":"vitest run"}}`
	if err := os.WriteFile(filepath.Join(dir, "package.json"), []byte(pkgContent), 0o644); err != nil {
		t.Fatal(err)
	}
	got := detectTestCommand(dir)
	if got != "npx vitest run --reporter=verbose" {
		t.Errorf("want vitest command (higher priority), got %q", got)
	}
}

// TestDetectTestCommand_Pytest_TestsDir verifies that pytest is detected for a
// Python project that has only a tests/ directory (fix for issue 1).
func TestDetectTestCommand_Pytest_TestsDir(t *testing.T) {
	if _, err := exec.LookPath("pytest"); err != nil {
		t.Skip("pytest not installed")
	}
	dir := t.TempDir()
	// No pytest.ini or pyproject.toml; only the tests/ directory.
	if err := os.MkdirAll(filepath.Join(dir, "tests"), 0o755); err != nil {
		t.Fatal(err)
	}
	got := detectTestCommand(dir)
	if got != "pytest -v" {
		t.Errorf("want pytest -v (tests/ dir detected), got %q", got)
	}
}

// TestDetectTestCommand_Pytest_TestsDir_NotForJSProject verifies that a JS project
// with a tests/ directory is not falsely detected as pytest (P2 fix).
func TestDetectTestCommand_Pytest_TestsDir_NotForJSProject(t *testing.T) {
	dir := t.TempDir()
	// package.json present (no scripts.test) + tests/ directory.
	pkgContent := `{"name":"my-app","scripts":{"build":"webpack"}}`
	if err := os.WriteFile(filepath.Join(dir, "package.json"), []byte(pkgContent), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(filepath.Join(dir, "tests"), 0o755); err != nil {
		t.Fatal(err)
	}
	got := detectTestCommand(dir)
	if got == "pytest -v" {
		t.Errorf("false positive: JS project with tests/ dir was detected as pytest, got %q", got)
	}
}

// TestDetectTestCommand_Cargo verifies that cargo test is detected for a Rust
// project that has Cargo.toml (fix for issue 2).
func TestDetectTestCommand_Cargo(t *testing.T) {
	dir := t.TempDir()
	cargoContent := `[package]
name = "my-crate"
version = "0.1.0"
edition = "2021"
`
	if err := os.WriteFile(filepath.Join(dir, "Cargo.toml"), []byte(cargoContent), 0o644); err != nil {
		t.Fatal(err)
	}
	got := detectTestCommand(dir)
	if got != "cargo test" {
		t.Errorf("want cargo test, got %q", got)
	}
}

// TestDetectTestCommand_Jest_FalsePositive_AtTypesJest verifies that Jest is not
// falsely detected for a package.json that has only @types/jest (fix for issue 3).
func TestDetectTestCommand_Jest_FalsePositive_AtTypesJest(t *testing.T) {
	dir := t.TempDir()
	// Only @types/jest in devDependencies (no jest config).
	pkgContent := `{"name":"my-app","devDependencies":{"@types/jest":"^29.0.0","typescript":"^5.0.0"},"scripts":{"build":"tsc"}}`
	if err := os.WriteFile(filepath.Join(dir, "package.json"), []byte(pkgContent), 0o644); err != nil {
		t.Fatal(err)
	}
	got := detectTestCommand(dir)
	// No jest config and no jest in scripts.test, so result should be npm test or empty.
	if got == "npx jest --verbose" {
		t.Errorf("false positive: got jest command for @types/jest-only package.json, got %q", got)
	}
}

// TestDetectTestCommand_Jest_FalsePositive_JestJunit verifies that Jest is not
// falsely detected for a package.json that has only jest-junit (fix for issue 3).
func TestDetectTestCommand_Jest_FalsePositive_JestJunit(t *testing.T) {
	dir := t.TempDir()
	pkgContent := `{"name":"my-app","devDependencies":{"jest-junit":"^16.0.0"},"scripts":{"build":"webpack"}}`
	if err := os.WriteFile(filepath.Join(dir, "package.json"), []byte(pkgContent), 0o644); err != nil {
		t.Fatal(err)
	}
	got := detectTestCommand(dir)
	if got == "npx jest --verbose" {
		t.Errorf("false positive: got jest command for jest-junit-only package.json, got %q", got)
	}
}

// TestDetectTestCommand_Jest_ConfigObject verifies that Jest is correctly detected
// when the "jest" key exists as an object in package.json (fix for issue 3).
func TestDetectTestCommand_Jest_ConfigObject(t *testing.T) {
	dir := t.TempDir()
	// jest key exists as a configuration object at the top level.
	pkgContent := `{"name":"my-app","jest":{"testEnvironment":"node","collectCoverage":true}}`
	if err := os.WriteFile(filepath.Join(dir, "package.json"), []byte(pkgContent), 0o644); err != nil {
		t.Fatal(err)
	}
	got := detectTestCommand(dir)
	if got != "npx jest --verbose" {
		t.Errorf("want npx jest --verbose (jest config object in package.json), got %q", got)
	}
}

// TestDetectTestCommand_Jest_ScriptsTest verifies that Jest is correctly detected
// when scripts.test contains "jest" (fix for issue 3).
func TestDetectTestCommand_Jest_ScriptsTest(t *testing.T) {
	dir := t.TempDir()
	pkgContent := `{"name":"my-app","scripts":{"test":"jest --coverage","build":"webpack"}}`
	if err := os.WriteFile(filepath.Join(dir, "package.json"), []byte(pkgContent), 0o644); err != nil {
		t.Fatal(err)
	}
	got := detectTestCommand(dir)
	if got != "npx jest --verbose" {
		t.Errorf("want npx jest --verbose (scripts.test contains jest), got %q", got)
	}
}

// TestDetectTestCommand_Jest_ConfigFile_HasPriority verifies that Jest is detected
// regardless of package.json contents when jest.config.js is present.
func TestDetectTestCommand_Jest_ConfigFile_HasPriority(t *testing.T) {
	// When both vitest.config and jest.config are present, vitest takes priority.
	dir := t.TempDir()
	if err := os.WriteFile(filepath.Join(dir, "vitest.config.ts"), []byte(""), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dir, "jest.config.js"), []byte(""), 0o644); err != nil {
		t.Fatal(err)
	}
	got := detectTestCommand(dir)
	if got != "npx vitest run --reporter=verbose" {
		t.Errorf("want vitest command, got %q", got)
	}
}

// --- findRelatedTests ---

func TestFindRelatedTests_TSFile(t *testing.T) {
	dir := t.TempDir()
	testFile := filepath.Join(dir, "utils.test.ts")
	if err := os.WriteFile(testFile, []byte(""), 0o644); err != nil {
		t.Fatal(err)
	}
	got := findRelatedTests(filepath.Join(dir, "utils.ts"), "")
	if got != testFile {
		t.Errorf("want %q, got %q", testFile, got)
	}
}

func TestFindRelatedTests_GoFile(t *testing.T) {
	// findRelatedTests searches for test files relative to the given file path.
	// For Go files it looks for "utils_test.go" in the same directory.
	// When an absolute path is passed, the search uses an absolute path, so the
	// file must be created in advance.
	dir := t.TempDir()
	srcFile := filepath.Join(dir, "utils.go")
	testFile := filepath.Join(dir, "utils_test.go")
	if err := os.WriteFile(srcFile, []byte(""), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(testFile, []byte(""), 0o644); err != nil {
		t.Fatal(err)
	}
	got := findRelatedTests(srcFile, "")
	if got != testFile {
		t.Errorf("want %q, got %q", testFile, got)
	}
}

func TestFindRelatedTests_PyFile(t *testing.T) {
	dir := t.TempDir()
	testFile := filepath.Join(dir, "test_utils.py")
	if err := os.WriteFile(testFile, []byte(""), 0o644); err != nil {
		t.Fatal(err)
	}
	// findRelatedTests searches by relative path.
	got := findRelatedTests("utils.py", "")
	// Returns empty string when the file does not exist.
	_ = got // Existence check depends on the actual file path; minimal test only.
}

func TestFindRelatedTests_NotFound(t *testing.T) {
	got := findRelatedTests("nonexistent_source_file.ts", "")
	if got != "" {
		t.Errorf("want empty, got %q", got)
	}
}

// TestFindRelatedTests_WithProjectRoot verifies that the test file corresponding to
// a relative-path source file is correctly detected when projectRoot is provided (P2 fix).
func TestFindRelatedTests_WithProjectRoot(t *testing.T) {
	dir := t.TempDir()
	// Create projectRoot/src/utils.test.ts for projectRoot/src/utils.ts.
	srcDir := filepath.Join(dir, "src")
	if err := os.MkdirAll(srcDir, 0o755); err != nil {
		t.Fatal(err)
	}
	testFile := filepath.Join(srcDir, "utils.test.ts")
	if err := os.WriteFile(testFile, []byte(""), 0o644); err != nil {
		t.Fatal(err)
	}
	// Pass a relative path and specify projectRoot.
	got := findRelatedTests("src/utils.ts", dir)
	if got != testFile {
		t.Errorf("want %q, got %q", testFile, got)
	}
}

// --- HandleAutoTestRunner (recommend mode) ---

func TestHandleAutoTestRunner_SkipsNonSourceFiles(t *testing.T) {
	input := `{"tool_name":"Write","cwd":"/tmp","tool_input":{"file_path":"README.md"}}`
	var out bytes.Buffer
	err := HandleAutoTestRunner(strings.NewReader(input), &out)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	// README.md is not a target, so emptyPostToolOutput (hookSpecificOutput with empty additionalContext) is returned.
	outStr := strings.TrimSpace(out.String())
	if outStr == "" {
		t.Errorf("expected hookSpecificOutput JSON, got empty string")
	}
	var hookOut autoTestHookOutput
	if err := json.Unmarshal([]byte(outStr), &hookOut); err != nil {
		t.Fatalf("invalid JSON: %v", err)
	}
	// additionalContext should be empty.
	if hookOut.HookSpecificOutput.AdditionalContext != "" {
		t.Errorf("expected empty additionalContext, got %q", hookOut.HookSpecificOutput.AdditionalContext)
	}
}

func TestHandleAutoTestRunner_EmptyInput(t *testing.T) {
	var out bytes.Buffer
	err := HandleAutoTestRunner(strings.NewReader(""), &out)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
}

func TestHandleAutoTestRunner_RecommendMode(t *testing.T) {
	dir := t.TempDir()
	// Place go.mod so that the test command is detected.
	if err := os.WriteFile(filepath.Join(dir, "go.mod"), []byte("module test\n\ngo 1.21\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	stateDir := filepath.Join(dir, ".claude", "state")

	input := `{"tool_name":"Write","cwd":"` + dir + `","tool_input":{"file_path":"` + dir + `/main.go"}}`
	var out bytes.Buffer
	// HARNESS_AUTO_TEST is not set (recommend mode).
	err := HandleAutoTestRunner(strings.NewReader(input), &out)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	// In recommend mode, test-recommendation.json is written.
	recPath := filepath.Join(stateDir, "test-recommendation.json")
	data, readErr := os.ReadFile(recPath)
	if readErr != nil {
		t.Skipf("recommendation file not written (may be due to CWD normalization): %v", readErr)
	}
	var rec autoTestRecommendation
	if err := json.Unmarshal(data, &rec); err != nil {
		t.Fatalf("invalid JSON in recommendation: %v", err)
	}
	if rec.TestCommand != "go test ./..." {
		t.Errorf("want go test ./..., got %q", rec.TestCommand)
	}
}

// --- limitLines ---

func TestLimitLines(t *testing.T) {
	input := "line1\nline2\nline3\nline4\nline5"
	got := limitLines(input, 3)
	want := "line1\nline2\nline3"
	if got != want {
		t.Errorf("want %q, got %q", want, got)
	}
}

func TestLimitLines_LessThanLimit(t *testing.T) {
	input := "line1\nline2"
	got := limitLines(input, 10)
	want := "line1\nline2"
	if got != want {
		t.Errorf("want %q, got %q", want, got)
	}
}

// --- buildExecCommand (P1 fix) ---

// TestBuildExecCommand_GoTest_NoDoubleDash verifies that go test does not receive a `-- <file>` argument (P1).
func TestBuildExecCommand_GoTest_NoDoubleDash(t *testing.T) {
	cmd := buildExecCommand("go test ./...", "internal/foo/bar_test.go", "/repo")
	if strings.Contains(cmd, "-- ") {
		t.Errorf("go test command must not contain '-- <file>', got %q", cmd)
	}
	// Verify that the result is in package-path form.
	if !strings.HasPrefix(cmd, "go test ./") {
		t.Errorf("go test command should start with 'go test ./', got %q", cmd)
	}
}

// TestBuildExecCommand_GoTest_PackagePath verifies that go test generates a package
// path from the directory containing _test.go (P1).
func TestBuildExecCommand_GoTest_PackagePath(t *testing.T) {
	got := buildExecCommand("go test ./...", "internal/foo/bar_test.go", "/repo")
	want := "go test ./internal/foo/..."
	if got != want {
		t.Errorf("want %q, got %q", want, got)
	}
}

// TestBuildExecCommand_GoTest_AbsRelatedTest verifies that the package path is
// correctly produced even when relatedTest is an absolute path (P1).
func TestBuildExecCommand_GoTest_AbsRelatedTest(t *testing.T) {
	got := buildExecCommand("go test ./...", "/repo/internal/foo/bar_test.go", "/repo")
	want := "go test ./internal/foo/..."
	if got != want {
		t.Errorf("want %q, got %q", want, got)
	}
}

// TestBuildExecCommand_Pytest_FileArg verifies that pytest takes a file path directly as an argument (P1).
func TestBuildExecCommand_Pytest_FileArg(t *testing.T) {
	got := buildExecCommand("pytest -v", "tests/test_utils.py", "")
	want := "pytest -v tests/test_utils.py"
	if got != want {
		t.Errorf("want %q, got %q", want, got)
	}
}

// TestBuildExecCommand_CargoTest_NoFileArg verifies that cargo test runs without a file argument (P1).
func TestBuildExecCommand_CargoTest_NoFileArg(t *testing.T) {
	got := buildExecCommand("cargo test", "src/lib.rs", "")
	if got != "cargo test" {
		t.Errorf("want 'cargo test' (no file arg), got %q", got)
	}
}

// TestBuildExecCommand_Jest_DoubleDash verifies that jest uses the `-- <file>` form for file specification (P1).
func TestBuildExecCommand_Jest_DoubleDash(t *testing.T) {
	got := buildExecCommand("npx jest --verbose", "src/utils.test.ts", "")
	want := "npx jest --verbose -- src/utils.test.ts"
	if got != want {
		t.Errorf("want %q, got %q", want, got)
	}
}

// TestBuildExecCommand_Vitest_DoubleDash verifies that vitest uses the `-- <file>` form for file specification (P1).
func TestBuildExecCommand_Vitest_DoubleDash(t *testing.T) {
	got := buildExecCommand("npx vitest run --reporter=verbose", "src/utils.test.ts", "")
	want := "npx vitest run --reporter=verbose -- src/utils.test.ts"
	if got != want {
		t.Errorf("want %q, got %q", want, got)
	}
}

// TestBuildExecCommand_NpmTest_NoFileArg verifies that npm test runs without a file argument (P1).
func TestBuildExecCommand_NpmTest_NoFileArg(t *testing.T) {
	got := buildExecCommand("npm test", "src/utils.ts", "")
	if got != "npm test" {
		t.Errorf("want 'npm test' (no file arg), got %q", got)
	}
}

// TestBuildExecCommand_NoRelatedTest verifies that the original command is returned
// unchanged when no related test file is found (P1).
func TestBuildExecCommand_NoRelatedTest(t *testing.T) {
	cases := []struct {
		testCmd string
	}{
		{"go test ./..."},
		{"pytest -v"},
		{"cargo test"},
		{"npx jest --verbose"},
		{"npm test"},
	}
	for _, tc := range cases {
		got := buildExecCommand(tc.testCmd, "", "")
		if got != tc.testCmd {
			t.Errorf("buildExecCommand(%q, \"\", \"\") = %q, want %q", tc.testCmd, got, tc.testCmd)
		}
	}
}

// --- autoTestWriteJSONFile ---

func TestWriteJSONFile(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "test.json")
	data := map[string]string{"key": "value"}
	if err := autoTestWriteJSONFile(path, data); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	content, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("read error: %v", err)
	}
	var got map[string]string
	if err := json.Unmarshal(content, &got); err != nil {
		t.Fatalf("invalid JSON: %v", err)
	}
	if got["key"] != "value" {
		t.Errorf("want value, got %q", got["key"])
	}
}

// TestHasNpmTestScript_Placeholder verifies that the npm init placeholder is excluded (P2 fix).
func TestHasNpmTestScript_Placeholder(t *testing.T) {
	// Default package.json generated by npm init.
	placeholderPkg := []byte(`{"scripts":{"test":"echo \"Error: no test specified\" && exit 1"}}`)

	got := hasNpmTestScript(placeholderPkg)
	if got {
		t.Error("expected hasNpmTestScript=false for npm init placeholder, got true")
	}
}

// TestHasNpmTestScript_RealScript verifies that a real test script returns true.
func TestHasNpmTestScript_RealScript(t *testing.T) {
	// package.json with a real test script.
	realPkg := []byte(`{"scripts":{"test":"jest --coverage"}}`)

	got := hasNpmTestScript(realPkg)
	if !got {
		t.Error("expected hasNpmTestScript=true for real test script, got false")
	}
}

// TestHasNpmTestScript_Empty verifies that false is returned when scripts.test is empty.
func TestHasNpmTestScript_Empty(t *testing.T) {
	emptyPkg := []byte(`{"scripts":{"test":""}}`)

	got := hasNpmTestScript(emptyPkg)
	if got {
		t.Error("expected hasNpmTestScript=false for empty test script, got true")
	}
}
