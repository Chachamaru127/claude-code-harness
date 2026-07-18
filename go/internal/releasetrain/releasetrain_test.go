package releasetrain_test

import (
	"testing"
	"time"

	"github.com/Chachamaru127/claude-code-harness/go/internal/releasetrain"
)

const sampleHeader = `# Changelog

## [Unreleased]
`

func daysAgo(now time.Time, days int) time.Time {
	return now.Add(-time.Duration(days) * 24 * time.Hour)
}

func TestEvaluate_Candidate(t *testing.T) {
	now := time.Date(2026, 7, 16, 12, 0, 0, 0, time.UTC)
	changelog := sampleHeader + `
### Added
- New release train proposer
`
	got := releasetrain.Evaluate(changelog, daysAgo(now, 8), true, now)
	if got.State != releasetrain.StateCandidate {
		t.Fatalf("State = %q, want %q", got.State, releasetrain.StateCandidate)
	}
	if got.Bump != "minor" {
		t.Fatalf("Bump = %q, want minor", got.Bump)
	}
	if got.TagAgeDays < 7 {
		t.Fatalf("TagAgeDays = %d, want >= 7", got.TagAgeDays)
	}
	if got.ThresholdDays != 7 {
		t.Fatalf("ThresholdDays = %d, want 7", got.ThresholdDays)
	}
}

func TestEvaluate_None(t *testing.T) {
	now := time.Date(2026, 7, 16, 12, 0, 0, 0, time.UTC)
	changelog := sampleHeader + `
### Fixed
- Minor tweak
`
	got := releasetrain.Evaluate(changelog, daysAgo(now, 1), true, now)
	if got.State != releasetrain.StateNone {
		t.Fatalf("State = %q, want %q", got.State, releasetrain.StateNone)
	}
}

func TestEvaluate_NotApplicable(t *testing.T) {
	now := time.Date(2026, 7, 16, 12, 0, 0, 0, time.UTC)
	tagDate := daysAgo(now, 8)

	t.Run("no Unreleased heading", func(t *testing.T) {
		changelog := `# Changelog

## [1.0.0] - 2026-01-01
### Added
- Initial release
`
		got := releasetrain.Evaluate(changelog, tagDate, true, now)
		if got.State != releasetrain.StateNotApplicable {
			t.Fatalf("State = %q, want %q", got.State, releasetrain.StateNotApplicable)
		}
	})

	t.Run("no semver tag", func(t *testing.T) {
		changelog := sampleHeader + `
### Added
- Something
`
		got := releasetrain.Evaluate(changelog, time.Time{}, false, now)
		if got.State != releasetrain.StateNotApplicable {
			t.Fatalf("State = %q, want %q", got.State, releasetrain.StateNotApplicable)
		}
	})
}

func TestEvaluate_SecurityShortensThreshold(t *testing.T) {
	now := time.Date(2026, 7, 16, 12, 0, 0, 0, time.UTC)

	t.Run("3 days old with Security is candidate at threshold 2", func(t *testing.T) {
		changelog := sampleHeader + `
### Security
- CVE fix

### Fixed
- Bug
`
		got := releasetrain.Evaluate(changelog, daysAgo(now, 3), true, now)
		if got.State != releasetrain.StateCandidate {
			t.Fatalf("State = %q, want %q", got.State, releasetrain.StateCandidate)
		}
		if got.Bump != "patch" {
			t.Fatalf("Bump = %q, want patch", got.Bump)
		}
		if got.ThresholdDays != 2 {
			t.Fatalf("ThresholdDays = %d, want 2", got.ThresholdDays)
		}
	})

	t.Run("1 day old with Security is none at threshold 2", func(t *testing.T) {
		changelog := sampleHeader + `
### Security
- CVE fix
`
		got := releasetrain.Evaluate(changelog, daysAgo(now, 1), true, now)
		if got.State != releasetrain.StateNone {
			t.Fatalf("State = %q, want %q", got.State, releasetrain.StateNone)
		}
	})
}

func TestEvaluate_BreakingTriggersImmediately(t *testing.T) {
	now := time.Date(2026, 7, 16, 12, 0, 0, 0, time.UTC)
	tagDate := now // 0 days old

	t.Run("Breaking short form", func(t *testing.T) {
		changelog := sampleHeader + `
### Breaking
- Removed old API
`
		got := releasetrain.Evaluate(changelog, tagDate, true, now)
		if got.State != releasetrain.StateCandidate {
			t.Fatalf("State = %q, want %q", got.State, releasetrain.StateCandidate)
		}
		if got.Bump != "major" {
			t.Fatalf("Bump = %q, want major", got.Bump)
		}
	})

	t.Run("Breaking Changes long form", func(t *testing.T) {
		changelog := sampleHeader + `
### Breaking Changes
- Removed old API
`
		got := releasetrain.Evaluate(changelog, tagDate, true, now)
		if got.State != releasetrain.StateCandidate {
			t.Fatalf("State = %q, want %q", got.State, releasetrain.StateCandidate)
		}
		if got.Bump != "major" {
			t.Fatalf("Bump = %q, want major", got.Bump)
		}
	})
}

func TestEvaluate_EmptyUnreleasedIsNone(t *testing.T) {
	now := time.Date(2026, 7, 16, 12, 0, 0, 0, time.UTC)
	changelog := sampleHeader + `
No subsection headings here, only prose.
`
	got := releasetrain.Evaluate(changelog, daysAgo(now, 30), true, now)
	if got.State != releasetrain.StateNone {
		t.Fatalf("State = %q, want %q", got.State, releasetrain.StateNone)
	}
}

func TestEvaluate_BumpLadder(t *testing.T) {
	now := time.Date(2026, 7, 16, 12, 0, 0, 0, time.UTC)
	tagDate := daysAgo(now, 10)

	tests := []struct {
		name     string
		body     string
		wantBump string
	}{
		{
			name: "Removed is major",
			body: `
### Removed
- Old feature
`,
			wantBump: "major",
		},
		{
			name: "Deprecated is minor",
			body: `
### Deprecated
- Legacy hook
`,
			wantBump: "minor",
		},
		{
			name: "Fixed and Changed is patch",
			body: `
### Fixed
- Bug

### Changed
- Docs
`,
			wantBump: "patch",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			got := releasetrain.Evaluate(sampleHeader+tc.body, tagDate, true, now)
			if got.State != releasetrain.StateCandidate {
				t.Fatalf("State = %q, want %q", got.State, releasetrain.StateCandidate)
			}
			if got.Bump != tc.wantBump {
				t.Fatalf("Bump = %q, want %q", got.Bump, tc.wantBump)
			}
		})
	}
}
