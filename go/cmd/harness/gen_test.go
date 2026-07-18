package main

import (
	"bytes"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/Chachamaru127/claude-code-harness/go/internal/docsgen"
)

// repoRootForTest walks up from the test's working directory (go/cmd/harness)
// to locate the directory containing hosts.toml.
func repoRootForTest(t *testing.T) string {
	t.Helper()
	dir, err := os.Getwd()
	if err != nil {
		t.Fatalf("getwd: %v", err)
	}
	for {
		if _, statErr := os.Stat(filepath.Join(dir, hostsDescriptorName)); statErr == nil {
			return dir
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			t.Fatal("could not locate hosts.toml above test working directory")
		}
		dir = parent
	}
}

func TestGeneratedHooks_ContainsCodexAndCursor(t *testing.T) {
	root := repoRootForTest(t)
	gen, err := generatedHooks(root)
	if err != nil {
		t.Fatalf("generatedHooks: %v", err)
	}
	for _, name := range []string{"codex", "cursor", "claude"} {
		if len(gen[name]) == 0 {
			t.Errorf("generatedHooks missing output for %s", name)
		}
	}
	if _, generated := gen["grok"]; generated {
		t.Error("Grok native hook config must remain deferred until live schema admission")
	}
	for _, name := range []string{"codex", "cursor"} {
		if !strings.Contains(string(gen[name]), "hook pre-tool") {
			t.Errorf("%s generated hooks.json does not invoke 'hook pre-tool':\n%s", name, gen[name])
		}
		if !strings.Contains(string(gen[name]), "inbox check") {
			t.Errorf("%s generated hooks.json does not invoke delivery inbox-check:\n%s", name, gen[name])
		}
	}
	if !strings.Contains(string(gen["codex"]), "\"Stop\"") {
		t.Errorf("codex generated hooks.json missing Stop delivery event:\n%s", gen["codex"])
	}
	if !strings.Contains(string(gen["cursor"]), "\"stop\"") {
		t.Errorf("cursor generated hooks.json missing stop delivery event:\n%s", gen["cursor"])
	}
}

func TestRunGenWrite_SkipsDeferredHosts(t *testing.T) {
	root := t.TempDir()
	hosts, err := os.ReadFile(filepath.Join(repoRootForTest(t), hostsDescriptorName))
	if err != nil {
		t.Fatalf("read %s: %v", hostsDescriptorName, err)
	}
	if err := os.WriteFile(filepath.Join(root, hostsDescriptorName), hosts, 0o644); err != nil {
		t.Fatalf("write %s: %v", hostsDescriptorName, err)
	}

	if err := runGenWrite(root); err != nil {
		t.Fatalf("runGenWrite must skip hosts with deferred hook generation: %v", err)
	}
	for _, path := range []string{".codex/hooks.json", ".cursor/hooks.json"} {
		if _, err := os.Stat(filepath.Join(root, path)); err != nil {
			t.Errorf("generated hook file %s: %v", path, err)
		}
	}
	if _, err := os.Stat(filepath.Join(root, ".grok/hooks.json")); !os.IsNotExist(err) {
		t.Errorf("deferred Grok hook file must not be generated, stat error = %v", err)
	}
}

// TestGeneratedHooks_MatchesGoldenFixtures is the in-process equivalent of
// `harness gen --check`: it guarantees the committed golden fixtures stay
// byte-for-byte in sync with the generator. If this fails, regenerate the
// fixtures from `harness gen` output.
func TestGeneratedHooks_MatchesGoldenFixtures(t *testing.T) {
	root := repoRootForTest(t)
	gen, err := generatedHooks(root)
	if err != nil {
		t.Fatalf("generatedHooks: %v", err)
	}
	fixtureDir := filepath.Join(root, "go", "cmd", "harness", "testdata", "gen")
	for _, name := range []string{"codex", "cursor"} {
		want, readErr := os.ReadFile(filepath.Join(fixtureDir, name+"-hooks.json"))
		if readErr != nil {
			t.Fatalf("read golden fixture %s: %v", name, readErr)
		}
		if !bytes.Equal(want, gen[name]) {
			t.Errorf("%s drifted from golden fixture.\n--- golden ---\n%s\n--- generated ---\n%s",
				name, want, gen[name])
		}
	}
}

// TestGenDocs_CatalogMatchesSkills is the in-process equivalent of
// `harness gen docs --check`: it guarantees the committed
// docs/CLAUDE-skill-catalog.md managed region stays in sync with the actual
// skills/*/SKILL.md frontmatter. If this fails, run `harness gen docs`.
func TestGenDocs_CatalogMatchesSkills(t *testing.T) {
	root := repoRootForTest(t)
	inSync, diff, err := docsgen.Check(root)
	if err != nil {
		t.Fatalf("docsgen.Check: %v", err)
	}
	if !inSync {
		t.Errorf("docs/CLAUDE-skill-catalog.md drifted from skills/*/SKILL.md (run `harness gen docs`):\n%s", diff)
	}
}

func TestUnifiedDiff_ReportsChangedLines(t *testing.T) {
	out := unifiedDiff("a\nb\nc\n", "a\nB\nc\n")
	if !strings.Contains(out, "- b") || !strings.Contains(out, "+ B") {
		t.Errorf("unifiedDiff did not flag the changed line: %q", out)
	}
	if same := unifiedDiff("x\ny\n", "x\ny\n"); same != "" {
		t.Errorf("unifiedDiff of identical input should be empty, got %q", same)
	}
}

func TestResolveGenRoot_ExplicitArg(t *testing.T) {
	dir := t.TempDir()
	got, err := resolveGenRoot([]string{dir})
	if err != nil {
		t.Fatalf("resolveGenRoot: %v", err)
	}
	// On macOS t.TempDir() may be under /var -> /private/var symlink; compare
	// via EvalSymlinks so the assertion is path-canonical.
	wantEval, _ := filepath.EvalSymlinks(dir)
	gotEval, _ := filepath.EvalSymlinks(got)
	if gotEval != wantEval {
		t.Errorf("resolveGenRoot(%q) = %q, want %q", dir, gotEval, wantEval)
	}
}

func TestResolveGenRoot_WalksUpToHostsToml(t *testing.T) {
	root := repoRootForTest(t)
	got, err := resolveGenRoot(nil)
	if err != nil {
		t.Fatalf("resolveGenRoot: %v", err)
	}
	if got != root {
		t.Errorf("resolveGenRoot(nil) = %q, want repo root %q", got, root)
	}
}
