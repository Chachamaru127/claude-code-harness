// Package ci は CI ステータスチェックとエビデンス収集機能を提供する。
//
// CI ステータスチェッカーは PostToolUse (Bash) フックから呼び出され、
// git push / gh pr コマンドの後に CI ステータスを非同期で確認する。
//
// エビデンスコレクターはテスト結果やビルドログを
// .claude/state/evidence/ に保存する。
//
// shell 版:
//   - scripts/hook-handlers/ci-status-checker.sh
//   - scripts/evidence/common.sh
package ci

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

// ---------------------------------------------------------------------------
// 共通型
// ---------------------------------------------------------------------------

// HookInput は CI ステータスチェッカーが stdin から受け取るフック JSON。
type HookInput struct {
	ToolName     string                 `json:"tool_name,omitempty"`
	ToolInput    map[string]interface{} `json:"tool_input,omitempty"`
	ToolResponse map[string]interface{} `json:"tool_response,omitempty"`
	CWD          string                 `json:"cwd,omitempty"`
	SessionID    string                 `json:"session_id,omitempty"`
}

// CIRun は gh run list の 1 エントリ。
type CIRun struct {
	Status     string `json:"status"`
	Conclusion string `json:"conclusion"`
	Name       string `json:"name"`
	URL        string `json:"url"`
}

// CIStatusRecord は .claude/state/ci-status.json のスキーマ。
type CIStatusRecord struct {
	Timestamp      string `json:"timestamp"`
	TriggerCommand string `json:"trigger_command"`
	Status         string `json:"status"`
	Conclusion     string `json:"conclusion"`
}

// signalEntry は breezing-signals.jsonl への追記エントリ。
type signalEntry struct {
	Signal         string `json:"signal"`
	Timestamp      string `json:"timestamp"`
	Conclusion     string `json:"conclusion"`
	TriggerCommand string `json:"trigger_command"`
}

// approveResponse はフックの approve レスポンス。
type approveResponse struct {
	Decision          string `json:"decision"`
	Reason            string `json:"reason,omitempty"`
	AdditionalContext string `json:"additionalContext,omitempty"`
}

// ---------------------------------------------------------------------------
// CIStatusHandler — hook ci-status
// ---------------------------------------------------------------------------

// CIStatusHandler は PostToolUse フックで CI ステータスを確認するハンドラ。
// stdin から JSON を受け取り、push/PR コマンドを検知したら
// バックグラウンドで CI チェックを開始する。
type CIStatusHandler struct {
	// StateDir はステートファイルの保存先。空なら自動解決。
	StateDir string
	// GHCmd は gh コマンドのパス。空なら "gh" を使う。
	GHCmd string
	// nowFunc はテスト用の時刻注入関数。
	nowFunc func() string
}

// Handle は stdin から PostToolUse ペイロードを読み取り、
// CI チェックを開始して approve レスポンスを返す。
func (h *CIStatusHandler) Handle(r io.Reader, w io.Writer) error {
	data, err := io.ReadAll(r)
	if err != nil || len(data) == 0 {
		return h.writeApprove(w, "ci-status: no payload", "")
	}

	var inp HookInput
	if err := json.Unmarshal(data, &inp); err != nil {
		return h.writeApprove(w, "ci-status: parse error", "")
	}

	// Bash コマンドを取得
	bashCmd := h.extractBashCommand(inp)
	if !isPushOrPRCommand(bashCmd) {
		return h.writeApprove(w, "ci-status: not a push/PR command", "")
	}

	// ステートディレクトリを確保
	stateDir := h.resolveStateDir(inp.CWD)
	if err := ensureDir(stateDir); err != nil {
		return h.writeApprove(w, "ci-status: state dir error", "")
	}

	// バックグラウンドで CI チェックを起動（フックをブロックしない）
	go h.checkCIAsync(stateDir, bashCmd)

	// 直近の CI 失敗シグナルがあれば additionalContext を注入
	additionalCtx := h.buildFailureContext(stateDir, bashCmd)

	return h.writeApprove(w, "ci-status: push/PR detected, CI monitoring started", additionalCtx)
}

