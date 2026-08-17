package hookhandler

// posttooluse_writing_lint.go
//
// PostToolUse Write/Edit 後に .md/.txt を対象に日本語文章スタイルの辞書照合を行う。
//   - .claude-code-harness.config.yaml の writing_lint セクションを読み込む
//   - ひらがな含有ゲートで英語ファイルを除外（辞書は日本語文章向け）
//   - writinglint 辞書 (JSONL) と照合し、該当文の書き直し推奨 + グッドパターンを additionalContext で返す
//   - 併せて structural（文末3連続・敬体常体混在）を通知する
//   - advisory（exit 0 固定、ブロックしない）

import (
	"bufio"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"

	"github.com/Chachamaru127/claude-code-harness/go/internal/writinglint"
)

// writingLintMaxMatches は additionalContext に列挙する辞書ヒットの上限件数。
const writingLintMaxMatches = 5

// writingLintInput は PostToolUse フックの stdin JSON。
type writingLintInput struct {
	ToolName  string `json:"tool_name"`
	ToolInput struct {
		FilePath string `json:"file_path"`
	} `json:"tool_input"`
	ToolResponse struct {
		FilePath string `json:"filePath"`
	} `json:"tool_response"`
	CWD string `json:"cwd"`
}

// writingLintConfig は .claude-code-harness.config.yaml の writing_lint セクション。
type writingLintConfig struct {
	Enabled    bool   // enabled: true/false（デフォルト false）
	Scene      string // scene: 空ならシーン絞り込みなし（全ルール適用）
	Structural bool   // structural: true/false（デフォルト true）
}

// HandlePostToolUseWritingLint は PostToolUse Write/Edit イベントで呼び出され、
// .md/.txt ファイルに対して writing-lint 辞書照合と structural チェックを行う。
// .claude-code-harness.config.yaml の writing_lint.enabled が true の場合のみ動作する。
func HandlePostToolUseWritingLint(in io.Reader, out io.Writer) error {
	data, err := io.ReadAll(in)
	if err != nil || len(strings.TrimSpace(string(data))) == 0 {
		return nil
	}

	var input writingLintInput
	if jsonErr := json.Unmarshal(data, &input); jsonErr != nil {
		return nil
	}

	// Write/Edit のみ対象
	if input.ToolName != "Write" && input.ToolName != "Edit" {
		return nil
	}

	// ファイルパスを取得
	filePath := input.ToolInput.FilePath
	if filePath == "" {
		filePath = input.ToolResponse.FilePath
	}
	if filePath == "" {
		return nil
	}

	// CWD があれば相対パスに変換
	cwd := input.CWD
	if cwd != "" && strings.HasPrefix(filePath, cwd+"/") {
		filePath = strings.TrimPrefix(filePath, cwd+"/")
	}
	locale := resolveHarnessLocale(cwd)

	// .md/.txt のみ対象
	if !isWritingLintTargetFile(filePath) {
		return nil
	}

	// 除外パスのチェック（quality_pack の isExcludedPath は再利用しない。docs/ は対象に含める）
	if isWritingLintExcludedPath(filePath) {
		return nil
	}

	// 設定を読み込む。プロジェクトルート起点で解決する（stop_writing_lint.go の
	// resolveProjectRoot() join と揃える）。プロセスの実 CWD がリポジトリの
	// サブディレクトリの場合、素の相対パスだとルート直下の config を見つけられず
	// enabled:false 相当に silent disable してしまうため。
	projectRoot := resolveProjectRoot()
	cfg := readWritingLintConfig(filepath.Join(projectRoot, harnessConfigFileName))
	if !cfg.Enabled {
		return nil
	}

	content, readErr := os.ReadFile(filePath)
	if readErr != nil {
		return nil
	}
	text := string(content)

	// ひらがな含有ゲート: ひらがなが無ければ英語ファイル等とみなしスキップ
	if !containsHiragana(text) {
		return nil
	}

	var feedbacks []string

	if cfg.Structural {
		feedbacks = append(feedbacks, structuralFeedback(text, locale)...)
	}

	dictPath := writinglint.ResolveDictPath(projectRoot)
	rules, dictErr := writinglint.LoadDict(dictPath)
	if dictErr != nil {
		// 辞書未検出時は一度だけ diagnostics を返す（ブロックはしない）。
		feedbacks = append(feedbacks, localizedHarnessMessage(locale,
			fmt.Sprintf("writing-lint dictionary unavailable (%s); pattern checks skipped", dictPath),
			fmt.Sprintf("writing-lint 辞書が見つかりません（%s）。パターン照合はスキップしました", dictPath)))
	} else {
		matches, invalidRuleIDs, scanErr := writinglint.ScanText(text, rules, writinglint.ScanOpts{Scene: cfg.Scene})
		if scanErr == nil {
			if len(matches) > 0 {
				feedbacks = append(feedbacks, matchFeedback(matches, locale)...)
			}
			if len(invalidRuleIDs) > 0 {
				feedbacks = append(feedbacks, invalidRuleFeedback(invalidRuleIDs, locale)...)
			}
		}
	}

	if len(feedbacks) == 0 {
		return nil
	}

	combined := "Writing Lint (PostToolUse)\n" + strings.Join(feedbacks, "\n")

	o := postToolOutput{}
	o.HookSpecificOutput.HookEventName = "PostToolUse"
	o.HookSpecificOutput.AdditionalContext = combined
	return writeJSON(out, o)
}

