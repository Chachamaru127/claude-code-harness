package main

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
)

// runDoctor implements the "harness doctor [--migration] [--migration-report] [--residue]" subcommand.
//
// Without flags: performs basic health checks on the project:
//   - Go binary version
//   - harness.toml existence
//   - hooks.json existence + JSON validity
//   - settings.json existence + JSON validity
//   - plugin.json existence + JSON validity
//   - state.db existence (checks ${CLAUDE_PLUGIN_DATA} and .harness/)
//   - bin/harness PATH resolution
//
// With --migration: additionally shows hook migration status (Go vs shell).
// With --migration-report: prints a non-destructive existing-user migration report.
// With --residue: calls scripts/check-residue.sh to detect v3 migration remnants.
//
// Both flags are independent and can be combined.
func runDoctor(args []string) {
	migration := false
	migrationReport := false
	residue := false
	var rootOverride string
	for _, arg := range args {
		switch arg {
		case "--migration":
			migration = true
		case "--migration-report":
			migrationReport = true
		case "--residue":
			residue = true
		default:
			rootOverride = arg
		}
	}

	projectRoot, err := resolveProjectRoot([]string{rootOverride})
	if err != nil {
		fmt.Fprintf(os.Stderr, "harness doctor: %v\n", err)
		os.Exit(1)
	}

	fmt.Println("harness doctor")
	fmt.Println()

	allOK := runBasicChecks(projectRoot)

	if migration {
		fmt.Println()
		migrationOK := runMigrationCheck(projectRoot)
		if !migrationOK {
			allOK = false
		}
	}

	if migrationReport {
		fmt.Println()
		reportOK := runMigrationReportCheck(projectRoot)
		if !reportOK {
			allOK = false
		}
	}

	if residue {
		fmt.Println()
		exitCode := runResidueCheck(projectRoot)
		if exitCode != 0 {
			allOK = false
		}
	}

	fmt.Println()
	if allOK {
		fmt.Println("All checks passed.")
	} else {
		fmt.Println("Some checks failed. See above for details.")
		os.Exit(1)
	}
}

// ---------------------------------------------------------------------------
// Basic checks
// ---------------------------------------------------------------------------

// checkResult holds the result of a single doctor check.
type checkResult struct {
	label  string
	ok     bool
	detail string
}

// runBasicChecks performs basic health checks and prints them.
// Returns true if all checks pass.
func runBasicChecks(projectRoot string) bool {
	results := []checkResult{
		checkVersion(),
		checkFileExists(projectRoot, "harness.toml", false),
		checkJSONFile(projectRoot, "hooks/hooks.json"),
		checkJSONFile(projectRoot, ".claude-plugin/settings.json"),
		checkJSONFile(projectRoot, ".claude-plugin/plugin.json"),
		checkStateDB(projectRoot),
		checkBinaryInPath(),
		// v4.0 Hokage — new checks
		checkVersionMatch(projectRoot),
		checkHooksGoPattern(projectRoot),
		checkPlatformBinary(projectRoot),
		checkNodeNotRequired(projectRoot),
	}

	allOK := true
	for _, r := range results {
		printCheck(r)
		if !r.ok {
			allOK = false
		}
	}
	return allOK
}

// checkVersion reports the current harness binary version.
func checkVersion() checkResult {
	return checkResult{
		label:  "harness version",
		ok:     true,
		detail: version,
	}
}

// checkFileExists checks whether a file exists at path relative to projectRoot.
// If warnOnly is true the check is non-critical (still ok=true if missing but shown as warning).
func checkFileExists(projectRoot, relPath string, warnOnly bool) checkResult {
	fullPath := filepath.Join(projectRoot, relPath)
	_, err := os.Stat(fullPath)
	exists := err == nil
	label := relPath + " exists"
	if exists {
		return checkResult{label: label, ok: true, detail: fullPath}
	}
	if warnOnly {
		return checkResult{label: label, ok: true, detail: "not found (optional)"}
	}
	return checkResult{label: label, ok: false, detail: fmt.Sprintf("not found: %s", fullPath)}
}

