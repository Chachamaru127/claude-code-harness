package main

import (
	"bufio"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
)

// validateTarget represents the target type for harness validate.
type validateTarget int

const (
	validateSkills validateTarget = iota
	validateAgents
	validateAll
)

// validationError holds a single validation error for a file.
type validationError struct {
	file    string
	message string
}

// skillFrontmatter holds parsed SKILL.md frontmatter fields.
type skillFrontmatter struct {
	name                   string
	description            string
	allowedTools           []string
	model                  string
	effort                 string
	context                string
	userInvocable          *bool
	disableModelInvocation *bool
}

// agentFrontmatter holds parsed agent *.md frontmatter fields.
type agentFrontmatter struct {
	name            string
	description     string
	model           string
	effort          string
	maxTurns        *int
	tools           []string
	disallowedTools []string
	skills          []string
	background      *bool
	isolation       string
}

// validModelNames is the set of recognized Claude model identifiers.
var validModelNames = map[string]bool{
	"claude-opus-4-7":   true,
	"claude-opus-4-6":   true,
	"claude-sonnet-4-6": true,
	"claude-haiku-4-5":  true,
	"claude-opus-4":     true,
	"claude-sonnet-4":   true,
	"claude-haiku-4":    true,
	"claude-3-7-sonnet": true,
	"claude-3-5-sonnet": true,
	"claude-3-5-haiku":  true,
	"claude-3-opus":     true,
	"opusplan":          true,
}

// validEffortValues is the set of accepted effort strings.
var validEffortValues = map[string]bool{
	"low":    true,
	"medium": true,
	"high":   true,
	"xhigh":  true,
}

// runValidate implements the "harness validate [skills|agents|all]" subcommand.
func runValidate(args []string) {
	target := validateSkills // default to skills
	var rootOverride string

	for _, arg := range args {
		switch arg {
		case "skills":
			target = validateSkills
		case "agents":
			target = validateAgents
		case "all":
			target = validateAll
		default:
			// Treat unknown args as project root override
			rootOverride = arg
		}
	}

	projectRoot, err := resolveProjectRoot([]string{rootOverride})
	if err != nil {
		fmt.Fprintf(os.Stderr, "harness validate: %v\n", err)
		os.Exit(1)
	}

	var allErrors []validationError
	totalChecked := 0
	skillsChecked := 0
	agentsChecked := 0

	if target == validateSkills || target == validateAll {
		errs, count := validateSkillsDir(filepath.Join(projectRoot, "skills"))
		allErrors = append(allErrors, errs...)
		skillsChecked = count
		totalChecked += count
	}

	if target == validateAgents || target == validateAll {
		errs, count := validateAgentsDir(filepath.Join(projectRoot, "agents"))
		allErrors = append(allErrors, errs...)
		agentsChecked = count
		totalChecked += count
	}

	// Print summary header
	switch target {
	case validateSkills:
		fmt.Printf("harness validate skills: %d skills checked\n", skillsChecked)
	case validateAgents:
		fmt.Printf("harness validate agents: %d agents checked\n", agentsChecked)
	case validateAll:
		fmt.Printf("harness validate all: %d files checked (%d skills, %d agents)\n",
			totalChecked, skillsChecked, agentsChecked)
	}

	fmt.Println()

	passed := totalChecked - len(allErrors)
	if len(allErrors) == 0 {
		fmt.Printf("✓ %d passed\n", passed)
		return
	}

	fmt.Printf("✓ %d passed\n", passed)
	fmt.Printf("✗ %d errors:\n", len(allErrors))
	for _, e := range allErrors {
		fmt.Printf("  - %s: %s\n", e.file, e.message)
	}
	os.Exit(1)
}

// ---------------------------------------------------------------------------
// Skills validation
// ---------------------------------------------------------------------------

