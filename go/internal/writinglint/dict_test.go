package writinglint

import (
	"os"
	"path/filepath"
	"testing"
)

func TestLoadDict_ParsesFixtureAndSkipsCommentsAndBlanks(t *testing.T) {
	rules, err := LoadDict("testdata/rules.jsonl")
	if err != nil {
		t.Fatalf("LoadDict: %v", err)
	}
	if len(rules) != 4 {
		t.Fatalf("len(rules) = %d, want 4 (comment/blank lines must be skipped)", len(rules))
	}
	if rules[0].ID != "meta-narration" || !rules[0].Enabled {
		t.Fatalf("rules[0] = %+v, want id=meta-narration enabled=true", rules[0])
	}
	if len(rules[0].Scenes) != 1 || rules[0].Scenes[0] != "external" {
		t.Fatalf("rules[0].Scenes = %v, want [external]", rules[0].Scenes)
	}
}

func TestLoadDict_MissingFileErrors(t *testing.T) {
	if _, err := LoadDict(filepath.Join(t.TempDir(), "nope.jsonl")); err == nil {
		t.Fatal("expected error for missing dict file")
	}
}

func TestLoadDict_MalformedLineErrors(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "bad.jsonl")
	if err := os.WriteFile(path, []byte("{\"id\": \"x\", \"pattern\": \"a\", \"good\": \"b\", \"enabled\": true, \"unknown_field\": 1}\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if _, err := LoadDict(path); err == nil {
		t.Fatal("expected error for unknown field (DisallowUnknownFields)")
	}
}

func TestResolveDictPath_ConfigBeatsEnvBeatsDefault(t *testing.T) {
	t.Run("config wins", func(t *testing.T) {
		repoRoot := t.TempDir()
		cfg := "writing_lint:\n  enabled: true\n  dict_path: custom/rules.jsonl\n"
		if err := os.WriteFile(filepath.Join(repoRoot, ".claude-code-harness.config.yaml"), []byte(cfg), 0o644); err != nil {
			t.Fatal(err)
		}
		t.Setenv(EnvDictPath, filepath.Join(t.TempDir(), "env-rules.jsonl"))
		got := ResolveDictPath(repoRoot)
		want := filepath.Join(repoRoot, "custom/rules.jsonl")
		if got != want {
			t.Fatalf("ResolveDictPath = %q, want %q", got, want)
		}
	})

	t.Run("env wins over default", func(t *testing.T) {
		repoRoot := t.TempDir() // no config file present
		envPath := filepath.Join(t.TempDir(), "env-rules.jsonl")
		t.Setenv(EnvDictPath, envPath)
		got := ResolveDictPath(repoRoot)
		if got != envPath {
			t.Fatalf("ResolveDictPath = %q, want %q", got, envPath)
		}
	})

	t.Run("falls back to home default", func(t *testing.T) {
		repoRoot := t.TempDir()
		t.Setenv(EnvDictPath, "")
		home := t.TempDir()
		t.Setenv("HOME", home)
		got := ResolveDictPath(repoRoot)
		want := filepath.Join(home, ".claude", "writing-lint", "rules.jsonl")
		if got != want {
			t.Fatalf("ResolveDictPath = %q, want %q", got, want)
		}
	})
}
