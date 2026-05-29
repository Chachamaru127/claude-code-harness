// Package lifecycle はエージェントのライフサイクル状態マシンを提供する。
package lifecycle

import (
	"fmt"
	"sync"
	"time"

	"github.com/Chachamaru127/claude-code-harness/go/internal/state"
	"github.com/Chachamaru127/claude-code-harness/go/pkg/hookproto"
)

// TrackedAgent は追跡中の個々のエージェントを表す。
type TrackedAgent struct {
	// AgentID はエージェントの識別子（CC が付与する agent_id）。
	AgentID string
	// AgentType はエージェントの種別（worker / reviewer / advisor 等）。
	AgentType string
	// SessionID はエージェントが属するセッションの識別子。
	SessionID string
	// SM はエージェントのライフサイクル状態マシン。
	SM *StateMachine
	// Recovery はエージェントのリカバリマネージャ。
	Recovery *RecoveryManager
	// StartedAt はエージェントの起動時刻。
	StartedAt time.Time
}

// AgentStatus は AgentTracker.Status() が返す単一エージェントの状態スナップショット。
type AgentStatus struct {
	// AgentID はエージェントの識別子。
	AgentID string
	// AgentType はエージェントの種別。
	AgentType string
	// SessionID は親セッションの識別子。
	SessionID string
	// State は現在の状態。
	State AgentState
	// Duration はエージェントの起動から現在までの経過時間。
	Duration time.Duration
	// RecoveryAttempts はリカバリ試行回数。
	RecoveryAttempts int
}

// AgentTracker は SubagentStart/Stop イベントを受け取り、
// エージェントのライフサイクル状態を管理する。
// ゴルーチンセーフ。SQLite ストアが利用可能な場合、状態を永続化する。
type AgentTracker struct {
	mu     sync.RWMutex
	agents map[string]*TrackedAgent // agent_id → TrackedAgent
	store  *state.HarnessStore      // SQLite 永続化（nil = インメモリのみ）
	now    func() time.Time         // テスト時差し替え可能な時刻ファンクション
}

// NewAgentTracker は新しい AgentTracker を返す。
// store が nil の場合、状態はインメモリのみで管理される（テスト用途）。
func NewAgentTracker(store *state.HarnessStore) *AgentTracker {
	return &AgentTracker{
		agents: make(map[string]*TrackedAgent),
		store:  store,
		now:    time.Now,
	}
}

// HandleStart は SubagentStart イベントを処理する。
// 新しい TrackedAgent を登録し、SPAWNING → RUNNING へ遷移する。
// agent_id が既に登録済みの場合は何もしない（冪等）。
func (t *AgentTracker) HandleStart(input hookproto.HookInput) error {
	agentID := extractAgentID(input)
	agentType := extractAgentType(input)
	sessionID := input.SessionID

	if agentID == "" {
		return fmt.Errorf("tracker: HandleStart: agent_id が空です")
	}

	t.mu.Lock()
	defer t.mu.Unlock()

	// 冪等: 既に登録済みならスキップ
	if _, exists := t.agents[agentID]; exists {
		return nil
	}

	sm := NewStateMachine()
	// SPAWNING → RUNNING へ即座に遷移（SubagentStart = 起動完了通知）
	if err := sm.Transition(StateRunning, "SubagentStart"); err != nil {
		return fmt.Errorf("tracker: HandleStart: 状態遷移失敗: %w", err)
	}

	agent := &TrackedAgent{
		AgentID:   agentID,
		AgentType: agentType,
		SessionID: sessionID,
		SM:        sm,
		StartedAt: t.now(),
	}
	agent.Recovery = NewRecoveryManager(sm)
	t.agents[agentID] = agent

	// SQLite 永続化
	if t.store != nil {
		rec := state.AgentStateRecord{
			AgentID:          agentID,
			AgentType:        agentType,
			SessionID:        sessionID,
			State:            string(StateRunning),
			StartedAt:        agent.StartedAt.UTC().Format(time.RFC3339),
			RecoveryAttempts: 0,
		}
		if err := t.store.UpsertAgentState(rec); err != nil {
			// 永続化失敗はエラーにするが処理は継続しない（fatal）
			return fmt.Errorf("tracker: HandleStart: DB 保存失敗: %w", err)
		}
	}

	return nil
}