// isWritingLintTargetFile は .md/.txt ファイルかどうかを判定する。
func isWritingLintTargetFile(filePath string) bool {
	lower := strings.ToLower(filePath)
	return strings.HasSuffix(lower, ".md") || strings.HasSuffix(lower, ".txt")
}

// isWritingLintExcludedPath は除外パスかどうかを判定する。
// quality_pack の isExcludedPath とは独立の専用最小除外リスト（docs/ は対象に含める）。
func isWritingLintExcludedPath(filePath string) bool {
	excludePrefixes := []string{
		".claude/",
		"node_modules/",
		".git/",
	}
	for _, prefix := range excludePrefixes {
		if strings.HasPrefix(filePath, prefix) {
			return true
		}
	}
	return false
}

// containsHiragana はテキストにひらがな（U+3041-U+3096）が1文字以上含まれるかを判定する。
// 英語ファイルの誤検知（辞書は日本語文章向け）を防ぐゲートとして使う。
func containsHiragana(text string) bool {
	for _, r := range text {
		if r >= 0x3041 && r <= 0x3096 {
			return true
		}
	}
	return false
}

// matchFeedback は辞書ヒットを上位 writingLintMaxMatches 件にキャップし、
// 「該当文を丸ごと書き直し」+ グッドパターンの advisory メッセージへ変換する。
// 超過件数がある場合は省略件数を明記する。
func matchFeedback(matches []writinglint.Match, locale string) []string {
	limit := len(matches)
	if limit > writingLintMaxMatches {
		limit = writingLintMaxMatches
	}

	lines := make([]string, 0, limit+1)
	for _, m := range matches[:limit] {
		lines = append(lines, localizedHarnessMessage(locale,
			fmt.Sprintf("- Rewrite the whole sentence containing %q (rule: %s) -> good pattern: %s", m.Text, m.RuleID, m.Good),
			fmt.Sprintf("- 「%s」を含む文を丸ごと書き直してください（ルール: %s）→ グッドパターン: %s", m.Text, m.RuleID, m.Good)))
	}

	if excess := len(matches) - limit; excess > 0 {
		lines = append(lines, localizedHarnessMessage(locale,
			fmt.Sprintf("...%d more hit(s) omitted", excess),
			fmt.Sprintf("…ほか %d 件は省略しました", excess)))
	}

	return lines
}

// invalidRuleFeedback は RE2 として compile できず skip した dictionary rule
// ID を advisory メッセージへ変換する（silent disable の regression 対策。
// writinglint.ScanText 参照）。
func invalidRuleFeedback(invalidRuleIDs []string, locale string) []string {
	lines := make([]string, 0, len(invalidRuleIDs))
	for _, id := range invalidRuleIDs {
		lines = append(lines, localizedHarnessMessage(locale,
			fmt.Sprintf("- invalid rule: %s (pattern failed to compile as RE2; skipped)", id),
			fmt.Sprintf("- invalid rule: %s（pattern が RE2 として compile できず skip しました）", id)))
	}
	return lines
}

// structuralFeedback は文末3連続・敬体常体混在を検出し advisory メッセージへ変換する。
func structuralFeedback(text, locale string) []string {
	var out []string

	for _, rep := range writinglint.DetectRepeatedSentenceEndings(text) {
		out = append(out, localizedHarnessMessage(locale,
			fmt.Sprintf("- Sentence ending %q repeats %d times in a row", rep.Ending, rep.Count),
			fmt.Sprintf("- 文末「%s」が%d回連続しています", rep.Ending, rep.Count)))
	}

	if mixing := writinglint.DetectStyleMixing(text); mixing.Mixed() {
		out = append(out, localizedHarnessMessage(locale,
			fmt.Sprintf("- Polite/plain style mixing detected (polite=%d, plain=%d)", mixing.PoliteCount, mixing.PlainCount),
			fmt.Sprintf("- 敬体・常体の混在を検出しました（敬体%d件、常体%d件）", mixing.PoliteCount, mixing.PlainCount)))
	}

	return out
}

// readWritingLintConfig は .claude-code-harness.config.yaml から writing_lint セクションを読む。
// YAML パーサーなしで実装（quality_pack の readQualityPackConfig と同等のロジック）。
func readWritingLintConfig(configPath string) writingLintConfig {
	cfg := writingLintConfig{
		Enabled:    false,
		Scene:      "",
		Structural: true,
	}

	f, err := os.Open(configPath)
	if err != nil {
		return cfg // ファイルが存在しない場合はデフォルト（無効）
	}
	defer f.Close()

	inWritingLint := false
	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		line := scanner.Text()

		if strings.TrimSpace(line) == "writing_lint:" {
			inWritingLint = true
			continue
		}

		// 別のトップレベルセクションが始まったら終了
		if inWritingLint && len(line) > 0 && line[0] != ' ' && line[0] != '\t' && line[0] != '#' {
			break
		}

		if !inWritingLint {
			continue
		}

		trimmed := strings.TrimSpace(line)
		parts := strings.SplitN(trimmed, ":", 2)
		if len(parts) != 2 {
			continue
		}
		key := strings.TrimSpace(parts[0])
		val := strings.TrimSpace(parts[1])
		val = strings.Trim(val, `"'`)

		switch key {
		case "enabled":
			cfg.Enabled = val == "true"
		case "scene":
			cfg.Scene = val
		case "structural":
			cfg.Structural = val != "false"
		}
	}

	return cfg
}
