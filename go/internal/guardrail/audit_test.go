package guardrail

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/Chachamaru127/claude-code-harness/go/pkg/hookproto"
)

const guardrailAuditRelativePath = ".claude/state/audit/guardrail-fires.jsonl"

func TestEvaluatePreTool_AuditsFloorRuleAndWarnDecisions(t *testing.T) {
	t.Setenv("HARNESS_RUNTIME_FLOOR_EGRESS", "")
	t.Setenv("HARNESS_RUNTIME_FLOOR_SECRET_ALLOW", "")
	t.Setenv("HARNESS_WORK_MODE", "")
	t.Setenv("ULTRAWORK_MODE", "")
	t.Setenv("HARNESS_CODEX_MODE", "")
	t.Setenv("HARNESS_BREEZING_ROLE", "")

	projectRoot := t.TempDir()
	// Task 126.3 approves OS temporary roots, so keep the R04 fixture under the package directory.
	outsideRoot := newNonTemporaryAuditFixture(t)
	floorCommand := "gh release create v9.9.9-audit-floor-known"
	askPath := filepath.Join(outsideRoot, "audit-rule-ask-known.txt")
	denyCommand := "sudo printf audit-rule-deny-known"
	warnPath := filepath.Join(projectRoot, "audit-warn-known.env")

	var floorInput hookproto.HookInput
	floorJSON, err := json.Marshal(map[string]interface{}{
		"cwd":       projectRoot,
		"host":      "codex",
		"tool_name": "Bash",
		"tool_input": map[string]interface{}{
			"command": floorCommand,
		},
	})
	if err != nil {
		t.Fatalf("marshal floor input: %v", err)
	}
	if err := json.Unmarshal(floorJSON, &floorInput); err != nil {
		t.Fatalf("unmarshal floor input: %v", err)
	}

	tests := []struct {
		name              string
		input             hookproto.HookInput
		wantDecision      hookproto.HookDecision
		wantRuleID        string
		wantCategory      string
		wantAuditDecision string
		wantSubject       string
		wantHost          string
	}{
		{
			name:              "floor deny",
			input:             floorInput,
			wantDecision:      hookproto.DecisionDeny,
			wantRuleID:        "RUNTIME_FLOOR:prod-deploy",
			wantCategory:      "prod-deploy",
			wantAuditDecision: "deny",
			wantSubject:       floorCommand,
			wantHost:          "codex",
		},
		{
			name: "rule ask",
			input: hookproto.HookInput{
				CWD:      projectRoot,
				ToolName: "Write",
				ToolInput: map[string]interface{}{
					"file_path": askPath,
				},
			},
			wantDecision:      hookproto.DecisionAsk,
			wantRuleID:        "R04:confirm-write-outside-project",
			wantAuditDecision: "ask",
			wantSubject:       askPath,
		},
		{
			name: "rule deny",
			input: hookproto.HookInput{
				CWD:      projectRoot,
				ToolName: "Bash",
				ToolInput: map[string]interface{}{
					"command": denyCommand,
				},
			},
			wantDecision:      hookproto.DecisionDeny,
			wantRuleID:        "R01:no-sudo",
			wantAuditDecision: "deny",
			wantSubject:       denyCommand,
		},
		{
			name: "warn",
			input: hookproto.HookInput{
				CWD:      projectRoot,
				ToolName: "Read",
				ToolInput: map[string]interface{}{
					"file_path": warnPath,
				},
			},
			wantDecision:      hookproto.DecisionApprove,
			wantRuleID:        "R09:warn-secret-file-read",
			wantAuditDecision: "warn",
			wantSubject:       warnPath,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := EvaluatePreTool(tt.input)
			if result.Decision != tt.wantDecision {
				t.Fatalf("decision = %q, want %q (reason=%q)", result.Decision, tt.wantDecision, result.Reason)
			}
			if got := hookResultRuleID(t, result); got != tt.wantRuleID {
				t.Fatalf("rule ID = %q, want %q", got, tt.wantRuleID)
			}
		})
	}

	entries, raw := readGuardrailAuditEntries(t, projectRoot)
	if len(entries) != len(tests) {
		t.Fatalf("audit entries = %d, want %d\n%s", len(entries), len(tests), raw)
	}

	for i, tt := range tests {
		entry := entries[i]
		assertExactAuditFields(t, entry, tt.wantHost != "", tt.wantCategory != "", true)
		if got := entry["schema_version"]; got != "guardrail-fire.v1" {
			t.Errorf("entry %d schema_version = %#v", i, got)
		}
		if got := entry["tool"]; got != tt.input.ToolName {
			t.Errorf("entry %d tool = %#v, want %q", i, got, tt.input.ToolName)
		}
		if got := entry["rule_id"]; got != tt.wantRuleID {
			t.Errorf("entry %d rule_id = %#v, want %q", i, got, tt.wantRuleID)
		}
		if got := entry["decision"]; got != tt.wantAuditDecision {
			t.Errorf("entry %d decision = %#v, want %q", i, got, tt.wantAuditDecision)
		}
		if got := entry["category"]; got != nil && got != tt.wantCategory {
			t.Errorf("entry %d category = %#v, want %q", i, got, tt.wantCategory)
		}
		if got := entry["host"]; got != nil && got != tt.wantHost {
			t.Errorf("entry %d host = %#v, want %q", i, got, tt.wantHost)
		}
		if _, err := time.Parse(time.RFC3339, entry["ts"].(string)); err != nil {
			t.Errorf("entry %d ts is not RFC3339: %v", i, err)
		}
		if got := entry["command_sha256"]; got != sha256Hex(tt.wantSubject) {
			t.Errorf("entry %d command_sha256 = %#v, want hash of subject", i, got)
		}
		if got := int(entry["command_len"].(float64)); got != len([]byte(tt.wantSubject)) {
			t.Errorf("entry %d command_len = %d, want %d", i, got, len([]byte(tt.wantSubject)))
		}
	}

	for _, secret := range []string{floorCommand, askPath, denyCommand, warnPath} {
		if strings.Contains(raw, secret) {
			t.Fatalf("audit log contains raw command or file path %q:\n%s", secret, raw)
		}
	}
}

