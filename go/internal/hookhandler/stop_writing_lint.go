package hookhandler

// stop_writing_lint.go
//
// Stop フックで .claude/state/changed-files.jsonl に記録された今回セッションの
// .md ファイルを writing-lint 辞書で再スキャンする。severity: error (major) の
// 辞書ヒットが残っていれば初回 Stop で decision:"block"、再入 (stop_hook_active)
// では systemMessage で警告するだけに留めて停止を許可する。この再入設計は
// stop_session_evaluator.go の WIP gate (Issue #269) と同型: block を繰り返すと
// 調査のみのセッションが停止不能になるため、1 回 block したら次は通す。
// severity: info/warning (minor) はこの Stop ゲートでは一切ブロックしない
// (PostToolUse の writing-lint hook が既に advisory で提示済み)。

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"

	"github.com/Chachamaru127/claude-code-harness/go/internal/writinglint"
)

// writingLintMajorSeverity is the writing-rule.v1 severity level (schema
// enum: info/warning/error) treated as "major" for this Stop re-scan gate.
// error is the strongest level; info/warning map to "minor" and never block.
const writingLintMajorSeverity = "error"

// stopWritingLintInput is the Stop hook stdin JSON payload this handler reads.
type stopWritingLintInput struct {
	StopHookActive bool   `json:"stop_hook_active"`
	SessionID      string `json:"session_id"`
}

// StopWritingLintHandler は scripts 側に対応物のない新規 Go ネイティブハンドラ。
// stop_session_evaluator.go の再入設計を踏襲する。
type StopWritingLintHandler struct {
	// ProjectRoot はプロジェクトルートのパス。空の場合は環境変数/CWD から解決。
	ProjectRoot string
}

// Handle processes the Stop event: re-scan touched .md files for major
// (severity: error) writing-lint hits and block once on first Stop.
func (h *StopWritingLintHandler) Handle(in io.Reader, out io.Writer) error {
	projectRoot := h.ProjectRoot
	if projectRoot == "" {
		projectRoot = resolveProjectRoot()
	}

	var input stopWritingLintInput
	limited := io.LimitReader(in, 65536)
	if payload, _ := io.ReadAll(limited); len(payload) > 0 {
		_ = json.Unmarshal(payload, &input)
	}

	cfg := readWritingLintConfig(filepath.Join(projectRoot, harnessConfigFileName))
	if !cfg.Enabled {
		return writeJSON(out, stopSessionResponse{OK: true})
	}

	majorHits, invalidRuleIDs := scanTouchedMarkdownForMajorHits(projectRoot, cfg, input.SessionID)
	locale := resolveHarnessLocale(projectRoot)
	invalidSuffix := invalidRuleDiagnosticSuffix(invalidRuleIDs, locale)

	if len(majorHits) == 0 {
		if invalidSuffix == "" {
			return writeJSON(out, stopSessionResponse{OK: true})
		}
		return writeJSON(out, stopSessionResponse{OK: true, SystemMessage: invalidSuffix})
	}

	summary := strings.Join(majorHits, "; ")

	if input.StopHookActive {
		msg := fmt.Sprintf(
			localizedHarnessMessage(locale,
				"[WritingLint] Stopping with %d major writing-lint issue(s) remaining: %s",
				"[WritingLint] major の writing-lint 指摘が %d 件残ったまま停止します: %s"),
			len(majorHits), summary,
		) + invalidSuffix
		return writeJSON(out, stopSessionResponse{OK: true, SystemMessage: msg})
	}

	msg := fmt.Sprintf(
		localizedHarnessMessage(locale,
			"[WritingLint] %d major writing-lint issue(s) remain: %s",
			"[WritingLint] major の writing-lint 指摘が %d 件残っています: %s"),
		len(majorHits), summary,
	) + invalidSuffix
	return writeJSON(out, stopSessionResponse{Decision: "block", Reason: msg})
}

// invalidRuleDiagnosticSuffix は RE2 として compile できず skip した
// dictionary rule ID を、既存メッセージへ追記する診断サフィックスへ変換する
// （silent disable の regression 対策。writinglint.ScanText 参照）。
// invalidRuleIDs が空なら空文字を返す。
func invalidRuleDiagnosticSuffix(invalidRuleIDs []string, locale string) string {
	if len(invalidRuleIDs) == 0 {
		return ""
	}
	return fmt.Sprintf(
		localizedHarnessMessage(locale,
			" [WritingLint] invalid rule(s) skipped (pattern failed to compile as RE2): %s",
			" [WritingLint] RE2 として compile できず skip した rule: %s"),
		strings.Join(invalidRuleIDs, ", "),
	)
}

// scanTouchedMarkdownForMajorHits reads the de-duplicated list of files this
// session touched (track_changes.go's changed-files.jsonl, via
// loadTouchedFilesForStop, narrowed to entries whose session_id matches
// sessionID so another session's stale major hit cannot block this Stop),
// narrows to .md paths not covered by the writing-lint exclude list, and
// returns one summary string per severity: error dictionary hit found in
// their current on-disk content, plus the de-duplicated set of rule IDs (if
// any) skipped because their pattern failed to compile as RE2 (see
// writinglint.ScanText).
func scanTouchedMarkdownForMajorHits(projectRoot string, cfg writingLintConfig, sessionID string) (hits []string, invalidRuleIDs []string) {
	touched := loadTouchedFilesForStop(projectRoot, sessionID)
	if len(touched) == 0 {
		return nil, nil
	}

	dictPath := writinglint.ResolveDictPath(projectRoot)
	rules, err := writinglint.LoadDict(dictPath)
	if err != nil {
		return nil, nil
	}

	seenInvalid := map[string]bool{}
	for _, rel := range touched {
		if !strings.HasSuffix(strings.ToLower(rel), ".md") {
			continue
		}
		if isWritingLintExcludedPath(rel) {
			continue
		}
		content, readErr := os.ReadFile(filepath.Join(projectRoot, rel))
		if readErr != nil {
			continue
		}
		matches, invalid, scanErr := writinglint.ScanText(string(content), rules, writinglint.ScanOpts{Scene: cfg.Scene})
		if scanErr != nil {
			continue
		}
		for _, id := range invalid {
			if !seenInvalid[id] {
				seenInvalid[id] = true
				invalidRuleIDs = append(invalidRuleIDs, id)
			}
		}
		for _, m := range matches {
			if m.Severity != writingLintMajorSeverity {
				continue
			}
			hits = append(hits, fmt.Sprintf("%s [%s] %q", rel, m.RuleID, m.Text))
		}
	}
	return hits, invalidRuleIDs
}
