package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

// writeSkillFile creates a skills/<name>/SKILL.md under dir with the provided
// content and returns the path to the SKILL.md.
func writeSkillFile(t *testing.T, dir, skillName, content string) string {
	t.Helper()
	skillDir := filepath.Join(dir, "skills", skillName)
	if err := os.MkdirAll(skillDir, 0o755); err != nil {
		t.Fatalf("mkdir %s: %v", skillDir, err)
	}
	path := filepath.Join(skillDir, "SKILL.md")
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatalf("write %s: %v", path, err)
	}
	return path
}

// writeAgentFile creates an agents/<name>.md under dir with the provided
// content and returns the path.
func writeAgentFile(t *testing.T, dir, agentName, content string) string {
	t.Helper()
	agentsDir := filepath.Join(dir, "agents")
	if err := os.MkdirAll(agentsDir, 0o755); err != nil {
		t.Fatalf("mkdir %s: %v", agentsDir, err)
	}
	path := filepath.Join(agentsDir, agentName+".md")
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatalf("write %s: %v", path, err)
	}
	return path
}

// ---------------------------------------------------------------------------
// extractFrontmatter tests
// ---------------------------------------------------------------------------

func TestExtractFrontmatter_Valid(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "SKILL.md")
	content := "---\nname: foo\ndescription: bar\n---\n\n# Body"
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}

	got, err := extractFrontmatter(path)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !strings.Contains(got, "name: foo") {
		t.Errorf("expected frontmatter to contain 'name: foo', got: %q", got)
	}
}

func TestExtractFrontmatter_NoFrontmatter(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "SKILL.md")
	if err := os.WriteFile(path, []byte("# No frontmatter here"), 0o644); err != nil {
		t.Fatal(err)
	}

	got, err := extractFrontmatter(path)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if got != "" {
		t.Errorf("expected empty frontmatter, got %q", got)
	}
}

func TestExtractFrontmatter_UnclosedDelimiter(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "SKILL.md")
	if err := os.WriteFile(path, []byte("---\nname: foo\n# no closing ---"), 0o644); err != nil {
		t.Fatal(err)
	}

	_, err := extractFrontmatter(path)
	if err == nil {
		t.Fatal("expected error for unclosed frontmatter, got nil")
	}
}

// ---------------------------------------------------------------------------
// parseFrontmatterKV tests
// ---------------------------------------------------------------------------

func TestParseFrontmatterKV(t *testing.T) {
	raw := `
name: my-skill
description: "A sample skill"
allowed-tools: ["Read", "Write"]
user-invocable: true
effort: high
`
	kv := parseFrontmatterKV(raw)

	cases := []struct {
		key  string
		want string
	}{
		{"name", "my-skill"},
		{"description", "A sample skill"},
		{"user-invocable", "true"},
		{"effort", "high"},
	}
	for _, c := range cases {
		if got := kv[c.key]; got != c.want {
			t.Errorf("kv[%q] = %q, want %q", c.key, got, c.want)
		}
	}

	// allowed-tools is stored verbatim (brackets intact)
	if !strings.Contains(kv["allowed-tools"], "Read") {
		t.Errorf("allowed-tools should contain 'Read', got %q", kv["allowed-tools"])
	}
}

// ---------------------------------------------------------------------------
// parseStringSlice tests
// ---------------------------------------------------------------------------

func TestParseStringSlice(t *testing.T) {
	cases := []struct {
		input string
		want  []string
		isErr bool
	}{
		{`["Read", "Write", "Edit"]`, []string{"Read", "Write", "Edit"}, false},
		{`['Bash', 'Glob']`, []string{"Bash", "Glob"}, false},
		{`[]`, nil, false},
		{``, nil, false},
		{`"notalist"`, nil, true},
	}

	for _, c := range cases {
		got, err := parseStringSlice(c.input)
		if c.isErr {
			if err == nil {
				t.Errorf("parseStringSlice(%q): expected error, got nil", c.input)
			}
			continue
		}
		if err != nil {
			t.Errorf("parseStringSlice(%q): unexpected error: %v", c.input, err)
			continue
		}
		if len(got) != len(c.want) {
			t.Errorf("parseStringSlice(%q) = %v, want %v", c.input, got, c.want)
			continue
		}
		for i := range c.want {
			if got[i] != c.want[i] {
				t.Errorf("parseStringSlice(%q)[%d] = %q, want %q", c.input, i, got[i], c.want[i])
			}
		}
	}
}

// ---------------------------------------------------------------------------
// validateSkillsDir: valid SKILL.md
// ---------------------------------------------------------------------------

