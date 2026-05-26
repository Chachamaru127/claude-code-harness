// Package breezing provides goroutine orchestration for Breezing mode.
//
// The underlying infrastructure for Lead sessions to spawn Workers/Reviewers in parallel:
//   - Maximum parallelism control (semaphore pattern)
//   - Graceful shutdown via context.Context
//   - Automatic task dependency resolution
//   - Worktree lifecycle management
package breezing

import (
	"context"
	"fmt"
	"sync"
	"time"

	"github.com/Chachamaru127/claude-code-harness/go/internal/lifecycle"
	"github.com/Chachamaru127/claude-code-harness/go/internal/state"
)

// TaskStatus represents task progress within the orchestrator.
type TaskStatus string

const (
	TaskPending   TaskStatus = "pending"
	TaskRunning   TaskStatus = "running"
	TaskCompleted TaskStatus = "completed"
	TaskFailed    TaskStatus = "failed"
	TaskBlocked   TaskStatus = "blocked"
)

// Task represents a single task managed by the orchestrator.
type Task struct {
	// ID is the task identifier (e.g. "35.6.1").
	ID string
	// Description is a summary of the task.
	Description string
	// DependsOn is the list of task IDs this task depends on.
	DependsOn []string
	// AgentType is the type of agent to spawn ("worker" / "reviewer").
	AgentType string
	// WorktreePath is the path to the worktree (when a worktree is used).
	WorktreePath string
}

// TaskResult represents the result of a completed task.
type TaskResult struct {
	// TaskID is the ID of the completed task.
	TaskID string
	// AgentID is the ID of the CC agent that ran the task.
	AgentID string
	// CommitHash is the commit hash on success.
	CommitHash string
	// Err is the error on failure.
	Err error
	// Duration is the execution time.
	Duration time.Duration
}

// WorkerFunc is the callback invoked by the orchestrator for each task.
// Must return promptly when the context is cancelled.
type WorkerFunc func(ctx context.Context, task *Task) TaskResult

// ProgressFunc is the progress callback invoked when a task completes.
type ProgressFunc func(completed, total int, result TaskResult)

// Orchestrator manages parallel goroutine execution of Workers/Reviewers.
// Controls maximum parallelism via a semaphore pattern and achieves graceful shutdown with context.Context.
type Orchestrator struct {
	mu sync.Mutex

	// tasks is the set of all managed tasks.
	tasks []*Task
	// status is the current state of each task.
	status map[string]TaskStatus
	// results holds the results of completed tasks.
	results map[string]TaskResult

	// maxParallel is the maximum number of parallel executions.
	maxParallel int
	// tracker is for agent lifecycle tracking.
	// Expected to call tracker.HandleStart/HandleStop inside workerFn.
	// The Orchestrator itself does not manipulate tracker directly (delegates to workerFn).
	tracker *lifecycle.AgentTracker
	// store is the SQLite persistence store (may be nil).
	// Expected to be used for state persistence inside workerFn.
	store *state.HarnessStore

	// workerFn is the execution function for each task.
	workerFn WorkerFunc
	// progressFn is the progress callback (may be nil).
	progressFn ProgressFunc
}

// OrchestratorOption is a configuration option for the Orchestrator.
type OrchestratorOption func(*Orchestrator)

// WithMaxParallel sets the maximum parallelism.
// Values of 0 or less fall back to the default (3).
func WithMaxParallel(n int) OrchestratorOption {
	return func(o *Orchestrator) {
		if n > 0 {
			o.maxParallel = n
		}
	}
}

// WithTracker sets the AgentTracker.
func WithTracker(t *lifecycle.AgentTracker) OrchestratorOption {
	return func(o *Orchestrator) {
		o.tracker = t
	}
}

// WithStore sets the HarnessStore.
func WithStore(s *state.HarnessStore) OrchestratorOption {
	return func(o *Orchestrator) {
		o.store = s
	}
}

// WithProgressFunc sets the progress callback.
func WithProgressFunc(fn ProgressFunc) OrchestratorOption {
	return func(o *Orchestrator) {
		o.progressFn = fn
	}
}

// NewOrchestrator creates a new Orchestrator.
// workerFn is the execution function for each task (required).
func NewOrchestrator(workerFn WorkerFunc, opts ...OrchestratorOption) *Orchestrator {
	o := &Orchestrator{
		status:      make(map[string]TaskStatus),
		results:     make(map[string]TaskResult),
		maxParallel: 3,
		workerFn:    workerFn,
	}
	for _, opt := range opts {
		opt(o)
	}
	return o
}

// AddTask adds a task to the orchestrator.
// All tasks must be added before calling Run.
func (o *Orchestrator) AddTask(task *Task) {
	o.mu.Lock()
	defer o.mu.Unlock()
	o.tasks = append(o.tasks, task)
	o.status[task.ID] = TaskPending
}

