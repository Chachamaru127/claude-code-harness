// Package releasetrain implements the read-only Release Train proposal logic
// for `harness release --check`.
package releasetrain

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"time"

	"github.com/Chachamaru127/claude-code-harness/go/internal/gitport"
)

const (
	StateCandidate     = "candidate"
	StateNone          = "none"
	StateNotApplicable = "not-applicable"
)

const (
	defaultThresholdDays  = 7
	securityThresholdDays = 2
)

// Result is the tri-state outcome of a release train check.
type Result struct {
	State         string
	Bump          string
	Reasons       []string
	TagName       string
	TagAgeDays    int
	ThresholdDays int
}

var (
	headingRe   = regexp.MustCompile(`(?m)^### (.+?)\s*$`)
	semverTagRe = regexp.MustCompile(`^v[0-9]`)
	pluginTagRe = regexp.MustCompile(`^claude-code-harness--v`)
)

// Evaluate applies the v1 Release Train trigger rules to changelog content and
// tag metadata. It performs no I/O.
func Evaluate(changelog string, lastTagDate time.Time, hasTag bool, now time.Time) Result {
	if !hasUnreleased(changelog) || !hasTag {
		return Result{State: StateNotApplicable}
	}

	headings := collectHeadings(changelog)
	if len(headings) == 0 {
		return Result{State: StateNone}
	}

	threshold := defaultThresholdDays
	if hasHeadingPrefix(headings, "Security") {
		threshold = securityThresholdDays
	}

	tagAge := tagAgeDays(lastTagDate, now)
	hasBreaking := hasBreakingHeading(headings)

	var reasons []string
	triggered := false
	if hasBreaking {
		triggered = true
		reasons = append(reasons, "breaking")
	}
	if tagAge >= threshold {
		triggered = true
		reasons = append(reasons, "tag_age")
	}

	if !triggered {
		return Result{
			State:         StateNone,
			TagAgeDays:    tagAge,
			ThresholdDays: threshold,
		}
	}

	return Result{
		State:         StateCandidate,
		Bump:          estimateBump(headings),
		Reasons:       reasons,
		TagAgeDays:    tagAge,
		ThresholdDays: threshold,
	}
}

// Check reads CHANGELOG.md and the newest semver tag under root, then evaluates
// the Release Train proposal. It never writes files.
func Check(root string, now time.Time) (Result, error) {
	changelogPath := filepath.Join(root, "CHANGELOG.md")
	data, err := os.ReadFile(changelogPath)
	if err != nil {
		if os.IsNotExist(err) {
			return Result{State: StateNotApplicable}, nil
		}
		return Result{}, err
	}

	tagName, tagDate, hasTag, err := resolveLatestSemverTag(root)
	if err != nil {
		return Result{}, err
	}
	if !hasTag {
		return Result{State: StateNotApplicable}, nil
	}

	result := Evaluate(string(data), tagDate, true, now)
	result.TagName = tagName
	return result, nil
}

// FormatLine returns the stable RELEASE_CANDIDATE stdout line for candidate
// state, or an empty string for none / not-applicable.
func (r Result) FormatLine() string {
	if r.State != StateCandidate {
		return ""
	}
	return fmt.Sprintf(
		"RELEASE_CANDIDATE: bump=%s tag=%s age_days=%d threshold_days=%d reasons=%s",
		r.Bump,
		r.TagName,
		r.TagAgeDays,
		r.ThresholdDays,
		strings.Join(r.Reasons, ","),
	)
}

func hasUnreleased(changelog string) bool {
	_, ok := extractUnreleasedBody(changelog)
	return ok
}

func extractUnreleasedBody(changelog string) (string, bool) {
	const marker = "## [Unreleased]"
	idx := strings.Index(changelog, marker)
	if idx < 0 {
		return "", false
	}
	rest := changelog[idx+len(marker):]
	rest = strings.TrimLeft(rest, " \t\r")
	if strings.HasPrefix(rest, "\n") {
		rest = rest[1:]
	}
	if next := strings.Index(rest, "\n## ["); next >= 0 {
		rest = rest[:next]
	}
	return rest, true
}

func collectHeadings(changelog string) []string {
	body, ok := extractUnreleasedBody(changelog)
	if !ok {
		return nil
	}
	matches := headingRe.FindAllStringSubmatch(body, -1)
	if len(matches) == 0 {
		return nil
	}
	headings := make([]string, 0, len(matches))
	for _, match := range matches {
		headings = append(headings, strings.TrimSpace(match[1]))
	}
	return headings
}

func hasHeadingPrefix(headings []string, prefix string) bool {
	for _, h := range headings {
		if h == prefix || strings.HasPrefix(h, prefix) {
			return true
		}
	}
	return false
}

// hasBreakingHeading reports whether any subsection heading uses the Breaking
// prefix. skills/harness-release/references/bump-detection.md documents the
// long form "### Breaking Changes"; this matcher absorbs both spellings.
func hasBreakingHeading(headings []string) bool {
	return hasHeadingPrefix(headings, "Breaking")
}

func tagAgeDays(lastTagDate, now time.Time) int {
	if lastTagDate.IsZero() {
		return 0
	}
	age := now.Sub(lastTagDate)
	if age < 0 {
		return 0
	}
	return int(age / (24 * time.Hour))
}

func estimateBump(headings []string) string {
	// Breaking*/Removed → major; Added/Deprecated → minor; Fixed/Changed/Security → patch.
	if hasBreakingHeading(headings) || hasHeadingPrefix(headings, "Removed") {
		return "major"
	}
	if hasHeadingPrefix(headings, "Added") || hasHeadingPrefix(headings, "Deprecated") {
		return "minor"
	}
	return "patch"
}

func resolveLatestSemverTag(root string) (name string, date time.Time, ok bool, err error) {
	out, err := gitport.Output(root, "tag", "-l", "v*", "--sort=-v:refname")
	if err != nil {
		return "", time.Time{}, false, err
	}

	for _, line := range strings.Split(out, "\n") {
		tag := strings.TrimSpace(line)
		if tag == "" {
			continue
		}
		if pluginTagRe.MatchString(tag) {
			continue
		}
		if !semverTagRe.MatchString(tag) {
			continue
		}

		dateOut, dateErr := gitport.Output(root, "log", "-1", "--format=%cI", tag)
		if dateErr != nil {
			return "", time.Time{}, false, dateErr
		}
		parsed, parseErr := time.Parse(time.RFC3339, strings.TrimSpace(dateOut))
		if parseErr != nil {
			return "", time.Time{}, false, parseErr
		}
		return tag, parsed, true, nil
	}

	return "", time.Time{}, false, nil
}