// extractBashCommand は HookInput から Bash コマンド文字列を取得する。
func (h *CIStatusHandler) extractBashCommand(inp HookInput) string {
	if inp.ToolInput == nil {
		return ""
	}
	cmd, _ := inp.ToolInput["command"].(string)
	return cmd
}

// isPushOrPRCommand は git push / gh pr コマンドかどうかを判定する。
func isPushOrPRCommand(cmd string) bool {
	patterns := []string{
		"git push",
		"gh pr create",
		"gh pr merge",
		"gh pr edit",
		"gh workflow run",
	}
	for _, p := range patterns {
		if strings.Contains(cmd, p) {
			return true
		}
	}
	return false
}

// resolveStateDir はプロジェクトルートから .claude/state パスを返す。
func (h *CIStatusHandler) resolveStateDir(cwd string) string {
	if h.StateDir != "" {
		return h.StateDir
	}

	root := cwd
	if root == "" {
		root, _ = os.Getwd()
	}
	return filepath.Join(root, ".claude", "state")
}

// checkCIAsync は gh run list をポーリングして CI ステータスを確認する。
// バックグラウンドゴルーチンとして実行される。
func (h *CIStatusHandler) checkCIAsync(stateDir, triggerCmd string) {
	ghCmd := h.GHCmd
	if ghCmd == "" {
		ghCmd = "gh"
	}

	// gh コマンドの存在確認
	if _, err := exec.LookPath(ghCmd); err != nil {
		return
	}

	maxWait := 60 * time.Second
	pollInterval := 10 * time.Second
	deadline := time.Now().Add(maxWait)

	for time.Now().Before(deadline) {
		time.Sleep(pollInterval)

		runs, err := h.fetchLatestRun(ghCmd)
		if err != nil || len(runs) == 0 {
			continue
		}

		run := runs[0]
		if run.Status != "completed" {
			continue
		}

		// 結果を記録
		h.writeCIStatus(stateDir, triggerCmd, run.Status, run.Conclusion)

		// 失敗した場合はシグナルを書き出す
		if isFailureConclusion(run.Conclusion) {
			h.writeFailureSignal(stateDir, triggerCmd, run.Conclusion)
		}
		return
	}
}

// fetchLatestRun は gh run list --limit 1 を実行して結果を返す。
func (h *CIStatusHandler) fetchLatestRun(ghCmd string) ([]CIRun, error) {
	// #nosec G204 — ghCmd は "gh" または設定値（テスト用モック）のみ
	out, err := exec.Command(ghCmd, "run", "list", "--limit", "1", "--json", "status,conclusion,name,url").Output()
	if err != nil {
		return nil, fmt.Errorf("gh run list: %w", err)
	}

	var runs []CIRun
	if err := json.Unmarshal(out, &runs); err != nil {
		return nil, fmt.Errorf("parsing gh output: %w", err)
	}
	return runs, nil
}

// isFailureConclusion は CI が失敗したかどうかを返す。
func isFailureConclusion(conclusion string) bool {
	switch conclusion {
	case "failure", "timed_out", "cancelled":
		return true
	}
	return false
}

// writeCIStatus は CI ステータスを ci-status.json に保存する。
func (h *CIStatusHandler) writeCIStatus(stateDir, triggerCmd, status, conclusion string) {
	rec := CIStatusRecord{
		Timestamp:      h.now(),
		TriggerCommand: triggerCmd,
		Status:         status,
		Conclusion:     conclusion,
	}
	data, err := json.Marshal(rec)
	if err != nil {
		return
	}

	path := filepath.Join(stateDir, "ci-status.json")
	if isSymlink(path) {
		return
	}
	_ = os.WriteFile(path, append(data, '\n'), 0600)
}