func TestEvaluatePreTool_PureApproveDoesNotCreateAuditLog(t *testing.T) {
	projectRoot := t.TempDir()
	result := EvaluatePreTool(hookproto.HookInput{
		CWD:      projectRoot,
		ToolName: "Read",
		ToolInput: map[string]interface{}{
			"file_path": filepath.Join(projectRoot, "README.md"),
		},
	})
	if result.Decision != hookproto.DecisionApprove || result.SystemMessage != "" {
		t.Fatalf("expected pure approve, got %#v", result)
	}

	if _, err := os.Stat(filepath.Join(projectRoot, guardrailAuditRelativePath)); !os.IsNotExist(err) {
		t.Fatalf("pure approve created audit log: err=%v", err)
	}
}

func TestEvaluatePreTool_SensitiveFloorCategoriesOmitCommandDerivedFields(t *testing.T) {
	t.Setenv("HARNESS_RUNTIME_FLOOR_SECRET_ALLOW", "")
	tests := []struct {
		category string
		command  string
	}{
		{
			category: "secret-read",
			command:  "cat ~/.aws/credentials",
		},
		{category: "money-billing", command: "stripe charges list"},
	}

	for _, tt := range tests {
		t.Run(tt.category, func(t *testing.T) {
			projectRoot := t.TempDir()
			result := EvaluatePreTool(hookproto.HookInput{
				CWD:      projectRoot,
				ToolName: "Bash",
				ToolInput: map[string]interface{}{
					"command": tt.command,
				},
			})
			if result.Decision != hookproto.DecisionDeny {
				t.Fatalf("expected %s deny, got %#v", tt.category, result)
			}

			entries, raw := readGuardrailAuditEntries(t, projectRoot)
			if len(entries) != 1 {
				t.Fatalf("audit entries = %d, want 1\n%s", len(entries), raw)
			}
			entry := entries[0]
			assertExactAuditFields(t, entry, false, true, false)
			if entry["rule_id"] != "RUNTIME_FLOOR:"+tt.category {
				t.Fatalf("rule_id = %#v", entry["rule_id"])
			}
			if entry["category"] != tt.category {
				t.Fatalf("category = %#v", entry["category"])
			}
			if _, ok := entry["command_sha256"]; ok {
				t.Fatalf("%s entry contains command_sha256: %s", tt.category, raw)
			}
			if _, ok := entry["command_len"]; ok {
				t.Fatalf("%s entry contains command_len: %s", tt.category, raw)
			}
			if strings.Contains(raw, tt.command) {
				t.Fatalf("%s entry contains raw command: %s", tt.category, raw)
			}
		})
	}
}

func TestEvaluatePreTool_ConcurrentAuditWritesRemainValidJSON(t *testing.T) {
	projectRoot := t.TempDir()
	start := make(chan struct{})
	inputs := []hookproto.HookInput{
		{
			CWD:      projectRoot,
			ToolName: "Bash",
			ToolInput: map[string]interface{}{
				"command": "sudo printf concurrent-audit-one",
			},
		},
		{
			CWD:      projectRoot,
			ToolName: "Bash",
			ToolInput: map[string]interface{}{
				"command": "sudo printf concurrent-audit-two",
			},
		},
	}

	var wg sync.WaitGroup
	for _, input := range inputs {
		input := input
		wg.Add(1)
		go func() {
			defer wg.Done()
			<-start
			result := EvaluatePreTool(input)
			if result.Decision != hookproto.DecisionDeny {
				t.Errorf("decision = %q, want deny", result.Decision)
			}
		}()
	}
	close(start)
	wg.Wait()

	entries, raw := readGuardrailAuditEntries(t, projectRoot)
	if len(entries) != len(inputs) {
		t.Fatalf("audit entries = %d, want %d\n%s", len(entries), len(inputs), raw)
	}
	for i, entry := range entries {
		if entry["schema_version"] != "guardrail-fire.v1" {
			t.Errorf("entry %d did not parse as a complete audit record: %#v", i, entry)
		}
	}
}

