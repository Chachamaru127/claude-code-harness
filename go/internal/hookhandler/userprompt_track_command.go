package hookhandler

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"time"
)

// TrackCommandHandler は UserPromptSubmit フックハンドラ（スラッシュコマンド追跡）。
// ユーザープロンプトから /slash コマンドを検出し、使用回数を記録する。
// また、必須コマンドは pending-skills マーカーファイルを作成する。
//
// shell 版: scripts/userprompt-track-command.sh
type TrackCommandHandler struct {
	// ProjectRoot はプロジェクトルートのパス。空の場合は cwd を使用する。
	ProjectRoot string
}

// trackCommandInput は UserPromptSubmit フックの入力。
type trackCommandInput struct {
	Prompt    string `json:"prompt"`
	SessionID string `json:"session_id"`
	CWD       string `json:"cwd"`
}

// lastSessionIDRecord は .claude/state/last-session-id.json のスキーマ。
// UserPromptSubmit ごとに実 session_id を記録し、`harness work-mode` の
// 解決チェーン第 3 段として使う (132.7)。同一 root の並行セッションでは
// 後勝ちになるため、読む側は updated_at の鮮度 (2h) を要求する。
type lastSessionIDRecord struct {
	SessionID string `json:"session_id"`
	UpdatedAt string `json:"updated_at"`
}

// trackCommandResponse は TrackCommand フックのレスポンス。
type trackCommandResponse struct {
	Continue bool `json:"continue"`
}

// pendingEntry は pending ファイルの内容。
type pendingEntry struct {
	Command       string `json:"command"`
	StartedAt     string `json:"started_at"`
	PromptPreview string `json:"prompt_preview"`
}

// skillRequiredCommands は pending マーカーを作成する必須コマンド一覧。
var skillRequiredCommands = map[string]bool{
	"work":            true,
	"harness-review":  true,
	"validate":        true,
	"plan-with-agent": true,
}

// slashCommandRe は行頭の /slash-command を検出する正規表現。
var slashCommandRe = regexp.MustCompile(`^/([a-zA-Z0-9_:/-]+)`)

// Handle は stdin からペイロードを読み取り、スラッシュコマンドを検出・記録する。
func (h *TrackCommandHandler) Handle(r io.Reader, w io.Writer) error {
	data, err := io.ReadAll(r)
	if err != nil {
		return writeTrackJSON(w, trackCommandResponse{Continue: true})
	}

	if len(data) == 0 {
		return writeTrackJSON(w, trackCommandResponse{Continue: true})
	}

	var input trackCommandInput
	if err := json.Unmarshal(data, &input); err != nil {
		return writeTrackJSON(w, trackCommandResponse{Continue: true})
	}

	// スラッシュコマンドの有無に関わらず、毎プロンプトで実 session_id を
	// 記録する (work-mode 解決チェーン用)。失敗は無視してフックを継続。
	h.recordLastSessionID(input)

	if input.Prompt == "" {
		return writeTrackJSON(w, trackCommandResponse{Continue: true})
	}

	// 最初の行のみチェック
	firstLine := strings.SplitN(input.Prompt, "\n", 2)[0]
	matches := slashCommandRe.FindStringSubmatch(firstLine)
	if matches == nil {
		return writeTrackJSON(w, trackCommandResponse{Continue: true})
	}

	rawCommand := matches[1]

	// コマンド名を正規化（プラグインプレフィックスを除去）
	// claude-code-harness:xxx:yyy → yyy（最後のセグメント）
	commandName := rawCommand
	if strings.HasPrefix(commandName, "harness:") || strings.HasPrefix(commandName, "harness/") || strings.HasPrefix(commandName, "claude-code-harness:") || strings.HasPrefix(commandName, "claude-code-harness/") {
		// 最後のセグメントを取り出す（: または / の後）
		parts := regexp.MustCompile(`[:/]`).Split(commandName, -1)
		commandName = parts[len(parts)-1]
	}

	if commandName == "" {
		return writeTrackJSON(w, trackCommandResponse{Continue: true})
	}

	projectRoot := h.ProjectRoot
	if projectRoot == "" {
		projectRoot, _ = os.Getwd()
	}

	stateDir := filepath.Join(projectRoot, ".claude", "state")
	pendingDir := filepath.Join(stateDir, "pending-skills")

	// Skill 必須コマンドかチェック
	if skillRequiredCommands[commandName] {
		if err := h.createPendingMarker(pendingDir, commandName, input.Prompt); err != nil {
			// pending ファイルの作成失敗は無視してフックを継続
			_, _ = fmt.Fprintf(os.Stderr, "[track-command] Warning: failed to create pending marker: %v\n", err)
		}
	}

	return writeTrackJSON(w, trackCommandResponse{Continue: true})
}

