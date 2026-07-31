package policy

import (
	"encoding/json"
	"reflect"
	"strings"
	"testing"

	"github.com/Chachamaru127/claude-code-harness/go/pkg/hookproto"
)

func TestEvaluateRules_ReturnsMatchedRuleIDWithoutLeakingIntoPreToolOutput(t *testing.T) {
	result := EvaluateRules(hookproto.RuleContext{
		Input: hookproto.HookInput{
			ToolName: "Bash",
			ToolInput: map[string]interface{}{
				"command": "sudo printf rule-id-output-test",
			},
		},
	})

	field, ok := reflect.TypeOf(result).FieldByName("RuleID")
	if !ok {
		t.Fatal("HookResult does not expose a RuleID field")
	}
	if field.Type.Kind() != reflect.String {
		t.Fatalf("HookResult.RuleID type = %s, want string", field.Type)
	}
	value := reflect.ValueOf(result).FieldByIndex(field.Index).String()
	if value != "R01:no-sudo" {
		t.Fatalf("RuleID = %q, want R01:no-sudo", value)
	}

	output := PreToolToOutput(result)
	data, err := json.Marshal(output)
	if err != nil {
		t.Fatalf("marshal PreToolToOutput: %v", err)
	}
	for _, forbidden := range []string{"RuleID", "rule_id", "R01:no-sudo"} {
		if strings.Contains(string(data), forbidden) {
			t.Fatalf("PreToolToOutput JSON leaked %q: %s", forbidden, data)
		}
	}
}
