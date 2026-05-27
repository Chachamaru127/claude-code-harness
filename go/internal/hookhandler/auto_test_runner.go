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

// autoTestRunnerInput は PostToolUse フックから渡される stdin JSON。
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

// autoTestResult は .claude/state/test-result.json に書き出す構造体。
type autoTestResult struct {
	Timestamp   string `json:"timestamp"`
	ChangedFile string `json:"changed_file"`
	Command     string `json:"command"`
	Status      string `json:"status"`
	ExitCode    int    `json:"exit_code"`
	Output      string `json:"output"`
}

// autoTestRecommendation は .claude/state/test-recommendation.json に書き出す構造体。
type autoTestRecommendation struct {
	Timestamp      string `json:"timestamp"`
	ChangedFile    string `json:"changed_file"`
	TestCommand    string `json:"test_command"`
	RelatedTest    string `json:"related_test"`
	Recommendation string `json:"recommendation"`
}

type autoTestCommandInvocation struct {
	Name    string
	Args    []string
	Display string
}

// autoTestHookOutput は additionalContext 付きの hookSpecificOutput。
type autoTestHookOutput struct {
	HookSpecificOutput struct {
		HookEventName     string `json:"hookEventName"`
		AdditionalContext string `json:"additionalContext"`
	} `json:"hookSpecificOutput"`
}

// sourceFileExtensions はテスト実行が必要なファイル拡張子。
var sourceFileExtensions = []string{
	".ts", ".tsx", ".js", ".jsx", ".py", ".go", ".rs",
}

// excludedDirs はテスト対象から除外するディレクトリプレフィックス。
var excludedDirs = []string{
	"node_modules/",
	"dist/",
	"build/",
	".next/",
}

// excludedExtensions はテスト対象から除外するファイル拡張子。
var excludedExtensions = []string{
	".md", ".json", ".yml", ".yaml", ".lock",
}

// HandleAutoTestRunner は auto-test-runner.sh の Go 移植。
//
// PostToolUse Write/Edit イベントでソースファイル変更を検出し、
// テストフレームワークを自動検出してテストを実行する。
//
// 動作モード:
//   - HARNESS_AUTO_TEST=run → テストを実際に実行し、additionalContext で通知
//   - デフォルト (recommend) → テスト推奨を .claude/state/ に記録
func HandleAutoTestRunner(in io.Reader, out io.Writer) error {
	data, err := io.ReadAll(in)
	if err != nil || len(bytes.TrimSpace(data)) == 0 {
		return emptyPostToolOutput(out)
	}

	var input autoTestRunnerInput
	if err := json.Unmarshal(data, &input); err != nil {
		return emptyPostToolOutput(out)
	}

	// 変更ファイルを取得
	changedFile := input.ToolInput.FilePath
	if changedFile == "" {
		changedFile = input.ToolResponse.FilePath
	}
	if changedFile == "" {
		return emptyPostToolOutput(out)
	}

	// プロジェクト相対パスへ正規化
	changedFile = normalizePathSeparators(changedFile)
	if input.CWD != "" {
		cwd := normalizePathSeparators(input.CWD)
		changedFile = makeRelativePath(changedFile, cwd)
	}

	// プロジェクトルートを決定（CWD またはカレントディレクトリ）
	projectRoot := input.CWD
	if projectRoot == "" {
		projectRoot, _ = os.Getwd()
	}

	// テスト実行が必要か判定
	if !shouldRunTests(changedFile) {
		return emptyPostToolOutput(out)
	}

	// テストコマンドを検出
	testCmd := detectTestCommand(projectRoot)
	if testCmd == "" {
		return emptyPostToolOutput(out)
	}

	// 関連テストファイルを検出（P2 修正: projectRoot を渡す）
	relatedTest := findRelatedTests(changedFile, projectRoot)

	stateDir := filepath.Join(projectRoot, ".claude", "state")
	if err := os.MkdirAll(stateDir, 0o755); err != nil {
		return emptyPostToolOutput(out)
	}

	// HARNESS_AUTO_TEST=run の場合は実際にテストを実行
	if os.Getenv("HARNESS_AUTO_TEST") == "run" {
		return runTestsAndReport(out, projectRoot, stateDir, changedFile, testCmd, relatedTest)
	}

	// デフォルト: recommend モード
	return writeTestRecommendation(out, stateDir, changedFile, testCmd, relatedTest)
}

