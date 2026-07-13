package projectconfig

import (
	"os"
	"path/filepath"
	"testing"
)

func writeConfig(t *testing.T, dir, name, body string) {
	t.Helper()
	if err := os.WriteFile(filepath.Join(dir, name), []byte(body), 0o600); err != nil {
		t.Fatalf("write config: %v", err)
	}
}

func TestResolvePrefersDottedName(t *testing.T) {
	dir := t.TempDir()
	writeConfig(t, dir, ".claude-code-harness.config.json", `{"version":"1.0"}`)
	writeConfig(t, dir, "claude-code-harness.config.json", `{"version":"2.0"}`)

	root, path, found := Resolve(dir)
	if !found {
		t.Fatal("expected config to be found")
	}
	if root != mustAbs(t, dir) {
		t.Errorf("root = %q, want %q", root, mustAbs(t, dir))
	}
	if filepath.Base(path) != ".claude-code-harness.config.json" {
		t.Errorf("expected dotted filename to win, got %q", path)
	}
}

func TestResolveAcceptsNonDottedName(t *testing.T) {
	dir := t.TempDir()
	writeConfig(t, dir, "claude-code-harness.config.json", `{"version":"1.0"}`)

	_, path, found := Resolve(dir)
	if !found {
		t.Fatal("expected non-dotted config to be found")
	}
	if filepath.Base(path) != "claude-code-harness.config.json" {
		t.Errorf("got %q", path)
	}
}

func TestResolveWalksUp(t *testing.T) {
	root := t.TempDir()
	writeConfig(t, root, ".claude-code-harness.config.json", `{"version":"1.0"}`)
	nested := filepath.Join(root, "a", "b", "c")
	if err := os.MkdirAll(nested, 0o755); err != nil {
		t.Fatal(err)
	}
	got, _, found := Resolve(nested)
	if !found {
		t.Fatal("expected walk-up to find config")
	}
	if got != mustAbs(t, root) {
		t.Errorf("root = %q, want %q", got, mustAbs(t, root))
	}
}

func TestLoadMissingIsNotError(t *testing.T) {
	dir := t.TempDir()
	res := Load(dir)
	if res.Found {
		t.Fatal("expected Found=false")
	}
	if res.ParseErr != nil {
		t.Errorf("missing file should not set ParseErr, got %v", res.ParseErr)
	}
	if res.Config != nil {
		t.Error("expected nil Config")
	}
	if got := res.ProtectedPaths(); got != nil {
		t.Errorf("ProtectedPaths on empty result = %v, want nil", got)
	}
}

func TestLoadMalformedSetsParseErr(t *testing.T) {
	dir := t.TempDir()
	writeConfig(t, dir, ".claude-code-harness.config.json", `{ this is : not json `)
	res := Load(dir)
	if !res.Found {
		t.Fatal("expected Found=true for present file")
	}
	if res.ParseErr == nil {
		t.Fatal("expected ParseErr for malformed json")
	}
	if res.Config != nil {
		t.Error("expected nil Config on parse error (fail closed)")
	}
}

func TestLoadFullConfig(t *testing.T) {
	dir := t.TempDir()
	body := `{
		"version": "1.0",
		"safety": {"mode": "dry-run", "require_confirmation": true, "max_auto_retries": 2},
		"git": {"allow_auto_commit": false, "protected_branches": ["main", "production", " release ", ""]},
		"paths": {"protected": [".github/", "infra/", "src/generated", "", "/etc/passwd", "../escape"]},
		"work": {"auto_commit": true, "commit_on_pm_approve": false},
		"runtimefloor": {"secretAllow": [".env.local"]}
	}`
	writeConfig(t, dir, ".claude-code-harness.config.json", body)

	res := Load(dir)
	if res.ParseErr != nil {
		t.Fatalf("unexpected parse error: %v", res.ParseErr)
	}
	if res.Config == nil {
		t.Fatal("expected non-nil config")
	}
	if res.Config.Safety.Mode != "dry-run" {
		t.Errorf("safety.mode = %q", res.Config.Safety.Mode)
	}
	if res.Config.Safety.MaxAutoRetries == nil || *res.Config.Safety.MaxAutoRetries != 2 {
		t.Errorf("safety.max_auto_retries not parsed")
	}

	gotBranches := res.ProtectedBranches()
	wantBranches := []string{"main", "production", "release"}
	if !equalStrings(gotBranches, wantBranches) {
		t.Errorf("ProtectedBranches = %v, want %v", gotBranches, wantBranches)
	}

	gotPaths := res.ProtectedPaths()
	wantPaths := []string{".github/", "infra/", "src/generated"}
	if !equalStrings(gotPaths, wantPaths) {
		t.Errorf("ProtectedPaths = %v, want %v", gotPaths, wantPaths)
	}
}

func TestProtectedPathsDedupAndNormalize(t *testing.T) {
	dir := t.TempDir()
	body := `{"paths": {"protected": ["src/", "src/", "./lib", "a/b/../c"]}}`
	writeConfig(t, dir, ".claude-code-harness.config.json", body)
	res := Load(dir)
	got := res.ProtectedPaths()
	want := []string{"src/", "lib", "a/c"}
	if !equalStrings(got, want) {
		t.Errorf("ProtectedPaths = %v, want %v", got, want)
	}
}

func mustAbs(t *testing.T, p string) string {
	t.Helper()
	// Mirror Resolve's behaviour: filepath.Abs without symlink resolution so
	// macOS /var -> /private/var symlinks do not cause spurious mismatches.
	abs, err := filepath.Abs(p)
	if err != nil {
		t.Fatal(err)
	}
	return abs
}

func equalStrings(a, b []string) bool {
	if len(a) != len(b) {
		return false
	}
	for i := range a {
		if a[i] != b[i] {
			return false
		}
	}
	return true
}
