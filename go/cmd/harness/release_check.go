package main

import (
	"fmt"
	"io"
	"os"
	"time"

	"github.com/Chachamaru127/claude-code-harness/go/internal/releasetrain"
)

// runReleaseCheck implements `harness release --check [root]`.
// It is read-only: no files are written and the process always exits 0 on the
// happy path (including none / not-applicable).
func runReleaseCheck(args []string) {
	var rootOverride string
	for _, arg := range args {
		switch arg {
		case "--check":
			// already dispatched by runRelease
		default:
			rootOverride = arg
		}
	}

	projectRoot, err := resolveProjectRoot([]string{rootOverride})
	if err != nil {
		fmt.Fprintf(os.Stderr, "harness release --check: %v\n", err)
		os.Exit(1)
	}

	if err := releaseCheck(projectRoot, time.Now(), os.Stdout); err != nil {
		fmt.Fprintf(os.Stderr, "harness release --check: %v\n", err)
		os.Exit(1)
	}
	os.Exit(0)
}

// releaseCheck evaluates the Release Train proposal for root and writes at most
// one RELEASE_CANDIDATE line to out. It never modifies files under root.
func releaseCheck(root string, now time.Time, out io.Writer) error {
	result, err := releasetrain.Check(root, now)
	if err != nil {
		return err
	}
	if line := result.FormatLine(); line != "" {
		fmt.Fprintln(out, line)
	}
	return nil
}
