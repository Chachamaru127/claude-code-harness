// Package ddouns provides a thin out-of-process companion driver for the
// DDouns substrate (closure invariant, dedup gate, attestation, hierarchical
// locks, audit). It is the Go analog of internal/harnessmem/companion.go and
// is intended to land at go/internal/ddouns/companion.go in the upstream PR.
//
// Contract: see DDouns docs/spec/wave-1-invariants-v1.md and
// docs/spec/companion-contract-v1.md. The harness never touches the DDouns
// SQLite/event-log directly — all interaction is via `ddouns <command> --json`
// over stdout, parsed into typed Go structs.
//
// Copyright 2026 the DDouns authors (Apache-2.0).
// Co-Authored-By: cmyoya/DDouns <noreply@ddouns.dev>
//
// This file is dual-licensed: the original claude-code-harness pattern is MIT
// (Chachamaru127); the DDouns adaptations are Apache-2.0. Both NOTICE files
// must be preserved when vendoring upstream.
package ddouns

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

const (
	// ContractVersion is the contract pin advertised by `ddouns doctor --json`
	// in its top-level `contract_version` field. Mismatch → fail-closed in the
	// caller (orchestration must not assume forward compat).
	ContractVersion = "ddouns-substrate.v1"

	defaultPipxPackage      = "ddouns"
	defaultCommandTimeout   = 90 * time.Second
	defaultSetupHookTimeout = 120 * time.Second
)

// ErrNotInstalled is returned when no DDouns CLI can be resolved and pipx
// fallback is not allowed by the caller.
var ErrNotInstalled = errors.New("ddouns is not installed")

// DoctorReport is the subset of `ddouns doctor --json` that
// claude-code-harness needs for orchestration. The harness never reads the
// DDouns event-log or SQLite schema directly. See companion-contract-v1.md.
type DoctorReport struct {
	Status          string          `json:"status"`
	AllGreen        bool            `json:"all_green"`
	FailedCount     int             `json:"failed_count"`
	Checks          json.RawMessage `json:"checks"`
	FixCommand      string          `json:"fix_command"`
	ContractVersion string          `json:"contract_version"`
	DDounsVersion   string          `json:"ddouns_version"`
}

// CommandResult mirrors harnessmem.CommandResult so callers can use the same
// shape across both companions.
type CommandResult struct {
	ExitCode int
	Stdout   string
	Stderr   string
}

// Invocation carries a resolved CLI command + any required arg prefix
// (e.g. `pipx run ddouns` requires `run ddouns` as a prefix before the
// subcommand).
type Invocation struct {
	Name      string
	ArgPrefix []string
	Installed bool
}

// ResolveInvocation finds an installed DDouns CLI. Resolution order:
//  1. $DDOUNS_CLI (explicit override — must be a runnable file path)
//  2. ~/.ddouns/runtime/ddouns/scripts/ddouns (default install location)
//  3. PATH lookup of `ddouns` (skipped when DDOUNS_DISABLE_PATH_LOOKUP=1)
//  4. If allowNpx is true, fall back to `pipx run ddouns` (Python equivalent
//     of npx — ephemeral install, no persistent state). This is named after
//     the harnessmem analog but pipx is what we actually invoke.
//
// The second return is `ok=false` when no CLI was resolvable and pipx fallback
// was not allowed; callers must treat that as ErrNotInstalled.
func ResolveInvocation(allowNpx bool) (Invocation, bool) {
	if cli := os.Getenv("DDOUNS_CLI"); cli != "" {
		return Invocation{Name: cli, Installed: true}, true
	}

	home, _ := os.UserHomeDir()
	if home != "" {
		candidate := filepath.Join(home, ".ddouns", "runtime", "ddouns", "scripts", "ddouns")
		if info, err := os.Stat(candidate); err == nil && !info.IsDir() {
			return Invocation{Name: candidate, Installed: true}, true
		}
	}

	if os.Getenv("DDOUNS_DISABLE_PATH_LOOKUP") != "1" {
		if path, err := exec.LookPath("ddouns"); err == nil {
			return Invocation{Name: path, Installed: true}, true
		}
	}

	if !allowNpx {
		return Invocation{}, false
	}

	pipxBin := os.Getenv("DDOUNS_PIPX_BIN")
	if pipxBin == "" {
		pipxBin = "pipx"
	}
	pkg := os.Getenv("DDOUNS_PIP_PACKAGE")
	if pkg == "" {
		pkg = defaultPipxPackage
	}
	return Invocation{
		Name:      pipxBin,
		ArgPrefix: []string{"run", pkg},
		Installed: false,
	}, true
}

// Run executes a single ddouns subcommand and captures stdout/stderr.
// It is the workhorse for Doctor() and for the R14/R15/R16 hot-path checks.
func Run(ctx context.Context, command string, args []string, allowNpx bool) (CommandResult, error) {
	inv, ok := ResolveInvocation(allowNpx)
	if !ok {
		return CommandResult{ExitCode: 127}, ErrNotInstalled
	}

	fullArgs := append([]string{}, inv.ArgPrefix...)
	fullArgs = append(fullArgs, command)
	fullArgs = append(fullArgs, args...)

	cmd := exec.CommandContext(ctx, inv.Name, fullArgs...)
	cmd.Env = withNonInteractiveEnv(os.Environ())

	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr

	err := cmd.Run()
	result := CommandResult{
		ExitCode: exitCode(err),
		Stdout:   stdout.String(),
		Stderr:   stderr.String(),
	}
	return result, err
}