// shouldRunTests はファイルがテスト実行が必要かどうかを判定する。
func shouldRunTests(file string) bool {
	if file == "" {
		return false
	}

	// 除外ディレクトリチェック
	for _, dir := range excludedDirs {
		if strings.HasPrefix(file, dir) {
			return false
		}
	}

	// 除外拡張子チェック
	for _, ext := range excludedExtensions {
		if strings.HasSuffix(file, ext) {
			return false
		}
	}

	// .gitignore
	if file == ".gitignore" {
		return false
	}

	// テストファイル自体の変更
	if strings.Contains(file, ".test.") || strings.Contains(file, ".spec.") || strings.Contains(file, "__tests__") {
		return true
	}

	// ソースコードファイルの変更
	for _, ext := range sourceFileExtensions {
		if strings.HasSuffix(file, ext) {
			return true
		}
	}

	return false
}

// detectTestCommand はプロジェクトルートからテストコマンドを自動検出する。
//
// 検出優先順（P2 修正: JS フレームワーク → Python → Rust → Go の順に並べ、
// tests/ の pytest 判定は package.json がない場合のみ適用する）:
//  1. vitest.config.* → npx vitest run --reporter=verbose
//  2. jest.config.* → npx jest --verbose
//  3. package.json の jest キー/scripts.test に jest → npx jest --verbose
//  4. package.json の scripts.test（npm test フォールバック）→ npm test
//  5. pytest.ini → pytest -v
//  6. pyproject.toml の [tool.pytest] → pytest -v
//  7. tests/ ディレクトリ（package.json がない場合のみ）→ pytest -v
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

	// jest: config ファイルによる検出（誤検出なし）
	jestConfigs := []string{
		"jest.config.ts", "jest.config.js", "jest.config.mjs", "jest.config.cjs",
	}
	for _, cfg := range jestConfigs {
		if autoTestFileExists(filepath.Join(projectRoot, cfg)) {
			return "npx jest --verbose"
		}
	}

	// package.json が存在する JS/Node プロジェクトの検出
	// jest 判定と npm test フォールバックをまとめて処理し、
	// tests/ の pytest 誤判定（P2）を防ぐために package.json チェックを先に行う。
	pkgPath := filepath.Join(projectRoot, "package.json")
	hasPkgJSON := autoTestFileExists(pkgPath)
	if hasPkgJSON {
		content, err := os.ReadFile(pkgPath)
		if err == nil {
			// jest: package.json の JSON パースによる検出
			// "jest" キーがトップレベルオブジェクトとして存在するか、
			// または scripts.test に "jest" を含む場合のみ Jest と判定する。
			// @types/jest や jest-junit のような依存パッケージ名による誤検出を防ぐ。
			if hasJestConfig(content) {
				return "npx jest --verbose"
			}
			// npm test フォールバック
			if hasNpmTestScript(content) {
				return "npm test"
			}
		}
	}

	// pytest 系フレームワーク: pytest バイナリが PATH 上に存在する場合のみ返す。
	// インストールされていない環境でフレームワーク設定ファイルだけ存在しても
	// コマンドが実行できないため、LookPath で事前に確認する。
	if _, pytestErr := exec.LookPath("pytest"); pytestErr == nil {
		// pytest.ini
		if autoTestFileExists(filepath.Join(projectRoot, "pytest.ini")) {
			return "pytest -v"
		}
		// pyproject.toml の [tool.pytest]
		pyprojectPath := filepath.Join(projectRoot, "pyproject.toml")
		if autoTestFileExists(pyprojectPath) {
			content, err := os.ReadFile(pyprojectPath)
			if err == nil && bytes.Contains(content, []byte("[tool.pytest")) {
				return "pytest -v"
			}
		}
		// tests/ ディレクトリが存在する Python プロジェクト（設定ファイルなし）
		// package.json がある JS プロジェクトには適用しない。
		if !hasPkgJSON {
			if autoTestFileExists(filepath.Join(projectRoot, "tests")) {
				if info, err := os.Stat(filepath.Join(projectRoot, "tests")); err == nil && info.IsDir() {
					return "pytest -v"
				}
			}
		}
	}

	// Cargo.toml が存在する Rust プロジェクト
	if autoTestFileExists(filepath.Join(projectRoot, "Cargo.toml")) {
		return "cargo test"
	}

	// go test: go.mod が存在するか確認
	if autoTestFileExists(filepath.Join(projectRoot, "go.mod")) {
		return "go test ./..."
	}

	return ""
}

