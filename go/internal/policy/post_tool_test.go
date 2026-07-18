package policy

import (
	"encoding/json"
	"strings"
	"testing"

	"github.com/Chachamaru127/claude-code-harness/go/pkg/hookproto"
)

func TestPostTool_NonWriteApproved(t *testing.T) {
	input := hookproto.HookInput{
		ToolName:  "Read",
		ToolInput: map[string]interface{}{"file_path": "/test.txt"},
	}
	result := EvaluatePostTool(input)
	if result.Decision != hookproto.DecisionApprove {
		t.Errorf("expected approve for Read, got %s", result.Decision)
	}
	if result.SystemMessage != "" {
		t.Errorf("expected no systemMessage, got: %s", result.SystemMessage)
	}
}

func TestPostTool_TamperingDetected(t *testing.T) {
	input := hookproto.HookInput{
		ToolName: "Write",
		ToolInput: map[string]interface{}{
			"file_path": "src/utils.test.ts",
			"content":   "describe.skip('should work', () => {});",
		},
	}
	result := EvaluatePostTool(input)
	if result.Decision != hookproto.DecisionApprove {
		t.Errorf("expected approve (warning only), got %s", result.Decision)
	}
	if !strings.Contains(result.SystemMessage, "Test-tampering") {
		t.Errorf("expected tampering warning, got: %s", result.SystemMessage)
	}
}

func TestPostTool_SecurityRiskDetected(t *testing.T) {
	input := hookproto.HookInput{
		ToolName: "Write",
		ToolInput: map[string]interface{}{
			"file_path": "src/main.ts",
			"content":   `password = "super_secret_12345"`,
		},
	}
	result := EvaluatePostTool(input)
	if !strings.Contains(result.SystemMessage, "Security risk") {
		t.Errorf("expected security warning, got: %s", result.SystemMessage)
	}
}

func TestPostTool_CleanWrite(t *testing.T) {
	input := hookproto.HookInput{
		ToolName: "Write",
		ToolInput: map[string]interface{}{
			"file_path": "src/main.ts",
			"content":   "const x = 42;\nconsole.log(x);",
		},
	}
	result := EvaluatePostTool(input)
	if result.SystemMessage != "" {
		t.Errorf("expected no warnings for clean code, got: %s", result.SystemMessage)
	}
}

func TestPostTool_EditNewString(t *testing.T) {
	input := hookproto.HookInput{
		ToolName: "Edit",
		ToolInput: map[string]interface{}{
			"file_path":  "src/app.test.ts",
			"new_string": "it.skip('broken test', () => {});",
		},
	}
	result := EvaluatePostTool(input)
	if !strings.Contains(result.SystemMessage, "Test-tampering") {
		t.Errorf("expected tampering warning for Edit, got: %s", result.SystemMessage)
	}
}

func TestPostTool_CIConfigTampering(t *testing.T) {
	input := hookproto.HookInput{
		ToolName: "Write",
		ToolInput: map[string]interface{}{
			"file_path": ".github/workflows/ci.yml",
			"content":   "continue-on-error: true",
		},
	}
	result := EvaluatePostTool(input)
	if !strings.Contains(result.SystemMessage, "Test-tampering") {
		t.Errorf("expected CI tampering warning, got: %s", result.SystemMessage)
	}
}

func TestPostTool_CoverageShrink_InvocationRemoved(t *testing.T) {
	oldStr := "# run tests\nbash \"$PLUGIN_ROOT/tests/test-foo.sh\"\necho done\n"
	newStr := "# run tests\necho done\n"
	input := hookproto.HookInput{
		ToolName: "Edit",
		ToolInput: map[string]interface{}{
			"file_path":  "tests/validate-plugin.sh",
			"old_string": oldStr,
			"new_string": newStr,
		},
	}
	result := EvaluatePostTool(input)
	if result.Decision != hookproto.DecisionApprove {
		t.Errorf("expected approve (warn-only), got %s", result.Decision)
	}
	if !strings.Contains(result.SystemMessage, "Coverage-shrink") {
		t.Fatalf("expected coverage-shrink warning, got: %s", result.SystemMessage)
	}
	if !strings.Contains(result.SystemMessage, "invocation") {
		t.Errorf("expected invocation removal mention, got: %s", result.SystemMessage)
	}
}

func TestPostTool_CoverageShrink_OrTrueAdded(t *testing.T) {
	oldStr := "run_test \"foo\"\n"
	newStr := "run_test \"foo\" || true\n"
	input := hookproto.HookInput{
		ToolName: "Edit",
		ToolInput: map[string]interface{}{
			"file_path":  "tests/test-foo.sh",
			"old_string": oldStr,
			"new_string": newStr,
		},
	}
	result := EvaluatePostTool(input)
	if result.Decision != hookproto.DecisionApprove {
		t.Errorf("expected approve (warn-only), got %s", result.Decision)
	}
	if !strings.Contains(result.SystemMessage, "Coverage-shrink") {
		t.Fatalf("expected coverage-shrink warning, got: %s", result.SystemMessage)
	}
	if !strings.Contains(result.SystemMessage, "|| true") {
		t.Errorf("expected || true mention, got: %s", result.SystemMessage)
	}
}

func TestPostTool_CoverageShrink_SetPlusEAdded(t *testing.T) {
	oldStr := "set -e\nrun_test \"foo\"\n"
	newStr := "set +e\nrun_test \"foo\"\n"
	input := hookproto.HookInput{
		ToolName: "Edit",
		ToolInput: map[string]interface{}{
			"file_path":  "tests/test-foo.sh",
			"old_string": oldStr,
			"new_string": newStr,
		},
	}
	result := EvaluatePostTool(input)
	if result.Decision != hookproto.DecisionApprove {
		t.Errorf("expected approve (warn-only), got %s", result.Decision)
	}
	if !strings.Contains(result.SystemMessage, "Coverage-shrink") {
		t.Fatalf("expected coverage-shrink warning, got: %s", result.SystemMessage)
	}
	if !strings.Contains(result.SystemMessage, "set +e") {
		t.Errorf("expected set +e mention, got: %s", result.SystemMessage)
	}
}

