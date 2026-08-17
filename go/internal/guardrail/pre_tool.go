package guardrail

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/Chachamaru127/claude-code-harness/go/internal/auditlog"
	"github.com/Chachamaru127/claude-code-harness/go/internal/policy"
	"github.com/Chachamaru127/claude-code-harness/go/internal/runtimefloor"
	"github.com/Chachamaru127/claude-code-harness/go/internal/scopeleash"
	"github.com/Chachamaru127/claude-code-harness/go/internal/state"
	"github.com/Chachamaru127/claude-code-harness/go/pkg/config"
	"github.com/Chachamaru127/claude-code-harness/go/pkg/hookproto"
)

const (
	tddEnforceLevelOff     = config.TDDEnforceLevelOff
	tddEnforceLevelCentral = config.TDDEnforceLevelCentral
	tddEnforceLevelMax     = config.TDDEnforceLevelMax
)

type tddRuntimeConfig struct {
	Level               string
	HookEnabled         bool
	BypassAuditRequired bool
}

// isTruthy checks if an env var value is truthy ("1", "true", "yes").
func isTruthy(value string) bool {
	switch strings.ToLower(strings.TrimSpace(value)) {
	case "1", "true", "yes", "on":
		return true
	default:
		return false
	}
}

func normalizeTddEnforceLevel(value string) string {
	switch strings.ToLower(strings.Trim(strings.TrimSpace(value), `"'`)) {
	case tddEnforceLevelCentral:
		return tddEnforceLevelCentral
	case tddEnforceLevelMax:
		return tddEnforceLevelMax
	default:
		return tddEnforceLevelOff
	}
}

func readTddRuntimeConfigFromHarnessTOML(path string) (tddRuntimeConfig, bool) {
	runtime := tddRuntimeConfig{Level: tddEnforceLevelOff}
	cfg, err := config.ParseFile(path)
	if err != nil {
		return runtime, false
	}
	if !cfg.TDD.Enforce.Enabled {
		return runtime, true
	}

	runtime.Level = normalizeTddEnforceLevel(cfg.TDD.Enforce.Level)
	runtime.HookEnabled = cfg.TDD.Enforce.HookEnabled
	runtime.BypassAuditRequired = cfg.TDD.Enforce.BypassAuditRequired
	return runtime, true
}

func resolveTddRuntimeConfig(input hookproto.HookInput, projectRoot string) tddRuntimeConfig {
	cfg := tddRuntimeConfig{Level: tddEnforceLevelOff}
	candidates := []string{filepath.Join(projectRoot, "harness.toml")}
	if input.PluginRoot != "" && input.PluginRoot != projectRoot {
		candidates = append(candidates, filepath.Join(input.PluginRoot, "harness.toml"))
	}

	for _, path := range candidates {
		if loaded, ok := readTddRuntimeConfigFromHarnessTOML(path); ok {
			cfg = loaded
			break
		}
	}

	envTddEnabled := os.Getenv("HARNESS_TDD_ENFORCE_ENABLED")
	if value := os.Getenv("HARNESS_TDD_ENFORCE_LEVEL"); value != "" {
		cfg.Level = normalizeTddEnforceLevel(value)
	}
	if value := os.Getenv("HARNESS_TDD_HOOK_ENABLED"); value != "" {
		cfg.HookEnabled = isTruthy(value)
	}
	if value := os.Getenv("HARNESS_TDD_BYPASS_AUDIT_REQUIRED"); value != "" {
		cfg.BypassAuditRequired = isTruthy(value)
	}
	if envTddEnabled != "" && !isTruthy(envTddEnabled) {
		cfg.Level = tddEnforceLevelOff
		cfg.HookEnabled = false
	}

	if cfg.Level == tddEnforceLevelOff {
		cfg.HookEnabled = false
	}

	return cfg
}

// ---------------------------------------------------------------------------
// Scope leash (134.5): advisory (warn, default) / enforce check on
// Write/Edit/MultiEdit against the active task's auto-inferred declared
// scope. Evaluated in evaluatePreTool after the runtime floor block AND after
// tryRegisterBreezingRole (breezing_state.go), so harness's own self-registration
// write is always decided by its own dedicated logic first. Unlike the floor
// this is a soft check by default and does not modify the live guardrail
// rule table (spec invariant 6) — see go/internal/scopeleash's package doc.
// ---------------------------------------------------------------------------

