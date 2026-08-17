package hookhandler

import (
	"bufio"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"time"
)

// trackChangesInput は track-changes.sh に渡される stdin JSON。
type trackChangesInput struct {
	ToolName  string `json:"tool_name"`
	CWD       string `json:"cwd"`
	SessionID string `json:"session_id"`
	ToolInput struct {
		FilePath string `json:"file_path"`
	} `json:"tool_input"`
	ToolResponse struct {
		FilePath string `json:"filePath"`
	} `json:"tool_response"`
}

// changedFileEntry は .claude/state/changed-files.jsonl の1行分のエントリ。
//
// SessionID (Phase 134 finding): changed-files.jsonl is a cross-session
// append-only log with no prior session scoping. Stop consumers
// (stop_writing_lint.go, stop_session_evaluator.go's DroppedScope) must be
// able to narrow "touched files" to the current session only, or a stale
// major-severity hit left by a different session can block an unrelated
// session's Stop. omitempty keeps pre-existing log lines (written before
// this field existed) round-tripping as an empty SessionID, which readers
// treat as "unknown session" and skip rather than misattribute.
type changedFileEntry struct {
	File      string `json:"file"`
	Action    string `json:"action"`
	Timestamp string `json:"timestamp"`
	Important bool   `json:"important"`
	SessionID string `json:"session_id,omitempty"`
}

// trackChangesMaxLines は JSONL ファイルのローテーション閾値。
const trackChangesMaxLines = 500

// trackChangesDedupWindow は同一ファイルの dedup ウィンドウ（2時間）。
const trackChangesDedupWindow = 2 * time.Hour

// changedFilesPath は変更記録ファイルのパス。
const changedFilesPath = ".claude/state/changed-files.jsonl"

// importantFilePatterns は重要ファイルの判定パターン。
var importantFilePatterns = []string{
	"Plans.md",
	"CLAUDE.md",
	"AGENTS.md",
}

// HandleTrackChanges は track-changes.sh の Go 移植。
//
// PostToolUse Write/Edit/Task イベントで呼び出され、ファイル変更を
// .claude/state/changed-files.jsonl に記録する。
//
// 動作:
//   - クロスプラットフォームパス正規化（Windows バックスラッシュ対応）
//   - 2時間の dedup（同一ファイルの連続記録を抑制）
//   - JSONL 500行超でローテーション（古い行を削除）
func HandleTrackChanges(in io.Reader, out io.Writer) error {
	data, err := io.ReadAll(in)
	if err != nil {
		return emptyPostToolOutput(out)
	}

	if len(strings.TrimSpace(string(data))) == 0 {
		return emptyPostToolOutput(out)
	}

	var input trackChangesInput
	if err := json.Unmarshal(data, &input); err != nil {
		return emptyPostToolOutput(out)
	}

	// tool_input.file_path または tool_response.filePath を取得
	filePath := input.ToolInput.FilePath
	if filePath == "" {
		filePath = input.ToolResponse.FilePath
	}

	// ファイルパスがない場合は終了
	if filePath == "" {
		return emptyPostToolOutput(out)
	}

	// クロスプラットフォームパス正規化（Windows バックスラッシュ → スラッシュ）
	filePath = normalizePathSeparators(filePath)

	// CWD が指定されている場合はプロジェクト相対パスに変換
	if input.CWD != "" {
		cwd := normalizePathSeparators(input.CWD)
		filePath = makeRelativePath(filePath, cwd)
	}

	toolName := input.ToolName
	if toolName == "" {
		toolName = "unknown"
	}

	// 重要ファイルかどうかを判定
	important := isImportantFile(filePath)

	now := time.Now().UTC()
	timestamp := now.Format(time.RFC3339)

	// dedup チェック: 同一セッションが同一ファイルを2時間以内に記録済みかどうか。
	// セッション単位にしないと、別セッションの記録が dedup で先勝ちし、今回
	// セッションのエントリが一切書かれず loadTouchedFilesForStop の session
	// フィルタが「touched なし」を返す穴になる (Phase 134 finding の随伴修正)。
	if isDuplicateWithin(filePath, input.SessionID, now, trackChangesDedupWindow) {
		return emptyPostToolOutput(out)
	}

	// 状態ディレクトリを作成
	stateDir := filepath.Dir(changedFilesPath)
	if err := os.MkdirAll(stateDir, 0o755); err != nil {
		return emptyPostToolOutput(out)
	}

	// 既存の行数をチェックしてローテーション
	if err := rotateIfNeeded(changedFilesPath, trackChangesMaxLines); err != nil {
		// ローテーション失敗は無視して続行
		fmt.Fprintf(os.Stderr, "[track-changes] rotate: %v\n", err)
	}

	// エントリを JSONL に追記
	entry := changedFileEntry{
		File:      filePath,
		Action:    toolName,
		Timestamp: timestamp,
		Important: important,
		SessionID: input.SessionID,
	}
	entryJSON, err := json.Marshal(entry)
	if err != nil {
		return emptyPostToolOutput(out)
	}

	f, err := os.OpenFile(changedFilesPath, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o644)
	if err != nil {
		return emptyPostToolOutput(out)
	}
	defer f.Close()

	if _, err := fmt.Fprintf(f, "%s\n", entryJSON); err != nil {
		return emptyPostToolOutput(out)
	}

	return emptyPostToolOutput(out)
}

