package config_test

import (
	"testing"

	"github.com/Chachamaru127/claude-code-harness/go/pkg/config"
)

// ---------------------------------------------------------------------------
// Full-featured parse test
// ---------------------------------------------------------------------------

var fullTOML = []byte(`
[project]
name = "claude-code-harness"
version = "3.17.0"
description = "Claude harness"
author = "Chachamaru"
homepage = "https://github.com/Chachamaru127/claude-code-harness"

[agent]
default = "security-reviewer"

[env]
CLAUDE_CODE_SUBPROCESS_ENV_SCRUB = "1"

[safety.permissions]
deny = [
  "Bash(sudo:*)",
  "Bash(rm -rf:*)",
  "mcp__codex__*",
  "Read(./.env)",
]
ask = [
  "Bash(rm -r:*)",
  "Bash(git push -f:*)",
]

[safety.sandbox]
failIfUnavailable = true

[safety.sandbox.network]
deniedDomains = ["169.254.169.254", "metadata.google.internal"]

[safety.sandbox.filesystem]
denyRead = [".env", "secrets/**", "**/*.pem"]
allowRead = [".env.example", "docs/**"]

`)

func TestParse_Full(t *testing.T) {
	cfg, err := config.ParseBytes(fullTOML)
	if err != nil {
		t.Fatalf("unexpected parse error: %v", err)
	}

	// [project]
	if cfg.Project.Name != "claude-code-harness" {
		t.Errorf("project.name = %q, want %q", cfg.Project.Name, "claude-code-harness")
	}
	if cfg.Project.Version != "3.17.0" {
		t.Errorf("project.version = %q, want %q", cfg.Project.Version, "3.17.0")
	}
	if cfg.Project.Description != "Claude harness" {
		t.Errorf("project.description = %q, want %q", cfg.Project.Description, "Claude harness")
	}
	if cfg.Project.Author != "Chachamaru" {
		t.Errorf("project.author = %q, want %q", cfg.Project.Author, "Chachamaru")
	}
	if cfg.Project.Homepage != "https://github.com/Chachamaru127/claude-code-harness" {
		t.Errorf("project.homepage = %q", cfg.Project.Homepage)
	}

	// [agent]
	if cfg.Agent.Default != "security-reviewer" {
		t.Errorf("agent.default = %q, want %q", cfg.Agent.Default, "security-reviewer")
	}

	// [env]
	if v := cfg.Env["CLAUDE_CODE_SUBPROCESS_ENV_SCRUB"]; v != "1" {
		t.Errorf("env.CLAUDE_CODE_SUBPROCESS_ENV_SCRUB = %q, want %q", v, "1")
	}

	// [safety.permissions]
	wantDeny := []string{
		"Bash(sudo:*)",
		"Bash(rm -rf:*)",
		"mcp__codex__*",
		"Read(./.env)",
	}
	if len(cfg.Safety.Permissions.Deny) != len(wantDeny) {
		t.Errorf("permissions.deny len = %d, want %d", len(cfg.Safety.Permissions.Deny), len(wantDeny))
	} else {
		for i, v := range wantDeny {
			if cfg.Safety.Permissions.Deny[i] != v {
				t.Errorf("permissions.deny[%d] = %q, want %q", i, cfg.Safety.Permissions.Deny[i], v)
			}
		}
	}

	wantAsk := []string{"Bash(rm -r:*)", "Bash(git push -f:*)"}
	if len(cfg.Safety.Permissions.Ask) != len(wantAsk) {
		t.Errorf("permissions.ask len = %d, want %d", len(cfg.Safety.Permissions.Ask), len(wantAsk))
	}

	// [safety.sandbox]
	if !cfg.Safety.Sandbox.FailIfUnavailable {
		t.Error("sandbox.failIfUnavailable = false, want true")
	}
	if len(cfg.Safety.Sandbox.Network.DeniedDomains) != 2 {
		t.Errorf("sandbox.network.deniedDomains len = %d, want 2", len(cfg.Safety.Sandbox.Network.DeniedDomains))
	}
	if cfg.Safety.Sandbox.Network.DeniedDomains[0] != "169.254.169.254" {
		t.Errorf("sandbox.network.deniedDomains[0] = %q", cfg.Safety.Sandbox.Network.DeniedDomains[0])
	}
	if len(cfg.Safety.Sandbox.Filesystem.DenyRead) != 3 {
		t.Errorf("sandbox.filesystem.denyRead len = %d, want 3", len(cfg.Safety.Sandbox.Filesystem.DenyRead))
	}
	if len(cfg.Safety.Sandbox.Filesystem.AllowRead) != 2 {
		t.Errorf("sandbox.filesystem.allowRead len = %d, want 2", len(cfg.Safety.Sandbox.Filesystem.AllowRead))
	}

}

