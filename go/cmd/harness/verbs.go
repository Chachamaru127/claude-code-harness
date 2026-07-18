package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/Chachamaru127/claude-code-harness/go/internal/gitport"
	"github.com/Chachamaru127/claude-code-harness/go/internal/plans"
	"github.com/Chachamaru127/claude-code-harness/go/internal/promptpack"
)

// The verb subcommands (work|plan|review|release) ASSEMBLE a host-facing prompt
// and emit it to stdout for the host (Claude/Codex/Cursor) to execute. They do
// NOT call any LLM. Policy enforcement happens via the host's hooks.
//
//	claude -p "$(harness work 1.1)"

// runWork handles `harness work <taskID>`: assemble the work prompt + the task
// from Plans.md and emit to stdout for the host to execute. No LLM is called.
//
// `harness work --team [--backend X] t1 t2 ...` delegates to runWorkTeam, which
// fans out N backend sub-runs through breezing.Orchestrator. Without --team the
// single-task emit behavior below is unchanged.
func runWork(args []string) {
	if len(args) > 0 && args[0] == "--team" {
		runWorkTeam(args)
		return
	}
	if isHelpFlag(args) {
		fmt.Println("Usage: harness work <taskID>  — emit the work prompt + task context for the host to execute")
		os.Exit(0)
	}
	runTaskVerb("work", args)
}

// runReview handles `harness review <taskID>`: same assemble-and-emit shape as
// work, using the reviewer contract.
func runReview(args []string) {
	if isHelpFlag(args) {
		fmt.Println("Usage: harness review <taskID>  — emit the review prompt + task context for the host to execute")
		os.Exit(0)
	}
	runTaskVerb("review", args)
}

// runPlan handles `harness plan [args]`: emit the plan contract plus a context
// header. No task is required.
func runPlan(args []string) {
	if isHelpFlag(args) {
		fmt.Println("Usage: harness plan  — emit the plan prompt for the host to execute")
		os.Exit(0)
	}
	runContextVerb("plan")
}

// runRelease handles `harness release [--check] [args]`: emit the release
// contract plus a context header, or run the read-only Release Train check.
func runRelease(args []string) {
	if isHelpFlag(args) {
		fmt.Println("Usage: harness release [--check]  — emit the release prompt for the host to execute")
		os.Exit(0)
	}
	for _, arg := range args {
		if arg == "--check" {
			runReleaseCheck(args)
			return
		}
	}
	runContextVerb("release")
}

// runTaskVerb implements the task-scoped verbs (work, review): require a taskID,
// resolve and parse Plans.md, find the task, then assemble and print.
func runTaskVerb(verb string, args []string) {
	if len(args) == 0 || strings.TrimSpace(args[0]) == "" {
		fmt.Fprintf(os.Stderr, "Usage: harness %s <taskID>\n", verb)
		os.Exit(1)
	}
	taskID := args[0]

	plansPath := resolvePlansFile()
	tasks, err := plans.ParseFile(plansPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "harness %s: cannot read Plans.md at %s: %v\n", verb, plansPath, err)
		os.Exit(1)
	}

	task := plans.Find(tasks, taskID)
	if task == nil {
		fmt.Fprintf(os.Stderr, "task %s not found\n", taskID)
		os.Exit(1)
	}

	out, err := assembleVerbPrompt(verb, task)
	if err != nil {
		fmt.Fprintf(os.Stderr, "harness %s: %v\n", verb, err)
		os.Exit(1)
	}
	fmt.Print(out)
	os.Exit(0)
}

// runContextVerb implements the task-less verbs (plan, release): emit the verb
// contract plus a short context header (cwd, Plans.md path).
func runContextVerb(verb string) {
	body, err := assembleVerbPrompt(verb, nil)
	if err != nil {
		fmt.Fprintf(os.Stderr, "harness %s: %v\n", verb, err)
		os.Exit(1)
	}

	cwd, _ := os.Getwd()
	header := fmt.Sprintf("## Context\n- CWD: %s\n- Plans.md: %s\n\n", cwd, resolvePlansFile())
	fmt.Print(header + body)
	os.Exit(0)
}

// assembleVerbPrompt composes the host-facing prompt: the embedded verb
// contract followed by the concrete task block (for work/review).
func assembleVerbPrompt(verb string, task *plans.Task) (string, error) {
	contract, err := promptpack.Get(verb)
	if err != nil {
		return "", err
	}
	if task == nil {
		return contract, nil
	}

	var b strings.Builder
	b.WriteString(contract)
	b.WriteString("\n\n## Task\n")
	fmt.Fprintf(&b, "- ID: %s\n", task.TaskID)
	fmt.Fprintf(&b, "- Title: %s\n", task.Title)
	fmt.Fprintf(&b, "- DoD: %s\n", task.DoD)
	fmt.Fprintf(&b, "- Depends: %s\n", task.Depends)
	fmt.Fprintf(&b, "- Status: %s\n", task.Status)
	return b.String(), nil
}

// resolveRepoRoot returns the project root, mirroring the hookhandler
// resolution order: HARNESS_PROJECT_ROOT, PROJECT_ROOT, git toplevel, then cwd.
func resolveRepoRoot() string {
	if v := os.Getenv("HARNESS_PROJECT_ROOT"); v != "" {
		return v
	}
	if v := os.Getenv("PROJECT_ROOT"); v != "" {
		return v
	}
	if out, err := gitport.Output("", "rev-parse", "--show-toplevel"); err == nil {
		if root := strings.TrimSpace(out); root != "" {
			return root
		}
	}
	cwd, _ := os.Getwd()
	return cwd
}

// resolvePlansFile returns the path to Plans.md. It checks the candidate file
// names under the resolved repo root and falls back to ./Plans.md when none
// exists (so callers get a stable, reportable path even on a miss).
func resolvePlansFile() string {
	root := resolveRepoRoot()
	for _, name := range []string{"Plans.md", "plans.md", "PLANS.md", "PLANS.MD"} {
		full := filepath.Join(root, name)
		if _, err := os.Stat(full); err == nil {
			return full
		}
	}
	return "./Plans.md"
}

// isHelpFlag reports whether the first arg is an explicit help flag
// (--help/-h/help). A bare invocation (no args) is NOT help: task verbs treat
// it as a missing-taskID error, and context verbs treat it as a normal emit.
func isHelpFlag(args []string) bool {
	if len(args) == 0 {
		return false
	}
	switch args[0] {
	case "--help", "-h", "help":
		return true
	}
	return false
}