func TestEvaluatePreTool_AuditFailureIsFailOpen(t *testing.T) {
	parent := t.TempDir()
	unusableRoot := filepath.Join(parent, "not-a-directory")
	if err := os.WriteFile(unusableRoot, []byte("file blocks mkdir"), 0o600); err != nil {
		t.Fatalf("create non-directory project root: %v", err)
	}

	result := EvaluatePreTool(hookproto.HookInput{
		CWD:      unusableRoot,
		ToolName: "Bash",
		ToolInput: map[string]interface{}{
			"command": "sudo printf audit-fail-open",
		},
	})
	if result.Decision != hookproto.DecisionDeny {
		t.Fatalf("audit write failure changed decision: %#v", result)
	}
	if got := hookResultRuleID(t, result); got != "R01:no-sudo" {
		t.Fatalf("audit write failure changed rule ID: %q", got)
	}
}

func TestEvaluatePreTool_AuditRootDoesNotChangeRuleEvaluationRoot(t *testing.T) {
	evaluationRoot := t.TempDir()
	// Task 126.3 approves OS temporary roots, so keep the R04 fixture under the package directory.
	auditRoot := newNonTemporaryAuditFixture(t)
	t.Setenv("HARNESS_PROJECT_ROOT", evaluationRoot)
	t.Setenv("PROJECT_ROOT", "")

	result := EvaluatePreTool(hookproto.HookInput{
		AuditRoot: auditRoot,
		ToolName:  "Write",
		ToolInput: map[string]interface{}{
			"file_path": filepath.Join(auditRoot, "outside-evaluation-root.txt"),
		},
	})
	if result.Decision != hookproto.DecisionAsk {
		t.Fatalf("audit root changed rule evaluation decision: %#v", result)
	}
	if got := hookResultRuleID(t, result); got != "R04:confirm-write-outside-project" {
		t.Fatalf("rule ID = %q, want R04", got)
	}

	entries, _ := readGuardrailAuditEntries(t, auditRoot)
	if len(entries) != 1 {
		t.Fatalf("audit entries = %d, want 1", len(entries))
	}
	if _, err := os.Stat(filepath.Join(evaluationRoot, guardrailAuditRelativePath)); !os.IsNotExist(err) {
		t.Fatalf("audit record used evaluation root instead of explicit audit root: err=%v", err)
	}
}

func newNonTemporaryAuditFixture(t *testing.T) string {
	t.Helper()
	workingDir, err := os.Getwd()
	if err != nil {
		t.Fatalf("get package working directory: %v", err)
	}
	fixtureRoot, err := os.MkdirTemp(workingDir, ".guardrail-audit-")
	if err != nil {
		t.Fatalf("create non-temporary audit fixture: %v", err)
	}
	t.Cleanup(func() {
		if err := os.RemoveAll(fixtureRoot); err != nil {
			t.Errorf("remove audit fixture %s: %v", fixtureRoot, err)
		}
	})
	return fixtureRoot
}

func hookResultRuleID(t *testing.T, result hookproto.HookResult) string {
	t.Helper()
	field := reflect.ValueOf(result).FieldByName("RuleID")
	if !field.IsValid() {
		t.Fatal("HookResult does not expose a RuleID field")
	}
	if field.Kind() != reflect.String {
		t.Fatalf("HookResult.RuleID kind = %s, want string", field.Kind())
	}
	return field.String()
}

func readGuardrailAuditEntries(t *testing.T, projectRoot string) ([]map[string]interface{}, string) {
	t.Helper()
	path := filepath.Join(projectRoot, guardrailAuditRelativePath)
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("read audit log %s: %v", path, err)
	}

	raw := string(data)
	lines := strings.Split(strings.TrimSpace(raw), "\n")
	entries := make([]map[string]interface{}, 0, len(lines))
	for i, line := range lines {
		var entry map[string]interface{}
		if err := json.Unmarshal([]byte(line), &entry); err != nil {
			t.Fatalf("audit line %d is invalid JSON: %v\n%s", i+1, err, line)
		}
		entries = append(entries, entry)
	}
	return entries, raw
}

func assertExactAuditFields(t *testing.T, entry map[string]interface{}, withHost, withCategory, withCommand bool) {
	t.Helper()
	want := map[string]bool{
		"schema_version": true,
		"ts":             true,
		"tool":           true,
		"rule_id":        true,
		"decision":       true,
	}
	if withHost {
		want["host"] = true
	}
	if withCategory {
		want["category"] = true
	}
	if withCommand {
		want["command_sha256"] = true
		want["command_len"] = true
	}
	if !reflect.DeepEqual(mapKeys(entry), want) {
		t.Fatalf("audit fields = %#v, want %#v (entry=%#v)", mapKeys(entry), want, entry)
	}
}

func mapKeys(entry map[string]interface{}) map[string]bool {
	keys := make(map[string]bool, len(entry))
	for key := range entry {
		keys[key] = true
	}
	return keys
}

func sha256Hex(value string) string {
	sum := sha256.Sum256([]byte(value))
	return hex.EncodeToString(sum[:])
}
