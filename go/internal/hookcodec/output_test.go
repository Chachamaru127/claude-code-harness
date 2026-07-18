package hookcodec

import (
	"encoding/json"
	"testing"
)

const denyReason = "git push --force is not allowed. History-destroying operations are forbidden."

func TestDenyOutput_Claude(t *testing.T) {
	b, err := DenyOutput(HostClaude, denyReason)
	if err != nil {
		t.Fatalf("DenyOutput: %v", err)
	}
	var got struct {
		HookSpecificOutput struct {
			HookEventName            string `json:"hookEventName"`
			PermissionDecision       string `json:"permissionDecision"`
			PermissionDecisionReason string `json:"permissionDecisionReason"`
		} `json:"hookSpecificOutput"`
	}
	if err := json.Unmarshal(b, &got); err != nil {
		t.Fatalf("output is not valid JSON: %v\n%s", err, b)
	}
	if got.HookSpecificOutput.HookEventName != "PreToolUse" {
		t.Errorf("hookEventName = %q, want PreToolUse", got.HookSpecificOutput.HookEventName)
	}
	if got.HookSpecificOutput.PermissionDecision != "deny" {
		t.Errorf("permissionDecision = %q, want deny", got.HookSpecificOutput.PermissionDecision)
	}
	if got.HookSpecificOutput.PermissionDecisionReason != denyReason {
		t.Errorf("permissionDecisionReason = %q, want the deny reason", got.HookSpecificOutput.PermissionDecisionReason)
	}
}

func TestDenyOutput_EmptyHostIsClaudeDefault(t *testing.T) {
	withEmpty, err := DenyOutput("", denyReason)
	if err != nil {
		t.Fatalf("DenyOutput(\"\"): %v", err)
	}
	withClaude, err := DenyOutput(HostClaude, denyReason)
	if err != nil {
		t.Fatalf("DenyOutput(claude): %v", err)
	}
	if string(withEmpty) != string(withClaude) {
		t.Errorf("empty host must equal claude default\n empty:  %s\n claude: %s", withEmpty, withClaude)
	}
}

func TestDenyOutput_Codex(t *testing.T) {
	b, err := DenyOutput(HostCodex, denyReason)
	if err != nil {
		t.Fatalf("DenyOutput: %v", err)
	}
	var got struct {
		HookSpecificOutput struct {
			HookEventName            string `json:"hookEventName"`
			PermissionDecision       string `json:"permissionDecision"`
			PermissionDecisionReason string `json:"permissionDecisionReason"`
		} `json:"hookSpecificOutput"`
	}
	if err := json.Unmarshal(b, &got); err != nil {
		t.Fatalf("output is not valid JSON: %v\n%s", err, b)
	}
	if got.HookSpecificOutput.HookEventName != "PreToolUse" {
		t.Errorf("hookEventName = %q, want PreToolUse", got.HookSpecificOutput.HookEventName)
	}
	if got.HookSpecificOutput.PermissionDecision != "deny" {
		t.Errorf("permissionDecision = %q, want deny", got.HookSpecificOutput.PermissionDecision)
	}
	if got.HookSpecificOutput.PermissionDecisionReason != denyReason {
		t.Errorf("permissionDecisionReason = %q, want the deny reason", got.HookSpecificOutput.PermissionDecisionReason)
	}
}

func TestDenyOutput_Cursor(t *testing.T) {
	b, err := DenyOutput(HostCursor, denyReason)
	if err != nil {
		t.Fatalf("DenyOutput: %v", err)
	}
	var got struct {
		Permission   string `json:"permission"`
		AgentMessage string `json:"agent_message"`
	}
	if err := json.Unmarshal(b, &got); err != nil {
		t.Fatalf("output is not valid JSON: %v\n%s", err, b)
	}
	if got.Permission != "deny" {
		t.Errorf("permission = %q, want deny", got.Permission)
	}
	if got.AgentMessage != denyReason {
		t.Errorf("agent_message = %q, want the deny reason", got.AgentMessage)
	}
}

func TestDenyOutput_UnknownHost(t *testing.T) {
	if _, err := DenyOutput("bogus", denyReason); err == nil {
		t.Fatal("expected error for unknown host")
	}
}

// TestDenyOutput_AllHostsValidJSON is a quick guard that every supported host's
// deny output round-trips through encoding/json.
func TestDenyOutput_AllHostsValidJSON(t *testing.T) {
	for _, host := range []string{HostClaude, HostCodex, HostCursor, HostGrok, ""} {
		b, err := DenyOutput(host, denyReason)
		if err != nil {
			t.Fatalf("DenyOutput(%q): %v", host, err)
		}
		var any map[string]interface{}
		if err := json.Unmarshal(b, &any); err != nil {
			t.Errorf("DenyOutput(%q) is not valid JSON: %v\n%s", host, err, b)
		}
	}
}
