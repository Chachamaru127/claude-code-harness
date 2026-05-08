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

func ddounsCheckQuick(subcmd string, args []string, v interface{}) bool {
	ctx, cancel := context.WithTimeout(context.Background(), hotPathBudget)
	defer cancel()

	full := append([]string{"--quick", "--json"}, args...)
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

func resolvePlanID() string {
	if v := strings.TrimSpace(os.Getenv("DDOUNS_PLAN_ID")); v != "" {
		return v
	}
	if v := strings.TrimSpace(os.Getenv("HARNESS_ACTIVE_PLAN_ID")); v != "" {
		return v
	}
	return ""
}
