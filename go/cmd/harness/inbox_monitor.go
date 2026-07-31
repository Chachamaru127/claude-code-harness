package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"time"
)

const inboxMonitorPollInterval = 5 * time.Second

type inboxMonitorOpts struct {
	Team  string
	Agent string
	DB    string
}

func runInboxMonitorCommand(args []string, stdout, stderr io.Writer) int {
	opts, err := parseInboxMonitorArgs(args)
	if err != nil {
		fmt.Fprintf(stderr, "harness inbox monitor: %v\n", err)
		return 0
	}

	ctx := context.Background()
	ticker := time.NewTicker(inboxMonitorPollInterval)
	defer ticker.Stop()

	emit := func() {
		out, err := executeInboxCheck(inboxCheckOpts{
			Team:  opts.Team,
			Agent: opts.Agent,
			DB:    opts.DB,
		})
		if err != nil {
			fmt.Fprintf(stderr, "harness inbox monitor: %v\n", err)
			return
		}
		if out.Unread == 0 {
			return
		}
		data, err := json.Marshal(out)
		if err != nil {
			fmt.Fprintf(stderr, "harness inbox monitor: marshal: %v\n", err)
			return
		}
		fmt.Fprintf(stdout, "%s\n", data)
	}

	emit()
	for {
		select {
		case <-ctx.Done():
			return 0
		case <-ticker.C:
			emit()
		}
	}
}

func parseInboxMonitorArgs(args []string) (inboxMonitorOpts, error) {
	check, err := parseInboxCheckArgs(args)
	if err != nil {
		return inboxMonitorOpts{}, err
	}
	return inboxMonitorOpts{
		Team:  check.Team,
		Agent: check.Agent,
		DB:    check.DB,
	}, nil
}
