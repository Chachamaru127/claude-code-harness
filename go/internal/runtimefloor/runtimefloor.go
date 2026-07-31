// Package runtimefloor implements the RUNTIME ACTION HARD FLOOR — a non-overridable
// pre-action gate that pattern-matches Bash commands before a worker runs them.
// It is distinct from the PRE-MERGE POLICY GATE in go/internal/floor (floor.Gate),
// which evaluates changed files at integration time.
package runtimefloor

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"

	"github.com/Chachamaru127/claude-code-harness/go/pkg/shellscan"
)

type Category string

const (
	CategoryMoneyBilling   Category = "money-billing"
	CategoryEgress         Category = "egress"
	CategorySecretRead     Category = "secret-read"
	CategoryProdDeploy     Category = "prod-deploy"
	CategoryWorktreeEscape Category = "worktree-escape"
)

type Context struct {
	WorktreeRoot string
}

type Decision struct {
	Stopped  bool
	Category Category
	Pattern  string
	Reason   string
}

var (
	moneyBillingPatterns = []struct {
		pattern string
		re      *regexp.Regexp
	}{
		{"stripe ", regexp.MustCompile(`(?i)\bstripe\s+`)},
		{"paypal", regexp.MustCompile(`(?i)\bpaypal\b`)},
		{"aws ce ", regexp.MustCompile(`(?i)\baws\s+ce\s+`)},
		{"gcloud billing", regexp.MustCompile(`(?i)\bgcloud\s+billing\b`)},
	}

	secretReadVerbs = regexp.MustCompile(`(?i)\b(?:cat|less|head|grep|cp|more|tail|sed)\b`)

	ghReleaseDeletePattern = struct {
		pattern string
		re      *regexp.Regexp
	}{"gh release delete", regexp.MustCompile(`(?i)\bgh\s+release\s+delete\b`)}

	prodDeployPatterns = []struct {
		pattern string
		re      *regexp.Regexp
	}{
		{"gh release ", regexp.MustCompile(`(?i)\bgh\s+release\s+`)},
		{"npm publish", regexp.MustCompile(`(?i)\bnpm\s+publish\b`)},
		{"vercel --prod", regexp.MustCompile(`(?i)\bvercel\b.*--prod\b`)},
		{"kubectl apply", regexp.MustCompile(`(?i)\bkubectl\s+apply\b`)},
		{"terraform apply", regexp.MustCompile(`(?i)\bterraform\s+apply\b`)},
		{"git push --tags", regexp.MustCompile(`(?i)\bgit\s+push\b.*--tags\b`)},
		{"git push origin v*", regexp.MustCompile(`(?i)\bgit\s+push\b.*\borigin\s+v`)},
	}

	prodDeployReleaseAutoBypass = map[string]bool{
		"gh release ":        true,
		"git push --tags":    true,
		"git push origin v*": true,
	}

	egressToolPattern = regexp.MustCompile(`(?i)\b(?:curl|wget|nc|scp|rsync)\b`)
	urlPattern        = regexp.MustCompile(`(?i)(?:https?|ftp)://([^\s/]+)`)
	remoteHostPattern = regexp.MustCompile(`(?i)(?:^|\s)(?:[\w.-]+@)?([a-z0-9][\w.-]*\.[a-z]{2,})(?::|/|\s|$)`)
	// schemelessHostAuthority matches curl/wget args like example.com/path without a URL scheme.
	schemelessHostAuthority = regexp.MustCompile(`(?i)^(?:[\w.-]+@)?([a-z0-9][\w.-]*\.[a-z]{2,})(?::\d+)?$`)
)

func CheckCommand(cmd string, ctx Context) Decision {
	cmd = strings.TrimSpace(cmd)
	if cmd == "" {
		return Decision{}
	}

	checks := []func(string, Context) Decision{
		checkMoneyBilling,
		checkEgress,
		checkSecretRead,
		checkProdDeploy,
		checkWorktreeEscape,
	}
	for _, check := range checks {
		if decision := check(cmd, ctx); decision.Stopped {
			return decision
		}
	}
	return Decision{}
}

