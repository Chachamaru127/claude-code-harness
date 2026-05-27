package hookhandler

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

// worktreeInput is the stdin JSON payload for the WorktreeCreate hook.
//
// The Claude Code runtime sends session_id, cwd (the main repo working dir),
// hook_event_name, and a free-form tool_input map. When the runtime already
// knows the intended worktree path it surfaces it under tool_input (path /
// worktreePath). We never assume the worktree exists or does not exist —
// every field is treated as advisory and verified against the filesystem.
type worktreeInput struct {
	SessionID     string                 `json:"session_id"`
	CWD           string                 `json:"cwd"`
	HookEventName string                 `json:"hook_event_name"`
	ToolInput     map[string]interface{} `json:"tool_input"`
}

// worktreeInfo is written to .claude/state/worktree-info.json inside the worktree.
type worktreeInfo struct {
	WorkerID  string `json:"worker_id"`
	CreatedAt string `json:"created_at"`
	CWD       string `json:"cwd"`
}

// HandleWorktreeCreate implements the Claude Code WorktreeCreate hook contract.
//
// Per the official spec (https://code.claude.com/docs/en/hooks) this hook
// "replaces default git behavior": a command hook must ensure the worktree
// directory exists and then print ONLY that directory path on stdout. A
// missing path or a non-zero exit aborts worktree creation. Emitting a
// decision JSON (the legacy behavior) makes the runtime treat the JSON text
// as a path, which fails with "returned a path that is not a directory".
//
// The implementation is deliberately defensive about non-determinism: it does
// not assume the worktree was already created, nor that it must create one. It
// resolves a target path, reuses it if it is already a valid git worktree, and
// otherwise creates it. On any unrecoverable ambiguity it emits nothing, which
// aborts creation safely rather than corrupting state.
func HandleWorktreeCreate(in io.Reader, out io.Writer) error {
	data, err := io.ReadAll(in)
	if err != nil || len(data) == 0 {
		// No payload: nothing we can create. Diagnostics go to stderr —
		// stdout is reserved for the path — and we defer to the runtime's
		// default git behavior.
		fmt.Fprintln(os.Stderr, "[claude-code-harness] worktree-create: no payload; deferring to default git behavior")
		return nil
	}

	var input worktreeInput
	if jsonErr := json.Unmarshal(data, &input); jsonErr != nil {
		fmt.Fprintf(os.Stderr, "[claude-code-harness] worktree-create: invalid payload JSON: %v\n", jsonErr)
		return nil
	}

	repoCWD, reason, ok := normalizeWorktreeCreateCWD(input.CWD)
	if !ok {
		// Malformed cwd (including the legacy decision-JSON-as-cwd bug).
		// We cannot safely derive a path; emit nothing on stdout.
		fmt.Fprintf(os.Stderr, "[claude-code-harness] worktree-create: %s\n", reason)
		return nil
	}

	target := resolveWorktreePath(input, repoCWD)

	finalPath, createErr := ensureWorktree(repoCWD, target)
	if createErr != nil {
		// Creation failed. Per the contract, printing no path aborts
		// creation — the correct, non-destructive outcome. Log and exit.
		fmt.Fprintf(os.Stderr, "[claude-code-harness] worktree-create: %v\n", createErr)
		return nil
	}

	initWorktreeState(finalPath, input.SessionID)

	// Contract: print ONLY the worktree directory path on stdout.
	_, err = fmt.Fprintln(out, finalPath)
	return err
}

// resolveWorktreePath determines the intended worktree directory without
// assuming whether it already exists. Preference order:
//  1. An explicit path the runtime placed in tool_input (path / worktreePath).
//  2. A deterministic path derived from the repo root + session id.
func resolveWorktreePath(input worktreeInput, repoCWD string) string {
	for _, key := range []string{"worktreePath", "path", "worktree_path"} {
		if raw, ok := input.ToolInput[key]; ok {
			if s, ok := raw.(string); ok {
				s = strings.TrimSpace(s)
				if s != "" && !looksLikeHookDecisionJSON(s) {
					return absOrSelf(s)
				}
			}
		}
	}

	slug := sanitizeWorktreeSlug(input.SessionID)
	if slug == "" {
		slug = "worker"
	}
	return filepath.Join(repoCWD, ".harness-worktrees", slug)
}