const (
	scopeLeashLevelOff     = config.ScopeLeashLevelOff
	scopeLeashLevelWarn    = config.ScopeLeashLevelWarn
	scopeLeashLevelEnforce = config.ScopeLeashLevelEnforce
)

func normalizeScopeLeashLevel(value string) string {
	switch strings.ToLower(strings.Trim(strings.TrimSpace(value), `"'`)) {
	case scopeLeashLevelOff:
		return scopeLeashLevelOff
	case scopeLeashLevelEnforce:
		return scopeLeashLevelEnforce
	default:
		return scopeLeashLevelWarn
	}
}

func readScopeLeashLevelFromHarnessTOML(path string) (string, bool) {
	cfg, err := config.ParseFile(path)
	if err != nil {
		return "", false
	}
	return normalizeScopeLeashLevel(cfg.ScopeLeash.EnforceLevel), true
}

func resolveScopeLeashLevel(input hookproto.HookInput, projectRoot string) string {
	level := scopeLeashLevelWarn
	candidates := []string{filepath.Join(projectRoot, "harness.toml")}
	if input.PluginRoot != "" && input.PluginRoot != projectRoot {
		candidates = append(candidates, filepath.Join(input.PluginRoot, "harness.toml"))
	}
	for _, path := range candidates {
		if loaded, ok := readScopeLeashLevelFromHarnessTOML(path); ok {
			level = loaded
			break
		}
	}
	if value := os.Getenv("HARNESS_SCOPE_LEASH_LEVEL"); value != "" {
		level = normalizeScopeLeashLevel(value)
	}
	return level
}

// scopeLeashContractDoc mirrors just the field of sprint-contract.json this
// check needs (go/internal/hookhandler/sprint_contract.go's sprintContractTask).
type scopeLeashContractDoc struct {
	Task struct {
		DeclaredScope []string `json:"declared_scope"`
	} `json:"task"`
}

// loadDeclaredScope reads the declared_scope baked into the task's
// sprint-contract.json at generation time (Generate() in sprint_contract.go).
// Any read/parse failure yields an empty scope (fail-open: no contract on
// disk means nothing to check against, not a block).
func loadDeclaredScope(projectRoot, taskID string) []string {
	path := filepath.Join(projectRoot, ".claude", "state", "contracts", taskID+".sprint-contract.json")
	data, err := os.ReadFile(path)
	if err != nil {
		return nil
	}
	var doc scopeLeashContractDoc
	if err := json.Unmarshal(data, &doc); err != nil {
		return nil
	}
	return doc.Task.DeclaredScope
}

// scopeLeashWarningEntry is one line of .claude/state/scope-leash.jsonl.
type scopeLeashWarningEntry struct {
	Timestamp string `json:"timestamp"`
	TaskID    string `json:"task_id"`
	File      string `json:"file"`
	Level     string `json:"level"`
}

// recordScopeLeashWarning appends a warn-level out-of-scope write to
// .claude/state/scope-leash.jsonl. Best-effort: write failures are ignored so
// the hook fast-path stays available (same contract as track_changes.go).
func recordScopeLeashWarning(projectRoot, taskID, targetPath string) {
	stateDir := filepath.Join(projectRoot, ".claude", "state")
	if err := os.MkdirAll(stateDir, 0o755); err != nil {
		return
	}
	entry := scopeLeashWarningEntry{
		Timestamp: time.Now().UTC().Format(time.RFC3339),
		TaskID:    taskID,
		File:      targetPath,
		Level:     scopeLeashLevelWarn,
	}
	data, err := json.Marshal(entry)
	if err != nil {
		return
	}
	f, err := os.OpenFile(filepath.Join(stateDir, "scope-leash.jsonl"), os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o644)
	if err != nil {
		return
	}
	defer f.Close()
	fmt.Fprintf(f, "%s\n", data)
}

// scopeLeashExemptDir is the repo-relative directory the scope leash never
// evaluates against declared scope. declared_scope is auto-inferred from
// Plans.md Title/DoD path tokens (go/internal/scopeleash.InferScopeFromPlan)
// and never contains .claude/ paths — that's the harness's own runtime state
// (active-task.json, sprint contracts, breezing role registration, ...), not
// task-declared product scope. Without this exemption, enforce_level=enforce
// would deny the harness's own internal writes the moment a task's inferred
// scope doesn't happen to mention .claude/ (code review major finding,
// 2026-08-16). No warning is recorded for an exempt write either — this is
// not "out of scope for the task", it's out of the check's domain entirely.
const scopeLeashExemptDir = ".claude"

