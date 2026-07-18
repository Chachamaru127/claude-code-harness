package policy

// Deny-surface self-audit (Phase 91.6 FLOOR).
//
// The guard rules R01-R15 are "the chain that constrains the agent": a subset
// of them can emit a DENY decision (force-push, reset --hard on a protected
// branch, secret / protected-path writes, Codex-mode direct writes, etc.). If
// that chain is silently weakened — a deny rule removed, or its triggering
// matcher narrowed so it no longer denies — an untrusted (codex/cursor) change
// could be adjudicated by a compromised policy and slip through the FLOOR.
//
// This file captures a stable fingerprint of the deny surface at build time and
// lets the gate entrypoints verify, before they adjudicate anything, that the
// live surface has not REGRESSED relative to that baseline. Following
// .claude/rules/self-audit.md, the check detects REDUCTION (missing rule or a
// changed deny signature), not absolute count: adding new deny rules is
// strengthening and is always allowed.
//
// Deny-signature representation
// -----------------------------
// Each rule that can deny contributes one entry "<ruleID>:<sha256-hex>". The
// hash covers only the *stable identifying parts that make the rule deny*:
//
//   - the rule's ID,
//   - its tool matcher (the regexp source of GuardRule.ToolPattern),
//   - the literal token "decision=deny", and
//   - a canonical descriptor of the condition under which the rule denies —
//     the sorted regexp sources of the patterns that gate the deny (for the
//     protected-path rules R02/R03 this is the set of deny-level path patterns;
//     for the command rules it is the helper's matcher source(s)).
//
// Consequences of this choice:
//   - Removing a deny rule drops its entry  → VerifyDenySurface fails (weakened).
//   - Narrowing a deny pattern (deleting one of the deny-level patterns, or
//     editing its source) changes the descriptor → signature changes → fails.
//   - Editing an unrelated part of the engine — a warn/ask pattern, a deny
//     *reason* string, the order of unrelated rules — does NOT touch any deny
//     signature, so it does not false-positive.
//
// The package stays standard-library only (crypto/sha256, sort, fmt, strings).

import (
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"regexp"
	"sort"
	"strings"
)

// denyRuleSignature describes, for one rule that can emit a deny decision, the
// stable parts whose change would mean the deny was removed or weakened.
type denyRuleSignature struct {
	ruleID string
	// matchers are the regexp sources that gate this rule's deny path. They are
	// sorted before hashing so reordering the underlying slice is not treated as
	// a change. Narrowing the deny (dropping a pattern) or editing a pattern's
	// source changes this set and therefore the signature.
	matchers []string
}

// denyRuleSignatures enumerates every rule in Rules that can return a
// DecisionDeny, paired with the matcher sources that gate that deny. It is
// derived from rules.go / helpers.go / protected_path.go; if a deny rule is
// added there, add it here too (and regenerate baselineDenySurface) so the
// surface stays a faithful mirror.
//
// Rules deliberately omitted (they never deny):
//   - R04, R05  → DecisionAsk
//   - R09, R13  → warn (approve + systemMessage)
//   - R14       → local-trial no-op
//
// R12 (direct push to a protected branch) is included: it CAN deny, under the
// `protected_branch_push=deny` configuration. Its deny is gated by the same
// detector regardless of the runtime policy value, so the matcher captures the
// detector, not the policy setting.
func denyRuleSignatures() []denyRuleSignature {
	return []denyRuleSignature{
		{ruleID: "R01:no-sudo", matchers: regexpSources(sudoPattern)},
		// R02/R03 deny via the protected-path taxonomy: the deny is the set of
		// deny-LEVEL path patterns. Narrowing that set (removing .env, .git, a
		// .pem rule, …) is exactly the weakening this surface must catch.
		{ruleID: "R02:no-write-protected-paths", matchers: protectedPathDenyPatternSources()},
		{ruleID: "R03:no-bash-write-protected-paths", matchers: protectedPathDenyPatternSources()},
		{ruleID: "R06:no-force-push", matchers: regexpSources(forcePushPattern, forcePushShort)},
		// R07 (Codex mode) and R08 (Breezing reviewer) deny on a context flag, not
		// a pattern; their condition descriptor is the flag predicate. R08 also has
		// the Bash prohibited-command patterns, which gate the Bash branch's deny.
		{ruleID: "R07:codex-mode-no-write", matchers: []string{"ctx.CodexMode"}},
		{ruleID: "R08:breezing-reviewer-no-write", matchers: append([]string{`ctx.BreezingRole=="reviewer"`}, regexpSources(r08ReviewerProhibitedPatterns...)...)},
		{ruleID: "R10:no-git-bypass-flags", matchers: regexpSources(noVerifyPattern, noGpgSignPattern)},
		{ruleID: "R11:no-reset-hard-protected-branch", matchers: regexpSources(protectedBranchRefPattern)},
		{ruleID: "R12:confirm-direct-push-protected-branch", matchers: append(regexpSources(gitPushPattern, protectedBranchRefPattern), "policy=deny")},
		{ruleID: "R15:no-stage-secret-file", matchers: append(regexpSources(r15SecretStagingPatterns...), "except="+publicEnvTemplatePattern.String(), "git-add-stage-commit-pathspec", "quote-aware-shell-lexer")},
	}
}

// regexpSources returns the source strings of the given patterns, in argument
// order (the caller's intent), before the per-rule sort in signature().
func regexpSources(patterns ...*regexp.Regexp) []string {
	out := make([]string, 0, len(patterns))
	for _, p := range patterns {
		out = append(out, p.String())
	}
	return out
}

