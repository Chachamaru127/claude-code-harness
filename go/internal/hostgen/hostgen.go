// Package hostgen generates each host's native pre-action hook configuration
// from a single descriptor file (hosts.toml at the repo root).
//
// The convergence goal of Phase 91.3: Claude, Codex, and Cursor each have a
// different hooks.json schema, but all three must invoke the SAME policy engine
// entrypoint — `bin/harness hook pre-tool` — so one R01-R13 rule kernel
// adjudicates every host. hosts.toml is the single source of cross-host
// differences (event key name, file path, deny mechanism); this package turns
// each [host] table into that host's native hooks.json bytes.
//
// Scope: this package emits native hook configs and managed agent profile
// artifacts. The Claude PreToolUse command is represented for
// completeness/testing, but the live .claude-plugin/hooks.json (a
// hand-maintained 592-line file) is NOT overwritten until the Phase 91.8
// cutover — `harness gen` skips writing it.
//
// hostgen is a tooling package (it parses hosts.toml with BurntSushi/toml),
// not part of the pure guardrail kernel, so external deps are acceptable here.
package hostgen

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"path/filepath"
	"sort"
	"strconv"
	"strings"

	"github.com/BurntSushi/toml"
)

// ErrHookGenerationDeferred marks a registered host whose runtime adapter is
// present but whose native lifecycle-hook schema has not passed live admission.
var ErrHookGenerationDeferred = errors.New("native hook generation deferred")

// preToolCommand is the argv tail every generated host hook appends after the
// harness binary: all three hosts converge on this single policy entrypoint.
const preToolCommand = "hook pre-tool"

const deliveryMatcher = "*"

const inboxCheckCommand = "bin/harness inbox check --from-env"

const inboxMonitorCommand = "bin/harness inbox monitor --from-env"

// claudeBinary is the binary invocation Codex and Cursor use directly. Claude's
// own hooks.json wraps the binary in a valid_root bootstrap (see
// ClaudePreToolCommand); Codex/Cursor configs are generated minimally and
// resolve the binary from PATH / the host's plugin root.
const claudeBinary = "bin/harness"

// ClaudePreToolCommand mirrors the valid_root bootstrap wrapper used by the
// tracked .claude-plugin/hooks.json PreToolUse entry (resolve the plugin root,
// verify it owns harness, then exec the binary with the hook args).
// It is reused verbatim so a regenerated Claude config at the Phase 91.8 cutover
// keeps the exact same launch semantics. The live file is not overwritten now.
const ClaudePreToolCommand = `/bin/bash -c 'valid_root(){ local r="${1:-}"; [ -n "$r" ] && [ -x "$r/bin/harness" ] && [ -f "$r/.claude-plugin/plugin.json" ] && /usr/bin/grep -q "\"name\"[[:space:]]*:[[:space:]]*\"harness\"" "$r/.claude-plugin/plugin.json"; }; root="${CLAUDE_PLUGIN_ROOT:-}"; if ! valid_root "$root"; then root=""; for c in "${CLAUDE_PROJECT_DIR:-}" "$PWD" "$HOME/.claude/plugins/marketplaces/claude-code-harness-marketplace" "$HOME/.claude/plugins/cache/claude-code-harness-marketplace/harness/"*; do if valid_root "$c"; then root="$c"; break; fi; done; fi; if ! valid_root "$root"; then echo "[harness] plugin root not found; hook skipped" >&2; exit 0; fi; exec "$root/bin/harness" "$@"' _ ` + preToolCommand

// Host describes one host's pre-action hook capabilities, parsed from a [host]
// table in hosts.toml.
type Host struct {
	Name                 string                  `toml:"-"`
	HookEvent            string                  `toml:"hook_event"`
	HookPath             string                  `toml:"hook_path"`
	Matcher              string                  `toml:"matcher"`
	Deny                 string                  `toml:"deny"`
	Transport            string                  `toml:"transport"`
	Model                string                  `toml:"model"`
	DeliveryStrategy     string                  `toml:"delivery_strategy"`
	DeliveryEventTurn    string                  `toml:"delivery_event_turn"`
	DeliveryEventMonitor string                  `toml:"delivery_event_monitor"`
	HookGeneration       string                  `toml:"hook_generation"`
	AgentProfiles        map[string]AgentProfile `toml:"agent_profiles"`
	// RequiresHomePath names a path under $HOME that must exist for this host
	// to be considered installed. Empty means always generate. Hosts Harness
	// does not fully manage use this so `gen` does not litter a repo with
	// config for a tool the operator never installed.
	RequiresHomePath string `toml:"requires_home_path"`
}