// isScopeLeashExempt reports whether targetPath, made project-root-relative,
// falls under scopeLeashExemptDir.
func isScopeLeashExempt(targetPath, projectRoot string) bool {
	rel := targetPath
	if projectRoot != "" {
		if r, err := filepath.Rel(projectRoot, targetPath); err == nil && !strings.HasPrefix(r, "..") {
			rel = r
		}
	}
	rel = filepath.ToSlash(rel)
	rel = strings.TrimPrefix(rel, "./")
	return rel == scopeLeashExemptDir || strings.HasPrefix(rel, scopeLeashExemptDir+"/")
}

// evaluateScopeLeash returns nil when there is nothing to say (off level,
// non-write tool, no active task, empty declared scope, or in-scope write).
// A non-nil Deny short-circuits the caller like the runtime floor; a non-nil
// Approve carries the warn-level SystemMessage to merge into the final result.
func evaluateScopeLeash(input hookproto.HookInput, projectRoot string) *hookproto.HookResult {
	if input.ToolName != "Write" && input.ToolName != "Edit" && input.ToolName != "MultiEdit" {
		return nil
	}
	level := resolveScopeLeashLevel(input, projectRoot)
	if level == scopeLeashLevelOff {
		return nil
	}

	activeTask, ok := resolveActiveTaskScope(projectRoot)
	if !ok || activeTask.Task == "" {
		return nil
	}

	declaredScope := loadDeclaredScope(projectRoot, activeTask.Task)
	if len(declaredScope) == 0 {
		// 空 scope は即 skip: no declared scope means nothing to enforce, and
		// treating "no contract yet" as "everything out of scope" would flag
		// every write in a session that never generated a sprint-contract.
		return nil
	}

	targetPath, ok := input.ToolInput["file_path"].(string)
	if !ok || strings.TrimSpace(targetPath) == "" {
		return nil
	}

	if isScopeLeashExempt(targetPath, projectRoot) {
		return nil
	}

	if scopeleash.CheckWrite(declaredScope, targetPath, projectRoot) {
		return nil
	}

	reason := fmt.Sprintf(
		"SCOPE_LEASH: %s is outside task %s's declared scope %v",
		targetPath, activeTask.Task, declaredScope,
	)

	if level == scopeLeashLevelEnforce {
		return &hookproto.HookResult{
			Decision: hookproto.DecisionDeny,
			Reason:   reason,
			RuleID:   "SCOPE_LEASH",
		}
	}

	recordScopeLeashWarning(projectRoot, activeTask.Task, targetPath)
	return &hookproto.HookResult{
		Decision:      hookproto.DecisionApprove,
		SystemMessage: reason,
	}
}

// BuildContext constructs a RuleContext from a HookInput and environment variables.
// Priority:
//  1. Environment variables (explicit overrides)
//  2. SQLite state DB (session-level state: codex_mode, work_mode)
//  3. State files under .claude/state/ (shell-guard parity, restored 132.6):
//     breezing-session-roles.json (role) / breezing-active.json (codex mode)
//  4. Defaults (false / empty)
//
// The SQLite lookup is best-effort: any DB error is silently ignored so that
// the hook fast-path remains available even when the DB is unreachable.
func BuildContext(input hookproto.HookInput) hookproto.RuleContext {
	projectRoot := resolveProjectRoot(input)

	// 環境変数ベースの値（明示的なオーバーライド）
	workMode := isTruthy(os.Getenv("HARNESS_WORK_MODE")) ||
		isTruthy(os.Getenv("ULTRAWORK_MODE"))
	codexMode := isTruthy(os.Getenv("HARNESS_CODEX_MODE"))
	breezingRole := os.Getenv("HARNESS_BREEZING_ROLE")
	tddRuntime := resolveTddRuntimeConfig(input, projectRoot)
	tddBypass := isTruthy(os.Getenv("HARNESS_TDD_BYPASS"))
	tddBypassReason := strings.TrimSpace(os.Getenv("HARNESS_TDD_BYPASS_REASON"))

	// SQLite から work_states を補完する（セッション ID がある場合のみ）
	// フック高速パスの制約（SPEC.md §12）に従い、I/O エラーは無視する。
	if input.SessionID != "" && !workMode && !codexMode {
		dbPath := state.ResolveStatePath(projectRoot)
		if ws, err := loadWorkStateFromDB(dbPath, input.SessionID); err == nil && ws != nil {
			if ws.CodexMode {
				codexMode = true
			}
			if ws.WorkMode {
				workMode = true
			}
		}
	}

	// shell 版ガード (scripts/pretooluse-guard.sh) が持っていたファイルベース
	// 解決の移植 (132.6)。Go 移行時にこの 2 経路が落ち、R07 / R08 が
	// 一度も発火しない状態が続いていた (2026-08-11 実測)。
	if breezingRole == "" {
		breezingRole = resolveBreezingRoleFromFile(projectRoot, input)
	}
	if !codexMode {
		codexMode = resolveCodexModeFromBreezingActive(projectRoot)
	}

	return hookproto.RuleContext{
		Input:                     input,
		ProjectRoot:               projectRoot,
		WorkMode:                  workMode,
		CodexMode:                 codexMode,
		BreezingRole:              breezingRole,
		ProtectedBranchPushPolicy: resolveProtectedBranchPushPolicy(input, projectRoot),
		ConsumePlanPreapproval:    newPlanPreapprovalConsumer(projectRoot, input),
		ProtectedPathAskList:      resolveProtectedPathAskList(input, projectRoot),
		TddEnforceLevel:           tddRuntime.Level,
		TddHookEnabled:            tddRuntime.HookEnabled,
		TddBypass:                 tddBypass,
		TddBypassReason:           tddBypassReason,
		TddBypassReasonRequired:   tddBypass && (tddRuntime.BypassAuditRequired || tddBypassReason == ""),
	}
}

