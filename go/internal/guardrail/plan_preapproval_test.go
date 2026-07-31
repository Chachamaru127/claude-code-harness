package guardrail

import (
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"sync"
	"sync/atomic"
	"testing"

	"github.com/Chachamaru127/claude-code-harness/go/pkg/hookproto"
)

type planPreapprovalTestApproval struct {
	Scope     map[string]string
	Commands  []string
	ExpiresAt string
	MaxUses   *int
	Uses      *int
	Decision  string
	Operation string
}

func intPtr(value int) *int {
	return &value
}

func writePlanPreapprovalFixture(t *testing.T, projectRoot string, approvals ...planPreapprovalTestApproval) string {
	t.Helper()

	rawApprovals := make([]map[string]interface{}, 0, len(approvals))
	for index, approval := range approvals {
		operation := approval.Operation
		if operation == "" {
			operation = "external-send"
		}
		decision := approval.Decision
		if decision == "" {
			decision = "approved"
		}
		entry := map[string]interface{}{
			"item":        "approved operation",
			"reason":      "Task 126.5 regression fixture",
			"scope":       approval.Scope,
			"operations":  []string{operation},
			"commands":    approval.Commands,
			"decision":    decision,
			"approved_at": "2026-07-28T00:00:00Z",
			"expires_at":  approval.ExpiresAt,
		}
		if approval.MaxUses != nil {
			entry["max_uses"] = *approval.MaxUses
		}
		if approval.Uses != nil {
			entry["uses"] = *approval.Uses
		}
		entry["item"] = "approved operation " + string(rune('A'+index))
		rawApprovals = append(rawApprovals, entry)
	}

	state := map[string]interface{}{
		"schema_version": "plan-preapproval.v2",
		"approved_at":    "2026-07-28T00:00:00Z",
		"approvals":      rawApprovals,
	}
	data, err := json.MarshalIndent(state, "", "  ")
	if err != nil {
		t.Fatal(err)
	}
	data = append(data, '\n')

	stateDir := filepath.Join(projectRoot, ".claude", "state")
	if err := os.MkdirAll(stateDir, 0o700); err != nil {
		t.Fatal(err)
	}
	statePath := filepath.Join(stateDir, "plan-preapprovals.json")
	if err := os.WriteFile(statePath, data, 0o600); err != nil {
		t.Fatal(err)
	}
	return statePath
}

func writeActiveTaskFixture(t *testing.T, projectRoot, phase, task string) {
	t.Helper()

	stateDir := filepath.Join(projectRoot, ".claude", "state")
	if err := os.MkdirAll(stateDir, 0o700); err != nil {
		t.Fatal(err)
	}
	data, err := json.Marshal(map[string]string{"phase": phase, "task": task})
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(stateDir, "active-task.json"), data, 0o600); err != nil {
		t.Fatal(err)
	}
}

func planPreapprovalPushInput(projectRoot, command string) hookproto.HookInput {
	return hookproto.HookInput{
		CWD:      projectRoot,
		ToolName: "Bash",
		ToolInput: map[string]interface{}{
			"command": command,
		},
	}
}

func isolatePlanPreapprovalEnv(t *testing.T) {
	t.Helper()
	for _, name := range []string{
		"HARNESS_ACTIVE_PHASE",
		"HARNESS_ACTIVE_TASK",
		"HARNESS_PROTECTED_BRANCH_PUSH_POLICY",
		"HARNESS_DIRECT_PUSH_POLICY",
		"HARNESS_RUNTIME_FLOOR_EGRESS",
		"HARNESS_RUNTIME_FLOOR_SECRET_ALLOW",
	} {
		t.Setenv(name, "")
	}
}

func TestR12PlanPreapprovalApprovedMatchingScopeSuppressesAskAndIncrementsUses(t *testing.T) {
	isolatePlanPreapprovalEnv(t)
	projectRoot := t.TempDir()
	writeActiveTaskFixture(t, projectRoot, "126", "126.5")
	statePath := writePlanPreapprovalFixture(t, projectRoot, planPreapprovalTestApproval{
		Scope:     map[string]string{"phase": "126", "task": "126.5"},
		Commands:  []string{"git push origin <branch>"},
		ExpiresAt: "2999-07-28T00:00:00Z",
	})

	result := EvaluatePreTool(planPreapprovalPushInput(projectRoot, "git push origin main"))
	if result.Decision != hookproto.DecisionApprove {
		t.Fatalf("approved matching preapproval decision = %q, want approve: %#v", result.Decision, result)
	}

	assertPlanPreapprovalUses(t, statePath, 0, 1)
}