// validateSkillsDir walks the skills directory, finds all SKILL.md files,
// and validates each one. Returns accumulated errors and the number of files
// checked.
func validateSkillsDir(skillsDir string) ([]validationError, int) {
	entries, err := os.ReadDir(skillsDir)
	if err != nil {
		// If skills/ doesn't exist, report zero errors (not an error itself)
		if os.IsNotExist(err) {
			return nil, 0
		}
		return []validationError{{file: skillsDir, message: fmt.Sprintf("cannot read directory: %v", err)}}, 0
	}

	var errs []validationError
	count := 0

	for _, entry := range entries {
		if !entry.IsDir() {
			continue
		}
		skillMD := filepath.Join(skillsDir, entry.Name(), "SKILL.md")
		if _, statErr := os.Stat(skillMD); os.IsNotExist(statErr) {
			continue // no SKILL.md — skip non-skill directories silently
		}

		count++
		fm, parseErrs := parseSkillFrontmatter(skillMD)
		errs = append(errs, parseErrs...)

		if len(parseErrs) == 0 {
			// Only perform semantic checks if parsing succeeded
			errs = append(errs, validateSkillFields(skillMD, entry.Name(), fm)...)
		}
	}

	return errs, count
}

// parseSkillFrontmatter reads and parses the YAML frontmatter from a SKILL.md
// file, returning a skillFrontmatter and any parse-level errors.
func parseSkillFrontmatter(path string) (skillFrontmatter, []validationError) {
	raw, err := extractFrontmatter(path)
	if err != nil {
		return skillFrontmatter{}, []validationError{{file: path, message: err.Error()}}
	}
	if raw == "" {
		return skillFrontmatter{}, []validationError{{file: path, message: "no YAML frontmatter found (missing --- delimiters)"}}
	}

	kv := parseFrontmatterKV(raw)
	var fm skillFrontmatter
	var errs []validationError

	fm.name = kv["name"]
	fm.description = kv["description"]
	fm.model = kv["model"]
	fm.effort = kv["effort"]
	fm.context = kv["context"]

	if v, ok := kv["allowed-tools"]; ok {
		tools, parseErr := parseStringSlice(v)
		if parseErr != nil {
			errs = append(errs, validationError{file: path, message: fmt.Sprintf("allowed-tools: %v", parseErr)})
		} else {
			fm.allowedTools = tools
		}
	}

	if v, ok := kv["user-invocable"]; ok && v != "" {
		b, parseErr := parseBool(v)
		if parseErr != nil {
			errs = append(errs, validationError{file: path, message: fmt.Sprintf("user-invocable: %v", parseErr)})
		} else {
			fm.userInvocable = &b
		}
	}

	if v, ok := kv["disable-model-invocation"]; ok && v != "" {
		b, parseErr := parseBool(v)
		if parseErr != nil {
			errs = append(errs, validationError{file: path, message: fmt.Sprintf("disable-model-invocation: %v", parseErr)})
		} else {
			fm.disableModelInvocation = &b
		}
	}

	return fm, errs
}

// validateSkillFields performs semantic validation on a parsed skillFrontmatter.
func validateSkillFields(path, dirName string, fm skillFrontmatter) []validationError {
	var errs []validationError

	// Required: name
	if fm.name == "" {
		errs = append(errs, validationError{file: path, message: `missing required field "name"`})
	} else if fm.name != dirName {
		errs = append(errs, validationError{
			file:    path,
			message: fmt.Sprintf(`name %q does not match directory %q`, fm.name, dirName),
		})
	}

	// Required: description (non-empty)
	if fm.description == "" {
		errs = append(errs, validationError{file: path, message: `missing required field "description"`})
	}

	// Optional: model must be a known model name
	if fm.model != "" && !validModelNames[fm.model] {
		errs = append(errs, validationError{
			file:    path,
			message: fmt.Sprintf(`model %q is not a recognized model name`, fm.model),
		})
	}

	// Optional: effort must be low/medium/high/xhigh
	if fm.effort != "" && !validEffortValues[fm.effort] {
		errs = append(errs, validationError{
			file:    path,
			message: fmt.Sprintf(`effort %q must be one of: low, medium, high, xhigh`, fm.effort),
		})
	}

	// Optional: context must be "fork" if set
	if fm.context != "" && fm.context != "fork" {
		errs = append(errs, validationError{
			file:    path,
			message: fmt.Sprintf(`context %q is invalid; only "fork" is accepted`, fm.context),
		})
	}

	return errs
}

