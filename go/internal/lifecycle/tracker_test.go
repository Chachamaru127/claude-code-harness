package lifecycle_test

import (
	"testing"
	"time"

	"github.com/Chachamaru127/claude-code-harness/go/internal/lifecycle"
	"github.com/Chachamaru127/claude-code-harness/go/pkg/hookproto"
)

// makeInput は指定した agent_id / agent_type を持つ HookInput を生成するヘルパー。
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
		t.Fatalf("HandleStart エラー: %v", err)
	}

	agent := tracker.Get("agent-001")
	if agent == nil {
		t.Fatal("HandleStart 後にエージェントが登録されていない")
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
		t.Fatalf("HandleStart エラー: %v", err)
	}

	agent := tracker.Get("agent-002")
	if agent == nil {
		t.Fatal("エージェントが登録されていない")
	}
	if got := agent.SM.Current(); got != lifecycle.StateRunning {
		t.Errorf("HandleStart 後の状態 = %s, want RUNNING", got)
	}
}

func TestHandleStart_IsIdempotent(t *testing.T) {
	tracker := lifecycle.NewAgentTracker(nil)

	input := makeInput("agent-003", "worker", "sess-3")
	if err := tracker.HandleStart(input); err != nil {
		t.Fatalf("1回目の HandleStart エラー: %v", err)
	}
	// 2回目: 冪等であること（エラーなし）
	if err := tracker.HandleStart(input); err != nil {
		t.Fatalf("2回目の HandleStart エラー: %v", err)
	}

	// エージェントは1件のまま
	statuses := tracker.Status()
	if len(statuses) != 1 {
		t.Errorf("Status() 件数 = %d, want 1", len(statuses))
	}
}

func TestHandleStart_EmptyAgentID_ReturnsError(t *testing.T) {
	tracker := lifecycle.NewAgentTracker(nil)

	input := hookproto.HookInput{
		SessionID: "sess-x",
		ToolInput: map[string]interface{}{
			"agent_type": "worker",
			// agent_id を意図的に省略
		},
	}
	if err := tracker.HandleStart(input); err == nil {
		t.Error("agent_id が空の場合はエラーを返すべき")
	}
}

// ============================================================
// HandleStop
// ============================================================

func TestHandleStop_TransitionsToReviewing(t *testing.T) {
	tracker := lifecycle.NewAgentTracker(nil)

	input := makeInput("agent-010", "worker", "sess-10")
	if err := tracker.HandleStart(input); err != nil {
		t.Fatalf("HandleStart エラー: %v", err)
	}

	if err := tracker.HandleStop(input); err != nil {
		t.Fatalf("HandleStop エラー: %v", err)
	}

	agent := tracker.Get("agent-010")
	if agent == nil {
		t.Fatal("エージェントが消えた")
	}
	if got := agent.SM.Current(); got != lifecycle.StateReviewing {
		t.Errorf("HandleStop 後の状態 = %s, want REVIEWING", got)
	}
}

func TestHandleStop_UnknownAgentID_ReturnsError(t *testing.T) {
	tracker := lifecycle.NewAgentTracker(nil)

	input := makeInput("nonexistent", "worker", "sess-x")
	if err := tracker.HandleStop(input); err == nil {
		t.Error("未登録 agent_id の場合はエラーを返すべき")
	}
}

func TestHandleStop_EmptyAgentID_ReturnsError(t *testing.T) {
	tracker := lifecycle.NewAgentTracker(nil)

	input := hookproto.HookInput{
		ToolInput: map[string]interface{}{},
	}
	if err := tracker.HandleStop(input); err == nil {
		t.Error("agent_id が空の場合はエラーを返すべき")
	}
}

// ============================================================
// Status
// ============================================================

func TestStatus_EmptyWhenNoAgents(t *testing.T) {
	tracker := lifecycle.NewAgentTracker(nil)
	statuses := tracker.Status()
	if len(statuses) != 0 {
		t.Errorf("初期状態の Status() 件数 = %d, want 0", len(statuses))
	}
}

func TestStatus_ReturnsAllTrackedAgents(t *testing.T) {
	tracker := lifecycle.NewAgentTracker(nil)

	for i, id := range []string{"a-1", "a-2", "a-3"} {
		input := makeInput(id, "worker", "sess-multi")
		if err := tracker.HandleStart(input); err != nil {
			t.Fatalf("HandleStart[%d] エラー: %v", i, err)
		}
	}

	statuses := tracker.Status()
	if len(statuses) != 3 {
		t.Errorf("Status() 件数 = %d, want 3", len(statuses))
	}
}

