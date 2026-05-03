package hookhandler

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"time"
)

// PostToolUseLogToolNameHandler は PostToolUse フックハンドラ。
// 全ツール使用をログに記録し、LSP ツール追跡・セッションイベントログを管理する。
//
// shell 版: scripts/posttooluse-log-toolname.sh
type PostToolUseLogToolNameHandler struct {
	// ProjectRoot はプロジェクトルートのパス。空の場合は cwd を使用する。
	ProjectRoot string
}

// logToolNameInput は PostToolUse フックの stdin JSON。
type logToolNameInput struct {
	ToolName  string               `json:"tool_name"`
	SessionID string               `json:"session_id"`
	ToolInput logToolNameToolInput `json:"tool_input"`
}

type logToolNameToolInput struct {
	FilePath string `json:"file_path"`
	Command  string `json:"command"`
	Skill    string `json:"skill"`
}

// toolEventEntry は tool-events.jsonl の 1 行エントリ。
type toolEventEntry struct {
	V             int    `json:"v"`
	Ts            string `json:"ts"`
	SessionID     string `json:"session_id"`
	PromptSeq     int    `json:"prompt_seq"`
	HookEventName string `json:"hook_event_name"`
	ToolName      string `json:"tool_name"`
}

// sessionEventEntry は session-events.jsonl の 1 行エントリ。
type sessionEventEntry struct {
	ID    string          `json:"id"`
	Type  string          `json:"type"`
	Ts    string          `json:"ts"`
	State string          `json:"state"`
	Data  json.RawMessage `json:"data,omitempty"`
}

// sessionState は session.json の最小構造。
type sessionState struct {
	PromptSeq int    `json:"prompt_seq"`
	EventSeq  int    `json:"event_seq"`
	State     string `json:"state"`
	UpdatedAt string `json:"updated_at"`
	LastEvID  string `json:"last_event_id"`
}

// skillsUsedState は session-skills-used.json の構造。
type skillsUsedState struct {
	Used         []string `json:"used"`
	SessionStart string   `json:"session_start"`
	LastUsed     string   `json:"last_used,omitempty"`
}

const (
	toolEventsFile    = "tool-events.jsonl"
	sessionEventsFile = "session-events.jsonl"
	skillsUsedFile    = "session-skills-used.json"
	logMaxSizeBytes   = 256 * 1024 // 256KB
	logMaxLines       = 2000
	logMaxGenerations = 5
	sessionEvMaxLines = 500
)

// Handle は stdin から PostToolUse ペイロードを読み取り、ログを記録する。
func (h *PostToolUseLogToolNameHandler) Handle(r io.Reader, w io.Writer) error {
	data, _ := io.ReadAll(r)

	if len(data) > 0 {
		var inp logToolNameInput
		if err := json.Unmarshal(data, &inp); err == nil && inp.ToolName != "" {
			projectRoot := h.resolveProjectRoot()
			stateDir := filepath.Join(projectRoot, ".claude", "state")
			_ = os.MkdirAll(stateDir, 0700)

			promptSeq := h.readPromptSeq(stateDir)

			// LSP 追跡（常に実行）
			if strings.Contains(strings.ToLower(inp.ToolName), "lsp") {
				h.trackLSP(stateDir, inp.ToolName, promptSeq)
			}

			// Phase0 ログ収集（CC_HARNESS_PHASE0_LOG=1 の時のみ）
			if os.Getenv("CC_HARNESS_PHASE0_LOG") == "1" {
				h.appendToolEvent(stateDir, inp, promptSeq)
			}

			// セッションイベントログ（重要ツールのみ）
			if isImportantTool(inp.ToolName) {
				ts := time.Now().UTC().Format(time.RFC3339)
				dataJSON := buildEventData(inp)
				h.appendSessionEvent(stateDir, inp.ToolName, ts, dataJSON)
			}

			// Skill 追跡（セッション単位）
			if inp.ToolName == "Skill" {
				h.trackSkillUsed(stateDir, inp.ToolInput.Skill)
			}
		}
	}

	// 常に {"continue": true} を返す
	_, err := fmt.Fprintf(w, `{"continue":true}%s`, "\n")
	return err
}

// resolveProjectRoot はプロジェクトルートを解決する。
func (h *PostToolUseLogToolNameHandler) resolveProjectRoot() string {
	if h.ProjectRoot != "" {
		return h.ProjectRoot
	}
	wd, _ := os.Getwd()
	return wd
}

// readPromptSeq は session.json から prompt_seq を読み込む。
func (h *PostToolUseLogToolNameHandler) readPromptSeq(stateDir string) int {
	sessionFile := filepath.Join(stateDir, "session.json")
	rawData, err := os.ReadFile(sessionFile)
	if err != nil {
		return 0
	}
	var s map[string]interface{}
	if err := json.Unmarshal(rawData, &s); err != nil {
		return 0
	}
	if v, ok := s["prompt_seq"].(float64); ok {
		return int(v)
	}
	return 0
}

