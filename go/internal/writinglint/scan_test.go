package writinglint

import "testing"

func loadFixtureRules(t *testing.T) []Rule {
	t.Helper()
	rules, err := LoadDict("testdata/rules.jsonl")
	if err != nil {
		t.Fatalf("LoadDict: %v", err)
	}
	return rules
}

func TestScanText_HitsEnabledPatternRegardlessOfScene(t *testing.T) {
	rules := loadFixtureRules(t)
	matches, _, err := ScanText("結論から書かず、以下に示します。", rules, ScanOpts{})
	if err != nil {
		t.Fatalf("ScanText: %v", err)
	}
	if len(matches) != 1 {
		t.Fatalf("len(matches) = %d, want 1: %+v", len(matches), matches)
	}
	if matches[0].RuleID != "meta-narration" || matches[0].Good == "" {
		t.Fatalf("matches[0] = %+v, want rule meta-narration with a Good suggestion", matches[0])
	}
}

func TestScanText_NegativeNoHitOnCleanText(t *testing.T) {
	rules := loadFixtureRules(t)
	matches, _, err := ScanText("結論。やったこと。なぜ。", rules, ScanOpts{})
	if err != nil {
		t.Fatalf("ScanText: %v", err)
	}
	if len(matches) != 0 {
		t.Fatalf("len(matches) = %d, want 0: %+v", len(matches), matches)
	}
}

func TestScanText_DisabledRuleNeverMatches(t *testing.T) {
	rules := loadFixtureRules(t)
	matches, _, err := ScanText("この行はヒットしない、はずが有効なら失敗する。", rules, ScanOpts{})
	if err != nil {
		t.Fatalf("ScanText: %v", err)
	}
	if len(matches) != 0 {
		t.Fatalf("disabled rule matched: %+v", matches)
	}
}

func TestScanText_SceneNarrowing(t *testing.T) {
	rules := loadFixtureRules(t)
	text := "重要なのはこの一点である。"

	// scene=external: rule is scoped to external+chat, must hit.
	hits, _, err := ScanText(text, rules, ScanOpts{Scene: "external"})
	if err != nil {
		t.Fatalf("ScanText: %v", err)
	}
	if len(hits) != 1 {
		t.Fatalf("scene=external: len(matches) = %d, want 1", len(hits))
	}

	// scene=report: rule is not scoped to report, must not hit.
	miss, _, err := ScanText(text, rules, ScanOpts{Scene: "report"})
	if err != nil {
		t.Fatalf("ScanText: %v", err)
	}
	if len(miss) != 0 {
		t.Fatalf("scene=report: len(matches) = %d, want 0: %+v", len(miss), miss)
	}
}

func TestScanText_NoSceneRuleAppliesToEveryScene(t *testing.T) {
	rules := loadFixtureRules(t)
	for _, scene := range []string{"", "external", "chat", "report"} {
		matches, _, err := ScanText("とても良い結果だった。", rules, ScanOpts{Scene: scene})
		if err != nil {
			t.Fatalf("ScanText(scene=%q): %v", scene, err)
		}
		found := false
		for _, m := range matches {
			if m.RuleID == "no-scene-rule" {
				found = true
			}
		}
		if !found {
			t.Fatalf("scene=%q: no-scene-rule did not match, matches=%+v", scene, matches)
		}
	}
}

// TestScanText_InvalidRE2PatternSkippedNotAborted is the regression for the
// silent-disable finding: an unvettable pattern (schema validation alone
// cannot catch this — see writing-rule-approve.sh's `harness writing-rule-vet`
// gate, which exists precisely to keep this rule out of the dictionary in the
// first place) must not make ScanText return an error; it must be reported
// via invalidRuleIDs and otherwise ignored.
func TestScanText_InvalidRE2PatternSkippedNotAborted(t *testing.T) {
	bad := []Rule{{ID: "bad", Pattern: "(?<=foo)bar", Enabled: true}} // lookbehind: unsupported in RE2
	matches, invalidRuleIDs, err := ScanText("foobar", bad, ScanOpts{})
	if err != nil {
		t.Fatalf("ScanText must not error on an uncompilable rule, got: %v", err)
	}
	if len(matches) != 0 {
		t.Fatalf("uncompilable rule must not match, got: %+v", matches)
	}
	if len(invalidRuleIDs) != 1 || invalidRuleIDs[0] != "bad" {
		t.Fatalf("invalidRuleIDs = %v, want [\"bad\"]", invalidRuleIDs)
	}
}

// TestScanText_InvalidRuleDoesNotBlockOtherRules is the core engine-resilience
// regression: before this fix, one rule with an uncompilable pattern made
// ScanText return an error for the whole call, and both hookhandler callers
// silently continued without any rules applied at all (silent disable). A
// broken rule must now leave every other enabled rule fully functional.
func TestScanText_InvalidRuleDoesNotBlockOtherRules(t *testing.T) {
	rules := []Rule{
		{ID: "bad", Pattern: "(?<=foo)bar", Enabled: true}, // lookbehind: unsupported in RE2
		{ID: "meta-narration", Pattern: "以下に示します", Good: "結論から直接書く", Enabled: true},
	}
	matches, invalidRuleIDs, err := ScanText("以下に示します。ここから本題です。", rules, ScanOpts{})
	if err != nil {
		t.Fatalf("ScanText: %v", err)
	}
	if len(invalidRuleIDs) != 1 || invalidRuleIDs[0] != "bad" {
		t.Fatalf("invalidRuleIDs = %v, want [\"bad\"]", invalidRuleIDs)
	}
	if len(matches) != 1 || matches[0].RuleID != "meta-narration" {
		t.Fatalf("expected the valid rule to still hit despite the broken one, got: %+v", matches)
	}
}