// ---------------------------------------------------------------------------
// Agents validation
// ---------------------------------------------------------------------------

// validateAgentsDir walks the agents directory, finds all *.md files
// (excluding CLAUDE.md), and validates each one.
func validateAgentsDir(agentsDir string) ([]validationError, int) {
	entries, err := os.ReadDir(agentsDir)
	if err != nil {
		if os.IsNotExist(err) {
			return nil, 0
		}
		return []validationError{{file: agentsDir, message: fmt.Sprintf("cannot read directory: %v", err)}}, 0
	}

	var errs []validationError
	count := 0

	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}
		name := entry.Name()
		if !strings.HasSuffix(name, ".md") {
			continue
		}
		// Skip index/meta files
		if name == "CLAUDE.md" || name == "team-composition.md" {
			continue
		}

		agentPath := filepath.Join(agentsDir, name)
		count++

		fm, parseErrs := parseAgentFrontmatter(agentPath)
		errs = append(errs, parseErrs...)

		if len(parseErrs) == 0 {
			errs = append(errs, validateAgentFields(agentPath, fm)...)
		}
	}

	return errs, count
}

// parseAgentFrontmatter reads and parses the YAML frontmatter from an agent
// markdown file.
func parseAgentFrontmatter(path string) (agentFrontmatter, []validationError) {
	raw, err := extractFrontmatter(path)
	if err != nil {
		return agentFrontmatter{}, []validationError{{file: path, message: err.Error()}}
	}
	// Agents may legitimately have no frontmatter; treat as empty, not error
	if raw == "" {
		return agentFrontmatter{}, nil
	}

	kv := parseFrontmatterKV(raw)
	var fm agentFrontmatter
	var errs []validationError

	fm.name = kv["name"]
	fm.description = kv["description"]
	fm.model = kv["model"]
	fm.effort = kv["effort"]
	fm.isolation = kv["isolation"]

	if v, ok := kv["maxTurns"]; ok {
		n, parseErr := strconv.Atoi(strings.TrimSpace(v))
		if parseErr != nil {
			errs = append(errs, validationError{file: path, message: fmt.Sprintf("maxTurns: must be an integer, got %q", v)})
		} else {
			fm.maxTurns = &n
		}
	}

	if v, ok := kv["tools"]; ok && v != "" {
		tools, parseErr := parseStringSlice(v)
		if parseErr != nil {
			errs = append(errs, validationError{file: path, message: fmt.Sprintf("tools: %v", parseErr)})
		} else {
			fm.tools = tools
		}
	}

	if v, ok := kv["disallowedTools"]; ok && v != "" {
		tools, parseErr := parseStringSlice(v)
		if parseErr != nil {
			errs = append(errs, validationError{file: path, message: fmt.Sprintf("disallowedTools: %v", parseErr)})
		} else {
			fm.disallowedTools = tools
		}
	}

	if v, ok := kv["skills"]; ok && v != "" {
		skills, parseErr := parseStringSlice(v)
		if parseErr != nil {
			errs = append(errs, validationError{file: path, message: fmt.Sprintf("skills: %v", parseErr)})
		} else {
			fm.skills = skills
		}
	}

	if v, ok := kv["background"]; ok && v != "" {
		b, parseErr := parseBool(v)
		if parseErr != nil {
			errs = append(errs, validationError{file: path, message: fmt.Sprintf("background: %v", parseErr)})
		} else {
			fm.background = &b
		}
	}

	return fm, errs
}

// validateAgentFields performs semantic validation on a parsed agentFrontmatter.
func validateAgentFields(path string, fm agentFrontmatter) []validationError {
	var errs []validationError

	// model must be recognized if set
	if fm.model != "" && !validModelNames[fm.model] {
		errs = append(errs, validationError{
			file:    path,
			message: fmt.Sprintf(`model %q is not a recognized model name`, fm.model),
		})
	}

	// effort must be low/medium/high/xhigh if set
	if fm.effort != "" && !validEffortValues[fm.effort] {
		errs = append(errs, validationError{
			file:    path,
			message: fmt.Sprintf(`effort %q must be one of: low, medium, high, xhigh`, fm.effort),
		})
	}

	// maxTurns must be positive if set
	if fm.maxTurns != nil && *fm.maxTurns <= 0 {
		errs = append(errs, validationError{
			file:    path,
			message: fmt.Sprintf(`maxTurns must be a positive integer, got %d`, *fm.maxTurns),
		})
	}

	// isolation must be "worktree" if set
	if fm.isolation != "" && fm.isolation != "worktree" {
		errs = append(errs, validationError{
			file:    path,
			message: fmt.Sprintf(`isolation %q is invalid; only "worktree" is accepted`, fm.isolation),
		})
	}

	return errs
}