// normalizePathSeparators は Windows バックスラッシュをスラッシュに変換する。
func normalizePathSeparators(p string) string {
	return strings.ReplaceAll(p, "\\", "/")
}

// makeRelativePath は filePath が cwd 配下にある場合、相対パスに変換する。
func makeRelativePath(filePath, cwd string) string {
	// 末尾スラッシュを付けて前方一致チェック
	cwdWithSlash := strings.TrimRight(cwd, "/") + "/"
	if strings.HasPrefix(filePath+"/", cwdWithSlash) || filePath == strings.TrimRight(cwd, "/") {
		if strings.HasPrefix(filePath, cwdWithSlash) {
			return filePath[len(cwdWithSlash):]
		}
	}
	return filePath
}

// isImportantFile はファイルが重要かどうかを判定する。
// Plans.md, CLAUDE.md, AGENTS.md、およびテストファイルが対象。
func isImportantFile(filePath string) bool {
	for _, pattern := range importantFilePatterns {
		if strings.Contains(filePath, pattern) {
			return true
		}
	}
	// テストファイルの検出
	if strings.Contains(filePath, ".test.") ||
		strings.Contains(filePath, ".spec.") ||
		strings.Contains(filePath, "__tests__") {
		return true
	}
	return false
}

// isDuplicateWithin は同じセッションが同じファイルを window 時間内に記録済み
// かどうかを確認する。sessionID が空の場合は従来通りファイル一致のみで判定
// する (session_id を送らない呼び出し元との互換を保つ)。sessionID が非空の
// 場合は entry.SessionID が一致する行のみを対象にする — 別セッションの記録
// で dedup が先勝ちし、このセッションのエントリが書かれずに終わる (結果
// loadTouchedFilesForStop のセッションフィルタが常に空を返す) 事態を防ぐ。
func isDuplicateWithin(filePath, sessionID string, now time.Time, window time.Duration) bool {
	f, err := os.Open(changedFilesPath)
	if err != nil {
		// ファイルが存在しない場合は重複なし
		return false
	}
	defer f.Close()

	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" {
			continue
		}
		var entry changedFileEntry
		if err := json.Unmarshal([]byte(line), &entry); err != nil {
			continue
		}
		if entry.File != filePath {
			continue
		}
		if sessionID != "" && entry.SessionID != sessionID {
			continue
		}
		t, err := time.Parse(time.RFC3339, entry.Timestamp)
		if err != nil {
			continue
		}
		if now.Sub(t) < window {
			return true
		}
	}
	return false
}

// rotateIfNeeded は JSONL ファイルが maxLines を超えている場合、古い行を削除する。
func rotateIfNeeded(path string, maxLines int) error {
	f, err := os.Open(path)
	if err != nil {
		// ファイルが存在しない場合はローテーション不要
		return nil
	}

	var lines []string
	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		line := scanner.Text()
		if strings.TrimSpace(line) != "" {
			lines = append(lines, line)
		}
	}
	f.Close()

	if len(lines) <= maxLines {
		return nil
	}

	// 古い行を削除（末尾 maxLines 行を保持）
	lines = lines[len(lines)-maxLines:]

	tmpPath := path + ".tmp"
	tmp, err := os.Create(tmpPath)
	if err != nil {
		return fmt.Errorf("create tmp: %w", err)
	}

	w := bufio.NewWriter(tmp)
	for _, line := range lines {
		if _, err := fmt.Fprintln(w, line); err != nil {
			tmp.Close()
			os.Remove(tmpPath)
			return fmt.Errorf("write tmp: %w", err)
		}
	}
	if err := w.Flush(); err != nil {
		tmp.Close()
		os.Remove(tmpPath)
		return fmt.Errorf("flush tmp: %w", err)
	}
	tmp.Close()

	return os.Rename(tmpPath, path)
}