func TestPostTool_CoverageShrink_AssertionCountReduced(t *testing.T) {
	oldStr := "assert_contains \"$out\" \"a\"\nassert_contains \"$out\" \"b\"\nassert_contains \"$out\" \"c\"\n"
	newStr := "assert_contains \"$out\" \"a\"\n"
	input := hookproto.HookInput{
		ToolName: "Edit",
		ToolInput: map[string]interface{}{
			"file_path":  "tests/test-foo.sh",
			"old_string": oldStr,
			"new_string": newStr,
		},
	}
	result := EvaluatePostTool(input)
	if result.Decision != hookproto.DecisionApprove {
		t.Errorf("expected approve (warn-only), got %s", result.Decision)
	}
	if !strings.Contains(result.SystemMessage, "Coverage-shrink") {
		t.Fatalf("expected coverage-shrink warning, got: %s", result.SystemMessage)
	}
	if !strings.Contains(result.SystemMessage, "assertion") {
		t.Errorf("expected assertion reduction mention, got: %s", result.SystemMessage)
	}
}

func TestPostTool_CoverageShrink_LegitimateAddition(t *testing.T) {
	oldStr := "echo setup\n"
	newStr := "echo setup\nbash \"$PLUGIN_ROOT/tests/test-bar.sh\"\nassert_contains \"$out\" \"ok\"\n"
	input := hookproto.HookInput{
		ToolName: "Edit",
		ToolInput: map[string]interface{}{
			"file_path":  "tests/validate-plugin.sh",
			"old_string": oldStr,
			"new_string": newStr,
		},
	}
	result := EvaluatePostTool(input)
	if result.Decision != hookproto.DecisionApprove {
		t.Errorf("expected approve, got %s", result.Decision)
	}
	if strings.Contains(result.SystemMessage, "Coverage-shrink") {
		t.Errorf("expected no coverage-shrink warning for legitimate addition, got: %s", result.SystemMessage)
	}
}

func TestPostTool_CoverageShrink_NonTestFileUntouched(t *testing.T) {
	oldStr := "run_test \"foo\" || true\n"
	newStr := "run_test \"foo\"\n"
	input := hookproto.HookInput{
		ToolName: "Edit",
		ToolInput: map[string]interface{}{
			"file_path":  "scripts/foo.sh",
			"old_string": oldStr,
			"new_string": newStr,
		},
	}
	result := EvaluatePostTool(input)
	if result.Decision != hookproto.DecisionApprove {
		t.Errorf("expected approve, got %s", result.Decision)
	}
	if strings.Contains(result.SystemMessage, "Coverage-shrink") {
		t.Errorf("expected no coverage-shrink warning for non-target file, got: %s", result.SystemMessage)
	}
}

func TestPostTool_CoverageShrink_WriteAdditiveOnly(t *testing.T) {
	input := hookproto.HookInput{
		ToolName: "Write",
		ToolInput: map[string]interface{}{
			"file_path": "tests/test-foo.sh",
			"content":   "#!/bin/bash\nset +e\nrun_test \"foo\"\n",
		},
	}
	result := EvaluatePostTool(input)
	if result.Decision != hookproto.DecisionApprove {
		t.Errorf("expected approve (warn-only), got %s", result.Decision)
	}
	if !strings.Contains(result.SystemMessage, "Coverage-shrink") {
		t.Fatalf("expected coverage-shrink warning for Write with set +e, got: %s", result.SystemMessage)
	}
}

func TestPostTool_CoverageShrink_PreexistingSetPlusENoWarn(t *testing.T) {
	helper := "assert_helper() {\n  set +e\n  local rc=$?\n  set -e\n}\n"
	oldStr := helper + "run_test \"foo\"\n"
	newStr := helper + "run_test \"foo\"\nrun_test \"bar\"\n"
	input := hookproto.HookInput{
		ToolName: "Edit",
		ToolInput: map[string]interface{}{
			"file_path":  "tests/test-judgment-card-v1-schema.sh",
			"old_string": oldStr,
			"new_string": newStr,
		},
	}
	result := EvaluatePostTool(input)
	if result.Decision != hookproto.DecisionApprove {
		t.Errorf("expected approve, got %s", result.Decision)
	}
	if strings.Contains(result.SystemMessage, "Coverage-shrink") {
		t.Errorf("expected no coverage-shrink warning when set +e pre-exists unchanged, got: %s", result.SystemMessage)
	}
}

func TestPostToolOutput_JSONUsesAdditionalContext(t *testing.T) {
	out := hookproto.PostToolOutput{
		HookSpecificOutput: hookproto.PostToolHookSpecific{
			HookEventName:     "PostToolUse",
			AdditionalContext: "警告: 機密ファイルの読み取りです",
		},
	}

	data, err := json.Marshal(out)
	if err != nil {
		t.Fatalf("marshal post-tool output: %v", err)
	}

	var decoded map[string]interface{}
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Fatalf("unmarshal post-tool output: %v", err)
	}

	hookOut := decoded["hookSpecificOutput"].(map[string]interface{})
	if hookOut["hookEventName"] != "PostToolUse" {
		t.Errorf("expected PostToolUse hookEventName, got %v", hookOut["hookEventName"])
	}
	if hookOut["additionalContext"] != "警告: 機密ファイルの読み取りです" {
		t.Errorf("expected additionalContext to be preserved, got %v", hookOut["additionalContext"])
	}
}
