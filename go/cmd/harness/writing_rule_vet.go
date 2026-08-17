package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"os"

	"github.com/Chachamaru127/claude-code-harness/go/internal/writinglint"
)

// runWritingRuleVet is the CLI entry point for `harness writing-rule-vet`.
func runWritingRuleVet(args []string) {
	os.Exit(runWritingRuleVetCommand(args, os.Stdin, os.Stdout, os.Stderr))
}

// runWritingRuleVetCommand reads one writing-rule.v1 JSON record from stdin
// and validates it as the promotion gate for the writing-rule proposal
// approval script under scripts/ (nothing in this repo invokes this command
// automatically; see that script's own header comment for the shape of the
// call):
//
//   - required fields (id, pattern) are present
//   - pattern compiles as a Go (RE2) regexp — the check the approve script's
//     Python-side schema validation cannot perform, since RE2 rejects syntax
//     (lookahead/lookbehind, backreferences, …) that other regex engines
//     accept. A pattern that slips past schema validation but fails to
//     compile as RE2 would otherwise silently disable writing-lint scanning
//     for every rule sharing the dictionary — see writinglint.ScanText,
//     which now skips (rather than aborts on) any such rule as a
//     defense-in-depth fallback, with this vet command as the primary,
//     fail-closed defense at promotion time.
//   - severity (if present) is one of the writing-rule.v1 schema enum values
//
// Prints exactly "ok" to stdout and exits 0 when the rule is valid. On any
// failure, prints nothing to stdout and a reason to stderr, and exits 1.
// The caller MUST treat "exit 0 AND stdout == ok" as the only success
// condition — the bin/harness shim exits 0 with EMPTY stdout when the
// platform binary is missing (hooks fail-open contract), so checking exit
// code alone would let an unvetted rule through fail-open instead of
// fail-closed.
func runWritingRuleVetCommand(args []string, stdin io.Reader, stdout, stderr io.Writer) int {
	if len(args) != 0 {
		fmt.Fprintln(stderr, "writing-rule-vet: unexpected arguments (reads one writing-rule.v1 JSON record from stdin)")
		return 1
	}

	data, err := io.ReadAll(io.LimitReader(stdin, 1<<20))
	if err != nil {
		fmt.Fprintf(stderr, "writing-rule-vet: read stdin: %v\n", err)
		return 1
	}

	var rule writinglint.Rule
	dec := json.NewDecoder(bytes.NewReader(data))
	dec.DisallowUnknownFields()
	if decErr := dec.Decode(&rule); decErr != nil {
		fmt.Fprintf(stderr, "writing-rule-vet: invalid JSON: %v\n", decErr)
		return 1
	}

	if rule.ID == "" {
		fmt.Fprintln(stderr, "writing-rule-vet: id is required")
		return 1
	}
	if rule.Pattern == "" {
		fmt.Fprintln(stderr, "writing-rule-vet: pattern is required")
		return 1
	}
	if _, compileErr := rule.Compile(); compileErr != nil {
		fmt.Fprintf(stderr, "writing-rule-vet: pattern %q failed to compile as RE2: %v\n", rule.Pattern, compileErr)
		return 1
	}
	switch rule.Severity {
	case "", "info", "warning", "error":
	default:
		fmt.Fprintf(stderr, "writing-rule-vet: severity %q is not one of info|warning|error\n", rule.Severity)
		return 1
	}

	fmt.Fprintln(stdout, "ok")
	return 0
}
