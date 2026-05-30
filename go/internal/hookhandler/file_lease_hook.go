package hookhandler

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
)

// fileLeaseInput is the stdin JSON payload shared by the PreToolUse and
// PostToolUse Write|Edit hooks. Only session_id and tool_input.file_path
// are load-bearing; cwd is used to resolve the repo root when the handler
// is invoked from a worktree whose working directory differs from the
// main checkout. The full hook payload is larger but anything else is
// ignored on purpose so a future schema bump in CC does not break us.
type fileLeaseInput struct {
	SessionID string `json:"session_id"`
	CWD       string `json:"cwd"`
	ToolName  string `json:"tool_name"`
	ToolInput struct {
		FilePath string `json:"file_path"`
	} `json:"tool_input"`
}

// fileLeaseDenyOutput is the JSON shape PostToolUse emits when a peer
// session holds the lease on the file the caller just wrote. The
// hookSpecificOutput envelope matches the CC 2.1.x permission contract;
// continueOnBlock:true sits at the top level per hooks-2.1.139-plus.md §3
// and turns the deny into diagnostic feedback rather than a guard rail
// (R01-R13). The model receives the reason string and can choose to wait
// or move to a different file.
type fileLeaseDenyOutput struct {
	HookSpecificOutput struct {
		HookEventName            string `json:"hookEventName"`
		PermissionDecision       string `json:"permissionDecision"`
		PermissionDecisionReason string `json:"permissionDecisionReason"`
	} `json:"hookSpecificOutput"`
	ContinueOnBlock bool `json:"continueOnBlock"`
}

// HandlePreToolUseFileLease silently records the current session as the
// lease holder for the file about to be written. It never emits a
// permission decision: if the file is already held by a peer, the
// PostToolUse handler is responsible for surfacing the conflict so the
// model can adapt. This split keeps PreToolUse fast and lets PostToolUse
// own the human-facing feedback.
//
// All failure paths fail-open (return nil with empty output) per Phase
// 85.1.5 (b): missing session_id, missing file_path, malformed JSON, a
// cwd outside any git repo, or a path that escapes the repo are all
// treated as "lease layer unavailable, do not interfere".
func HandlePreToolUseFileLease(in io.Reader, _ io.Writer) error {
	inp, ok := readFileLeaseInput(in)
	if !ok {
		return nil
	}
	repoRoot, gitCommonDir, ok := leaseHookRepoFromCWD(inp.CWD)
	if !ok {
		return nil
	}
	relPath, ok := leaseHookRepoRelative(inp.ToolInput.FilePath, repoRoot)
	if !ok {
		return nil
	}
	cfg := LeaseConfig{
		RepoRoot:     repoRoot,
		GitCommonDir: gitCommonDir,
		SessionID:    inp.SessionID,
		LiveSessions: LoadLiveSessionsFromActiveJSON(repoRoot),
	}
	// AcquireLease's result is intentionally ignored: a successful acquire
	// makes future PostToolUse calls see self-held, a HeldByOther result
	// will be surfaced by the PostToolUse hook after the write happens.
	// Either way PreToolUse stays silent so the tool is never blocked.
	_, _ = AcquireLease(relPath, cfg)
	return nil
}

// HandlePostToolUseFileLease emits a deny+continueOnBlock decision when a
// different session already holds the lease for the file that was just
// written. Self-held and unavailable both fall back to silent allow so
// the same session writing the same file in sequence (the common case)
// never produces noise.
//
// The reason string is intentionally Japanese-only because it is part of
// the model-facing prompt that already mixes languages in this codebase;
// the structured fields (hookEventName, permissionDecision) carry the
// machine-checkable contract. The holder session id is truncated to 8
// characters so a long peer id never floods the model's context.
func HandlePostToolUseFileLease(in io.Reader, out io.Writer) error {
	inp, ok := readFileLeaseInput(in)
	if !ok {
		return nil
	}
	repoRoot, gitCommonDir, ok := leaseHookRepoFromCWD(inp.CWD)
	if !ok {
		return nil
	}
	relPath, ok := leaseHookRepoRelative(inp.ToolInput.FilePath, repoRoot)
	if !ok {
		return nil
	}
	cfg := LeaseConfig{
		RepoRoot:     repoRoot,
		GitCommonDir: gitCommonDir,
		SessionID:    inp.SessionID,
		LiveSessions: LoadLiveSessionsFromActiveJSON(repoRoot),
	}
	result := CheckLease(relPath, cfg)
	if result.Status != StatusHeldByOther || result.Holder == nil {
		// Self-held, free, or unavailable — fail-open per (b).
		return nil
	}

	holderShort := result.Holder.SessionID
	if len(holderShort) > 8 {
		holderShort = holderShort[:8]
	}
	reason := fmt.Sprintf("session %s が `%s` を編集中。完了を待つか別ファイルへ", holderShort, relPath)

	resp := fileLeaseDenyOutput{}
	resp.HookSpecificOutput.HookEventName = "PostToolUse"
	resp.HookSpecificOutput.PermissionDecision = "deny"
	resp.HookSpecificOutput.PermissionDecisionReason = reason
	resp.ContinueOnBlock = true

	enc := json.NewEncoder(out)
	enc.SetEscapeHTML(false) // keep the Japanese path readable; no HTML context
	return enc.Encode(&resp)
}

