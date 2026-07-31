package main

import (
	"fmt"
	"io"
	"os"
)

func runInbox(args []string) {
	os.Exit(runInboxCommand(args, os.Stdout, os.Stderr))
}

func runInboxCommand(args []string, stdout, stderr io.Writer) int {
	if len(args) == 0 {
		fmt.Fprintln(stderr, "Usage: harness inbox <check|monitor|send|sent>")
		return 1
	}
	switch args[0] {
	case "check":
		return runInboxCheckCommand(args[1:], stdout, stderr)
	case "monitor":
		return runInboxMonitorCommand(args[1:], stdout, stderr)
	case "send":
		return runInboxSendCommand(args[1:], stdout, stderr)
	case "sent":
		return runInboxSentCommand(args[1:], stdout, stderr)
	default:
		fmt.Fprintf(stderr, "Unknown inbox subcommand: %s\n", args[0])
		return 1
	}
}
