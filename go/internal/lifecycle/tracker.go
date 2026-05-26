// Package lifecycle provides the agent lifecycle state machine.
package lifecycle

import (
	"fmt"
	"sync"
	"time"

	"github.com/Chachamaru127/claude-code-harness/go/internal/state"
	"github.com/Chachamaru127/claude-code-harness/go/pkg/hookproto"
)

// TrackedAgent represents an individual agent being tracked.
type TrackedAgent struct {
	// AgentID is the agent identifier (agent_id assigned by CC).
	AgentID string
	// AgentType is the agent type (worker / reviewer / scaffolder, etc.).
	AgentType string
	// SessionID is the identifier of the session the agent belongs to.
	SessionID string
	// SM is the agent lifecycle state machine.
	SM *StateMachine
	// Recovery is the agent recovery manager.
	Recovery *RecoveryManager
	// StartedAt is the time the agent started.
	StartedAt time.Time
}

// AgentStatus is a state snapshot of a single agent returned by AgentTracker.Status().
type AgentStatus struct {
	// AgentID is the agent identifier.
	AgentID string
	// AgentType is the agent type.
	AgentType string
	// SessionID is the identifier of the parent session.
	SessionID string
	// State is the current state.
	State AgentState
	// Duration is the elapsed time since the agent started.
	Duration time.Duration
	// RecoveryAttempts is the number of recovery attempts made.
	RecoveryAttempts int
}

// AgentTracker receives SubagentStart/Stop events and manages
// the lifecycle state of agents.
// Goroutine-safe. Persists state to SQLite if a store is available.
type AgentTracker struct {
	mu     sync.RWMutex
	agents map[string]*TrackedAgent // agent_id → TrackedAgent
	store  *state.HarnessStore      // SQLite persistence (nil = in-memory only)
	now    func() time.Time         // injectable time function for tests
}

// NewAgentTracker returns a new AgentTracker.
// If store is nil, state is managed in-memory only (for testing).
func NewAgentTracker(store *state.HarnessStore) *AgentTracker {
	return &AgentTracker{
		agents: make(map[string]*TrackedAgent),
		store:  store,
		now:    time.Now,
	}
}

// HandleStart processes a SubagentStart event.
// Registers a new TrackedAgent and transitions it from SPAWNING → RUNNING.
// Does nothing if agent_id is already registered (idempotent).
func (t *AgentTracker) HandleStart(input hookproto.HookInput) error {
	agentID := extractAgentID(input)
	agentType := extractAgentType(input)
	sessionID := input.SessionID

	if agentID == "" {
		return fmt.Errorf("tracker: HandleStart: agent_id is empty")
	}

	t.mu.Lock()
	defer t.mu.Unlock()

	// Idempotent: skip if already registered
	if _, exists := t.agents[agentID]; exists {
		return nil
	}

	sm := NewStateMachine()
	// Immediately transition SPAWNING → RUNNING (SubagentStart = startup complete notification)
	if err := sm.Transition(StateRunning, "SubagentStart"); err != nil {
		return fmt.Errorf("tracker: HandleStart: state transition failed: %w", err)
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

	// SQLite persistence
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
			// Persistence failure is treated as an error and processing stops (fatal)
			return fmt.Errorf("tracker: HandleStart: DB save failed: %w", err)
		}
	}

	return nil
}

// HandleStop processes a SubagentStop event.
// Transitions the agent from RUNNING → REVIEWING and records the stop time.
// If not registered in memory but present in SQLite, updates state from the DB.
// Returns an error if agent_id is not registered and does not exist in the DB.
func (t *AgentTracker) HandleStop(input hookproto.HookInput) error {
	agentID := extractAgentID(input)

	if agentID == "" {
		return fmt.Errorf("tracker: HandleStop: agent_id is empty")
	}

	t.mu.Lock()
	defer t.mu.Unlock()

	agent, exists := t.agents[agentID]
	if !exists {
		// Not registered in memory: attempt to restore from DB
		if t.store != nil {
			rec, err := t.store.GetAgentState(agentID)
			if err != nil {
				return fmt.Errorf("tracker: HandleStop: DB lookup failed: %w", err)
			}
			if rec != nil {
				// Reconstruct in-memory AgentTracker from DB record
				restored, restoreErr := t.restoreFromRecord(rec)
				if restoreErr != nil {
					return fmt.Errorf("tracker: HandleStop: state restore failed: %w", restoreErr)
				}
				t.agents[agentID] = restored
				agent = restored
				exists = true
			}
		}
		if !exists {
			return fmt.Errorf("tracker: HandleStop: unregistered agent_id=%q", agentID)
		}
	}

	// Transition RUNNING → REVIEWING (SubagentStop = task complete, awaiting review)
	// Skip the transition if already in REVIEWING or a later state
	if agent.SM.CanTransition(StateReviewing) {
		if err := agent.SM.Transition(StateReviewing, "SubagentStop"); err != nil {
			return fmt.Errorf("tracker: HandleStop: state transition failed: %w", err)
		}
	}

	// SQLite persistence
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
			return fmt.Errorf("tracker: HandleStop: DB save failed: %w", err)
		}
	}

	return nil
}

// restoreFromRecord reconstructs an in-memory TrackedAgent from a DB record.
// Advances the StateMachine from StartedAt to the current State via the shortest path.
func (t *AgentTracker) restoreFromRecord(rec *state.AgentStateRecord) (*TrackedAgent, error) {
	sm := NewStateMachine()

	// Advance the StateMachine based on the DB state.
	// Happy path: SPAWNING → RUNNING (minimal; REVIEWING and beyond are advanced by HandleStop)
	currentState := AgentState(rec.State)
	if currentState != StateSpawning {
		if err := sm.Transition(StateRunning, "restored from DB"); err != nil {
			return nil, fmt.Errorf("restore: SPAWNING → RUNNING failed: %w", err)
		}
	}

	// Reflect states beyond RUNNING (e.g. REVIEWING)
	if currentState != StateSpawning && currentState != StateRunning {
		// If already at REVIEWING or beyond, attempt RUNNING → REVIEWING
		if sm.CanTransition(currentState) {
			if err := sm.Transition(currentState, "restored from DB"); err != nil {
				// Continue even if the transition cannot be made (best-effort)
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

// Status returns a state snapshot of all tracked agents.
// The returned slice is in map iteration order, not sorted by agent_id.
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

// Get returns the TrackedAgent for the given agent_id.
// Returns nil if not found.
func (t *AgentTracker) Get(agentID string) *TrackedAgent {
	t.mu.RLock()
	defer t.mu.RUnlock()
	return t.agents[agentID]
}

// ============================================================
// Internal helpers
// ============================================================

// extractAgentID extracts agent_id from HookInput.
// In CC v2.1.69+, it is passed as tool_input["agent_id"].
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

// extractAgentType extracts agent_type from HookInput.
// In CC v2.1.69+, it is passed as tool_input["agent_type"].
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
