// DDouns substrate hot-path helpers — supporting code for guard rules
// R14 (closure invariant), R15 (dedup gate), R16 (attestation).
//
// The three rule literals themselves live inline in the Rules slice in
// rules.go. This file holds:
//   - hot-path subprocess invocation (ddounsCheckQuick)
//   - typed response shapes for the three substrate checks
//   - shared regex (memoryFilePattern) for R16 path scoping
//   - plan_id resolution from hook env
//
// Spec reference: docs/spec/wave-1-invariants-v1.md (Invariants 1, 2, 3).
//
// Copyright 2026 the DDouns authors (Apache-2.0).
// Co-Authored-By: cmyoya/DDouns <noreply@ddouns.dev>

package guardrail

import (
	"context"
	"encoding/json"
	"os"
	"regexp"
	"strings"
	"time"

	"github.com/Chachamaru127/claude-code-harness/go/internal/ddouns"
)

const hotPathBudget = 25 * time.Millisecond

var memoryFilePattern = regexp.MustCompile(
	`(?i)(?:^|/)(?:\.claude/(?:projects/[^/]+/)?memory/[^/]+\.md` +
		`|MEMORY\.md` +
		`|knowledge/[^/]+/(?:CLAUDE\.md|deep/episodes/[^/]+\.md))$`,
)

type ddounsClosureResp struct {
	Violation bool   `json:"violation"`
	Predicate string `json:"predicate,omitempty"`
	Detail    string `json:"detail,omitempty"`
}

type ddounsDedupResp struct {
	Collision   bool    `json:"collision"`
	Neighbor    string  `json:"neighbor,omitempty"`
	Similarity  float64 `json:"similarity,omitempty"`
	Explanation string  `json:"explanation,omitempty"`
}

type ddounsAttestResp struct {
	Attested    bool   `json:"attested"`
	PlanID      string `json:"plan_id,omitempty"`
	NeedsAttest bool   `json:"needs_attest"`
	Reason      string `json:"reason,omitempty"`
}

// ddounsCheckQuick invokes a `ddouns <subcmd> --quick --json` subprocess
// and JSON-decodes its stdout into v.
//
// content: when non-empty, the bytes are written to a tempfile and the
// tempfile path is appended to args as the positional <path> argument
// the DDouns substrate CLI expects (see cmyoya/DDouns spec/companion-
// contract-v1.md). When empty, args are passed through unchanged
// (R16/attest reads the on-disk file via the caller-provided path).
//
// Threading the proposed edit through a tempfile is required because
// the substrate CLI subcommands are positional-path designs by spec —
// they read from disk, not stdin — and Write/Edit/MultiEdit hooks need
// the candidate edit checked, not the pre-edit on-disk state.
func ddounsCheckQuick(subcmd string, args []string, content string, v interface{}) bool {
	ctx, cancel := context.WithTimeout(context.Background(), hotPathBudget)
	defer cancel()

	finalArgs := args
	if content != "" {
		tmpPath, cleanup, err := writeContentTemp(content)
		if err != nil {
			return false
		}
		defer cleanup()
		finalArgs = append(append([]string{}, args...), tmpPath)
	}

	full := append([]string{"--quick", "--json"}, finalArgs...)
	result, err := ddouns.Run(ctx, subcmd, full, false)
	if err != nil {
		return false
	}
	out := strings.TrimSpace(result.Stdout)
	if out == "" {
		return false
	}
	if err := json.Unmarshal([]byte(out), v); err != nil {
		return false
	}
	return true
}

// writeContentTemp materialises content to a uniquely-named temp file
// in the OS temp dir and returns the path plus a cleanup func. Caller
// MUST defer cleanup() to remove the file.
func writeContentTemp(content string) (string, func(), error) {
	f, err := os.CreateTemp("", "ddouns-edit-*.md")
	if err != nil {
		return "", func() {}, err
	}
	if _, err := f.WriteString(content); err != nil {
		_ = f.Close()
		_ = os.Remove(f.Name())
		return "", func() {}, err
	}
	if err := f.Close(); err != nil {
		_ = os.Remove(f.Name())
		return "", func() {}, err
	}
	return f.Name(), func() { _ = os.Remove(f.Name()) }, nil
}

func resolvePlanID() string {
	if v := strings.TrimSpace(os.Getenv("DDOUNS_PLAN_ID")); v != "" {
		return v
	}
	if v := strings.TrimSpace(os.Getenv("HARNESS_ACTIVE_PLAN_ID")); v != "" {
		return v
	}
	return ""
}
