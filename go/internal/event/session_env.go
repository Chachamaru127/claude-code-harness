package event

import (
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
)

// SessionEnvHandler is the SessionStart hook handler.
// It uses CLAUDE_ENV_FILE to set harness environment variables.
//
// Shell version: scripts/hook-handlers/session-env-setup.sh
type SessionEnvHandler struct {
	// PluginRoot is the root directory to search for the version file.
	// If empty, it is obtained from the CLAUDE_PLUGIN_ROOT environment variable.
	PluginRoot string
}

// SessionEnvVars is the set of harness environment variables.
type SessionEnvVars struct {
	HarnessVersion           string
	HarnessEffortDefault     string
	HarnessAgentType         string
	HarnessIsRemote          string
	HarnessBreezingSessionID string // Not written if empty
}

// Handle reads a SessionStart payload from stdin and
// writes harness environment variables to CLAUDE_ENV_FILE.
// Does nothing if CLAUDE_ENV_FILE is not set.
func (h *SessionEnvHandler) Handle(r io.Reader, _ io.Writer) error {
	// Skip if CLAUDE_ENV_FILE is not set
	envFile := os.Getenv("CLAUDE_ENV_FILE")
	if envFile == "" {
		return nil
	}

	// Read stdin, but tool_name is not needed for SessionStart
	// (ignore errors and continue processing)
	_, _ = io.ReadAll(r)

	vars := h.buildEnvVars()
	return h.writeEnvFile(envFile, vars)
}

// buildEnvVars constructs SessionEnvVars from the current environment variables.
func (h *SessionEnvHandler) buildEnvVars() SessionEnvVars {
	pluginRoot := h.PluginRoot
	if pluginRoot == "" {
		pluginRoot = os.Getenv("CLAUDE_PLUGIN_ROOT")
	}

	version := h.readVersion(pluginRoot)

	agentType := os.Getenv("BREEZING_ROLE")
	if agentType == "" {
		agentType = "solo"
	}

	isRemote := os.Getenv("CLAUDE_CODE_REMOTE")
	if isRemote == "" {
		isRemote = "false"
	}

	return SessionEnvVars{
		HarnessVersion:           version,
		HarnessEffortDefault:     "medium",
		HarnessAgentType:         agentType,
		HarnessIsRemote:          isRemote,
		HarnessBreezingSessionID: os.Getenv("BREEZING_SESSION_ID"),
	}
}

// readVersion reads the version string from the VERSION file.
func (h *SessionEnvHandler) readVersion(pluginRoot string) string {
	if pluginRoot == "" {
		return "unknown"
	}

	data, err := os.ReadFile(filepath.Join(pluginRoot, "VERSION"))
	if err != nil {
		return "unknown"
	}

	v := strings.TrimSpace(string(data))
	if v == "" {
		return "unknown"
	}
	return v
}

// writeEnvFile appends harness environment variables to CLAUDE_ENV_FILE.
func (h *SessionEnvHandler) writeEnvFile(envFile string, vars SessionEnvVars) error {
	// Symlink check (security)
	if isSymlink(envFile) {
		return fmt.Errorf("security: symlinked env file refused: %s", envFile)
	}

	f, err := os.OpenFile(envFile, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0600)
	if err != nil {
		return fmt.Errorf("opening env file: %w", err)
	}
	defer f.Close()

	lines := []string{
		fmt.Sprintf("HARNESS_VERSION=%s", vars.HarnessVersion),
		fmt.Sprintf("HARNESS_EFFORT_DEFAULT=%s", vars.HarnessEffortDefault),
		fmt.Sprintf("HARNESS_AGENT_TYPE=%s", vars.HarnessAgentType),
		fmt.Sprintf("HARNESS_IS_REMOTE=%s", vars.HarnessIsRemote),
	}
	if vars.HarnessBreezingSessionID != "" {
		lines = append(lines, fmt.Sprintf("HARNESS_BREEZING_SESSION_ID=%s", vars.HarnessBreezingSessionID))
	}

	for _, line := range lines {
		if _, err := fmt.Fprintln(f, line); err != nil {
			return fmt.Errorf("writing env file: %w", err)
		}
	}
	return nil
}