func TestValidateSkills_Valid(t *testing.T) {
	dir := t.TempDir()
	writeSkillFile(t, dir, "my-skill", `---
name: my-skill
description: "A perfectly valid skill description with trigger phrases."
allowed-tools: ["Read", "Write"]
effort: medium
context: fork
user-invocable: true
---

# My Skill
`)

	errs, count := validateSkillsDir(filepath.Join(dir, "skills"))
	if count != 1 {
		t.Errorf("expected 1 skill checked, got %d", count)
	}
	if len(errs) != 0 {
		t.Errorf("expected no errors, got %d: %v", len(errs), errs)
	}
}

// ---------------------------------------------------------------------------
// validateSkillsDir: missing required fields
// ---------------------------------------------------------------------------

func TestValidateSkills_MissingName(t *testing.T) {
	dir := t.TempDir()
	writeSkillFile(t, dir, "missing-name-skill", `---
description: "Has description but no name."
---
`)

	errs, _ := validateSkillsDir(filepath.Join(dir, "skills"))
	if !containsError(errs, `missing required field "name"`) {
		t.Errorf("expected 'missing required field \"name\"' error, got: %v", errs)
	}
}

func TestValidateSkills_MissingDescription(t *testing.T) {
	dir := t.TempDir()
	writeSkillFile(t, dir, "no-desc", `---
name: no-desc
---
`)

	errs, _ := validateSkillsDir(filepath.Join(dir, "skills"))
	if !containsError(errs, `missing required field "description"`) {
		t.Errorf("expected 'missing required field \"description\"' error, got: %v", errs)
	}
}

// ---------------------------------------------------------------------------
// validateSkillsDir: name mismatch
// ---------------------------------------------------------------------------

func TestValidateSkills_NameMismatch(t *testing.T) {
	dir := t.TempDir()
	// Directory is "actual-dir" but name field says "other-name"
	writeSkillFile(t, dir, "actual-dir", `---
name: other-name
description: "Skill with mismatched name."
---
`)

	errs, _ := validateSkillsDir(filepath.Join(dir, "skills"))
	if !containsError(errs, `does not match directory`) {
		t.Errorf("expected name mismatch error, got: %v", errs)
	}
}

// ---------------------------------------------------------------------------
// validateSkillsDir: invalid optional field values
// ---------------------------------------------------------------------------

func TestValidateSkills_InvalidEffort(t *testing.T) {
	dir := t.TempDir()
	writeSkillFile(t, dir, "bad-effort", `---
name: bad-effort
description: "Skill with invalid effort level."
effort: ultra
---
`)

	errs, _ := validateSkillsDir(filepath.Join(dir, "skills"))
	if !containsError(errs, "effort") {
		t.Errorf("expected effort validation error, got: %v", errs)
	}
}

func TestValidateSkills_XHighEffort(t *testing.T) {
	dir := t.TempDir()
	writeSkillFile(t, dir, "xhigh-skill", `---
name: xhigh-skill
description: "Skill with xhigh effort."
effort: xhigh
---
`)

	errs, _ := validateSkillsDir(filepath.Join(dir, "skills"))
	if len(errs) != 0 {
		t.Errorf("expected no errors for xhigh skill effort, got: %v", errs)
	}
}

func TestValidateSkills_InvalidContext(t *testing.T) {
	dir := t.TempDir()
	writeSkillFile(t, dir, "bad-context", `---
name: bad-context
description: "Skill with invalid context value."
context: parallel
---
`)

	errs, _ := validateSkillsDir(filepath.Join(dir, "skills"))
	if !containsError(errs, `context`) {
		t.Errorf("expected context validation error, got: %v", errs)
	}
}

func TestValidateSkills_InvalidModel(t *testing.T) {
	dir := t.TempDir()
	writeSkillFile(t, dir, "bad-model", `---
name: bad-model
description: "Skill with unrecognized model."
model: gpt-4
---
`)

	errs, _ := validateSkillsDir(filepath.Join(dir, "skills"))
	if !containsError(errs, "model") {
		t.Errorf("expected model validation error, got: %v", errs)
	}
}

func TestValidateSkills_FableModelAccepted(t *testing.T) {
	dir := t.TempDir()
	writeSkillFile(t, dir, "fable-brain", `---
name: fable-brain
description: "Skill opting the brain tier into Fable 5."
model: claude-fable-5
---
`)

	errs, _ := validateSkillsDir(filepath.Join(dir, "skills"))
	if len(errs) != 0 {
		t.Errorf("claude-fable-5 must be a recognized model, got: %v", errs)
	}
}

