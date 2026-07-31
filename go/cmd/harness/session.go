package main

import (
	"fmt"
	"io"
	"os"
	"strings"
	"time"

	"github.com/Chachamaru127/claude-code-harness/go/internal/hookhandler"
)

func runSession(args []string) {
	os.Exit(runSessionCommand(args, os.Stdout, os.Stderr))
}

func runSessionCommand(args []string, stdout, stderr io.Writer) int {
	if len(args) == 0 {
		fmt.Fprintln(stderr, "Usage: harness session <declare|list>")
		return 1
	}
	switch args[0] {
	case "declare":
		return runSessionDeclareCommand(args[1:], stdout, stderr)
	case "list":
		return runSessionListCommand(args[1:], stdout, stderr)
	default:
		fmt.Fprintf(stderr, "Unknown session subcommand: %s\n", args[0])
		return 1
	}
}

func runSessionDeclareCommand(args []string, stdout, stderr io.Writer) int {
	var (
		taskID    string
		clearTask bool
		sessionID string
		root      string
	)
	for i := 0; i < len(args); i++ {
		switch args[i] {
		case "--task":
			if i+1 >= len(args) {
				fmt.Fprintln(stderr, "declare: --task requires a value")
				return 1
			}
			taskID = args[i+1]
			i++
		case "--clear":
			clearTask = true
		case "--session-id":
			if i+1 >= len(args) {
				fmt.Fprintln(stderr, "declare: --session-id requires a value")
				return 1
			}
			sessionID = args[i+1]
			i++
		default:
			if root == "" && !strings.HasPrefix(args[i], "-") {
				root = args[i]
			}
		}
	}
	projectRoot, err := resolveProjectRoot(sessionRootArgs(root))
	if err != nil {
		fmt.Fprintf(stderr, "declare: %v\n", err)
		return 1
	}
	if sessionID == "" {
		sessionID = hookhandler.ReadLocalSessionID(projectRoot)
	}
	if sessionID == "" {
		fmt.Fprintln(stderr, "declare: no session id (set .claude/state/session.json or --session-id)")
		return 1
	}
	if clearTask {
		if err := hookhandler.SessionDeclareClear(projectRoot, sessionID); err != nil {
			fmt.Fprintf(stderr, "declare: %v\n", err)
			return 1
		}
		fmt.Fprintln(stdout, "cleared")
		return 0
	}
	if strings.TrimSpace(taskID) == "" {
		fmt.Fprintln(stderr, "Usage: harness session declare --task <id> | declare --clear")
		return 1
	}
	if err := hookhandler.SessionDeclareTask(projectRoot, sessionID, taskID); err != nil {
		fmt.Fprintf(stderr, "declare: %v\n", err)
		return 1
	}
	fmt.Fprintf(stdout, "declared %s\n", taskID)
	return 0
}

func runSessionListCommand(args []string, stdout, stderr io.Writer) int {
	var root string
	for _, arg := range args {
		if !strings.HasPrefix(arg, "-") {
			root = arg
			break
		}
	}
	projectRoot, err := resolveProjectRoot(sessionRootArgs(root))
	if err != nil {
		fmt.Fprintf(stderr, "list: %v\n", err)
		return 1
	}
	out := hookhandler.FormatSessionTeamList(projectRoot, time.Now())
	fmt.Fprint(stdout, out)
	return 0
}

func sessionRootArgs(override string) []string {
	if override != "" {
		return []string{override}
	}
	if v := os.Getenv("HARNESS_PROJECT_ROOT"); v != "" {
		return []string{v}
	}
	return nil
}
