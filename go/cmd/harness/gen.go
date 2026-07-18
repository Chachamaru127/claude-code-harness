package main

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"reflect"
	"strings"

	"github.com/Chachamaru127/claude-code-harness/go/internal/docsgen"
	"github.com/Chachamaru127/claude-code-harness/go/internal/hostgen"
)

// hostsDescriptorName is the single descriptor file at the repo root that drives
// `harness gen`.
const hostsDescriptorName = "hosts.toml"

// runGen handles `harness gen [hooks|docs] [--check] [root]`.
//
// Phase 91.3 convergence core: a single hosts.toml describes each host's
// pre-action hook differences, and `harness gen` materializes each host's native
// hooks.json so Claude, Codex, and Cursor all invoke `bin/harness hook pre-tool`
// (one R01-R13 policy engine for every host).
//
//	harness gen            — write each host's generated hooks.json to its hook_path
//	harness gen hooks      — alias for the above
//	harness gen --check    — compare generated codex+cursor output against golden
//	                         fixtures byte-for-byte; exit 1 on any mismatch
//	harness gen docs       — regenerate the SKILL CATALOG section of
//	                         docs/CLAUDE-skill-catalog.md from skills/*/SKILL.md
//	harness gen docs --check — diff the generated catalog vs the committed file;
//	                         exit 1 on mismatch
//
// The tracked .claude-plugin/hooks.json (claude) is NEVER overwritten by the
// hooks path: its full event set is hand-maintained and stays committed because
// the Claude marketplace reads it directly (Model A — see spec.md Host
// Distribution Contract). `harness gen` prints a skip line for claude and writes
// only .codex/hooks.json and .cursor/hooks.json (both gitignored generated
// artifacts for local dev). `harness gen --check` separately verifies that the
// committed Claude PreToolUse guardrail group still matches hosts.toml, so the
// shared pre-action route cannot drift even though that file is not generated.
func runGen(args []string) {
	// Subcommand dispatch: `docs` routes to the catalog generator. `hooks`
	// (or no subcommand) stays on the host-hooks path below.
	if len(args) > 0 && args[0] == "docs" {
		runGenDocs(args[1:])
		return
	}

	check := false
	var positional []string
	for _, a := range args {
		switch a {
		case "--check":
			check = true
		case "hooks":
			// `gen` and `gen hooks` are equivalent in this phase.
		default:
			positional = append(positional, a)
		}
	}

	root, err := resolveGenRoot(positional)
	if err != nil {
		fmt.Fprintf(os.Stderr, "gen: %v\n", err)
		os.Exit(1)
	}

	if check {
		os.Exit(runGenCheck(root))
	}
	if err := runGenWrite(root); err != nil {
		fmt.Fprintf(os.Stderr, "gen: %v\n", err)
		os.Exit(1)
	}
}

// runGenDocs handles `harness gen docs [--check] [root]`: it regenerates the
// machine-managed SKILL CATALOG region of docs/CLAUDE-skill-catalog.md from the
// frontmatter of every skills/*/SKILL.md. With --check it does not write; it
// exits 1 when the committed catalog has drifted from what the generator would
// produce (so CI can pin the catalog as the source of truth).
func runGenDocs(args []string) {
	check := false
	var positional []string
	for _, a := range args {
		switch a {
		case "--check":
			check = true
		default:
			positional = append(positional, a)
		}
	}

	root, err := resolveGenRoot(positional)
	if err != nil {
		fmt.Fprintf(os.Stderr, "gen docs: %v\n", err)
		os.Exit(1)
	}

	if check {
		inSync, diff, checkErr := docsgen.Check(root)
		if checkErr != nil {
			fmt.Fprintf(os.Stderr, "gen docs --check: %v\n", checkErr)
			os.Exit(1)
		}
		if !inSync {
			fmt.Printf("gen docs --check: MISMATCH for %s (committed vs generated)\n", docsgen.CatalogRelPath)
			fmt.Print(diff)
			fmt.Fprintln(os.Stderr, "gen docs --check: catalog drifted from skills/*/SKILL.md (run `harness gen docs`)")
			os.Exit(1)
		}
		fmt.Printf("gen docs --check: %s matches skills/*/SKILL.md\n", docsgen.CatalogRelPath)
		os.Exit(0)
	}

	changed, writeErr := docsgen.Write(root)
	if writeErr != nil {
		fmt.Fprintf(os.Stderr, "gen docs: %v\n", writeErr)
		os.Exit(1)
	}
	if changed {
		fmt.Printf("gen docs: %s regenerated from skills/*/SKILL.md\n", docsgen.CatalogRelPath)
	} else {
		fmt.Printf("gen docs: %s already up to date\n", docsgen.CatalogRelPath)
	}
}

