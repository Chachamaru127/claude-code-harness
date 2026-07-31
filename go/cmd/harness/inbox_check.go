package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/Chachamaru127/claude-code-harness/go/internal/deliveryidentity"
	"github.com/Chachamaru127/claude-code-harness/go/internal/livemsg"
)

// resolveInboxDBPath returns the default livemsg store path when --db is omitted,
// using the same precedence as the state store: ${CLAUDE_PLUGIN_DATA}/livemsg.db,
// then ${PROJECT_ROOT}/.harness/livemsg.db, then ./.harness/livemsg.db. The
// generated Mode-2 delivery hooks (Phase 105.9) invoke `inbox check` without a
// --db argument, so the command must resolve a canonical path itself instead of
// erroring. executeInboxCheck already treats a missing db file as "no messages".
func resolveInboxDBPath() string {
	if pluginData := os.Getenv("CLAUDE_PLUGIN_DATA"); pluginData != "" {
		return filepath.Join(pluginData, "livemsg.db")
	}
	if projectRoot := os.Getenv("CLAUDE_PROJECT_DIR"); projectRoot != "" {
		return filepath.Join(projectRoot, ".harness", "livemsg.db")
	}
	if cwd, err := os.Getwd(); err == nil {
		return filepath.Join(cwd, ".harness", "livemsg.db")
	}
	return ".harness/livemsg.db"
}

type inboxCheckOutput struct {
	Team          string                   `json:"team"`
	Agent         string                   `json:"agent"`
	Unread        int                      `json:"unread"`
	Messages      []inboxCheckMessageEntry `json:"messages"`
	InjectContext string                   `json:"inject_context,omitempty"`
}

type inboxCheckMessageEntry struct {
	ID        string `json:"id"`
	Team      string `json:"team"`
	FromAgent string `json:"from_agent"`
	ToAgent   string `json:"to_agent"`
	Subject   string `json:"subject"`
	Body      string `json:"body"`
	CreatedAt string `json:"created_at"`
}

type inboxCheckOpts struct {
	Team    string
	Agent   string
	DB      string
	FromEnv bool
}

type inboxCheckStdinHint struct {
	SessionID string `json:"session_id"`
}

func runInboxCheckCommand(args []string, stdout, stderr io.Writer) int {
	opts, err := parseInboxCheckArgs(args)
	if err != nil {
		fmt.Fprintf(stderr, "harness inbox check: %v\n", err)
		return 0
	}
	if opts.Agent == "" {
		opts.Agent = resolveInboxAgentFromStdin()
	}
	if opts.Agent == "" {
		if opts.FromEnv {
			fmt.Fprintf(stderr, "livemsg: identity unresolved (set HARNESS_LIVEMSG_TEAM/AGENT or run under breezing)\n")
		}
		// Fail-open: no identity → treat as no delivery (silent Stop hook).
		return 0
	}

	out, err := executeInboxCheck(opts)
	if err != nil {
		fmt.Fprintf(stderr, "harness inbox check: %v\n", err)
		return 0
	}

	if out.Unread == 0 {
		return 0
	}

	data, err := json.Marshal(out)
	if err != nil {
		fmt.Fprintf(stderr, "harness inbox check: marshal: %v\n", err)
		return 0
	}
	fmt.Fprintf(stdout, "%s\n", data)
	return 0
}

func parseInboxCheckArgs(args []string) (inboxCheckOpts, error) {
	var opts inboxCheckOpts
	fromEnv := false
	for i := 0; i < len(args); i++ {
		switch args[i] {
		case "--from-env":
			fromEnv = true
		case "--team":
			if i+1 >= len(args) {
				return opts, fmt.Errorf("--team requires a value")
			}
			i++
			opts.Team = args[i]
		case "--agent":
			if i+1 >= len(args) {
				return opts, fmt.Errorf("--agent requires a value")
			}
			i++
			opts.Agent = args[i]
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
	if fromEnv {
		opts.FromEnv = true
		team, agent, err := deliveryidentity.Resolve()
		if err == nil {
			opts.Team = team
			opts.Agent = agent
		}
	}
	if opts.Team == "" {
		opts.Team = strings.TrimSpace(os.Getenv("HARNESS_LIVEMSG_TEAM"))
	}
	if opts.Team == "" {
		opts.Team = "default"
	}
	if opts.Agent == "" {
		opts.Agent = strings.TrimSpace(os.Getenv("HARNESS_LIVEMSG_AGENT"))
	}
	if opts.DB == "" {
		// Generated Mode-2 delivery hooks (Phase 105.9) omit --db; resolve the
		// canonical livemsg store path instead of failing. A missing file is
		// handled downstream as "no messages", so the hook stays silent when the
		// Mode-2 write path is not active.
		opts.DB = resolveInboxDBPath()
	}
	return opts, nil
}

func executeInboxCheck(opts inboxCheckOpts) (inboxCheckOutput, error) {
	empty := inboxCheckOutput{
		Team:     opts.Team,
		Agent:    opts.Agent,
		Unread:   0,
		Messages: []inboxCheckMessageEntry{},
	}

	if _, err := os.Stat(opts.DB); os.IsNotExist(err) {
		return empty, nil
	}

	store, err := livemsg.Open(opts.DB)
	if err != nil {
		return empty, nil
	}
	defer store.Close()

	ctx := context.Background()
	messages, err := store.Inbox(ctx, opts.Team, opts.Agent)
	if err != nil {
		return empty, nil
	}

	locale := resolveInboxLocale()
	entries := make([]inboxCheckMessageEntry, 0, len(messages))
	for _, msg := range messages {
		entry := inboxCheckMessageEntry{
			ID:        msg.ID,
			Team:      msg.Team,
			FromAgent: msg.FromAgent,
			ToAgent:   msg.ToAgent,
			Subject:   msg.Subject,
			Body:      msg.Body,
			CreatedAt: msg.CreatedAt.UTC().Format(time.RFC3339Nano),
		}
		entries = append(entries, sanitizeInboxCheckEntry(entry))
		if err := store.MarkRead(ctx, opts.Team, msg.ID, opts.Agent); err != nil {
			return empty, nil
		}
	}

	return inboxCheckOutput{
		Team:          opts.Team,
		Agent:         opts.Agent,
		Unread:        len(entries),
		Messages:      entries,
		InjectContext: buildLivemsgInjectContext(entries, locale),
	}, nil
}

func resolveInboxAgentFromStdin() string {
	stat, err := os.Stdin.Stat()
	if err != nil || (stat.Mode()&os.ModeCharDevice) != 0 {
		return ""
	}
	data, err := io.ReadAll(os.Stdin)
	if err != nil || len(bytes.TrimSpace(data)) == 0 {
		return ""
	}
	var hint inboxCheckStdinHint
	if err := json.Unmarshal(data, &hint); err != nil {
		return ""
	}
	return strings.TrimSpace(hint.SessionID)
}
