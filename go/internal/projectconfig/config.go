// Package projectconfig loads the per-project harness configuration file
// (claude-code-harness.config.json) that is described by
// claude-code-harness.config.schema.json.
//
// Historically only runtimefloor.secretAllow was read from this file, so most
// of the documented sections had no effect. This package parses the full schema
// into a typed struct so that the configuration is genuinely read, and exposes
// helpers for the sections that are enforced by the PreToolUse guardrail
// (paths.protected, git.protected_branches).
//
// Two behaviours matter for callers:
//
//   - Resolution walks up from a start directory and accepts BOTH the canonical
//     dotted filename ".claude-code-harness.config.json" and the non-dotted
//     "claude-code-harness.config.json". The example/schema files ship without a
//     leading dot, so users frequently copy them to the non-dotted name; both
//     resolve to avoid a silent no-op.
//   - Loading is fail-safe: a missing file yields Found=false with no error; a
//     present-but-unparseable file yields Found=true with ParseErr set and a nil
//     Config so that security-sensitive callers can fail closed.
package projectconfig

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
)

// ConfigFileNames lists the accepted project config filenames in resolution
// priority order. The dotted name is canonical (it matches the sibling
// ".claude-code-harness.config.yaml"); the non-dotted name is accepted because
// the shipped schema/example files use it as their base name.
var ConfigFileNames = []string{
	".claude-code-harness.config.json",
	"claude-code-harness.config.json",
}

// Config mirrors claude-code-harness.config.schema.json. Every documented
// section is represented so the file is fully parsed; sections that are not yet
// enforced by a hook are still available to consumers via this struct.
type Config struct {
	Version             string                    `json:"version"`
	Safety              SafetyConfig              `json:"safety"`
	Git                 GitConfig                 `json:"git"`
	Paths               PathsConfig               `json:"paths"`
	CI                  CIConfig                  `json:"ci"`
	Scaffolding         ScaffoldingConfig         `json:"scaffolding"`
	DestructiveCommands DestructiveCommandsConfig `json:"destructive_commands"`
	I18n                I18nConfig                `json:"i18n"`
	Constitution        ConstitutionConfig        `json:"constitution"`
	RuntimeFloor        RuntimeFloorConfig        `json:"runtimefloor"`
	Orchestration       OrchestrationConfig       `json:"orchestration"`
	Work                WorkConfig                `json:"work"`
	Session             SessionConfig             `json:"session"`
}

// SafetyConfig maps the "safety" section. These fields are advisory today:
// they are consumed by markdown skills, not the PreToolUse guardrail.
type SafetyConfig struct {
	Mode                string `json:"mode"`
	RequireConfirmation *bool  `json:"require_confirmation"`
	MaxAutoRetries      *int   `json:"max_auto_retries"`
}

// GitConfig maps the "git" section. ProtectedBranches is enforced by the
// guardrail (R11/R12); the remaining flags are advisory hints for skills.
type GitConfig struct {
	AllowAutoCommit   *bool    `json:"allow_auto_commit"`
	AllowAutoPush     *bool    `json:"allow_auto_push"`
	ProtectedBranches []string `json:"protected_branches"`
	CommitPrefix      string   `json:"commit_prefix"`
}

// PathsConfig maps the "paths" section. Protected is enforced by the guardrail
// (deny writes); the other fields are advisory.
type PathsConfig struct {
	AllowedModify []string `json:"allowed_modify"`
	Protected     []string `json:"protected"`
	PlansFile     string   `json:"plans_file"`
	AgentsFile    string   `json:"agents_file"`
}

// CIConfig maps the "ci" section (advisory).
type CIConfig struct {
	Provider      string `json:"provider"`
	EnableAutoFix *bool  `json:"enable_auto_fix"`
	RequireGhCLI  *bool  `json:"require_gh_cli"`
}

// ScaffoldingConfig maps the "scaffolding" section (advisory).
type ScaffoldingConfig struct {
	TechChoiceMode string            `json:"tech_choice_mode"`
	BaseStack      string            `json:"base_stack"`
	AllowWebSearch *bool             `json:"allow_web_search"`
	Templates      map[string]string `json:"templates"`
}

// DestructiveCommandsConfig maps the "destructive_commands" section (advisory).
type DestructiveCommandsConfig struct {
	AllowRmRf        *bool `json:"allow_rm_rf"`
	AllowNpmInstall  *bool `json:"allow_npm_install"`
	RequireSizeCheck *bool `json:"require_size_check"`
	MaxFilesToModify *int  `json:"max_files_to_modify"`
}

// I18nConfig maps the "i18n" section. The canonical language source remains the
// YAML config; this mirror keeps the JSON schema complete.
type I18nConfig struct {
	Language string `json:"language"`
}

// ConstitutionConfig maps the "constitution" section (consumed by skills).
type ConstitutionConfig struct {
	Path string `json:"path"`
}

// RuntimeFloorConfig maps the "runtimefloor" section. SecretAllow is consumed by
// the runtime action hard floor.
type RuntimeFloorConfig struct {
	SecretAllow []string `json:"secretAllow"`
}