// hasJestConfig は package.json の内容から Jest が設定されているかを JSON パースで確認する。
//
// 以下のいずれかを満たす場合に true を返す:
//   - トップレベルに "jest" キーがオブジェクトとして存在する（Jest 設定オブジェクト）
//   - scripts.test の値に "jest" という文字列が含まれる
//
// @types/jest や jest-junit のような依存パッケージ名を単純文字列検索した場合の誤検出を防ぐ。
func hasJestConfig(content []byte) bool {
	var pkg map[string]json.RawMessage
	if err := json.Unmarshal(content, &pkg); err != nil {
		return false
	}

	// "jest" キーがトップレベルオブジェクトとして存在するか確認
	if jestRaw, ok := pkg["jest"]; ok {
		// 値がオブジェクト（Jest 設定）かどうかを確認
		var jestObj map[string]json.RawMessage
		if json.Unmarshal(jestRaw, &jestObj) == nil {
			return true
		}
	}

	// scripts.test に "jest" が含まれるか確認
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

// hasNpmTestScript は package.json の内容に scripts.test が定義されているか確認する。
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
	// "test" キーが存在しても空文字や npm init のプレースホルダーは除外
	testStr, ok := testVal.(string)
	if !ok || strings.TrimSpace(testStr) == "" {
		return false
	}
	// npm init が生成するデフォルト値はテスト有りと見なさない
	if strings.Contains(testStr, "Error: no test specified") {
		return false
	}
	return true
}