func TestR12PlanPreapprovalFailSafeFallsBackToAsk(t *testing.T) {
	tests := []struct {
		name  string
		setup func(t *testing.T, projectRoot string)
	}{
		{
			name: "missing approval file",
			setup: func(t *testing.T, projectRoot string) {
				writeActiveTaskFixture(t, projectRoot, "126", "126.5")
			},
		},
		{
			name: "expired approval",
			setup: func(t *testing.T, projectRoot string) {
				writeActiveTaskFixture(t, projectRoot, "126", "126.5")
				writePlanPreapprovalFixture(t, projectRoot, planPreapprovalTestApproval{
					Scope:     map[string]string{"phase": "126", "task": "126.5"},
					Commands:  []string{"git push origin <branch>"},
					ExpiresAt: "2020-01-01T00:00:00Z",
				})
			},
		},
		{
			name: "usage limit reached",
			setup: func(t *testing.T, projectRoot string) {
				writeActiveTaskFixture(t, projectRoot, "126", "126.5")
				writePlanPreapprovalFixture(t, projectRoot, planPreapprovalTestApproval{
					Scope:     map[string]string{"phase": "126", "task": "126.5"},
					Commands:  []string{"git push origin <branch>"},
					ExpiresAt: "2999-07-28T00:00:00Z",
					MaxUses:   intPtr(2),
					Uses:      intPtr(2),
				})
			},
		},
		{
			name: "phase mismatch",
			setup: func(t *testing.T, projectRoot string) {
				writeActiveTaskFixture(t, projectRoot, "127", "126.5")
				writePlanPreapprovalFixture(t, projectRoot, planPreapprovalTestApproval{
					Scope:     map[string]string{"phase": "126", "task": "126.5"},
					Commands:  []string{"git push origin <branch>"},
					ExpiresAt: "2999-07-28T00:00:00Z",
				})
			},
		},
		{
			name: "task mismatch",
			setup: func(t *testing.T, projectRoot string) {
				writeActiveTaskFixture(t, projectRoot, "126", "126.6")
				writePlanPreapprovalFixture(t, projectRoot, planPreapprovalTestApproval{
					Scope:     map[string]string{"phase": "126", "task": "126.5"},
					Commands:  []string{"git push origin <branch>"},
					ExpiresAt: "2999-07-28T00:00:00Z",
				})
			},
		},
		{
			name: "active task file takes precedence over environment",
			setup: func(t *testing.T, projectRoot string) {
				t.Setenv("HARNESS_ACTIVE_PHASE", "126")
				t.Setenv("HARNESS_ACTIVE_TASK", "126.5")
				writeActiveTaskFixture(t, projectRoot, "126", "126.6")
				writePlanPreapprovalFixture(t, projectRoot, planPreapprovalTestApproval{
					Scope:     map[string]string{"phase": "126", "task": "126.5"},
					Commands:  []string{"git push origin <branch>"},
					ExpiresAt: "2999-07-28T00:00:00Z",
				})
			},
		},
		{
			name: "scope unresolved",
			setup: func(t *testing.T, projectRoot string) {
				writePlanPreapprovalFixture(t, projectRoot, planPreapprovalTestApproval{
					Scope:     map[string]string{"phase": "126", "task": "126.5"},
					Commands:  []string{"git push origin <branch>"},
					ExpiresAt: "2999-07-28T00:00:00Z",
				})
			},
		},
		{
			name: "malformed active task does not fall through to environment",
			setup: func(t *testing.T, projectRoot string) {
				t.Setenv("HARNESS_ACTIVE_PHASE", "126")
				t.Setenv("HARNESS_ACTIVE_TASK", "126.5")
				stateDir := filepath.Join(projectRoot, ".claude", "state")
				if err := os.MkdirAll(stateDir, 0o700); err != nil {
					t.Fatal(err)
				}
				if err := os.WriteFile(filepath.Join(stateDir, "active-task.json"), []byte("{broken"), 0o600); err != nil {
					t.Fatal(err)
				}
				writePlanPreapprovalFixture(t, projectRoot, planPreapprovalTestApproval{
					Scope:     map[string]string{"phase": "126", "task": "126.5"},
					Commands:  []string{"git push origin <branch>"},
					ExpiresAt: "2999-07-28T00:00:00Z",
				})
			},
		},
		{
			name: "malformed approval JSON",
			setup: func(t *testing.T, projectRoot string) {
				writeActiveTaskFixture(t, projectRoot, "126", "126.5")
				stateDir := filepath.Join(projectRoot, ".claude", "state")
				if err := os.WriteFile(filepath.Join(stateDir, "plan-preapprovals.json"), []byte("{broken"), 0o600); err != nil {
					t.Fatal(err)
				}
			},
		},
		{
			name: "schema mismatch",
			setup: func(t *testing.T, projectRoot string) {
				writeActiveTaskFixture(t, projectRoot, "126", "126.5")
				statePath := writePlanPreapprovalFixture(t, projectRoot, planPreapprovalTestApproval{
					Scope:     map[string]string{"phase": "126", "task": "126.5"},
					Commands:  []string{"git push origin <branch>"},
					ExpiresAt: "2999-07-28T00:00:00Z",
				})
				var state map[string]interface{}
				data, err := os.ReadFile(statePath)
				if err != nil {
					t.Fatal(err)
				}
				if err := json.Unmarshal(data, &state); err != nil {
					t.Fatal(err)
				}
				state["unexpected"] = true
				data, err = json.Marshal(state)
				if err != nil {
					t.Fatal(err)
				}
				if err := os.WriteFile(statePath, data, 0o600); err != nil {
					t.Fatal(err)
				}
			},
		},
		{
			name: "schema mismatch explicit null",
			setup: func(t *testing.T, projectRoot string) {
				writeActiveTaskFixture(t, projectRoot, "126", "126.5")
				statePath := writePlanPreapprovalFixture(t, projectRoot, planPreapprovalTestApproval{
					Scope:     map[string]string{"phase": "126", "task": "126.5"},
					Commands:  []string{"git push origin <branch>"},
					ExpiresAt: "2999-07-28T00:00:00Z",
				})
				var state map[string]interface{}
				data, err := os.ReadFile(statePath)
				if err != nil {
					t.Fatal(err)
				}
				if err := json.Unmarshal(data, &state); err != nil {
					t.Fatal(err)
				}
				approvals := state["approvals"].([]interface{})
				approvals[0].(map[string]interface{})["max_uses"] = nil
				data, err = json.Marshal(state)
				if err != nil {
					t.Fatal(err)
				}
				if err := os.WriteFile(statePath, data, 0o600); err != nil {
					t.Fatal(err)
				}
			},
		},
		{
			name: "legacy v1 has no R12 runtime authority",
			setup: func(t *testing.T, projectRoot string) {
				writeActiveTaskFixture(t, projectRoot, "126", "126.5")
				statePath := writePlanPreapprovalFixture(t, projectRoot, planPreapprovalTestApproval{
					Scope:     map[string]string{"phase": "126", "task": "126.5"},
					Commands:  []string{"git push origin <branch>"},
					ExpiresAt: "2999-07-28T00:00:00Z",
				})
				var state map[string]interface{}
				data, err := os.ReadFile(statePath)
				if err != nil {
					t.Fatal(err)
				}
				if err := json.Unmarshal(data, &state); err != nil {
					t.Fatal(err)
				}
				state["schema_version"] = "plan-preapproval.v1"
				for _, rawApproval := range state["approvals"].([]interface{}) {
					approval := rawApproval.(map[string]interface{})
					delete(approval, "expires_at")
					delete(approval, "max_uses")
					delete(approval, "uses")
				}
				data, err = json.Marshal(state)
				if err != nil {
					t.Fatal(err)
				}
				if err := os.WriteFile(statePath, data, 0o600); err != nil {
					t.Fatal(err)
				}
			},
		},
		{
			name: "decision denied",
			setup: func(t *testing.T, projectRoot string) {
				writeActiveTaskFixture(t, projectRoot, "126", "126.5")
				writePlanPreapprovalFixture(t, projectRoot, planPreapprovalTestApproval{
					Scope:     map[string]string{"phase": "126", "task": "126.5"},
					Commands:  []string{"git push origin <branch>"},
					ExpiresAt: "2999-07-28T00:00:00Z",
					Decision:  "denied",
				})
			},
		},
		{
			name: "operation not external send",
			setup: func(t *testing.T, projectRoot string) {
				writeActiveTaskFixture(t, projectRoot, "126", "126.5")
				writePlanPreapprovalFixture(t, projectRoot, planPreapprovalTestApproval{
					Scope:     map[string]string{"phase": "126", "task": "126.5"},
					Commands:  []string{"git push origin <branch>"},
					ExpiresAt: "2999-07-28T00:00:00Z",
					Operation: "destructive",
				})
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			isolatePlanPreapprovalEnv(t)
			projectRoot := t.TempDir()
			tt.setup(t, projectRoot)

			result := EvaluatePreTool(planPreapprovalPushInput(projectRoot, "git push origin main"))
			if result.Decision != hookproto.DecisionAsk {
				t.Fatalf("decision = %q, want ask: %#v", result.Decision, result)
			}
			if result.RuleID != "R12:confirm-direct-push-protected-branch" {
				t.Fatalf("rule ID = %q, want R12", result.RuleID)
			}
		})
	}
}