// OrchestrationConfig maps the "orchestration" section (advisory).
type OrchestrationConfig struct {
	StateMachineVersion string `json:"state_machine_version"`
	MaxStateRetries     *int   `json:"max_state_retries"`
	RetryBackoffSeconds *int   `json:"retry_backoff_seconds"`
}

// WorkConfig maps the "work" section (consumed by the /work skill).
type WorkConfig struct {
	AutoCommit        *bool `json:"auto_commit"`
	CommitOnPmApprove *bool `json:"commit_on_pm_approve"`
}

// SessionConfig maps the "session" section (advisory).
type SessionConfig struct {
	SnapshotPath string `json:"snapshot_path"`
	EventLogPath string `json:"event_log_path"`
	ResumePolicy string `json:"resume_policy"`
	ForkPolicy   string `json:"fork_policy"`
}

// LoadResult is the outcome of loading the project config.
type LoadResult struct {
	// Config is the parsed configuration, or nil when the file is missing or
	// could not be parsed.
	Config *Config
	// ProjectRoot is the directory that contains the resolved config file.
	ProjectRoot string
	// Path is the resolved config file path.
	Path string
	// Found reports whether a config file was located.
	Found bool
	// ParseErr is set when a file was found but could not be parsed. Callers
	// that tighten security on the basis of this file should fail closed when
	// Found is true and ParseErr is non-nil.
	ParseErr error
}

// Resolve walks up from startDir looking for an accepted config filename.
// It returns the directory containing the file, the file path, and whether one
// was found. When startDir is empty the current working directory is used.
func Resolve(startDir string) (projectRoot string, path string, found bool) {
	start := strings.TrimSpace(startDir)
	if start == "" {
		wd, err := os.Getwd()
		if err != nil {
			return "", "", false
		}
		start = wd
	}
	abs, err := filepath.Abs(start)
	if err != nil {
		abs = filepath.Clean(start)
	}
	if info, statErr := os.Stat(abs); statErr == nil && !info.IsDir() {
		abs = filepath.Dir(abs)
	}
	for {
		for _, name := range ConfigFileNames {
			candidate := filepath.Join(abs, name)
			if info, statErr := os.Stat(candidate); statErr == nil && !info.IsDir() {
				return abs, candidate, true
			}
		}
		parent := filepath.Dir(abs)
		if parent == abs {
			return "", "", false
		}
		abs = parent
	}
}

// Load resolves and parses the project config starting from startDir.
// It never returns an error value; inspect the LoadResult fields instead.
func Load(startDir string) LoadResult {
	projectRoot, path, found := Resolve(startDir)
	if !found {
		return LoadResult{Found: false}
	}
	data, err := os.ReadFile(path)
	if err != nil {
		return LoadResult{ProjectRoot: projectRoot, Path: path, Found: true, ParseErr: err}
	}
	var cfg Config
	if err := json.Unmarshal(data, &cfg); err != nil {
		return LoadResult{ProjectRoot: projectRoot, Path: path, Found: true, ParseErr: err}
	}
	return LoadResult{Config: &cfg, ProjectRoot: projectRoot, Path: path, Found: true}
}

// ProtectedPaths returns the normalized, project-relative protected path
// declarations from paths.protected. Absolute paths and parent-directory
// escapes are dropped so a declaration can never point outside the project.
// The result is deduplicated and forward-slash normalized.
func (r LoadResult) ProtectedPaths() []string {
	if r.Config == nil {
		return nil
	}
	seen := make(map[string]struct{})
	var out []string
	for _, raw := range r.Config.Paths.Protected {
		p := sanitizeRelPath(raw)
		if p == "" {
			continue
		}
		if _, dup := seen[p]; dup {
			continue
		}
		seen[p] = struct{}{}
		out = append(out, p)
	}
	return out
}

// ProtectedBranches returns the deduplicated, trimmed branch names from
// git.protected_branches. Empty entries are dropped.
func (r LoadResult) ProtectedBranches() []string {
	if r.Config == nil {
		return nil
	}
	seen := make(map[string]struct{})
	var out []string
	for _, raw := range r.Config.Git.ProtectedBranches {
		b := strings.TrimSpace(strings.Trim(strings.TrimSpace(raw), `"'`))
		if b == "" {
			continue
		}
		if _, dup := seen[b]; dup {
			continue
		}
		seen[b] = struct{}{}
		out = append(out, b)
	}
	return out
}

// sanitizeRelPath normalizes a declared path to a clean, forward-slash,
// project-relative form. It returns "" for empty, absolute, or escaping paths.
func sanitizeRelPath(raw string) string {
	p := strings.TrimSpace(strings.Trim(strings.TrimSpace(raw), `"'`))
	if p == "" {
		return ""
	}
	if filepath.IsAbs(p) || strings.HasPrefix(p, "/") {
		return ""
	}
	// Preserve a trailing slash intent (directory prefix) before cleaning.
	trailingDir := strings.HasSuffix(p, "/")
	cleaned := filepath.ToSlash(filepath.Clean(p))
	if cleaned == "." || cleaned == ".." || strings.HasPrefix(cleaned, "../") {
		return ""
	}
	if trailingDir && !strings.HasSuffix(cleaned, "/") {
		cleaned += "/"
	}
	return cleaned
}