// ---------------------------------------------------------------------------
// Unsupported key rejection
// ---------------------------------------------------------------------------

func TestParse_RejectUserConfig(t *testing.T) {
	data := []byte(`
[project]
name = "test"

[userConfig]
some_key = "value"
`)
	_, err := config.ParseBytes(data)
	if err == nil {
		t.Fatal("expected error for unsupported key userConfig, got nil")
	}
}

func TestParse_RejectChannels(t *testing.T) {
	data := []byte(`
[project]
name = "test"

[channels]
slack = "C12345"
`)
	_, err := config.ParseBytes(data)
	if err == nil {
		t.Fatal("expected error for unsupported key channels, got nil")
	}
}

func TestParse_RejectCaseInsensitive(t *testing.T) {
	// Verify that "USERCONFIG" (uppercase) is also rejected.
	// TOML keys are case-sensitive, but our rejection check uses EqualFold.
	data := []byte(`
[project]
name = "test"

[USERCONFIG]
x = "y"
`)
	_, err := config.ParseBytes(data)
	if err == nil {
		t.Fatal("expected error for USERCONFIG (case-insensitive), got nil")
	}
}

// ---------------------------------------------------------------------------
// Minimal / empty config
// ---------------------------------------------------------------------------

func TestParse_Minimal(t *testing.T) {
	// Only [project].name is set; all other fields must have zero values.
	data := []byte(`
[project]
name = "minimal"
`)
	cfg, err := config.ParseBytes(data)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if cfg.Project.Name != "minimal" {
		t.Errorf("project.name = %q, want %q", cfg.Project.Name, "minimal")
	}
	if cfg.Agent.Default != "" {
		t.Errorf("agent.default should be empty, got %q", cfg.Agent.Default)
	}
	if len(cfg.Env) != 0 {
		t.Errorf("env should be empty, got %v", cfg.Env)
	}
	if len(cfg.Safety.Permissions.Deny) != 0 {
		t.Errorf("permissions.deny should be empty")
	}
}

func TestParse_Empty(t *testing.T) {
	cfg, err := config.ParseBytes([]byte{})
	if err != nil {
		t.Fatalf("empty TOML should parse without error: %v", err)
	}
	// All fields must be zero values
	if cfg.Project.Name != "" {
		t.Errorf("project.name should be empty, got %q", cfg.Project.Name)
	}
}

// ---------------------------------------------------------------------------
// Invalid TOML syntax
// ---------------------------------------------------------------------------

func TestParse_InvalidSyntax(t *testing.T) {
	data := []byte(`
[project
name = "broken
`)
	_, err := config.ParseBytes(data)
	if err == nil {
		t.Fatal("expected parse error for invalid TOML, got nil")
	}
}

// ---------------------------------------------------------------------------
// env section with multiple keys
// ---------------------------------------------------------------------------

func TestParse_EnvMultipleKeys(t *testing.T) {
	data := []byte(`
[env]
FOO = "bar"
BAZ = "qux"
EMPTY = ""
`)
	cfg, err := config.ParseBytes(data)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if cfg.Env["FOO"] != "bar" {
		t.Errorf("env.FOO = %q, want %q", cfg.Env["FOO"], "bar")
	}
	if cfg.Env["BAZ"] != "qux" {
		t.Errorf("env.BAZ = %q, want %q", cfg.Env["BAZ"], "qux")
	}
	if cfg.Env["EMPTY"] != "" {
		t.Errorf("env.EMPTY = %q, want empty", cfg.Env["EMPTY"])
	}
}

// ---------------------------------------------------------------------------
// sandbox without filesystem subsection
// ---------------------------------------------------------------------------

func TestParse_SandboxWithoutFilesystem(t *testing.T) {
	data := []byte(`
[safety.sandbox]
failIfUnavailable = false
`)
	cfg, err := config.ParseBytes(data)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if cfg.Safety.Sandbox.FailIfUnavailable {
		t.Error("sandbox.failIfUnavailable should be false")
	}
	if len(cfg.Safety.Sandbox.Filesystem.DenyRead) != 0 {
		t.Error("filesystem.denyRead should be empty when not specified")
	}
}