// checkJSONFile checks whether a JSON file exists and contains valid JSON.
func checkJSONFile(projectRoot, relPath string) checkResult {
	fullPath := filepath.Join(projectRoot, relPath)
	label := relPath + " valid JSON"

	data, err := os.ReadFile(fullPath)
	if err != nil {
		return checkResult{label: label, ok: false, detail: fmt.Sprintf("not found: %s", fullPath)}
	}
	if !json.Valid(data) {
		return checkResult{label: label, ok: false, detail: fmt.Sprintf("invalid JSON: %s", fullPath)}
	}
	return checkResult{label: label, ok: true, detail: fullPath}
}

// checkStateDB checks for state.db in ${CLAUDE_PLUGIN_DATA} or .harness/.
func checkStateDB(projectRoot string) checkResult {
	label := "state.db exists"

	// Check ${CLAUDE_PLUGIN_DATA}/state.db
	if pluginData := os.Getenv("CLAUDE_PLUGIN_DATA"); pluginData != "" {
		p := filepath.Join(pluginData, "state.db")
		if _, err := os.Stat(p); err == nil {
			return checkResult{label: label, ok: true, detail: p}
		}
	}

	// Check .harness/state.db
	harnessPath := filepath.Join(projectRoot, ".harness", "state.db")
	if _, err := os.Stat(harnessPath); err == nil {
		return checkResult{label: label, ok: true, detail: harnessPath}
	}

	// Not found in either location — not a hard failure (db may not exist yet)
	return checkResult{label: label, ok: true, detail: "not found (will be created on first run)"}
}

// checkBinaryInPath checks whether bin/harness is resolvable via PATH.
func checkBinaryInPath() checkResult {
	label := "bin/harness in PATH"

	// Look through PATH for a "harness" binary
	pathEnv := os.Getenv("PATH")
	if pathEnv == "" {
		return checkResult{label: label, ok: false, detail: "PATH is empty"}
	}

	for _, dir := range filepath.SplitList(pathEnv) {
		candidate := filepath.Join(dir, "harness")
		if info, err := os.Stat(candidate); err == nil && !info.IsDir() {
			return checkResult{label: label, ok: true, detail: candidate}
		}
	}
	return checkResult{label: label, ok: false, detail: "harness not found in PATH — run 'go install' or add bin/ to PATH"}
}

// ---------------------------------------------------------------------------
// v4.0 Hokage — additional checks
// ---------------------------------------------------------------------------

// checkVersionMatch verifies that the binary version matches the VERSION file.
// A mismatch typically means the binary was not rebuilt after a version bump.
func checkVersionMatch(projectRoot string) checkResult {
	label := "binary version matches VERSION file"

	versionFilePath := filepath.Join(projectRoot, "VERSION")
	data, err := os.ReadFile(versionFilePath)
	if err != nil {
		// VERSION file not found — skip rather than fail
		return checkResult{label: label, ok: true, detail: "VERSION file not found (skipped)"}
	}

	fileVersion := strings.TrimSpace(string(data))
	if fileVersion == "" {
		return checkResult{label: label, ok: true, detail: "VERSION file is empty (skipped)"}
	}

	// version is the binary variable set via -ldflags (may be "dev" in local builds)
	if version == "dev" {
		return checkResult{label: label, ok: true, detail: fmt.Sprintf("binary version is 'dev' (local build), VERSION=%s", fileVersion)}
	}

	if version != fileVersion {
		return checkResult{
			label:  label,
			ok:     true, // advisory only
			detail: fmt.Sprintf("⚠️ Binary version mismatch: binary=%s, VERSION=%s. Run: cd go && make install", version, fileVersion),
		}
	}
	return checkResult{label: label, ok: true, detail: fmt.Sprintf("%s", fileVersion)}
}

