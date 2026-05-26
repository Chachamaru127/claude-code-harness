package hookhandler

import (
	"bufio"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
)

// AutoCleanupHandler is a PostToolUse hook handler (automatic size check).
// It checks the size (line count) of files written by Write/Edit tools and
// emits a systemMessage warning when Plans.md / session-log.md / CLAUDE.md
// exceed the configured threshold.
//
// shell equivalent: scripts/auto-cleanup-hook.sh
type AutoCleanupHandler struct {
	// ProjectRoot is the path to the project root. If empty, cwd is used.
	ProjectRoot string

	// Thresholds (0 means use the default value).
	PlansMaxLines      int
	SessionLogMaxLines int
	ClaudeMdMaxLines   int
}

const (
	defaultPlansMaxLines      = 200
	defaultSessionLogMaxLines = 500
	defaultClaudeMdMaxLines   = 100
)

// autoCleanupInput is the stdin JSON for the PostToolUse hook.
type autoCleanupInput struct {
	ToolInput    autoCleanupToolInput    `json:"tool_input"`
	ToolResponse autoCleanupToolResponse `json:"tool_response"`
	CWD          string                  `json:"cwd"`
}

type autoCleanupToolInput struct {
	FilePath string `json:"file_path"`
}

type autoCleanupToolResponse struct {
	FilePath string `json:"filePath"`
}

// Handle reads the PostToolUse payload from stdin and checks file sizes.
func (h *AutoCleanupHandler) Handle(r io.Reader, w io.Writer) error {
	data, _ := io.ReadAll(r)

	if len(data) == 0 {
		return nil
	}

	var inp autoCleanupInput
	if err := json.Unmarshal(data, &inp); err != nil {
		return nil
	}

	filePath := inp.ToolInput.FilePath
	if filePath == "" {
		filePath = inp.ToolResponse.FilePath
	}
	if filePath == "" {
		return nil
	}

	cwd := inp.CWD
	if cwd == "" {
		if h.ProjectRoot != "" {
			cwd = h.ProjectRoot
		} else {
			cwd, _ = os.Getwd()
		}
	}

	// Normalize to a project-relative path.
	if strings.HasPrefix(filePath, cwd+"/") {
		filePath = filePath[len(cwd)+1:]
	}

	// Determine thresholds.
	plansMax := h.PlansMaxLines
	if plansMax == 0 {
		plansMax = h.envInt("PLANS_MAX_LINES", defaultPlansMaxLines)
	}
	sessionMax := h.SessionLogMaxLines
	if sessionMax == 0 {
		sessionMax = h.envInt("SESSION_LOG_MAX_LINES", defaultSessionLogMaxLines)
	}
	claudeMax := h.ClaudeMdMaxLines
	if claudeMax == 0 {
		claudeMax = h.envInt("CLAUDE_MD_MAX_LINES", defaultClaudeMdMaxLines)
	}

	// Resolve absolute path (used for file existence checks).
	absPath := filePath
	if !filepath.IsAbs(absPath) {
		absPath = filepath.Join(cwd, filePath)
	}

	feedback := h.checkFile(filePath, absPath, plansMax, sessionMax, claudeMax, cwd, resolveHarnessLocale(cwd))
	if feedback == "" {
		return nil
	}

	return writeCleanupOutput(w, feedback)
}

// checkFile identifies the file and performs a size check, returning a feedback string.
func (h *AutoCleanupHandler) checkFile(relPath, absPath string, plansMax, sessionMax, claudeMax int, cwd, locale string) string {
	lower := strings.ToLower(relPath)
	var feedback string

	switch {
	case strings.Contains(lower, "plans.md"):
		feedback = h.checkPlans(absPath, plansMax, cwd, locale)
	case strings.Contains(lower, "session-log.md"):
		feedback = h.checkSessionLog(absPath, sessionMax, locale)
	case strings.Contains(lower, "claude.md"):
		feedback = h.checkClaudeMd(absPath, claudeMax, locale)
	}

	return feedback
}