func stop(category Category, pattern, detail string) Decision {
	return Decision{
		Stopped:  true,
		Category: category,
		Pattern:  pattern,
		Reason:   fmt.Sprintf("runtime action hard floor: %s (%s)", detail, pattern),
	}
}

func checkMoneyBilling(cmd string, _ Context) Decision {
	for _, item := range moneyBillingPatterns {
		if item.re.MatchString(cmd) {
			return stop(CategoryMoneyBilling, item.pattern,
				"money/billing command requires human approval")
		}
	}
	return Decision{}
}

func checkEgress(cmd string, _ Context) Decision {
	if !egressToolPattern.MatchString(cmd) {
		return Decision{}
	}
	if egressFloorExempted() {
		return Decision{}
	}

	lower := strings.ToLower(cmd)

	for _, match := range urlPattern.FindAllStringSubmatch(cmd, -1) {
		host := strings.ToLower(strings.TrimSpace(match[1]))
		if host == "" {
			continue
		}
		host = strings.TrimSuffix(host, ":")
		if !isAllowlistedHost(host) {
			return stop(CategoryEgress, match[0],
				"external network egress requires human approval")
		}
	}

	if strings.Contains(lower, "scp ") || strings.Contains(lower, "rsync ") {
		for _, match := range remoteHostPattern.FindAllStringSubmatch(cmd, -1) {
			host := strings.ToLower(match[1])
			if !isAllowlistedHost(host) {
				return stop(CategoryEgress, match[0],
					"remote copy/sync requires human approval")
			}
		}
	}

	if strings.Contains(lower, "nc ") {
		fields := strings.Fields(cmd)
		for i, field := range fields {
			if strings.EqualFold(field, "nc") && i+1 < len(fields) {
				host := strings.ToLower(fields[i+1])
				if !isAllowlistedHost(host) {
					return stop(CategoryEgress, "nc "+host,
						"network connection to non-allowlisted host requires human approval")
				}
			}
		}
	}

	if decision := checkCurlWgetSchemelessHosts(cmd); decision.Stopped {
		return decision
	}

	return Decision{}
}

func egressFloorExempted() bool {
	return strings.EqualFold(strings.TrimSpace(os.Getenv("HARNESS_RUNTIME_FLOOR_EGRESS")), "off")
}

func checkCurlWgetSchemelessHosts(cmd string) Decision {
	fields := strings.Fields(cmd)
	for i, field := range fields {
		if !strings.EqualFold(field, "curl") && !strings.EqualFold(field, "wget") {
			continue
		}
		for j := i + 1; j < len(fields); j++ {
			token := fields[j]
			if strings.HasPrefix(token, "-") {
				continue
			}
			authority := extractHostAuthority(token)
			if authority == "" || isAllowlistedHost(authority) {
				continue
			}
			if schemelessHostAuthority.MatchString(authority) {
				return stop(CategoryEgress, token,
					"external network egress requires human approval")
			}
		}
	}
	return Decision{}
}

func extractHostAuthority(token string) string {
	token = strings.Trim(token, `"'`)
	if slash := strings.Index(token, "/"); slash >= 0 {
		token = token[:slash]
	}
	return strings.ToLower(token)
}

func isAllowlistedHost(host string) bool {
	host = strings.Trim(host, `"'`)
	host = strings.TrimSuffix(host, ":")
	if host == "localhost" || host == "127.0.0.1" {
		return true
	}
	if strings.HasPrefix(host, "localhost:") || strings.HasPrefix(host, "127.0.0.1:") {
		return true
	}
	return false
}