// Stream is the streaming variant of Run, used for long-running interactive
// commands like `ddouns setup`. Hot-path guard rules MUST NOT use Stream —
// they use Run with a sub-second timeout and the --quick flag.
func Stream(ctx context.Context, command string, args []string, allowNpx bool, stdout, stderr io.Writer) (int, error) {
	inv, ok := ResolveInvocation(allowNpx)
	if !ok {
		fmt.Fprintln(stderr, "ddouns is not installed")
		return 127, ErrNotInstalled
	}

	fullArgs := append([]string{}, inv.ArgPrefix...)
	fullArgs = append(fullArgs, command)
	fullArgs = append(fullArgs, args...)

	cmd := exec.CommandContext(ctx, inv.Name, fullArgs...)
	cmd.Env = withNonInteractiveEnv(os.Environ())
	cmd.Stdout = stdout
	cmd.Stderr = stderr

	err := cmd.Run()
	return exitCode(err), err
}

// Doctor calls `ddouns doctor --json` and parses the typed contract response.
// Used by `harness doctor` to surface DDouns substrate health alongside
// harness-mem health.
func Doctor(ctx context.Context, allowNpx bool) (DoctorReport, CommandResult, error) {
	result, err := Run(ctx, "doctor", []string{"--json", "--skip-version-check"}, allowNpx)
	if errors.Is(err, ErrNotInstalled) {
		return DoctorReport{}, result, err
	}
	if strings.TrimSpace(result.Stdout) == "" {
		if err != nil {
			return DoctorReport{}, result, err
		}
		return DoctorReport{}, result, fmt.Errorf("doctor returned empty stdout")
	}

	var report DoctorReport
	if jsonErr := json.Unmarshal([]byte(result.Stdout), &report); jsonErr != nil {
		return DoctorReport{}, result, fmt.Errorf("doctor returned invalid JSON: %w", jsonErr)
	}
	return report, result, err
}

// AutoSetupResult mirrors the harnessmem variant for SessionStart hook reuse.
type AutoSetupResult struct {
	Attempted bool
	Skipped   bool
	Ready     bool
	Reason    string
	ExitCode  int
}

// AutoSetupFromSetupHook is the SessionStart bootstrap. It runs `ddouns doctor`
// once per session; if not all-green and CLAUDE_CODE_HARNESS_DDOUNS_AUTO_SETUP
// is not "0", it runs `ddouns setup` via pipx (ephemeral) so first-time users
// don't have to bootstrap manually.
func AutoSetupFromSetupHook(markerPath string) AutoSetupResult {
	if os.Getenv("CLAUDE_CODE_HARNESS_DDOUNS_AUTO_SETUP") == "0" {
		return AutoSetupResult{Skipped: true, Reason: "disabled"}
	}
	if markerPath != "" {
		if _, err := os.Stat(markerPath); err == nil {
			return AutoSetupResult{Skipped: true, Reason: "already-attempted"}
		}
	}

	ctx, cancel := context.WithTimeout(context.Background(), defaultSetupHookTimeout)
	defer cancel()

	report, _, err := Doctor(ctx, false)
	if err == nil && report.AllGreen {
		writeMarker(markerPath, "ready")
		return AutoSetupResult{Skipped: true, Ready: true, Reason: "already-ready"}
	}

	setupArgs := []string{"--non-interactive", "--accept-defaults"}
	result, setupErr := Run(ctx, "setup", setupArgs, true)
	writeMarker(markerPath, "attempted")

	if setupErr != nil {
		reason := strings.TrimSpace(result.Stderr)
		if reason == "" {
			reason = setupErr.Error()
		}
		return AutoSetupResult{Attempted: true, Reason: reason, ExitCode: result.ExitCode}
	}

	return AutoSetupResult{Attempted: true, Ready: true, Reason: "setup-complete", ExitCode: 0}
}

// DefaultTimeoutContext returns a context with the 90s default command
// budget. Hot-path guard rules MUST use a separate, much shorter context
// (sub-10ms with --quick), not this one.
func DefaultTimeoutContext() (context.Context, context.CancelFunc) {
	return context.WithTimeout(context.Background(), defaultCommandTimeout)
}

func withNonInteractiveEnv(env []string) []string {
	filtered := make([]string, 0, len(env)+1)
	seen := false
	for _, item := range env {
		if strings.HasPrefix(item, "DDOUNS_NON_INTERACTIVE=") {
			filtered = append(filtered, "DDOUNS_NON_INTERACTIVE=1")
			seen = true
			continue
		}
		filtered = append(filtered, item)
	}
	if !seen {
		filtered = append(filtered, "DDOUNS_NON_INTERACTIVE=1")
	}
	return filtered
}

func exitCode(err error) int {
	if err == nil {
		return 0
	}
	var exitErr *exec.ExitError
	if errors.As(err, &exitErr) {
		return exitErr.ExitCode()
	}
	return 1
}

func writeMarker(path, status string) {
	if path == "" {
		return
	}
	_ = os.MkdirAll(filepath.Dir(path), 0o755)
	payload := map[string]string{
		"status":       status,
		"attempted_at": time.Now().UTC().Format(time.RFC3339),
		"contract":     ContractVersion,
	}
	data, _ := json.Marshal(payload)
	_ = os.WriteFile(path, append(data, '\n'), 0o644)
}