// checkPlans checks the line count of Plans.md and also detects archive sections.
func (h *AutoCleanupHandler) checkPlans(absPath string, maxLines int, cwd, locale string) string {
	lines, err := countLines(absPath)
	if err != nil {
		return ""
	}

	var feedback string
	if lines > maxLines {
		feedback = localizedHarnessMessage(locale,
			fmt.Sprintf("Warning: Plans.md has %d lines (limit: %d). Consider archiving old tasks with /maintenance.", lines, maxLines),
			fmt.Sprintf("⚠️ Plans.md has %d lines (limit: %d). Consider archiving old tasks with /maintenance.", lines, maxLines))
	}

	// Detect archive section + check SSOT flag.
	if containsArchiveSection(absPath) {
		// Use the stateDir at the repository root.
		repoRoot := cwd
		if root, err := gitRepoRoot(cwd); err == nil {
			repoRoot = root
		}
		stateDir := filepath.Join(repoRoot, ".claude", "state")
		ssotFlag := filepath.Join(stateDir, ".ssot-synced-this-session")

		if !fileExists(ssotFlag) {
			ssotWarning := localizedHarnessMessage(locale,
				"**Run /memory sync before cleaning up Plans.md** - important decisions or learnings may not be reflected in the SSOT (decisions.md/patterns.md).",
				"**Run /memory sync before cleaning up Plans.md** - important decisions or learnings may not be reflected in the SSOT (decisions.md/patterns.md).")
			if feedback != "" {
				feedback = feedback + localizedHarnessMessage(locale, " | Warning: ", " | Warning: ") + ssotWarning
			} else {
				feedback = localizedHarnessMessage(locale, "Warning: ", "Warning: ") + ssotWarning
			}
		}
	}

	return feedback
}

// checkSessionLog checks the line count of session-log.md.
func (h *AutoCleanupHandler) checkSessionLog(absPath string, maxLines int, locale string) string {
	lines, err := countLines(absPath)
	if err != nil {
		return ""
	}
	if lines > maxLines {
		return localizedHarnessMessage(locale,
			fmt.Sprintf("Warning: session-log.md has %d lines (limit: %d). Consider splitting it by month with /maintenance.", lines, maxLines),
			fmt.Sprintf("⚠️ session-log.md has %d lines (limit: %d). Consider splitting it by month with /maintenance.", lines, maxLines))
	}
	return ""
}

// checkClaudeMd checks the line count of CLAUDE.md.
func (h *AutoCleanupHandler) checkClaudeMd(absPath string, maxLines int, locale string) string {
	lines, err := countLines(absPath)
	if err != nil {
		return ""
	}
	if lines > maxLines {
		return localizedHarnessMessage(locale,
			fmt.Sprintf("Warning: CLAUDE.md has %d lines. Consider splitting rules into .claude/rules/ or moving long content to docs/ and referencing it with @docs/filename.md.", lines),
			fmt.Sprintf("⚠️ CLAUDE.md has %d lines. Consider splitting rules into .claude/rules/ or moving long content to docs/ and referencing it with @docs/filename.md.", lines))
	}
	return ""
}

// countLines counts the number of lines in a file.
func countLines(path string) (int, error) {
	f, err := os.Open(path)
	if err != nil {
		return 0, err
	}
	defer f.Close()

	count := 0
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		count++
	}
	return count, sc.Err()
}

// containsArchiveSection reports whether a file contains an archive section.
func containsArchiveSection(path string) bool {
	f, err := os.Open(path)
	if err != nil {
		return false
	}
	defer f.Close()

	sc := bufio.NewScanner(f)
	for sc.Scan() {
		line := sc.Text()
		if strings.Contains(line, "📦 Archive") ||
			strings.Contains(line, "## Archive") ||
			strings.Contains(line, "Archive") {
			return true
		}
	}
	return false
}

// envInt reads an environment variable as an integer; returns defaultVal if unset or parse fails.
func (h *AutoCleanupHandler) envInt(key string, defaultVal int) int {
	val := os.Getenv(key)
	if val == "" {
		return defaultVal
	}
	var n int
	if _, err := fmt.Sscanf(val, "%d", &n); err != nil {
		return defaultVal
	}
	return n
}

// writeCleanupOutput writes feedback as additionalContext JSON output.
// The bash equivalent outputs a plain JSON string, so we use the same format here.
func writeCleanupOutput(w io.Writer, feedback string) error {
	type hookOutput struct {
		HookEventName     string `json:"hookEventName"`
		AdditionalContext string `json:"additionalContext"`
	}
	type output struct {
		HookSpecificOutput hookOutput `json:"hookSpecificOutput"`
	}
	out := output{
		HookSpecificOutput: hookOutput{
			HookEventName:     "PostToolUse",
			AdditionalContext: feedback,
		},
	}
	data, err := json.Marshal(out)
	if err != nil {
		return fmt.Errorf("marshaling JSON: %w", err)
	}
	_, err = fmt.Fprintf(w, "%s\n", data)
	return err
}