func TestValidateSkills_Opus5ModelAccepted(t *testing.T) {
	dir := t.TempDir()
	writeSkillFile(t, dir, "opus5-brain", `---
name: opus5-brain
description: "Skill opting the brain tier into Opus 5."
model: claude-opus-5
---
`)

	errs, _ := validateSkillsDir(filepath.Join(dir, "skills"))
	if len(errs) != 0 {
		t.Errorf("claude-opus-5 must be a recognized model, got: %v", errs)
	}
}

// ---------------------------------------------------------------------------
// validateSkillsDir: no frontmatter
// ---------------------------------------------------------------------------

func TestValidateSkills_NoFrontmatter(t *testing.T) {
	dir := t.TempDir()
	writeSkillFile(t, dir, "no-fm", "# No frontmatter\nJust a body.\n")

	errs, count := validateSkillsDir(filepath.Join(dir, "skills"))
	if count != 1 {
		t.Errorf("expected 1 skill checked, got %d", count)
	}
	if !containsError(errs, "no YAML frontmatter") {
		t.Errorf("expected 'no YAML frontmatter' error, got: %v", errs)
	}
}

// ---------------------------------------------------------------------------
// validateSkillsDir: multiple skills — errors isolated per skill
// ---------------------------------------------------------------------------

func TestValidateSkills_MultipleSkills(t *testing.T) {
	dir := t.TempDir()

	// good skill
	writeSkillFile(t, dir, "good-skill", `---
name: good-skill
description: "A valid skill with all required fields."
---
`)

	// bad skill — missing description
	writeSkillFile(t, dir, "bad-skill", `---
name: bad-skill
---
`)

	errs, count := validateSkillsDir(filepath.Join(dir, "skills"))
	if count != 2 {
		t.Errorf("expected 2 skills checked, got %d", count)
	}
	// Only the bad skill should produce errors
	if len(errs) != 1 {
		t.Errorf("expected exactly 1 error, got %d: %v", len(errs), errs)
	}
	if !containsError(errs, `missing required field "description"`) {
		t.Errorf("expected description error, got: %v", errs)
	}
}

// ---------------------------------------------------------------------------
// validateAgentsDir: agent frontmatter checks
// ---------------------------------------------------------------------------

func TestValidateAgents_Valid(t *testing.T) {
	dir := t.TempDir()
	writeAgentFile(t, dir, "my-agent", `---
name: my-agent
description: "A valid agent"
model: claude-sonnet-5
effort: high
maxTurns: 50
---

# My Agent
`)

	errs, count := validateAgentsDir(filepath.Join(dir, "agents"))
	if count != 1 {
		t.Errorf("expected 1 agent checked, got %d", count)
	}
	if len(errs) != 0 {
		t.Errorf("expected no errors, got: %v", errs)
	}
}

func TestValidateAgents_InvalidEffort(t *testing.T) {
	dir := t.TempDir()
	writeAgentFile(t, dir, "bad-agent", `---
name: bad-agent
effort: extreme
---
`)

	errs, _ := validateAgentsDir(filepath.Join(dir, "agents"))
	if !containsError(errs, "effort") {
		t.Errorf("expected effort error, got: %v", errs)
	}
}

func TestValidateAgents_XHighEffort(t *testing.T) {
	dir := t.TempDir()
	writeAgentFile(t, dir, "xhigh-agent", `---
name: xhigh-agent
effort: xhigh
---
`)

	errs, _ := validateAgentsDir(filepath.Join(dir, "agents"))
	if len(errs) != 0 {
		t.Errorf("expected no errors for xhigh agent effort, got: %v", errs)
	}
}

func TestValidateAgents_InvalidMaxTurns(t *testing.T) {
	dir := t.TempDir()
	writeAgentFile(t, dir, "bad-turns", `---
name: bad-turns
maxTurns: -5
---
`)

	errs, _ := validateAgentsDir(filepath.Join(dir, "agents"))
	if !containsError(errs, "maxTurns") {
		t.Errorf("expected maxTurns error, got: %v", errs)
	}
}

func TestValidateAgents_SkipsCLAUDEmd(t *testing.T) {
	dir := t.TempDir()
	// CLAUDE.md should be skipped silently
	writeAgentFile(t, dir, "CLAUDE", "# This is a meta file, not an agent\n")
	writeAgentFile(t, dir, "real-agent", `---
name: real-agent
description: "A real agent"
---
`)

	_, count := validateAgentsDir(filepath.Join(dir, "agents"))
	if count != 1 {
		t.Errorf("CLAUDE.md should be skipped; expected count 1, got %d", count)
	}
}

