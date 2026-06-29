// Package runtimefloor implements the RUNTIME ACTION HARD FLOOR — a non-overridable
// pre-action gate that pattern-matches Bash commands before a worker runs them.
// It is distinct from the PRE-MERGE POLICY GATE in go/internal/floor (floor.Gate),
// which evaluates changed files at integration time.
package runtimefloor

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"
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

	rmRecursivePattern = regexp.MustCompile(`(?i)\brm\s+(?:-[a-z]*r[a-z]*\s+|-[a-z]*f[a-z]*r[a-z]*\s+|-[a-z]*r[a-z]*f[a-z]*\s+)`)
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

	// Owner-level scope control: HARNESS_RUNTIME_FLOOR_EGRESS=off lets the human
	// who launches the session opt the egress category out of the hard floor —
	// e.g. for user-driven research / dynamic-workflow runs that legitimately
	// fetch many external URLs and where the human is the approval. This is NOT a
	// worker-level override: the PreToolUse hook subprocess inherits Claude Code's
	// process environment, so a sandboxed or prompt-injected worker cannot set
	// this variable for the hook — only a shell export or ~/.claude/settings.json
	// "env" by the owner can. The other four categories (money-billing,
	// secret-read, prod-deploy, worktree-escape) stay non-overridable.
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

// egressFloorExempted reports whether the owner has explicitly scoped the egress
// hard floor out of the current session via HARNESS_RUNTIME_FLOOR_EGRESS=off.
// Only the literal value "off" (case-insensitive) exempts; any other value, or an
// unset variable, keeps the egress floor enforced (fail-safe default).
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

func checkSecretRead(cmd string, _ Context) Decision {
	if !secretReadVerbs.MatchString(cmd) {
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

	for _, item := range indicators {
		if item.re.MatchString(cmd) {
			return stop(CategorySecretRead, item.pattern,
				"credential or secret read requires human approval")
		}
	}
	return Decision{}
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
