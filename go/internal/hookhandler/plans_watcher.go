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

// exitFailClosed is called on fail-closed paths such as lock acquisition failures.
// Per the PostToolUse hook spec, a non-zero exit code is treated as a hook error.
// This prevents Plans updates from being silently dropped ("lost update").
// Not called directly from tests (replaced via a mockable variable).
var exitFailClosed = func(msg string) {
	fmt.Fprintf(os.Stderr, "[plans-watcher] fail-closed exit: %s\n", msg)
	os.Exit(1)
}

// plansWatcherInput is the stdin JSON passed to plans-watcher.sh.
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

// plansStateFile is the path to the file that stores the previous state.
const plansStateFile = ".claude/state/plans-state.json"

// plansLockFile is the path to the flock file used for exclusive access to plans-state.json.
// Semantically equivalent to the 3-tier fallback in the shell version scripts/plans-watcher.sh.
const plansLockFile = ".claude/state/locks/plans.flock"

// plansLockDirSuffix is the name of the mkdir-based fallback lock used when flock is unavailable.
const plansLockDirSuffix = ".dir"

// plansLockMaxRetries is the maximum number of lock acquisition retries.
const plansLockMaxRetries = 3

// flockCall and sleepCall are replaceable for tests.
var flockCall = func(fd int, how int) error {
	return fileLock(fd, how)
}

var sleepCall = time.Sleep

// plansLockHandle represents either an flock or a mkdir fallback lock.
type plansLockHandle struct {
	file    *os.File
	lockDir string
	mode    string
}

// acquirePlansLock acquires an exclusive lock protecting plans-state.json.
// Normally uses flock; falls back to a mkdir-based atomic lock only when
// flock is unavailable (e.g. on shared storage).
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

// releasePlansLock releases the lock and closes the file.
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

// pmNotificationFile is the path to the PM notification file.
const pmNotificationFile = ".claude/state/pm-notification.md"

// cursorNotificationFile is the path to the cursor notification file for compatibility.
const cursorNotificationFile = ".claude/state/cursor-notification.md"

// plansState holds the aggregated marker counts for Plans.md.
type plansState struct {
	Timestamp   string `json:"timestamp"`
	PmPending   int    `json:"pm_pending"`
	CcTodo      int    `json:"cc_todo"`
	CcWip       int    `json:"cc_wip"`
	CcDone      int    `json:"cc_done"`
	PmConfirmed int    `json:"pm_confirmed"`
}

// plansFileNames is the list of candidate filenames to search for Plans.md.
var plansFileNames = []string{"Plans.md", "plans.md", "PLANS.md", "PLANS.MD"}