// reBashHook matches hook command strings that invoke bash explicitly.
var reBashHook = regexp.MustCompile(`\bbash\b`)

// checkHooksGoPattern inspects hooks.json for legacy bash hooks.
// Command-type hooks should use "bin/harness hook" in v4; bash invocations are legacy.
func checkHooksGoPattern(projectRoot string) checkResult {
	label := "hooks.json uses Go binary pattern"

	hooksPath := filepath.Join(projectRoot, "hooks", "hooks.json")
	data, err := os.ReadFile(hooksPath)
	if err != nil {
		// Fallback to .claude-plugin/hooks.json
		hooksPath = filepath.Join(projectRoot, ".claude-plugin", "hooks.json")
		data, err = os.ReadFile(hooksPath)
		if err != nil {
			return checkResult{label: label, ok: true, detail: "hooks.json not found (skipped)"}
		}
	}

	var schema hooksJSONSchema
	if err := json.Unmarshal(data, &schema); err != nil {
		return checkResult{label: label, ok: true, detail: "hooks.json parse error (skipped)"}
	}

	var legacyCommands []string
	for _, groups := range schema.Hooks {
		for _, group := range groups {
			for _, entry := range group.Hooks {
				if entry.Type != "command" {
					continue
				}
				if reBashHook.MatchString(entry.Command) {
					legacyCommands = append(legacyCommands, entry.Command)
				}
			}
		}
	}

	if len(legacyCommands) > 0 {
		// Report only the first legacy command to keep output concise
		return checkResult{
			label:  label,
			ok:     true, // advisory only
			detail: fmt.Sprintf("⚠️ Legacy bash hook detected: %s. Run: harness sync", legacyCommands[0]),
		}
	}
	return checkResult{label: label, ok: true, detail: "all command hooks use Go binary pattern"}
}

// checkPlatformBinary verifies that bin/harness exists and is executable.
// The binary is built from Go source (not committed); run `make build` to generate it.
func checkPlatformBinary(projectRoot string) checkResult {
	label := "bin/harness built"
	binaryPath := filepath.Join(projectRoot, "bin", "harness")

	info, err := os.Stat(binaryPath)
	if err == nil && info.Mode()&0o111 != 0 {
		return checkResult{label: label, ok: true, detail: binaryPath}
	}
	return checkResult{
		label:  label,
		ok:     false,
		detail: fmt.Sprintf("bin/harness not found or not executable. Run: make build  (or: cd go && go build -o ../bin/harness ./cmd/harness/)"),
	}
}

var reLegacyHooksNodeDeps = regexp.MustCompile(`node\t|run-script`)

// checkNodeNotRequired verifies that hooks/ no longer contains legacy Node.js
// runtime references such as "node<TAB>" or "run-script".
func checkNodeNotRequired(projectRoot string) checkResult {
	label := "Node.js dependency"
	hooksDir := filepath.Join(projectRoot, "hooks")

	if _, err := os.Stat(hooksDir); err != nil {
		if os.IsNotExist(err) {
			return checkResult{
				label:  label,
				ok:     true,
				detail: "hooks/ not found (skipped)",
			}
		}
		return checkResult{
			label:  label,
			ok:     false,
			detail: fmt.Sprintf("failed to inspect hooks/: %v", err),
		}
	}

	var matches []string
	walkErr := filepath.Walk(hooksDir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if info.IsDir() {
			return nil
		}
		data, err := os.ReadFile(path)
		if err != nil {
			return err
		}
		if reLegacyHooksNodeDeps.Match(data) {
			rel, relErr := filepath.Rel(projectRoot, path)
			if relErr != nil {
				rel = path
			}
			matches = append(matches, filepath.ToSlash(rel))
		}
		return nil
	})
	if walkErr != nil {
		return checkResult{
			label:  label,
			ok:     false,
			detail: fmt.Sprintf("failed to scan hooks/: %v", walkErr),
		}
	}

	if len(matches) > 0 {
		return checkResult{
			label:  label,
			ok:     false,
			detail: fmt.Sprintf("legacy Node.js hook reference found in %s", matches[0]),
		}
	}

	return checkResult{
		label:  label,
		ok:     true,
		detail: "hooks/ contains no legacy Node.js hook references",
	}
}

