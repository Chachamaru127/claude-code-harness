package policy

import (
	"strings"
	"testing"
)

// TestDenySurface_PrintBaseline is a generator helper, not an assertion. Run it
// with -v to print the literal slice for baselineDenySurface after intentionally
// changing a deny rule:
//
//	go test ./internal/policy/ -run TestDenySurface_PrintBaseline -v
func TestDenySurface_PrintBaseline(t *testing.T) {
	var b strings.Builder
	b.WriteString("\nvar baselineDenySurface = []string{\n")
	for _, e := range DenySurface() {
		b.WriteString("\t\"" + e + "\",\n")
	}
	b.WriteString("}\n")
	t.Log(b.String())
}

// TestVerifyDenySurface_IntactPasses is the load-bearing invariant: on the
// current rule table the live surface equals the baseline, so verification
// passes. If a deny rule is removed/narrowed without regenerating the baseline,
// this fails — which is the point.
func TestVerifyDenySurface_IntactPasses(t *testing.T) {
	if err := VerifyDenySurface(); err != nil {
		t.Fatalf("VerifyDenySurface() on the intact surface = %v, want nil "+
			"(regenerate baselineDenySurface via TestDenySurface_PrintBaseline if a deny rule changed intentionally)", err)
	}
}

// TestDenySurface_StableAndNonEmpty guards the fingerprint shape: it is sorted,
// non-empty, and every entry is "<ruleID>:<64-hex>". A malformed signature would
// make the comparator meaningless.
func TestDenySurface_StableAndNonEmpty(t *testing.T) {
	surface := DenySurface()
	if len(surface) == 0 {
		t.Fatal("DenySurface() is empty; no deny rules enumerated")
	}
	for i, e := range surface {
		if i > 0 && surface[i-1] >= e {
			t.Errorf("DenySurface() not strictly sorted at %d: %q !< %q", i, surface[i-1], e)
		}
		// The ruleID itself contains a colon ("R01:no-sudo"), so the signature is
		// the segment after the LAST colon.
		idx := strings.LastIndex(e, ":")
		if idx <= 0 {
			t.Errorf("entry %q is not <ruleID>:<sig>", e)
			continue
		}
		id, sig := e[:idx], e[idx+1:]
		if id == "" {
			t.Errorf("entry %q has an empty ruleID", e)
		}
		if len(sig) != 64 {
			t.Errorf("entry %q: signature len = %d, want 64 (sha256 hex)", e, len(sig))
		}
	}
	// Calling it twice yields identical output (no map iteration leakage).
	second := DenySurface()
	if strings.Join(surface, "|") != strings.Join(second, "|") {
		t.Error("DenySurface() not deterministic across calls")
	}
}

// TestCompareDenySurfaces_WeakeningFails simulates a weakened surface by DROPPING
// one baseline entry from the "current" set (as if a deny rule were removed or
// its pattern narrowed). The comparator must reject it. This uses the internal
// comparator so the real Rules table is never mutated.
func TestCompareDenySurfaces_WeakeningFails(t *testing.T) {
	baseline := DenySurface()
	if len(baseline) < 2 {
		t.Fatalf("need >= 2 baseline entries to drop one, have %d", len(baseline))
	}

	for drop := range baseline {
		weakened := make([]string, 0, len(baseline)-1)
		for i, e := range baseline {
			if i == drop {
				continue
			}
			weakened = append(weakened, e)
		}
		err := compareDenySurfaces(weakened, baseline)
		if err == nil {
			t.Fatalf("dropping baseline[%d]=%q did not fail verification (weakening undetected)", drop, baseline[drop])
		}
		// The missing rule's ID must be named in the error for actionability.
		id := strings.SplitN(baseline[drop], ":", 2)[0]
		if !strings.Contains(err.Error(), id) {
			t.Errorf("error %q does not name the dropped rule %q", err.Error(), id)
		}
	}
}

// TestCompareDenySurfaces_NarrowedSignatureFails simulates a deny pattern being
// NARROWED: the rule ID still appears in current, but with a different
// signature. Because the baseline entry binds id+signature, its absence is
// detected even though the ID is still present (i.e. it is not enough for a
// weakened rule to merely keep its name).
func TestCompareDenySurfaces_NarrowedSignatureFails(t *testing.T) {
	baseline := DenySurface()
	current := append([]string(nil), baseline...)

	// Mutate the signature of the first entry, preserving its ruleID prefix.
	id := strings.SplitN(baseline[0], ":", 2)[0]
	current[0] = id + ":0000000000000000000000000000000000000000000000000000000000000000"

	err := compareDenySurfaces(current, baseline)
	if err == nil {
		t.Fatalf("a narrowed signature for %q was not detected as weakening", id)
	}
	if !strings.Contains(err.Error(), baseline[0]) {
		t.Errorf("error %q does not name the original baseline entry %q", err.Error(), baseline[0])
	}
}

// TestCompareDenySurfaces_StrengtheningAllowed adds a synthetic EXTRA deny entry
// (a rule not in baseline) to the current set. Strengthening must NOT fail: the
// chain getting stronger is always allowed.
func TestCompareDenySurfaces_StrengtheningAllowed(t *testing.T) {
	baseline := DenySurface()
	current := append(append([]string(nil), baseline...),
		"R99:synthetic-extra-deny:1111111111111111111111111111111111111111111111111111111111111111")

	if err := compareDenySurfaces(current, baseline); err != nil {
		t.Fatalf("adding a new deny rule (strengthening) must not fail, got %v", err)
	}
}

// TestCompareDenySurfaces_IdenticalPasses is the trivial baseline: a surface
// compared against itself passes.
func TestCompareDenySurfaces_IdenticalPasses(t *testing.T) {
	s := DenySurface()
	if err := compareDenySurfaces(s, s); err != nil {
		t.Fatalf("identical surfaces must pass, got %v", err)
	}
}

// TestDenySurface_CoversExpectedRules pins the membership of the deny surface to
// the rules that actually deny in rules.go, and asserts the non-deny rules
// (R04/R05 ask, R09/R13 warn, R14 no-op) are NOT present. This catches a future
// edit that makes a rule deny (or stop denying) without updating the surface.
func TestDenySurface_CoversExpectedRules(t *testing.T) {
	present := map[string]bool{}
	for _, e := range DenySurface() {
		present[strings.SplitN(e, ":", 2)[0]] = true
	}

	wantDeny := []string{
		"R01", "R02", "R03", "R06", "R07", "R08", "R10", "R11", "R12", "R16",
	}
	for _, id := range wantDeny {
		if !present[id] {
			t.Errorf("deny surface missing expected deny rule %q", id)
		}
	}

	wantAbsent := []string{"R04", "R05", "R09", "R13", "R14"}
	for _, id := range wantAbsent {
		if present[id] {
			t.Errorf("non-deny rule %q must not be in the deny surface", id)
		}
	}
}
