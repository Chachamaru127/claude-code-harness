package guardrail

import (
	"os"
	"path/filepath"
	"strings"

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

	// Environment variable based values (explicit overrides)
	workMode := isTruthy(os.Getenv("HARNESS_WORK_MODE")) ||
		isTruthy(os.Getenv("ULTRAWORK_MODE"))
	codexMode := isTruthy(os.Getenv("HARNESS_CODEX_MODE"))
	breezingRole := os.Getenv("HARNESS_BREEZING_ROLE")
	tddRuntime := resolveTddRuntimeConfig(input, projectRoot)
	tddBypass := isTruthy(os.Getenv("HARNESS_TDD_BYPASS"))
	tddBypassReason := strings.TrimSpace(os.Getenv("HARNESS_TDD_BYPASS_REASON"))

	// Supplement work_states from SQLite (only when session ID is available)
	// Per hook fast-path constraints (SPEC.md §12), I/O errors are ignored.
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
		TddEnforceLevel:           tddRuntime.Level,
		TddHookEnabled:            tddRuntime.HookEnabled,
		TddBypass:                 tddBypass,
		TddBypassReason:           tddBypassReason,
		TddBypassReasonRequired:   tddBypass && (tddRuntime.BypassAuditRequired || tddBypassReason == ""),
	}
}

// loadWorkStateFromDB retrieves a work_state from the specified DB path.
// Returns (nil, nil) if the DB does not exist or cannot be read (errors are not propagated).
// This prevents the hook fast-path from stopping due to filesystem issues.
func loadWorkStateFromDB(dbPath, sessionID string) (*state.WorkState, error) {
	// Do not open if the DB file does not exist (prevents slow start)
	if _, err := os.Stat(dbPath); os.IsNotExist(err) {
		return nil, nil
	}

	store, err := state.NewHarnessStore(dbPath)
	if err != nil {
		return nil, nil //nolint:nilerr // best-effort: do not propagate DB errors
	}
	defer store.Close()

	ws, err := store.GetWorkState(sessionID)
	if err != nil {
		return nil, nil //nolint:nilerr // best-effort
	}

	return ws, nil
}

// EvaluatePreTool is the PreToolUse hook entry point.
// It builds the context and evaluates all guard rules.
func EvaluatePreTool(input hookproto.HookInput) hookproto.HookResult {
	ctx := BuildContext(input)
	return EvaluateRules(ctx)
}

// PreToolToOutput converts a HookResult to the official PreToolUse hookSpecificOutput.
func PreToolToOutput(result hookproto.HookResult) *hookproto.PreToolOutput {
	// Only convert deny/ask decisions to hookSpecificOutput.
	// approve with no systemMessage needs no output (exit 0 with empty stdout).
	if result.Decision == hookproto.DecisionApprove && result.SystemMessage == "" {
		return nil
	}

	inner := hookproto.PreToolHookSpecific{
		HookEventName: "PreToolUse",
	}

	switch result.Decision {
	case hookproto.DecisionDeny:
		inner.PermissionDecision = "deny"
		inner.PermissionDecisionReason = result.Reason
	case hookproto.DecisionAsk:
		inner.PermissionDecision = "ask"
		inner.PermissionDecisionReason = result.Reason
	case hookproto.DecisionApprove:
		inner.PermissionDecision = "allow"
		if result.SystemMessage != "" {
			inner.AdditionalContext = result.SystemMessage
		}
	case hookproto.DecisionDefer:
		// CC 2.1.89: DecisionDefer passes the decision to CC for human review.
		inner.PermissionDecision = "defer"
		inner.PermissionDecisionReason = result.Reason
	}

	return &hookproto.PreToolOutput{HookSpecificOutput: inner}
}

// FormatPreToolResult converts a HookResult to the appropriate output for PreToolUse.
// Returns (json bytes or nil, exit code).
//   - deny → hookSpecificOutput JSON, exit 2
//   - ask → hookSpecificOutput JSON, exit 0
//   - approve with systemMessage → hookSpecificOutput JSON, exit 0
//   - approve without message → nil, exit 0
func FormatPreToolResult(result hookproto.HookResult) (output interface{}, exitCode int) {
	// deny always blocks
	if result.Decision == hookproto.DecisionDeny {
		return PreToolToOutput(result), 2
	}

	out := PreToolToOutput(result)
	if out != nil {
		return out, 0
	}

	// Pure approve — empty output, exit 0
	return nil, 0
}

// matchesWriteEditMultiEdit checks if tool name is Write, Edit, or MultiEdit.
func matchesWriteEditMultiEdit(toolName string) bool {
	return toolName == "Write" || toolName == "Edit" || toolName == "MultiEdit"
}

// getStringField safely extracts a string field from tool_input.
func getStringField(input map[string]interface{}, key string) (string, bool) {
	v, ok := input[key]
	if !ok {
		return "", false
	}
	s, ok := v.(string)
	return s, ok && s != ""
}

// getChangedContent extracts the changed content from Write (content) or Edit (new_string).
func getChangedContent(input map[string]interface{}) string {
	if content, ok := getStringField(input, "content"); ok {
		return content
	}
	if newStr, ok := getStringField(input, "new_string"); ok {
		return newStr
	}
	return ""
}