// ensureWorktree guarantees that target is a usable worktree directory rooted
// in the repo at repoCWD, then returns the path that should be reported.
//
// It checks the actual filesystem/git state rather than trusting the payload:
//   - If target is already a git worktree, it is reused as-is.
//   - If target exists as a non-empty non-worktree dir, it is reported as-is
//     (never clobbered) to avoid destroying in-progress user state.
//   - If target does not exist (or is an empty placeholder), a fresh worktree
//     is created (origin default branch when available, else HEAD).
//   - If git reports the path is already registered, that is treated as reuse.
func ensureWorktree(repoCWD, target string) (string, error) {
	if isGitWorktree(target) {
		return target, nil
	}

	if info, statErr := os.Stat(target); statErr == nil && info.IsDir() {
		if !dirIsEmpty(target) {
			return target, nil
		}
		// Empty dir: git worktree add refuses a pre-existing path, so
		// remove the empty placeholder before adding.
		_ = os.Remove(target)
	}

	branch := worktreeBranchName(target)
	if err := gitWorktreeAdd(repoCWD, target, branch); err != nil {
		// Re-check: a concurrent run or prior registration may already
		// have produced a valid worktree.
		if isGitWorktree(target) {
			return target, nil
		}
		return "", fmt.Errorf("git worktree add %q: %w", target, err)
	}
	return target, nil
}

// gitWorktreeAdd creates a worktree at path on a new branch. It prefers the
// origin default branch as the base ref (matching the harness baseRef:"fresh"
// SSOT) and falls back to HEAD when origin is unavailable (e.g. offline).
func gitWorktreeAdd(repoCWD, path, branch string) error {
	base := originDefaultRef(repoCWD)

	args := []string{"worktree", "add", "-b", branch, path}
	if base != "" {
		args = append(args, base)
	}
	cmd := exec.Command("git", args...)
	cmd.Dir = repoCWD
	if outBytes, err := cmd.CombinedOutput(); err != nil {
		// Branch may already exist from a prior run; retry without -b but
		// name the branch explicitly so git checks out the intended
		// existing branch (not one derived from the target's basename).
		retry := exec.Command("git", "worktree", "add", path, branch)
		retry.Dir = repoCWD
		if outBytes2, err2 := retry.CombinedOutput(); err2 != nil {
			return fmt.Errorf("%s / %s: %w",
				strings.TrimSpace(string(outBytes)),
				strings.TrimSpace(string(outBytes2)), err2)
		}
	}
	return nil
}

// originDefaultRef returns origin/<default-branch> if it can be resolved,
// otherwise an empty string (caller falls back to HEAD).
func originDefaultRef(repoCWD string) string {
	cmd := exec.Command("git", "symbolic-ref", "--short", "refs/remotes/origin/HEAD")
	cmd.Dir = repoCWD
	if outBytes, err := cmd.Output(); err == nil {
		if ref := strings.TrimSpace(string(outBytes)); ref != "" {
			return ref
		}
	}
	// Fallback: probe common default branch names on origin.
	for _, name := range []string{"origin/main", "origin/master"} {
		verify := exec.Command("git", "rev-parse", "--verify", "--quiet", name)
		verify.Dir = repoCWD
		if verify.Run() == nil {
			return name
		}
	}
	return ""
}