// recordLastSessionID は実 session_id を last-session-id.json へ書く。
// atomic rename で書き、失敗は警告のみ (フックは fail-open)。
func (h *TrackCommandHandler) recordLastSessionID(input trackCommandInput) {
	sid := strings.TrimSpace(input.SessionID)
	if sid == "" {
		return
	}
	projectRoot := h.ProjectRoot
	if projectRoot == "" {
		projectRoot = strings.TrimSpace(input.CWD)
	}
	if projectRoot == "" {
		projectRoot, _ = os.Getwd()
	}
	stateDir := filepath.Join(projectRoot, ".claude", "state")
	if isSymlink(filepath.Dir(stateDir)) || isSymlink(stateDir) {
		return
	}
	if err := os.MkdirAll(stateDir, 0o755); err != nil {
		return
	}
	rec := lastSessionIDRecord{
		SessionID: sid,
		UpdatedAt: time.Now().UTC().Format(time.RFC3339),
	}
	data, err := json.Marshal(rec)
	if err != nil {
		return
	}
	tmp, err := os.CreateTemp(stateDir, ".last-session-id-*.tmp")
	if err != nil {
		return
	}
	tmpName := tmp.Name()
	if _, err := tmp.Write(data); err != nil {
		tmp.Close()
		_ = os.Remove(tmpName)
		return
	}
	tmp.Close()
	if err := os.Rename(tmpName, filepath.Join(stateDir, "last-session-id.json")); err != nil {
		_ = os.Remove(tmpName)
		_, _ = fmt.Fprintf(os.Stderr, "[track-command] Warning: failed to record session id: %v\n", err)
	}
}

// createPendingMarker は pending マーカーファイルを作成する。
// シンボリックリンク経由のパス横断を防止するため、各パスを検証する。
func (h *TrackCommandHandler) createPendingMarker(pendingDir, commandName, prompt string) error {
	// シンボリックリンクチェック（pendingDir とその親）
	parentDir := filepath.Dir(pendingDir)
	if isSymlink(parentDir) || isSymlink(pendingDir) {
		return fmt.Errorf("symlink detected in state path, skipping")
	}

	// ディレクトリ作成（owner-only パーミッション）
	if err := os.MkdirAll(pendingDir, 0700); err != nil {
		return fmt.Errorf("mkdir pending dir: %w", err)
	}

	pendingFile := filepath.Join(pendingDir, commandName+".pending")

	// pending ファイル自体がシンボリックリンクでないか確認
	if isSymlink(pendingFile) {
		return fmt.Errorf("symlink detected at %s, skipping", pendingFile)
	}

	// prompt preview（最大200文字（rune）、改行をスペースに変換）
	preview := strings.ReplaceAll(prompt, "\n", " ")
	runes := []rune(preview)
	if len(runes) > 200 {
		preview = string(runes[:200])
	}

	entry := pendingEntry{
		Command:       commandName,
		StartedAt:     time.Now().UTC().Format(time.RFC3339),
		PromptPreview: preview,
	}

	entryData, err := json.MarshalIndent(entry, "", "  ")
	if err != nil {
		return fmt.Errorf("marshaling pending entry: %w", err)
	}

	// owner-only パーミッションで書き込み
	return os.WriteFile(pendingFile, entryData, 0600)
}

// writeTrackJSON は v を JSON として w に書き出す。
func writeTrackJSON(w io.Writer, v interface{}) error {
	data, err := json.Marshal(v)
	if err != nil {
		return fmt.Errorf("marshaling JSON: %w", err)
	}
	_, err = fmt.Fprintf(w, "%s\n", data)
	return err
}