// readFileLeaseInput parses the hook stdin payload into fileLeaseInput.
// Returns (zero, false) for any unusable shape so the caller can early-
// return without emitting output.
func readFileLeaseInput(in io.Reader) (fileLeaseInput, bool) {
	data, err := io.ReadAll(in)
	if err != nil {
		return fileLeaseInput{}, false
	}
	var inp fileLeaseInput
	if err := json.Unmarshal(data, &inp); err != nil {
		return fileLeaseInput{}, false
	}
	if inp.SessionID == "" || inp.ToolInput.FilePath == "" {
		return fileLeaseInput{}, false
	}
	return inp, true
}

// leaseHookRepoFromCWD walks up from cwd to locate the repo root and the
// matching git common dir. A plain `.git` directory is the simple case;
// when cwd is inside a worktree, `.git` is a regular file whose first
// line is "gitdir: /path/to/worktree-dir" and the common dir is stored
// alongside in a "commondir" file. Returning the common dir explicitly
// lets LeaseConfig skip the `git rev-parse --git-common-dir` subprocess
// inside the hook, which keeps the PreToolUse path well under the 5s
// timeout budget even on cold disk.
func leaseHookRepoFromCWD(cwd string) (repoRoot, gitCommonDir string, ok bool) {
	if cwd == "" {
		var err error
		cwd, err = os.Getwd()
		if err != nil || cwd == "" {
			return "", "", false
		}
	}
	dir := cwd
	for {
		gp := filepath.Join(dir, ".git")
		info, err := os.Stat(gp)
		if err == nil {
			if info.IsDir() {
				return dir, gp, true
			}
			// `.git` is a file (worktree pointer). Resolve its `gitdir:`
			// line, then read the sibling `commondir` to get the shared
			// .git directory all worktrees back-reference.
			gdir, ok := readWorktreeGitDir(gp)
			if !ok {
				return "", "", false
			}
			if !filepath.IsAbs(gdir) {
				gdir = filepath.Clean(filepath.Join(dir, gdir))
			}
			if common, ok := readWorktreeCommonDir(gdir); ok {
				return dir, common, true
			}
			// commondir missing means the worktree is malformed; fall
			// back to the gitdir itself so leaseStore still has
			// somewhere to anchor (rare, dev-only edge case).
			return dir, gdir, true
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			return "", "", false
		}
		dir = parent
	}
}

// readWorktreeGitDir parses the "gitdir: <path>" line in a worktree's
// .git pointer file. Returns ("", false) on any I/O or shape error.
func readWorktreeGitDir(gitFilePath string) (string, bool) {
	b, err := os.ReadFile(gitFilePath)
	if err != nil {
		return "", false
	}
	line := strings.TrimSpace(string(b))
	if !strings.HasPrefix(line, "gitdir:") {
		return "", false
	}
	return strings.TrimSpace(strings.TrimPrefix(line, "gitdir:")), true
}

// readWorktreeCommonDir reads the "commondir" sibling file inside a
// worktree's .git directory. The value may be relative; the caller is
// responsible for joining against the gitdir when needed. Returns ("",
// false) when the commondir file is absent — that signals the directory
// is itself the common dir, not a worktree.
func readWorktreeCommonDir(gitDir string) (string, bool) {
	b, err := os.ReadFile(filepath.Join(gitDir, "commondir"))
	if err != nil {
		return "", false
	}
	common := strings.TrimSpace(string(b))
	if common == "" {
		return "", false
	}
	if !filepath.IsAbs(common) {
		common = filepath.Clean(filepath.Join(gitDir, common))
	}
	return common, true
}

// leaseHookRepoRelative converts the tool's file_path (which may be
// absolute or relative to cwd) into a clean repo-relative path. A path
// that escapes the repo via `..` is refused so a hostile or merely
// confused tool input cannot trigger a lease lookup for an off-repo
// file. Defense-in-depth: leaseKey already hashes the path so the
// on-disk key is always safe, but refusing here keeps the lease store
// scoped to the repo it was provisioned for.
func leaseHookRepoRelative(filePath, repoRoot string) (string, bool) {
	if filePath == "" || repoRoot == "" {
		return "", false
	}
	abs := filePath
	if !filepath.IsAbs(abs) {
		abs = filepath.Join(repoRoot, abs)
	}
	cleaned := filepath.Clean(abs)
	repoCleaned := filepath.Clean(repoRoot)
	rel, err := filepath.Rel(repoCleaned, cleaned)
	if err != nil {
		return "", false
	}
	// strings.HasPrefix(rel, "..") catches both ".." and "../foo".
	// filepath.IsAbs catches the edge case where Rel returned an
	// absolute path because the two trees share no common ancestor.
	if strings.HasPrefix(rel, "..") || filepath.IsAbs(rel) {
		return "", false
	}
	return rel, true
}
