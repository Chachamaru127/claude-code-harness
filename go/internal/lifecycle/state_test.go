package lifecycle_test

import (
	"testing"

	"github.com/Chachamaru127/claude-code-harness/go/internal/lifecycle"
)

// ============================================================
// IsTerminal
// ============================================================

func TestIsTerminal_CommittedIsTerminal(t *testing.T) {
	if !lifecycle.IsTerminal(lifecycle.StateCommitted) {
		t.Error("COMMITTED should be a terminal state")
	}
}

func TestIsTerminal_AbortedIsTerminal(t *testing.T) {
	if !lifecycle.IsTerminal(lifecycle.StateAborted) {
		t.Error("ABORTED should be a terminal state")
	}
}

func TestIsTerminal_CancelledIsTerminal(t *testing.T) {
	if !lifecycle.IsTerminal(lifecycle.StateCancelled) {
		t.Error("CANCELLED should be a terminal state")
	}
}

func TestIsTerminal_NonTerminalStates(t *testing.T) {
	nonTerminal := []lifecycle.AgentState{
		lifecycle.StateSpawning,
		lifecycle.StateRunning,
		lifecycle.StateReviewing,
		lifecycle.StateApproved,
		lifecycle.StateFailed,
		lifecycle.StateStale,
		lifecycle.StateRecovering,
	}
	for _, s := range nonTerminal {
		if lifecycle.IsTerminal(s) {
			t.Errorf("state %s must not be a terminal state", s)
		}
	}
}

// ============================================================
// NewStateMachine / Current
// ============================================================

func TestNewStateMachine_StartsAtSpawning(t *testing.T) {
	sm := lifecycle.NewStateMachine()
	if sm.Current() != lifecycle.StateSpawning {
		t.Errorf("initial state should be SPAWNING but was %s", sm.Current())
	}
}

func TestNewStateMachine_HistoryIsEmpty(t *testing.T) {
	sm := lifecycle.NewStateMachine()
	if len(sm.History()) != 0 {
		t.Errorf("history should be empty in the initial state but had %d entries", len(sm.History()))
	}
}

// ============================================================
// Full happy-path transition
// ============================================================

func TestHappyPath_FullTransition(t *testing.T) {
	sm := lifecycle.NewStateMachine()

	steps := []struct {
		to      lifecycle.AgentState
		trigger string
	}{
		{lifecycle.StateRunning, "agent started"},
		{lifecycle.StateReviewing, "task completed"},
		{lifecycle.StateApproved, "review passed"},
		{lifecycle.StateCommitted, "commit succeeded"},
	}

	for _, step := range steps {
		if err := sm.Transition(step.to, step.trigger); err != nil {
			t.Fatalf("transition → %s failed: %v", step.to, err)
		}
		if sm.Current() != step.to {
			t.Errorf("state after transition should be %s but was %s", step.to, sm.Current())
		}
	}
}

// ============================================================
// Error-path transitions
// ============================================================

func TestAbnormal_SpawningToFailed(t *testing.T) {
	sm := lifecycle.NewStateMachine()
	if err := sm.Transition(lifecycle.StateFailed, "spawn error"); err != nil {
		t.Errorf("SPAWNING → FAILED should be permitted: %v", err)
	}
}

func TestAbnormal_RunningToFailed(t *testing.T) {
	sm := lifecycle.NewStateMachine()
	_ = sm.Transition(lifecycle.StateRunning, "started")
	if err := sm.Transition(lifecycle.StateFailed, "retry exceeded"); err != nil {
		t.Errorf("RUNNING → FAILED should be permitted: %v", err)
	}
}

func TestAbnormal_RunningToCancelled(t *testing.T) {
	sm := lifecycle.NewStateMachine()
	_ = sm.Transition(lifecycle.StateRunning, "started")
	if err := sm.Transition(lifecycle.StateCancelled, "user interrupt"); err != nil {
		t.Errorf("RUNNING → CANCELLED should be permitted: %v", err)
	}
}

func TestAbnormal_ReviewingToFailed(t *testing.T) {
	sm := lifecycle.NewStateMachine()
	_ = sm.Transition(lifecycle.StateRunning, "started")
	_ = sm.Transition(lifecycle.StateReviewing, "task done")
	if err := sm.Transition(lifecycle.StateFailed, "review error"); err != nil {
		t.Errorf("REVIEWING → FAILED should be permitted: %v", err)
	}
}

