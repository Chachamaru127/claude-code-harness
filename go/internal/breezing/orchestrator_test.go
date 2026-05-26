package breezing

import (
	"context"
	"fmt"
	"sync/atomic"
	"testing"
	"time"
)

func TestOrchestratorEmptyRun(t *testing.T) {
	o := NewOrchestrator(func(ctx context.Context, task *Task) TaskResult {
		return TaskResult{}
	})
	results, err := o.Run(context.Background())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(results) != 0 {
		t.Fatalf("expected 0 results, got %d", len(results))
	}
}

func TestOrchestratorSingleTask(t *testing.T) {
	o := NewOrchestrator(func(ctx context.Context, task *Task) TaskResult {
		return TaskResult{CommitHash: "abc1234"}
	})
	o.AddTask(&Task{ID: "1", Description: "test task"})

	results, err := o.Run(context.Background())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(results) != 1 {
		t.Fatalf("expected 1 result, got %d", len(results))
	}
	if results[0].CommitHash != "abc1234" {
		t.Errorf("expected commit abc1234, got %s", results[0].CommitHash)
	}
	if o.Status("1") != TaskCompleted {
		t.Errorf("expected completed, got %s", o.Status("1"))
	}
}

func TestOrchestratorParallelLimit(t *testing.T) {
	var maxConcurrent int64
	var current int64

	o := NewOrchestrator(
		func(ctx context.Context, task *Task) TaskResult {
			n := atomic.AddInt64(&current, 1)
			defer atomic.AddInt64(&current, -1)

			// Record the maximum concurrency
			for {
				old := atomic.LoadInt64(&maxConcurrent)
				if n <= old || atomic.CompareAndSwapInt64(&maxConcurrent, old, n) {
					break
				}
			}

			time.Sleep(50 * time.Millisecond)
			return TaskResult{}
		},
		WithMaxParallel(2),
	)

	for i := 0; i < 5; i++ {
		o.AddTask(&Task{ID: fmt.Sprintf("%d", i), Description: fmt.Sprintf("task %d", i)})
	}

	results, err := o.Run(context.Background())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(results) != 5 {
		t.Fatalf("expected 5 results, got %d", len(results))
	}

	mc := atomic.LoadInt64(&maxConcurrent)
	if mc > 2 {
		t.Errorf("max parallel exceeded: expected <= 2, got %d", mc)
	}
	if mc < 2 {
		t.Errorf("expected at least 2 parallel, got %d (semaphore may be too restrictive)", mc)
	}
}

func TestOrchestratorDependencyChain(t *testing.T) {
	var order []string
	var orderMu = make(chan struct{}, 1)

	o := NewOrchestrator(func(ctx context.Context, task *Task) TaskResult {
		orderMu <- struct{}{}
		order = append(order, task.ID)
		<-orderMu
		return TaskResult{}
	})

	o.AddTask(&Task{ID: "A", Description: "first"})
	o.AddTask(&Task{ID: "B", Description: "second", DependsOn: []string{"A"}})
	o.AddTask(&Task{ID: "C", Description: "third", DependsOn: []string{"B"}})

	results, err := o.Run(context.Background())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(results) != 3 {
		t.Fatalf("expected 3 results, got %d", len(results))
	}

	// A must come before B, B before C
	idxA, idxB, idxC := -1, -1, -1
	for i, id := range order {
		switch id {
		case "A":
			idxA = i
		case "B":
			idxB = i
		case "C":
			idxC = i
		}
	}
	if idxA >= idxB || idxB >= idxC {
		t.Errorf("dependency order violated: A=%d, B=%d, C=%d", idxA, idxB, idxC)
	}
}

func TestOrchestratorFailedDependencyBlocks(t *testing.T) {
	o := NewOrchestrator(func(ctx context.Context, task *Task) TaskResult {
		if task.ID == "A" {
			return TaskResult{Err: fmt.Errorf("A failed")}
		}
		return TaskResult{}
	})

	o.AddTask(&Task{ID: "A", Description: "will fail"})
	o.AddTask(&Task{ID: "B", Description: "depends on A", DependsOn: []string{"A"}})

	results, err := o.Run(context.Background())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(results) != 2 {
		t.Fatalf("expected 2 results, got %d", len(results))
	}

	if o.Status("A") != TaskFailed {
		t.Errorf("expected A=failed, got %s", o.Status("A"))
	}
	if o.Status("B") != TaskBlocked {
		t.Errorf("expected B=blocked, got %s", o.Status("B"))
	}
}

func TestOrchestratorGracefulShutdown(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())

	started := make(chan struct{})
	o := NewOrchestrator(func(ctx context.Context, task *Task) TaskResult {
		close(started)
		<-ctx.Done()
		return TaskResult{Err: ctx.Err()}
	})

	o.AddTask(&Task{ID: "1", Description: "long running"})

	done := make(chan struct{})
	var results []TaskResult
	var runErr error
	go func() {
		results, runErr = o.Run(ctx)
		close(done)
	}()

	<-started
	cancel()

	select {
	case <-done:
	case <-time.After(3 * time.Second):
		t.Fatal("Run did not return after context cancel")
	}

	if runErr != context.Canceled {
		t.Errorf("expected context.Canceled, got %v", runErr)
	}
	_ = results
}

func TestOrchestratorProgressCallback(t *testing.T) {
	var calls []int

	o := NewOrchestrator(
		func(ctx context.Context, task *Task) TaskResult {
			return TaskResult{}
		},
		WithProgressFunc(func(completed, total int, result TaskResult) {
			calls = append(calls, completed)
		}),
	)

	o.AddTask(&Task{ID: "1", Description: "a"})
	o.AddTask(&Task{ID: "2", Description: "b"})
	o.AddTask(&Task{ID: "3", Description: "c"})

	_, err := o.Run(context.Background())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if len(calls) != 3 {
		t.Fatalf("expected 3 progress calls, got %d", len(calls))
	}
	// last call should be 3
	if calls[len(calls)-1] != 3 {
		t.Errorf("final progress should be 3, got %d", calls[len(calls)-1])
	}
}

func TestOrchestratorIndependentTasksParallel(t *testing.T) {
	// 3 independent tasks with maxParallel=3 should all start concurrently
	started := make(chan string, 3)

	o := NewOrchestrator(
		func(ctx context.Context, task *Task) TaskResult {
			started <- task.ID
			time.Sleep(100 * time.Millisecond)
			return TaskResult{}
		},
		WithMaxParallel(3),
	)

	o.AddTask(&Task{ID: "X"})
	o.AddTask(&Task{ID: "Y"})
	o.AddTask(&Task{ID: "Z"})

	go func() {
		o.Run(context.Background()) //nolint:errcheck
	}()

	// All 3 should start within 200ms (dispatch loop polls every 50ms)
	timeout := time.After(500 * time.Millisecond)
	count := 0
	for count < 3 {
		select {
		case <-started:
			count++
		case <-timeout:
			t.Fatalf("expected 3 tasks to start, only %d started", count)
		}
	}
}