// resolveProjectRoot determines the project root for a hook invocation.
//
// The hook payload carries the tool call's cwd, which is NOT the project root
// whenever the call was made from a subdirectory. Before 133.11 the cwd was
// used verbatim, so a call from <repo>/go resolved the root to <repo>/go.
// Measured consequence (2026-08-13 run, reproduced 2026-08-14): work-mode was
// on for the session, but ResolveStatePath looked for <repo>/go/.harness/state.db,
// found nothing, left ctx.WorkMode false and R05 asked for confirmation. The
// same misresolution silently weakened every projectRoot-relative check —
// protected paths, plan preapprovals, the TDD config — because they were
// computed against a directory that holds none of those files. The stray
// go/.claude/state/ and benchmarks/**/.claude/state/ trees are artifacts of it.
//
// Explicit roots (HARNESS_PROJECT_ROOT / PROJECT_ROOT) are declarations of
// intent and are honored verbatim; only a cwd gets the upward search.
func resolveProjectRoot(input hookproto.HookInput) string {
	if cwd := strings.TrimSpace(input.CWD); cwd != "" {
		return ascendToProjectRoot(cwd)
	}
	if root := strings.TrimSpace(os.Getenv("HARNESS_PROJECT_ROOT")); root != "" {
		return root
	}
	if root := strings.TrimSpace(os.Getenv("PROJECT_ROOT")); root != "" {
		return root
	}
	cwd, err := os.Getwd()
	if err != nil {
		return ""
	}
	return ascendToProjectRoot(cwd)
}

// projectRootMarkers are the entries that identify a directory as a project
// root. `.claude` is deliberately NOT a marker: the stray `.claude/state/`
// trees this bug created would otherwise be self-confirming, pinning the root
// to whichever subdirectory a tool call once ran in. `.git` is matched as
// either a directory or a file so that linked worktrees (where `.git` is a
// file pointing into the main repo) resolve to the worktree root.
var projectRootMarkers = []string{".harness", ".git"}

// ascendToProjectRoot walks from dir toward the filesystem root and returns the
// nearest ancestor holding a project marker. It returns dir unchanged when no
// marker is found, which preserves the pre-133.11 behavior for directories that
// are not inside a project.
//
// The walk never ascends to or past the user's home directory. ctx.ProjectRoot
// is what R05 treats as "deletable without confirmation", so a stray ~/.git
// (a dotfiles repo is common) would otherwise turn the entire home directory
// into an allow surface for `rm -rf`. Stopping short only ever yields a
// narrower root than the caller's cwd would have implied, never a wider one.
func ascendToProjectRoot(dir string) string {
	abs, err := filepath.Abs(dir)
	if err != nil {
		return dir
	}
	home, _ := os.UserHomeDir()
	if home != "" {
		if absHome, err := filepath.Abs(home); err == nil {
			home = filepath.Clean(absHome)
		}
	}

	current := filepath.Clean(abs)
	for {
		// Stop before the home directory itself; see the doc comment.
		if home != "" && current == home {
			break
		}
		for _, marker := range projectRootMarkers {
			if _, err := os.Lstat(filepath.Join(current, marker)); err == nil {
				return current
			}
		}
		parent := filepath.Dir(current)
		if parent == current {
			break
		}
		current = parent
	}
	return abs
}