// printCheck prints a single check result.
func printCheck(r checkResult) {
	mark := "OK  "
	if !r.ok {
		mark = "FAIL"
	}
	if r.detail != "" {
		fmt.Printf("  [%s] %s — %s\n", mark, r.label, r.detail)
	} else {
		fmt.Printf("  [%s] %s\n", mark, r.label)
	}
}

// ---------------------------------------------------------------------------
// Migration check
// ---------------------------------------------------------------------------

// hooksMigrationResult holds per-event migration statistics.
type hooksMigrationResult struct {
	event   string
	total   int
	goCount int
	shell   int
}

// status returns "go", "shell", "partial", or "empty".
func (h hooksMigrationResult) status() string {
	if h.total == 0 {
		return "empty"
	}
	if h.goCount == h.total {
		return "go"
	}
	if h.shell == h.total {
		return "shell"
	}
	return "partial"
}

// hooksJSONSchema matches the top-level hooks.json structure.
// hooks is a map from event name → list of hook groups.
type hooksJSONSchema struct {
	Hooks map[string][]hookGroup `json:"hooks"`
}

// hookGroup represents one entry in a hook event array (with optional matcher).
type hookGroup struct {
	Matcher string      `json:"matcher,omitempty"`
	Hooks   []hookEntry `json:"hooks"`
}

// hookEntry represents a single hook definition.
type hookEntry struct {
	Type    string `json:"type"`
	Command string `json:"command,omitempty"`
}

// reGoCommand matches hook commands that use the harness binary directly.
// Examples: "harness hook pre-tool", "/path/to/harness hook post-tool"
var reGoCommand = regexp.MustCompile(`(?:^|/)harness\s+hook\b`)

// classifyCommand classifies a hook command string as "go" or "shell".
func classifyCommand(cmd string) string {
	if reGoCommand.MatchString(cmd) {
		return "go"
	}
	// Anything using bash/node/scripts/ is shell
	return "shell"
}

// mixedWarning reports mixed-mode hook events.
type mixedWarning struct {
	event string
	path  string // which hooks.json path
}

