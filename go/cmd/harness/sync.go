package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"

	"github.com/Chachamaru127/claude-code-harness/go/pkg/config"
)

// runSync implements the "harness sync" subcommand.
//
// It reads harness.toml from the project root, then generates:
//   - .claude-plugin/plugin.json   ← [project] section
//   - hooks/hooks.json             ← current hooks.json template (Phase 35.3 will make this dynamic)
//   - .claude-plugin/hooks.json    ← identical copy of hooks/hooks.json
//   - .claude-plugin/settings.json ← [agent] + [env] + [safety.permissions] + [safety.sandbox]
//
// The project root is determined by the first argument (or cwd if omitted).
// Exit 0 on success, exit 1 on any error.
func runSync(args []string) {
	// Determine project root
	projectRoot, err := resolveProjectRoot(args)
	if err != nil {
		fmt.Fprintf(os.Stderr, "harness sync: %v\n", err)
		os.Exit(1)
	}

	// Parse harness.toml
	tomlPath := filepath.Join(projectRoot, "harness.toml")
	cfg, err := config.ParseFile(tomlPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "harness sync: %v\n", err)
		os.Exit(1)
	}

	// Run each generator; collect errors to report all at once
	var errs []error

	if err := generatePluginJSON(projectRoot, cfg); err != nil {
		errs = append(errs, fmt.Errorf("plugin.json: %w", err))
	}

	if err := syncHooksJSON(projectRoot); err != nil {
		errs = append(errs, fmt.Errorf("hooks.json sync: %w", err))
	}

	if err := generateSettingsJSON(projectRoot, cfg); err != nil {
		errs = append(errs, fmt.Errorf("settings.json: %w", err))
	}

	if len(errs) > 0 {
		for _, e := range errs {
			fmt.Fprintf(os.Stderr, "harness sync: %v\n", e)
		}
		os.Exit(1)
	}

	fmt.Println("harness sync: done")
}

// ---------------------------------------------------------------------------
// resolveProjectRoot
// ---------------------------------------------------------------------------

// resolveProjectRoot returns the project root directory.
// If args contains one element it is treated as the root; otherwise the
// current working directory is used.
func resolveProjectRoot(args []string) (string, error) {
	if len(args) > 0 {
		abs, err := filepath.Abs(args[0])
		if err != nil {
			return "", fmt.Errorf("invalid project root %q: %w", args[0], err)
		}
		return abs, nil
	}

	cwd, err := os.Getwd()
	if err != nil {
		return "", fmt.Errorf("cannot determine working directory: %w", err)
	}
	return cwd, nil
}

// ---------------------------------------------------------------------------
// plugin.json
// ---------------------------------------------------------------------------

// pluginJSON is the schema for .claude-plugin/plugin.json.
// Fields that are not set in harness.toml are omitted from the output.
type pluginJSON struct {
	Name        string      `json:"name,omitempty"`
	Version     string      `json:"version,omitempty"`
	Description string      `json:"description,omitempty"`
	Author      interface{} `json:"author,omitempty"`
	Homepage    string      `json:"homepage,omitempty"`
	Repository  string      `json:"repository,omitempty"`
	License     string      `json:"license,omitempty"`
	Keywords    []string    `json:"keywords,omitempty"`
	// Skills declares the skill discovery roots per CC 2.1.94+.
	// Points to the directory containing skill subdirectories (each with SKILL.md).
	// Previously hardcoded to ["./"] per 009faf74, which assumed SKILL.md lived at
	// the plugin root. That assumption did not match this repo's layout (SKILL.md
	// files are under `skills/`), so `claude plugin install` / `--plugin-dir`
	// discovered zero skills. v4.0.3 (25bd633d) fixed plugin.json to "./skills/"
	// but the sync regenerator still wrote back "./"; this field now emits
	// "./skills/" so subsequent syncs preserve the fix.
	Skills       []string `json:"skills,omitempty"`
	OutputStyles string   `json:"outputStyles,omitempty"`
}

func generatePluginJSON(projectRoot string, cfg *config.Config) error {
	// Author: preserve object form if URL is set, otherwise use string
	var author interface{}
	name := cfg.Project.AuthorName()
	url := cfg.Project.AuthorURL()
	if name != "" {
		if url != "" {
			author = map[string]string{"name": name, "url": url}
		} else {
			author = name
		}
	}

	p := pluginJSON{
		Name:        cfg.Project.Name,
		Version:     cfg.Project.Version,
		Description: cfg.Project.Description,
		Author:      author,
		Homepage:    cfg.Project.Homepage,
		Repository:  cfg.Project.Repository,
		License:     cfg.Project.License,
		Keywords:    cfg.Project.Keywords,
		// Emit ["./skills/"] so CC 2.1.94+ can discover SKILL.md files under the
		// actual skills directory. The earlier ["./"] value (009faf74) pointed to
		// the plugin root where no SKILL.md exists, causing distributed installs
		// (`claude plugin install`, `--plugin-dir`) to load zero skills.
		Skills:       []string{"./skills/"},
		OutputStyles: cfg.Project.OutputStyles,
	}

	data, err := marshalPretty(p)
	if err != nil {
		return err
	}

	dest := filepath.Join(projectRoot, ".claude-plugin", "plugin.json")
	if err := writeFile(dest, data); err != nil {
		return err
	}

	fmt.Printf("  wrote %s\n", rel(projectRoot, dest))
	return nil
}

