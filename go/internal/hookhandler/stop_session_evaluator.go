package hookhandler

import (
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"strings"

	"github.com/Chachamaru127/claude-code-harness/go/internal/plans"
)

// stopSessionInput は Stop フックの stdin JSON ペイロード。
// CC 2.1.47+ で last_assistant_message が含まれる。
type stopSessionInput struct {
	StopHookActive       bool   `json:"stop_hook_active"`
	TranscriptPath       string `json:"transcript_path"`
	LastAssistantMessage string `json:"last_assistant_message"`
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
	// Plans.md の status が Stop 再入時の進捗シグナルであり、stop_hook_active は
	// bypass フラグではない。再入のたびに Plans.md を再読込し、実 WIP が残る間だけ
	// block を継続する。ホスト側の block cap が runaway loop の最終ガードになる。
	wipCount := h.countWIPTasks(projectRoot)
	if wipCount > 0 {
		var msg string
		if input.StopHookActive {
			msg = fmt.Sprintf(
				localizedHarnessMessage("ja",
					"[StopSession] %d WIP tasks remain after Stop re-entry. Transition each task to cc:done or blocked before stopping.",
					"[StopSession] Stop 再入後も %d 件の WIP タスクが残っています。停止前に各タスクを cc:done または blocked へ遷移してください。"),
				wipCount,
			)
		} else {
			msg = fmt.Sprintf(
				localizedHarnessMessage("ja",
					"[StopSession] %d WIP tasks remain. Check Plans.md.",
					"[StopSession] %d WIP タスクが残っています。Plans.md を確認してください。"),
				wipCount,
			)
		}
		return writeJSON(out, stopSessionResponse{
			Decision: "block",
			Reason:   msg,
		})
	}

	return writeJSON(out, stopSessionResponse{OK: true})
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
