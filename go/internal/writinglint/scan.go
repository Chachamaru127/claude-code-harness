package writinglint

// Match is one writing-lint hit against a scanned text.
type Match struct {
	RuleID   string
	Text     string // matched substring
	Good     string // suggested rewrite pattern
	Severity string
	Start    int
	End      int
}

// ScanOpts configures ScanText.
type ScanOpts struct {
	// Scene narrows which rules run via Rule.AppliesToScene. Empty means no
	// narrowing (every enabled rule runs).
	Scene string
}

// ScanText narrows rules to Enabled + AppliesToScene(opts.Scene), then runs
// each rule's compiled regexp against text and returns every match.
//
// A rule whose Pattern fails to compile as RE2 (lookahead/lookbehind,
// backreferences, …) is skipped rather than aborting the whole scan: one
// broken rule must never silently take every other rule down with it. Its ID
// is appended to invalidRuleIDs so callers can surface the skip instead of
// swallowing it (this is the engine-level fallback; the primary defense is
// the `harness writing-rule-vet` compile check run at proposal-approval
// time, before a rule ever reaches the dictionary).
func ScanText(text string, rules []Rule, opts ScanOpts) (matches []Match, invalidRuleIDs []string, err error) {
	for _, rule := range rules {
		if !rule.Enabled || !rule.AppliesToScene(opts.Scene) {
			continue
		}
		compiled, compileErr := rule.Compile()
		if compileErr != nil {
			invalidRuleIDs = append(invalidRuleIDs, rule.ID)
			continue
		}
		for _, loc := range compiled.Regexp.FindAllStringIndex(text, -1) {
			matches = append(matches, Match{
				RuleID:   rule.ID,
				Text:     text[loc[0]:loc[1]],
				Good:     rule.Good,
				Severity: rule.Severity,
				Start:    loc[0],
				End:      loc[1],
			})
		}
	}
	return matches, invalidRuleIDs, nil
}