func checkSecretRead(cmd string, ctx Context) Decision {
	// Scan only the executable portion of the command, not heredoc bodies or
	// comments. A secret filename that appears purely as document text (e.g.
	// inside a `<<'EOF' ... EOF` block, or after `#`) is not an actual read and
	// must not trip the floor. The read verb + indicator still fire on real
	// reads like `cat .env`.
	scannable := shellscan.StripNonExecutableText(cmd)
	if !secretReadVerbs.MatchString(scannable) {
		return Decision{}
	}

	indicators := []struct {
		pattern string
		re      *regexp.Regexp
	}{
		{"~/.aws", regexp.MustCompile(`(?i)~/.aws|/\.aws/`)},
		{"~/.ssh", regexp.MustCompile(`(?i)~/.ssh|/\.ssh/`)},
		{".env", regexp.MustCompile(`(?i)(?:^|[\s/])\.env(?:\b|/)`)},
		{"*.pem", regexp.MustCompile(`(?i)\.pem\b`)},
		{"*.key", regexp.MustCompile(`(?i)\.key\b`)},
		{"credentials", regexp.MustCompile(`(?i)\bcredentials\b`)},
	}

	// Phase 108: an operator can pre-authorize known-safe secret paths so a
	// declared pipeline is not stalled mid-run. Deny unless EVERY matched secret
	// path is explicitly allowlisted; an unlisted secret still denies.
	allow := secretAllowPatterns(ctx)
	for _, item := range indicators {
		for _, loc := range item.re.FindAllStringIndex(scannable, -1) {
			token := enclosingToken(scannable, loc[0])
			if !isAllowlistedSecretPath(token, allow) {
				return stop(CategorySecretRead, item.pattern,
					"credential or secret read requires human approval")
			}
		}
	}
	return Decision{}
}

// secretAllowPatterns returns the operator-declared secret-read allowlist from
// HARNESS_RUNTIME_FLOOR_SECRET_ALLOW (comma-separated path prefixes / globs)
// plus project-local .claude-code-harness.config.json runtimefloor.secretAllow.
// Empty entries and blanket wildcards ("*" / "**") are dropped: the allowlist
// only relaxes EXPLICITLY declared paths and never turns the whole category off.
// If a project config exists but cannot be parsed, fail safe by ignoring all
// declarations, including env, so secret-read stays deny-by-default.
func secretAllowPatterns(ctx Context) []string {
	if configAllow, found, ok := configSecretAllowPatterns(ctx); found {
		if !ok {
			return nil
		}
		return append(envSecretAllowPatterns(), configAllow...)
	}
	return envSecretAllowPatterns()
}

func envSecretAllowPatterns() []string {
	raw := os.Getenv("HARNESS_RUNTIME_FLOOR_SECRET_ALLOW")
	if raw == "" {
		return nil
	}
	var out []string
	for _, p := range strings.Split(raw, ",") {
		p = strings.TrimSpace(strings.Trim(strings.TrimSpace(p), `"'`))
		if p == "" || p == "*" || p == "**" || p == "/" {
			continue
		}
		out = append(out, p)
	}
	return out
}

type runtimeFloorConfig struct {
	RuntimeFloor struct {
		SecretAllow []string `json:"secretAllow"`
		ReleaseAuto bool     `json:"releaseAuto"`
	} `json:"runtimefloor"`
}

// releaseAutoEnabled reports whether the project declares autonomous release
// completion via .claude-code-harness.config.json runtimefloor.releaseAuto.
// Config absent, unparseable, or explicitly false → false (fail-safe).
func releaseAutoEnabled(ctx Context) bool {
	_, configPath, found := resolveProjectRoot(ctx)
	if !found {
		return false
	}
	data, err := os.ReadFile(configPath)
	if err != nil {
		return false
	}
	var cfg runtimeFloorConfig
	if err := json.Unmarshal(data, &cfg); err != nil {
		return false
	}
	return cfg.RuntimeFloor.ReleaseAuto
}