// AgentProfile is a managed Codex custom-agent declaration. OutputPath is the
// repository-relative path of the generated artifact; the remaining fields are
// emitted as the Codex profile itself.
type AgentProfile struct {
	OutputPath            string `toml:"output_path"`
	Name                  string `toml:"name"`
	Description           string `toml:"description"`
	Model                 string `toml:"model"`
	ModelReasoningEffort  string `toml:"model_reasoning_effort"`
	SandboxMode           string `toml:"sandbox_mode"`
	DeveloperInstructions string `toml:"developer_instructions"`
}

// Load parses hosts.toml and returns a map keyed by host name (claude, codex,
// cursor). The Name field of each Host is populated from its table key.
func Load(path string) (map[string]Host, error) {
	var raw map[string]Host
	if _, err := toml.DecodeFile(path, &raw); err != nil {
		return nil, fmt.Errorf("hosts.toml: parse error: %w", err)
	}
	if len(raw) == 0 {
		return nil, fmt.Errorf("hosts.toml: no host tables found in %s", path)
	}
	out := make(map[string]Host, len(raw))
	for name, h := range raw {
		h.Name = name
		for role, profile := range h.AgentProfiles {
			if err := validateAgentProfile(role, profile); err != nil {
				return nil, fmt.Errorf("hosts.toml: %s.agent_profiles.%s: %w", name, role, err)
			}
		}
		out[name] = h
	}
	return out, nil
}

// GenerateAgentProfile emits one managed Codex custom-agent profile. The
// output path is metadata used by the caller and is deliberately not copied
// into the Codex file, whose schema only contains the profile fields.
func GenerateAgentProfile(profile AgentProfile) ([]byte, error) {
	if err := validateAgentProfile("", profile); err != nil {
		return nil, fmt.Errorf("hostgen: invalid agent profile: %w", err)
	}
	var b strings.Builder
	fmt.Fprintf(&b, "name = %s\n", strconv.Quote(profile.Name))
	fmt.Fprintf(&b, "description = %s\n", strconv.Quote(profile.Description))
	fmt.Fprintf(&b, "model = %s\n", strconv.Quote(profile.Model))
	fmt.Fprintf(&b, "model_reasoning_effort = %s\n", strconv.Quote(profile.ModelReasoningEffort))
	if profile.SandboxMode != "" {
		fmt.Fprintf(&b, "sandbox_mode = %s\n", strconv.Quote(profile.SandboxMode))
	}
	b.WriteString("developer_instructions = ")
	b.WriteString(formatTOMLString(profile.DeveloperInstructions))
	b.WriteByte('\n')
	return []byte(b.String()), nil
}

func validateAgentProfile(role string, profile AgentProfile) error {
	if profile.OutputPath == "" {
		return errors.New("output_path is required")
	}
	if err := validateInPackagePath(profile.OutputPath); err != nil {
		return fmt.Errorf("output_path: %w", err)
	}
	if role != "" && profile.Name != role {
		return fmt.Errorf("name %q must match profile key %q", profile.Name, role)
	}
	for field, value := range map[string]string{
		"name":                   profile.Name,
		"description":            profile.Description,
		"model":                  profile.Model,
		"model_reasoning_effort": profile.ModelReasoningEffort,
		"sandbox_mode":           profile.SandboxMode,
		"developer_instructions": profile.DeveloperInstructions,
	} {
		if field == "sandbox_mode" && strings.TrimSpace(value) == "" {
			continue
		}
		if strings.TrimSpace(value) == "" {
			return fmt.Errorf("%s is required", field)
		}
		if strings.ContainsRune(value, '\x00') {
			return fmt.Errorf("%s contains NUL", field)
		}
	}
	if strings.Contains(profile.DeveloperInstructions, `"""`) {
		return errors.New("developer_instructions must not contain triple quotes")
	}
	return nil
}

func validateInPackagePath(value string) error {
	if filepath.IsAbs(value) || strings.HasPrefix(value, `\\`) ||
		(len(value) >= 3 && ((value[0] >= 'A' && value[0] <= 'Z') || (value[0] >= 'a' && value[0] <= 'z')) && value[1] == ':' && (value[2] == '/' || value[2] == '\\')) {
		return errors.New("must be a relative in-package path")
	}
	if value == "" || filepath.Clean(value) == "." {
		return errors.New("must name a file inside the package")
	}
	// Check slash-separated components explicitly so this remains safe when a
	// descriptor is evaluated on a different host OS than the authoring host.
	for _, component := range strings.FieldsFunc(value, func(r rune) bool { return r == '/' || r == '\\' }) {
		if component == ".." {
			return errors.New("must not contain .. path components")
		}
	}
	if strings.ContainsRune(value, '\x00') {
		return errors.New("must not contain NUL")
	}
	return nil
}

