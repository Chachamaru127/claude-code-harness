package main

import (
	"bytes"
	"strings"
	"testing"
)

func TestRunWritingRuleVetCommand_ValidRuleOK(t *testing.T) {
	rule := `{"id":"no-meta-narration","pattern":"以下に示します","good":"結論から直接書く","enabled":true,"severity":"warning"}`
	var stdout, stderr bytes.Buffer
	code := runWritingRuleVetCommand(nil, strings.NewReader(rule), &stdout, &stderr)
	if code != 0 {
		t.Fatalf("exit code = %d, want 0; stderr=%q", code, stderr.String())
	}
	if strings.TrimSpace(stdout.String()) != "ok" {
		t.Fatalf("stdout = %q, want %q", stdout.String(), "ok")
	}
}

// TestRunWritingRuleVetCommand_LookaheadPatternRejected is the regression for
// the finding: writing-rule-approve.sh's schema-only validate() never
// compile-checked `pattern` as RE2, so a proposal whose pattern relies on
// unsupported syntax (Python's re accepts lookahead; Go's RE2 does not) could
// reach rules.jsonl and later silently disable the whole writing-lint
// dictionary at scan time (writinglint.ScanText). This is the primary,
// fail-closed defense: reject it here, before promotion.
func TestRunWritingRuleVetCommand_LookaheadPatternRejected(t *testing.T) {
	rule := `{"id":"bad-lookahead","pattern":"(?=foo)bar","good":"g","enabled":true}`
	var stdout, stderr bytes.Buffer
	code := runWritingRuleVetCommand(nil, strings.NewReader(rule), &stdout, &stderr)
	if code == 0 {
		t.Fatalf("exit code = 0, want non-zero for an RE2-uncompilable pattern; stdout=%q", stdout.String())
	}
	if stdout.Len() != 0 {
		t.Fatalf("stdout must be empty on rejection (caller checks stdout==\"ok\" for fail-closed), got %q", stdout.String())
	}
	if !strings.Contains(stderr.String(), "compile") {
		t.Fatalf("stderr should explain the RE2 compile failure, got %q", stderr.String())
	}
}

func TestRunWritingRuleVetCommand_MissingIDRejected(t *testing.T) {
	rule := `{"pattern":"foo","good":"g","enabled":true}`
	var stdout, stderr bytes.Buffer
	code := runWritingRuleVetCommand(nil, strings.NewReader(rule), &stdout, &stderr)
	if code == 0 {
		t.Fatalf("exit code = 0, want non-zero for missing id")
	}
	if stdout.Len() != 0 {
		t.Fatalf("stdout must be empty on rejection, got %q", stdout.String())
	}
}

func TestRunWritingRuleVetCommand_InvalidSeverityRejected(t *testing.T) {
	rule := `{"id":"x","pattern":"foo","good":"g","enabled":true,"severity":"critical"}`
	var stdout, stderr bytes.Buffer
	code := runWritingRuleVetCommand(nil, strings.NewReader(rule), &stdout, &stderr)
	if code == 0 {
		t.Fatalf("exit code = 0, want non-zero for an out-of-enum severity")
	}
}

func TestRunWritingRuleVetCommand_InvalidJSONRejected(t *testing.T) {
	var stdout, stderr bytes.Buffer
	code := runWritingRuleVetCommand(nil, strings.NewReader("not json"), &stdout, &stderr)
	if code == 0 {
		t.Fatalf("exit code = 0, want non-zero for invalid JSON")
	}
	if stdout.Len() != 0 {
		t.Fatalf("stdout must be empty on rejection, got %q", stdout.String())
	}
}

func TestRunWritingRuleVetCommand_UnexpectedArgsRejected(t *testing.T) {
	var stdout, stderr bytes.Buffer
	code := runWritingRuleVetCommand([]string{"--bogus"}, strings.NewReader("{}"), &stdout, &stderr)
	if code == 0 {
		t.Fatalf("exit code = 0, want non-zero for unexpected arguments")
	}
}
