package guardrail

import (
	"os"
	"path/filepath"
	"regexp"
	"strings"

	"github.com/Chachamaru127/claude-code-harness/go/pkg/hookproto"
)

// ---------------------------------------------------------------------------
// Protected path taxonomy
// ---------------------------------------------------------------------------

type protectedPathLevel int

const (
	protectedPathNone protectedPathLevel = iota
	protectedPathWarn
	protectedPathAsk
	protectedPathDeny
)

type protectedPathMatch struct {
	Level  protectedPathLevel
	Reason string
	Path   string
}

type protectedPathRule struct {
	level   protectedPathLevel
	reason  string
	pattern *regexp.Regexp
}

// Claude Code 2.1.121/2.1.126 protected path taxonomy:
//   - deny: .git/, secrets, shell rc/profile files, destructive hook entrypoints.
//   - ask: .claude/skills/, .claude/agents/, .claude/commands/, .vscode/.
//   - warn: .claude/rules/, .claude/memory/, setup metadata.
//
// This intentionally does not deny every .claude/ path. Runtime state and other
// project-local Claude data remain governed by the normal write rules.
var protectedPathRules = []protectedPathRule{
	// deny: repository internals, secrets, hook entrypoints, and shell startup files
	{protectedPathDeny, "Git internal metadata", regexp.MustCompile(`(?:^|/)\.git(?:/|$)`)},
	{protectedPathDeny, "secret or credential file", regexp.MustCompile(`(?:^|/)\.env(?:$|\.)`)},
	{protectedPathDeny, "secret or credential file", regexp.MustCompile(`(?:^|/)\.envrc$`)},
	{protectedPathDeny, "secret or credential file", regexp.MustCompile(`(?:^|/)secrets?(?:/|$)`)},
	{protectedPathDeny, "secret or credential file", regexp.MustCompile(`(?:^|/)(?:id_rsa|id_ed25519|id_ecdsa|id_dsa)$`)},
	{protectedPathDeny, "secret or credential file", regexp.MustCompile(`\.(?:pem|key|p12|pfx)$`)},
	{protectedPathDeny, "SSH trust file", regexp.MustCompile(`(?:^|/)(?:authorized_keys|known_hosts)$`)},
	{protectedPathDeny, "destructive hook entrypoint", regexp.MustCompile(`(?:^|/)\.husky(?:/|$)`)},
	{protectedPathDeny, "destructive hook entrypoint", regexp.MustCompile(`(?:^|/)\.claude/hooks(?:/|$)`)},
	{protectedPathDeny, "shell rc/profile file", regexp.MustCompile(`(?:^|/)\.(?:bashrc|bash_profile|bash_login|profile|zshrc|zprofile|zshenv|zlogin|zlogout|kshrc|cshrc|tcshrc)$`)},
	{protectedPathDeny, "shell rc/profile file", regexp.MustCompile(`(?:^|/)\.config/fish/config\.fish$`)},
	{protectedPathDeny, "shell rc/profile file", regexp.MustCompile(`(?:^|/)(?:Microsoft\.)?(?:PowerShell_)?profile\.ps1$`)},

	// ask: agent capability surfaces and editor automation settings
	{protectedPathAsk, "Claude capability path", regexp.MustCompile(`(?:^|/)\.claude/(?:skills|agents|commands)(?:/|$)`)},
	{protectedPathAsk, "editor automation settings", regexp.MustCompile(`(?:^|/)\.vscode(?:/|$)`)},

	// warn: policy/memory/setup metadata that is important but not hard-denied
	{protectedPathWarn, "Claude rule or memory path", regexp.MustCompile(`(?:^|/)\.claude/(?:rules|memory)(?:/|$)`)},
	{protectedPathWarn, "setup metadata", regexp.MustCompile(`(?:^|/)\.claude/(?:settings(?:\.local)?\.json|config(?:/|$)|Plans\.md$)`)},
	{protectedPathWarn, "setup metadata", regexp.MustCompile(`(?:^|/)\.claude-plugin/plugin\.json$`)},
	{protectedPathWarn, "setup metadata", regexp.MustCompile(`(?:^|/)(?:CLAUDE|AGENTS)\.md$`)},
	{protectedPathWarn, "setup metadata", regexp.MustCompile(`(?:^|/)\.mcp\.json$`)},
	{protectedPathWarn, "setup metadata", regexp.MustCompile(`(?:^|/)harness\.toml$`)},
}

func normalizePathForGuardrail(filePath string) string {
	cleaned := filepath.Clean(filePath)
	if cleaned == "." {
		return filePath
	}
	return filepath.ToSlash(cleaned)
}

