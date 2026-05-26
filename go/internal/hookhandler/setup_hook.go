package hookhandler

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	"github.com/Chachamaru127/claude-code-harness/go/internal/harnessmem"
)

// setupInput is the stdin JSON payload for the Setup hook.
type setupInput struct {
	HookEventName string `json:"hook_event_name"`
	SessionID     string `json:"session_id"`
	Mode          string `json:"mode"` // "init" or "maintenance"
}

// setupOutput is the response format for the Setup hook.
type setupOutput struct {
	HookSpecificOutput struct {
		HookEventName     string `json:"hookEventName"`
		AdditionalContext string `json:"additionalContext"`
	} `json:"hookSpecificOutput"`
}

// writeSetupOutput writes a Setup hook response.
func writeSetupOutput(w io.Writer, message string) error {
	var out setupOutput
	out.HookSpecificOutput.HookEventName = "Setup"
	out.HookSpecificOutput.AdditionalContext = message
	return writeJSON(w, out)
}

// isSimpleMode detects simple mode via the CLAUDE_CODE_SIMPLE environment variable.
// Corresponds to the is_simple_mode() function in check-simple-mode.sh.
func isSimpleMode() bool {
	val := strings.ToLower(os.Getenv("CLAUDE_CODE_SIMPLE"))
	return val == "1" || val == "true" || val == "yes"
}

// runSyncPluginCache runs the plugin cache sync script if it exists.
func runSyncPluginCache(scriptDir string) {
	syncScript := filepath.Join(scriptDir, "sync-plugin-cache.sh")
	if _, err := os.Stat(syncScript); err == nil {
		cmd := exec.Command("bash", syncScript)
		_ = cmd.Run() // Errors are ignored
	}
}

// getPlansFilePath retrieves the path to Plans.md from the configuration.
// Native Go implementation using resolvePlansPath() from helpers.go.
// Eliminates the dependency on bash (config-utils.sh).
func getPlansFilePath(_ string) string {
	projectRoot := resolveProjectRoot()
	if path := resolvePlansPath(projectRoot); path != "" {
		return path
	}
	return filepath.Join(projectRoot, "Plans.md")
}

// runTemplateTracker runs the template tracker script.
func runTemplateTracker(scriptDir, action string) string {
	trackerScript := filepath.Join(scriptDir, "template-tracker.sh")
	if _, err := os.Stat(trackerScript); err == nil {
		cmd := exec.Command("bash", trackerScript, action)
		if out, err := cmd.Output(); err == nil {
			return strings.TrimSpace(string(out))
		}
	}
	return ""
}

// HandleSetupHookInit is a Go port of the init mode of setup-hook.sh.
//
// Performs the following initial setup steps:
//  1. Sync plugin cache
//  2. Initialize .claude/state/ directory
//  3. Generate default config file (if not present)
//  4. Generate CLAUDE.md (if not present)
//  5. Generate Plans.md (if not present)
//  6. Initialize template tracker
func HandleSetupHookInit(in io.Reader, out io.Writer) error {
	return handleSetupHook(in, out, "init")
}

// HandleSetupHookMaintenance is a Go port of the maintenance mode of setup-hook.sh.
//
// Performs the following maintenance steps:
//  1. Sync plugin cache
//  2. Delete session archives older than 7 days
//  3. Delete .tmp files
//  4. Check for template updates
//  5. Validate YAML syntax of config files
func HandleSetupHookMaintenance(in io.Reader, out io.Writer) error {
	return handleSetupHook(in, out, "maintenance")
}

// HandleSetupHook is a Go port of setup-hook.sh.
// Determines the mode from the stdin JSON payload or arguments.
func HandleSetupHook(in io.Reader, out io.Writer) error {
	return handleSetupHook(in, out, "")
}