// HandlePlansWatcher is the Go port of plans-watcher.sh.
//
// Called on PostToolUse Write/Edit events to detect changes to Plans.md.
// Generates an aggregated summary of WIP/TODO/done markers and writes it
// to the PM notification file. Files other than Plans.md are skipped.
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

	// Get the changed file path
	changedFile := input.ToolInput.FilePath
	if changedFile == "" {
		changedFile = input.ToolResponse.FilePath
	}

	if changedFile == "" {
		return emptyPostToolOutput(out)
	}

	// Convert to relative path when CWD is available
	if input.CWD != "" {
		changedFile = makeRelativePath(
			normalizePathSeparators(changedFile),
			normalizePathSeparators(input.CWD),
		)
	}

	// Find the Plans.md file (respects plansDirectory config setting).
	// When input.CWD is present, use it as projectRoot.
	// This fixes the issue where the hook process CWD differs from input.CWD
	// and would otherwise reference the wrong Plans.md.
	projectRoot := input.CWD
	if projectRoot == "" {
		projectRoot = resolveProjectRoot()
	}
	plansFile := resolvePlansPath(projectRoot)
	if plansFile == "" {
		return emptyPostToolOutput(out)
	}

	// Skip if the changed file is not Plans.md (strict full-path comparison)
	if !isPlansFileWithRoot(changedFile, plansFile, projectRoot) {
		return emptyPostToolOutput(out)
	}

	// Settle CWD into a single variable.
	// Deriving both lock path and state file path from the same CWD ensures
	// that when hooks run concurrently in different worktrees (CWD A / CWD B),
	// "same CWD → same lock + same state" and "different CWD → separate lock + separate state",
	// giving each project its own independent exclusive control.
	cwd := input.CWD
	if cwd == "" {
		var cwdErr error
		cwd, cwdErr = os.Getwd()
		if cwdErr != nil {
			cwd = ""
		}
	}

	// Derive lock path and state file path from the same cwd
	lockPath := plansLockFile
	stateFilePath := plansStateFile
	if cwd != "" {
		lockPath = filepath.Join(cwd, plansLockFile)
		// plansStateFile is a relative-path constant; join with cwd to get an absolute path
		stateFilePath = filepath.Join(cwd, plansStateFile)
	}

	// Protect the read-modify-write on plans-state.json with flock.
	// Fail-closed to avoid losing state due to races with Workers:
	// abort if lock acquisition fails.
	// Per the PostToolUse hook spec, a non-zero exit code signals a hook error.
	// Returning emptyPostToolOutput (= empty success response) would be interpreted
	// as success by the hook framework, causing lost updates.
	// exitFailClosed returns exit code 1 to explicitly signal to the hook framework
	// that a Plans update was dropped.
	lockFile, lockErr := acquirePlansLock(lockPath)
	if lockErr != nil {
		fmt.Fprintf(os.Stderr, "[plans-watcher] lock acquisition failed (fail-closed): %v\n", lockErr)
		exitFailClosed("lock acquisition timed out (3 retries exhausted)")
		// exitFailClosed normally calls os.Exit(1), but fall back to an empty
		// response in case the mock replacement allows execution to continue in tests.
		return emptyPostToolOutput(out)
	}
	defer releasePlansLock(lockFile)

	// Aggregate the current state
	current, err := collectPlansState(plansFile)
	if err != nil {
		return emptyPostToolOutput(out)
	}

	// Load the previous state (using CWD-based absolute path)
	prev := loadPrevPlansState(stateFilePath)

	// Save the state (using CWD-based absolute path)
	stateDir := filepath.Dir(stateFilePath)
	if mkErr := os.MkdirAll(stateDir, 0o755); mkErr == nil {
		savePlansState(stateFilePath, current)
	}

	// Determine the type of change
	hasNewTasks := current.PmPending > prev.PmPending
	hasCompletedTasks := current.CcDone > prev.CcDone

	if !hasNewTasks && !hasCompletedTasks {
		return emptyPostToolOutput(out)
	}

	// Generate the PM notification file
	if err := writePMNotification(cwd, current, hasNewTasks, hasCompletedTasks); err != nil {
		fmt.Fprintf(os.Stderr, "[plans-watcher] write notification: %v\n", err)
	}

	// Output the notification summary via systemMessage
	summary := buildSummaryMessage(current, hasNewTasks, hasCompletedTasks)
	o := postToolOutput{}
	o.HookSpecificOutput.HookEventName = "PostToolUse"
	o.HookSpecificOutput.AdditionalContext = summary
	return writeJSON(out, o)
}

// findPlansFile searches the current directory for Plans.md.
func findPlansFile() string {
	for _, name := range plansFileNames {
		if _, err := os.Stat(name); err == nil {
			return name
		}
	}
	return ""
}

// isPlansFile reports whether the changed file is Plans.md.
//
// Matching logic:
//  1. Exact match after filepath.Clean (handles both relative and absolute paths)
//  2. If changedFile is relative, convert to absolute using projectRoot and compare again
//
// The case-insensitive basename fallback present in the old implementation was removed.
// Matching on basename alone could falsely match a same-named file in a different
// directory (e.g. /tmp/other/Plans.md), so only a strict full-path match is used.
func isPlansFile(changedFile, plansFile string) bool {
	// Normalize with filepath.Clean and compare for exact match
	if filepath.Clean(changedFile) == filepath.Clean(plansFile) {
		return true
	}
	return false
}

