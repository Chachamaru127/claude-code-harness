// Package lifecycle provides the agent lifecycle state machine.
package lifecycle

import "fmt"

// RecoveryLevel is the type representing the recovery stage.
// Corresponds to the 4 stages defined in SPEC.md §8.
type RecoveryLevel int

const (
	// SelfHeal is stage 1: self-healing. Error analysis → auto-fix → retry.
	SelfHeal RecoveryLevel = iota
	// PeerHeal is stage 2: peer healing. Delegates the task to another Worker.
	PeerHeal
	// LeadEscalation is stage 3: commander intervention. Escalates to the Lead session.
	LeadEscalation
	// Abort is stage 4: stop. Transitions to ABORTED state and notifies the user.
	Abort
)

// String returns the string representation of RecoveryLevel.
func (l RecoveryLevel) String() string {
	switch l {
	case SelfHeal:
		return "SelfHeal"
	case PeerHeal:
		return "PeerHeal"
	case LeadEscalation:
		return "LeadEscalation"
	case Abort:
		return "Abort"
	default:
		return fmt.Sprintf("RecoveryLevel(%d)", int(l))
	}
}

// RecoveryAction represents the recovery stage and the action to take.
type RecoveryAction struct {
	// Level is the current recovery stage.
	Level RecoveryLevel
	// Retry is true when the same task should be retried after self-healing.
	Retry bool
	// DelegateToWorker is true when the task should be delegated to another Worker.
	DelegateToWorker bool
	// EscalateToLead is true when escalation to the Lead session is needed.
	EscalateToLead bool
	// Stop is true when recovery is impossible and execution should stop.
	Stop bool
	// Error is the error that triggered recovery (informational).
	Error error
}

// RecoveryManager is a struct that manages the 4-stage recovery logic.
// Works with StateMachine to control transitions to RECOVERING / ABORTED states.
type RecoveryManager struct {
	// sm is a reference to the lifecycle state machine.
	sm *StateMachine
	// attempts is the cumulative number of times HandleFailure has been called (0-based).
	attempts int
	// maxSelfHeal is the maximum number of self-healing attempts. Default 3.
	maxSelfHeal int
	// maxPeerHeal is the maximum number of peer-healing attempts. Default 1.
	maxPeerHeal int
}

// NewRecoveryManager creates a RecoveryManager with default settings.
// maxSelfHeal=3, maxPeerHeal=1 are used as initial values.
func NewRecoveryManager(sm *StateMachine) *RecoveryManager {
	return &RecoveryManager{
		sm:          sm,
		attempts:    0,
		maxSelfHeal: 3,
		maxPeerHeal: 1,
	}
}

// HandleFailure receives a failure and returns a recovery action based on the current attempt count.
// Stage determination rules (attempts is 0-based):
//
//	0, 1, 2 (attempts < maxSelfHeal=3)              → SelfHeal (Retry=true)
//	3       (attempts < maxSelfHeal+maxPeerHeal=4)  → PeerHeal (DelegateToWorker=true)
//	4       (attempts < maxSelfHeal+maxPeerHeal+1=5)→ LeadEscalation (EscalateToLead=true)
//	5+      (otherwise)                             → Abort (Stop=true)
//
// If StateMachine is in FAILED state, it transitions to RECOVERING.
// At the Abort stage, it transitions from RECOVERING → ABORTED.
func (rm *RecoveryManager) HandleFailure(err error) RecoveryAction {
	// If StateMachine is FAILED, attempt transition to RECOVERING
	if rm.sm.Current() == StateFailed {
		_ = rm.sm.Transition(StateRecovering, fmt.Sprintf("recovery attempt %d: %v", rm.attempts+1, err))
	}

	action := rm.determineAction(err)
	rm.attempts++

	// At Abort stage, transition StateMachine to ABORTED
	if action.Stop && rm.sm.Current() == StateRecovering {
		_ = rm.sm.Transition(StateAborted, fmt.Sprintf("all recovery attempts exhausted: %v", err))
	}

	return action
}

// determineAction is an internal method that determines the recovery action based on the current attempts value.
// Expected to be called before incrementing attempts.
func (rm *RecoveryManager) determineAction(err error) RecoveryAction {
	switch {
	case rm.attempts < rm.maxSelfHeal:
		// Stage 1: self-healing (SelfHeal)
		return RecoveryAction{
			Level: SelfHeal,
			Retry: true,
			Error: err,
		}
	case rm.attempts < rm.maxSelfHeal+rm.maxPeerHeal:
		// Stage 2: peer healing (PeerHeal)
		return RecoveryAction{
			Level:            PeerHeal,
			DelegateToWorker: true,
			Error:            err,
		}
	case rm.attempts < rm.maxSelfHeal+rm.maxPeerHeal+1:
		// Stage 3: commander intervention (LeadEscalation)
		return RecoveryAction{
			Level:          LeadEscalation,
			EscalateToLead: true,
			Error:          err,
		}
	default:
		// Stage 4: stop (Abort)
		return RecoveryAction{
			Level: Abort,
			Stop:  true,
			Error: err,
		}
	}
}

// Attempts returns the current number of recovery attempts.
func (rm *RecoveryManager) Attempts() int {
	return rm.attempts
}

// Reset resets the recovery attempt count to zero.
// Call after a task completes successfully.
func (rm *RecoveryManager) Reset() {
	rm.attempts = 0
}