func TestAbnormal_ReviewingToCancelled(t *testing.T) {
	sm := lifecycle.NewStateMachine()
	_ = sm.Transition(lifecycle.StateRunning, "started")
	_ = sm.Transition(lifecycle.StateReviewing, "task done")
	if err := sm.Transition(lifecycle.StateCancelled, "user interrupt"); err != nil {
		t.Errorf("REVIEWING → CANCELLED should be permitted: %v", err)
	}
}

func TestAbnormal_RunningToStale(t *testing.T) {
	sm := lifecycle.NewStateMachine()
	_ = sm.Transition(lifecycle.StateRunning, "started")
	if err := sm.Transition(lifecycle.StateStale, "24h exceeded"); err != nil {
		t.Errorf("RUNNING → STALE should be permitted: %v", err)
	}
}

func TestAbnormal_ReviewingToStale(t *testing.T) {
	sm := lifecycle.NewStateMachine()
	_ = sm.Transition(lifecycle.StateRunning, "started")
	_ = sm.Transition(lifecycle.StateReviewing, "task done")
	if err := sm.Transition(lifecycle.StateStale, "24h exceeded"); err != nil {
		t.Errorf("REVIEWING → STALE should be permitted: %v", err)
	}
}

func TestAbnormal_FailedToRecovering(t *testing.T) {
	sm := lifecycle.NewStateMachine()
	_ = sm.Transition(lifecycle.StateFailed, "error")
	if err := sm.Transition(lifecycle.StateRecovering, "recovery started"); err != nil {
		t.Errorf("FAILED → RECOVERING should be permitted: %v", err)
	}
}

func TestAbnormal_RecoveringToRunning(t *testing.T) {
	sm := lifecycle.NewStateMachine()
	_ = sm.Transition(lifecycle.StateFailed, "error")
	_ = sm.Transition(lifecycle.StateRecovering, "recovery started")
	if err := sm.Transition(lifecycle.StateRunning, "recovery succeeded"); err != nil {
		t.Errorf("RECOVERING → RUNNING should be permitted: %v", err)
	}
}

func TestAbnormal_RecoveringToAborted(t *testing.T) {
	sm := lifecycle.NewStateMachine()
	_ = sm.Transition(lifecycle.StateFailed, "error")
	_ = sm.Transition(lifecycle.StateRecovering, "recovery started")
	if err := sm.Transition(lifecycle.StateAborted, "recovery failed"); err != nil {
		t.Errorf("RECOVERING → ABORTED should be permitted: %v", err)
	}
}

// ============================================================
// Invalid transitions
// ============================================================

func TestInvalidTransition_SpawningToCommitted(t *testing.T) {
	sm := lifecycle.NewStateMachine()
	err := sm.Transition(lifecycle.StateCommitted, "skip all")
	if err == nil {
		t.Error("SPAWNING → COMMITTED should be rejected but was permitted")
	}
}

func TestInvalidTransition_SpawningToReviewing(t *testing.T) {
	sm := lifecycle.NewStateMachine()
	err := sm.Transition(lifecycle.StateReviewing, "skip running")
	if err == nil {
		t.Error("SPAWNING → REVIEWING should be rejected but was permitted")
	}
}

func TestInvalidTransition_RunningToApproved(t *testing.T) {
	sm := lifecycle.NewStateMachine()
	_ = sm.Transition(lifecycle.StateRunning, "started")
	err := sm.Transition(lifecycle.StateApproved, "skip review")
	if err == nil {
		t.Error("RUNNING → APPROVED should be rejected but was permitted")
	}
}

func TestInvalidTransition_ApprovedToRunning(t *testing.T) {
	sm := lifecycle.NewStateMachine()
	_ = sm.Transition(lifecycle.StateRunning, "started")
	_ = sm.Transition(lifecycle.StateReviewing, "task done")
	_ = sm.Transition(lifecycle.StateApproved, "approved")
	err := sm.Transition(lifecycle.StateRunning, "go back")
	if err == nil {
		t.Error("APPROVED → RUNNING should be rejected but was permitted")
	}
}

// ============================================================
// All transitions from terminal states must fail
// ============================================================

func TestTerminalStates_AllTransitionsBlocked(t *testing.T) {
	allStates := []lifecycle.AgentState{
		lifecycle.StateSpawning,
		lifecycle.StateRunning,
		lifecycle.StateReviewing,
		lifecycle.StateApproved,
		lifecycle.StateCommitted,
		lifecycle.StateFailed,
		lifecycle.StateCancelled,
		lifecycle.StateStale,
		lifecycle.StateRecovering,
		lifecycle.StateAborted,
	}

	terminalList := []lifecycle.AgentState{
		lifecycle.StateCommitted,
		lifecycle.StateAborted,
		lifecycle.StateCancelled,
	}

	for _, terminal := range terminalList {
		for _, target := range allStates {
			sm := newSMAt(t, terminal)
			err := sm.Transition(target, "from terminal")
			if err == nil {
				t.Errorf("terminal state %s → %s should be rejected but was permitted", terminal, target)
			}
		}
	}
}