func configSecretAllowPatterns(ctx Context) ([]string, bool, bool) {
	projectRoot, configPath, found := resolveProjectRoot(ctx)
	if !found {
		return nil, false, true
	}
	data, err := os.ReadFile(configPath)
	if err != nil {
		return nil, true, false
	}
	var cfg runtimeFloorConfig
	if err := json.Unmarshal(data, &cfg); err != nil {
		return nil, true, false
	}
	rootAbs, err := filepath.Abs(projectRoot)
	if err != nil {
		rootAbs = filepath.Clean(projectRoot)
	}
	rootAbs = filepath.Clean(rootAbs)
	// The symlink-boundary check below compares an EvalSymlinks()-resolved
	// declaration path against the root. On macOS /var is itself a symlink to
	// /private/var, so resolving an ordinary in-worktree file (no declared
	// symlink at all) yields a path under /private/var while rootAbs is still
	// under /var — comparing that against the unresolved rootAbs would deny
	// every existing file. Resolve the root once with the same function so
	// both sides of the comparison are in the same coordinate space.
	rootResolved, err := filepath.EvalSymlinks(rootAbs)
	if err != nil {
		rootResolved = rootAbs
	}
	rootResolved = filepath.Clean(rootResolved)

	var out []string
	for _, raw := range cfg.RuntimeFloor.SecretAllow {
		p := strings.TrimSpace(strings.Trim(strings.TrimSpace(raw), `"'`))
		if p == "" || p == "*" || p == "**" || p == "/" {
			continue
		}
		if filepath.IsAbs(p) {
			abs, err := filepath.Abs(p)
			if err != nil {
				abs = filepath.Clean(p)
			}
			abs = filepath.Clean(abs)
			if !pathUnderWorktree(abs, rootAbs) {
				continue
			}
			if !secretAllowSymlinkStaysInWorktree(abs, rootResolved) {
				continue
			}
			out = append(out, abs)
			continue
		}
		// Resolve relative declarations against the project root and enforce
		// the same worktree-boundary check as the absolute-path branch above.
		// A raw string check on p (e.g. rejecting a leading "..") is not
		// sufficient: multi-segment escapes ("a/../../etc") or platform
		// separator quirks can still resolve outside rootAbs after Join, so
		// the check must run on the resolved path, not the declaration text.
		joined := filepath.Clean(filepath.Join(rootAbs, filepath.Clean(p)))
		if !pathUnderWorktree(joined, rootAbs) {
			continue
		}
		if !secretAllowSymlinkStaysInWorktree(joined, rootResolved) {
			continue
		}
		out = append(out, joined)
	}
	return out, true, true
}

// secretAllowSymlinkStaysInWorktree reports whether a worktree-bound
// secretAllow declaration stays inside the worktree after symlinks are
// resolved. rootResolved must already be EvalSymlinks()-resolved (or its
// EvalSymlinks fallback) so both sides of the comparison are in the same
// coordinate space — see the comment in configSecretAllowPatterns about the
// macOS /var -> /private/var symlink. This closes an escape where a
// declaration names a path that is textually inside the worktree but is (or
// contains) a symlink pointing outside it (same class of escape as Phase
// 126.4's R05 use of EvalSymlinks). Symlink resolution is used ONLY to
// decide pass/deny here — the allowlist itself must keep storing the
// operator's DECLARED path (the caller appends its own `abs`/`joined` value,
// not this function's return), because isAllowlistedSecretPath() matches the
// token the command names against declared patterns via strings.HasPrefix.
// Substituting the resolved realpath into the allowlist would both (a) stop
// matching the operator's own declared path (regression) and (b) start
// matching the realpath even though the operator never declared it
// (widening) — the declaration and the allowlist entry must refer to the
// same path. If the symlink cannot be resolved (path does not exist yet,
// permission error, etc.) this reports true — fail-safe here means "do not
// widen the allowlist" for a resolved escape, not "silently drop a
// legitimate not-yet-created declaration".
func secretAllowSymlinkStaysInWorktree(path, rootResolved string) bool {
	resolved, err := filepath.EvalSymlinks(path)
	if err != nil {
		return true
	}
	return pathUnderWorktree(filepath.Clean(resolved), rootResolved)
}

func resolveProjectRoot(ctx Context) (string, string, bool) {
	start := strings.TrimSpace(ctx.WorktreeRoot)
	if start == "" {
		var err error
		start, err = os.Getwd()
		if err != nil {
			return "", "", false
		}
	}
	abs, err := filepath.Abs(start)
	if err != nil {
		abs = filepath.Clean(start)
	}
	info, err := os.Stat(abs)
	if err == nil && !info.IsDir() {
		abs = filepath.Dir(abs)
	}
	for {
		candidate := filepath.Join(abs, ".claude-code-harness.config.json")
		if _, err := os.Stat(candidate); err == nil {
			return abs, candidate, true
		}
		parent := filepath.Dir(abs)
		if parent == abs {
			return "", "", false
		}
		abs = parent
	}
}

