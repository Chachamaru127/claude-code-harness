package hookhandler

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/Chachamaru127/claude-code-harness/go/internal/plans"
)

// exitFailClosed は lock 取得失敗など fail-closed パスで呼び出す。
// PostToolUse フック仕様では exit code 非ゼロがフックエラー扱いになる。
// これにより Plans 更新が静かに drop される「ロストアップデート」を防ぐ。
// テストから直接呼ばれることはない（モック可能な変数で差し替える）。
var exitFailClosed = func(msg string) {
	fmt.Fprintf(os.Stderr, "[plans-watcher] fail-closed exit: %s\n", msg)
	os.Exit(1)
}

// plansWatcherInput は plans-watcher.sh に渡される stdin JSON。
type plansWatcherInput struct {
	ToolName  string `json:"tool_name"`
	CWD       string `json:"cwd"`
	ToolInput struct {
		FilePath string `json:"file_path"`
	} `json:"tool_input"`
	ToolResponse struct {
		FilePath string `json:"filePath"`
	} `json:"tool_response"`
}

// plansStateFile は前回の状態を保存するファイルのパス。
const plansStateFile = ".claude/state/plans-state.json"

// plansLockFile は plans-state.json の排他制御に使用する flock ファイルのパス。
// shell 版 scripts/plans-watcher.sh の 3-tier fallback と意味的に同等。
const plansLockFile = ".claude/state/locks/plans.flock"

// plansLockDirSuffix は flock が利用できない環境で使う mkdir ベースのフォールバックロック名。
const plansLockDirSuffix = ".dir"

// plansLockMaxRetries は lock 取得の最大リトライ回数。
const plansLockMaxRetries = 3

// flockCall と sleepCall はテスト差し替え用。
var flockCall = func(fd int, how int) error {
	return fileLock(fd, how)
}

var sleepCall = time.Sleep

// plansLockHandle は flock または mkdir fallback のどちらかを表す。
type plansLockHandle struct {
	file    *os.File
	lockDir string
	mode    string
}

// acquirePlansLock は plans-state.json を保護する排他ロックを取得する。
// 通常は flock を使い、共有ストレージなどで flock が使えない場合のみ
// mkdir ベースのアトミックロックへフォールバックする。
func acquirePlansLock(lockPath string) (*plansLockHandle, error) {
	if err := os.MkdirAll(filepath.Dir(lockPath), 0o755); err != nil {
		return nil, fmt.Errorf("mkdir for plans lock: %w", err)
	}
	for attempt := 1; attempt <= plansLockMaxRetries; attempt++ {
		f, err := os.OpenFile(lockPath, os.O_CREATE|os.O_RDWR, 0o644)
		if err != nil {
			return nil, fmt.Errorf("open plans lock file: %w", err)
		}

		if err := flockCall(int(f.Fd()), fileLockExclusive|fileLockNonblock); err == nil {
			return &plansLockHandle{
				file:    f,
				lockDir: lockPath + plansLockDirSuffix,
				mode:    "flock",
			}, nil
		} else if !isPlansLockBusy(err) {
			f.Close()
			return acquirePlansMkdirLock(lockPath + plansLockDirSuffix)
		}

		f.Close()
		if attempt < plansLockMaxRetries {
			sleepCall(1 * time.Second)
		}
	}
	return nil, fmt.Errorf("failed to acquire plans lock after %d retries", plansLockMaxRetries)
}

func acquirePlansMkdirLock(lockDir string) (*plansLockHandle, error) {
	for attempt := 1; attempt <= plansLockMaxRetries; attempt++ {
		if err := os.Mkdir(lockDir, 0o755); err == nil {
			return &plansLockHandle{
				lockDir: lockDir,
				mode:    "mkdir",
			}, nil
		} else if !errors.Is(err, os.ErrExist) {
			return nil, fmt.Errorf("mkdir fallback lock: %w", err)
		}

		if attempt < plansLockMaxRetries {
			sleepCall(1 * time.Second)
		}
	}
	return nil, fmt.Errorf("failed to acquire mkdir fallback lock after %d retries", plansLockMaxRetries)
}

func isPlansLockBusy(err error) bool {
	return fileLockBusy(err)
}

// releasePlansLock はロックを解放してファイルをクローズする。
func releasePlansLock(lock *plansLockHandle) {
	if lock == nil {
		return
	}
	switch lock.mode {
	case "mkdir":
		os.Remove(lock.lockDir) //nolint:errcheck
	default:
		if lock.file == nil {
			return
		}
		flockCall(int(lock.file.Fd()), fileLockUnlock) //nolint:errcheck
		lock.file.Close()
	}
}

