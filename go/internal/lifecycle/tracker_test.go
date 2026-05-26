package lifecycle_test

import (
	"testing"
	"time"

	"github.com/Chachamaru127/claude-code-harness/go/internal/lifecycle"
	"github.com/Chachamaru127/claude-code-harness/go/pkg/hookproto"
)

// makeInput is a helper that creates a HookInput with the given agent_id / agent_type.
func makeInput(agentID, agentType, sessionID string) hookproto.HookInput {
	return hookproto.HookInput{
		SessionID: sessionID,
		ToolInput: map[string]interface{}{
			"agent_id":   agentID,
			"agent_type": agentType,
		},
	}
}

// ============================================================
// HandleStart
// ============================================================

func TestHandleStart_RegistersAgent(t *testing.T) {
	tracker := lifecycle.NewAgentTracker(nil)

	input := makeInput("agent-001", "worker", "sess-1")
	if err := tracker.HandleStart(input); err != nil {
		t.Fatalf("HandleStart error: %v", err)
	}

	agent := tracker.Get("agent-001")
	if agent == nil {
		t.Fatal("agent not registered after HandleStart")
	}
	if agent.AgentID != "agent-001" {
		t.Errorf("AgentID = %q, want %q", agent.AgentID, "agent-001")
	}
	if agent.AgentType != "worker" {
		t.Errorf("AgentType = %q, want %q", agent.AgentType, "worker")
	}
	if agent.SessionID != "sess-1" {
		t.Errorf("SessionID = %q, want %q", agent.SessionID, "sess-1")
	}
}

func TestHandleStart_TransitionsToRunning(t *testing.T) {
	tracker := lifecycle.NewAgentTracker(nil)

	input := makeInput("agent-002", "reviewer", "sess-2")
	if err := tracker.HandleStart(input); err != nil {
		t.Fatalf("HandleStart error: %v", err)
	}

	agent := tracker.Get("agent-002")
	if agent == nil {
		t.Fatal("agent not registered")
	}
	if got := agent.SM.Current(); got != lifecycle.StateRunning {
		t.Errorf("state after HandleStart = %s, want RUNNING", got)
	}
}

func TestHandleStart_IsIdempotent(t *testing.T) {
	tracker := lifecycle.NewAgentTracker(nil)

	input := makeInput("agent-003", "worker", "sess-3")
	if err := tracker.HandleStart(input); err != nil {
		t.Fatalf("1st HandleStart error: %v", err)
	}
	// 2nd call: must be idempotent (no error)
	if err := tracker.HandleStart(input); err != nil {
		t.Fatalf("2nd HandleStart error: %v", err)
	}

	// Agent count must remain 1
	statuses := tracker.Status()
	if len(statuses) != 1 {
		t.Errorf("Status() count = %d, want 1", len(statuses))
	}
}

func TestHandleStart_EmptyAgentID_ReturnsError(t *testing.T) {
	tracker := lifecycle.NewAgentTracker(nil)

	input := hookproto.HookInput{
		SessionID: "sess-x",
		ToolInput: map[string]interface{}{
			"agent_type": "worker",
			// agent_id intentionally omitted
		},
	}
	if err := tracker.HandleStart(input); err == nil {
		t.Error("should return an error when agent_id is empty")
	}
}

// ============================================================
// HandleStop
// ============================================================

func TestHandleStop_TransitionsToReviewing(t *testing.T) {
	tracker := lifecycle.NewAgentTracker(nil)

	input := makeInput("agent-010", "worker", "sess-10")
	if err := tracker.HandleStart(input); err != nil {
		t.Fatalf("HandleStart error: %v", err)
	}

	if err := tracker.HandleStop(input); err != nil {
		t.Fatalf("HandleStop error: %v", err)
	}

	agent := tracker.Get("agent-010")
	if agent == nil {
		t.Fatal("agent disappeared")
	}
	if got := agent.SM.Current(); got != lifecycle.StateReviewing {
		t.Errorf("state after HandleStop = %s, want REVIEWING", got)
	}
}

func TestHandleStop_UnknownAgentID_ReturnsError(t *testing.T) {
	tracker := lifecycle.NewAgentTracker(nil)

	input := makeInput("nonexistent", "worker", "sess-x")
	if err := tracker.HandleStop(input); err == nil {
		t.Error("should return an error for an unregistered agent_id")
	}
}

func TestHandleStop_EmptyAgentID_ReturnsError(t *testing.T) {
	tracker := lifecycle.NewAgentTracker(nil)

	input := hookproto.HookInput{
		ToolInput: map[string]interface{}{},
	}
	if err := tracker.HandleStop(input); err == nil {
		t.Error("should return an error when agent_id is empty")
	}
}

// ============================================================
// Status
// ============================================================

func TestStatus_EmptyWhenNoAgents(t *testing.T) {
	tracker := lifecycle.NewAgentTracker(nil)
	statuses := tracker.Status()
	if len(statuses) != 0 {
		t.Errorf("Status() count in initial state = %d, want 0", len(statuses))
	}
}

