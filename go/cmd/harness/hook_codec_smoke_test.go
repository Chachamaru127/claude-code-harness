package main

import (
	"encoding/json"
	"testing"

	"github.com/Chachamaru127/claude-code-harness/go/internal/guardrail"
	"github.com/Chachamaru127/claude-code-harness/go/internal/hookcodec"
	"github.com/Chachamaru127/claude-code-harness/go/internal/policy"
	"github.com/Chachamaru127/claude-code-harness/go/pkg/hookproto"
)

// TestHookCodecSmoke_ForcePushDeniedAcrossHosts is the Phase 91.4 DoD (d) smoke
// test: for each host (claude/codex/cursor), a `git push --force origin main`
// action expressed in that host's native stdin shape must, after the codec →
// guardrail.EvaluatePreTool → policy.FormatPreToolResult pipeline, produce a
// DENY decision, exit code 2, and a valid host-appropriate deny JSON.
//
// It drives the functions directly — no os.Exit, no subprocess — so the policy
// engine (UNCHANGED) is exercised through the new normalization layer for all
// three input shapes.
func TestHookCodecSmoke_ForcePushDeniedAcrossHosts(t *testing.T) {
	cases := []struct {
		name     string
		hostHint string
		wantHost string
		stdin    string
	}{
		{
			name:     "claude",
			hostHint: "", // Claude default: no --host, inferred from session_id+tool_input
			wantHost: hookcodec.HostClaude,
			stdin: `{
				"session_id":"sess-claude",
				"hook_event_name":"PreToolUse",
				"tool_name":"Bash",
				"tool_input":{"command":"git push --force origin main"},
				"cwd":"/repo"
			}`,
		},
		{
			name:     "codex",
			hostHint: hookcodec.HostCodex, // wrapper passes --host codex
			wantHost: hookcodec.HostCodex,
			stdin: `{
				"session_id":"sess-codex",
				"tool_name":"Bash",
				"tool_input":{"command":"git push --force origin main"},
				"tool_use_id":"call_1",
				"turn_id":"turn_1",
				"cwd":"/work"
			}`,
		},
		{
			name:     "cursor",
			hostHint: hookcodec.HostCursor, // wrapper passes --host cursor
			wantHost: hookcodec.HostCursor,
			stdin: `{
				"conversation_id":"conv-cursor",
				"hook_event_name":"preToolUse",
				"command":"git push --force origin main",
				"cwd":"/proj",
				"sandbox":false,
				"workspace_roots":["/proj"]
			}`,
		},
		{
			// Live cursor-agent shape (2026-06-12 spike): tool_name "Shell"
			// + structured tool_input, no top-level command shorthand.
			name:     "cursor-live-shell",
			hostHint: hookcodec.HostCursor,
			wantHost: hookcodec.HostCursor,
			stdin: `{
				"conversation_id":"conv-cursor-live",
				"hook_event_name":"preToolUse",
				"model":"composer-2.5",
				"tool_name":"Shell",
				"tool_input":{"command":"git push --force origin main"},
				"workspace_roots":["/proj"]
			}`,
		},
		{
			// Phase 111.5: Grok PreToolUse shares Claude-compatible envelope.
			name:     "grok",
			hostHint: hookcodec.HostGrok,
			wantHost: hookcodec.HostGrok,
			stdin: `{
				"session_id":"sess-grok",
				"hook_event_name":"PreToolUse",
				"tool_name":"Bash",
				"tool_input":{"command":"git push --force origin main"},
				"cwd":"/repo"
			}`,
		},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			// 1. Normalize the host-native stdin into the canonical input.
			in, host, err := hookcodec.Normalize([]byte(tc.stdin), tc.hostHint)
			if err != nil {
				t.Fatalf("Normalize(%s): %v", tc.name, err)
			}
			if host != tc.wantHost {
				t.Errorf("resolved host = %q, want %q", host, tc.wantHost)
			}
			if in.ToolName != "Bash" {
				t.Errorf("ToolName = %q, want Bash", in.ToolName)
			}
			if in.ToolInput["command"] != "git push --force origin main" {
				t.Errorf("command = %v, want the force-push command", in.ToolInput["command"])
			}

			// 2. The UNCHANGED policy engine adjudicates.
			result := guardrail.EvaluatePreTool(in)
			if result.Decision != hookproto.DecisionDeny {
				t.Fatalf("decision = %q, want deny (R06 force-push block)", result.Decision)
			}

			// 3. Exit code must be the universal hard-block 2.
			_, exitCode := policy.FormatPreToolResult(result)
			if exitCode != 2 {
				t.Errorf("exit code = %d, want 2", exitCode)
			}

			// 4. The host's deny output must be valid JSON.
			denyJSON, err := hookcodec.DenyOutput(host, result.Reason)
			if err != nil {
				t.Fatalf("DenyOutput(%s): %v", host, err)
			}
			var any map[string]interface{}
			if err := json.Unmarshal(denyJSON, &any); err != nil {
				t.Errorf("deny output for %s is not valid JSON: %v\n%s", host, err, denyJSON)
			}

			// 5. Per-host deny shape sanity.
			assertDenyShape(t, host, denyJSON, result.Reason)
		})
	}
}