func classifyProtectedPathPattern(filePath string) protectedPathMatch {
	normalized := normalizePathForGuardrail(filePath)
	best := protectedPathMatch{Level: protectedPathNone, Path: normalized}
	for _, rule := range protectedPathRules {
		if rule.pattern.MatchString(normalized) && rule.level > best.Level {
			best = protectedPathMatch{
				Level:  rule.level,
				Reason: rule.reason,
				Path:   normalized,
			}
		}
	}
	return best
}

func strongerProtectedPathMatch(a, b protectedPathMatch) protectedPathMatch {
	if b.Level > a.Level {
		return b
	}
	return a
}

func classifyProtectedPath(filePath string) protectedPathMatch {
	match := classifyProtectedPathPattern(filePath)

	// Resolve symlinks and check the real path (CC 2.1.89: symlink target resolution)
	realPath, err := filepath.EvalSymlinks(filePath)
	if err != nil {
		// Fail-safe: symlink loop, broken link, or other error → deny.
		// Exception: if the path simply doesn't exist, it's classified from
		// the path text only, so new non-sensitive files are not over-blocked.
		if _, statErr := os.Lstat(filePath); os.IsNotExist(statErr) {
			return match
		}
		return protectedPathMatch{
			Level:  protectedPathDeny,
			Reason: "unresolvable protected path",
			Path:   normalizePathForGuardrail(filePath),
		}
	}

	return strongerProtectedPathMatch(match, classifyProtectedPathPattern(realPath))
}

// isProtectedPath checks whether filePath matches any protected taxonomy level.
// If EvalSymlinks returns an error (symlink loop, broken link, etc.),
// the function returns true via the fail-safe deny classification.
func isProtectedPath(filePath string) bool {
	return classifyProtectedPath(filePath).Level != protectedPathNone
}

// ---------------------------------------------------------------------------
// Bash write target extraction
// ---------------------------------------------------------------------------

var (
	bashRedirectionTargetPattern = regexp.MustCompile(`(?:^|[\s;&|])(?:\d*&>>?|\d*>>?|&>>?|>\|)\s*['"]?([^'"` + "`" + `\s;&|]+)['"]?`)
	bashTeeCommandPattern        = regexp.MustCompile(`(?:^|[|;&]\s*)tee\b([^;&|]*)`)
)

func stripShellTokenQuotes(token string) string {
	token = strings.TrimSpace(token)
	token = strings.Trim(token, "'\"")
	return token
}

func extractBashWriteTargets(command string) []string {
	var targets []string
	for _, m := range bashRedirectionTargetPattern.FindAllStringSubmatch(command, -1) {
		if len(m) >= 2 {
			targets = append(targets, stripShellTokenQuotes(m[1]))
		}
	}

	for _, m := range bashTeeCommandPattern.FindAllStringSubmatch(command, -1) {
		if len(m) < 2 {
			continue
		}
		for _, token := range strings.Fields(m[1]) {
			token = stripShellTokenQuotes(token)
			if token == "" || token == "--" {
				continue
			}
			if strings.HasPrefix(token, "-") {
				continue
			}
			if strings.ContainsAny(token, "<>|`$") {
				continue
			}
			targets = append(targets, token)
		}
	}

	return targets
}

func classifyBashProtectedWrite(command string) protectedPathMatch {
	best := protectedPathMatch{Level: protectedPathNone}
	for _, target := range extractBashWriteTargets(command) {
		best = strongerProtectedPathMatch(best, classifyProtectedPathPattern(target))
	}
	return best
}

func bashProtectedWriteHookResult(ctx hookproto.RuleContext, command string) *hookproto.HookResult {
	var askResult *hookproto.HookResult
	var warnResult *hookproto.HookResult

	for _, target := range extractBashWriteTargets(command) {
		match := classifyProtectedPathPattern(target)
		switch match.Level {
		case protectedPathDeny:
			if result := r03ProtectedPathAskResult(ctx, match.Path); result != nil {
				if askResult == nil {
					askResult = result
				}
				continue
			}
			return protectedPathHookResult(match, match.Path, "shell write to a protected path")
		case protectedPathAsk:
			if askResult == nil {
				askResult = protectedPathHookResult(match, match.Path, "shell write to a protected path")
			}
		case protectedPathWarn:
			if warnResult == nil {
				warnResult = protectedPathHookResult(match, match.Path, "shell write to a protected path")
			}
		}
	}

	if askResult != nil {
		return askResult
	}
	if warnResult != nil {
		return warnResult
	}
	return nil
}

// ---------------------------------------------------------------------------
// Project root check
// ---------------------------------------------------------------------------