// HandleStop は SubagentStop イベントを処理する。
// エージェントを RUNNING → REVIEWING へ遷移し、停止時刻を記録する。
// インメモリに未登録でも SQLite に記録があれば DB ベースで状態を更新する。
// agent_id が未登録かつ DB にも存在しない場合はエラーを返す。
func (t *AgentTracker) HandleStop(input hookproto.HookInput) error {
	agentID := extractAgentID(input)

	if agentID == "" {
		return fmt.Errorf("tracker: HandleStop: agent_id が空です")
	}

	t.mu.Lock()
	defer t.mu.Unlock()

	agent, exists := t.agents[agentID]
	if !exists {
		// インメモリ未登録: DB から復元を試みる
		if t.store != nil {
			rec, err := t.store.GetAgentState(agentID)
			if err != nil {
				return fmt.Errorf("tracker: HandleStop: DB 参照失敗: %w", err)
			}
			if rec != nil {
				// DB レコードからインメモリ AgentTracker を再構成する
				restored, restoreErr := t.restoreFromRecord(rec)
				if restoreErr != nil {
					return fmt.Errorf("tracker: HandleStop: 状態復元失敗: %w", restoreErr)
				}
				t.agents[agentID] = restored
				agent = restored
				exists = true
			}
		}
		if !exists {
			return fmt.Errorf("tracker: HandleStop: 未登録の agent_id=%q", agentID)
		}
	}

	// RUNNING → REVIEWING へ遷移（SubagentStop = タスク完了、レビュー待ち）
	// 既に REVIEWING 以降の状態になっている場合は遷移をスキップ
	if agent.SM.CanTransition(StateReviewing) {
		if err := agent.SM.Transition(StateReviewing, "SubagentStop"); err != nil {
			return fmt.Errorf("tracker: HandleStop: 状態遷移失敗: %w", err)
		}
	}

	// SQLite 永続化
	if t.store != nil {
		stoppedAtStr := t.now().UTC().Format(time.RFC3339)
		rec := state.AgentStateRecord{
			AgentID:          agent.AgentID,
			AgentType:        agent.AgentType,
			SessionID:        agent.SessionID,
			State:            string(agent.SM.Current()),
			StartedAt:        agent.StartedAt.UTC().Format(time.RFC3339),
			StoppedAt:        &stoppedAtStr,
			RecoveryAttempts: agent.Recovery.Attempts(),
		}
		if err := t.store.UpsertAgentState(rec); err != nil {
			return fmt.Errorf("tracker: HandleStop: DB 保存失敗: %w", err)
		}
	}

	return nil
}

// restoreFromRecord は DB レコードからインメモリ TrackedAgent を再構成する。
// 現在の状態を StartedAt → 現在の State まで最短経路で StateMachine に反映する。
func (t *AgentTracker) restoreFromRecord(rec *state.AgentStateRecord) (*TrackedAgent, error) {
	sm := NewStateMachine()

	// DB の state を元に StateMachine を進める
	// 正常系パス: SPAWNING → RUNNING（最小限。REVIEWING 以降は HandleStop で進める）
	currentState := AgentState(rec.State)
	if currentState != StateSpawning {
		if err := sm.Transition(StateRunning, "restored from DB"); err != nil {
			return nil, fmt.Errorf("restore: SPAWNING → RUNNING 失敗: %w", err)
		}
	}

	// RUNNING 以降の状態を反映する（REVIEWING 等）
	if currentState != StateSpawning && currentState != StateRunning {
		// 既に REVIEWING 以降であれば RUNNING → REVIEWING を試みる
		if sm.CanTransition(currentState) {
			if err := sm.Transition(currentState, "restored from DB"); err != nil {
				// 遷移できない状態でも続行（最善努力）
				_ = err
			}
		}
	}

	startedAt := t.now()
	if rec.StartedAt != "" {
		if parsed, err := time.Parse(time.RFC3339, rec.StartedAt); err == nil {
			startedAt = parsed
		}
	}

	agent := &TrackedAgent{
		AgentID:   rec.AgentID,
		AgentType: rec.AgentType,
		SessionID: rec.SessionID,
		SM:        sm,
		StartedAt: startedAt,
	}
	agent.Recovery = NewRecoveryManager(sm)

	return agent, nil
}

// Status は全追跡中エージェントの状態スナップショットを返す。
// 返されるスライスは agent_id の昇順ではなくマップ走査順になる。
func (t *AgentTracker) Status() []AgentStatus {
	t.mu.RLock()
	defer t.mu.RUnlock()

	now := t.now()
	result := make([]AgentStatus, 0, len(t.agents))
	for _, agent := range t.agents {
		result = append(result, AgentStatus{
			AgentID:          agent.AgentID,
			AgentType:        agent.AgentType,
			SessionID:        agent.SessionID,
			State:            agent.SM.Current(),
			Duration:         now.Sub(agent.StartedAt),
			RecoveryAttempts: agent.Recovery.Attempts(),
		})
	}
	return result
}

// Get は指定した agent_id の TrackedAgent を返す。
// 存在しない場合は nil を返す。
func (t *AgentTracker) Get(agentID string) *TrackedAgent {
	t.mu.RLock()
	defer t.mu.RUnlock()
	return t.agents[agentID]
}

// ============================================================
// 内部ヘルパー
// ============================================================

// extractAgentID は HookInput から agent_id を取り出す。
// CC v2.1.69+ では tool_input["agent_id"] として渡される。
func extractAgentID(input hookproto.HookInput) string {
	if input.ToolInput == nil {
		return ""
	}
	if v, ok := input.ToolInput["agent_id"]; ok {
		if s, ok := v.(string); ok {
			return s
		}
	}
	return ""
}

// extractAgentType は HookInput から agent_type を取り出す。
// CC v2.1.69+ では tool_input["agent_type"] として渡される。
func extractAgentType(input hookproto.HookInput) string {
	if input.ToolInput == nil {
		return ""
	}
	if v, ok := input.ToolInput["agent_type"]; ok {
		if s, ok := v.(string); ok {
			return s
		}
	}
	return ""
}
