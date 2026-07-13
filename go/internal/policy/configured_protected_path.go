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
func matchConfiguredProtectedPath(ctx hookproto.RuleContext, filePath string) (string, bool) {
	if len(ctx.ProtectedPathDenyList) == 0 {
		return "", false
	}
	target, ok := canonicalProtectedPathAskPath(filePath, ctx.ProjectRoot)
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
		// Glob match against the full path or the basename.
		if ok, _ := filepath.Match(entry, target); ok {
			return raw, true
		}
		if ok, _ := filepath.Match(entry, filepath.Base(target)); ok {
			return raw, true
		}
	}
	return "", false
}