func TestStatus_ReturnsAllTrackedAgents(t *testing.T) {
	tracker := lifecycle.NewAgentTracker(nil)

	for i, id := range []string{"a-1", "a-2", "a-3"} {
		input := makeInput(id, "worker", "sess-multi")
		if err := tracker.HandleStart(input); err != nil {
			t.Fatalf("HandleStart[%d] error: %v", i, err)
		}
	}

	statuses := tracker.Status()
	if len(statuses) != 3 {
		t.Errorf("Status() count = %d, want 3", len(statuses))
	}
}

func TestStatus_DurationIsPositive(t *testing.T) {
	tracker := lifecycle.NewAgentTracker(nil)

	input := makeInput("dur-agent", "worker", "sess-dur")
	if err := tracker.HandleStart(input); err != nil {
		t.Fatalf("HandleStart error: %v", err)
	}

	// Wait briefly before fetching Status
	time.Sleep(1 * time.Millisecond)

	statuses := tracker.Status()
	if len(statuses) != 1 {
		t.Fatalf("Status() count = %d, want 1", len(statuses))
	}
	if statuses[0].Duration <= 0 {
		t.Errorf("Duration = %v, want > 0", statuses[0].Duration)
	}
}

func TestStatus_StateReflectsLatestTransition(t *testing.T) {
	tracker := lifecycle.NewAgentTracker(nil)

	input := makeInput("state-agent", "reviewer", "sess-state")
	if err := tracker.HandleStart(input); err != nil {
		t.Fatalf("HandleStart error: %v", err)
	}

	// Should be RUNNING immediately after Start
	startStatuses := tracker.Status()
	if len(startStatuses) != 1 {
		t.Fatalf("Status() count differs from expected: %d", len(startStatuses))
	}
	if startStatuses[0].State != lifecycle.StateRunning {
		t.Errorf("state after Start = %s, want RUNNING", startStatuses[0].State)
	}

	// Should be REVIEWING after Stop
	if err := tracker.HandleStop(input); err != nil {
		t.Fatalf("HandleStop error: %v", err)
	}
	stopStatuses := tracker.Status()
	if len(stopStatuses) != 1 {
		t.Fatalf("Status() count after Stop differs from expected: %d", len(stopStatuses))
	}
	if stopStatuses[0].State != lifecycle.StateReviewing {
		t.Errorf("state after Stop = %s, want REVIEWING", stopStatuses[0].State)
	}
}

// ============================================================
// RecoveryAttempts
// ============================================================

func TestStatus_RecoveryAttemptsIsZeroInitially(t *testing.T) {
	tracker := lifecycle.NewAgentTracker(nil)

	input := makeInput("recover-agent", "worker", "sess-recover")
	if err := tracker.HandleStart(input); err != nil {
		t.Fatalf("HandleStart error: %v", err)
	}

	statuses := tracker.Status()
	if len(statuses) != 1 {
		t.Fatalf("Status() count = %d, want 1", len(statuses))
	}
	if statuses[0].RecoveryAttempts != 0 {
		t.Errorf("RecoveryAttempts = %d, want 0", statuses[0].RecoveryAttempts)
	}
}

// ============================================================
// StateMachine integration
// ============================================================

func TestTracker_StateMachineConnectedToRecovery(t *testing.T) {
	tracker := lifecycle.NewAgentTracker(nil)

	input := makeInput("sm-agent", "worker", "sess-sm")
	if err := tracker.HandleStart(input); err != nil {
		t.Fatalf("HandleStart error: %v", err)
	}

	agent := tracker.Get("sm-agent")
	if agent == nil {
		t.Fatal("agent not registered")
	}
	if agent.SM == nil {
		t.Fatal("SM is nil")
	}
	if agent.Recovery == nil {
		t.Fatal("Recovery is nil")
	}

	// Verify SM and Recovery are connected:
	// RUNNING → FAILED → RECOVERING should work
	if err := agent.SM.Transition(lifecycle.StateFailed, "test failure"); err != nil {
		t.Fatalf("RUNNING → FAILED transition failed: %v", err)
	}

	action := agent.Recovery.HandleFailure(nil)
	if action.Level != lifecycle.SelfHeal {
		t.Errorf("RecoveryAction.Level = %v, want SelfHeal", action.Level)
	}
	// HandleFailure should have transitioned FAILED → RECOVERING
	if got := agent.SM.Current(); got != lifecycle.StateRecovering {
		t.Errorf("state after HandleFailure = %s, want RECOVERING", got)
	}
}

// ============================================================
// extractAgentID / extractAgentType (indirect tests)
// ============================================================

func TestHandleStart_AgentTypeStoredCorrectly(t *testing.T) {
	tracker := lifecycle.NewAgentTracker(nil)

	for _, tc := range []struct {
		id       string
		agentTyp string
	}{
		{"t-worker", "worker"},
		{"t-reviewer", "reviewer"},
		{"t-scaffolder", "scaffolder"},
	} {
		input := makeInput(tc.id, tc.agentTyp, "sess-type")
		if err := tracker.HandleStart(input); err != nil {
			t.Fatalf("HandleStart(%s) error: %v", tc.id, err)
		}
		agent := tracker.Get(tc.id)
		if agent == nil {
			t.Fatalf("Get(%s) returned nil", tc.id)
		}
		if agent.AgentType != tc.agentTyp {
			t.Errorf("AgentType(%s) = %q, want %q", tc.id, agent.AgentType, tc.agentTyp)
		}
	}
}