// resolveGenRoot finds the repo root that contains hosts.toml. An explicit
// positional arg wins; otherwise it walks up from the working directory (dev
// invocations run from go/ or the repo root) until hosts.toml is found, falling
// back to the working directory.
func resolveGenRoot(args []string) (string, error) {
	if len(args) > 0 {
		abs, err := filepath.Abs(args[0])
		if err != nil {
			return "", fmt.Errorf("invalid root %q: %w", args[0], err)
		}
		return abs, nil
	}
	cwd, err := os.Getwd()
	if err != nil {
		return "", fmt.Errorf("cannot determine working directory: %w", err)
	}
	dir := cwd
	for {
		if _, statErr := os.Stat(filepath.Join(dir, hostsDescriptorName)); statErr == nil {
			return dir, nil
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			break
		}
		dir = parent
	}
	return cwd, nil
}

// generatedHooks loads hosts.toml from root and returns each host's generated
// hooks.json bytes keyed by host name. Factored out so `--check` and the tests
// can obtain the generator output without writing files or shelling out.
func generatedHooks(root string) (map[string][]byte, error) {
	hosts, err := hostgen.Load(filepath.Join(root, hostsDescriptorName))
	if err != nil {
		return nil, err
	}
	out := make(map[string][]byte, len(hosts))
	for _, name := range hostgen.SortedNames(hosts) {
		b, genErr := generateHostHooksJSON(hosts[name])
		if genErr != nil {
			if errors.Is(genErr, hostgen.ErrHookGenerationDeferred) {
				continue
			}
			return nil, genErr
		}
		out[name] = b
	}
	return out, nil
}

func generateHostHooksJSON(h hostgen.Host) ([]byte, error) {
	enforcement, err := hostgen.GenerateHooksJSON(h)
	if err != nil {
		return nil, err
	}
	delivery, ok, err := hostgen.GenerateDeliveryHooksJSON(h)
	if err != nil {
		return nil, err
	}
	if !ok {
		return enforcement, nil
	}
	return mergeHooksJSON(enforcement, delivery)
}

func mergeHooksJSON(base, extra []byte) ([]byte, error) {
	var baseDoc map[string]interface{}
	if err := json.Unmarshal(base, &baseDoc); err != nil {
		return nil, fmt.Errorf("parse generated enforcement hooks: %w", err)
	}
	var extraDoc map[string]interface{}
	if err := json.Unmarshal(extra, &extraDoc); err != nil {
		return nil, fmt.Errorf("parse generated delivery hooks: %w", err)
	}
	baseHooks, err := hooksMap(baseDoc)
	if err != nil {
		return nil, fmt.Errorf("enforcement hooks: %w", err)
	}
	extraHooks, err := hooksMap(extraDoc)
	if err != nil {
		return nil, fmt.Errorf("delivery hooks: %w", err)
	}
	for event, groups := range extraHooks {
		if _, exists := baseHooks[event]; exists {
			return nil, fmt.Errorf("refusing to overwrite generated hooks.%s while adding delivery hooks", event)
		}
		baseHooks[event] = groups
	}
	return marshalGenJSON(baseDoc)
}

func hooksMap(doc map[string]interface{}) (map[string]interface{}, error) {
	raw, ok := doc["hooks"]
	if !ok {
		return nil, fmt.Errorf("missing hooks key")
	}
	hooks, ok := raw.(map[string]interface{})
	if !ok {
		return nil, fmt.Errorf("hooks key is %T, want object", raw)
	}
	return hooks, nil
}

