// Package lifecycle provides the agent lifecycle state machine.
//
// Declaratively implements all transition rules defined in SPEC.md §8.
// Happy path: SPAWNING → RUNNING → REVIEWING → APPROVED → COMMITTED
// Error paths include: FAILED / CANCELLED / STALE / RECOVERING / ABORTED.
package lifecycle

import (
	"fmt"
	"sync"
)

// AgentState is a string type representing the state of an agent.
type AgentState string

const (
	// StateSpawning indicates the agent is starting up.
	StateSpawning AgentState = "SPAWNING"
	// StateRunning indicates the agent is executing a task.
	StateRunning AgentState = "RUNNING"
	// StateReviewing indicates the agent is in the review phase.
	StateReviewing AgentState = "REVIEWING"
	// StateApproved indicates the review has been approved.
	StateApproved AgentState = "APPROVED"
	// StateCommitted is the terminal state indicating a commit has completed.
	StateCommitted AgentState = "COMMITTED"
	// StateFailed indicates failure due to an error.
	StateFailed AgentState = "FAILED"
	// StateCancelled is the terminal state indicating the agent was stopped by user interruption.
	StateCancelled AgentState = "CANCELLED"
	// StateStale indicates the agent was automatically stopped after exceeding 24 hours.
	StateStale AgentState = "STALE"
	// StateRecovering indicates recovery processing is in progress.
	StateRecovering AgentState = "RECOVERING"
	// StateAborted is the terminal state indicating human intervention is required due to recovery failure.
	StateAborted AgentState = "ABORTED"
)

// terminalStates is the set of terminal states from which no transition is possible.
var terminalStates = map[AgentState]struct{}{
	StateCommitted: {},
	StateAborted:   {},
	StateCancelled: {},
}

// IsTerminal returns whether the given state is a terminal state.
// COMMITTED / ABORTED / CANCELLED are the terminal states.
func IsTerminal(state AgentState) bool {
	_, ok := terminalStates[state]
	return ok
}

// transitionKey is the (From, To) pair used as a key in the transition table.
type transitionKey struct {
	From AgentState
	To   AgentState
}

// validTransitions declaratively defines all permitted transition rules.
// Covers both happy-path and error-path cases from SPEC.md §8.
var validTransitions = map[transitionKey]struct{}{
	// Happy path
	{StateSpawning, StateRunning}:   {}, // startup succeeded
	{StateRunning, StateReviewing}:  {}, // execution complete → review
	{StateReviewing, StateApproved}: {}, // review approved
	{StateApproved, StateCommitted}: {}, // commit complete

	// Error path: FAILED
	{StateSpawning, StateFailed}:  {}, // startup failed
	{StateRunning, StateFailed}:   {}, // runtime error / 3 retries exceeded
	{StateReviewing, StateFailed}: {}, // error during review

	// Error path: CANCELLED
	{StateRunning, StateCancelled}:   {}, // user interruption (Ctrl+C)
	{StateReviewing, StateCancelled}: {}, // user interruption

	// Error path: STALE (24h exceeded)
	{StateRunning, StateStale}:   {}, // 24h exceeded during execution
	{StateReviewing, StateStale}: {}, // 24h exceeded during review

	// Error path: RECOVERING
	{StateFailed, StateRecovering}: {}, // recovery started

	// Error path: recovery outcome
	{StateRecovering, StateRunning}: {}, // recovery succeeded → re-execute
	{StateRecovering, StateAborted}: {}, // recovery failed → human intervention required
}

// Transition is a struct that records a single state transition.
type Transition struct {
	// From is the source state of the transition.
	From AgentState
	// To is the destination state of the transition.
	To AgentState
	// Trigger is a description of the event that caused the transition.
	Trigger string
}

// StateMachine is the agent lifecycle state machine.
// Goroutine-safe.
type StateMachine struct {
	mu      sync.RWMutex
	current AgentState
	history []Transition
}

// NewStateMachine returns a new StateMachine starting in the SPAWNING state.
func NewStateMachine() *StateMachine {
	return &StateMachine{
		current: StateSpawning,
		history: make([]Transition, 0),
	}
}

// Current returns the current state.
func (sm *StateMachine) Current() AgentState {
	sm.mu.RLock()
	defer sm.mu.RUnlock()
	return sm.current
}

// CanTransition returns whether a transition from the current state to the given state is permitted.
func (sm *StateMachine) CanTransition(to AgentState) bool {
	sm.mu.RLock()
	defer sm.mu.RUnlock()
	return sm.canTransitionLocked(to)
}

// canTransitionLocked is an internal method that checks whether a transition is possible,
// assuming the lock is already held.
func (sm *StateMachine) canTransitionLocked(to AgentState) bool {
	key := transitionKey{From: sm.current, To: to}
	_, ok := validTransitions[key]
	return ok
}

// Transition transitions from the current state to the given state.
// Returns an error if the transition is not permitted.
// trigger is a description of the event that caused the transition (for logging/debugging).
func (sm *StateMachine) Transition(to AgentState, trigger string) error {
	sm.mu.Lock()
	defer sm.mu.Unlock()

	if !sm.canTransitionLocked(to) {
		return fmt.Errorf(
			"lifecycle: invalid transition %s → %s (trigger: %q)",
			sm.current, to, trigger,
		)
	}

	t := Transition{
		From:    sm.current,
		To:      to,
		Trigger: trigger,
	}
	sm.history = append(sm.history, t)
	sm.current = to
	return nil
}

// History returns a copy of the recorded transition history.
// Modifications to the returned slice by the caller do not affect internal state.
func (sm *StateMachine) History() []Transition {
	sm.mu.RLock()
	defer sm.mu.RUnlock()

	result := make([]Transition, len(sm.history))
	copy(result, sm.history)
	return result
}