// handleSetupHook is the internal implementation of setup-hook.sh.
// If mode is empty, it is determined from the stdin payload.
func handleSetupHook(in io.Reader, out io.Writer, mode string) error {
	// Detect SIMPLE mode
	simpleMode := isSimpleMode()
	if simpleMode {
		fmt.Fprintf(os.Stderr, "[WARNING] CLAUDE_CODE_SIMPLE mode detected — skills/agents/memory disabled\n")
	}

	// Read JSON from stdin (errors are ignored)
	data, _ := io.ReadAll(in)

	// Determine mode from payload (argument takes precedence)
	if mode == "" {
		var input setupInput
		if len(data) > 0 {
			_ = json.Unmarshal(data, &input)
		}
		if input.Mode != "" {
			mode = input.Mode
		} else {
			mode = "init"
		}
	}

	// Resolve script directory (relative to the executing binary; falls back to cwd during tests)
	scriptDir := resolveSetupScriptDir()

	switch mode {
	case "init":
		return runSetupInit(out, scriptDir, simpleMode)
	case "maintenance":
		return runSetupMaintenance(out, scriptDir, simpleMode)
	default:
		return writeSetupOutput(out, fmt.Sprintf("[Setup] unknown mode: %s", mode))
	}
}

// resolveSetupScriptDir resolves the path to the script directory.
// Because hooks run in the CWD of the target project, a CWD-based lookup
// does not point to the harness installation directory. Resolution order:
//
//  1. CLAUDE_PLUGIN_ROOT environment variable (harness install location)
//  2. HARNESS_SCRIPT_DIR environment variable (explicit override)
//  3. CWD (fallback for development environments)
func resolveSetupScriptDir() string {
	if root := os.Getenv("CLAUDE_PLUGIN_ROOT"); root != "" {
		return filepath.Join(root, "scripts")
	}
	if dir := os.Getenv("HARNESS_SCRIPT_DIR"); dir != "" {
		return dir
	}
	// Fallback: scripts/ under the current directory (for development environments)
	cwd, _ := os.Getwd()
	return filepath.Join(cwd, "scripts")
}

// runSetupInit executes the init mode processing.
func runSetupInit(out io.Writer, scriptDir string, simpleMode bool) error {
	var messages []string

	// 1. Sync plugin cache
	syncScript := filepath.Join(scriptDir, "sync-plugin-cache.sh")
	if _, err := os.Stat(syncScript); err == nil {
		cmd := exec.Command("bash", syncScript)
		if err := cmd.Run(); err == nil {
			messages = append(messages, "plugin cache sync complete")
		}
	}

	// 2. Initialize state directory
	stateDir := ".claude/state"
	if err := os.MkdirAll(stateDir, 0o755); err == nil {
		// Initialization successful (existing directory is also OK)
	}

	// 3. Generate default config file
	configFile := ".claude-code-harness.config.yaml"
	if !fileExists(configFile) {
		templatePath := filepath.Join(scriptDir, "..", "templates", ".claude-code-harness.config.yaml.template")
		if _, err := os.Stat(templatePath); err == nil {
			if err := copyFile(templatePath, configFile); err == nil {
				messages = append(messages, "config file generated")
			}
		}
	}

	// 4. Generate CLAUDE.md
	if !fileExists("CLAUDE.md") {
		templatePath := filepath.Join(scriptDir, "..", "templates", "CLAUDE.md.template")
		if _, err := os.Stat(templatePath); err == nil {
			if err := copyFile(templatePath, "CLAUDE.md"); err == nil {
				messages = append(messages, "CLAUDE.md generated")
			}
		}
	}

	// 5. Generate Plans.md (respecting plansDirectory setting)
	plansPath := getPlansFilePath(scriptDir)
	if !fileExists(plansPath) {
		plansDir := filepath.Dir(plansPath)
		if plansDir != "." {
			_ = os.MkdirAll(plansDir, 0o755)
		}
		templatePath := filepath.Join(scriptDir, "..", "templates", "Plans.md.template")
		if _, err := os.Stat(templatePath); err == nil {
			if err := copyFile(templatePath, plansPath); err == nil {
				messages = append(messages, "Plans.md generated")
			}
		}
	}

	// 6. Initialize template tracker
	runTemplateTracker(scriptDir, "init")

	// 7. Auto-setup for harness-mem managed companion.
	// Failures do not stop the main Harness Setup hook.
	if result := harnessmem.AutoSetupFromSetupHook(harnessMemAutoSetupMarkerPath()); result.Attempted {
		if result.Ready {
			messages = append(messages, "harness-mem companion setup complete")
		} else {
			messages = append(messages, "harness-mem companion setup deferred")
		}
	} else if result.Ready {
		messages = append(messages, "harness-mem companion ready")
	}

	// Add SIMPLE mode warning
	if simpleMode {
		messages = append(messages, "WARNING: CLAUDE_CODE_SIMPLE mode — skills/agents/memory disabled, hooks only")
	}

	if len(messages) == 0 {
		return writeSetupOutput(out, "[Setup:init] Harness is already initialized")
	}
	return writeSetupOutput(out, "[Setup:init] "+strings.Join(messages, ", "))
}

