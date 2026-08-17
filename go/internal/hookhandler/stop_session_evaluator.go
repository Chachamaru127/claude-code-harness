package hookhandler

import (
	"bufio"
	"crypto/sha256"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"

	"github.com/Chachamaru127/claude-code-harness/go/internal/plans"
	"github.com/Chachamaru127/claude-code-harness/go/internal/scopeleash"
)

// stopSessionInput は Stop フックの stdin JSON ペイロード。
// CC 2.1.47+ で last_assistant_message が含まれる。
type stopSessionInput struct {
	StopHookActive       bool   `json:"stop_hook_active"`
	TranscriptPath       string `json:"transcript_path"`
	LastAssistantMessage string `json:"last_assistant_message"`
	SessionID            string `json:"session_id"`
}

// stopSessionResponse は Stop フックのレスポンス。
type stopSessionResponse struct {
	OK            bool   `json:"ok,omitempty"`
	Decision      string `json:"decision,omitempty"`
	Reason        string `json:"reason,omitempty"`
	SystemMessage string `json:"systemMessage,omitempty"`
}

// StopSessionEvaluatorHandler は scripts/hook-handlers/stop-session-evaluator.sh の Go 移植。
//
// Stop イベントでセッション状態を評価する。
//   - last_assistant_message を長さ・ハッシュ（SHA-256 先頭 16 文字）にして session.json に記録
//   - Plans.md の status 列に WIP タスクがある場合は decision:block を返す
//   - WIP がない場合だけ停止を許可する（ok: true）
type StopSessionEvaluatorHandler struct {
	// ProjectRoot はプロジェクトルートのパス。空の場合は環境変数/CWD から解決。
	ProjectRoot string
}

// Handle は Stop フックを処理する。
func (h *StopSessionEvaluatorHandler) Handle(in io.Reader, out io.Writer) error {
	// プロジェクトルート解決
	projectRoot := h.ProjectRoot
	if projectRoot == "" {
		projectRoot = resolveProjectRoot()
	}
	stateFile := projectRoot + "/.claude/state/session.json"

	// stdin を読み取る（サイズ上限: 64 KiB）
	var payload []byte
	limited := io.LimitReader(in, 65536)
	payload, _ = io.ReadAll(limited)

	// last_assistant_message のメタデータを session.json に記録
	var input stopSessionInput
	if len(payload) > 0 {
		if jsonErr := json.Unmarshal(payload, &input); jsonErr == nil {
			if input.LastAssistantMessage != "" {
				h.recordLastMessage(stateFile, input.LastAssistantMessage)
			}
		}
	}

	// WIP タスクチェック: Plans.md を探して canonical WIP status を数える。
	// session.json の state は bookkeeping なので、stopped / 欠損 / 壊れた状態の
	// いずれも WIP gate を bypass できない。
	//
	// Issue #269: stop_hook_active (再入) は「1 回 block 済み」のシグナルとして扱う。
	// 初回 Stop で WIP が残っていれば block して marker 遷移を促す (nudge) が、
	// 再入してもなお WIP が残る場合はもう block しない。block を繰り返すと調査のみの
	// セッションが停止不能になる (実測 12 連続発火)。再入時は停止を許可し、
	// systemMessage で警告するだけに留める。ホスト側の block cap には依存しない設計にする。
	wipCount := h.countWIPTasks(projectRoot)
	if wipCount > 0 {
		if input.StopHookActive {
			msg := fmt.Sprintf(
				localizedHarnessMessage("ja",
					"[StopSession] Stopping with %d WIP tasks remaining. Check Plans.md markers in the next session.",
					"[StopSession] %d 件の WIP タスクを残したまま停止します。次回セッションで Plans.md の marker を確認してください。"),
				wipCount,
			)
			return writeJSON(out, stopSessionResponse{
				OK:            true,
				SystemMessage: msg,
			})
		}
		msg := fmt.Sprintf(
			localizedHarnessMessage("ja",
				"[StopSession] %d WIP tasks remain. Check Plans.md.",
				"[StopSession] %d WIP タスクが残っています。Plans.md を確認してください。"),
			wipCount,
		)
		return writeJSON(out, stopSessionResponse{
			Decision: "block",
			Reason:   msg,
		})
	}

	if notice := h.droppedScopeAdvisory(projectRoot, input.SessionID); notice != "" {
		return writeJSON(out, stopSessionResponse{OK: true, SystemMessage: notice})
	}

	return writeJSON(out, stopSessionResponse{OK: true})
}

// droppedScopeAdvisory (134.5) is the DroppedScope extension of this Stop
// handler: when the active task declared a scope (via the sprint-contract's
// declared_scope, baked in at generation time) and this run never touched
// some of it, surface an advisory notice. This never blocks the stop — it
// only decorates the ok:true response's systemMessage — and it registers no
// new hook (hooks.json is unchanged); it is purely an extension of the
// existing Stop handler.
func (h *StopSessionEvaluatorHandler) droppedScopeAdvisory(projectRoot, sessionID string) string {
	taskID, ok := resolveActiveTaskForStop(projectRoot)
	if !ok {
		return ""
	}
	declared := loadDeclaredScopeForStop(projectRoot, taskID)
	if len(declared) == 0 {
		return ""
	}
	touched := loadTouchedFilesForStop(projectRoot, sessionID)
	dropped := scopeleash.DroppedScope(declared, touched)
	if len(dropped) == 0 {
		return ""
	}
	return fmt.Sprintf(
		localizedHarnessMessage("ja",
			"[ScopeLeash] Task %s declared scope not touched this run: %s",
			"[ScopeLeash] タスク %s の declared_scope のうち今回未着手のもの: %s"),
		taskID, strings.Join(dropped, ", "),
	)
}