func formatTOMLString(value string) string {
	if !strings.ContainsAny(value, "\r\n") {
		return strconv.Quote(value)
	}
	// The descriptor uses a TOML multiline basic string for instructions so the
	// generated file stays readable and preserves the exact instruction text.
	value = strings.ReplaceAll(value, `\`, `\\`)
	return `"""` + "\n" + value + `"""`
}

// GenerateHooksJSON emits the host's native hooks.json bytes wiring
// h.HookEvent → `bin/harness hook pre-tool`. Output is deterministic (stable
// key order via a fixed encoder, no map iteration over content) and ends with a
// trailing newline. The per-host JSON shape follows each vendor's documented
// schema:
//
//   - claude: {"hooks":{"<event>":[{"matcher":..,"hooks":[{"type":"command","command":<valid_root wrapper>,"timeout":10}]}]}}
//   - codex:  {"hooks":{"<event>":[{"matcher":..,"hooks":[{"type":"command","command":"bin/harness hook pre-tool --host codex","timeout":30}]}]}}
//   - cursor: {"version":1,"hooks":{"<event>":[{"command":"bin/harness hook pre-tool --host cursor","timeout":30}]}}
//
// A deny is expressed by the policy engine at runtime (exit 2 + hookSpecific
// output), not by this static config, so the generated file only declares the
// wiring; the deny mechanism column in hosts.toml documents how each host reads
// that engine result. Host-neutral audit metadata such as FloorPolicyFragment
// must stay outside vendor hook documents because strict parsers reject unknown
// top-level keys.
// GenerateDeliveryHooksJSON emits per-host delivery-notice hook wiring for
// livemsg inbox check (turn boundary) and, for Claude only, inbox monitor
// (SessionStart blocking stream). Returns (nil, false, nil) when delivery
// config is absent — fail-open for hosts without live-notice wiring.
func GenerateDeliveryHooksJSON(h Host) ([]byte, bool, error) {
	doc, ok := buildDeliveryDoc(h)
	if !ok {
		return nil, false, nil
	}
	out, err := marshalStable(doc)
	if err != nil {
		return nil, false, err
	}
	return out, true, nil
}

func buildDeliveryDoc(h Host) (interface{}, bool) {
	if h.DeliveryStrategy == "" || h.DeliveryEventTurn == "" {
		return nil, false
	}

	turnEntry := commandEntry{Type: "command", Command: inboxCheckCommand, Timeout: 30}
	hooks := map[string]interface{}{
		h.DeliveryEventTurn: deliveryTurnGroups(h, turnEntry),
	}

	if h.Name == "claude" && h.DeliveryEventMonitor != "" {
		monitorEntry := commandEntry{Type: "command", Command: inboxMonitorCommand, Timeout: 300}
		hooks[h.DeliveryEventMonitor] = []matcherGroup{
			{Matcher: deliveryMatcher, Hooks: []commandEntry{monitorEntry}},
		}
	}

	switch h.Name {
	case "cursor":
		return map[string]interface{}{
			"version": 1,
			"hooks":   hooks,
		}, true
	case "codex", "claude", "grok", "hermes":
		// grok reads the Claude document shape (133.8, verified against
		// grok 1.0.3). It was previously dropped by the default branch even
		// though hosts.toml declares delivery_strategy/delivery_event_turn for
		// it, which left those keys as config that nothing consumed.
		return map[string]interface{}{
			"hooks": hooks,
		}, true
	default:
		return nil, false
	}
}

func deliveryTurnGroups(h Host, entry commandEntry) interface{} {
	switch h.Name {
	case "cursor":
		return []cursorEntry{
			{Type: entry.Type, Command: entry.Command, Matcher: deliveryMatcher, Timeout: entry.Timeout},
		}
	default:
		return []matcherGroup{
			{Matcher: deliveryMatcher, Hooks: []commandEntry{entry}},
		}
	}
}

func GenerateHooksJSON(h Host) ([]byte, error) {
	if h.HookGeneration == "deferred" {
		return nil, fmt.Errorf("hostgen: %s for host %q: %w", h.HookGeneration, h.Name, ErrHookGenerationDeferred)
	}
	var doc map[string]interface{}
	switch h.Name {
	case "cursor":
		doc = cursorDoc(h)
	case "codex":
		doc = codexDoc(h)
	case "claude":
		doc = claudeDoc(h)
	case "grok":
		doc = grokDoc(h)
	case "hermes":
		// Hermes hooks are declared in ~/.hermes/config.yaml. Keep it out of
		// native hook-file generation while allowing delivery metadata above to
		// be generated and validated independently.
		return nil, fmt.Errorf("hostgen: native hook file is managed by ~/.hermes/config.yaml for host %q: %w", h.Name, ErrHookGenerationDeferred)
	default:
		return nil, fmt.Errorf("hostgen: unknown host %q (expected claude, codex, cursor, grok, or hermes)", h.Name)
	}
	return marshalStable(doc)
}

// commandEntry is one `{type,command,timeout}` hook step (Claude/Codex shape,
// where steps are nested under a matcher group).
type commandEntry struct {
	Type    string `json:"type"`
	Command string `json:"command"`
	Timeout int    `json:"timeout"`
}

// matcherGroup is one `{matcher,hooks:[...]}` group used by Claude and Codex.
type matcherGroup struct {
	Matcher string         `json:"matcher"`
	Hooks   []commandEntry `json:"hooks"`
}

// cursorEntry is one Cursor hook step. Cursor uses a flatter schema: each event
// maps directly to an array of `{command,...}` entries (no matcher wrapper),
// with the matcher inlined as a sibling field.
type cursorEntry struct {
	Type    string `json:"type"`
	Command string `json:"command"`
	Matcher string `json:"matcher"`
	Timeout int    `json:"timeout"`
}

func claudeDoc(h Host) map[string]interface{} {
	return map[string]interface{}{
		"hooks": map[string]interface{}{
			h.HookEvent: []matcherGroup{
				{
					Matcher: h.Matcher,
					Hooks: []commandEntry{
						{Type: "command", Command: ClaudePreToolCommand, Timeout: 10},
					},
				},
			},
		},
	}
}

// grokDoc emits the Claude-shaped hooks document grok reads.
//
// grok 1.0.3 reports `Harness Compatibility → claude → hooks on (default)` and
// discovers other plugins' hooks from `hooks/hooks.json` in the Claude layout,
// so the document shape is Claude's — only the routed host differs. The command
// carries `--host grok` so the policy engine records the calling host; the
// decision itself is byte-identical to `--host claude` (probed 2026-08-13,
// re-probed 2026-08-14).
func grokDoc(h Host) map[string]interface{} {
	return map[string]interface{}{
		"hooks": map[string]interface{}{
			h.HookEvent: []matcherGroup{
				{
					Matcher: h.Matcher,
					Hooks: []commandEntry{
						{Type: "command", Command: binCommand(h.Name), Timeout: 10},
					},
				},
			},
		},
	}
}

func codexDoc(h Host) map[string]interface{} {
	return map[string]interface{}{
		"hooks": map[string]interface{}{
			h.HookEvent: []matcherGroup{
				{
					Matcher: h.Matcher,
					Hooks: []commandEntry{
						{Type: "command", Command: binCommand(h.Name), Timeout: 30},
					},
				},
			},
		},
	}
}

func cursorDoc(h Host) map[string]interface{} {
	return map[string]interface{}{
		"version": 1,
		"hooks": map[string]interface{}{
			h.HookEvent: []cursorEntry{
				{Type: "command", Command: binCommand(h.Name), Matcher: h.Matcher, Timeout: 30},
			},
		},
	}
}

// binCommand returns the harness binary invocation Codex/Cursor write into their
// command field. Codex and Cursor pass an explicit `--host <name>` so the codec
// (go/internal/hookcodec) renders that host's native deny shape; e.g.
// `bin/harness hook pre-tool --host codex`. Claude is invoked via its valid_root
// wrapper (ClaudePreToolCommand) with no flag — the codec treats the empty host
// as the Claude default. The host string is taken verbatim from the [host] table
// key, so a hosts.toml typo surfaces as a wrong flag in the golden diff.
// binCommand builds the direct binary invocation used by every host except
// Claude, which needs the ClaudePreToolCommand bootstrap wrapper instead.
//
// The condition excludes "claude" rather than enumerating the other hosts: an
// allowlist silently drops `--host` for any host added later, and the decoder
// then reads the missing flag as Claude's default. 133.8 hit exactly that when
// grok was added.
func binCommand(host string) string {
	cmd := claudeBinary + " " + preToolCommand
	if host != "" && host != "claude" {
		cmd += " --host " + host
	}
	return cmd
}

// marshalStable JSON-encodes v with sorted keys, 2-space indentation, no HTML
// escaping, and a trailing newline so generator output is byte-stable across
// runs (Go's json package already sorts map keys; the explicit settings pin the
// rest of the format).
func marshalStable(v interface{}) ([]byte, error) {
	var buf bytes.Buffer
	enc := json.NewEncoder(&buf)
	enc.SetEscapeHTML(false)
	enc.SetIndent("", "  ")
	if err := enc.Encode(v); err != nil {
		return nil, fmt.Errorf("hostgen: marshal error: %w", err)
	}
	return buf.Bytes(), nil
}

// SortedNames returns the host names in deterministic order. Useful for callers
// that iterate hosts for stable output (e.g. `harness gen --check`).
func SortedNames(hosts map[string]Host) []string {
	names := make([]string, 0, len(hosts))
	for name := range hosts {
		names = append(names, name)
	}
	sort.Strings(names)
	return names
}