func isUnderProjectRoot(filePath, projectRoot string) bool {
	// 相対パスは projectRoot を基準に解決
	resolved := filePath
	if !filepath.IsAbs(filePath) {
		resolved = filepath.Join(projectRoot, filePath)
	}
	cleaned := filepath.Clean(resolved)
	root := filepath.Clean(projectRoot)
	if !strings.HasSuffix(root, string(filepath.Separator)) {
		root += string(filepath.Separator)
	}
	return strings.HasPrefix(cleaned, root) || cleaned == root
}

// ---------------------------------------------------------------------------
// Whitespace normalization (CC 2.1.98: wildcard pattern defense-in-depth)
// ---------------------------------------------------------------------------

// wsNormPattern matches one or more whitespace characters (spaces, tabs, etc.)
var wsNormPattern = regexp.MustCompile(`\s+`)

// normalizeCommand collapses consecutive whitespace characters (spaces, tabs,
// and other whitespace) into a single space and trims leading/trailing whitespace.
// This is used as a defense-in-depth measure before wildcard pattern matching,
// so that "git  push  --force" and "git\tpush\t--force" are treated identically
// to "git push --force".
func normalizeCommand(cmd string) string {
	return strings.TrimSpace(wsNormPattern.ReplaceAllString(cmd, " "))
}

// ---------------------------------------------------------------------------
// Dangerous deletion detection
// ---------------------------------------------------------------------------

var (
	rmRecursivePattern            = regexp.MustCompile(`\brm\s+--recursive\b`)
	findDeletePattern             = regexp.MustCompile(`\bfind\s+.*(?:\s-delete(?:\s|$)|\s-exec\s+rm\s+.*(?:\\;|;|\+|$))`)
	macOSDangerousRmTargetPattern = regexp.MustCompile(
		`\brm\s+.*(?:/private/(?:etc|var|tmp|home)(?:/|\s|$)|/System(?:/|\s|$)|/Library/(?:LaunchDaemons|LaunchAgents|Preferences|Keychains)(?:/|\s|$)|~/Library(?:/|\s|$)|/Users/[^/\s]+/Library(?:/|\s|$))`,
	)
)

// rmRfManual detects rm with both -r and -f flags (in any order/combination).
// Go regexp doesn't support lookahead (?=...) so we check manually.
var rmWithFlags = regexp.MustCompile(`\brm\s+(.+)`)

func hasDangerousRmRf(command string) bool {
	// Normalize whitespace before matching (CC 2.1.98: defense-in-depth)
	command = normalizeCommand(command)
	if hasDangerousFindDelete(command) || hasDangerousMacOSRemovalPath(command) {
		return true
	}
	if rmRecursivePattern.MatchString(command) {
		return true
	}
	// Check for -rf, -fr, -r -f, etc. in rm arguments
	m := rmWithFlags.FindStringSubmatch(command)
	if m == nil {
		return false
	}
	args := m[1]
	// Scan tokens for flag groups containing both r and f
	hasR := false
	hasF := false
	for _, token := range strings.Fields(args) {
		if !strings.HasPrefix(token, "-") || strings.HasPrefix(token, "--") {
			continue // skip non-short-flags and long flags
		}
		flags := token[1:] // strip leading -
		for _, c := range flags {
			if c == 'r' {
				hasR = true
			}
			if c == 'f' {
				hasF = true
			}
		}
	}
	return hasR && hasF
}

func hasDangerousFindDelete(command string) bool {
	return findDeletePattern.MatchString(command)
}

func hasDangerousMacOSRemovalPath(command string) bool {
	return macOSDangerousRmTargetPattern.MatchString(command)
}

// ---------------------------------------------------------------------------
// git push --force detection
// ---------------------------------------------------------------------------

var (
	forcePushPattern = regexp.MustCompile(`\bgit\s+push\b.*--force(?:-with-lease)?\b`)
	forcePushShort   = regexp.MustCompile(`\bgit\s+push\b.*-f\b`)
)

func hasForcePush(command string) bool {
	// Normalize whitespace before matching (CC 2.1.98: defense-in-depth)
	command = normalizeCommand(command)
	return forcePushPattern.MatchString(command) || forcePushShort.MatchString(command)
}

// ---------------------------------------------------------------------------
// sudo detection
// ---------------------------------------------------------------------------

// sudoPattern matches "sudo" preceded by start-of-string, whitespace,
// or shell metacharacters that introduce a subshell context: (, |, &, `, ;.
// This prevents bypass via "echo $(sudo ...)" or "echo `sudo ...`".
// CC 2.1.110: extended to cover subshell and backtick contexts.
var sudoPattern = regexp.MustCompile(`(?:^|[\s(|&` + "`" + `;])sudo\s`)