// resolveActiveTaskForStop resolves the task ID .claude/state/active-task.json
// declares, falling back to HARNESS_ACTIVE_TASK when the file is absent.
// Mirrors go/internal/guardrail's resolveActiveTaskScope (task field only;
// that function lives in a different package with no import path back here).
func resolveActiveTaskForStop(projectRoot string) (string, bool) {
	activeTaskPath := filepath.Join(projectRoot, ".claude", "state", "active-task.json")
	data, err := os.ReadFile(activeTaskPath)
	switch {
	case err == nil:
		var scope struct {
			Task string `json:"task"`
		}
		if jsonErr := json.Unmarshal(data, &scope); jsonErr != nil {
			return "", false
		}
		task := strings.TrimSpace(scope.Task)
		return task, task != ""
	case !errors.Is(err, os.ErrNotExist):
		return "", false
	}

	task := strings.TrimSpace(os.Getenv("HARNESS_ACTIVE_TASK"))
	return task, task != ""
}

// loadDeclaredScopeForStop reads the declared_scope baked into taskID's
// sprint-contract.json at generation time (Generate() in sprint_contract.go).
func loadDeclaredScopeForStop(projectRoot, taskID string) []string {
	path := filepath.Join(projectRoot, ".claude", "state", "contracts", taskID+".sprint-contract.json")
	data, err := os.ReadFile(path)
	if err != nil {
		return nil
	}
	var doc struct {
		Task struct {
			DeclaredScope []string `json:"declared_scope"`
		} `json:"task"`
	}
	if err := json.Unmarshal(data, &doc); err != nil {
		return nil
	}
	return doc.Task.DeclaredScope
}

// loadTouchedFilesForStop reads the de-duplicated set of files the current
// session wrote to from .claude/state/changed-files.jsonl (track_changes.go's
// PostToolUse record). Order is first-seen; malformed lines are skipped.
//
// changed-files.jsonl is a cross-session append-only log: entries from other
// sessions (including entries written before session_id was recorded) remain
// on disk indefinitely. This narrows results to entries whose session_id
// matches sessionID, so a stale entry from a different session's writes
// cannot be misread as "this session touched this file". Both an empty
// sessionID (Stop payload lacked session_id) and an empty entry.SessionID
// (pre-existing log line, or an entry genuinely missing session_id) fail the
// match and are skipped — the conservative direction, since callers use this
// to decide whether to block/advise the current Stop.
func loadTouchedFilesForStop(projectRoot, sessionID string) []string {
	if sessionID == "" {
		return nil
	}

	f, err := os.Open(filepath.Join(projectRoot, changedFilesPath))
	if err != nil {
		return nil
	}
	defer f.Close()

	seen := map[string]struct{}{}
	var touched []string
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
		if entry.File == "" {
			continue
		}
		if entry.SessionID != sessionID {
			continue
		}
		if _, dup := seen[entry.File]; dup {
			continue
		}
		seen[entry.File] = struct{}{}
		touched = append(touched, entry.File)
	}
	return touched
}

// recordLastMessage は session.json に last_message_length と last_message_hash を記録する。
// 平文内容は保存しない（プライバシー保護）。
func (h *StopSessionEvaluatorHandler) recordLastMessage(stateFile, msg string) {
	// ファイルが存在しない場合はスキップ（bash 版と同じ動作）
	sessionData, err := os.ReadFile(stateFile)
	if err != nil {
		return
	}

	var sessionMap map[string]interface{}
	if jsonErr := json.Unmarshal(sessionData, &sessionMap); jsonErr != nil {
		return
	}

	msgLen := len(msg)
	hash := fmt.Sprintf("%x", sha256.Sum256([]byte(msg)))[:16]

	sessionMap["last_message_length"] = msgLen
	sessionMap["last_message_hash"] = hash

	newData, err := json.Marshal(sessionMap)
	if err != nil {
		return
	}

	// アトミック書き込み: 一時ファイル + rename
	stateDir := stateFile[:strings.LastIndex(stateFile, "/")]
	tmpFile, err := os.CreateTemp(stateDir, "session.json.*")
	if err != nil {
		return
	}
	tmpPath := tmpFile.Name()
	defer func() {
		// rename 失敗時のクリーンアップ
		os.Remove(tmpPath)
	}()

	if _, err := tmpFile.Write(append(newData, '\n')); err != nil {
		tmpFile.Close()
		return
	}
	tmpFile.Close()

	_ = os.Rename(tmpPath, stateFile)
}

// countWIPTasks は projectRoot 配下の Plans.md を探し、table と heading task の
// canonical WIP status 数を返す。
func (h *StopSessionEvaluatorHandler) countWIPTasks(projectRoot string) int {
	path := resolvePlansPath(projectRoot)
	if path == "" {
		return 0
	}
	data, err := os.ReadFile(path)
	if err != nil {
		return 0
	}
	content := string(data)
	count := 0
	for _, task := range plans.ParseMarkdown(content) {
		if task.Tags.Wip {
			count++
		}
	}
	return count + countHeadingWIPTasks(content)
}

// countHeadingWIPTasks counts only valid task headings whose terminal status
// marker is WIP. Prose and marker mentions inside task titles do not qualify.
func countHeadingWIPTasks(content string) int {
	count := 0
	for _, line := range strings.Split(content, "\n") {
		if match := headingTaskRe.FindStringSubmatch(line); len(match) < 4 {
			continue
		}
		matches := headingStatusRe.FindAllStringIndex(line, -1)
		if len(matches) == 0 {
			continue
		}
		last := matches[len(matches)-1]
		if suffix := strings.TrimSpace(line[last[1]:]); strings.Trim(suffix, "`") != "" {
			continue
		}
		if plans.IsWIPStatus(line[last[0]:last[1]]) {
			count++
		}
	}
	return count
}