// trackLSP は LSP ツール使用を tooling-policy.json に記録する。
func (h *PostToolUseLogToolNameHandler) trackLSP(stateDir, toolName string, promptSeq int) {
	policyFile := filepath.Join(stateDir, "tooling-policy.json")
	rawData, err := os.ReadFile(policyFile)
	if err != nil {
		return
	}

	var policy map[string]interface{}
	if err := json.Unmarshal(rawData, &policy); err != nil {
		return
	}

	lsp, ok := policy["lsp"].(map[string]interface{})
	if !ok {
		lsp = make(map[string]interface{})
	}
	lsp["last_used_prompt_seq"] = promptSeq
	lsp["last_used_tool_name"] = toolName
	lsp["used_since_last_prompt"] = true
	policy["lsp"] = lsp

	updated, err := json.MarshalIndent(policy, "", "  ")
	if err != nil {
		return
	}

	tmp := policyFile + ".tmp"
	if err := os.WriteFile(tmp, updated, 0600); err != nil {
		return
	}
	_ = os.Rename(tmp, policyFile)
}

// appendToolEvent は tool-events.jsonl に JSONL エントリを追記する（flock でロック）。
func (h *PostToolUseLogToolNameHandler) appendToolEvent(stateDir string, inp logToolNameInput, promptSeq int) {
	logFile := filepath.Join(stateDir, toolEventsFile)
	lockFile := logFile + ".lock"

	entry := toolEventEntry{
		V:             1,
		Ts:            time.Now().UTC().Format(time.RFC3339),
		SessionID:     inp.SessionID,
		PromptSeq:     promptSeq,
		HookEventName: "PostToolUse",
		ToolName:      inp.ToolName,
	}

	line, err := json.Marshal(entry)
	if err != nil {
		return
	}

	withFileLock(lockFile, func() {
		// ローテーション判定
		if needsRotation(logFile, logMaxSizeBytes, logMaxLines) {
			rotateLog(logFile, logMaxGenerations)
		}

		f, err := os.OpenFile(logFile, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0600)
		if err != nil {
			return
		}
		defer f.Close()
		_, _ = fmt.Fprintf(f, "%s\n", line)
	})
}

// appendSessionEvent はセッションイベントログに追記し、session.json を更新する。
func (h *PostToolUseLogToolNameHandler) appendSessionEvent(stateDir, toolName, ts, dataJSON string) {
	sessionFile := filepath.Join(stateDir, "session.json")
	eventLogFile := filepath.Join(stateDir, sessionEventsFile)
	lockFile := eventLogFile + ".lock"

	if _, err := os.Stat(sessionFile); os.IsNotExist(err) {
		return
	}

	withFileLock(lockFile, func() {
		// session.json を読み込む
		rawData, err := os.ReadFile(sessionFile)
		if err != nil {
			return
		}
		var session map[string]interface{}
		if err := json.Unmarshal(rawData, &session); err != nil {
			return
		}

		// event_seq をインクリメント
		eventSeq := 0
		if v, ok := session["event_seq"].(float64); ok {
			eventSeq = int(v)
		}
		eventSeq++
		eventID := fmt.Sprintf("event-%06d", eventSeq)

		currentState := "executing"
		if v, ok := session["state"].(string); ok && v != "" {
			currentState = v
		}

		// session.json を更新
		session["updated_at"] = ts
		session["last_event_id"] = eventID
		session["event_seq"] = eventSeq

		updated, err := json.MarshalIndent(session, "", "  ")
		if err != nil {
			return
		}
		tmp := sessionFile + ".tmp"
		if err := os.WriteFile(tmp, updated, 0600); err != nil {
			return
		}
		_ = os.Rename(tmp, sessionFile)

		// イベントログファイルを初期化
		_ = touchFile(eventLogFile)

		// ローテーション判定（行数のみ）
		if needsRotationLines(eventLogFile, sessionEvMaxLines) {
			rotateLog(eventLogFile, logMaxGenerations)
		}

		// エントリ構築
		toolType := strings.ToLower(toolName)
		var eventLine []byte
		if dataJSON != "" {
			eventLine, _ = json.Marshal(map[string]interface{}{
				"id":    eventID,
				"type":  "tool." + toolType,
				"ts":    ts,
				"state": currentState,
				"data":  json.RawMessage(dataJSON),
			})
		} else {
			eventLine, _ = json.Marshal(map[string]interface{}{
				"id":    eventID,
				"type":  "tool." + toolType,
				"ts":    ts,
				"state": currentState,
			})
		}

		f, err := os.OpenFile(eventLogFile, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0600)
		if err != nil {
			return
		}
		defer f.Close()
		_, _ = fmt.Fprintf(f, "%s\n", eventLine)
	})
}

