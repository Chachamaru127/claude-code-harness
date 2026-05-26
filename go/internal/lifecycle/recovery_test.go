package lifecycle

import (
	"errors"
	"testing"
)

// errTest is a generic error for tests.
var errTest = errors.New("test failure")

// TestSelfHealFirst3Attempts verifies that self-healing returns
// SelfHeal + Retry=true for 3 attempts (attempts 0, 1, 2).
func TestSelfHealFirst3Attempts(t *testing.T) {
	t.Parallel()

	sm := newRecoveringStateMachine()
	rm := NewRecoveryManager(sm)

	for i := range 3 {
		action := rm.HandleFailure(errTest)
		if action.Level != SelfHeal {
			t.Errorf("attempt %d: Level = %v, want SelfHeal", i+1, action.Level)
		}
		if !action.Retry {
			t.Errorf("attempt %d: Retry = false, want true", i+1)
		}
		if action.DelegateToWorker || action.EscalateToLead || action.Stop {
			t.Errorf("attempt %d: unexpected flags set: DelegateToWorker=%v EscalateToLead=%v Stop=%v",
				i+1, action.DelegateToWorker, action.EscalateToLead, action.Stop)
		}
		if action.Error == nil {
			t.Errorf("attempt %d: Error is nil, want non-nil", i+1)
		}
		// Reset StateMachine to FAILED for the next HandleFailure call
		if i < 2 {
			resetToFailed(sm)
		}
	}
}

// TestPeerHealAt4thAttempt verifies that PeerHeal is selected on the 4th attempt (attempts=3).
func TestPeerHealAt4thAttempt(t *testing.T) {
	t.Parallel()

	sm := newRecoveringStateMachine()
	rm := NewRecoveryManager(sm)

	// Attempts 1-3: consume SelfHeal
	for i := range 3 {
		rm.HandleFailure(errTest)
		if i < 2 {
			resetToFailed(sm)
		}
	}

	// 4th attempt: should be PeerHeal
	resetToFailed(sm)
	action := rm.HandleFailure(errTest)

	if action.Level != PeerHeal {
		t.Errorf("4th attempt: Level = %v, want PeerHeal", action.Level)
	}
	if !action.DelegateToWorker {
		t.Errorf("4th attempt: DelegateToWorker = false, want true")
	}
	if action.Retry || action.EscalateToLead || action.Stop {
		t.Errorf("4th attempt: unexpected flags: Retry=%v EscalateToLead=%v Stop=%v",
			action.Retry, action.EscalateToLead, action.Stop)
	}
}

// TestLeadEscalationAfterPeerHealFailure verifies that LeadEscalation
// is selected after PeerHeal failure (5th attempt = attempts=4).
func TestLeadEscalationAfterPeerHealFailure(t *testing.T) {
	t.Parallel()

	sm := newRecoveringStateMachine()
	rm := NewRecoveryManager(sm)

	// Attempts 1-4: consume SelfHeal × 3 + PeerHeal × 1
	for i := range 4 {
		rm.HandleFailure(errTest)
		if i < 3 {
			resetToFailed(sm)
		}
	}

	// 5th attempt: should be LeadEscalation
	resetToFailed(sm)
	action := rm.HandleFailure(errTest)

	if action.Level != LeadEscalation {
		t.Errorf("5th attempt: Level = %v, want LeadEscalation", action.Level)
	}
	if !action.EscalateToLead {
		t.Errorf("5th attempt: EscalateToLead = false, want true")
	}
	if action.Retry || action.DelegateToWorker || action.Stop {
		t.Errorf("5th attempt: unexpected flags: Retry=%v DelegateToWorker=%v Stop=%v",
			action.Retry, action.DelegateToWorker, action.Stop)
	}
}

// TestAbortAtFinalStage verifies that Abort is returned at the final stage (6th attempt and beyond).
func TestAbortAtFinalStage(t *testing.T) {
	t.Parallel()

	sm := newRecoveringStateMachine()
	rm := NewRecoveryManager(sm)

	// Consume attempts 1-5
	for i := range 5 {
		rm.HandleFailure(errTest)
		if i < 4 {
			resetToFailed(sm)
		}
	}

	// 6th attempt: should be Abort
	resetToFailed(sm)
	action := rm.HandleFailure(errTest)

	if action.Level != Abort {
		t.Errorf("6th attempt: Level = %v, want Abort", action.Level)
	}
	if !action.Stop {
		t.Errorf("6th attempt: Stop = false, want true")
	}
	if action.Retry || action.DelegateToWorker || action.EscalateToLead {
		t.Errorf("6th attempt: unexpected flags: Retry=%v DelegateToWorker=%v EscalateToLead=%v",
			action.Retry, action.DelegateToWorker, action.EscalateToLead)
	}
}

