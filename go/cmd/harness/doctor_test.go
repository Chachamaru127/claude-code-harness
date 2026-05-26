package main

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// ---------------------------------------------------------------------------
// TestDoctor_Residue
// ---------------------------------------------------------------------------

// TestDoctor_Residue verifies that runResidueCheck calls scripts/check-residue.sh
// and returns the correct exit code.
//
// This is an integration test that invokes the actual scanner against the
// repository. The scanner is expected to be in a clean state (exit 0) after
// Phase 40 baseline work. Run with -short to skip.
//
// NOTE: The scanner may take up to ~30 seconds on large repositories.
// Future phases may introduce a --fast flag to the scanner for test use.
func TestDoctor_Residue(t *testing.T) {
	if testing.Short() {
		t.Skip("skipping integration test in short mode (scanner can be slow)")
	}

	// Resolve the project root from the test binary's location.
	// The test runs from go/cmd/harness/, so we go up three levels.
	cwd, err := os.Getwd()
	if err != nil {
		t.Fatalf("os.Getwd: %v", err)
	}
	// go up: harness/ -> cmd/ -> go/ -> project root
	projectRoot := filepath.Join(cwd, "..", "..", "..")

	// Verify the scanner script exists at the expected location.
	script := filepath.Join(projectRoot, "scripts", "check-residue.sh")
	if _, err := os.Stat(script); err != nil {
		t.Skipf("scripts/check-residue.sh not found at %s — skipping integration test", script)
	}

	exitCode := runResidueCheck(projectRoot)
	// The scanner must exit 0 (clean state) after Phase 40 baseline commit.
	if exitCode != 0 {
		t.Errorf("runResidueCheck returned exit code %d, want 0 (clean state)", exitCode)
	}
}

// TestDoctor_Residue_MissingScript verifies that runResidueCheck returns exit
// code 2 when the scanner script does not exist.
func TestDoctor_Residue_MissingScript(t *testing.T) {
	dir := t.TempDir() // empty dir — no scripts/check-residue.sh

	exitCode := runResidueCheck(dir)
	if exitCode != 2 {
		t.Errorf("expected exit code 2 when script is missing, got %d", exitCode)
	}
}

// ---------------------------------------------------------------------------
// helpers
// ---------------------------------------------------------------------------

// writeHooksJSON writes a hooks.json file at relPath under dir.
func writeHooksJSON(t *testing.T, dir, relPath string, schema hooksJSONSchema) {
	t.Helper()
	data, err := json.MarshalIndent(schema, "", "  ")
	if err != nil {
		t.Fatalf("marshal hooks.json: %v", err)
	}
	full := filepath.Join(dir, relPath)
	if err := os.MkdirAll(filepath.Dir(full), 0o755); err != nil {
		t.Fatalf("mkdir %s: %v", filepath.Dir(full), err)
	}
	if err := os.WriteFile(full, data, 0o644); err != nil {
		t.Fatalf("write %s: %v", full, err)
	}
}

// makeHooksSchema is a convenience builder for test schemas.
func makeHooksSchema(events map[string][]hookGroup) hooksJSONSchema {
	return hooksJSONSchema{Hooks: events}
}

// ---------------------------------------------------------------------------
// TestDoctor_ClassifyCommand
// ---------------------------------------------------------------------------

// TestDoctor_ClassifyCommand verifies that command strings are classified
// correctly as "go" or "shell".
func TestDoctor_ClassifyCommand(t *testing.T) {
	tests := []struct {
		cmd  string
		want string
	}{
		// Go binary invocations
		{"harness hook pre-tool", "go"},
		{"harness hook post-tool", "go"},
		{"harness hook permission", "go"},
		{"/usr/local/bin/harness hook pre-tool", "go"},
		{"./bin/harness hook pre-tool", "go"},
		// Shell invocations
		{`bash "${CLAUDE_PLUGIN_ROOT}/hooks/pre-tool.sh"`, "shell"},
		{`bash "${CLAUDE_PLUGIN_ROOT}/scripts/run-hook.sh" session-init`, "shell"},
		{`node "${CLAUDE_PLUGIN_ROOT}/scripts/run-script.js" script-name`, "shell"},
		// Edge cases
		{"", "shell"},
	}

	for _, tc := range tests {
		got := classifyCommand(tc.cmd)
		if got != tc.want {
			t.Errorf("classifyCommand(%q) = %q, want %q", tc.cmd, got, tc.want)
		}
	}
}