func TestR12PlanPreapprovalScopeEnvironmentFallback(t *testing.T) {
	isolatePlanPreapprovalEnv(t)
	t.Setenv("HARNESS_ACTIVE_PHASE", "126")
	t.Setenv("HARNESS_ACTIVE_TASK", "126.5")
	projectRoot := t.TempDir()
	statePath := writePlanPreapprovalFixture(t, projectRoot, planPreapprovalTestApproval{
		Scope:     map[string]string{"phase": "126", "task": "126.5"},
		Commands:  []string{"git push origin main"},
		ExpiresAt: "2999-07-28T00:00:00Z",
	})

	result := EvaluatePreTool(planPreapprovalPushInput(projectRoot, "git push origin main"))
	if result.Decision != hookproto.DecisionApprove {
		t.Fatalf("env-scoped preapproval decision = %q, want approve: %#v", result.Decision, result)
	}
	assertPlanPreapprovalUses(t, statePath, 0, 1)
}

func TestPlanPreapprovalCommandPlaceholderMatchesExactlyOneToken(t *testing.T) {
	tests := []struct {
		name    string
		pattern string
		command string
		want    bool
	}{
		{
			name:    "placeholder matches branch token",
			pattern: "git   push origin   <branch>",
			command: "git push  origin feature/x",
			want:    true,
		},
		{
			name:    "extra force token is rejected",
			pattern: "git push origin <branch>",
			command: "git push origin main --force",
			want:    false,
		},
		{
			name:    "placeholder does not span whitespace",
			pattern: "git push origin <refspec>",
			command: "git push origin HEAD : main",
			want:    false,
		},
		{
			name:    "literal metacharacters are not regex",
			pattern: "git push origin release[1]",
			command: "git push origin release1",
			want:    false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := matchesPlanPreapprovalCommand(tt.pattern, tt.command); got != tt.want {
				t.Fatalf("matchesPlanPreapprovalCommand(%q, %q) = %t, want %t", tt.pattern, tt.command, got, tt.want)
			}
		})
	}
}