func harnessMemAutoSetupMarkerPath() string {
	projectRoot := resolveProjectRoot()
	return filepath.Join(projectRoot, ".claude", "state", "harness-mem-companion-setup.json")
}

// runSetupMaintenance executes the maintenance mode processing.
func runSetupMaintenance(out io.Writer, scriptDir string, simpleMode bool) error {
	var messages []string

	// 1. Sync plugin cache
	syncScript := filepath.Join(scriptDir, "sync-plugin-cache.sh")
	if _, err := os.Stat(syncScript); err == nil {
		cmd := exec.Command("bash", syncScript)
		if err := cmd.Run(); err == nil {
			messages = append(messages, "cache sync complete")
		}
	}

	// 2. Clean up old session files (7+ days)
	stateDir := ".claude/state"
	archiveDir := filepath.Join(stateDir, "sessions")
	if _, err := os.Stat(archiveDir); err == nil {
		cutoff := time.Now().AddDate(0, 0, -7)
		entries, err := os.ReadDir(archiveDir)
		if err == nil {
			for _, entry := range entries {
				if !strings.HasPrefix(entry.Name(), "session-") || !strings.HasSuffix(entry.Name(), ".json") {
					continue
				}
				info, err := entry.Info()
				if err != nil {
					continue
				}
				if info.ModTime().Before(cutoff) {
					_ = os.Remove(filepath.Join(archiveDir, entry.Name()))
				}
			}
		}
		messages = append(messages, "old session archives deleted")
	}

	// 3. Clean up temporary files
	if _, err := os.Stat(stateDir); err == nil {
		removeTmpFiles(stateDir)
	}

	// 4. Check for template updates
	checkResult := runTemplateTracker(scriptDir, "check")
	if checkResult != "" {
		var checkData map[string]interface{}
		if err := json.Unmarshal([]byte(checkResult), &checkData); err == nil {
			if needsCheck, ok := checkData["needsCheck"].(bool); ok && needsCheck {
				updatesCount := 0
				if count, ok := checkData["updatesCount"].(float64); ok {
					updatesCount = int(count)
				}
				messages = append(messages, fmt.Sprintf("template updates available: %d", updatesCount))
			}
		}
	}

	// 5. Add SIMPLE mode warning
	if simpleMode {
		messages = append(messages, "WARNING: CLAUDE_CODE_SIMPLE mode — skills/agents/memory disabled, hooks only")
	}

	// 6. YAML syntax check of config file (if python3 is available)
	configFile := ".claude-code-harness.config.yaml"
	if fileExists(configFile) {
		if err := validateYAMLConfig(configFile); err != nil {
			messages = append(messages, "warning: config file syntax error")
		}
	}

	if len(messages) == 0 {
		return writeSetupOutput(out, "[Setup:maintenance] maintenance complete (no changes)")
	}
	return writeSetupOutput(out, "[Setup:maintenance] "+strings.Join(messages, ", "))
}

// copyFile copies a file.
func copyFile(src, dst string) error {
	data, err := os.ReadFile(src)
	if err != nil {
		return fmt.Errorf("read %s: %w", src, err)
	}
	return os.WriteFile(dst, data, 0o644)
}

// removeTmpFiles recursively deletes .tmp files within a directory.
func removeTmpFiles(dir string) {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return
	}
	for _, entry := range entries {
		path := filepath.Join(dir, entry.Name())
		if entry.IsDir() {
			removeTmpFiles(path)
			continue
		}
		if strings.HasSuffix(entry.Name(), ".tmp") {
			_ = os.Remove(path)
		}
	}
}

// validateYAMLConfig validates YAML syntax using python3.
func validateYAMLConfig(configFile string) error {
	if _, err := exec.LookPath("python3"); err != nil {
		return nil // Skip if python3 is not available
	}
	script := fmt.Sprintf("import yaml; yaml.safe_load(open(%q))", configFile)
	cmd := exec.Command("python3", "-c", script)
	return cmd.Run()
}