// isPlansFileWithRoot resolves changedFile against projectRoot when it is relative,
// then compares. Used when calling from HandlePlansWatcher.
func isPlansFileWithRoot(changedFile, plansFile, projectRoot string) bool {
	// If changedFile is absolute, compare directly
	if filepath.IsAbs(changedFile) {
		return isPlansFile(changedFile, plansFile)
	}
	// If relative, convert to absolute using projectRoot as the base
	absChanged := filepath.Join(projectRoot, changedFile)
	return isPlansFile(absChanged, plansFile)
}

// countMarker returns the number of occurrences of the marker string in Plans.md.
func countMarker(plansFile, marker string) int {
	data, err := os.ReadFile(plansFile)
	if err != nil {
		return 0
	}
	re := regexp.MustCompile(regexp.QuoteMeta(marker))
	return len(re.FindAllIndex(data, -1))
}

// collectPlansState aggregates the markers in Plans.md.
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

// loadPrevPlansState loads the previously saved state. Returns zero value if not found.
// stateFilePath accepts both absolute and relative paths.
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

// savePlansState saves the current state to a file.
// stateFilePath accepts both absolute and relative paths.
func savePlansState(stateFilePath string, state plansState) {
	data, err := json.MarshalIndent(state, "", "  ")
	if err != nil {
		return
	}
	os.WriteFile(stateFilePath, append(data, '\n'), 0o644) //nolint:errcheck
}

// buildSummaryMessage constructs the notification summary string.
func buildSummaryMessage(state plansState, hasNewTasks, hasCompletedTasks bool) string {
	var sb strings.Builder

	sb.WriteString("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
	sb.WriteString("Plans.md update detected\n")
	sb.WriteString("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")

	if hasNewTasks {
		sb.WriteString("New tasks: request from PM\n")
		sb.WriteString("   → Check status with /sync-status and start work with /work\n")
	}

	if hasCompletedTasks {
		sb.WriteString("Tasks completed: ready to report to PM\n")
		sb.WriteString("   → Report with /handoff-to-pm-claude (or /handoff-to-cursor)\n")
	}

	sb.WriteString("\nCurrent status:\n")
	sb.WriteString("   pm:pending      : " + strconv.Itoa(state.PmPending) + "\n")
	sb.WriteString("   cc:TODO         : " + strconv.Itoa(state.CcTodo) + "\n")
	sb.WriteString("   cc:WIP          : " + strconv.Itoa(state.CcWip) + "\n")
	sb.WriteString("   cc:done         : " + strconv.Itoa(state.CcDone) + "\n")
	sb.WriteString("   pm:confirmed    : " + strconv.Itoa(state.PmConfirmed) + "\n")
	sb.WriteString("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

	return sb.String()
}

// writePMNotification generates the PM notification file.
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
	sb.WriteString("# Notification to PM\n\n")
	sb.WriteString("**Generated at**: " + ts + "\n\n")
	sb.WriteString("## Status change\n\n")

	if hasNewTasks {
		sb.WriteString("### New tasks\n\n")
		sb.WriteString("New tasks have been requested by PM (pm:pending / compat: cursor:pending).\n\n")
	}

	if hasCompletedTasks {
		sb.WriteString("### Completed tasks\n\n")
		sb.WriteString("Impl Claude has completed tasks. Please review (cc:done).\n\n")
	}

	sb.WriteString("---\n\n")
	sb.WriteString("**Next action**: Review in PM Claude and re-request if necessary (/handoff-to-impl-claude).\n")

	content := []byte(sb.String())
	if err := os.WriteFile(pmPath, content, 0o644); err != nil {
		return fmt.Errorf("write pm-notification.md: %w", err)
	}

	// Compat: also copy to cursor-notification.md
	_ = os.WriteFile(cursorPath, content, 0o644)

	return nil
}
