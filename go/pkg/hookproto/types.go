// Package protocol defines the Claude Code hooks protocol types.
//
// These types conform to the official Claude Code plugin hooks specification:
// https://code.claude.com/docs/en/hooks
package hookproto

import "encoding/json"

// ---------------------------------------------------------------------------
// Hook Input (stdin JSON from Claude Code)
// ---------------------------------------------------------------------------

// HookInput represents the JSON payload sent to hooks via stdin.
// Fields match the official Claude Code hooks hookproto.
type HookInput struct {
	SessionID      string                 `json:"session_id,omitempty"`
	TranscriptPath string                 `json:"transcript_path,omitempty"`
	CWD            string                 `json:"cwd,omitempty"`
	PermissionMode string                 `json:"permission_mode,omitempty"`
	HookEventName  string                 `json:"hook_event_name,omitempty"`
	ToolName       string                 `json:"tool_name"`
	ToolInput      map[string]interface{} `json:"tool_input"`
	// PermissionSuggestions contains the "always allow/deny" options proposed by
	// Claude Code for PermissionRequest hooks.
	PermissionSuggestions []PermissionUpdateEntry `json:"permission_suggestions,omitempty"`

	// Harness extension fields
	PluginRoot string `json:"plugin_root,omitempty"`
}

// ---------------------------------------------------------------------------
// Hook Output — generic
// ---------------------------------------------------------------------------

// HookDecision represents an action returned by a hook.
type HookDecision string

const (
	DecisionApprove HookDecision = "approve"
	DecisionDeny    HookDecision = "deny"
	DecisionAsk     HookDecision = "ask"
	DecisionDefer   HookDecision = "defer"
)

// HookResult is the generic hook output (legacy format).
type HookResult struct {
	Decision      HookDecision `json:"decision"`
	Reason        string       `json:"reason,omitempty"`
	SystemMessage string       `json:"systemMessage,omitempty"`
}

// ---------------------------------------------------------------------------
// PreToolUse hookSpecificOutput (official protocol)
// ---------------------------------------------------------------------------

// PreToolHookSpecific is the inner hookSpecificOutput for PreToolUse events.
type PreToolHookSpecific struct {
	HookEventName            string          `json:"hookEventName"`
	PermissionDecision       string          `json:"permissionDecision"`
	PermissionDecisionReason string          `json:"permissionDecisionReason,omitempty"`
	UpdatedInput             json.RawMessage `json:"updatedInput,omitempty"`
	AdditionalContext        string          `json:"additionalContext,omitempty"`
}

// PreToolOutput wraps PreToolHookSpecific with the required hookSpecificOutput key.
type PreToolOutput struct {
	HookSpecificOutput PreToolHookSpecific `json:"hookSpecificOutput"`
}

// ---------------------------------------------------------------------------
// PostToolUse hookSpecificOutput (documented fields only)
// ---------------------------------------------------------------------------

// PostToolHookSpecific is the inner hookSpecificOutput for PostToolUse events.
type PostToolHookSpecific struct {
	HookEventName     string `json:"hookEventName"`
	AdditionalContext string `json:"additionalContext,omitempty"`
}

// PostToolOutput wraps PostToolHookSpecific with the required hookSpecificOutput key.
type PostToolOutput struct {
	HookSpecificOutput PostToolHookSpecific `json:"hookSpecificOutput"`
}

// ---------------------------------------------------------------------------
// PermissionRequest hookSpecificOutput (official protocol)
// ---------------------------------------------------------------------------

// PermissionRule identifies a permission rule entry for a specific tool.
type PermissionRule struct {
	ToolName    string `json:"toolName"`
	RuleContent string `json:"ruleContent,omitempty"`
}

// PermissionUpdateEntry represents one entry in permission_suggestions or
// decision.updatedPermissions.
type PermissionUpdateEntry struct {
	Type        string           `json:"type"`
	Rules       []PermissionRule `json:"rules,omitempty"`
	Behavior    string           `json:"behavior,omitempty"`
	Destination string           `json:"destination,omitempty"`
	Mode        string           `json:"mode,omitempty"`
	Directories []string         `json:"directories,omitempty"`
}

// PermissionDecision is the decision object returned by PermissionRequest.
type PermissionDecision struct {
	Behavior           string                  `json:"behavior"` // "allow" or "deny"
	UpdatedInput       json.RawMessage         `json:"updatedInput,omitempty"`
	UpdatedPermissions []PermissionUpdateEntry `json:"updatedPermissions,omitempty"`
	Message            string                  `json:"message,omitempty"`
	Interrupt          *bool                   `json:"interrupt,omitempty"`
}

// PermissionHookSpecific is the hookSpecificOutput for PermissionRequest events.
type PermissionHookSpecific struct {
	HookEventName string             `json:"hookEventName"`
	Decision      PermissionDecision `json:"decision"`
}

// PermissionOutput wraps PermissionHookSpecific for the full response.
type PermissionOutput struct {
	HookSpecificOutput PermissionHookSpecific `json:"hookSpecificOutput"`
}

// ---------------------------------------------------------------------------
// Guard rule context (used by the guardrail engine)
// ---------------------------------------------------------------------------

// RuleContext carries the evaluation context for guard rules.
type RuleContext struct {
	Input                     HookInput
	ProjectRoot               string
	WorkMode                  bool
	CodexMode                 bool
	BreezingRole              string // "" means not in breezing mode
	ProtectedBranchPushPolicy string // ask, deny, or allow
	ProtectedPathAskList      []ProtectedPathAskEntry
	// ProtectedPathDenyList holds project-relative path prefixes declared in
	// paths.protected of .claude-code-harness.config.json. Writes under any of
	// these are denied by the guardrail (R16).
	ProtectedPathDenyList []string
	// ProtectedPathRoot is the directory that contains the resolved
	// .claude-code-harness.config.json. paths.protected declarations are
	// relative to this root, NOT to the (possibly nested) cwd/ProjectRoot, so
	// R16 matching must canonicalize targets against it. Empty when no config
	// was found, in which case ProtectedPathDenyList is also empty.
	ProtectedPathRoot string
	// ConfigParseError is set when a .claude-code-harness.config.json file was
	// found but could not be parsed (malformed JSON, unknown keys, invalid glob
	// pattern). R16 fails closed on this: writes are denied until the config is
	// fixed, so a typo can never silently drop the declared protections.
	ConfigParseError string
	// ProtectedBranches holds branch names declared in git.protected_branches of
	// .claude-code-harness.config.json. When non-empty it augments the built-in
	// main/master set used by R11/R12.
	ProtectedBranches       []string
	// AllowRmRf mirrors destructive_commands.allow_rm_rf. When true, the R05
	// destructive-delete confirmation is suppressed (opt-in, default false). The
	// runtimefloor worktree-escape hard floor is unaffected.
	AllowRmRf               bool
	TddEnforceLevel         string // off, central, or max
	TddHookEnabled          bool
	TddBypass               bool
	TddBypassReason         string
	TddBypassReasonRequired bool
}

// ProtectedPathAskEntry is a narrow R03 break-glass policy entry loaded from
// harness.toml. Source is the config file path used for audit messages.
type ProtectedPathAskEntry struct {
	Path   string
	Reason string
	Source string
}
