package hookhandler

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"time"
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

	// CWD があれば相対パスに変換
	if input.CWD != "" {
		changedFile = makeRelativePath(
			normalizePathSeparators(changedFile),
			normalizePathSeparators(input.CWD),
		)
	}

	// Plans.md ファイルを探す（設定ファイルの plansDirectory 対応）
	// input.CWD が存在する場合はそれを projectRoot として使用する。
	// フックプロセスの CWD が input.CWD と異なる場合に誤った Plans.md を参照する問題を修正。
	projectRoot := input.CWD
	if projectRoot == "" {
		projectRoot = resolveProjectRoot()
	}
	plansFile := resolvePlansPath(projectRoot)
	if plansFile == "" {
		return emptyPostToolOutput(out)
	}

	// 変更されたファイルが Plans.md でない場合はスキップ（完全パスで厳密比較）
	if !isPlansFileWithRoot(changedFile, plansFile, projectRoot) {
		return emptyPostToolOutput(out)
	}

	// CWD を一つの変数に決定する。
	// lock path と state file path を同じ CWD から導出することで、
	// 異なる worktree（CWD A / CWD B）で hook が同時に走っても
	// 「同じ CWD → 同じ lock + 同じ state」「異なる CWD → 別 lock + 別 state」となり
	// プロジェクトごとに独立した排他制御が機能する。
	cwd := input.CWD
	if cwd == "" {
		var cwdErr error
		cwd, cwdErr = os.Getwd()
		if cwdErr != nil {
			cwd = ""
		}
	}

	// lock path と state file path を同じ cwd から導出する
	lockPath := plansLockFile
	stateFilePath := plansStateFile
	if cwd != "" {
		lockPath = filepath.Join(cwd, plansLockFile)
		// plansStateFile は相対パス定数なので cwd と結合して絶対パス化
		stateFilePath = filepath.Join(cwd, plansStateFile)
	}

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

	// 前回の状態を読み込む（CWD ベースの絶対パスを使用）
	prev := loadPrevPlansState(stateFilePath)

	// 状態を保存（CWD ベースの絶対パスを使用）
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
	if err := writePMNotification(cwd, current, hasNewTasks, hasCompletedTasks); err != nil {
		fmt.Fprintf(os.Stderr, "[plans-watcher] write notification: %v\n", err)
	}

	// systemMessage で通知サマリを出力
	summary := buildSummaryMessage(current, hasNewTasks, hasCompletedTasks)
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

// countMarker は Plans.md 内の marker 文字列の出現回数を返す。
func countMarker(plansFile, marker string) int {
	data, err := os.ReadFile(plansFile)
	if err != nil {
		return 0
	}
	re := regexp.MustCompile(regexp.QuoteMeta(marker))
	return len(re.FindAllIndex(data, -1))
}

// collectPlansState は Plans.md のマーカーを集計する。
func collectPlansState(plansFile string) (plansState, error) {
	if _, err := os.Stat(plansFile); err != nil {
		return plansState{}, fmt.Errorf("plans file not found: %w", err)
	}

	pmPending := countMarker(plansFile, "pm:依頼中") + countMarker(plansFile, "cursor:依頼中")
	ccTodo := countMarker(plansFile, "cc:TODO")
	ccWip := countMarker(plansFile, "cc:WIP")
	ccDone := countMarker(plansFile, "cc:完了")
	pmConfirmed := countMarker(plansFile, "pm:確認済") + countMarker(plansFile, "cursor:確認済")

	return plansState{
		Timestamp:   time.Now().UTC().Format(time.RFC3339),
		PmPending:   pmPending,
		CcTodo:      ccTodo,
		CcWip:       ccWip,
		CcDone:      ccDone,
		PmConfirmed: pmConfirmed,
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
func buildSummaryMessage(state plansState, hasNewTasks, hasCompletedTasks bool) string {
	var sb strings.Builder

	sb.WriteString("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
	sb.WriteString("Plans.md 更新検知\n")
	sb.WriteString("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")

	if hasNewTasks {
		sb.WriteString("新規タスク: PM から依頼あり\n")
		sb.WriteString("   → /sync-status で状況を確認し、/work で着手してください\n")
	}

	if hasCompletedTasks {
		sb.WriteString("タスク完了: PM へ報告可能\n")
		sb.WriteString("   → /handoff-to-pm-claude（または /handoff-to-cursor）で報告してください\n")
	}

	sb.WriteString("\n現在のステータス:\n")
	sb.WriteString("   pm:依頼中      : " + strconv.Itoa(state.PmPending) + " 件\n")
	sb.WriteString("   cc:TODO        : " + strconv.Itoa(state.CcTodo) + " 件\n")
	sb.WriteString("   cc:WIP         : " + strconv.Itoa(state.CcWip) + " 件\n")
	sb.WriteString("   cc:完了        : " + strconv.Itoa(state.CcDone) + " 件\n")
	sb.WriteString("   pm:確認済      : " + strconv.Itoa(state.PmConfirmed) + " 件\n")
	sb.WriteString("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

	return sb.String()
}

// writePMNotification は PM 通知ファイルを生成する。
func writePMNotification(cwd string, state plansState, hasNewTasks, hasCompletedTasks bool) error {
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

	var sb strings.Builder
	sb.WriteString("# PM への通知\n\n")
	sb.WriteString("**生成日時**: " + ts + "\n\n")
	sb.WriteString("## ステータス変更\n\n")

	if hasNewTasks {
		sb.WriteString("### 新規タスク\n\n")
		sb.WriteString("PM から新しいタスクが依頼されました（pm:依頼中 / 互換: cursor:依頼中）。\n\n")
	}

	if hasCompletedTasks {
		sb.WriteString("### 完了タスク\n\n")
		sb.WriteString("Impl Claude がタスクを完了しました。レビューをお願いします（cc:完了）。\n\n")
	}

	sb.WriteString("---\n\n")
	sb.WriteString("**次のアクション**: PM Claude でレビューし、必要なら再依頼（/handoff-to-impl-claude）。\n")

	content := []byte(sb.String())
	if err := os.WriteFile(pmPath, content, 0o644); err != nil {
		return fmt.Errorf("write pm-notification.md: %w", err)
	}

	// 互換: cursor-notification.md にもコピー
	_ = os.WriteFile(cursorPath, content, 0o644)

	return nil
}
