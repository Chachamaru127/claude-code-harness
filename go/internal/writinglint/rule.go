// Package writinglint implements a dictionary-driven Japanese writing-style
// linter: a JSONL dictionary of regexp rules (writing-rule.v1), scene-scoped
// scanning of arbitrary text, and pure structural checks (repeated sentence
// endings, polite/plain style mixing). It has no I/O side effects beyond
// reading the dictionary file — callers (e.g. the PostToolUse hook handler)
// own dispatch, config gating, and output formatting.
package writinglint

import "regexp"

// Rule is one writing-rule.v1 dictionary entry.
type Rule struct {
	ID       string   `json:"id"`
	Pattern  string   `json:"pattern"`
	Good     string   `json:"good"`
	Scenes   []string `json:"scenes,omitempty"`
	Enabled  bool     `json:"enabled"`
	Severity string   `json:"severity,omitempty"`
}

// CompiledRule pairs a Rule with its compiled RE2 regexp.
type CompiledRule struct {
	Rule
	Regexp *regexp.Regexp
}

// Compile compiles r.Pattern as a Go (RE2) regexp. Patterns that rely on
// unsupported syntax (lookahead/lookbehind, backreferences, …) return an
// error here rather than at scan time.
func (r Rule) Compile() (*CompiledRule, error) {
	re, err := regexp.Compile(r.Pattern)
	if err != nil {
		return nil, err
	}
	return &CompiledRule{Rule: r, Regexp: re}, nil
}

// AppliesToScene reports whether the rule is in scope for scene. A rule with
// no Scenes applies to every scene; an empty scene argument also matches
// every rule (no narrowing requested).
func (r Rule) AppliesToScene(scene string) bool {
	if scene == "" || len(r.Scenes) == 0 {
		return true
	}
	for _, s := range r.Scenes {
		if s == scene {
			return true
		}
	}
	return false
}