// writeFailureSignal は CI 失敗シグナルを breezing-signals.jsonl に追記する。
func (h *CIStatusHandler) writeFailureSignal(stateDir, triggerCmd, conclusion string) {
	entry := signalEntry{
		Signal:         "ci_failure_detected",
		Timestamp:      h.now(),
		Conclusion:     conclusion,
		TriggerCommand: triggerCmd,
	}
	data, err := json.Marshal(entry)
	if err != nil {
		return
	}

	path := filepath.Join(stateDir, "breezing-signals.jsonl")
	if isSymlink(path) || isSymlink(path+".tmp") {
		return
	}

	f, err := os.OpenFile(path, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0600)
	if err != nil {
		return
	}
	defer f.Close()
	_, _ = fmt.Fprintf(f, "%s\n", data)
}

// buildFailureContext は直近の CI 失敗シグナルをチェックして additionalContext を返す。
func (h *CIStatusHandler) buildFailureContext(stateDir, bashCmd string) string {
	signalsFile := filepath.Join(stateDir, "breezing-signals.jsonl")
	if isSymlink(signalsFile) {
		return ""
	}

	data, err := os.ReadFile(signalsFile)
	if err != nil {
		return ""
	}

	// 末尾から ci_failure_detected を探す
	lines := splitLines(data)
	for i := len(lines) - 1; i >= 0; i-- {
		line := lines[i]
		if !strings.Contains(line, `"ci_failure_detected"`) {
			continue
		}

		var sig signalEntry
		if err := json.Unmarshal([]byte(line), &sig); err != nil {
			continue
		}

		return fmt.Sprintf(
			"[CI 失敗を検知しました]\nCI ステータス: %s\nトリガーコマンド: %s\n\n"+
				"推奨アクション: /breezing または ci-cd-fixer エージェントを spawn して CI 障害を自動修復してください。\n"+
				"  例: ci-cd-fixer に「CI が失敗しました。ログを確認して修正してください。」と依頼",
			sig.Conclusion, bashCmd,
		)
	}
	return ""
}

// writeApprove は approve レスポンスを w に書き出す。
func (h *CIStatusHandler) writeApprove(w io.Writer, reason, additionalCtx string) error {
	resp := approveResponse{
		Decision:          "approve",
		Reason:            reason,
		AdditionalContext: additionalCtx,
	}
	data, err := json.Marshal(resp)
	if err != nil {
		return err
	}
	_, err = fmt.Fprintf(w, "%s\n", data)
	return err
}

// now は現在時刻を ISO 8601 UTC 形式で返す。
func (h *CIStatusHandler) now() string {
	if h.nowFunc != nil {
		return h.nowFunc()
	}
	return time.Now().UTC().Format(time.RFC3339)
}

// ---------------------------------------------------------------------------
// EvidenceCollector — evidence collect
// ---------------------------------------------------------------------------

// CollectOptions はエビデンス収集のオプション。
type CollectOptions struct {
	// ProjectRoot はプロジェクトルートディレクトリ。
	ProjectRoot string
	// Label はエビデンスのラベル（例: "test-run", "build"）。
	Label string
	// Content は保存するコンテンツ文字列。
	Content string
	// ContentFile は保存元ファイルパス（Content の代わりに使用）。
	ContentFile string
}

// CollectResult はエビデンス収集の結果。
type CollectResult struct {
	// SavedPath は保存先パス。
	SavedPath string
	// Label は使用したラベル。
	Label string
	// Timestamp は収集時刻。
	Timestamp string
	// Error はエラーメッセージ（エラーがない場合は空）。
	Error string
}

// EvidenceCollector はエビデンスを収集して保存するコレクター。
type EvidenceCollector struct {
	// nowFunc はテスト用の時刻注入関数。
	nowFunc func() string
}