func TestR12PlanPreapprovalDoesNotOverrideDenyPolicy(t *testing.T) {
	isolatePlanPreapprovalEnv(t)
	t.Setenv("HARNESS_PROTECTED_BRANCH_PUSH_POLICY", "deny")
	projectRoot := t.TempDir()
	writeActiveTaskFixture(t, projectRoot, "126", "126.5")
	statePath := writePlanPreapprovalFixture(t, projectRoot, planPreapprovalTestApproval{
		Scope:     map[string]string{"phase": "126", "task": "126.5"},
		Commands:  []string{"git push origin main"},
		ExpiresAt: "2999-07-28T00:00:00Z",
	})

	result := EvaluatePreTool(planPreapprovalPushInput(projectRoot, "git push origin main"))
	if result.Decision != hookproto.DecisionDeny {
		t.Fatalf("deny policy decision = %q, want deny: %#v", result.Decision, result)
	}
	assertPlanPreapprovalUses(t, statePath, 0, 0)
}

func TestR12PlanPreapprovalUsageWriteFailureKeepsSuppressionAndAudits(t *testing.T) {
	isolatePlanPreapprovalEnv(t)
	projectRoot := t.TempDir()
	writeActiveTaskFixture(t, projectRoot, "126", "126.5")
	statePath := writePlanPreapprovalFixture(t, projectRoot, planPreapprovalTestApproval{
		Scope:     map[string]string{"phase": "126", "task": "126.5"},
		Commands:  []string{"git push origin main"},
		ExpiresAt: "2999-07-28T00:00:00Z",
	})

	originalWriter := planPreapprovalStateWriter
	planPreapprovalStateWriter = func(string, planPreapprovalState) error {
		return errors.New("injected usage write failure")
	}
	t.Cleanup(func() {
		planPreapprovalStateWriter = originalWriter
	})

	result := EvaluatePreTool(planPreapprovalPushInput(projectRoot, "git push origin main"))
	if result.Decision != hookproto.DecisionApprove {
		t.Fatalf("write failure changed approved decision to %q: %#v", result.Decision, result)
	}
	assertPlanPreapprovalUses(t, statePath, 0, 0)

	entries, _ := readGuardrailAuditEntries(t, projectRoot)
	if len(entries) != 1 {
		t.Fatalf("audit entries = %d, want one write-failure warning", len(entries))
	}
	if got := entries[0]["rule_id"]; got != "R12:plan-preapproval-usage-write-failed" {
		t.Fatalf("audit rule_id = %v, want R12 usage write failure", got)
	}
	if got := entries[0]["decision"]; got != "warn" {
		t.Fatalf("audit decision = %v, want warn", got)
	}
}

