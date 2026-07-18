package policy

import (
	"fmt"
	"regexp"
	"strings"
)

// ---------------------------------------------------------------------------
// Test tampering patterns (ported from tampering.ts)
// ---------------------------------------------------------------------------

type tamperingPattern struct {
	ID           string
	Description  string
	Pattern      *regexp.Regexp
	TestFileOnly bool
}

var tamperingPatterns = []tamperingPattern{
	{ID: "T01:it-skip", Description: "Test skipped via it.skip / describe.skip",
		Pattern: regexp.MustCompile(`(?:it|test|describe|context)\.skip\s*\(`), TestFileOnly: true},
	{ID: "T02:xit-xdescribe", Description: "Test disabled via xit / xdescribe",
		Pattern: regexp.MustCompile(`\b(?:xit|xtest|xdescribe)\s*\(`), TestFileOnly: true},
	{ID: "T03:pytest-skip", Description: "Test skipped via pytest.mark.skip",
		Pattern: regexp.MustCompile(`@pytest\.mark\.(?:skip|xfail)\b`), TestFileOnly: true},
	{ID: "T04:go-skip", Description: "Test skipped via t.Skip()",
		Pattern: regexp.MustCompile(`\bt\.Skip(?:f|Now)?\s*\(`), TestFileOnly: true},
	{ID: "T05:expect-removed", Description: "expect / assert possibly removed (commented out)",
		Pattern: regexp.MustCompile(`//\s*expect\s*\(`), TestFileOnly: true},
	{ID: "T06:assert-commented", Description: "assert call commented out",
		Pattern: regexp.MustCompile(`//\s*assert(?:Equal|NotEqual|True|False|Nil|Error)?\s*\(`), TestFileOnly: true},
	{ID: "T07:todo-assert", Description: "Assertion replaced by a TODO comment",
		Pattern: regexp.MustCompile(`(?i)//\s*TODO.*assert|//\s*TODO.*expect`), TestFileOnly: true},
	{ID: "T08:eslint-disable", Description: "Lint rule disabled via eslint-disable",
		Pattern: regexp.MustCompile(`(?m)(?://\s*eslint-disable(?:-next-line|-line)?(?:\s+[^\n]+)?$|/\*\s*eslint-disable\b[^*]*\*/)`), TestFileOnly: false},
	{ID: "T09:ci-continue-on-error", Description: "CI failure ignored via continue-on-error: true",
		Pattern: regexp.MustCompile(`continue-on-error\s*:\s*true`), TestFileOnly: false},
	{ID: "T10:ci-if-always", Description: "CI step forced to run via if: always()",
		Pattern: regexp.MustCompile(`if\s*:\s*always\s*\(\s*\)`), TestFileOnly: false},
	{ID: "T11:hardcoded-answer", Description: "Hardcoded test expectation (dictionary lookup)",
		Pattern: regexp.MustCompile(`answers?_for_tests?\s*=\s*\{`), TestFileOnly: true},
	{ID: "T12:return-hardcoded", Description: "Pattern returning test-case values directly",
		Pattern: regexp.MustCompile(`(?i)return\s+(?:"[^"]*"|'[^']*'|\d+)\s*;\s*//.*(?:test|spec|expect)`), TestFileOnly: true},
}

var testFilePatterns = []*regexp.Regexp{
	regexp.MustCompile(`\.test\.[jt]sx?$`),
	regexp.MustCompile(`\.spec\.[jt]sx?$`),
	regexp.MustCompile(`\.test\.py$`),
	regexp.MustCompile(`test_[^/]+\.py$`),
	regexp.MustCompile(`[^/]+_test\.py$`),
	regexp.MustCompile(`\.test\.go$`),
	regexp.MustCompile(`[^/]+_test\.go$`),
	regexp.MustCompile(`/__tests__/`),
	regexp.MustCompile(`/tests/`),
}

var configFilePatterns = []*regexp.Regexp{
	regexp.MustCompile(`(?:^|/)\.eslintrc(?:\.[^/]+)?$`),
	regexp.MustCompile(`(?:^|/)eslint\.config\.[^/]+$`),
	regexp.MustCompile(`(?:^|/)\.prettierrc(?:\.[^/]+)?$`),
	regexp.MustCompile(`(?:^|/)prettier\.config\.[^/]+$`),
	regexp.MustCompile(`(?:^|/)tsconfig(?:\.[^/]+)?\.json$`),
	regexp.MustCompile(`(?:^|/)biome\.json$`),
	regexp.MustCompile(`(?:^|/)\.stylelintrc(?:\.[^/]+)?$`),
	regexp.MustCompile(`(?:^|/)(?:jest|vitest)\.config\.[^/]+$`),
	regexp.MustCompile(`\.github/workflows/[^/]+\.ya?ml$`),
	regexp.MustCompile(`(?:^|/)\.gitlab-ci\.ya?ml$`),
	regexp.MustCompile(`(?:^|/)Jenkinsfile$`),
}

func isTestFile(filePath string) bool {
	for _, p := range testFilePatterns {
		if p.MatchString(filePath) {
			return true
		}
	}
	return false
}

func isConfigFile(filePath string) bool {
	for _, p := range configFilePatterns {
		if p.MatchString(filePath) {
			return true
		}
	}
	return false
}

