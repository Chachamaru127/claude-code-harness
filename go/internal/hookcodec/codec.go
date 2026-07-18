// Package hookcodec normalizes the divergent pre-tool stdin JSON shapes that
// Claude, Codex, and Cursor send into the single canonical hookproto.HookInput,
// and renders each host's expected deny output. This lets one R01-R13 policy
// engine (go/internal/policy) adjudicate every host without the kernel knowing
// which host it is serving.
//
// Phase 91.3 wired all three hosts to the SAME entrypoint
// (`bin/harness hook pre-tool`); Phase 91.4 (this package) makes that entrypoint
// accept all three input shapes and emit each host's deny format.
//
// Field-name divergence handled by Normalize (see normalization rules below):
//
//   - Claude: session_id / tool_name / tool_input / cwd  (== hookproto.HookInput)
//   - Codex:  session_id / tool_name / tool_input{command} / cwd / tool_use_id / turn_id
//   - Cursor: conversation_id / tool_name+tool_input OR top-level command /
//     file_path / workspace_roots[] / hook_event_name "preToolUse"
//
// The package depends only on the standard library and pkg/hookproto, so it
// stays composable with the pure guardrail kernel.
package hookcodec

import (
	"encoding/json"
	"fmt"

	"github.com/Chachamaru127/claude-code-harness/go/pkg/hookproto"
)

// Host identifiers returned by Normalize and accepted by DenyOutput.
const (
	HostClaude = "claude"
	HostCodex  = "codex"
	HostCursor = "cursor"
	// HostGrok uses the Claude-compatible PreToolUse deny envelope (Grok
	// documents PreToolUse hooks with permissionDecision-style blocking).
	HostGrok = "grok"
)

// rawPayload is a permissive view over a host's pre-tool stdin JSON. Every host
// field this codec cares about is declared with all known aliases so a single
// json.Unmarshal captures them regardless of which host produced the payload.
// Unknown fields are ignored (hosts add their own metadata we don't need).
type rawPayload struct {
	// session / conversation identity
	SessionID       string `json:"session_id"`
	ConversationID  string `json:"conversation_id"`
	ConversationID2 string `json:"conversationId"`

	// tool identity
	ToolName  string                 `json:"tool_name"`
	ToolName2 string                 `json:"toolName"`
	ToolInput map[string]interface{} `json:"tool_input"`

	// shell-event shorthands (Cursor beforeShellExecution / top-level command)
	Command string `json:"command"`

	// file-edit shorthands
	FilePath string `json:"file_path"`
	Path     string `json:"path"`

	// working directory
	CWD            string   `json:"cwd"`
	WorkspaceRoot  string   `json:"workspace_root"`
	WorkspaceRoots []string `json:"workspace_roots"`

	// event name (used for host inference: "preToolUse" ⇒ cursor)
	HookEventName string `json:"hook_event_name"`

	// harness extension
	PluginRoot string `json:"plugin_root"`
}