func marshalGenJSON(v interface{}) ([]byte, error) {
	var buf bytes.Buffer
	enc := json.NewEncoder(&buf)
	enc.SetEscapeHTML(false)
	enc.SetIndent("", "  ")
	if err := enc.Encode(v); err != nil {
		return nil, fmt.Errorf("marshal generated hooks: %w", err)
	}
	return buf.Bytes(), nil
}

// runGenWrite writes the generated codex/cursor hooks.json to their hook_path
// and skips the tracked claude config.
func runGenWrite(root string) error {
	hosts, err := hostgen.Load(filepath.Join(root, hostsDescriptorName))
	if err != nil {
		return err
	}
	for _, name := range hostgen.SortedNames(hosts) {
		h := hosts[name]
		dest := filepath.Join(root, filepath.FromSlash(h.HookPath))
		if name == "claude" {
			fmt.Printf("gen: %-7s %s  skipped (tracked, hand-maintained; PreToolUse drift-checked)\n", name, h.HookPath)
			continue
		}
		data, genErr := generateHostHooksJSON(h)
		if genErr != nil {
			if errors.Is(genErr, hostgen.ErrHookGenerationDeferred) {
				fmt.Printf("gen: %-7s %s  skipped (native hook generation deferred)\n", name, h.HookPath)
				continue
			}
			return genErr
		}
		if mkErr := os.MkdirAll(filepath.Dir(dest), 0o755); mkErr != nil {
			return fmt.Errorf("gen: cannot create dir for %s: %w", h.HookPath, mkErr)
		}
		if wErr := os.WriteFile(dest, data, 0o644); wErr != nil {
			return fmt.Errorf("gen: cannot write %s: %w", h.HookPath, wErr)
		}
		fmt.Printf("gen: %-7s %s  written (%d bytes)\n", name, h.HookPath, len(data))
	}
	return nil
}

// runGenCheck regenerates codex+cursor hooks in memory and compares them against
// the golden fixtures under cmd/harness/testdata/gen/. Returns 0 when every
// fixture matches byte-for-byte and 1 otherwise (printing a line-level diff).
// The claude config is excluded because this phase does not regenerate the
// tracked file.
func runGenCheck(root string) int {
	gen, err := generatedHooks(root)
	if err != nil {
		fmt.Fprintf(os.Stderr, "gen --check: %v\n", err)
		return 1
	}
	fixtureDir := filepath.Join(root, "go", "cmd", "harness", "testdata", "gen")
	// When invoked from within go/ (dev default), the repo root resolver may
	// return the go/ dir itself if hosts.toml is not above it; guard by also
	// trying a path relative to the located root.
	if _, statErr := os.Stat(fixtureDir); statErr != nil {
		fixtureDir = filepath.Join(root, "cmd", "harness", "testdata", "gen")
	}

	hosts := []string{"codex", "cursor"}
	ok := true
	for _, name := range hosts {
		want, readErr := os.ReadFile(filepath.Join(fixtureDir, name+"-hooks.json"))
		if readErr != nil {
			fmt.Fprintf(os.Stderr, "gen --check: cannot read golden fixture for %s: %v\n", name, readErr)
			ok = false
			continue
		}
		got := gen[name]
		if !bytes.Equal(want, got) {
			ok = false
			fmt.Printf("gen --check: MISMATCH for %s (golden vs generated)\n", name)
			fmt.Print(unifiedDiff(string(want), string(got)))
		} else {
			fmt.Printf("gen --check: %s OK\n", name)
		}
	}
	// Claude's full hooks.json is hand-maintained (27 events); only its
	// security-critical PreToolUse wiring is generator-owned. Verify the committed
	// entry still matches what hostgen produces from hosts.toml so the R01-R13
	// pre-action route cannot silently drift from the single host descriptor.
	if err := checkClaudePreToolDrift(root); err != nil {
		ok = false
		fmt.Printf("gen --check: MISMATCH for claude PreToolUse — %v\n", err)
	} else {
		fmt.Println("gen --check: claude PreToolUse OK")
	}
	if !ok {
		fmt.Fprintln(os.Stderr, "gen --check: generated output drifted from source (run `harness gen` / fix hosts.toml or the committed config)")
		return 1
	}
	fmt.Println("gen --check: all hosts match (codex+cursor fixtures, claude PreToolUse)")
	return 0
}

