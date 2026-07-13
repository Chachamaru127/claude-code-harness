package policy

import (
	"fmt"
	"path/filepath"
	"strings"

	"github.com/Chachamaru127/claude-code-harness/go/pkg/hookproto"
)

// configuredProtectedPathResult denies a file write when the target matches a
// path declared in paths.protected of .claude-code-harness.config.json (R16).
//
// Declarations are project-relative prefixes. A declaration "dir/" or "dir"
// matches the directory and everything beneath it; a declaration naming a file
// matches that exact project-relative path. Writes resolved outside the project
// root never match (those are governed by R04), and the built-in security
// classifier (R02/R03) still runs independently.
func configuredProtectedPathResult(ctx hookproto.RuleContext, filePath string) *hookproto.HookResult {
	// Fail closed: a present-but-unparseable config (malformed JSON, unknown
	// keys, invalid glob) must not silently drop protections. Deny writes until
	// the operator fixes the file.
	if ctx.ConfigParseError != "" {
		return &hookproto.HookResult{
			Decision: hookproto.DecisionDeny,
			Reason: fmt.Sprintf(
				"file write blocked: .claude-code-harness.config.json could not be parsed, so protected paths cannot be enforced (failing closed). Fix the config: %s",
				ctx.ConfigParseError,
			),
		}
	}
	entry, ok := matchConfiguredProtectedPath(ctx, filePath)
	if !ok {
		return nil
	}
	return &hookproto.HookResult{
		Decision: hookproto.DecisionDeny,
		Reason: fmt.Sprintf(
			"file write to a protected path is not allowed: %s (matched paths.protected entry %q in .claude-code-harness.config.json)",
			filePath, entry,
		),
	}
}

// matchConfiguredProtectedPath reports whether filePath falls under any declared
// protected path, returning the matched declaration. A declaration matches when
// it is a path prefix of the target (directory or exact file) OR when it is a
// glob that matches the full project-relative path or its basename (so
// declarations like ".env.*" behave as documented).
//
// Targets are canonicalized against the directory that contains the config file
// (ProtectedPathRoot), not the possibly-nested cwd, so declarations keep
// pointing at the same files regardless of where the hook was invoked from.
func matchConfiguredProtectedPath(ctx hookproto.RuleContext, filePath string) (string, bool) {
	if len(ctx.ProtectedPathDenyList) == 0 {
		return "", false
	}
	root := ctx.ProtectedPathRoot
	if root == "" {
		root = ctx.ProjectRoot
	}
	target, ok := canonicalProtectedPathAskPath(filePath, root)
	if !ok {
		return "", false
	}
	for _, raw := range ctx.ProtectedPathDenyList {
		entry := normalizePathForGuardrail(strings.Trim(strings.TrimSpace(raw), `"'`))
		prefix := strings.TrimSuffix(entry, "/")
		if prefix == "" || prefix == "." {
			continue
		}
		// Directory / exact-path prefix match.
		if target == prefix || strings.HasPrefix(target, prefix+"/") {
			return raw, true
		}
		// Glob match against the full path or the basename. An invalid pattern
		// (ErrBadPattern) fails closed: treat it as a match so a malformed
		// declaration blocks rather than silently allows the write. (Load-time
		// validation normally rejects these first; this is defense in depth.)
		if ok, err := filepath.Match(entry, target); ok || err != nil {
			return raw, true
		}
		if ok, err := filepath.Match(entry, filepath.Base(target)); ok || err != nil {
			return raw, true
		}
	}
	return "", false
}