// ---------------------------------------------------------------------------
// TestDoctor_MigrationStatus_AllShell
// ---------------------------------------------------------------------------

// TestDoctor_MigrationStatus_AllShell verifies that a hooks.json containing
// only shell commands shows 0% migration and no mixed-mode warnings.
func TestDoctor_MigrationStatus_AllShell(t *testing.T) {
	dir := t.TempDir()

	schema := makeHooksSchema(map[string][]hookGroup{
		"PreToolUse": {
			{Hooks: []hookEntry{
				{Type: "command", Command: `bash "${CLAUDE_PLUGIN_ROOT}/hooks/pre-tool.sh"`},
				{Type: "command", Command: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/run-hook.sh" pretooluse-inbox-check`},
			}},
		},
		"SessionStart": {
			{Hooks: []hookEntry{
				{Type: "command", Command: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/run-hook.sh" session-init`},
			}},
		},
	})
	writeHooksJSON(t, dir, "hooks/hooks.json", schema)

	// Build per-event results using the same logic as runMigrationCheck.
	events := schema.Hooks
	eventNames := sortedKeys(events)

	totalEntries := 0
	totalGo := 0
	var mixedEvents []string

	for _, event := range eventNames {
		groups := events[event]
		goCount := 0
		shellCount := 0
		for _, g := range groups {
			for _, e := range g.Hooks {
				if e.Type != "command" {
					continue
				}
				totalEntries++
				if classifyCommand(e.Command) == "go" {
					goCount++
					totalGo++
				} else {
					shellCount++
				}
			}
		}
		r := hooksMigrationResult{event: event, total: goCount + shellCount, goCount: goCount, shell: shellCount}
		if r.status() == "partial" {
			mixedEvents = append(mixedEvents, event)
		}
	}

	if totalGo != 0 {
		t.Errorf("expected 0 Go entries, got %d", totalGo)
	}
	if totalEntries != 3 {
		t.Errorf("expected 3 total entries, got %d", totalEntries)
	}
	if len(mixedEvents) != 0 {
		t.Errorf("expected no mixed events, got %v", mixedEvents)
	}
}

// ---------------------------------------------------------------------------
// TestDoctor_MigrationStatus_Mixed
// ---------------------------------------------------------------------------

// TestDoctor_MigrationStatus_Mixed verifies that an event containing both Go
// and shell commands is detected as "partial" and triggers a mixed warning.
func TestDoctor_MigrationStatus_Mixed(t *testing.T) {
	dir := t.TempDir()

	schema := makeHooksSchema(map[string][]hookGroup{
		"PreToolUse": {
			{Hooks: []hookEntry{
				{Type: "command", Command: "harness hook pre-tool"},                                        // Go
				{Type: "command", Command: `bash "${CLAUDE_PLUGIN_ROOT}/hooks/pre-tool.sh"`},               // shell
				{Type: "command", Command: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/run-hook.sh" inbox-check`}, // shell
			}},
		},
	})
	writeHooksJSON(t, dir, "hooks/hooks.json", schema)

	events := schema.Hooks
	eventNames := sortedKeys(events)

	var mixedEvents []string
	for _, event := range eventNames {
		groups := events[event]
		goCount := 0
		shellCount := 0
		for _, g := range groups {
			for _, e := range g.Hooks {
				if e.Type != "command" {
					continue
				}
				if classifyCommand(e.Command) == "go" {
					goCount++
				} else {
					shellCount++
				}
			}
		}
		r := hooksMigrationResult{event: event, total: goCount + shellCount, goCount: goCount, shell: shellCount}
		if r.status() == "partial" {
			mixedEvents = append(mixedEvents, event)
		}
	}

	if len(mixedEvents) == 0 {
		t.Error("expected mixed-mode warning for PreToolUse, got none")
	}
	found := false
	for _, ev := range mixedEvents {
		if ev == "PreToolUse" {
			found = true
		}
	}
	if !found {
		t.Errorf("expected PreToolUse in mixed events, got %v", mixedEvents)
	}
}

// ---------------------------------------------------------------------------
// TestDoctor_MigrationStatus_FullyMigrated
// ---------------------------------------------------------------------------

// TestDoctor_MigrationStatus_FullyMigrated verifies that when all command
// hooks use the harness binary, the status is "go" and no warnings are issued.
func TestDoctor_MigrationStatus_FullyMigrated(t *testing.T) {
	dir := t.TempDir()

	schema := makeHooksSchema(map[string][]hookGroup{
		"PreToolUse": {
			{Hooks: []hookEntry{
				{Type: "command", Command: "harness hook pre-tool"},
			}},
		},
		"PostToolUse": {
			{Hooks: []hookEntry{
				{Type: "command", Command: "harness hook post-tool"},
			}},
		},
		"PermissionRequest": {
			{Hooks: []hookEntry{
				{Type: "command", Command: "harness hook permission"},
			}},
		},
	})
	writeHooksJSON(t, dir, "hooks/hooks.json", schema)

	events := schema.Hooks
	eventNames := sortedKeys(events)

	totalGo := 0
	totalEntries := 0
	var mixedEvents []string

	for _, event := range eventNames {
		groups := events[event]
		goCount := 0
		shellCount := 0
		for _, g := range groups {
			for _, e := range g.Hooks {
				if e.Type != "command" {
					continue
				}
				totalEntries++
				if classifyCommand(e.Command) == "go" {
					goCount++
					totalGo++
				} else {
					shellCount++
				}
			}
		}
		r := hooksMigrationResult{event: event, total: goCount + shellCount, goCount: goCount, shell: shellCount}
		if r.status() == "partial" {
			mixedEvents = append(mixedEvents, event)
		}
	}

	if totalGo != 3 || totalEntries != 3 {
		t.Errorf("expected 3/3 Go entries, got %d/%d", totalGo, totalEntries)
	}
	if len(mixedEvents) != 0 {
		t.Errorf("expected no mixed events, got %v", mixedEvents)
	}
}

// ---------------------------------------------------------------------------
// TestDoctor_HooksMigrationResult_Status
// ---------------------------------------------------------------------------

// TestDoctor_HooksMigrationResult_Status tests the status() method of
// hooksMigrationResult with various Go/shell combinations.
func TestDoctor_HooksMigrationResult_Status(t *testing.T) {
	tests := []struct {
		name    string
		total   int
		goCount int
		shell   int
		want    string
	}{
		{"empty", 0, 0, 0, "empty"},
		{"all shell", 3, 0, 3, "shell"},
		{"all go", 3, 3, 0, "go"},
		{"partial", 4, 1, 3, "partial"},
		{"partial equal", 2, 1, 1, "partial"},
	}

	for _, tc := range tests {
		r := hooksMigrationResult{
			event:   "TestEvent",
			total:   tc.total,
			goCount: tc.goCount,
			shell:   tc.shell,
		}
		got := r.status()
		if got != tc.want {
			t.Errorf("[%s] status() = %q, want %q", tc.name, got, tc.want)
		}
	}
}

// ---------------------------------------------------------------------------
// TestDoctor_DetectHooksDivergence
// ---------------------------------------------------------------------------

// TestDoctor_DetectHooksDivergence verifies that divergence is detected
// when hooks/hooks.json and .claude-plugin/hooks.json differ.
func TestDoctor_DetectHooksDivergence(t *testing.T) {
	dir := t.TempDir()

	schemaA := makeHooksSchema(map[string][]hookGroup{
		"PreToolUse": {{Hooks: []hookEntry{{Type: "command", Command: "harness hook pre-tool"}}}},
	})
	schemaB := makeHooksSchema(map[string][]hookGroup{
		"PreToolUse": {{Hooks: []hookEntry{{Type: "command", Command: `bash "${CLAUDE_PLUGIN_ROOT}/hooks/pre-tool.sh"`}}}},
	})

	writeHooksJSON(t, dir, "hooks/hooks.json", schemaA)
	writeHooksJSON(t, dir, ".claude-plugin/hooks.json", schemaB)

	paths := []string{
		filepath.Join(dir, "hooks/hooks.json"),
		filepath.Join(dir, ".claude-plugin/hooks.json"),
	}

	if !detectHooksDivergence(paths) {
		t.Error("expected divergence detected, got false")
	}
}

// TestDoctor_DetectHooksDivergence_Identical verifies no divergence is
// reported when both copies are identical.
func TestDoctor_DetectHooksDivergence_Identical(t *testing.T) {
	dir := t.TempDir()

	schema := makeHooksSchema(map[string][]hookGroup{
		"PreToolUse": {{Hooks: []hookEntry{{Type: "command", Command: `bash "${CLAUDE_PLUGIN_ROOT}/hooks/pre-tool.sh"`}}}},
	})

	writeHooksJSON(t, dir, "hooks/hooks.json", schema)
	writeHooksJSON(t, dir, ".claude-plugin/hooks.json", schema)

	paths := []string{
		filepath.Join(dir, "hooks/hooks.json"),
		filepath.Join(dir, ".claude-plugin/hooks.json"),
	}

	if detectHooksDivergence(paths) {
		t.Error("expected no divergence for identical files, got true")
	}
}

// ---------------------------------------------------------------------------
// TestDoctor_CheckJSONFile
// ---------------------------------------------------------------------------

// TestDoctor_CheckJSONFile verifies that checkJSONFile correctly handles
// missing files, invalid JSON, and valid JSON.
func TestDoctor_CheckJSONFile(t *testing.T) {
	dir := t.TempDir()

	// Missing file
	r := checkJSONFile(dir, "missing.json")
	if r.ok {
		t.Error("expected ok=false for missing file")
	}
	if !strings.Contains(r.detail, "not found") {
		t.Errorf("expected 'not found' in detail, got %q", r.detail)
	}

	// Invalid JSON
	invalidPath := filepath.Join(dir, "invalid.json")
	if err := os.WriteFile(invalidPath, []byte("{bad json"), 0o644); err != nil {
		t.Fatal(err)
	}
	r = checkJSONFile(dir, "invalid.json")
	if r.ok {
		t.Error("expected ok=false for invalid JSON")
	}
	if !strings.Contains(r.detail, "invalid JSON") {
		t.Errorf("expected 'invalid JSON' in detail, got %q", r.detail)
	}

	// Valid JSON
	validPath := filepath.Join(dir, "valid.json")
	if err := os.WriteFile(validPath, []byte(`{"key": "value"}`), 0o644); err != nil {
		t.Fatal(err)
	}
	r = checkJSONFile(dir, "valid.json")
	if !r.ok {
		t.Errorf("expected ok=true for valid JSON, got false (detail: %s)", r.detail)
	}
}

// ---------------------------------------------------------------------------
// TestDoctor_CheckStateDB
// ---------------------------------------------------------------------------

// TestDoctor_CheckStateDB verifies state.db discovery via CLAUDE_PLUGIN_DATA
// and the fallback .harness/ directory.
func TestDoctor_CheckStateDB(t *testing.T) {
	dir := t.TempDir()

	// No state.db anywhere — should still be ok=true (optional)
	r := checkStateDB(dir)
	if !r.ok {
		t.Errorf("expected ok=true when state.db is absent (optional), got false")
	}
	if !strings.Contains(r.detail, "not found") {
		t.Errorf("expected 'not found' in detail, got %q", r.detail)
	}

	// Create .harness/state.db
	harnessDir := filepath.Join(dir, ".harness")
	if err := os.MkdirAll(harnessDir, 0o755); err != nil {
		t.Fatal(err)
	}
	dbPath := filepath.Join(harnessDir, "state.db")
	if err := os.WriteFile(dbPath, []byte(""), 0o644); err != nil {
		t.Fatal(err)
	}

	r = checkStateDB(dir)
	if !r.ok {
		t.Errorf("expected ok=true when .harness/state.db exists, got false")
	}
	if r.detail != dbPath {
		t.Errorf("expected detail=%q, got %q", dbPath, r.detail)
	}
}

// TestDoctor_CheckStateDB_ViaEnv verifies that CLAUDE_PLUGIN_DATA env var
// is respected when locating state.db.
func TestDoctor_CheckStateDB_ViaEnv(t *testing.T) {
	pluginDataDir := t.TempDir()

	// Set the env var for this test
	t.Setenv("CLAUDE_PLUGIN_DATA", pluginDataDir)

	dbPath := filepath.Join(pluginDataDir, "state.db")
	if err := os.WriteFile(dbPath, []byte(""), 0o644); err != nil {
		t.Fatal(err)
	}

	projectDir := t.TempDir()
	r := checkStateDB(projectDir)
	if !r.ok {
		t.Errorf("expected ok=true when CLAUDE_PLUGIN_DATA/state.db exists, got false")
	}
	if r.detail != dbPath {
		t.Errorf("expected detail=%q, got %q", dbPath, r.detail)
	}
}

// ---------------------------------------------------------------------------
// TestDoctor_NonCommandHooksSkipped
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// TestDoctor_CheckVersionMatch
// ---------------------------------------------------------------------------

// TestDoctor_CheckVersionMatch_Match verifies that matching binary/VERSION is ok.
func TestDoctor_CheckVersionMatch_Match(t *testing.T) {
	dir := t.TempDir()

	// Write a VERSION file matching the binary version variable.
	versionFile := filepath.Join(dir, "VERSION")
	if err := os.WriteFile(versionFile, []byte("3.17.1\n"), 0o644); err != nil {
		t.Fatal(err)
	}

	// Temporarily override the global version variable.
	orig := version
	version = "3.17.1"
	defer func() { version = orig }()

	r := checkVersionMatch(dir)
	if !r.ok {
		t.Errorf("expected ok=true for matching versions, got false")
	}
	if strings.Contains(r.detail, "mismatch") {
		t.Errorf("expected no mismatch warning, got %q", r.detail)
	}
}

// TestDoctor_CheckVersionMatch_Mismatch verifies that a mismatch produces a warning detail.
func TestDoctor_CheckVersionMatch_Mismatch(t *testing.T) {
	dir := t.TempDir()

	versionFile := filepath.Join(dir, "VERSION")
	if err := os.WriteFile(versionFile, []byte("4.0.0\n"), 0o644); err != nil {
		t.Fatal(err)
	}

	orig := version
	version = "3.17.1"
	defer func() { version = orig }()

	r := checkVersionMatch(dir)
	if !r.ok {
		t.Errorf("expected ok=true (advisory), got false")
	}
	if !strings.Contains(r.detail, "mismatch") {
		t.Errorf("expected 'mismatch' in detail, got %q", r.detail)
	}
	if !strings.Contains(r.detail, "make install") {
		t.Errorf("expected remediation hint 'make install' in detail, got %q", r.detail)
	}
}

// TestDoctor_CheckVersionMatch_DevBuild verifies that "dev" binary version is always ok.
func TestDoctor_CheckVersionMatch_DevBuild(t *testing.T) {
	dir := t.TempDir()

	versionFile := filepath.Join(dir, "VERSION")
	if err := os.WriteFile(versionFile, []byte("4.0.0\n"), 0o644); err != nil {
		t.Fatal(err)
	}

	orig := version
	version = "dev"
	defer func() { version = orig }()

	r := checkVersionMatch(dir)
	if !r.ok {
		t.Errorf("expected ok=true for dev build, got false")
	}
	if strings.Contains(r.detail, "mismatch") {
		t.Errorf("expected no mismatch for dev build, got %q", r.detail)
	}
}

// TestDoctor_CheckVersionMatch_MissingFile verifies graceful handling when VERSION is absent.
func TestDoctor_CheckVersionMatch_MissingFile(t *testing.T) {
	dir := t.TempDir() // no VERSION file

	r := checkVersionMatch(dir)
	if !r.ok {
		t.Errorf("expected ok=true when VERSION file is missing, got false")
	}
	if !strings.Contains(r.detail, "not found") {
		t.Errorf("expected 'not found' in detail, got %q", r.detail)
	}
}

// ---------------------------------------------------------------------------
// TestDoctor_CheckHooksGoPattern
// ---------------------------------------------------------------------------

// TestDoctor_CheckHooksGoPattern_LegacyBash verifies that bash hooks are detected.
func TestDoctor_CheckHooksGoPattern_LegacyBash(t *testing.T) {
	dir := t.TempDir()

	schema := makeHooksSchema(map[string][]hookGroup{
		"PreToolUse": {
			{Hooks: []hookEntry{
				{Type: "command", Command: `bash "${CLAUDE_PLUGIN_ROOT}/hooks/pre-tool.sh"`},
			}},
		},
	})
	writeHooksJSON(t, dir, "hooks/hooks.json", schema)

	r := checkHooksGoPattern(dir)
	if !r.ok {
		t.Errorf("expected ok=true (advisory only), got false")
	}
	if !strings.Contains(r.detail, "Legacy bash hook") {
		t.Errorf("expected 'Legacy bash hook' in detail, got %q", r.detail)
	}
	if !strings.Contains(r.detail, "harness sync") {
		t.Errorf("expected 'harness sync' remediation hint, got %q", r.detail)
	}
}

// TestDoctor_CheckHooksGoPattern_GoOnly verifies that Go-pattern hooks pass cleanly.
func TestDoctor_CheckHooksGoPattern_GoOnly(t *testing.T) {
	dir := t.TempDir()

	schema := makeHooksSchema(map[string][]hookGroup{
		"PreToolUse": {
			{Hooks: []hookEntry{
				{Type: "command", Command: "harness hook pre-tool"},
			}},
		},
	})
	writeHooksJSON(t, dir, "hooks/hooks.json", schema)

	r := checkHooksGoPattern(dir)
	if !r.ok {
		t.Errorf("expected ok=true for Go-pattern hooks, got false")
	}
	if strings.Contains(r.detail, "Legacy") {
		t.Errorf("expected no legacy warning for Go-only hooks, got %q", r.detail)
	}
}

// TestDoctor_CheckHooksGoPattern_MissingFile verifies graceful handling when hooks.json is absent.
func TestDoctor_CheckHooksGoPattern_MissingFile(t *testing.T) {
	dir := t.TempDir() // no hooks.json

	r := checkHooksGoPattern(dir)
	if !r.ok {
		t.Errorf("expected ok=true when hooks.json is missing, got false")
	}
	if !strings.Contains(r.detail, "skipped") {
		t.Errorf("expected 'skipped' in detail, got %q", r.detail)
	}
}

// ---------------------------------------------------------------------------
// TestDoctor_CheckPlatformBinary
// ---------------------------------------------------------------------------

// TestDoctor_CheckPlatformBinary_Present verifies ok when bin/harness exists and is executable.
func TestDoctor_CheckPlatformBinary_Present(t *testing.T) {
	dir := t.TempDir()

	binDir := filepath.Join(dir, "bin")
	if err := os.MkdirAll(binDir, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(binDir, "harness"), []byte(""), 0o755); err != nil {
		t.Fatal(err)
	}

	r := checkPlatformBinary(dir)
	if !r.ok {
		t.Errorf("expected ok=true when bin/harness exists, got false: %s", r.detail)
	}
	if strings.Contains(r.detail, "not found") {
		t.Errorf("expected no 'not found' warning, got %q", r.detail)
	}
}

// TestDoctor_CheckPlatformBinary_Absent verifies error detail when bin/harness is missing.
func TestDoctor_CheckPlatformBinary_Absent(t *testing.T) {
	dir := t.TempDir() // no bin/ directory

	r := checkPlatformBinary(dir)
	if r.ok {
		t.Errorf("expected ok=false when bin/harness is absent, got true")
	}
	if !strings.Contains(r.detail, "bin/harness") {
		t.Errorf("expected 'bin/harness' in detail, got %q", r.detail)
	}
	if !strings.Contains(r.detail, "make build") {
		t.Errorf("expected 'make build' remediation hint, got %q", r.detail)
	}
	if !strings.Contains(r.detail, "go build") {
		t.Errorf("expected 'go build' remediation hint, got %q", r.detail)
	}
}

// ---------------------------------------------------------------------------
// TestDoctor_CheckNodeNotRequired
// ---------------------------------------------------------------------------

// TestDoctor_CheckNodeNotRequired_CleanHooks verifies that hooks/ without
// legacy Node.js references passes the check.
func TestDoctor_CheckNodeNotRequired_CleanHooks(t *testing.T) {
	dir := t.TempDir()
	if err := os.MkdirAll(filepath.Join(dir, "hooks"), 0o755); err != nil {
		t.Fatalf("mkdir hooks: %v", err)
	}
	if err := os.WriteFile(filepath.Join(dir, "hooks", "hooks.json"), []byte(`{"hooks":{}}`), 0o644); err != nil {
		t.Fatalf("write hooks.json: %v", err)
	}
	if err := os.WriteFile(filepath.Join(dir, "hooks", "BEST_PRACTICES.md"), []byte("# Hooks Best Practices\n"), 0o644); err != nil {
		t.Fatalf("write BEST_PRACTICES.md: %v", err)
	}

	r := checkNodeNotRequired(dir)
	if !r.ok {
		t.Fatalf("expected ok=true for clean hooks/, got false: %s", r.detail)
	}
	if !strings.Contains(r.detail, "no legacy Node.js hook references") {
		t.Errorf("expected clean detail, got %q", r.detail)
	}
}

// TestDoctor_CheckNodeNotRequired_DirtyHooks verifies that legacy references
// inside hooks/ are reported.
func TestDoctor_CheckNodeNotRequired_DirtyHooks(t *testing.T) {
	dir := t.TempDir()
	if err := os.MkdirAll(filepath.Join(dir, "hooks"), 0o755); err != nil {
		t.Fatalf("mkdir hooks: %v", err)
	}
	if err := os.WriteFile(filepath.Join(dir, "hooks", "legacy.txt"), []byte("node\tlegacy-call\nrun-script legacy-call\n"), 0o644); err != nil {
		t.Fatalf("write legacy.txt: %v", err)
	}

	r := checkNodeNotRequired(dir)
	if r.ok {
		t.Fatalf("expected ok=false for legacy hooks/, got true: %s", r.detail)
	}
	if !strings.Contains(r.detail, "legacy Node.js hook reference found") {
		t.Errorf("expected legacy reference detail, got %q", r.detail)
	}
	if !strings.Contains(r.detail, "hooks/legacy.txt") {
		t.Errorf("expected matching file path in detail, got %q", r.detail)
	}
}

// ---------------------------------------------------------------------------
// TestDoctor_NonCommandHooksSkipped
// ---------------------------------------------------------------------------

// TestDoctor_NonCommandHooksSkipped verifies that agent/prompt/http hooks
// are not counted in the migration statistics.
func TestDoctor_NonCommandHooksSkipped(t *testing.T) {
	schema := makeHooksSchema(map[string][]hookGroup{
		"PreToolUse": {
			{Hooks: []hookEntry{
				{Type: "agent", Command: ""},  // not counted
				{Type: "prompt", Command: ""}, // not counted
				{Type: "command", Command: `bash "${CLAUDE_PLUGIN_ROOT}/hooks/pre-tool.sh"`}, // shell
			}},
		},
	})

	events := schema.Hooks
	totalEntries := 0
	totalGo := 0

	for _, groups := range events {
		for _, g := range groups {
			for _, e := range g.Hooks {
				if e.Type != "command" {
					continue
				}
				totalEntries++
				if classifyCommand(e.Command) == "go" {
					totalGo++
				}
			}
		}
	}

	if totalEntries != 1 {
		t.Errorf("expected 1 command entry (agent/prompt skipped), got %d", totalEntries)
	}
	if totalGo != 0 {
		t.Errorf("expected 0 Go entries, got %d", totalGo)
	}
}