// newSMAt is a helper that returns a StateMachine at the given terminal state.
// Reaches COMMITTED / ABORTED / CANCELLED each via the shortest path.
func newSMAt(t *testing.T, state lifecycle.AgentState) *lifecycle.StateMachine {
	t.Helper()
	sm := lifecycle.NewStateMachine()

	var steps []struct {
		to      lifecycle.AgentState
		trigger string
	}

	switch state {
	case lifecycle.StateCommitted:
		steps = []struct {
			to      lifecycle.AgentState
			trigger string
		}{
			{lifecycle.StateRunning, "started"},
			{lifecycle.StateReviewing, "done"},
			{lifecycle.StateApproved, "approved"},
			{lifecycle.StateCommitted, "committed"},
		}
	case lifecycle.StateAborted:
		steps = []struct {
			to      lifecycle.AgentState
			trigger string
		}{
			{lifecycle.StateFailed, "error"},
			{lifecycle.StateRecovering, "recovering"},
			{lifecycle.StateAborted, "recovery failed"},
		}
	case lifecycle.StateCancelled:
		steps = []struct {
			to      lifecycle.AgentState
			trigger string
		}{
			{lifecycle.StateRunning, "started"},
			{lifecycle.StateCancelled, "user interrupt"},
		}
	default:
		t.Fatalf("newSMAt: %s is not a terminal state", state)
	}

	for _, step := range steps {
		if err := sm.Transition(step.to, step.trigger); err != nil {
			t.Fatalf("setup transition → %s failed: %v", step.to, err)
		}
	}
	return sm
}

// ============================================================
// Transition history
// ============================================================

func TestHistory_RecordsAllTransitions(t *testing.T) {
	sm := lifecycle.NewStateMachine()
	_ = sm.Transition(lifecycle.StateRunning, "trigger-1")
	_ = sm.Transition(lifecycle.StateReviewing, "trigger-2")

	history := sm.History()
	if len(history) != 2 {
		t.Fatalf("history should have 2 entries but had %d", len(history))
	}

	if history[0].From != lifecycle.StateSpawning || history[0].To != lifecycle.StateRunning {
		t.Errorf("history[0] differs from expected: %+v", history[0])
	}
	if history[0].Trigger != "trigger-1" {
		t.Errorf("history[0].Trigger should be %q but was %q", "trigger-1", history[0].Trigger)
	}
	if history[1].From != lifecycle.StateRunning || history[1].To != lifecycle.StateReviewing {
		t.Errorf("history[1] differs from expected: %+v", history[1])
	}
	if history[1].Trigger != "trigger-2" {
		t.Errorf("history[1].Trigger should be %q but was %q", "trigger-2", history[1].Trigger)
	}
}

func TestHistory_FailedTransitionNotRecorded(t *testing.T) {
	sm := lifecycle.NewStateMachine()
	_ = sm.Transition(lifecycle.StateRunning, "ok")
	// Invalid transition (expected to fail)
	_ = sm.Transition(lifecycle.StateCommitted, "invalid")

	history := sm.History()
	if len(history) != 1 {
		t.Errorf("invalid transition must not be recorded in history but had %d entries", len(history))
	}
}

func TestHistory_ReturnsIndependentCopy(t *testing.T) {
	sm := lifecycle.NewStateMachine()
	_ = sm.Transition(lifecycle.StateRunning, "started")

	h1 := sm.History()
	h1[0].Trigger = "TAMPERED"

	h2 := sm.History()
	if h2[0].Trigger == "TAMPERED" {
		t.Error("History() is returning a reference to the internal slice (should return a copy)")
	}
}

// ============================================================
// CanTransition
// ============================================================

func TestCanTransition_ValidTransitionReturnsTrue(t *testing.T) {
	sm := lifecycle.NewStateMachine()
	if !sm.CanTransition(lifecycle.StateRunning) {
		t.Error("transition from SPAWNING to RUNNING should be possible")
	}
}

func TestCanTransition_InvalidTransitionReturnsFalse(t *testing.T) {
	sm := lifecycle.NewStateMachine()
	if sm.CanTransition(lifecycle.StateCommitted) {
		t.Error("transition from SPAWNING to COMMITTED should not be possible")
	}
}