// findRelatedTests は変更ファイルに対応するテストファイルを探す。
//
// P2 修正: projectRoot を受け取り、ファイルが相対パスの場合は
// filepath.Join(projectRoot, file) を基準にテストファイルを探索する。
// harness バイナリがリポルート外から起動された場合でも正しくテストを検出できる。
func findRelatedTests(file, projectRoot string) string {
	// file が絶対パスでない場合は projectRoot と結合して絶対パスを求め、
	// パターン生成の基準とする。
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

// buildExecCommand はテストランナーごとにファイル引数の渡し方を分岐して実行コマンドを返す。
//
// P1 修正: `go test` は `-- <file>` 引数を受け付けないため、ランナーごとに分岐する。
//
//   - go test    : go test ./path/to/pkg/... (パッケージパスに変換)
//   - pytest     : pytest path/to/test_file.py
//   - cargo test : cargo test (ファイル指定なし)
//   - jest/vitest: npx jest -- path/to/test.ts / npx vitest run -- path/to/test.ts
//   - npm test   : npm test (ファイル指定なし)
func buildExecCommand(testCmd, relatedTest, projectRoot string) string {
	return buildExecInvocation(testCmd, relatedTest, projectRoot).Display
}

func buildExecInvocation(testCmd, relatedTest, projectRoot string) autoTestCommandInvocation {
	if relatedTest == "" {
		return invocationFromKnownTestCommand(testCmd)
	}

	switch {
	case strings.HasPrefix(testCmd, "go test"):
		// go test は <package path> を引数に取る。
		// relatedTest が絶対パスの場合は projectRoot からの相対パスに戻してパッケージパスへ変換する。
		rel := relatedTest
		if filepath.IsAbs(relatedTest) && projectRoot != "" {
			if r, err := filepath.Rel(projectRoot, relatedTest); err == nil {
				rel = r
			}
		}
		// _test.go ファイルが属するディレクトリのパッケージパスを生成する。
		// 例: internal/foo/bar_test.go -> go test ./internal/foo/...
		return newAutoTestInvocation("go", []string{"test", goTestPackageArg(rel)})

	case strings.HasPrefix(testCmd, "pytest"):
		// pytest はファイルパスを直接引数に渡せる。
		return newAutoTestInvocation("pytest", []string{"-v", relatedTest})

	case strings.HasPrefix(testCmd, "cargo test"):
		// cargo test はファイル単位の指定をサポートしないため、ファイル指定なしで実行する。
		return newAutoTestInvocation("cargo", []string{"test"})

	case strings.HasPrefix(testCmd, "npx jest"),
		strings.HasPrefix(testCmd, "npx vitest"):
		// jest/vitest は `-- <file>` 形式でテストファイルを絞り込める。
		inv := invocationFromKnownTestCommand(testCmd)
		inv.Args = append(inv.Args, "--", relatedTest)
		inv.Display = displayCommand(inv.Name, inv.Args)
		return inv

	case strings.HasPrefix(testCmd, "npm test"):
		// npm test はファイル指定のインターフェースが不定のため、ファイル指定なしで実行する。
		return newAutoTestInvocation("npm", []string{"test"})

	default:
		// 不明なランナーはファイル指定なしで安全側に倒す。
		return invocationFromKnownTestCommand(testCmd)
	}
}

func goTestPackageArg(relatedTest string) string {
	pkgDir := filepath.ToSlash(filepath.Dir(relatedTest))
	pkgDir = strings.TrimPrefix(pkgDir, "./")
	if pkgDir == "." || pkgDir == "" {
		return "./..."
	}
	return "./" + pkgDir + "/..."
}

func invocationFromKnownTestCommand(testCmd string) autoTestCommandInvocation {
	switch testCmd {
	case "npx vitest run --reporter=verbose":
		return newAutoTestInvocation("npx", []string{"vitest", "run", "--reporter=verbose"})
	case "npx jest --verbose":
		return newAutoTestInvocation("npx", []string{"jest", "--verbose"})
	case "pytest -v":
		return newAutoTestInvocation("pytest", []string{"-v"})
	case "cargo test":
		return newAutoTestInvocation("cargo", []string{"test"})
	case "go test ./...":
		return newAutoTestInvocation("go", []string{"test", "./..."})
	case "npm test":
		return newAutoTestInvocation("npm", []string{"test"})
	default:
		fields := strings.Fields(testCmd)
		if len(fields) == 0 {
			return autoTestCommandInvocation{}
		}
		return newAutoTestInvocation(fields[0], fields[1:])
	}
}

func newAutoTestInvocation(name string, args []string) autoTestCommandInvocation {
	return autoTestCommandInvocation{
		Name:    name,
		Args:    args,
		Display: displayCommand(name, args),
	}
}

func displayCommand(name string, args []string) string {
	parts := append([]string{name}, args...)
	return strings.Join(parts, " ")
}

// runTestsAndReport はテストを実行して結果を記録し、additionalContext で通知する。
func runTestsAndReport(out io.Writer, projectRoot, stateDir, changedFile, testCmd, relatedTest string) error {
	// 実行コマンドを決定（P1 修正: ランナーごとにファイル引数を分岐）
	invocation := buildExecInvocation(testCmd, relatedTest, projectRoot)
	execCmd := invocation.Display

	ts := time.Now().UTC().Format(time.RFC3339)

	// タイムアウト付きでテスト実行（最大 60 秒）
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()

	cmd := exec.CommandContext(ctx, invocation.Name, invocation.Args...)
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

	// 出力を最大 200 行に制限
	output := limitLines(buf.String(), 200)

	// 結果を JSON で書き出す
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

	// additionalContext を構築
	var contextMsg string
	outputSnippet := limitLines(output, 30)

	switch status {
	case "passed":
		contextMsg = fmt.Sprintf("[Auto Test Runner] Tests passed / テスト成功\nCommand: %s\nFile: %s\nStatus: PASSED (exit=0)",
			testCmd, changedFile)
	case "timeout":
		contextMsg = fmt.Sprintf("[Auto Test Runner] Tests timed out / テストがタイムアウトしました (60s)\nCommand: %s\nFile: %s\nStatus: TIMEOUT\n\nOutput:\n%s",
			testCmd, changedFile, outputSnippet)
	default:
		contextMsg = fmt.Sprintf("[Auto Test Runner] Tests failed / テスト失敗\nCommand: %s\nFile: %s\nStatus: FAILED (exit=%d)\n\nOutput:\n%s\n\nFix the implementation to make the tests pass. / テストが通るように実装を修正してください。",
			testCmd, changedFile, exitCode, outputSnippet)
	}

	var hookOut autoTestHookOutput
	hookOut.HookSpecificOutput.HookEventName = "PostToolUse"
	hookOut.HookSpecificOutput.AdditionalContext = contextMsg

	return json.NewEncoder(out).Encode(hookOut)
}

// writeTestRecommendation はテスト推奨を記録する（recommend モード）。
func writeTestRecommendation(out io.Writer, stateDir, changedFile, testCmd, relatedTest string) error {
	ts := time.Now().UTC().Format(time.RFC3339)
	recPath := filepath.Join(stateDir, "test-recommendation.json")
	rec := autoTestRecommendation{
		Timestamp:      ts,
		ChangedFile:    changedFile,
		TestCommand:    testCmd,
		RelatedTest:    relatedTest,
		Recommendation: "テストの実行を推奨します",
	}
	if err := autoTestWriteJSONFile(recPath, rec); err != nil {
		fmt.Fprintf(os.Stderr, "[auto-test-runner] write recommendation: %v\n", err)
	}

	// recommend モードでは空の PostToolUse 出力を返す
	return emptyPostToolOutput(out)
}

// autoTestFileExists はファイルが存在するかどうかを確認する。
func autoTestFileExists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}

// limitLines はテキストを最大 n 行に制限する。
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

// autoTestWriteJSONFile は v を JSON エンコードしてファイルに書き出す。
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
