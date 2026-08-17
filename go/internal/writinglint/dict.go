package writinglint

import (
	"bufio"
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

const (
	// EnvDictPath is the environment variable override for the dictionary path.
	EnvDictPath = "CLAUDE_WRITING_LINT_DICT"

	harnessConfigFileName = ".claude-code-harness.config.yaml"
	defaultDictRelPath    = ".claude/writing-lint/rules.jsonl"
)

// LoadDict reads a JSONL dictionary of writing-rule.v1 entries from path.
// Blank lines and lines starting with "#" are skipped so the dictionary stays
// human-editable. Any other malformed line is a hard error.
func LoadDict(path string) ([]Rule, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, fmt.Errorf("open dict: %w", err)
	}
	defer f.Close()

	var rules []Rule
	scanner := bufio.NewScanner(f)
	scanner.Buffer(make([]byte, 0, 64*1024), 1024*1024)
	lineNo := 0
	for scanner.Scan() {
		lineNo++
		line := strings.TrimSpace(scanner.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		var rule Rule
		dec := json.NewDecoder(bytes.NewReader([]byte(line)))
		dec.DisallowUnknownFields()
		if err := dec.Decode(&rule); err != nil {
			return nil, fmt.Errorf("dict %s line %d: %w", path, lineNo, err)
		}
		rules = append(rules, rule)
	}
	if err := scanner.Err(); err != nil {
		return nil, fmt.Errorf("scan dict %s: %w", path, err)
	}
	return rules, nil
}

// ResolveDictPath resolves the writing-lint dictionary path with precedence:
//  1. .claude-code-harness.config.yaml's writing_lint.dict_path (relative to repoRoot)
//  2. env CLAUDE_WRITING_LINT_DICT
//  3. ~/.claude/writing-lint/rules.jsonl
//
// repoRoot may be empty, in which case step 1 is skipped.
func ResolveDictPath(repoRoot string) string {
	if v := readDictPathFromConfig(repoRoot); v != "" {
		if filepath.IsAbs(v) {
			return v
		}
		return filepath.Join(repoRoot, v)
	}
	if v := strings.TrimSpace(os.Getenv(EnvDictPath)); v != "" {
		return v
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return ""
	}
	return filepath.Join(home, defaultDictRelPath)
}

// readDictPathFromConfig reads the writing_lint.dict_path key from the
// project's .claude-code-harness.config.yaml. It does a minimal line-oriented
// scan (matching the convention used elsewhere in hookhandler) rather than a
// full YAML parse, since only a single scalar key is needed.
func readDictPathFromConfig(repoRoot string) string {
	if repoRoot == "" {
		return ""
	}
	f, err := os.Open(filepath.Join(repoRoot, harnessConfigFileName))
	if err != nil {
		return ""
	}
	defer f.Close()

	inSection := false
	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		line := scanner.Text()
		if strings.TrimSpace(line) == "writing_lint:" {
			inSection = true
			continue
		}
		if inSection && len(line) > 0 && line[0] != ' ' && line[0] != '\t' && line[0] != '#' {
			break
		}
		if !inSection {
			continue
		}
		trimmed := strings.TrimSpace(line)
		if trimmed == "" || strings.HasPrefix(trimmed, "#") {
			continue
		}
		parts := strings.SplitN(trimmed, ":", 2)
		if len(parts) != 2 || strings.TrimSpace(parts[0]) != "dict_path" {
			continue
		}
		val := strings.TrimSpace(parts[1])
		return strings.Trim(val, `"'`)
	}
	return ""
}
