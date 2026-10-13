package hookhandler

import (
	"encoding/json"
	"io"
	"os"
	"path/filepath"
	"regexp"
	"strings"

	"github.com/Chachamaru127/claude-code-harness/go/internal/plans"
)

// tddCheckInput は tdd-order-check.sh に渡される stdin JSON。
type tddCheckInput struct {
	CWD       string `json:"cwd"`
	ToolName  string `json:"tool_name"`
	ToolInput struct {
		FilePath string `json:"file_path"`
	} `json:"tool_input"`
}

// tddApproveOutput は PreToolUse / PostToolUse フックの承認レスポンス形式。
// tdd-order-check.sh はブロックせず、systemMessage で警告を出す。
type tddApproveOutput struct {
	Decision      string `json:"decision"`
	Reason        string `json:"reason"`
	SystemMessage string `json:"systemMessage,omitempty"`
}

// sourceFileExts は TDD チェック対象のソースファイル拡張子パターン。
var sourceFileExts = regexp.MustCompile(`\.(ts|tsx|js|jsx|py|go)$`)

// testFilePatterns はテストファイルを判定する正規表現パターン一覧。
var testFilePatterns = []*regexp.Regexp{
	regexp.MustCompile(`\.(test|spec)\.(ts|tsx|js|jsx)$`),
	regexp.MustCompile(`_test\.go$`),
	regexp.MustCompile(`test_.*\.py$`),
	regexp.MustCompile(`__tests__/`),
	regexp.MustCompile(`/tests?/`),
}

// tddSkipMarkerRe は WIP タスク行中の [skip:tdd] マーカーを検出するパターン。
var tddSkipMarkerRe = regexp.MustCompile(`\[skip:tdd\]`)

// sessionChangesFile はセッション中に編集されたファイルを記録するファイルパス。
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

// HandleTDDOrderCheck は tdd-order-check.sh の Go 移植。
//
// PostToolUse Write/Edit イベントで呼び出され、実装ファイルが対応するテストファイルより
// 先に編集されたかどうかを検出する。
//
// 動作:
//   - ソースファイル（.ts, .js, .tsx, .jsx, .py, .go）が編集されたとき
//   - cc:WIP タスクが Plans.md に存在する
//   - [skip:tdd] マーカーがない
//   - セッション中にテストファイルが編集されていない
//     → systemMessage で TDD 順序の推奨を警告（ブロックはしない）
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

	// テストファイル自体はスキップ
	if isTestFilePath(filePath) {
		return writeTDDApprove(out, "")
	}

	// ソースファイルでなければスキップ
	if !isSourceFilePath(filePath) {
		return writeTDDApprove(out, "")
	}

	// cc:WIP タスクが存在しなければスキップ
	projectRoot := resolveProjectRoot(input.CWD)
	if !hasActiveWIPTask(projectRoot) {
		return writeTDDApprove(out, "")
	}

	// [skip:tdd] マーカーがあればスキップ
	if isTDDSkipped(projectRoot) {
		return writeTDDApprove(out, "")
	}

	// セッション中にテストファイルが編集済みならスキップ
	if testEditedThisSession(projectRoot) {
		return writeTDDApprove(out, "")
	}

	// 警告を出力（ブロックはしない）
	return writeTDDApprove(out, tddWarningMessage(resolveHarnessLocale(projectRoot)))
}

// writeTDDApprove は approve レスポンスを書き込む。
// systemMessage が空の場合は警告なしで承認する。
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

// isTestFilePath はファイルパスがテストファイルかどうかを判定する。
// パターン: *.test.ts, *.spec.ts, *_test.go, test_*.py, __tests__/, /tests?/
func isTestFilePath(filePath string) bool {
	for _, re := range testFilePatterns {
		if re.MatchString(filePath) {
			return true
		}
	}
	return false
}

// isSourceFilePath はファイルパスがソースファイルかどうかを判定する。
// テストファイルを除く .ts, .tsx, .js, .jsx, .py, .go が対象。
func isSourceFilePath(filePath string) bool {
	return sourceFileExts.MatchString(filePath) && !isTestFilePath(filePath)
}

// hasActiveWIPTask は Plans.md に cc:WIP タスクが存在するかどうかを確認する。
// projectRoot が空の場合は resolveProjectRoot() でカレントディレクトリを基準にする。
// resolvePlansPath が空文字を返した場合（Plans.md が存在しない）は false を返す。
func hasActiveWIPTask(projectRoot string) bool {
	if projectRoot == "" {
		projectRoot = resolveProjectRoot()
	}
	plansPath := resolvePlansPath(projectRoot)
	if plansPath == "" {
		return false
	}
	taskRows, err := plans.ParseFile(plansPath)
	if err != nil {
		return false
	}
	for _, task := range taskRows {
		if task.Tags.Wip {
			return true
		}
	}
	return false
}

// isTDDSkipped は Plans.md の WIP タスクに [skip:tdd] マーカーがあるかを確認する。
// projectRoot が空の場合は resolveProjectRoot() でカレントディレクトリを基準にする。
// resolvePlansPath が空文字を返した場合（Plans.md が存在しない）は false を返す。
func isTDDSkipped(projectRoot string) bool {
	if projectRoot == "" {
		projectRoot = resolveProjectRoot()
	}
	plansPath := resolvePlansPath(projectRoot)
	if plansPath == "" {
		return false
	}
	taskRows, err := plans.ParseFile(plansPath)
	if err != nil {
		return false
	}
	for _, task := range taskRows {
		if !task.Tags.Wip {
			continue
		}
		row := task.TaskID + " " + task.Title + " " + task.DoD + " " + task.Status
		if tddSkipMarkerRe.MatchString(row) {
			return true
		}
	}
	return false
}

// testEditedThisSession はセッション中にテストファイルが編集されたかどうかを確認する。
// .claude/state/session-changes.json を参照する（存在しない場合は false）。
func testEditedThisSession(projectRoot string) bool {
	data, err := os.ReadFile(filepath.Join(projectRoot, sessionChangesFile))
	if err != nil {
		// session-changes.json がなければ changed-files.jsonl もチェック
		return testEditedInChangedFiles(projectRoot)
	}
	content := string(data)
	return strings.Contains(content, ".test.") ||
		strings.Contains(content, ".spec.") ||
		strings.Contains(content, "_test.") ||
		strings.Contains(content, "test_") ||
		strings.Contains(content, "__tests__")
}

// testEditedInChangedFiles は .claude/state/changed-files.jsonl を参照して
// セッション中にテストファイルが編集されたかを確認する。
func testEditedInChangedFiles(projectRoot string) bool {
	data, err := os.ReadFile(filepath.Join(projectRoot, changedFilesPath))
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

// findCorrespondingTestFile は実装ファイルに対応するテストファイルパスを推定する。
// 例: src/main.ts → src/main.test.ts
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