type tamperingWarning struct {
	PatternID   string
	Description string
	MatchedText string
}

func detectTampering(text string, isTest bool) []tamperingWarning {
	var warnings []tamperingWarning
	for _, tp := range tamperingPatterns {
		if tp.TestFileOnly && !isTest {
			continue
		}
		loc := tp.Pattern.FindStringIndex(text)
		if loc != nil {
			matched := text[loc[0]:loc[1]]
			if len(matched) > 120 {
				matched = matched[:120]
			}
			warnings = append(warnings, tamperingWarning{
				PatternID:   tp.ID,
				Description: tp.Description,
				MatchedText: matched,
			})
		}
	}
	return warnings
}

// ---------------------------------------------------------------------------
// Coverage-shrink guard (PostToolUse, warn-only — never deny)
//
// Scoped to tests/validate-plugin.sh and tests/test-*.sh only.
// Hook parity: fires on Claude via .claude-plugin/hooks.json PostToolUse →
// harness hook post-tool; Codex/Cursor use PreToolUse-only gen (hostgen) and
// have no PostToolUse concept, so no hostgen/hooks.json changes are needed.
//
// Write limitation: old file content is unavailable in the PostToolUse payload
// (file already overwritten), so invocation-removal and assertion-count checks
// are skipped for Write; only || true / set +e presence checks apply.
// ---------------------------------------------------------------------------

var coverageShrinkTargetPattern = regexp.MustCompile(`(?:^|/)tests/(validate-plugin\.sh|test-[^/]+\.sh)$`)

var testInvocationLinePattern = regexp.MustCompile(`(?m)^[^\n#]*\bbash\b[^\n]*(?:tests/)?test-[^\s/]+\.sh`)
var orTruePattern = regexp.MustCompile(`\|\|\s*true\b`)
var setPlusEPattern = regexp.MustCompile(`set\s+\+e\b`)
var assertionLinePattern = regexp.MustCompile(`(?m)^[^\n#]*(?:\bassert(?:_\w+|\()|\bfail_test\b|\bpass_test\b|\bjq\s+-e\b|\bgrep\s+-Fq\b|\bgrep\s+-q\b)`)

type coverageShrinkWarning struct {
	PatternID   string
	Description string
	Detail      string
}

func isCoverageShrinkTarget(filePath string) bool {
	return coverageShrinkTargetPattern.MatchString(filePath)
}

func countAssertionLines(text string) int {
	return len(assertionLinePattern.FindAllString(text, -1))
}

func detectCoverageShrink(pairs []contentPair, isWrite bool) []coverageShrinkWarning {
	if len(pairs) == 0 {
		return nil
	}

	var warnings []coverageShrinkWarning
	seen := make(map[string]bool)

	addWarning := func(w coverageShrinkWarning) {
		key := w.PatternID + "\x00" + w.Detail
		if seen[key] {
			return
		}
		seen[key] = true
		warnings = append(warnings, w)
	}

	if isWrite {
		// Write: old content unavailable — patterns 2 & 3 only (presence in new).
		newContent := pairs[0].new
		if orTruePattern.MatchString(newContent) {
			addWarning(coverageShrinkWarning{
				PatternID:   "T14:or-true",
				Description: "|| true addition — failure may be silently ignored",
				Detail:      strings.TrimSpace(orTruePattern.FindString(newContent)),
			})
		}
		if setPlusEPattern.MatchString(newContent) {
			addWarning(coverageShrinkWarning{
				PatternID:   "T15:set-plus-e",
				Description: "set +e addition — errexit disabled",
				Detail:      strings.TrimSpace(setPlusEPattern.FindString(newContent)),
			})
		}
		return warnings
	}

	for _, pair := range pairs {
		for _, inv := range testInvocationLinePattern.FindAllString(pair.old, -1) {
			trimmed := strings.TrimSpace(inv)
			if !strings.Contains(pair.new, trimmed) {
				addWarning(coverageShrinkWarning{
					PatternID:   "T13:invocation-removed",
					Description: "test invocation removal — bash test-*.sh line disappeared",
					Detail:      trimmed,
				})
			}
		}

		if !orTruePattern.MatchString(pair.old) && orTruePattern.MatchString(pair.new) {
			addWarning(coverageShrinkWarning{
				PatternID:   "T14:or-true",
				Description: "|| true addition — failure may be silently ignored",
				Detail:      strings.TrimSpace(orTruePattern.FindString(pair.new)),
			})
		}

		if !setPlusEPattern.MatchString(pair.old) && setPlusEPattern.MatchString(pair.new) {
			addWarning(coverageShrinkWarning{
				PatternID:   "T15:set-plus-e",
				Description: "set +e addition — errexit disabled",
				Detail:      strings.TrimSpace(setPlusEPattern.FindString(pair.new)),
			})
		}

		oldCount := countAssertionLines(pair.old)
		newCount := countAssertionLines(pair.new)
		if newCount < oldCount {
			addWarning(coverageShrinkWarning{
				PatternID:   "T16:assertion-reduced",
				Description: "assertion count reduction — fewer assert/fail_test/pass_test/jq -e/grep -q lines",
				Detail:      fmt.Sprintf("%d → %d", oldCount, newCount),
			})
		}
	}

	return warnings
}