// loadWorkStateFromDB は指定した DB パスから work_state を取得する。
// DB が存在しない・読み取れない場合は (nil, nil) を返す（エラーを伝播させない）。
// これにより hooks の fast-path がファイルシステムの問題で止まることを防ぐ。
func loadWorkStateFromDB(dbPath, sessionID string) (*state.WorkState, error) {
	// DB ファイルが存在しない場合は開かない（スロースタートの防止）
	if _, err := os.Stat(dbPath); os.IsNotExist(err) {
		return nil, nil
	}

	store, err := state.NewHarnessStore(dbPath)
	if err != nil {
		return nil, nil //nolint:nilerr // best-effort: DB エラーを伝播させない
	}
	defer store.Close()

	ws, err := store.GetWorkState(sessionID)
	if err != nil {
		return nil, nil //nolint:nilerr // best-effort
	}

	return ws, nil
}

// EvaluatePreTool is the PreToolUse hook entry point.
// It runs the runtime action hard floor first, then evaluates guard rules.
func EvaluatePreTool(input hookproto.HookInput) hookproto.HookResult {
	result := evaluatePreTool(input)
	auditlog.Record(resolveAuditRoot(input), input, result)
	return result
}

func resolveAuditRoot(input hookproto.HookInput) string {
	if input.AuditRoot != "" {
		return input.AuditRoot
	}
	return resolveProjectRoot(input)
}

func evaluatePreTool(input hookproto.HookInput) hookproto.HookResult {
	// Plan preapprovals are intentionally absent from this runtime-floor path.
	// The five floor categories remain non-overridable except for their two
	// explicit operator-configured exceptions (secretAllow and releaseAuto).
	if input.ToolName == "Bash" {
		if command, ok := input.ToolInput["command"].(string); ok {
			worktreeRoot := input.CWD
			if worktreeRoot == "" {
				worktreeRoot = os.Getenv("HARNESS_PROJECT_ROOT")
			}
			if worktreeRoot == "" {
				worktreeRoot = os.Getenv("PROJECT_ROOT")
			}
			if decision := runtimefloor.CheckCommand(command, runtimefloor.Context{
				WorktreeRoot: worktreeRoot,
			}); decision.Stopped {
				return hookproto.HookResult{
					Decision: hookproto.DecisionDeny,
					Reason: fmt.Sprintf(
						"RUNTIME_FLOOR:%s: %s",
						decision.Category,
						decision.Reason,
					),
					RuleID: fmt.Sprintf("RUNTIME_FLOOR:%s", decision.Category),
				}
			}
		}
	}

	// Breezing role 自己登録 (shell 版 try_register_breezing_role の移植)。
	// teammate の最初の Write (.claude/state/breezing-role-*.json) を捕捉し、
	// hook payload の agent_id / session_id キーで roles ファイルへ登録する。
	// 登録キーは payload 由来のみ (書かれた内容の ID は使わない = 他セッション
	// への role 付与を防ぐ)。登録 Write 自体は approve する。
	//
	// This must run BEFORE the scope-leash check below: registration is the
	// harness's own internal bookkeeping, not subject to any task's declared
	// scope, and should be decided by its own dedicated logic regardless of
	// what evaluateScopeLeash would otherwise conclude (code review major
	// finding, 2026-08-16 — see also the .claude/ exemption in
	// isScopeLeashExempt, which is the other half of that fix).
	if result := tryRegisterBreezingRole(input); result != nil {
		return *result
	}

	// Scope leash (134.5): off/warn/enforce advisory check, see the block
	// above evaluateScopeLeash. warn does not block — its SystemMessage is
	// merged into the final result below.
	scopeLeashProjectRoot := resolveProjectRoot(input)
	var scopeWarning string
	if scopeResult := evaluateScopeLeash(input, scopeLeashProjectRoot); scopeResult != nil {
		if scopeResult.Decision == hookproto.DecisionDeny {
			return *scopeResult
		}
		scopeWarning = scopeResult.SystemMessage
	}

	ctx := BuildContext(input)
	result := policy.EvaluateRules(ctx)
	if scopeWarning != "" && result.Decision == hookproto.DecisionApprove && result.SystemMessage == "" {
		result.SystemMessage = scopeWarning
	}
	return result
}
