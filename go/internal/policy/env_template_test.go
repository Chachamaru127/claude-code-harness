package policy

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/Chachamaru127/claude-code-harness/go/pkg/hookproto"
)

func TestPublicEnvTemplatesAreAllowedAcrossGuardrails(t *testing.T) {
	var templates []string
	for _, name := range publicEnvTemplateBasenames {
		templates = append(templates, name, filepath.Join("config", name))
	}

	for _, filePath := range templates {
		t.Run(filePath, func(t *testing.T) {
			if match := classifyProtectedPathPattern(filePath); match.Level != protectedPathNone {
				t.Fatalf("template path classified as protected: level=%v reason=%q", match.Level, match.Reason)
			}

			for _, toolName := range []string{"Write", "Edit"} {
				result := EvaluateRules(makeCtx(toolName, map[string]interface{}{"file_path": filePath}))
				if result.Decision != hookproto.DecisionApprove {
					t.Errorf("%s %s: expected approve, got %s (%s)", toolName, filePath, result.Decision, result.Reason)
				}
			}

			bashWrite := EvaluateRules(makeCtx("Bash", map[string]interface{}{
				"command": "printf 'KEY=value\\n' > " + filePath,
			}))
			if bashWrite.Decision != hookproto.DecisionApprove {
				t.Errorf("Bash write %s: expected approve, got %s (%s)", filePath, bashWrite.Decision, bashWrite.Reason)
			}

			gitAdd := EvaluateRules(makeCtx("Bash", map[string]interface{}{
				"command": "git add -- " + filePath,
			}))
			if gitAdd.Decision != hookproto.DecisionApprove {
				t.Errorf("git add %s: expected approve, got %s (%s)", filePath, gitAdd.Decision, gitAdd.Reason)
			}
		})
	}
}

func TestSecretEnvVariantsRemainDenied(t *testing.T) {
	denied := []string{
		".env",
		".env.local",
		".env.production",
		".env.*",
		".env.example.local",
		".env.template.bak",
		"secret/.env.example",
		"secrets/.env.example",
		".git/.env.example",
	}

	for _, filePath := range denied {
		t.Run(filePath, func(t *testing.T) {
			if match := classifyProtectedPathPattern(filePath); match.Level != protectedPathDeny {
				t.Fatalf("expected deny classification for %s, got level=%v reason=%q", filePath, match.Level, match.Reason)
			}

			write := EvaluateRules(makeCtx("Write", map[string]interface{}{"file_path": filePath}))
			if write.Decision != hookproto.DecisionDeny {
				t.Errorf("Write %s: expected deny, got %s", filePath, write.Decision)
			}

			bashWrite := EvaluateRules(makeCtx("Bash", map[string]interface{}{
				"command": "printf 'KEY=value\\n' > " + filePath,
			}))
			if bashWrite.Decision != hookproto.DecisionDeny {
				t.Errorf("Bash write %s: expected deny, got %s", filePath, bashWrite.Decision)
			}
		})
	}
}

func TestEnvTemplateSymlinkBoundariesRemainDeniedAcrossRules(t *testing.T) {
	root := t.TempDir()
	secretDir := filepath.Join(root, "secrets")
	if err := os.Mkdir(secretDir, 0o700); err != nil {
		t.Fatalf("mkdir secrets: %v", err)
	}
	if err := os.WriteFile(filepath.Join(root, ".env"), []byte("SECRET=value\n"), 0o600); err != nil {
		t.Fatalf("write secret target: %v", err)
	}
	if err := os.Symlink(filepath.Join(root, ".env"), filepath.Join(root, ".env.example")); err != nil {
		t.Fatalf("create direct symlink: %v", err)
	}
	if err := os.Symlink(secretDir, filepath.Join(root, "config")); err != nil {
		t.Fatalf("create parent symlink: %v", err)
	}

	for _, filePath := range []string{".env.example", "config/.env.template"} {
		for _, toolName := range []string{"Write", "Edit"} {
			ctx := makeCtx(toolName, map[string]interface{}{"file_path": filePath})
			ctx.ProjectRoot = root
			if result := EvaluateRules(ctx); result.Decision != hookproto.DecisionDeny {
				t.Errorf("%s %s: expected deny, got %s", toolName, filePath, result.Decision)
			}
		}

		ctx := makeCtx("Bash", map[string]interface{}{"command": "printf x > " + filePath})
		ctx.ProjectRoot = root
		if result := EvaluateRules(ctx); result.Decision != hookproto.DecisionDeny {
			t.Errorf("Bash redirect %s: expected deny, got %s", filePath, result.Decision)
		}

		ctx = makeCtx("Bash", map[string]interface{}{"command": "git add -- " + filePath})
		ctx.ProjectRoot = root
		if result := EvaluateRules(ctx); result.Decision != hookproto.DecisionDeny {
			t.Errorf("git add %s: expected deny, got %s", filePath, result.Decision)
		}
	}
}