func hasSudo(command string) bool {
	command = normalizeCommand(command)
	return sudoPattern.MatchString(command)
}

// ---------------------------------------------------------------------------
// --no-verify / --no-gpg-sign detection
// ---------------------------------------------------------------------------

// shellTokenBoundary matches the characters that terminate a flag token on a
// shell command line. Besides whitespace, bash treats the metacharacters
// `;`, `&`, `|`, `(`, `)`, `<` and `>` as token separators, so a flag such as
// `--no-verify` is still effective when written as `--no-verify&&echo` or
// `--no-verify;cmd`. Anchoring on this class (instead of `\s` alone) prevents
// the detection from being bypassed by appending a metacharacter without a
// surrounding space.
const shellTokenBoundary = `[\s;&|()<>]`

var (
	noVerifyPattern  = regexp.MustCompile(`(?:^|` + shellTokenBoundary + `)--no-verify(?:` + shellTokenBoundary + `|$)`)
	noGpgSignPattern = regexp.MustCompile(`(?:^|` + shellTokenBoundary + `)--no-gpg-sign(?:` + shellTokenBoundary + `|$)`)
)

func hasDangerousGitBypassFlag(command string) bool {
	command = normalizeCommand(command)
	return noVerifyPattern.MatchString(command) || noGpgSignPattern.MatchString(command)
}

// ---------------------------------------------------------------------------
// Protected branch reset --hard detection
// ---------------------------------------------------------------------------

var protectedBranchRefPattern = regexp.MustCompile(
	`^(?:origin/|upstream/)?(?:refs/heads/)?(?:main|master)(?:[~^]\d+)?$`,
)

func normalizeGitToken(token string) string {
	return strings.Trim(token, "'\"")
}

func hasProtectedBranchResetHard(command string) bool {
	command = normalizeCommand(command)
	tokens := strings.Fields(command)
	resetIndex := -1
	hasHard := false
	for i, t := range tokens {
		normalized := normalizeGitToken(t)
		if normalized == "reset" {
			resetIndex = i
		}
		if normalized == "--hard" {
			hasHard = true
		}
	}
	if resetIndex == -1 || !hasHard {
		return false
	}
	for _, t := range tokens[resetIndex+1:] {
		normalized := normalizeGitToken(t)
		if strings.HasPrefix(normalized, "-") {
			continue
		}
		if protectedBranchRefPattern.MatchString(normalized) {
			return true
		}
	}
	return false
}

// ---------------------------------------------------------------------------
// Direct push to protected branch detection
// ---------------------------------------------------------------------------

var gitPushPattern = regexp.MustCompile(`\bgit\s+push\b`)

func hasDirectPushToProtectedBranch(command string) bool {
	command = normalizeCommand(command)
	if !gitPushPattern.MatchString(command) {
		return false
	}
	tokens := strings.Fields(command)
	pushIndex := -1
	for i, t := range tokens {
		if t == "push" {
			pushIndex = i
			break
		}
	}
	if pushIndex == -1 {
		return false
	}

	// Collect non-flag args after "push"
	var args []string
	for _, t := range tokens[pushIndex+1:] {
		if !strings.HasPrefix(t, "-") {
			args = append(args, t)
		}
	}
	if len(args) == 0 {
		return false
	}

	for _, arg := range args {
		normalized := normalizeGitToken(arg)
		if protectedBranchRefPattern.MatchString(normalized) {
			return true
		}
		// Check refspec (src:dst)
		parts := strings.SplitN(arg, ":", 2)
		if len(parts) == 2 {
			if protectedBranchRefPattern.MatchString(normalizeGitToken(parts[1])) {
				return true
			}
		}
	}
	return false
}

// ---------------------------------------------------------------------------
// Protected review path detection (warn-only)
// ---------------------------------------------------------------------------

var protectedReviewPathPatterns = []*regexp.Regexp{
	regexp.MustCompile(`(?:^|/)package\.json$`),
	regexp.MustCompile(`(?:^|/)Dockerfile$`),
	regexp.MustCompile(`(?:^|/)docker-compose\.yml$`),
	regexp.MustCompile(`(?:^|/)\.github/workflows/[^/]+$`),
	regexp.MustCompile(`(?:^|/)schema\.prisma$`),
	regexp.MustCompile(`(?:^|/)wrangler\.toml$`),
	regexp.MustCompile(`(?:^|/)index\.html$`),
}

func isProtectedReviewPath(filePath string) bool {
	for _, p := range protectedReviewPathPatterns {
		if p.MatchString(filePath) {
			return true
		}
	}
	return false
}