func TestStatus_DurationIsPositive(t *testing.T) {
	tracker := lifecycle.NewAgentTracker(nil)

	input := makeInput("dur-agent", "worker", "sess-dur")
	if err := tracker.HandleStart(input); err != nil {
		t.Fatalf("HandleStart エラー: %v", err)
	}

	// 少し待ってから Status を取得
	time.Sleep(1 * time.Millisecond)

	statuses := tracker.Status()
	if len(statuses) != 1 {
		t.Fatalf("Status() 件数 = %d, want 1", len(statuses))
	}
	if statuses[0].Duration <= 0 {
		t.Errorf("Duration = %v, want > 0", statuses[0].Duration)
	}
}

func TestStatus_StateReflectsLatestTransition(t *testing.T) {
	tracker := lifecycle.NewAgentTracker(nil)

	input := makeInput("state-agent", "reviewer", "sess-state")
	if err := tracker.HandleStart(input); err != nil {
		t.Fatalf("HandleStart エラー: %v", err)
	}

	// Start 直後は RUNNING
	startStatuses := tracker.Status()
	if len(startStatuses) != 1 {
		t.Fatalf("Status() 件数が期待と異なる: %d", len(startStatuses))
	}
	if startStatuses[0].State != lifecycle.StateRunning {
		t.Errorf("Start 後の状態 = %s, want RUNNING", startStatuses[0].State)
	}

	// Stop 後は REVIEWING
	if err := tracker.HandleStop(input); err != nil {
		t.Fatalf("HandleStop エラー: %v", err)
	}
	stopStatuses := tracker.Status()
	if len(stopStatuses) != 1 {
		t.Fatalf("Stop 後の Status() 件数が期待と異なる: %d", len(stopStatuses))
	}
	if stopStatuses[0].State != lifecycle.StateReviewing {
		t.Errorf("Stop 後の状態 = %s, want REVIEWING", stopStatuses[0].State)
	}
}

// ============================================================
// RecoveryAttempts
// ============================================================

func TestStatus_RecoveryAttemptsIsZeroInitially(t *testing.T) {
	tracker := lifecycle.NewAgentTracker(nil)

	input := makeInput("recover-agent", "worker", "sess-recover")
	if err := tracker.HandleStart(input); err != nil {
		t.Fatalf("HandleStart エラー: %v", err)
	}

	statuses := tracker.Status()
	if len(statuses) != 1 {
		t.Fatalf("Status() 件数 = %d, want 1", len(statuses))
	}
	if statuses[0].RecoveryAttempts != 0 {
		t.Errorf("RecoveryAttempts = %d, want 0", statuses[0].RecoveryAttempts)
	}
}

// ============================================================
// StateMachine 連携
// ============================================================

func TestTracker_StateMachineConnectedToRecovery(t *testing.T) {
	tracker := lifecycle.NewAgentTracker(nil)

	input := makeInput("sm-agent", "worker", "sess-sm")
	if err := tracker.HandleStart(input); err != nil {
		t.Fatalf("HandleStart エラー: %v", err)
	}

	agent := tracker.Get("sm-agent")
	if agent == nil {
		t.Fatal("エージェントが登録されていない")
	}
	if agent.SM == nil {
		t.Fatal("SM が nil")
	}
	if agent.Recovery == nil {
		t.Fatal("Recovery が nil")
	}

	// SM と Recovery が連携していることを確認:
	// RUNNING → FAILED → RECOVERING が動作すること
	if err := agent.SM.Transition(lifecycle.StateFailed, "test failure"); err != nil {
		t.Fatalf("RUNNING → FAILED 遷移失敗: %v", err)
	}

	action := agent.Recovery.HandleFailure(nil)
	if action.Level != lifecycle.SelfHeal {
		t.Errorf("RecoveryAction.Level = %v, want SelfHeal", action.Level)
	}
	// HandleFailure により FAILED → RECOVERING へ遷移しているはず
	if got := agent.SM.Current(); got != lifecycle.StateRecovering {
		t.Errorf("HandleFailure 後の状態 = %s, want RECOVERING", got)
	}
}

// ============================================================
// extractAgentID / extractAgentType（間接テスト）
// ============================================================

func TestHandleStart_AgentTypeStoredCorrectly(t *testing.T) {
	tracker := lifecycle.NewAgentTracker(nil)

	for _, tc := range []struct {
		id       string
		agentTyp string
	}{
		{"t-worker", "worker"},
		{"t-reviewer", "reviewer"},
		{"t-advisor", "advisor"},
	} {
		input := makeInput(tc.id, tc.agentTyp, "sess-type")
		if err := tracker.HandleStart(input); err != nil {
			t.Fatalf("HandleStart(%s) エラー: %v", tc.id, err)
		}
		agent := tracker.Get(tc.id)
		if agent == nil {
			t.Fatalf("Get(%s) が nil", tc.id)
		}
		if agent.AgentType != tc.agentTyp {
			t.Errorf("AgentType(%s) = %q, want %q", tc.id, agent.AgentType, tc.agentTyp)
		}
	}
}