// ---------------------------------------------------------------------------
// Frontmatter parsing utilities
// ---------------------------------------------------------------------------

// extractFrontmatter reads a markdown file and returns the raw YAML content
// between the first pair of "---" delimiters (not including the delimiters).
// Returns an empty string if no frontmatter is found.
func extractFrontmatter(path string) (string, error) {
	f, err := os.Open(path)
	if err != nil {
		return "", fmt.Errorf("cannot open %s: %w", path, err)
	}
	defer f.Close() //nolint:errcheck

	scanner := bufio.NewScanner(f)

	// Read the first line; it must be "---" to have frontmatter
	if !scanner.Scan() {
		return "", nil
	}
	firstLine := strings.TrimRight(scanner.Text(), "\r")
	if firstLine != "---" {
		return "", nil
	}

	// Collect lines until the closing "---"
	var lines []string
	for scanner.Scan() {
		line := strings.TrimRight(scanner.Text(), "\r")
		if line == "---" {
			return strings.Join(lines, "\n"), nil
		}
		lines = append(lines, line)
	}

	// Closing delimiter not found — frontmatter is malformed
	return "", fmt.Errorf("unclosed frontmatter in %s (missing closing ---)", path)
}

// reKVLine matches "key: value" or "key: 'value'" or `key: "value"` lines.
// Multi-line values are not supported (not needed for these schemas).
var reKVLine = regexp.MustCompile(`^([\w-]+):\s*(.*)$`)

// parseFrontmatterKV parses a simple YAML-like block into a key→value map.
// Supports:
//   - key: value
//   - key: "quoted value"
//   - key: 'single quoted'
//   - key: [item1, item2]  (stored verbatim; callers use parseStringSlice)
//   - key: true/false
func parseFrontmatterKV(raw string) map[string]string {
	kv := make(map[string]string)
	for _, line := range strings.Split(raw, "\n") {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		m := reKVLine.FindStringSubmatch(line)
		if m == nil {
			continue
		}
		key := m[1]
		val := strings.TrimSpace(m[2])

		// Strip surrounding quotes (double or single)
		if len(val) >= 2 {
			if (val[0] == '"' && val[len(val)-1] == '"') ||
				(val[0] == '\'' && val[len(val)-1] == '\'') {
				val = val[1 : len(val)-1]
			}
		}

		kv[key] = val
	}
	return kv
}

// reStringSlice matches a YAML-style inline sequence: ["a", "b"] or ['a', 'b']
var reSliceItem = regexp.MustCompile(`["']([^"']+)["']`)

// parseStringSlice converts a YAML inline sequence string such as
// `["Read", "Write", "Edit"]` into a []string.
func parseStringSlice(raw string) ([]string, error) {
	raw = strings.TrimSpace(raw)
	if raw == "" || raw == "[]" {
		return nil, nil
	}
	if raw[0] != '[' {
		return nil, fmt.Errorf("expected a list starting with '[', got %q", raw)
	}

	matches := reSliceItem.FindAllStringSubmatch(raw, -1)
	if matches == nil {
		return nil, fmt.Errorf("could not parse list items from %q", raw)
	}

	result := make([]string, 0, len(matches))
	for _, m := range matches {
		result = append(result, m[1])
	}
	return result, nil
}

// parseBool converts "true" or "false" (case-insensitive) to bool.
func parseBool(raw string) (bool, error) {
	switch strings.ToLower(strings.TrimSpace(raw)) {
	case "true":
		return true, nil
	case "false":
		return false, nil
	default:
		return false, fmt.Errorf("expected true or false, got %q", raw)
	}
}