func TestR12PlanPreapprovalConcurrentUsesDoNotExceedLimit(t *testing.T) {
	isolatePlanPreapprovalEnv(t)
	projectRoot := t.TempDir()
	writeActiveTaskFixture(t, projectRoot, "126", "126.5")
	statePath := writePlanPreapprovalFixture(t, projectRoot, planPreapprovalTestApproval{
		Scope:     map[string]string{"phase": "126", "task": "126.5"},
		Commands:  []string{"git push origin main"},
		ExpiresAt: "2999-07-28T00:00:00Z",
		MaxUses:   intPtr(10),
	})

	var approved atomic.Int32
	var asked atomic.Int32
	var wg sync.WaitGroup
	for range 20 {
		wg.Add(1)
		go func() {
			defer wg.Done()
			result := EvaluatePreTool(planPreapprovalPushInput(projectRoot, "git push origin main"))
			switch result.Decision {
			case hookproto.DecisionApprove:
				approved.Add(1)
			case hookproto.DecisionAsk:
				asked.Add(1)
			default:
				t.Errorf("unexpected decision: %#v", result)
			}
		}()
	}
	wg.Wait()

	if got := approved.Load(); got != 10 {
		t.Fatalf("approved count = %d, want 10", got)
	}
	if got := asked.Load(); got != 10 {
		t.Fatalf("ask count = %d, want 10", got)
	}
	assertPlanPreapprovalUses(t, statePath, 0, 10)
}

func assertPlanPreapprovalUses(t *testing.T, statePath string, approvalIndex, want int) {
	t.Helper()

	data, err := os.ReadFile(statePath)
	if err != nil {
		t.Fatal(err)
	}
	var state struct {
		Approvals []struct {
			Uses int `json:"uses"`
		} `json:"approvals"`
	}
	if err := json.Unmarshal(data, &state); err != nil {
		t.Fatal(err)
	}
	if approvalIndex >= len(state.Approvals) {
		t.Fatalf("approval index %d out of range", approvalIndex)
	}
	if got := state.Approvals[approvalIndex].Uses; got != want {
		t.Fatalf("approval uses = %d, want %d", got, want)
	}
}