// trackSkillUsed は Skill ツール使用を session-skills-used.json に記録する。
func (h *PostToolUseLogToolNameHandler) trackSkillUsed(stateDir, skillName string) {
	skillsFile := filepath.Join(stateDir, skillsUsedFile)

	if skillName == "" {
		skillName = "unknown"
	}

	// ファイルが存在しない場合は初期化
	if _, err := os.Stat(skillsFile); os.IsNotExist(err) {
		initial := skillsUsedState{
			Used:         []string{},
			SessionStart: time.Now().UTC().Format(time.RFC3339),
		}
		rawData, _ := json.MarshalIndent(initial, "", "  ")
		_ = os.WriteFile(skillsFile, rawData, 0600)
	}

	rawData, err := os.ReadFile(skillsFile)
	if err != nil {
		return
	}

	var state skillsUsedState
	if err := json.Unmarshal(rawData, &state); err != nil {
		return
	}

	state.Used = append(state.Used, skillName)
	state.LastUsed = time.Now().UTC().Format(time.RFC3339)

	updated, err := json.MarshalIndent(state, "", "  ")
	if err != nil {
		return
	}

	tmp := skillsFile + ".tmp"
	if err := os.WriteFile(tmp, updated, 0600); err != nil {
		return
	}
	_ = os.Rename(tmp, skillsFile)
}

// isImportantTool は重要なツールかどうかを判定する。
func isImportantTool(toolName string) bool {
	switch toolName {
	case "Write", "Edit", "Bash", "Task", "Skill", "SlashCommand":
		return true
	}
	return false
}

// buildEventData はツール使用からイベントデータ JSON 文字列を構築する。
func buildEventData(inp logToolNameInput) string {
	if inp.ToolInput.FilePath != "" {
		fp := trimText(inp.ToolInput.FilePath, 200)
		return fmt.Sprintf(`{"file_path":%s}`, jsonString(fp))
	}
	if inp.ToolInput.Command != "" {
		cmd := trimText(inp.ToolInput.Command, 200)
		return fmt.Sprintf(`{"command":%s}`, jsonString(cmd))
	}
	return ""
}

// trimText は文字列を最大 maxLen 文字（rune 単位）に切り詰める。
func trimText(s string, maxLen int) string {
	runes := []rune(s)
	if len(runes) > maxLen {
		return string(runes[:maxLen])
	}
	return s
}

// jsonString は Go 文字列を JSON 文字列表現に変換する。
func jsonString(s string) string {
	b, _ := json.Marshal(s)
	return string(b)
}

// needsRotation はログファイルのローテーションが必要かを判定する（サイズ・行数）。
func needsRotation(path string, maxBytes, maxLines int) bool {
	fi, err := os.Stat(path)
	if err != nil {
		return false
	}
	if int(fi.Size()) >= maxBytes {
		return true
	}
	return needsRotationLines(path, maxLines)
}

// needsRotationLines はログファイルの行数がしきい値を超えているか判定する。
func needsRotationLines(path string, maxLines int) bool {
	f, err := os.Open(path)
	if err != nil {
		return false
	}
	defer f.Close()

	count := 0
	buf := make([]byte, 32*1024)
	for {
		n, err := f.Read(buf)
		for i := 0; i < n; i++ {
			if buf[i] == '\n' {
				count++
				if count >= maxLines {
					return true
				}
			}
		}
		if err != nil {
			break
		}
	}
	return false
}

// rotateLog はログファイルをローテーションする（.1 → .2 → ... → maxGen）。
func rotateLog(path string, maxGen int) {
	// 最古を削除
	oldest := fmt.Sprintf("%s.%d", path, maxGen)
	_ = os.Remove(oldest)

	// .{n-1} → .{n} にリネーム
	for i := maxGen - 1; i >= 1; i-- {
		src := fmt.Sprintf("%s.%d", path, i)
		dst := fmt.Sprintf("%s.%d", path, i+1)
		_ = os.Rename(src, dst)
	}

	// 現行を .1 に
	_ = os.Rename(path, path+".1")
	// 新しいファイルを作成
	_ = touchFile(path)
}

// touchFile はファイルを作成（存在する場合はそのまま）。
func touchFile(path string) error {
	f, err := os.OpenFile(path, os.O_CREATE|os.O_WRONLY, 0600)
	if err != nil {
		return err
	}
	return f.Close()
}

// withFileLock はファイルロックを取得して fn を実行する。
// flock(2) システムコールを使用し、失敗時はロックなしで実行する（ベストエフォート）。
func withFileLock(lockFile string, fn func()) {
	f, err := os.OpenFile(lockFile, os.O_CREATE|os.O_RDWR, 0600)
	if err != nil {
		// ロックファイルを開けない場合はロックなしで実行
		fn()
		return
	}
	defer f.Close()

	// flock で排他ロック（タイムアウトなし、ブロック）
	if err := fileLock(int(f.Fd()), fileLockExclusive); err != nil {
		// flock が使えない環境ではロックなしで実行
		fn()
		return
	}
	defer func() {
		_ = fileLock(int(f.Fd()), fileLockUnlock)
	}()

	fn()
}