// checkClaudePreToolDrift verifies the committed .claude-plugin/hooks.json
// PreToolUse entry matches what hostgen generates for the [claude] host in
// hosts.toml. The remaining hand-maintained events in that file are out of scope
// (validate-plugin.sh validates their structure); this gate covers only the
// generator-owned pre-action route so the one R01-R13 entrypoint shared by all
// three hosts cannot drift from the single descriptor. The full file stays
// committed because the Claude marketplace clones the repo and reads it directly
// — there is no install-time generation step (see spec.md Host Distribution).
func checkClaudePreToolDrift(root string) error {
	hosts, err := hostgen.Load(filepath.Join(root, hostsDescriptorName))
	if err != nil {
		return err
	}
	claude, ok := hosts["claude"]
	if !ok {
		return fmt.Errorf("hosts.toml has no [claude] table")
	}
	genBytes, err := hostgen.GenerateHooksJSON(claude)
	if err != nil {
		return err
	}
	wantGroups, err := extractEventGroups(genBytes, claude.HookEvent)
	if err != nil {
		return fmt.Errorf("generated: %w", err)
	}
	committedPath := filepath.Join(root, ".claude-plugin", "hooks.json")
	committedBytes, err := os.ReadFile(committedPath)
	if err != nil {
		return fmt.Errorf("cannot read %s: %w", committedPath, err)
	}
	gotGroups, err := extractEventGroups(committedBytes, claude.HookEvent)
	if err != nil {
		return fmt.Errorf(".claude-plugin/hooks.json: %w", err)
	}
	// The committed file legitimately carries several PreToolUse hook groups: the
	// R01-R13 guardrail group is one, alongside hand-maintained pre-action hooks
	// (TDD checks, file leases, etc.). The generator owns only the guardrail
	// group, so the contract is containment — every generated group must appear
	// verbatim among the committed groups; anything else in the committed file is
	// allowed. This drift-proofs the guardrail route (matcher + valid_root command
	// + timeout) against hosts.toml without claiming to own the whole file.
	for _, want := range wantGroups {
		found := false
		for _, got := range gotGroups {
			if reflect.DeepEqual(want, got) {
				found = true
				break
			}
		}
		if !found {
			return fmt.Errorf("the generated %s guardrail group is absent from committed .claude-plugin/hooks.json (pre-action wiring drifted from hosts.toml)", claude.HookEvent)
		}
	}
	return nil
}

// extractEventGroups parses a hooks.json document and returns the array of hook
// groups at hooks.<event>, each decoded generically so groups can be compared
// semantically (independent of key order or whitespace).
func extractEventGroups(doc []byte, event string) ([]interface{}, error) {
	var parsed struct {
		Hooks map[string]json.RawMessage `json:"hooks"`
	}
	if err := json.Unmarshal(doc, &parsed); err != nil {
		return nil, fmt.Errorf("parse hooks json: %w", err)
	}
	raw, ok := parsed.Hooks[event]
	if !ok {
		return nil, fmt.Errorf("missing hooks.%s entry", event)
	}
	var groups []interface{}
	if err := json.Unmarshal(raw, &groups); err != nil {
		return nil, fmt.Errorf("parse hooks.%s: %w", event, err)
	}
	return groups, nil
}

// unifiedDiff renders a minimal line-by-line diff between want and got. It is
// intentionally simple (per-line markers, not an LCS algorithm) — enough to show
// where generator output diverged from a fixture.
func unifiedDiff(want, got string) string {
	wl := strings.Split(want, "\n")
	gl := strings.Split(got, "\n")
	n := len(wl)
	if len(gl) > n {
		n = len(gl)
	}
	var b strings.Builder
	for i := 0; i < n; i++ {
		var w, g string
		if i < len(wl) {
			w = wl[i]
		}
		if i < len(gl) {
			g = gl[i]
		}
		if w == g {
			continue
		}
		if i < len(wl) {
			fmt.Fprintf(&b, "  - %s\n", w)
		}
		if i < len(gl) {
			fmt.Fprintf(&b, "  + %s\n", g)
		}
	}
	return b.String()
}