// TestStateMachineTransitionOnFailure verifies that HandleFailure
// transitions StateMachine from FAILED → RECOVERING → (ABORTED if needed).
func TestStateMachineTransitionOnFailure(t *testing.T) {
	t.Parallel()

	t.Run("TransitionsToRECOVERINGAtSelfHealStage", func(t *testing.T) {
		t.Parallel()

		sm := newFailedStateMachine()
		rm := NewRecoveryManager(sm)

		rm.HandleFailure(errTest)

		if got := sm.Current(); got != StateRecovering {
			t.Errorf("StateMachine.Current() = %v, want RECOVERING", got)
		}
	})

	t.Run("TransitionsToABORTEDAtAbortStage", func(t *testing.T) {
		t.Parallel()

		sm := newRecoveringStateMachine()
		rm := NewRecoveryManager(sm)

		// Consume attempts 1-5 to reach attempts=5
		for i := range 5 {
			rm.HandleFailure(errTest)
			if i < 4 {
				resetToFailed(sm)
			}
		}

		// 6th attempt: Abort → transition to ABORTED
		resetToFailed(sm)
		action := rm.HandleFailure(errTest)

		if action.Level != Abort {
			t.Fatalf("expected Abort, got %v", action.Level)
		}
		if got := sm.Current(); got != StateAborted {
			t.Errorf("StateMachine.Current() = %v, want ABORTED", got)
		}
	})
}

// TestAttemptsCounter verifies that Attempts() accurately returns the call count.
func TestAttemptsCounter(t *testing.T) {
	t.Parallel()

	sm := newRecoveringStateMachine()
	rm := NewRecoveryManager(sm)

	if got := rm.Attempts(); got != 0 {
		t.Errorf("initial Attempts() = %d, want 0", got)
	}

	for want := 1; want <= 3; want++ {
		rm.HandleFailure(errTest)
		if got := rm.Attempts(); got != want {
			t.Errorf("after %d HandleFailure calls: Attempts() = %d, want %d", want, got, want)
		}
		resetToFailed(sm)
	}
}

// TestReset verifies that Attempts returns 0 after Reset().
func TestReset(t *testing.T) {
	t.Parallel()

	sm := newRecoveringStateMachine()
	rm := NewRecoveryManager(sm)

	rm.HandleFailure(errTest)
	rm.HandleFailure(errTest)

	rm.Reset()

	if got := rm.Attempts(); got != 0 {
		t.Errorf("after Reset: Attempts() = %d, want 0", got)
	}
}

// TestErrorPropagation verifies that the error passed to HandleFailure
// is correctly propagated to RecoveryAction.Error.
func TestErrorPropagation(t *testing.T) {
	t.Parallel()

	sm := newFailedStateMachine()
	rm := NewRecoveryManager(sm)

	specificErr := errors.New("specific error for propagation test")
	action := rm.HandleFailure(specificErr)

	if !errors.Is(action.Error, specificErr) {
		t.Errorf("action.Error = %v, want %v", action.Error, specificErr)
	}
}

// TestRecoveryLevelString verifies that RecoveryLevel.String() returns the correct string.
func TestRecoveryLevelString(t *testing.T) {
	t.Parallel()

	cases := []struct {
		level RecoveryLevel
		want  string
	}{
		{SelfHeal, "SelfHeal"},
		{PeerHeal, "PeerHeal"},
		{LeadEscalation, "LeadEscalation"},
		{Abort, "Abort"},
	}

	for _, tc := range cases {
		if got := tc.level.String(); got != tc.want {
			t.Errorf("RecoveryLevel(%d).String() = %q, want %q", int(tc.level), got, tc.want)
		}
	}
}

// ---- Helper functions --------------------------------------------------------

// newFailedStateMachine returns a StateMachine in the FAILED state.
// It is created by transitioning through SPAWNING → RUNNING → FAILED.
func newFailedStateMachine() *StateMachine {
	sm := NewStateMachine()
	must(sm.Transition(StateRunning, "test: start"))
	must(sm.Transition(StateFailed, "test: fail"))
	return sm
}

// newRecoveringStateMachine returns a StateMachine in the RECOVERING state.
// It is created by transitioning through SPAWNING → RUNNING → FAILED → RECOVERING.
func newRecoveringStateMachine() *StateMachine {
	sm := newFailedStateMachine()
	must(sm.Transition(StateRecovering, "test: start recovery"))
	return sm
}

// resetToFailed resets a StateMachine in the RECOVERING state to FAILED
// by transitioning through RUNNING → FAILED.
// Used to simulate multiple failures since HandleFailure performs FAILED → RECOVERING.
// Uses the RECOVERING → RUNNING → FAILED transition path.
func resetToFailed(sm *StateMachine) {
	must(sm.Transition(StateRunning, "test: retry"))
	must(sm.Transition(StateFailed, "test: fail again"))
}

// must panics if err is non-nil. Test helper.
func must(err error) {
	if err != nil {
		panic(err)
	}
}