// Collect はコンテンツを .claude/state/evidence/{label}/{timestamp}.txt に保存する。
func (c *EvidenceCollector) Collect(opts CollectOptions) CollectResult {
	ts := c.now()

	label := opts.Label
	if label == "" {
		label = "general"
	}
	safeLabel, err := sanitizeEvidenceLabel(label)
	if err != nil {
		return CollectResult{
			Label:     label,
			Timestamp: ts,
			Error:     err.Error(),
		}
	}

	// コンテンツを取得
	content := opts.Content
	if content == "" && opts.ContentFile != "" {
		data, err := os.ReadFile(opts.ContentFile)
		if err != nil {
			return CollectResult{
				Label:     label,
				Timestamp: ts,
				Error:     fmt.Sprintf("reading content file: %v", err),
			}
		}
		content = string(data)
	}

	if content == "" {
		return CollectResult{
			Label:     label,
			Timestamp: ts,
			Error:     "no content to collect",
		}
	}

	// 保存先ディレクトリを作成
	root := opts.ProjectRoot
	if root == "" {
		root, _ = os.Getwd()
	}

	evidenceDir := filepath.Join(root, ".claude", "state", "evidence", safeLabel)
	if err := ensureDir(evidenceDir); err != nil {
		return CollectResult{
			Label:     label,
			Timestamp: ts,
			Error:     fmt.Sprintf("creating evidence dir: %v", err),
		}
	}

	// タイムスタンプをファイル名に使用（コロンをハイフンに置換してファイル名安全に）
	safeTS := strings.ReplaceAll(ts, ":", "-")
	filename := fmt.Sprintf("%s.txt", safeTS)
	savePath := filepath.Join(evidenceDir, filename)

	if isSymlink(savePath) {
		return CollectResult{
			Label:     label,
			Timestamp: ts,
			Error:     "security: symlinked evidence path refused",
		}
	}

	if err := os.WriteFile(savePath, []byte(content), 0600); err != nil {
		return CollectResult{
			Label:     label,
			Timestamp: ts,
			Error:     fmt.Sprintf("writing evidence file: %v", err),
		}
	}

	return CollectResult{
		SavedPath: savePath,
		Label:     safeLabel,
		Timestamp: ts,
	}
}

func sanitizeEvidenceLabel(label string) (string, error) {
	if label == "" {
		return "", fmt.Errorf("security: evidence label must not be empty")
	}
	if label == "." || label == ".." {
		return "", fmt.Errorf("security: invalid evidence label %q", label)
	}
	if !filepath.IsLocal(label) || filepath.IsAbs(label) || strings.ContainsAny(label, `/\`) {
		return "", fmt.Errorf("security: invalid evidence label %q", label)
	}
	for _, r := range label {
		if (r >= 'a' && r <= 'z') || (r >= 'A' && r <= 'Z') || (r >= '0' && r <= '9') || r == '-' || r == '_' || r == '.' {
			continue
		}
		return "", fmt.Errorf("security: invalid evidence label %q", label)
	}
	return label, nil
}

// CollectFromStdin は stdin からコンテンツを読み取ってエビデンスを保存する。
func (c *EvidenceCollector) CollectFromStdin(r io.Reader, w io.Writer, opts CollectOptions) error {
	data, err := io.ReadAll(r)
	if err != nil {
		return fmt.Errorf("reading stdin: %w", err)
	}

	opts.Content = string(data)
	result := c.Collect(opts)

	if err := json.NewEncoder(w).Encode(result); err != nil {
		return err
	}
	if result.Error != "" {
		return fmt.Errorf("%s", result.Error)
	}
	return nil
}

// now は現在時刻を ISO 8601 UTC 形式で返す。
func (c *EvidenceCollector) now() string {
	if c.nowFunc != nil {
		return c.nowFunc()
	}
	return time.Now().UTC().Format(time.RFC3339)
}

// ---------------------------------------------------------------------------
// ユーティリティ
// ---------------------------------------------------------------------------

// ensureDir はディレクトリを作成する。
func ensureDir(dir string) error {
	return os.MkdirAll(dir, 0700)
}

// isSymlink はパスがシンボリックリンクかどうかを返す。
func isSymlink(path string) bool {
	fi, err := os.Lstat(path)
	if err != nil {
		return false
	}
	return fi.Mode()&os.ModeSymlink != 0
}

// splitLines は改行で分割し、空行を除外する。
func splitLines(data []byte) []string {
	var lines []string
	start := 0
	for i, b := range data {
		if b == '\n' {
			line := string(data[start:i])
			if line != "" {
				lines = append(lines, line)
			}
			start = i + 1
		}
	}
	if start < len(data) {
		line := string(data[start:])
		if line != "" {
			lines = append(lines, line)
		}
	}
	return lines
}
