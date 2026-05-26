package hookhandler

// terminal_notify.go
// Shared helper for building the `terminalSequence` field in CC 2.1.141+ hook JSON output.
// Opt-in via the HARNESS_TERMINAL_NOTIFY env variable.
//
// Details: .claude/rules/hooks-2.1.139-plus.md
// Shell reference implementation: scripts/lib/terminal-notify.sh

import (
	"os"
	"strings"
)

// terminalNotifyMode is the result of interpreting the HARNESS_TERMINAL_NOTIFY env variable.
type terminalNotifyMode int

const (
	notifyOff terminalNotifyMode = iota
	notifyBell
	notifyTitle
	notifyOSC9
	notifyDesktop // OSC 777
)

// resolveTerminalNotifyMode resolves the mode from the env variable. Unknown values default to notifyOff.
func resolveTerminalNotifyMode() terminalNotifyMode {
	switch strings.ToLower(strings.TrimSpace(os.Getenv("HARNESS_TERMINAL_NOTIFY"))) {
	case "", "0":
		return notifyOff
	case "1", "bell":
		return notifyBell
	case "title":
		return notifyTitle
	case "osc9":
		return notifyOSC9
	case "notify":
		return notifyDesktop
	default:
		// Unknown values are silent (consistent with the rule)
		return notifyOff
	}
}

// sanitizeTerminalText strips control characters (0x00-0x1F, 0x7F) from title/body.
// Only printable characters are allowed, to prevent terminal corruption and secret leakage.
func sanitizeTerminalText(s string) string {
	if s == "" {
		return ""
	}
	var b strings.Builder
	b.Grow(len(s))
	for _, r := range s {
		// 0x00-0x1F are control characters; 0x7F is DEL
		if r < 0x20 || r == 0x7F {
			continue
		}
		b.WriteRune(r)
	}
	return b.String()
}

// BuildTerminalSequence builds the raw OSC sequence for the terminalSequence field.
//
// When title is empty, only bell mode returns BEL; all other modes return an empty string.
// Returns an empty string when HARNESS_TERMINAL_NOTIFY is not set (preserves opt-in behaviour).
//
// The return value is raw bytes. Encode with json.Marshal when embedding in JSON.
func BuildTerminalSequence(title, body string) string {
	mode := resolveTerminalNotifyMode()
	if mode == notifyOff {
		return ""
	}

	cleanTitle := sanitizeTerminalText(title)
	cleanBody := sanitizeTerminalText(body)

	// Bell mode does not require a title; all other modes do
	if mode != notifyBell && cleanTitle == "" {
		return ""
	}

	const (
		esc = "\x1b"
		bel = "\x07"
	)

	switch mode {
	case notifyBell:
		return bel
	case notifyTitle:
		return esc + "]0;" + cleanTitle + bel
	case notifyOSC9:
		return esc + "]9;" + cleanTitle + bel
	case notifyDesktop:
		// OSC 777;notify;<title>;<body><BEL>
		if cleanBody != "" {
			return esc + "]777;notify;" + cleanTitle + ";" + cleanBody + bel
		}
		return esc + "]777;notify;" + cleanTitle + bel
	}
	return ""
}

// AugmentWithTerminalSequence adds a terminalSequence field to the hook response map.
// Does nothing when HARNESS_TERMINAL_NOTIFY is unset, or when title is empty (non-bell mode).
func AugmentWithTerminalSequence(resp map[string]interface{}, title, body string) {
	if resp == nil {
		return
	}
	seq := BuildTerminalSequence(title, body)
	if seq != "" {
		resp["terminalSequence"] = seq
	}
}
