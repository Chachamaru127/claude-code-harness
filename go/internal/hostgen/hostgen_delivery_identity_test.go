package hostgen

import (
	"strings"
	"testing"
)

// TestGenerateDeliveryHooksJSON_NoPlaceholderIdentity requires generated delivery
// hook commands to carry no {{TEAM}}/{{AGENT}} template literals and to use the
// runtime identity resolution form (--from-env) so one artifact works per checkout.
func TestGenerateDeliveryHooksJSON_NoPlaceholderIdentity(t *testing.T) {
	hosts := loadDeliveryHosts(t)
	for _, name := range []string{"claude", "codex", "cursor"} {
		out, ok, err := GenerateDeliveryHooksJSON(hosts[name])
		if err != nil {
			t.Fatalf("GenerateDeliveryHooksJSON(%s): %v", name, err)
		}
		if !ok {
			t.Fatalf("%s: expected ok=true", name)
		}
		s := string(out)
		if strings.Contains(s, "{{") || strings.Contains(s, "}}") {
			t.Errorf("%s: delivery hooks must not contain template placeholders:\n%s", name, s)
		}
		if !strings.Contains(s, "inbox check --from-env") {
			t.Errorf("%s: inbox check command must use --from-env identity resolution, got:\n%s", name, s)
		}
		if name == "claude" && !strings.Contains(s, "inbox monitor --from-env") {
			t.Errorf("claude: inbox monitor must use --from-env, got:\n%s", s)
		}
	}
}