// protectedPathDenyPatternSources returns the sorted regexp sources of every
// deny-LEVEL rule in protectedPathRules. R02 (Write/Edit) and R03 (Bash) both
// reach deny exclusively through these patterns, so this set is their deny
// condition. Sorting makes the result order-independent.
func protectedPathDenyPatternSources() []string {
	var out []string
	for _, rule := range protectedPathRules {
		if rule.level == protectedPathDeny {
			descriptor := rule.pattern.String()
			if rule.pattern == envFileDenyPattern {
				descriptor += " except=" + publicEnvTemplatePattern.String()
			}
			out = append(out, descriptor)
		}
	}
	sort.Strings(out)
	return out
}

// signature hashes the stable deny-identifying parts of one rule into a hex
// SHA-256 string. Matchers are sorted so the hash is independent of slice order.
func (s denyRuleSignature) signature() string {
	matchers := append([]string(nil), s.matchers...)
	sort.Strings(matchers)

	h := sha256.New()
	// Field-separated, length-free domain tokens keep the hash unambiguous: the
	// "decision=deny" literal binds the signature to the fact that this rule
	// denies, so a rule mutated to stop denying could not reproduce it.
	h.Write([]byte("ruleID="))
	h.Write([]byte(s.ruleID))
	h.Write([]byte("\x00decision=deny\x00matchers="))
	h.Write([]byte(strings.Join(matchers, "\x1f")))
	return hex.EncodeToString(h.Sum(nil))
}

// computeDenySurface builds the sorted "<ruleID>:<sha256-hex>" fingerprint from
// the given rule signatures. It is the shared core of DenySurface() (live) and
// the baseline generator, so both are produced identically.
func computeDenySurface(sigs []denyRuleSignature) []string {
	out := make([]string, 0, len(sigs))
	for _, s := range sigs {
		out = append(out, s.ruleID+":"+s.signature())
	}
	sort.Strings(out)
	return out
}

// DenySurface returns a stable, sorted fingerprint of every rule that can emit a
// deny decision: each entry is "<ruleID>:<sha256-of-its-deny-signature>".
func DenySurface() []string {
	return computeDenySurface(denyRuleSignatures())
}

// baselineDenySurface is the expected deny surface captured at build time (the
// required deny rules plus their signatures). It is generated FROM the current
// DenySurface() — see the generator comment below — so VerifyDenySurface()
// passes today and only fails when the live surface regresses.
//
// To regenerate after intentionally changing a deny rule:
//
//	go test ./internal/policy/ -run TestDenySurface_PrintBaseline -v
//
// and paste the printed slice here.
var baselineDenySurface = []string{
	"R01:no-sudo:3d90ab7cf0b192d7fd9b6267693d75b8015a379ba75da09022850322c695e6f0",
	"R02:no-write-protected-paths:29429e94fe28594af8edb8c546b87b9726043aecf7623c0df0dcf9a93f2e36f7",
	"R03:no-bash-write-protected-paths:5b31f8cea6641053e56feae079f52f67b96b6b9220066a77319497526ad6bd71",
	"R06:no-force-push:7320e66b09a8fd7c4cf6b24a800b7b78b8b82181720ca722bb6ab4002fc574a2",
	"R07:codex-mode-no-write:9d6770d2cb308bf2a3eb48c420b44658f2befaa642d652eeb348f54b3529213d",
	"R08:breezing-reviewer-no-write:24fc5cdcd6523b736e87ce797afa85493d8364109133fd68a119222531c2860d",
	"R10:no-git-bypass-flags:4a9a63d2d3a4f496d16fb4f2e135b060d741b95006278c249c526ae683c732c5",
	"R11:no-reset-hard-protected-branch:7b0ffd50649b06d0fc4630cdbbf134e4278f3dbe707df381521b87c0a7a61bfd",
	"R12:confirm-direct-push-protected-branch:1f47124d7cec9dd1ec43abc991b8ab054c756cd56d0d5bbc407ea4137b50de6b",
	"R15:no-stage-secret-file:d1953619a0859c4b5337766f90c981bd88611d9847aacce95b2a40fbbe578cc4",
}

// compareDenySurfaces reports whether current is WEAKENED relative to baseline.
// It is the pure comparator used by VerifyDenySurface and exercised directly by
// tests (so a simulated surface can be passed without mutating the real rule
// table).
//
// Weakening = a baseline rule's deny signature is missing from current. That
// covers both "rule removed" (its "<id>:<sig>" entry is gone) and "deny
// narrowed" (the id may still appear, but with a different signature, so the
// baseline entry is absent). Entries present in current but absent from
// baseline are NEW deny rules — strengthening — and are allowed.
func compareDenySurfaces(current, baseline []string) error {
	live := make(map[string]struct{}, len(current))
	for _, e := range current {
		live[e] = struct{}{}
	}

	var missing []string
	for _, b := range baseline {
		if _, ok := live[b]; !ok {
			missing = append(missing, b)
		}
	}
	if len(missing) == 0 {
		return nil
	}
	sort.Strings(missing)
	return fmt.Errorf(
		"deny surface weakened: %d baseline deny rule(s) missing or with a changed deny signature: %s",
		len(missing), strings.Join(missing, ", "),
	)
}

// VerifyDenySurface returns an error iff the current deny surface is WEAKENED
// relative to baseline: a baseline ruleID is missing, or a baseline rule's deny
// signature changed. Adding NEW deny rules (not in baseline) is allowed
// (strengthening). It is called fail-closed at the FLOOR / gate entrypoints
// before they adjudicate any untrusted change.
func VerifyDenySurface() error {
	return compareDenySurfaces(DenySurface(), baselineDenySurface)
}