// isGitWorktree reports whether path is the root of a checked-out git worktree.
func isGitWorktree(path string) bool {
	if path == "" {
		return false
	}
	if _, err := os.Stat(path); err != nil {
		return false
	}
	// --is-inside-work-tree is true for ANY path inside a checkout, so a repo
	// subdirectory (or a leftover dir inside the main checkout) would be
	// misreported as a reusable worktree. A worktree root requires git's
	// toplevel to equal path itself.
	cmd := exec.Command("git", "rev-parse", "--show-toplevel")
	cmd.Dir = path
	outBytes, err := cmd.Output()
	if err != nil {
		return false
	}
	return sameDir(strings.TrimSpace(string(outBytes)), path)
}

// sameDir reports whether two paths resolve to the same directory, accounting
// for relative paths and symlinks (e.g. macOS /var -> /private/var).
func sameDir(a, b string) bool {
	return resolveDir(a) == resolveDir(b)
}

func resolveDir(p string) string {
	if abs, err := filepath.Abs(p); err == nil {
		p = abs
	}
	if real, err := filepath.EvalSymlinks(p); err == nil {
		return real
	}
	return filepath.Clean(p)
}

// initWorktreeState creates .claude/state/ inside the worktree and records
// worker identity. Best-effort and idempotent — failures are non-fatal.
func initWorktreeState(worktreePath, sessionID string) {
	stateDir := worktreeStateDir(worktreePath)
	if err := os.MkdirAll(stateDir, 0o755); err != nil {
		fmt.Fprintf(os.Stderr, "[claude-code-harness] worktree-create: mkdir %s: %v\n", stateDir, err)
		return
	}

	info := worktreeInfo{
		WorkerID:  sessionID,
		CreatedAt: time.Now().UTC().Format(time.RFC3339),
		CWD:       worktreePath,
	}
	if infoData, err := json.Marshal(info); err == nil {
		_ = os.WriteFile(filepath.Join(stateDir, "worktree-info.json"), append(infoData, '\n'), 0o644)
	}
}

func worktreeBranchName(path string) string {
	slug := sanitizeWorktreeSlug(filepath.Base(path))
	if slug == "" {
		slug = "worker"
	}
	return "harness/worker/" + slug
}

func dirIsEmpty(path string) bool {
	entries, err := os.ReadDir(path)
	if err != nil {
		return false
	}
	return len(entries) == 0
}

func absOrSelf(p string) string {
	if abs, err := filepath.Abs(p); err == nil {
		return abs
	}
	return p
}

// sanitizeWorktreeSlug makes a string safe for use as a branch/dir segment.
func sanitizeWorktreeSlug(s string) string {
	r := strings.NewReplacer(
		" ", "-",
		"/", "-",
		"\\", "-",
		".", "-",
		":", "-",
	)
	return strings.Trim(r.Replace(strings.TrimSpace(s)), "-")
}

// normalizeWorktreeCreateCWD validates and trims the repo cwd from the payload.
// It returns the cleaned cwd, a human-readable reason when rejected, and an ok
// flag. The decision-JSON guard prevents the legacy bug (a decision JSON
// arriving where a cwd was expected) from ever being treated as a path.
func normalizeWorktreeCreateCWD(raw string) (string, string, bool) {
	cwd := strings.TrimSpace(raw)
	if cwd == "" {
		return "", "WorktreeCreate: no cwd", false
	}
	if looksLikeHookDecisionJSON(cwd) {
		return "", "WorktreeCreate: invalid cwd (decision JSON)", false
	}
	return cwd, "", true
}

// worktreeStateDir returns the .claude/state directory under base.
func worktreeStateDir(base string) string {
	return filepath.Join(base, ".claude", "state")
}

// looksLikeHookDecisionJSON detects a {"decision":...,"reason":...} object so
// the legacy decision-JSON-as-cwd bug can never be treated as a path.
func looksLikeHookDecisionJSON(value string) bool {
	trimmed := strings.TrimSpace(value)
	if !strings.HasPrefix(trimmed, "{") {
		return false
	}
	var payload map[string]json.RawMessage
	if err := json.Unmarshal([]byte(trimmed), &payload); err != nil {
		return false
	}
	_, hasDecision := payload["decision"]
	_, hasReason := payload["reason"]
	return hasDecision && hasReason
}