// Normalize parses a host's raw pre-tool stdin JSON into the canonical
// hookproto.HookInput, tolerating the field-name differences across
// Claude / Codex / Cursor. hostHint ("claude"|"codex"|"cursor"|"") biases
// detection; when empty the host is inferred from the payload.
//
// It returns the normalized input, the resolved host name, and an error. The
// error is non-nil only when the payload is empty/invalid JSON or carries no
// usable tool action (so callers can fail open exactly like hook.ReadInput).
func Normalize(raw []byte, hostHint string) (hookproto.HookInput, string, error) {
	if len(raw) == 0 {
		return hookproto.HookInput{}, "", fmt.Errorf("empty input")
	}
	// Reject whitespace-only payloads the same way hook.ReadInput does.
	if isBlank(raw) {
		return hookproto.HookInput{}, "", fmt.Errorf("empty input")
	}

	var p rawPayload
	if err := json.Unmarshal(raw, &p); err != nil {
		return hookproto.HookInput{}, "", fmt.Errorf("parsing JSON: %w", err)
	}

	host := inferHost(hostHint, p)

	input := hookproto.HookInput{
		SessionID:     firstNonEmpty(p.SessionID, p.ConversationID, p.ConversationID2),
		CWD:           firstNonEmpty(p.CWD, p.WorkspaceRoot, firstSlice(p.WorkspaceRoots)),
		HookEventName: p.HookEventName,
	}

	// PluginRoot keeps existing behavior: explicit plugin_root wins, else fall
	// back to the resolved cwd (matches the pre-91.4 Claude path where callers
	// derived the project root from cwd).
	input.PluginRoot = firstNonEmpty(p.PluginRoot, input.CWD)

	// ToolName: explicit field (either alias) wins; otherwise a shell-shaped
	// event (top-level command, or a Cursor preToolUse with a command) is a
	// Bash action.
	input.ToolName = firstNonEmpty(p.ToolName, p.ToolName2)
	if input.ToolName == "" && p.Command != "" {
		input.ToolName = "Bash"
	}
	// The live Cursor CLI names its shell tool "Shell" (preToolUse stdin
	// observed 2026-06-12; docs/research/cursor-adapter-candidate.md "Hook
	// runtime deny parity"). The policy kernel only knows the canonical
	// "Bash" name, so an unmapped "Shell" would slip past R06/R11. No other
	// host uses "Shell", so the mapping is unconditional.
	if input.ToolName == "Shell" {
		input.ToolName = "Bash"
	}

	// ToolInput: prefer the explicit map; otherwise synthesize one from the
	// shell/file shorthands so the policy engine (which reads tool_input
	// ["command"] / ["file_path"]) sees a uniform structure.
	input.ToolInput = resolveToolInput(p)

	if input.ToolName == "" {
		return hookproto.HookInput{}, host, fmt.Errorf("missing required field 'tool_name'")
	}

	return input, host, nil
}

// resolveToolInput builds the canonical tool_input map. An explicit tool_input
// map is used as-is, but a top-level command/file_path is still merged in when
// the map omits it (some hosts send both the structured map and the shorthand;
// the shorthand only fills gaps so an explicit tool_input value is never
// overwritten). When no structured map is present, the shorthands become the
// map. The result is never nil.
func resolveToolInput(p rawPayload) map[string]interface{} {
	out := map[string]interface{}{}
	for k, v := range p.ToolInput {
		out[k] = v
	}
	if _, ok := out["command"]; !ok && p.Command != "" {
		out["command"] = p.Command
	}
	if _, ok := out["file_path"]; !ok {
		if fp := firstNonEmpty(p.FilePath, p.Path); fp != "" {
			out["file_path"] = fp
		}
	}
	return out
}

// inferHost resolves the host name. A non-empty, recognized hostHint always
// wins (the wrapper passed --host). When the hint is empty or unrecognized, the
// payload is inspected with a deterministic, documented precedence:
//
//  1. Cursor markers — hook_event_name "preToolUse", a workspace_roots array,
//     or a top-level command (the Cursor beforeShellExecution / preToolUse
//     shorthand) — ⇒ "cursor".
//  2. A conversation_id (without Cursor markers) ⇒ "codex". Codex is the only
//     remaining host that keys identity off conversation_id rather than
//     session_id; Claude and the Codex docs both use session_id, but Cursor is
//     already excluded by step 1, so conversation_id here means Codex.
//  3. Otherwise ⇒ "claude" (session_id + tool_input, the canonical shape).
func inferHost(hint string, p rawPayload) string {
	switch hint {
	case HostClaude, HostCodex, HostCursor, HostGrok:
		return hint
	}

	if p.HookEventName == "preToolUse" || len(p.WorkspaceRoots) > 0 || p.WorkspaceRoot != "" || p.Command != "" {
		return HostCursor
	}
	if p.ConversationID != "" || p.ConversationID2 != "" {
		return HostCodex
	}
	return HostClaude
}

// firstNonEmpty returns the first non-empty string argument, or "".
func firstNonEmpty(vals ...string) string {
	for _, v := range vals {
		if v != "" {
			return v
		}
	}
	return ""
}

// firstSlice returns the first element of a string slice, or "".
func firstSlice(s []string) string {
	if len(s) > 0 {
		return s[0]
	}
	return ""
}

// isBlank reports whether raw is empty or contains only ASCII whitespace.
func isBlank(raw []byte) bool {
	for _, b := range raw {
		switch b {
		case ' ', '\t', '\n', '\r', '\v', '\f':
			continue
		default:
			return false
		}
	}
	return true
}