// pmNotificationFile は PM 通知ファイルのパス。
const pmNotificationFile = ".claude/state/pm-notification.md"

// cursorNotificationFile は互換用 cursor 通知ファイルのパス。
const cursorNotificationFile = ".claude/state/cursor-notification.md"

// plansState は Plans.md のマーカー集計状態。
type plansState struct {
	Timestamp   string `json:"timestamp"`
	PmPending   int    `json:"pm_pending"`
	CcTodo      int    `json:"cc_todo"`
	CcWip       int    `json:"cc_wip"`
	CcDone      int    `json:"cc_done"`
	PmConfirmed int    `json:"pm_confirmed"`
}

// plansFileNames は検索対象の Plans.md ファイル名候補。
var plansFileNames = []string{"Plans.md", "plans.md", "PLANS.md", "PLANS.MD"}

// HandlePlansWatcher は plans-watcher.sh の Go 移植。
//
// PostToolUse Write/Edit イベントで呼び出され、Plans.md への変更を検出する。
// WIP/TODO/done マーカーの集計サマリを生成し、PM 通知ファイルに書き込む。
// Plans.md 以外のファイルはスキップ。
func HandlePlansWatcher(in io.Reader, out io.Writer) error {
	data, err := io.ReadAll(in)
	if err != nil {
		return emptyPostToolOutput(out)
	}

	if len(strings.TrimSpace(string(data))) == 0 {
		return emptyPostToolOutput(out)
	}

	var input plansWatcherInput
	if err := json.Unmarshal(data, &input); err != nil {
		return emptyPostToolOutput(out)
	}

	// 変更されたファイルパスを取得
	changedFile := input.ToolInput.FilePath
	if changedFile == "" {
		changedFile = input.ToolResponse.FilePath
	}

	if changedFile == "" {
		return emptyPostToolOutput(out)
	}

	projectRoot := resolveProjectRoot(input.CWD)
	changedFile = normalizePathSeparators(changedFile)
	if !filepath.IsAbs(changedFile) {
		changedFile = filepath.Join(firstNonEmpty(input.CWD, projectRoot), changedFile)
	}

	// Plans.md と state を同じプロジェクトルートから解決する。
	plansFile := resolvePlansPath(projectRoot)
	if plansFile == "" {
		return emptyPostToolOutput(out)
	}

	// 変更されたファイルが Plans.md でない場合はスキップ（完全パスで厳密比較）
	if !isPlansFileWithRoot(changedFile, plansFile, projectRoot) {
		return emptyPostToolOutput(out)
	}

	// lock、state、通知を同じルートに置き、サブディレクトリ間でも共有する。
	lockPath := filepath.Join(projectRoot, plansLockFile)
	stateFilePath := filepath.Join(projectRoot, plansStateFile)

	// plans-state.json の read-modify-write を flock で保護する。
	// Worker との競合で state を失わないよう fail-closed: lock 取得失敗時は処理を中断。
	// PostToolUse フック仕様では exit code 非ゼロがフックエラー扱いになる。
	// emptyPostToolOutput（= 空成功応答）を返すと hook framework は成功と解釈するため、
	// ロストアップデートが発生する。exitFailClosed で exit code 1 を返すことで
	// Plans 更新の drop を hook framework に明示的にエラーとして通知する。
	lockFile, lockErr := acquirePlansLock(lockPath)
	if lockErr != nil {
		fmt.Fprintf(os.Stderr, "[plans-watcher] lock acquisition failed (fail-closed): %v\n", lockErr)
		exitFailClosed("lock acquisition timed out (3 retries exhausted)")
		// exitFailClosed は通常 os.Exit(1) するが、テスト時にモック差し替えで
		// 通過する場合に備えて空応答にフォールバックする。
		return emptyPostToolOutput(out)
	}
	defer releasePlansLock(lockFile)

	// 現在の状態を集計
	current, err := collectPlansState(plansFile)
	if err != nil {
		return emptyPostToolOutput(out)
	}

	// 前回の状態を読み込む（プロジェクトルート基準）
	prev := loadPrevPlansState(stateFilePath)

	// 状態を保存（プロジェクトルート基準）
	stateDir := filepath.Dir(stateFilePath)
	if mkErr := os.MkdirAll(stateDir, 0o755); mkErr == nil {
		savePlansState(stateFilePath, current)
	}

	// 変更の種類を判定
	hasNewTasks := current.PmPending > prev.PmPending
	hasCompletedTasks := current.CcDone > prev.CcDone

	if !hasNewTasks && !hasCompletedTasks {
		return emptyPostToolOutput(out)
	}

	// PM 通知ファイルを生成
	locale := resolveHarnessLocale(projectRoot)
	if err := writePMNotification(projectRoot, current, hasNewTasks, hasCompletedTasks, locale); err != nil {
		fmt.Fprintf(os.Stderr, "[plans-watcher] write notification: %v\n", err)
	}

	// systemMessage で通知サマリを出力
	summary := buildSummaryMessage(current, hasNewTasks, hasCompletedTasks, locale)
	o := postToolOutput{}
	o.HookSpecificOutput.HookEventName = "PostToolUse"
	o.HookSpecificOutput.AdditionalContext = summary
	return writeJSON(out, o)
}

