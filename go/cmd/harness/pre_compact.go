package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

type preCompactInput struct {
	SessionID string `json:"session_id,omitempty"`
	CWD       string `json:"cwd,omitempty"`
	AgentType string `json:"agent_type,omitempty"`
	Role      string `json:"role,omitempty"`
}

type preCompactDecision struct {
	Decision string `json:"decision"`
	Reason   string `json:"reason,omitempty"`
}

type preCompactContinue struct {
	Continue bool   `json:"continue"`
	Message  string `json:"message,omitempty"`
}

const preCompactAutoCheckpointMessage = "chore(plans): auto-checkpoint before compaction"

func runPreCompact(_ []string) {
	exitCode, err := evaluatePreCompact(os.Stdin, os.Stdout)
	if err != nil {
		fmt.Fprintf(os.Stderr, "pre-compact error: %v\n", err)
		os.Exit(1)
	}
	os.Exit(exitCode)
}

func evaluatePreCompact(r io.Reader, w io.Writer) (int, error) {
	input, err := readPreCompactInput(r)
	if err != nil {
		return 0, nil
	}

	projectRoot := resolvePreCompactRoot(input.CWD)
	role := normalizePreCompactRole(input.Role, input.AgentType)
	sessionID := strings.TrimSpace(firstNonEmpty(input.SessionID, os.Getenv("CLAUDE_SESSION_ID")))

	if role == "reviewer" || role == "advisor" {
		return 0, nil
	}

	if shouldBlockLongRunningSession(projectRoot, sessionID) {
		return writePreCompactBlock(w, "long-running worker session is active; compact would interrupt owned work"), nil
	}

	plansPath := resolvePlansFilePath(projectRoot)
	if plansPath == "" {
		// No Plans.md anywhere — nothing to protect, allow compact.
		return 0, nil
	}
	if isPlansDirty(projectRoot, plansPath) {
		if readPrecompactAutoCommitFromHarnessConfig(projectRoot) {
			return tryAutoCommitPlansBeforeCompact(w, projectRoot, plansPath)
		}
		return writePreCompactBlock(w, "Plans.md has uncommitted edits; save or checkpoint before compacting"), nil
	}

	return 0, nil
}

// resolvePlansFilePath mirrors hookhandler.resolvePlansPath so PreCompact
// honors the same plansDirectory configuration used elsewhere. Inlined here
// to keep the cmd/harness package import-free of internal/hookhandler for
// circular-dependency reasons.
//
// Resolution order:
//  1. Read plansDirectory from .claude-code-harness.config.yaml at projectRoot
//  2. If set, search baseDir = filepath.Join(projectRoot, plansDirectory)
//  3. If not set, search baseDir = projectRoot
//  4. Try Plans.md, plans.md, PLANS.md, PLANS.MD in order
//  5. Return empty string if none exist (no-op block protection)
func resolvePlansFilePath(projectRoot string) string {
	plansDir := readPlansDirectoryFromHarnessConfig(projectRoot)
	baseDir := projectRoot
	if plansDir != "" {
		baseDir = filepath.Join(projectRoot, plansDir)
	}
	for _, name := range []string{"Plans.md", "plans.md", "PLANS.md", "PLANS.MD"} {
		full := filepath.Join(baseDir, name)
		if _, err := os.Stat(full); err == nil {
			return full
		}
	}
	return ""
}

// readPlansDirectoryFromHarnessConfig parses the plansDirectory key from
// .claude-code-harness.config.yaml without requiring a YAML dependency.
// Mirrors hookhandler.readPlansDirectoryFromConfig including the security
// rejections (absolute path, parent traversal).
func readPlansDirectoryFromHarnessConfig(projectRoot string) string {
	const configFile = ".claude-code-harness.config.yaml"
	const key = "plansDirectory:"

	f, err := os.Open(filepath.Join(projectRoot, configFile))
	if err != nil {
		return ""
	}
	defer f.Close()

	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		line := scanner.Text()
		if !strings.HasPrefix(line, key) {
			continue
		}
		value := strings.TrimSpace(line[len(key):])
		value = strings.Trim(value, `"'`)
		value = strings.TrimSpace(value)
		if value == "" || filepath.IsAbs(value) || strings.Contains(value, "..") {
			return ""
		}
		return value
	}
	return ""
}

// readPrecompactAutoCommitFromHarnessConfig parses precompactAutoCommit from
// .claude-code-harness.config.yaml. Default is true (auto-commit ON); only an
// explicit false disables it.
func readPrecompactAutoCommitFromHarnessConfig(projectRoot string) bool {
	const configFile = ".claude-code-harness.config.yaml"
	const key = "precompactAutoCommit:"

	f, err := os.Open(filepath.Join(projectRoot, configFile))
	if err != nil {
		return true
	}
	defer f.Close()

	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		line := scanner.Text()
		if !strings.HasPrefix(line, key) {
			continue
		}
		value := strings.TrimSpace(line[len(key):])
		value = strings.Trim(value, `"'`)
		value = strings.ToLower(strings.TrimSpace(value))
		return value != "false"
	}
	return true
}

