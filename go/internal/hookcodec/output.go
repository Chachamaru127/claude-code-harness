package hookcodec

import (
	"encoding/json"
	"fmt"

	"github.com/Chachamaru127/claude-code-harness/go/pkg/hookproto"
)

// codexDenyOutput is Codex's deny envelope. It reuses the Claude-style
// hookSpecificOutput key but Codex reads only permissionDecision /
// permissionDecisionReason (it ignores Claude-only fields such as updatedInput).
type codexDenyOutput struct {
	HookSpecificOutput codexDenyInner `json:"hookSpecificOutput"`
}

type codexDenyInner struct {
	HookEventName            string `json:"hookEventName"`
	PermissionDecision       string `json:"permissionDecision"`
	PermissionDecisionReason string `json:"permissionDecisionReason"`
}

// cursorDenyOutput is Cursor's deny envelope: a flat {permission, agent_message}
// object. agent_message is the reason surfaced to the agent.
type cursorDenyOutput struct {
	Permission   string `json:"permission"`
	AgentMessage string `json:"agent_message"`
}

// DenyOutput returns the stdout JSON bytes (or nil) a given host expects for a
// deny decision. Exit code 2 is the universal blocker across all hosts; the
// JSON carries the human reason.
//
//   - claude → PreToolUse hookSpecificOutput with permissionDecision:"deny"
//     (the exact bytes the pre-91.4 Claude path emitted, via policy.PreToolToOutput).
//   - codex  → {"hookSpecificOutput":{"hookEventName":"PreToolUse",
//     "permissionDecision":"deny","permissionDecisionReason":reason}}
//   - cursor → {"permission":"deny","agent_message":reason}
//   - grok   → Claude-compatible PreToolUse permissionDecision deny (Grok
//     PreToolUse can block; envelope matches Claude JSON for shared floor)
//
// An unknown host name is an error so the caller can fail open deliberately
// rather than silently emitting the wrong shape.
func DenyOutput(host, reason string) ([]byte, error) {
	switch host {
	case HostClaude, HostGrok, "":
		// Claude default: byte-identical to the existing pre-tool deny path.
		// Grok shares this envelope (Phase 111.5 floor membership).
		out := hookproto.PreToolOutput{
			HookSpecificOutput: hookproto.PreToolHookSpecific{
				HookEventName:            "PreToolUse",
				PermissionDecision:       "deny",
				PermissionDecisionReason: reason,
			},
		}
		return json.Marshal(out)
	case HostCodex:
		out := codexDenyOutput{
			HookSpecificOutput: codexDenyInner{
				HookEventName:            "PreToolUse",
				PermissionDecision:       "deny",
				PermissionDecisionReason: reason,
			},
		}
		return json.Marshal(out)
	case HostCursor:
		out := cursorDenyOutput{
			Permission:   "deny",
			AgentMessage: reason,
		}
		return json.Marshal(out)
	default:
		return nil, fmt.Errorf("hookcodec: unknown host %q (expected claude, codex, cursor, or grok)", host)
	}
}