// runMigrationCheck reads hooks.json (and the .claude-plugin copy if it exists),
// classifies each command hook as Go or shell, prints a summary table, and
// returns true if there are no warnings.
func runMigrationCheck(projectRoot string) bool {
	fmt.Println("Hook Migration Status:")
	fmt.Println()

	// Primary hooks.json paths in priority order
	paths := []string{
		filepath.Join(projectRoot, "hooks", "hooks.json"),
		filepath.Join(projectRoot, ".claude-plugin", "hooks.json"),
	}

	// Detect divergence between the two copies
	divergence := detectHooksDivergence(paths)

	// Use the first readable file for the migration table
	var schema hooksJSONSchema
	var usedPath string
	for _, p := range paths {
		data, err := os.ReadFile(p)
		if err != nil {
			continue
		}
		if err := json.Unmarshal(data, &schema); err != nil {
			continue
		}
		usedPath = p
		break
	}

	if usedPath == "" {
		fmt.Println("  No hooks.json found — skipping migration check.")
		return false
	}

	// Collect per-event stats
	eventNames := sortedKeys(schema.Hooks)
	results := make([]hooksMigrationResult, 0, len(eventNames))
	totalEntries := 0
	totalGo := 0

	for _, event := range eventNames {
		groups := schema.Hooks[event]
		res := hooksMigrationResult{event: event}

		for _, group := range groups {
			for _, entry := range group.Hooks {
				if entry.Type != "command" {
					// agent / http / prompt hooks are not classified
					continue
				}
				res.total++
				totalEntries++
				if classifyCommand(entry.Command) == "go" {
					res.goCount++
					totalGo++
				} else {
					res.shell++
				}
			}
		}

		results = append(results, res)
	}

	// Print table header
	fmt.Printf("  %-24s  %7s  %4s  %5s  %s\n", "Hook Event", "Entries", "Go", "Shell", "Status")
	fmt.Printf("  %-24s  %7s  %4s  %5s  %s\n",
		strings.Repeat("-", 24), strings.Repeat("-", 7),
		strings.Repeat("-", 4), strings.Repeat("-", 5),
		strings.Repeat("-", 8))

	var mixedEvents []string
	for _, r := range results {
		if r.total == 0 {
			continue
		}
		status := r.status()
		fmt.Printf("  %-24s  %7d  %4d  %5d  %s\n",
			r.event, r.total, r.goCount, r.shell, status)
		if status == "partial" {
			mixedEvents = append(mixedEvents, r.event)
		}
	}

	fmt.Println()

	// Summary
	pct := 0
	if totalEntries > 0 {
		pct = (totalGo * 100) / totalEntries
	}
	fmt.Printf("  Summary: %d/%d entries migrated to Go (%d%%)\n",
		totalGo, totalEntries, pct)

	allOK := true

	// Mixed-mode warnings
	if len(mixedEvents) > 0 {
		fmt.Println()
		fmt.Println("  Warnings:")
		for _, event := range mixedEvents {
			fmt.Printf("    [WARN] %s: mixed Go and shell hooks in same event\n", event)
		}
		allOK = false
	}

	// Divergence warning
	if divergence {
		fmt.Println()
		fmt.Printf("  [WARN] hooks/hooks.json and .claude-plugin/hooks.json differ — run 'harness sync' to re-sync\n")
		allOK = false
	}

	return allOK
}

// detectHooksDivergence returns true if two hooks.json files exist and have
// different content (byte-for-byte comparison is intentionally strict).
func detectHooksDivergence(paths []string) bool {
	var contents [][]byte
	for _, p := range paths {
		data, err := os.ReadFile(p)
		if err != nil {
			continue
		}
		contents = append(contents, data)
	}
	if len(contents) < 2 {
		return false
	}
	if len(contents[0]) != len(contents[1]) {
		return true
	}
	for i := range contents[0] {
		if contents[0][i] != contents[1][i] {
			return true
		}
	}
	return false
}

// sortedKeys returns the keys of a map in sorted order.
func sortedKeys(m map[string][]hookGroup) []string {
	keys := make([]string, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	return keys
}

// ---------------------------------------------------------------------------
// Residue check (Phase 40 — Migration Residue Scanner)
// ---------------------------------------------------------------------------

// runResidueCheck calls scripts/check-residue.sh as a subprocess and
// transparently streams its output to stdout/stderr.
//
// Return values:
//
//	0 — scanner exited cleanly (no residue detected)
//	1 — scanner found migration residue (exit code 1 from script)
//	2 — scanner script not found or failed to launch
func runResidueCheck(projectRoot string) int {
	fmt.Println("Migration Residue Check:")
	fmt.Println()

	script := filepath.Join(projectRoot, "scripts", "check-residue.sh")
	if _, err := os.Stat(script); err != nil {
		fmt.Fprintf(os.Stderr, "  scanner failed: scripts/check-residue.sh not found at %s\n", script)
		return 2
	}

	cmd := exec.Command("bash", script)
	// Pipe scanner output directly to this process's stdout/stderr so that
	// file paths, line numbers, and counts appear transparently to the user.
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Dir = projectRoot

	if err := cmd.Run(); err != nil {
		if exitErr, ok := err.(*exec.ExitError); ok {
			return exitErr.ExitCode()
		}
		fmt.Fprintf(os.Stderr, "  scanner failed: %v\n", err)
		return 2
	}
	return 0
}
