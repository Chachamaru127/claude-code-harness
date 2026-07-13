package guardrail

import (
	"github.com/Chachamaru127/claude-code-harness/go/internal/projectconfig"
	"github.com/Chachamaru127/claude-code-harness/go/pkg/hookproto"
)

// resolveProjectConfig loads the per-project .claude-code-harness.config.json
// starting from projectRoot, falling back to the plugin root. Loading is
// best-effort: a missing or unparseable file yields an empty result so the hook
// fast-path never fails on configuration problems.
func resolveProjectConfig(input hookproto.HookInput, projectRoot string) projectconfig.LoadResult {
	if res := projectconfig.Load(projectRoot); res.Found {
		return res
	}
	if input.PluginRoot != "" && input.PluginRoot != projectRoot {
		if res := projectconfig.Load(input.PluginRoot); res.Found {
			return res
		}
	}
	return projectconfig.LoadResult{}
}

// resolveProtectedPathDenyList returns the project-relative protected path
// prefixes declared in paths.protected. If the config is present but
// unparseable, the declarations are ignored (best-effort, no extra denies).
func resolveProtectedPathDenyList(res projectconfig.LoadResult) []string {
	return res.ProtectedPaths()
}

// resolveProtectedBranches returns the configured protected branch names from
// git.protected_branches.
func resolveProtectedBranches(res projectconfig.LoadResult) []string {
	return res.ProtectedBranches()
}

// resolveAllowRmRf reports whether the project opted into suppressing the
// destructive-delete confirmation via destructive_commands.allow_rm_rf. A
// missing or unparseable config returns false, keeping the confirmation on.
func resolveAllowRmRf(res projectconfig.LoadResult) bool {
	return res.AllowRmRf()
}

// resolveConfigParseError returns a human-readable message when a project config
// file was found but could not be parsed (malformed JSON, unknown keys, or an
// invalid glob pattern). R16 fails closed on this so a typo cannot silently drop
// the declared protections. An empty string means the config is absent or valid.
func resolveConfigParseError(res projectconfig.LoadResult) string {
	if res.Found && res.ParseErr != nil {
		return res.ParseErr.Error()
	}
	return ""
}
