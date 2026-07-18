package policy

import (
	"strings"

	"github.com/Chachamaru127/claude-code-harness/go/pkg/hookproto"
)

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
	if pairs := getContentPairs("MultiEdit", input); len(pairs) > 0 {
		var b strings.Builder
		for i, p := range pairs {
			if i > 0 {
				b.WriteByte('\n')
			}
			b.WriteString(p.new)
		}
		return b.String()
	}
	return ""
}

// contentPair holds old/new fragments for delta-based PostToolUse checks.
type contentPair struct {
	old string
	new string
}

// getOldContent extracts prior content from Edit (old_string) or MultiEdit edits.
// Write has no old content in the payload (file already overwritten at PostToolUse time).
func getOldContent(toolName string, input map[string]interface{}) string {
	pairs := getContentPairs(toolName, input)
	if len(pairs) == 0 {
		return ""
	}
	var b strings.Builder
	for i, p := range pairs {
		if i > 0 {
			b.WriteByte('\n')
		}
		b.WriteString(p.old)
	}
	return b.String()
}

// getContentPairs returns per-edit old/new pairs for Edit and MultiEdit, or a single
// new-only pair for Write. MultiEdit pairs each edit's old_string with its new_string.
func getContentPairs(toolName string, input map[string]interface{}) []contentPair {
	switch toolName {
	case "Write":
		if content, ok := getStringField(input, "content"); ok {
			return []contentPair{{new: content}}
		}
	case "Edit":
		oldStr, _ := getStringField(input, "old_string")
		newStr, _ := getStringField(input, "new_string")
		if oldStr != "" || newStr != "" {
			return []contentPair{{old: oldStr, new: newStr}}
		}
	case "MultiEdit":
		editsRaw, ok := input["edits"]
		if !ok {
			return nil
		}
		edits, ok := editsRaw.([]interface{})
		if !ok {
			return nil
		}
		var pairs []contentPair
		for _, e := range edits {
			editMap, ok := e.(map[string]interface{})
			if !ok {
				continue
			}
			oldStr, _ := getStringField(editMap, "old_string")
			newStr, _ := getStringField(editMap, "new_string")
			pairs = append(pairs, contentPair{old: oldStr, new: newStr})
		}
		return pairs
	}
	return nil
}