// Run executes tasks in parallel respecting their dependency order.
// Waits until all tasks complete (successfully or with failure). Graceful shutdown on context cancel.
// The returned []TaskResult is in completion order.
func (o *Orchestrator) Run(ctx context.Context) ([]TaskResult, error) {
	o.mu.Lock()
	total := len(o.tasks)
	if total == 0 {
		o.mu.Unlock()
		return nil, nil
	}
	o.mu.Unlock()

	// semaphore: buffered channel to control maximum parallelism
	sem := make(chan struct{}, o.maxParallel)
	// resultCh: aggregates completion notifications
	resultCh := make(chan TaskResult, total)
	// wg: waits for all goroutines to finish
	var wg sync.WaitGroup

	// Periodically check for tasks with resolved dependencies and dispatch them
	ctx, cancel := context.WithCancel(ctx)
	defer cancel()

	// dispatch loop
	go func() {
		ticker := time.NewTicker(50 * time.Millisecond)
		defer ticker.Stop()

		for {
			select {
			case <-ctx.Done():
				return
			case <-ticker.C:
				o.dispatchReady(ctx, sem, resultCh, &wg)

				// Exit when all tasks have completed or failed
				o.mu.Lock()
				allDone := o.allTerminated()
				o.mu.Unlock()
				if allDone {
					return
				}
			}
		}
	}()

	// result aggregation loop
	var results []TaskResult
	completed := 0
	for completed < total {
		select {
		case result := <-resultCh:
			results = append(results, result)
			completed++
			if o.progressFn != nil {
				o.progressFn(completed, total, result)
			}
		case <-ctx.Done():
			// Cancelled: wait for all remaining task results
			wg.Wait()
			// drain remaining results
			for len(resultCh) > 0 {
				result := <-resultCh
				results = append(results, result)
			}
			return results, ctx.Err()
		}
	}

	wg.Wait()
	return results, nil
}

// Status returns the current status of the specified task.
func (o *Orchestrator) Status(taskID string) TaskStatus {
	o.mu.Lock()
	defer o.mu.Unlock()
	return o.status[taskID]
}

// Results returns the results of all completed tasks.
func (o *Orchestrator) Results() map[string]TaskResult {
	o.mu.Lock()
	defer o.mu.Unlock()
	res := make(map[string]TaskResult, len(o.results))
	for k, v := range o.results {
		res[k] = v
	}
	return res
}

// dispatchReady launches goroutines for pending tasks whose dependencies are resolved.
func (o *Orchestrator) dispatchReady(ctx context.Context, sem chan struct{}, resultCh chan<- TaskResult, wg *sync.WaitGroup) {
	o.mu.Lock()
	defer o.mu.Unlock()

	for _, task := range o.tasks {
		if o.status[task.ID] != TaskPending {
			continue
		}

		// Check for failed dependencies before depsResolved, and mark as blocked
		if o.depsFailed(task) {
			o.status[task.ID] = TaskBlocked
			resultCh <- TaskResult{
				TaskID: task.ID,
				Err:    fmt.Errorf("blocked: dependency failed"),
			}
			continue
		}

		if !o.depsResolved(task) {
			continue
		}

		// Attempt to acquire the semaphore (non-blocking)
		select {
		case sem <- struct{}{}:
		default:
			continue // parallelism limit reached
		}

		o.status[task.ID] = TaskRunning
		wg.Add(1)

		go func(t *Task) {
			defer wg.Done()
			defer func() { <-sem }() // release semaphore

			start := time.Now()
			result := o.workerFn(ctx, t)
			result.Duration = time.Since(start)
			result.TaskID = t.ID

			o.mu.Lock()
			if result.Err != nil {
				o.status[t.ID] = TaskFailed
			} else {
				o.status[t.ID] = TaskCompleted
			}
			o.results[t.ID] = result
			o.mu.Unlock()

			resultCh <- result
		}(task)
	}
}

// depsResolved returns whether all dependency tasks are completed.
// Assumes the lock is already held.
func (o *Orchestrator) depsResolved(task *Task) bool {
	for _, depID := range task.DependsOn {
		if o.status[depID] != TaskCompleted {
			return false
		}
	}
	return true
}

// depsFailed returns whether any dependency task is failed or blocked.
// Assumes the lock is already held.
func (o *Orchestrator) depsFailed(task *Task) bool {
	for _, depID := range task.DependsOn {
		s := o.status[depID]
		if s == TaskFailed || s == TaskBlocked {
			return true
		}
	}
	return false
}

// allTerminated returns whether all tasks are in a terminal state (completed/failed/blocked).
// Assumes the lock is already held.
func (o *Orchestrator) allTerminated() bool {
	for _, task := range o.tasks {
		s := o.status[task.ID]
		if s != TaskCompleted && s != TaskFailed && s != TaskBlocked {
			return false
		}
	}
	return true
}