func tryAutoCommitPlansBeforeCompact(w io.Writer, projectRoot, plansPath string) (int, error) {
	relPath, err := filepath.Rel(projectRoot, plansPath)
	if err != nil || relPath == "." || strings.HasPrefix(relPath, "..") {
		relPath = "Plans.md"
	}

	addCmd := exec.Command("git", "add", "--", relPath)
	addCmd.Dir = projectRoot
	if out, err := addCmd.CombinedOutput(); err != nil {
		return writePreCompactBlock(w, plansDirtyBlockReasonWithCommitErr(string(out), err)), nil
	}

	commitCmd := exec.Command("git", "commit", "-m", preCompactAutoCheckpointMessage, "--", relPath)
	commitCmd.Dir = projectRoot
	if out, err := commitCmd.CombinedOutput(); err != nil {
		resetCmd := exec.Command("git", "reset", "HEAD", "--", relPath)
		resetCmd.Dir = projectRoot
		_ = resetCmd.Run()
		return writePreCompactBlock(w, plansDirtyBlockReasonWithCommitErr(string(out), err)), nil
	}

	hashCmd := exec.Command("git", "rev-parse", "--short", "HEAD")
	hashCmd.Dir = projectRoot
	hashOut, err := hashCmd.Output()
	if err != nil {
		return writePreCompactBlock(w, plansDirtyBlockReasonWithCommitErr("", err)), nil
	}
	shortHash := strings.TrimSpace(string(hashOut))

	resp := preCompactContinue{
		Continue: true,
		Message:  fmt.Sprintf("Plans.md auto-committed (%s) before compaction", shortHash),
	}
	data, err := json.Marshal(resp)
	if err != nil {
		fmt.Fprintf(w, "{\"continue\":true}\n")
		return 0, nil
	}
	fmt.Fprintf(w, "%s\n", data)
	return 0, nil
}

func plansDirtyBlockReasonWithCommitErr(gitOutput string, commitErr error) string {
	const base = "Plans.md has uncommitted edits; save or checkpoint before compacting"
	hint := strings.TrimSpace(gitOutput)
	if hint == "" && commitErr != nil {
		hint = commitErr.Error()
	}
	if hint == "" {
		return base + " (auto-commit failed)"
	}
	return base + " (auto-commit failed: " + strings.TrimSpace(hint) + ")"
}

func readPreCompactInput(r io.Reader) (preCompactInput, error) {
	var input preCompactInput
	data, err := io.ReadAll(r)
	if err != nil {
		return input, err
	}
	if len(strings.TrimSpace(string(data))) == 0 {
		return input, nil
	}
	if err := json.Unmarshal(data, &input); err != nil {
		return preCompactInput{}, err
	}
	return input, nil
}

func resolvePreCompactRoot(cwd string) string {
	start := strings.TrimSpace(cwd)
	if start == "" {
		if wd, err := os.Getwd(); err == nil {
			start = wd
		} else {
			start = "."
		}
	}
	// CC may launch from a repo subdirectory. Walk up to git toplevel so that
	// .claude/state/locks/ and Plans.md are always discovered at repo root,
	// not at the subdirectory the user happened to start CC from.
	cmd := exec.Command("git", "-C", start, "rev-parse", "--show-toplevel")
	out, err := cmd.Output()
	if err == nil {
		if root := strings.TrimSpace(string(out)); root != "" {
			return root
		}
	}
	return start
}

func normalizePreCompactRole(values ...string) string {
	candidates := append([]string{}, values...)
	candidates = append(candidates,
		os.Getenv("HARNESS_SESSION_ROLE"),
		os.Getenv("HARNESS_ACTIVE_ROLE"),
		os.Getenv("CLAUDE_AGENT_ROLE"),
		os.Getenv("CLAUDE_AGENT_TYPE"),
	)

	for _, raw := range candidates {
		value := strings.ToLower(strings.TrimSpace(raw))
		switch {
		case strings.Contains(value, "reviewer"):
			return "reviewer"
		case strings.Contains(value, "advisor"):
			return "advisor"
		case strings.Contains(value, "worker"):
			return "worker"
		}
	}
	return ""
}

func shouldBlockLongRunningSession(projectRoot, sessionID string) bool {
	if sessionID == "" {
		return false
	}

	metaPath := filepath.Join(projectRoot, ".claude", "state", "locks", "loop-session.lock.d", "meta.json")
	data, err := os.ReadFile(metaPath)
	if err != nil {
		return false
	}

	var meta struct {
		SessionID string `json:"session_id"`
	}
	if err := json.Unmarshal(data, &meta); err != nil {
		return false
	}

	return strings.TrimSpace(meta.SessionID) == sessionID
}

func isPlansDirty(projectRoot, plansPath string) bool {
	if _, err := os.Stat(plansPath); err != nil {
		return false
	}
	if _, err := os.Stat(filepath.Join(projectRoot, ".git")); err != nil {
		return false
	}

	relPath, err := filepath.Rel(projectRoot, plansPath)
	if err != nil {
		relPath = "Plans.md"
	}

	cmd := exec.Command("git", "status", "--short", "--", relPath)
	cmd.Dir = projectRoot
	out, err := cmd.Output()
	if err != nil {
		return false
	}

	return strings.TrimSpace(string(out)) != ""
}

func writePreCompactBlock(w io.Writer, reason string) int {
	resp := preCompactDecision{
		Decision: "block",
		Reason:   reason,
	}
	data, err := json.Marshal(resp)
	if err != nil {
		fmt.Fprintf(w, "{\"decision\":\"block\"}\n")
		return 2
	}
	fmt.Fprintf(w, "%s\n", data)
	return 2
}

func firstNonEmpty(values ...string) string {
	for _, value := range values {
		trimmed := strings.TrimSpace(value)
		if trimmed != "" {
			return trimmed
		}
	}
	return ""
}
