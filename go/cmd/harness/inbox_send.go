package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"time"

	"github.com/Chachamaru127/claude-code-harness/go/internal/livemsg"
)

type inboxSendOpts struct {
	Team    string
	From    string
	To      string
	Subject string
	Body    string
	DB      string
}

func runInboxSendCommand(args []string, stdout, stderr io.Writer) int {
	opts, err := parseInboxSendArgs(args)
	if err != nil {
		fmt.Fprintf(stderr, "harness inbox send: %v\n", err)
		return 1
	}

	store, err := livemsg.Open(opts.DB)
	if err != nil {
		fmt.Fprintf(stderr, "harness inbox send: %v\n", err)
		return 1
	}
	defer store.Close()

	subject := sanitizeAndCapLivemsgField(opts.Subject, 512)
	body := sanitizeLivemsgBodyForStore(opts.Body)
	from := sanitizeAndCapLivemsgField(opts.From, 256)
	to := sanitizeAndCapLivemsgField(opts.To, 256)

	ctx := context.Background()
	id, err := store.Send(ctx, opts.Team, from, to, subject, body)
	if err != nil {
		fmt.Fprintf(stderr, "harness inbox send: %v\n", err)
		return 1
	}

	out := map[string]string{
		"id":         id,
		"team":       opts.Team,
		"from_agent": opts.From,
		"to_agent":   opts.To,
	}
	data, err := json.Marshal(out)
	if err != nil {
		fmt.Fprintf(stderr, "harness inbox send: marshal: %v\n", err)
		return 1
	}
	fmt.Fprintf(stdout, "%s\n", data)
	return 0
}

func parseInboxSendArgs(args []string) (inboxSendOpts, error) {
	var opts inboxSendOpts
	var positional []string
	for i := 0; i < len(args); i++ {
		switch args[i] {
		case "--team":
			if i+1 >= len(args) {
				return opts, fmt.Errorf("--team requires a value")
			}
			i++
			opts.Team = args[i]
		case "--from":
			if i+1 >= len(args) {
				return opts, fmt.Errorf("--from requires a value")
			}
			i++
			opts.From = args[i]
		case "--to":
			if i+1 >= len(args) {
				return opts, fmt.Errorf("--to requires a value")
			}
			i++
			opts.To = args[i]
		case "--subject":
			if i+1 >= len(args) {
				return opts, fmt.Errorf("--subject requires a value")
			}
			i++
			opts.Subject = args[i]
		case "--db":
			if i+1 >= len(args) {
				return opts, fmt.Errorf("--db requires a value")
			}
			i++
			opts.DB = args[i]
		default:
			positional = append(positional, args[i])
		}
	}
	if len(positional) != 1 {
		return opts, fmt.Errorf("body message argument is required (exactly one positional)")
	}
	opts.Body = positional[0]
	if opts.Team == "" {
		return opts, fmt.Errorf("--team is required")
	}
	if opts.From == "" {
		return opts, fmt.Errorf("--from is required")
	}
	if opts.To == "" {
		return opts, fmt.Errorf("--to is required")
	}
	if opts.DB == "" {
		opts.DB = resolveInboxDBPath()
	}
	return opts, nil
}

type inboxSentOutput struct {
	Team     string           `json:"team"`
	From     string           `json:"from_agent"`
	Messages []inboxSentEntry `json:"messages"`
}

type inboxSentEntry struct {
	ID        string `json:"id"`
	Team      string `json:"team"`
	FromAgent string `json:"from_agent"`
	ToAgent   string `json:"to_agent"`
	Subject   string `json:"subject"`
	Body      string `json:"body"`
	CreatedAt string `json:"created_at"`
	Read      bool   `json:"read"`
	ReadAt    string `json:"read_at,omitempty"`
}

type inboxSentOpts struct {
	Team string
	From string
	DB   string
}

func runInboxSentCommand(args []string, stdout, stderr io.Writer) int {
	opts, err := parseInboxSentArgs(args)
	if err != nil {
		fmt.Fprintf(stderr, "harness inbox sent: %v\n", err)
		return 1
	}

	if _, err := os.Stat(opts.DB); os.IsNotExist(err) {
		emitEmptySent(stdout, opts)
		return 0
	}

	store, err := livemsg.Open(opts.DB)
	if err != nil {
		fmt.Fprintf(stderr, "harness inbox sent: %v\n", err)
		return 1
	}
	defer store.Close()

	ctx := context.Background()
	sent, err := store.Sent(ctx, opts.Team, opts.From)
	if err != nil {
		fmt.Fprintf(stderr, "harness inbox sent: %v\n", err)
		return 1
	}

	entries := make([]inboxSentEntry, 0, len(sent))
	for _, msg := range sent {
		entry := inboxSentEntry{
			ID:        msg.ID,
			Team:      msg.Team,
			FromAgent: msg.FromAgent,
			ToAgent:   msg.ToAgent,
			Subject:   msg.Subject,
			Body:      msg.Body,
			CreatedAt: msg.CreatedAt.UTC().Format(time.RFC3339Nano),
			Read:      msg.Read,
		}
		if msg.Read && !msg.ReadAt.IsZero() {
			entry.ReadAt = msg.ReadAt.UTC().Format(time.RFC3339Nano)
		}
		entries = append(entries, entry)
	}

	out := inboxSentOutput{Team: opts.Team, From: opts.From, Messages: entries}
	data, err := json.Marshal(out)
	if err != nil {
		fmt.Fprintf(stderr, "harness inbox sent: marshal: %v\n", err)
		return 1
	}
	fmt.Fprintf(stdout, "%s\n", data)
	return 0
}

func emitEmptySent(stdout io.Writer, opts inboxSentOpts) {
	out := inboxSentOutput{Team: opts.Team, From: opts.From, Messages: []inboxSentEntry{}}
	data, _ := json.Marshal(out)
	fmt.Fprintf(stdout, "%s\n", data)
}

func parseInboxSentArgs(args []string) (inboxSentOpts, error) {
	var opts inboxSentOpts
	for i := 0; i < len(args); i++ {
		switch args[i] {
		case "--team":
			if i+1 >= len(args) {
				return opts, fmt.Errorf("--team requires a value")
			}
			i++
			opts.Team = args[i]
		case "--from":
			if i+1 >= len(args) {
				return opts, fmt.Errorf("--from requires a value")
			}
			i++
			opts.From = args[i]
		case "--db":
			if i+1 >= len(args) {
				return opts, fmt.Errorf("--db requires a value")
			}
			i++
			opts.DB = args[i]
		default:
			return opts, fmt.Errorf("unknown flag %q", args[i])
		}
	}
	if opts.Team == "" {
		return opts, fmt.Errorf("--team is required")
	}
	if opts.From == "" {
		return opts, fmt.Errorf("--from is required")
	}
	if opts.DB == "" {
		opts.DB = resolveInboxDBPath()
	}
	return opts, nil
}