func TestEnvTemplateStagingCommandForms(t *testing.T) {
	allowed := []string{
		`git add -- ".env.example"`,
		`git -C . add -- config/.env.template`,
		`git commit -- .env.sample`,
		`FOO=bar /usr/bin/git add -- .env.dist`,
	}
	for _, command := range allowed {
		if result := EvaluateRules(makeCtx("Bash", map[string]interface{}{"command": command})); result.Decision != hookproto.DecisionApprove {
			t.Errorf("%q: expected approve, got %s (%s)", command, result.Decision, result.Reason)
		}
	}

	denied := []string{
		`git add -- ".env.local"`,
		`git -C . add -- secrets/.env.example`,
		`git commit -- .env.production`,
	}
	for _, command := range denied {
		if result := EvaluateRules(makeCtx("Bash", map[string]interface{}{"command": command})); result.Decision != hookproto.DecisionDeny {
			t.Errorf("%q: expected deny, got %s", command, result.Decision)
		}
	}
}

func TestEnvTemplateStagingRespectsGitWorkingDirectory(t *testing.T) {
	root := t.TempDir()
	secretDir := filepath.Join(root, "secrets")
	if err := os.MkdirAll(filepath.Join(secretDir, "nested"), 0o700); err != nil {
		t.Fatalf("mkdir secret fixture: %v", err)
	}

	commands := []string{
		`git -C secrets add -- .env.example`,
		`git -C secrets commit -- .env.template`,
		`git -C ` + secretDir + ` add -- .env.sample`,
		`git -C secrets/nested add -- ../.env.dist`,
		`git -C secrets -C nested add -- ../.env.example`,
		`git --work-tree secrets add -- .env.example`,
		`git --work-tree=secrets add -- .env.template`,
		`git --work-tree secrets commit -- .env.sample`,
		`git -C secrets/nested --work-tree .. add -- .env.dist`,
		`GIT_WORK_TREE=secrets git add -- .env.example`,
		`env GIT_WORK_TREE=secrets git add -- .env.template`,
		`env -- GIT_WORK_TREE=secrets git commit -- .env.sample`,
		`cd secrets && git add -- .env.dist`,
		`(cd secrets; git add -- .env.example)`,
		`pushd secrets >/dev/null && git commit -- .env.template`,
		`env -C secrets git add -- .env.sample`,
		`env --chdir=secrets git commit -- .env.dist`,
		`WT=secrets git -C "$WT" add -- .env.example`,
		`WT=secrets git --work-tree "$WT" add -- .env.template`,
		`export WT=secrets; git --work-tree "$WT" commit -- .env.sample`,
		`git --work-tree "${WT:-secrets}" add -- .env.dist`,
		`git -C 'secr?ts' add -- .env.example`,
		`git --work-tree 'secr*ts' commit -- .env.template`,
		`git -C "$(printf secrets)" add -- .env.sample`,
		`git --work-tree "$(pwd)/secrets" commit -- .env.dist`,
	}
	for _, command := range commands {
		ctx := makeCtx("Bash", map[string]interface{}{"command": command})
		ctx.ProjectRoot = root
		if result := EvaluateRules(ctx); result.Decision != hookproto.DecisionDeny {
			t.Errorf("%q: expected deny, got %s (%s)", command, result.Decision, result.Reason)
		}
	}
}

func TestTemplateNamedSymlinkToSecretRemainsDenied(t *testing.T) {
	tmp := t.TempDir()
	target := filepath.Join(tmp, ".env")
	if err := os.WriteFile(target, []byte("SECRET=value\n"), 0o600); err != nil {
		t.Fatalf("write secret target: %v", err)
	}
	link := filepath.Join(tmp, ".env.example")
	if err := os.Symlink(target, link); err != nil {
		t.Fatalf("create template-named symlink: %v", err)
	}

	match := classifyProtectedPath(link)
	if match.Level != protectedPathDeny {
		t.Fatalf("template-named symlink to .env must remain denied, got level=%v reason=%q", match.Level, match.Reason)
	}
}
