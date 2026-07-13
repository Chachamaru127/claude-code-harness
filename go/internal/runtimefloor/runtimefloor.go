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

	"github.com/Chachamaru127/claude-code-harness/go/internal/projectconfig"
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

	egressToolPattern = regexp.MustCompile(`(?i)\b(?:curl|wget|nc|scp|rsync)\b`)
	urlPattern        = regexp.MustCompile(`(?i)(?:https?|ftp)://([^\s/]+)`)
	remoteHostPattern = regexp.MustCompile(`(?i)(?:^|\s)(?:[\w.-]+@)?([a-z0-9][\w.-]*\.[a-z]{2,})(?::|/|\s|$)`)
	// schemelessHostAuthority matches curl/wget args like example.com/path without a URL scheme.
	schemelessHostAuthority = regexp.MustCompile(`(?i)^(?:[\w.-]+@)?([a-z0-9][\w.-]*\.[a-z]{2,})(?::\d+)?$`)

	// rmRecursivePattern gates the worktree-escape floor. It matches short-flag
	// recursive removals (-r, -rf, -fr, …) and the long-form `rm --recursive`,
	// so a destructive delete outside the task worktree is stopped regardless of
	// which flag spelling is used.
	rmRecursivePattern = regexp.MustCompile(`(?i)\brm\s+(?:-[a-z]*r[a-z]*\s+|-[a-z]*f[a-z]*r[a-z]*\s+|-[a-z]*r[a-z]*f[a-z]*\s+|--recursive(?:\s|=|$))`)
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
	scannable := stripNonExecutableText(cmd)
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
			// The indicator regex may consume a leading whitespace delimiter
			// (e.g. `cat .env` matches " .env"), so loc[0] can point at the
			// space *before* the secret path. Advancing past leading whitespace
			// anchors enclosingToken on the path token itself instead of the
			// preceding command word; a leading "/" is kept so absolute paths
			// still resolve to their full form.
			start := loc[0]
			for start < loc[1] && (scannable[start] == ' ' || scannable[start] == '\t' || scannable[start] == '\n') {
				start++
			}
			token := enclosingToken(scannable, start)
			if secretTokenAllowlisted(token, allow, ctx.WorktreeRoot) {
				continue
			}
			return stop(CategorySecretRead, item.pattern,
				"credential or secret read requires human approval")
		}
	}
	return Decision{}
}

// secretTokenAllowlisted reports whether a matched secret-read token is covered
// by the allowlist. It first compares the token as written, then—because a
// project config resolves relative declarations (secretAllow:[".env"]) to a
// project-root-absolute path—retries with the token resolved against the
// worktree root so a bare relative read like `cat .env` matches. The retry is
// additive: it can only grant, never deny a token the base match already
// allowed.
func secretTokenAllowlisted(token string, allow []string, worktreeRoot string) bool {
	if isAllowlistedSecretPath(token, allow) {
		return true
	}
	root := strings.TrimSpace(worktreeRoot)
	if root == "" || token == "" || filepath.IsAbs(token) || strings.HasPrefix(token, "~") {
		return false
	}
	abs := filepath.Clean(filepath.Join(root, token))
	return isAllowlistedSecretPath(abs, allow)
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
	} `json:"runtimefloor"`
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
			out = append(out, abs)
			continue
		}
		// Relative entries resolve against the project root. Boundary-check them
		// the same way as absolute entries so a traversal like "../.ssh/id_rsa"
		// cannot allowlist a secret outside the task worktree.
		abs := filepath.Clean(filepath.Join(rootAbs, filepath.Clean(p)))
		if !pathUnderWorktree(abs, rootAbs) {
			continue
		}
		out = append(out, abs)
	}
	return out, true, true
}

