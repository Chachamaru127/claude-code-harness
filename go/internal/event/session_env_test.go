package event

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestSessionEnvHandler_Handle_NoEnvFile(t *testing.T) {
	// Does nothing when CLAUDE_ENV_FILE is not set
	t.Setenv("CLAUDE_ENV_FILE", "")

	h := &SessionEnvHandler{}
	err := h.Handle(strings.NewReader(`{}`), os.Stdout)
	if err != nil {
		t.Errorf("expected no error, got %v", err)
	}
}

func TestSessionEnvHandler_Handle_WritesEnvVars(t *testing.T) {
	dir := t.TempDir()
	envFile := filepath.Join(dir, "env")
	versionFile := filepath.Join(dir, "VERSION")

	if err := os.WriteFile(versionFile, []byte("4.2.0\n"), 0600); err != nil {
		t.Fatal(err)
	}

	t.Setenv("CLAUDE_ENV_FILE", envFile)
	t.Setenv("BREEZING_ROLE", "")
	t.Setenv("BREEZING_SESSION_ID", "")
	t.Setenv("CLAUDE_CODE_REMOTE", "")

	h := &SessionEnvHandler{PluginRoot: dir}
	if err := h.Handle(strings.NewReader(`{}`), os.Stdout); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	data, err := os.ReadFile(envFile)
	if err != nil {
		t.Fatal(err)
	}
	content := string(data)

	checks := []string{
		"HARNESS_VERSION=4.2.0",
		"HARNESS_EFFORT_DEFAULT=medium",
		"HARNESS_AGENT_TYPE=solo",
		"HARNESS_IS_REMOTE=false",
	}
	for _, want := range checks {
		if !strings.Contains(content, want) {
			t.Errorf("expected %q in env file, got:\n%s", want, content)
		}
	}
	// BREEZING_SESSION_ID is empty, so it should not be present
	if strings.Contains(content, "HARNESS_BREEZING_SESSION_ID") {
		t.Errorf("expected no HARNESS_BREEZING_SESSION_ID, got:\n%s", content)
	}
}

func TestSessionEnvHandler_Handle_BreezingRole(t *testing.T) {
	dir := t.TempDir()
	envFile := filepath.Join(dir, "env")

	t.Setenv("CLAUDE_ENV_FILE", envFile)
	t.Setenv("BREEZING_ROLE", "worker")
	t.Setenv("BREEZING_SESSION_ID", "sess-123")
	t.Setenv("CLAUDE_CODE_REMOTE", "true")

	h := &SessionEnvHandler{PluginRoot: dir}
	if err := h.Handle(strings.NewReader(`{}`), os.Stdout); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	data, err := os.ReadFile(envFile)
	if err != nil {
		t.Fatal(err)
	}
	content := string(data)

	checks := []string{
		"HARNESS_AGENT_TYPE=worker",
		"HARNESS_IS_REMOTE=true",
		"HARNESS_BREEZING_SESSION_ID=sess-123",
	}
	for _, want := range checks {
		if !strings.Contains(content, want) {
			t.Errorf("expected %q in env file, got:\n%s", want, content)
		}
	}
}

func TestSessionEnvHandler_Handle_MissingVersionFile(t *testing.T) {
	dir := t.TempDir()
	envFile := filepath.Join(dir, "env")

	t.Setenv("CLAUDE_ENV_FILE", envFile)
	t.Setenv("BREEZING_ROLE", "")
	t.Setenv("BREEZING_SESSION_ID", "")
	t.Setenv("CLAUDE_CODE_REMOTE", "")

	// No VERSION file
	h := &SessionEnvHandler{PluginRoot: dir}
	if err := h.Handle(strings.NewReader(`{}`), os.Stdout); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	data, err := os.ReadFile(envFile)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(string(data), "HARNESS_VERSION=unknown") {
		t.Errorf("expected HARNESS_VERSION=unknown, got:\n%s", string(data))
	}
}