// ---------------------------------------------------------------------------
// hooks.json sync
// ---------------------------------------------------------------------------

// syncHooksJSON copies hooks/hooks.json to .claude-plugin/hooks.json.
// Phase 35.2 uses the existing hooks.json as a static template.
// Phase 35.3 will make hooks generation dynamic based on harness.toml [hooks].
func syncHooksJSON(projectRoot string) error {
	src := filepath.Join(projectRoot, "hooks", "hooks.json")
	dst := filepath.Join(projectRoot, ".claude-plugin", "hooks.json")

	data, err := os.ReadFile(src)
	if err != nil {
		return fmt.Errorf("read %s: %w", src, err)
	}

	// Validate that the source is valid JSON before copying
	if !json.Valid(data) {
		return fmt.Errorf("%s is not valid JSON", src)
	}

	if err := writeFile(dst, data); err != nil {
		return err
	}

	fmt.Printf("  wrote %s (copied from %s)\n", rel(projectRoot, dst), rel(projectRoot, src))
	return nil
}

// ---------------------------------------------------------------------------
// settings.json
// ---------------------------------------------------------------------------

// settingsJSON mirrors the schema of .claude-plugin/settings.json.
// Only non-empty / non-nil fields are included in the output so that
// a minimal harness.toml produces a minimal settings.json.
type settingsJSON struct {
	Schema      string            `json:"$schema,omitempty"`
	Agent       string            `json:"agent,omitempty"`
	Env         map[string]string `json:"env,omitempty"`
	Permissions *permissionsField `json:"permissions,omitempty"`
	Sandbox     *sandboxField     `json:"sandbox,omitempty"`
}

type permissionsField struct {
	Deny []string `json:"deny,omitempty"`
	Ask  []string `json:"ask,omitempty"`
}

type sandboxField struct {
	FailIfUnavailable bool                    `json:"failIfUnavailable"`
	Network           *sandboxNetworkField    `json:"network,omitempty"`
	Filesystem        *sandboxFilesystemField `json:"filesystem,omitempty"`
}

type sandboxNetworkField struct {
	DeniedDomains []string `json:"deniedDomains,omitempty"`
}

type sandboxFilesystemField struct {
	DenyRead  []string `json:"denyRead,omitempty"`
	AllowRead []string `json:"allowRead,omitempty"`
}

func generateSettingsJSON(projectRoot string, cfg *config.Config) error {
	s := settingsJSON{
		Schema: "https://json.schemastore.org/claude-code-settings.json",
	}

	// [agent]
	if cfg.Agent.Default != "" {
		s.Agent = cfg.Agent.Default
	}

	// [env]
	if len(cfg.Env) > 0 {
		s.Env = cfg.Env
	}

	// [safety.permissions]
	p := &permissionsField{
		Deny: cfg.Safety.Permissions.Deny,
		Ask:  cfg.Safety.Permissions.Ask,
	}
	if len(p.Deny) > 0 || len(p.Ask) > 0 {
		s.Permissions = p
	}

	// [safety.sandbox]
	sb := cfg.Safety.Sandbox
	if sb.FailIfUnavailable || len(sb.Network.DeniedDomains) > 0 || len(sb.Filesystem.DenyRead) > 0 || len(sb.Filesystem.AllowRead) > 0 {
		sf := &sandboxField{
			FailIfUnavailable: sb.FailIfUnavailable,
		}
		if len(sb.Network.DeniedDomains) > 0 {
			sf.Network = &sandboxNetworkField{
				DeniedDomains: sb.Network.DeniedDomains,
			}
		}
		if len(sb.Filesystem.DenyRead) > 0 || len(sb.Filesystem.AllowRead) > 0 {
			sf.Filesystem = &sandboxFilesystemField{
				DenyRead:  sb.Filesystem.DenyRead,
				AllowRead: sb.Filesystem.AllowRead,
			}
		}
		s.Sandbox = sf
	}

	data, err := marshalPretty(s)
	if err != nil {
		return err
	}

	dest := filepath.Join(projectRoot, ".claude-plugin", "settings.json")
	if err := writeFile(dest, data); err != nil {
		return err
	}

	fmt.Printf("  wrote %s\n", rel(projectRoot, dest))
	return nil
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

// marshalPretty marshals v to indented JSON with a trailing newline.
func marshalPretty(v interface{}) ([]byte, error) {
	var buf bytes.Buffer
	enc := json.NewEncoder(&buf)
	enc.SetIndent("", "  ")
	enc.SetEscapeHTML(false)
	if err := enc.Encode(v); err != nil {
		return nil, fmt.Errorf("JSON marshal: %w", err)
	}
	return buf.Bytes(), nil
}

// writeFile writes data to path, creating parent directories as needed.
// It refuses to write to paths outside the OS temp directory or the file's
// own parent (safety guard against path-traversal in tests).
func writeFile(path string, data []byte) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return fmt.Errorf("mkdir %s: %w", filepath.Dir(path), err)
	}
	if err := os.WriteFile(path, data, 0o644); err != nil {
		return fmt.Errorf("write %s: %w", path, err)
	}
	return nil
}

// rel returns path relative to base, falling back to the absolute path.
func rel(base, path string) string {
	r, err := filepath.Rel(base, path)
	if err != nil {
		return path
	}
	return r
}