func TestValidateAgents_ValidWithFullFields(t *testing.T) {
	dir := t.TempDir()
	writeAgentFile(t, dir, "full-agent", `---
name: full-agent
description: "An agent with all optional fields set"
model: claude-opus-4-6
effort: low
maxTurns: 100
tools: ["Read", "Write", "Edit"]
disallowedTools: ["Bash"]
skills: ["harness-review"]
background: true
isolation: worktree
---

# Full Agent
`)

	errs, count := validateAgentsDir(filepath.Join(dir, "agents"))
	if count != 1 {
		t.Errorf("expected 1 agent checked, got %d", count)
	}
	if len(errs) != 0 {
		t.Errorf("expected no errors for valid full-field agent, got: %v", errs)
	}
}

func TestValidateAgents_InvalidModel(t *testing.T) {
	dir := t.TempDir()
	writeAgentFile(t, dir, "bad-model-agent", `---
name: bad-model-agent
model: gpt-4-turbo
---
`)

	errs, _ := validateAgentsDir(filepath.Join(dir, "agents"))
	if !containsError(errs, "model") {
		t.Errorf("expected model validation error, got: %v", errs)
	}
}

func TestValidateAgents_InvalidIsolation(t *testing.T) {
	dir := t.TempDir()
	writeAgentFile(t, dir, "bad-isolation", `---
name: bad-isolation
isolation: sandbox
---
`)

	errs, _ := validateAgentsDir(filepath.Join(dir, "agents"))
	if !containsError(errs, "isolation") {
		t.Errorf("expected isolation validation error, got: %v", errs)
	}
}

func TestValidateAgents_ValidIsolationWorktree(t *testing.T) {
	dir := t.TempDir()
	writeAgentFile(t, dir, "worktree-agent", `---
name: worktree-agent
isolation: worktree
---
`)

	errs, _ := validateAgentsDir(filepath.Join(dir, "agents"))
	if len(errs) != 0 {
		t.Errorf("expected no errors for isolation: worktree, got: %v", errs)
	}
}

func TestValidateAgents_InvalidDisallowedToolsNotList(t *testing.T) {
	dir := t.TempDir()
	writeAgentFile(t, dir, "bad-disallowed", `---
name: bad-disallowed
disallowedTools: "Bash"
---
`)

	errs, _ := validateAgentsDir(filepath.Join(dir, "agents"))
	if !containsError(errs, "disallowedTools") {
		t.Errorf("expected disallowedTools parse error, got: %v", errs)
	}
}

func TestValidateAgents_InvalidBackground(t *testing.T) {
	dir := t.TempDir()
	writeAgentFile(t, dir, "bad-background", `---
name: bad-background
background: yes
---
`)

	errs, _ := validateAgentsDir(filepath.Join(dir, "agents"))
	if !containsError(errs, "background") {
		t.Errorf("expected background validation error, got: %v", errs)
	}
}

func TestValidateAgents_MaxTurnsNotInteger(t *testing.T) {
	dir := t.TempDir()
	writeAgentFile(t, dir, "nan-turns", `---
name: nan-turns
maxTurns: many
---
`)

	errs, _ := validateAgentsDir(filepath.Join(dir, "agents"))
	if !containsError(errs, "maxTurns") {
		t.Errorf("expected maxTurns parse error, got: %v", errs)
	}
}

func TestValidateAgents_NonexistentDir(t *testing.T) {
	errs, count := validateAgentsDir("/tmp/harness-test-nonexistent-agents-dir-xyz")
	if count != 0 {
		t.Errorf("expected count 0 for missing dir, got %d", count)
	}
	if len(errs) != 0 {
		t.Errorf("expected no errors for missing dir, got: %v", errs)
	}
}

// ---------------------------------------------------------------------------
// validateSkillsDir: nonexistent directory
// ---------------------------------------------------------------------------

func TestValidateSkills_NonexistentDir(t *testing.T) {
	errs, count := validateSkillsDir("/tmp/harness-test-nonexistent-dir-xyz")
	if count != 0 {
		t.Errorf("expected count 0 for missing dir, got %d", count)
	}
	if len(errs) != 0 {
		t.Errorf("expected no errors for missing dir, got: %v", errs)
	}
}

// ---------------------------------------------------------------------------
// helpers
// ---------------------------------------------------------------------------

// containsError returns true if any error in errs has a message that contains
// the given substring.
func containsError(errs []validationError, substr string) bool {
	for _, e := range errs {
		if strings.Contains(e.message, substr) {
			return true
		}
	}
	return false
}