func resolveProjectRoot(ctx Context) (string, string, bool) {
	// Delegate to the shared project-config resolver so that both the canonical
	// ".claude-code-harness.config.json" and the non-dotted
	// "claude-code-harness.config.json" (the shipped example's base name) are
	// honored consistently across the guardrail and the runtime floor.
	return projectconfig.Resolve(strings.TrimSpace(ctx.WorktreeRoot))
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

var heredocOpen = regexp.MustCompile(`<<-?\s*(['"]?)([A-Za-z_][A-Za-z0-9_]*)(['"]?)`)

// stripNonExecutableText removes heredoc bodies and trailing line comments so
// that secret indicators appearing only as document text do not trigger the
// floor. It is deliberately conservative: it strips heredoc bodies between an
// opener (`<<WORD`) and the matching terminator line, and removes `#` comments
// that start at line-begin or after whitespace (not inside a token).
func stripNonExecutableText(cmd string) string {
	lines := strings.Split(cmd, "\n")
	out := make([]string, 0, len(lines))
	var terminator string       // non-empty while inside a heredoc body
	var inSingle, inDouble bool // shell quote state carried ACROSS lines

	for _, line := range lines {
		if terminator != "" {
			// Inside a heredoc body: drop lines until the terminator line.
			// Quotes here are literal document text, so quote state is not
			// touched while suppressing the body.
			if strings.TrimSpace(line) == terminator {
				terminator = ""
			}
			continue
		}
		// Detect a heredoc opener on this line; keep the line itself (the
		// opener is part of the command) but suppress the following body.
		if m := heredocOpen.FindStringSubmatch(line); m != nil {
			terminator = m[2]
		}
		var stripped string
		stripped, inSingle, inDouble = stripLineComment(line, inSingle, inDouble)
		out = append(out, stripped)
	}
	return strings.Join(out, "\n")
}

// stripLineComment removes a `#` comment from a single line when the `#` is at
// line start or preceded by whitespace and is not inside single/double quotes.
// Quote state is threaded in and out so that a string opened on a previous line
// keeps the `#` on a continuation line from being misread as a comment — without
// this, a multi-line quoted string whose closing quote shares a line with `#`
// would let stripLineComment delete real trailing code (e.g. `&& cat .env`),
// silently defeating the secret-read floor.
func stripLineComment(line string, inSingle, inDouble bool) (string, bool, bool) {
	for i := 0; i < len(line); i++ {
		c := line[i]
		switch {
		case c == '\'' && !inDouble:
			inSingle = !inSingle
		case c == '"' && !inSingle:
			inDouble = !inDouble
		case c == '#' && !inSingle && !inDouble:
			if i == 0 || line[i-1] == ' ' || line[i-1] == '\t' {
				return line[:i], inSingle, inDouble
			}
		}
	}
	return line, inSingle, inDouble
}

func checkProdDeploy(cmd string, _ Context) Decision {
	for _, item := range prodDeployPatterns {
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
	if !rmRecursivePattern.MatchString(cmd) {
		return Decision{}
	}

	worktreeRoot, err := filepath.Abs(ctx.WorktreeRoot)
	if err != nil {
		worktreeRoot = filepath.Clean(ctx.WorktreeRoot)
	}

	tempRoots := allowlistedTempRoots()

	targets := extractRmTargets(cmd)
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
		if pathUnderAnyRoot(abs, tempRoots) {
			continue
		}
		return stop(CategoryWorktreeEscape, "rm "+target,
			"destructive command outside task worktree requires human approval")
	}
	return Decision{}
}

// allowlistedTempRoots lists OS-managed scratch roots where a destructive rm
// carries no data-loss risk. The set covers /tmp, /var/tmp, their macOS
// /private/* canonical forms, the $TMPDIR override, and per-user cache roots
// (~/.cache on Linux, ~/Library/Caches on macOS). Worktree-escape stays in
// effect for everything else (Desktop, Documents, repo-adjacent paths).
func allowlistedTempRoots() []string {
	roots := []string{
		"/tmp",
		"/var/tmp",
		"/private/tmp",
		"/private/var/tmp",
	}
	if t := strings.TrimSpace(os.Getenv("TMPDIR")); t != "" {
		if abs, err := filepath.Abs(t); err == nil {
			roots = append(roots, filepath.Clean(abs))
		} else {
			roots = append(roots, filepath.Clean(t))
		}
	}
	if home, err := os.UserHomeDir(); err == nil && home != "" {
		roots = append(roots, filepath.Join(home, ".cache"))
		roots = append(roots, filepath.Join(home, "Library", "Caches"))
	}
	return roots
}

func pathUnderAnyRoot(absPath string, roots []string) bool {
	for _, root := range roots {
		if root == "" {
			continue
		}
		if pathUnderWorktree(absPath, root) {
			return true
		}
	}
	return false
}

func extractRmTargets(cmd string) []string {
	fields := strings.Fields(cmd)
	var targets []string
	for i, field := range fields {
		if !strings.EqualFold(field, "rm") {
			continue
		}
		for j := i + 1; j < len(fields); j++ {
			arg := fields[j]
			if strings.HasPrefix(arg, "-") {
				continue
			}
			targets = append(targets, arg)
		}
	}
	return targets
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
