package rulecoverage

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// readReal loads the live repo files the analyzer scans. Paths are relative to
// this package dir (go/internal/rulecoverage).
func readReal(t *testing.T) (rules, selfaudit, shellGate string, tests []string) {
	t.Helper()
	read := func(p string) string {
		b, err := os.ReadFile(p)
		if err != nil {
			t.Fatalf("read %s: %v", p, err)
		}
		return string(b)
	}
	rules = read("../policy/rules.go")
	selfaudit = read("../policy/selfaudit.go")
	shellGate = read("../../../tests/validate-plugin.sh")
	matches, err := filepath.Glob("../policy/*_test.go")
	if err != nil {
		t.Fatalf("glob test files: %v", err)
	}
	for _, m := range matches {
		tests = append(tests, read(m))
	}
	return
}

func TestCoverage_MatrixCountsMatchExpected(t *testing.T) {
	rules, selfaudit, shellGate, tests := readReal(t)
	m := BuildMatrix(rules, selfaudit, shellGate, tests...)
	c := Summarize(m)

	// Lock the numbers so future drift is caught (the U3 "4/14 gated" finding).
	if c.Total != 16 {
		t.Fatalf("expected 16 defined rules, got %d", c.Total)
	}
	if c.ShellGate != 4 {
		t.Fatalf("expected 4 shell-gated rules (R10-R13), got %d", c.ShellGate)
	}
	if c.SelfauditPin != 11 {
		t.Fatalf("expected 11 selfaudit-pinned rules, got %d", c.SelfauditPin)
	}
	if c.BehavioralTest != 16 {
		t.Fatalf("expected 16 behaviorally-tested rules, got %d", c.BehavioralTest)
	}
}

func TestCoverage_NoIneffectiveRule(t *testing.T) {
	rules, selfaudit, shellGate, tests := readReal(t)
	m := BuildMatrix(rules, selfaudit, shellGate, tests...)
	if orphans := RuleOrphans(m); len(orphans) != 0 {
		t.Fatalf("found rules with NO check on any surface (ineffective): %v", orphans)
	}
}

func TestCoverage_NoOrphanBaselineEntry(t *testing.T) {
	rules, selfaudit, _, _ := readReal(t)
	ids := ExtractRuleIDs(rules)
	if orphans := SelfauditOrphans(selfaudit, ids); len(orphans) != 0 {
		t.Fatalf("selfaudit baseline references rules that do not exist: %v", orphans)
	}
}

// Red-team: a fixture with rules that no surface checks must be flagged.
func TestCoverage_DetectsInjectedIneffectiveRule(t *testing.T) {
	fixtureRules := `var Rules = []GuardRule{
		{ID: "R98:ghost-rule"},
		{ID: "R99:phantom-rule"},
	}`
	m := BuildMatrix(fixtureRules, "", "" /* no tests */)
	orphans := RuleOrphans(m)
	want := []string{"R98", "R99"}
	if strings.Join(orphans, ",") != strings.Join(want, ",") {
		t.Fatalf("expected ineffective rules %v, got %v", want, orphans)
	}
}

// Red-team: a selfaudit baseline citing a non-existent rule must be flagged.
func TestCoverage_DetectsOrphanBaselineEntry(t *testing.T) {
	defined := []string{"R01", "R06"}
	fixtureSelfaudit := `baseline := []string{
		"R01:no-sudo:hash",
		"R06:no-force-push:hash",
		"R97:deleted-rule:hash",
	}`
	orphans := SelfauditOrphans(fixtureSelfaudit, defined)
	if len(orphans) != 1 || orphans[0] != "R97" {
		t.Fatalf("expected orphan baseline entry [R97], got %v", orphans)
	}
}

func TestCoverage_MatrixJSONDerivable(t *testing.T) {
	rules, selfaudit, shellGate, tests := readReal(t)
	m := BuildMatrix(rules, selfaudit, shellGate, tests...)
	b, err := MatrixJSON(m)
	if err != nil {
		t.Fatalf("MatrixJSON: %v", err)
	}
	if !strings.Contains(string(b), "R06") {
		t.Fatalf("derived matrix JSON missing R06:\n%s", b)
	}
}