// isAllowlistedSecretPath reports whether a secret path token is covered by an
// operator-declared allowlist entry. A match is a path prefix, a full-path glob,
// or a basename glob. An empty allowlist never matches (deny-by-default).
func isAllowlistedSecretPath(token string, patterns []string) bool {
	if token == "" || len(patterns) == 0 {
		return false
	}
	token = strings.Trim(token, `"'`)
	for _, pat := range patterns {
		if strings.HasPrefix(token, pat) {
			return true
		}
		if ok, _ := filepath.Match(pat, token); ok {
			return true
		}
		if ok, _ := filepath.Match(pat, filepath.Base(token)); ok {
			return true
		}
	}
	return false
}

// enclosingToken extracts the whitespace-delimited token of s that contains byte
// position idx. Used to recover the concrete secret file path around an indicator
// match so it can be checked against the allowlist.
func enclosingToken(s string, idx int) string {
	if idx < 0 || idx >= len(s) {
		return ""
	}
	isSep := func(b byte) bool { return b == ' ' || b == '\t' || b == '\n' || b == '=' }
	start := idx
	for start > 0 && !isSep(s[start-1]) {
		start--
	}
	end := idx
	for end < len(s) && !isSep(s[end]) {
		end++
	}
	return s[start:end]
}

func checkProdDeploy(cmd string, ctx Context) Decision {
	if ghReleaseDeletePattern.re.MatchString(cmd) {
		return stop(CategoryProdDeploy, ghReleaseDeletePattern.pattern,
			"production deploy or publish requires human approval")
	}

	releaseAuto := releaseAutoEnabled(ctx)

	for _, item := range prodDeployPatterns {
		if releaseAuto && prodDeployReleaseAutoBypass[item.pattern] {
			continue
		}
		if item.re.MatchString(cmd) {
			return stop(CategoryProdDeploy, item.pattern,
				"production deploy or publish requires human approval")
		}
	}
	return Decision{}
}

func checkWorktreeEscape(cmd string, ctx Context) Decision {
	if ctx.WorktreeRoot == "" {
		return Decision{}
	}
	dangerous, targets := shellscan.DangerousRemoval(cmd)
	if !dangerous {
		return Decision{}
	}

	worktreeRoot, err := filepath.Abs(ctx.WorktreeRoot)
	if err != nil {
		worktreeRoot = filepath.Clean(ctx.WorktreeRoot)
	}

	for _, target := range targets {
		expanded, ok := expandPathTarget(target)
		if !ok {
			continue
		}
		abs, err := filepath.Abs(expanded)
		if err != nil {
			abs = filepath.Clean(expanded)
		}
		if pathUnderWorktree(abs, worktreeRoot) {
			continue
		}
		if shellscan.IsAllowlistedTempPath(abs) {
			continue
		}
		return stop(CategoryWorktreeEscape, "rm "+target,
			"destructive command outside task worktree requires human approval")
	}
	return Decision{}
}

func expandPathTarget(target string) (string, bool) {
	if strings.HasPrefix(target, "~/") || target == "~" {
		home, err := os.UserHomeDir()
		if err != nil {
			return "", false
		}
		if target == "~" {
			return home, true
		}
		return filepath.Join(home, strings.TrimPrefix(target, "~/")), true
	}
	if strings.HasPrefix(target, "/") {
		return target, true
	}
	return "", false
}

func pathUnderWorktree(path, worktreeRoot string) bool {
	cleanPath := filepath.Clean(path)
	cleanRoot := filepath.Clean(worktreeRoot)
	if cleanPath == cleanRoot {
		return true
	}
	return strings.HasPrefix(cleanPath, cleanRoot+string(filepath.Separator))
}
