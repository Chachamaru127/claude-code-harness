package writinglint

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func repoRoot(t *testing.T) string {
	t.Helper()
	wd, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	dir := wd
	for {
		if _, err := os.Stat(filepath.Join(dir, SchemaRelPath)); err == nil {
			return dir
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			t.Fatalf("could not find repo root from %s", wd)
		}
		dir = parent
	}
}

func schemaPath(t *testing.T) string {
	t.Helper()
	return DefaultSchemaPath(repoRoot(t))
}

func TestSchema_WritingRuleV1_RejectsMissingRequiredFields(t *testing.T) {
	raw := map[string]interface{}{
		"pattern": "以下に示します",
		"good":    "結論から書く",
		"enabled": true,
	}
	if err := validateRuleMap(raw, schemaPath(t)); err == nil {
		t.Fatal("expected schema reject for missing id")
	}
}

func TestSchema_WritingRuleV1_AdditionalPropertiesFalse(t *testing.T) {
	data, err := os.ReadFile(schemaPath(t))
	if err != nil {
		t.Fatal(err)
	}
	var schema map[string]interface{}
	if err := json.Unmarshal(data, &schema); err != nil {
		t.Fatalf("invalid schema JSON: %v", err)
	}
	id, _ := schema["$id"].(string)
	if id == "" || !strings.Contains(id, "writing-rule.v1") {
		t.Fatalf("$id = %q, want writing-rule.v1", id)
	}
	if schema["additionalProperties"] != false {
		t.Fatalf("additionalProperties = %v, want false", schema["additionalProperties"])
	}
}

func TestSchema_WritingRuleV1_ValidRule(t *testing.T) {
	rule := Rule{
		ID:       "meta-narration",
		Pattern:  "以下に示します",
		Good:     "結論から直接書く",
		Scenes:   []string{"external"},
		Enabled:  true,
		Severity: "warning",
	}
	if err := ValidateRule(rule, schemaPath(t)); err != nil {
		t.Fatalf("valid rule rejected: %v", err)
	}
}

func TestSchema_WritingRuleV1_RejectsBadSeverity(t *testing.T) {
	raw := map[string]interface{}{
		"id":       "x",
		"pattern":  "y",
		"good":     "z",
		"enabled":  true,
		"severity": "catastrophic",
	}
	if err := validateRuleMap(raw, schemaPath(t)); err == nil {
		t.Fatal("expected schema reject for severity outside enum")
	}
}

func TestSchema_WritingRuleV1_FixtureRulesAllValid(t *testing.T) {
	rules, err := LoadDict(filepath.Join(repoRoot(t), "go/internal/writinglint/testdata/rules.jsonl"))
	if err != nil {
		t.Fatal(err)
	}
	for _, r := range rules {
		if err := ValidateRule(r, schemaPath(t)); err != nil {
			t.Fatalf("rule %q invalid against schema: %v", r.ID, err)
		}
	}
}