// TestHookCodecSmoke_ClaudeDenyByteParity guards the no-flag (Claude default)
// contract: hookcodec.DenyOutput("claude", reason) must be byte-for-byte
// identical to the legacy pre-91.4 deny output, which was
// json.Marshal(policy.PreToolToOutput(deny)). This is the DoD requirement that
// `harness hook pre-tool` with no --host stays behavior-compatible with today.
func TestHookCodecSmoke_ClaudeDenyByteParity(t *testing.T) {
	reason := "git push --force is not allowed. History-destroying operations are forbidden."

	legacyOut := policy.PreToolToOutput(hookproto.HookResult{
		Decision: hookproto.DecisionDeny,
		Reason:   reason,
	})
	legacyBytes, err := json.Marshal(legacyOut)
	if err != nil {
		t.Fatalf("marshal legacy output: %v", err)
	}

	newBytes, err := hookcodec.DenyOutput(hookcodec.HostClaude, reason)
	if err != nil {
		t.Fatalf("DenyOutput(claude): %v", err)
	}

	if string(legacyBytes) != string(newBytes) {
		t.Errorf("Claude deny output drifted from legacy bytes\n legacy: %s\n new:    %s", legacyBytes, newBytes)
	}
	// Empty host must also equal the Claude default.
	emptyBytes, err := hookcodec.DenyOutput("", reason)
	if err != nil {
		t.Fatalf("DenyOutput(\"\"): %v", err)
	}
	if string(emptyBytes) != string(legacyBytes) {
		t.Errorf("empty-host deny output != legacy bytes\n empty:  %s\n legacy: %s", emptyBytes, legacyBytes)
	}
}

// assertDenyShape checks the host-specific deny envelope fields.
func assertDenyShape(t *testing.T, host string, denyJSON []byte, reason string) {
	t.Helper()
	switch host {
	case hookcodec.HostClaude, hookcodec.HostCodex, hookcodec.HostGrok:
		var got struct {
			HookSpecificOutput struct {
				HookEventName            string `json:"hookEventName"`
				PermissionDecision       string `json:"permissionDecision"`
				PermissionDecisionReason string `json:"permissionDecisionReason"`
			} `json:"hookSpecificOutput"`
		}
		if err := json.Unmarshal(denyJSON, &got); err != nil {
			t.Fatalf("%s deny shape unmarshal: %v", host, err)
		}
		if got.HookSpecificOutput.PermissionDecision != "deny" {
			t.Errorf("%s permissionDecision = %q, want deny", host, got.HookSpecificOutput.PermissionDecision)
		}
		if got.HookSpecificOutput.HookEventName != "PreToolUse" {
			t.Errorf("%s hookEventName = %q, want PreToolUse", host, got.HookSpecificOutput.HookEventName)
		}
		if got.HookSpecificOutput.PermissionDecisionReason != reason {
			t.Errorf("%s reason mismatch: %q", host, got.HookSpecificOutput.PermissionDecisionReason)
		}
	case hookcodec.HostCursor:
		var got struct {
			Permission   string `json:"permission"`
			AgentMessage string `json:"agent_message"`
		}
		if err := json.Unmarshal(denyJSON, &got); err != nil {
			t.Fatalf("cursor deny shape unmarshal: %v", err)
		}
		if got.Permission != "deny" {
			t.Errorf("cursor permission = %q, want deny", got.Permission)
		}
		if got.AgentMessage != reason {
			t.Errorf("cursor agent_message mismatch: %q", got.AgentMessage)
		}
	default:
		t.Fatalf("unexpected host %q", host)
	}
}