// findPlansFile は現在のディレクトリで Plans.md を探す。
func findPlansFile() string {
	for _, name := range plansFileNames {
		if _, err := os.Stat(name); err == nil {
			return name
		}
	}
	return ""
}

// isPlansFile は変更されたファイルが Plans.md かどうかを判定する。
//
// 判定ロジック:
//  1. filepath.Clean による完全一致（相対パス・絶対パス双方に対応）
//  2. changedFile が相対パスの場合、projectRoot で絶対パスに変換して再比較
//
// 旧実装にあった basename による大文字小文字を区別しないフォールバックは削除した。
// basename のみの比較では別ディレクトリにある同名ファイル（例: /tmp/other/Plans.md）
// が誤ってマッチするため、フルパスでの厳密一致のみを採用する。
func isPlansFile(changedFile, plansFile string) bool {
	// filepath.Clean で正規化して完全一致
	if filepath.Clean(changedFile) == filepath.Clean(plansFile) {
		return true
	}
	return false
}

// isPlansFileWithRoot は changedFile が相対パスの場合に projectRoot を補完して比較する。
// HandlePlansWatcher から呼び出す際に使用する。
func isPlansFileWithRoot(changedFile, plansFile, projectRoot string) bool {
	// changedFile が絶対パスの場合はそのまま比較
	if filepath.IsAbs(changedFile) {
		return isPlansFile(changedFile, plansFile)
	}
	// 相対パスの場合は projectRoot を基点に絶対パスへ変換
	absChanged := filepath.Join(projectRoot, changedFile)
	return isPlansFile(absChanged, plansFile)
}

// collectPlansState は Plans.md のマーカーを集計する。
func collectPlansState(plansFile string) (plansState, error) {
	if _, err := os.Stat(plansFile); err != nil {
		return plansState{}, fmt.Errorf("plans file not found: %w", err)
	}

	taskRows, err := plans.ParseFile(plansFile)
	if err != nil {
		return plansState{}, fmt.Errorf("parse plans file: %w", err)
	}
	counts := plans.CountTags(taskRows)

	return plansState{
		Timestamp:   time.Now().UTC().Format(time.RFC3339),
		PmPending:   counts.Pending,
		CcTodo:      counts.Todo,
		CcWip:       counts.Wip,
		CcDone:      counts.Done,
		PmConfirmed: counts.Confirmed,
	}, nil
}

// loadPrevPlansState は前回保存した状態を読み込む。存在しない場合はゼロ値を返す。
// stateFilePath は絶対パスまたは相対パスを受け付ける。
func loadPrevPlansState(stateFilePath string) plansState {
	data, err := os.ReadFile(stateFilePath)
	if err != nil {
		return plansState{}
	}
	var state plansState
	if err := json.Unmarshal(data, &state); err != nil {
		return plansState{}
	}
	return state
}

// savePlansState は現在の状態をファイルに保存する。
// stateFilePath は絶対パスまたは相対パスを受け付ける。
func savePlansState(stateFilePath string, state plansState) {
	data, err := json.MarshalIndent(state, "", "  ")
	if err != nil {
		return
	}
	os.WriteFile(stateFilePath, append(data, '\n'), 0o644) //nolint:errcheck
}

