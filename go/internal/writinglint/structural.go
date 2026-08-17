package writinglint

import (
	"regexp"
	"strings"
)

// sentenceSplitRE splits Japanese prose into sentences on 。！？.
var sentenceSplitRE = regexp.MustCompile(`[。！？]`)

// politeEndingRE matches 敬体 (polite, です・ます体) sentence-final forms.
var politeEndingRE = regexp.MustCompile(`(でした|ました|ません|ましょう|です|ます)$`)

// plainEndingRE matches 常体 (plain, だ・である体) sentence-final forms.
var plainEndingRE = regexp.MustCompile(`(であった|だった|である|だ)$`)

// RepeatedEnding is one run of 3+ consecutive sentences that share an
// identical closing pattern (文末3連続, e.g. "〜だ。〜だ。〜だ。").
type RepeatedEnding struct {
	Ending string
	Count  int
	Start  int // 0-based index of the run's first sentence
}

// DetectRepeatedSentenceEndings splits text into sentences and reports every
// run of 3 or more consecutive sentences ending in the identical closing
// pattern. It is a pure function: no I/O, no package-level state mutation.
func DetectRepeatedSentenceEndings(text string) []RepeatedEnding {
	sentences := splitSentences(text)

	var out []RepeatedEnding
	runEnding := ""
	runCount := 0
	runStart := 0

	flush := func() {
		if runCount >= 3 && runEnding != "" {
			out = append(out, RepeatedEnding{Ending: runEnding, Count: runCount, Start: runStart})
		}
	}

	for i, s := range sentences {
		ending := sentenceEnding(s)
		switch {
		case ending == "" || ending != runEnding:
			flush()
			runEnding = ending
			runCount = 1
			runStart = i
		default:
			runCount++
		}
	}
	flush()
	return out
}

// sentenceEnding extracts a comparable closing token for s: the matched
// polite/plain ending if one is found, else the trailing (up to 3) runes.
func sentenceEnding(s string) string {
	s = strings.TrimSpace(s)
	if s == "" {
		return ""
	}
	if m := politeEndingRE.FindString(s); m != "" {
		return m
	}
	if m := plainEndingRE.FindString(s); m != "" {
		return m
	}
	runes := []rune(s)
	n := 3
	if len(runes) < n {
		n = len(runes)
	}
	return string(runes[len(runes)-n:])
}

// splitSentences splits text on 。！？ and drops empty/whitespace-only
// fragments (e.g. the trailing fragment after a final 。).
func splitSentences(text string) []string {
	var out []string
	for _, s := range sentenceSplitRE.Split(text, -1) {
		s = strings.TrimSpace(s)
		if s != "" {
			out = append(out, s)
		}
	}
	return out
}

// StyleMixing counts 敬体 (polite) vs 常体 (plain) sentence endings found in a text.
type StyleMixing struct {
	PoliteCount int
	PlainCount  int
}

// Mixed reports whether both polite and plain sentence endings occur, i.e.
// 敬体常体混在 (inconsistent register within one piece of writing).
func (m StyleMixing) Mixed() bool {
	return m.PoliteCount > 0 && m.PlainCount > 0
}

// DetectStyleMixing splits text into sentences and classifies each by
// closing register (敬体 vs 常体), ignoring sentences that match neither.
func DetectStyleMixing(text string) StyleMixing {
	var m StyleMixing
	for _, s := range splitSentences(text) {
		switch {
		case politeEndingRE.MatchString(s):
			m.PoliteCount++
		case plainEndingRE.MatchString(s):
			m.PlainCount++
		}
	}
	return m
}
