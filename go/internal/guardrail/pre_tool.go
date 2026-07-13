package guardrail

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/Chachamaru127/claude-code-harness/go/internal/policy"
	"github.com/Chachamaru127/claude-code-harness/go/internal/runtimefloor"
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

// BuildContext constructs a RuleContext from a HookInput and environment variables.
// Priority:
//  1. Environment variables (explicit overrides)
//  2. SQLite state DB (session-level state: codex_mode, work_mode)
//  3. Defaults (false / empty)
//
// The SQLite lookup is best-effort: any DB error is silently ignored so that
// the hook fast-path remains available even when the DB is unreachable.
func BuildContext(input hookproto.HookInput) hookproto.RuleContext {
	projectRoot := input.CWD
	if projectRoot == "" {
		projectRoot = os.Getenv("HARNESS_PROJECT_ROOT")
	}
	if projectRoot == "" {
		projectRoot = os.Getenv("PROJECT_ROOT")
	}
	if projectRoot == "" {
		projectRoot, _ = os.Getwd()
	}

	// 環境変数ベースの値（明示的なオーバーライド）
	workMode := isTruthy(os.Getenv("HARNESS_WORK_MODE")) ||
		isTruthy(os.Getenv("ULTRAWORK_MODE"))
	codexMode := isTruthy(os.Getenv("HARNESS_CODEX_MODE"))
	breezingRole := os.Getenv("HARNESS_BREEZING_ROLE")
	tddRuntime := resolveTddRuntimeConfig(input, projectRoot)
	tddBypass := isTruthy(os.Getenv("HARNESS_TDD_BYPASS"))
	tddBypassReason := strings.TrimSpace(os.Getenv("HARNESS_TDD_BYPASS_REASON"))

	// Per-project .claude-code-harness.config.json declarations. Loaded once and
	// reused for both the protected-path deny list and the protected-branch set.
	projectCfg := resolveProjectConfig(input, projectRoot)
	protectedPathDenyList := resolveProtectedPathDenyList(projectCfg)
	protectedBranches := resolveProtectedBranches(projectCfg)

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

	return hookproto.RuleContext{
		Input:                     input,
		ProjectRoot:               projectRoot,
		WorkMode:                  workMode,
		CodexMode:                 codexMode,
		BreezingRole:              breezingRole,
		ProtectedBranchPushPolicy: resolveProtectedBranchPushPolicy(input, projectRoot),
		ProtectedPathAskList:      resolveProtectedPathAskList(input, projectRoot),
		ProtectedPathDenyList:     protectedPathDenyList,
		ProtectedBranches:         protectedBranches,
		TddEnforceLevel:           tddRuntime.Level,
		TddHookEnabled:            tddRuntime.HookEnabled,
		TddBypass:                 tddBypass,
		TddBypassReason:           tddBypassReason,
		TddBypassReasonRequired:   tddBypass && (tddRuntime.BypassAuditRequired || tddBypassReason == ""),
	}
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
				}
			}
		}
	}

	ctx := BuildContext(input)
	return policy.EvaluateRules(ctx)
}