// buildSummaryMessage は通知サマリ文字列を構築する。
func buildSummaryMessage(state plansState, hasNewTasks, hasCompletedTasks bool, locale string) string {
	var sb strings.Builder

	sb.WriteString("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
	sb.WriteString(localizedHarnessMessage(locale,
		"Plans.md update detected\n",
		"Plans.md 更新検知\n"))
	sb.WriteString("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")

	if hasNewTasks {
		sb.WriteString(localizedHarnessMessage(locale,
			"New task: PM requested work\n",
			"新規タスク: PM から依頼あり\n"))
		sb.WriteString(localizedHarnessMessage(locale,
			"   -> Check the status with /sync-status, then start with /work\n",
			"   → /sync-status で状況を確認し、/work で着手してください\n"))
	}

	if hasCompletedTasks {
		sb.WriteString(localizedHarnessMessage(locale,
			"Task completed: ready to report to PM\n",
			"タスク完了: PM へ報告可能\n"))
		sb.WriteString(localizedHarnessMessage(locale,
			"   -> Report with /handoff-to-pm-claude (or /handoff-to-cursor)\n",
			"   → /handoff-to-pm-claude（または /handoff-to-cursor）で報告してください\n"))
	}

	sb.WriteString(localizedHarnessMessage(locale, "\nCurrent status:\n", "\n現在のステータス:\n"))
	sb.WriteString(localizedHarnessMessage(locale, "   pm:pending    : ", "   pm:依頼中      : ") + strconv.Itoa(state.PmPending) + localizedHarnessMessage(locale, "\n", " 件\n"))
	sb.WriteString("   cc:TODO        : " + strconv.Itoa(state.CcTodo) + localizedHarnessMessage(locale, "\n", " 件\n"))
	sb.WriteString("   cc:WIP         : " + strconv.Itoa(state.CcWip) + localizedHarnessMessage(locale, "\n", " 件\n"))
	sb.WriteString(localizedHarnessMessage(locale, "   cc:done       : ", "   cc:完了        : ") + strconv.Itoa(state.CcDone) + localizedHarnessMessage(locale, "\n", " 件\n"))
	sb.WriteString(localizedHarnessMessage(locale, "   pm:confirmed  : ", "   pm:確認済      : ") + strconv.Itoa(state.PmConfirmed) + localizedHarnessMessage(locale, "\n", " 件\n"))
	sb.WriteString("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

	return sb.String()
}

// writePMNotification は PM 通知ファイルを生成する。
func writePMNotification(cwd string, state plansState, hasNewTasks, hasCompletedTasks bool, locale string) error {
	pmPath := pmNotificationFile
	cursorPath := cursorNotificationFile
	if cwd != "" {
		pmPath = filepath.Join(cwd, pmNotificationFile)
		cursorPath = filepath.Join(cwd, cursorNotificationFile)
	}

	stateDir := filepath.Dir(pmPath)
	if err := os.MkdirAll(stateDir, 0o755); err != nil {
		return fmt.Errorf("mkdir state dir: %w", err)
	}

	ts := time.Now().Format("2006-01-02 15:04:05")
	content := []byte(buildPMNotificationContent(state, hasNewTasks, hasCompletedTasks, ts, locale))
	if err := os.WriteFile(pmPath, content, 0o644); err != nil {
		return fmt.Errorf("write pm-notification.md: %w", err)
	}

	// 互換: cursor-notification.md にもコピー
	_ = os.WriteFile(cursorPath, content, 0o644)

	return nil
}

func buildPMNotificationContent(_ plansState, hasNewTasks, hasCompletedTasks bool, ts, locale string) string {
	var sb strings.Builder
	sb.WriteString(localizedHarnessMessage(locale, "# Notification for PM\n\n", "# PM への通知\n\n"))
	sb.WriteString(localizedHarnessMessage(locale, "**Generated at**: ", "**生成日時**: ") + ts + "\n\n")
	sb.WriteString(localizedHarnessMessage(locale, "## Status changes\n\n", "## ステータス変更\n\n"))

	if hasNewTasks {
		sb.WriteString(localizedHarnessMessage(locale, "### New task\n\n", "### 新規タスク\n\n"))
		sb.WriteString(localizedHarnessMessage(locale,
			"PM requested a new task (pm:pending / compat: cursor:pending).\n\n",
			"PM から新しいタスクが依頼されました（pm:依頼中 / 互換: cursor:依頼中）。\n\n"))
	}

	if hasCompletedTasks {
		sb.WriteString(localizedHarnessMessage(locale, "### Completed task\n\n", "### 完了タスク\n\n"))
		sb.WriteString(localizedHarnessMessage(locale,
			"Impl Claude completed a task. Please review it (cc:done).\n\n",
			"Impl Claude がタスクを完了しました。レビューをお願いします（cc:完了）。\n\n"))
	}

	sb.WriteString("---\n\n")
	sb.WriteString(localizedHarnessMessage(locale,
		"**Next action**: Review in PM Claude, then re-request if needed (/handoff-to-impl-claude).\n",
		"**次のアクション**: PM Claude でレビューし、必要なら再依頼（/handoff-to-impl-claude）。\n"))
	return sb.String()
}
