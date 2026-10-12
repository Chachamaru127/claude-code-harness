package session

import (
	"os"
	"path/filepath"
	"testing"
)

func TestResolveHarnessBinary_SkipsTestExecutable(t *testing.T) {
	root := t.TempDir()
	binDir := filepath.Join(root, "bin")
	if err := os.MkdirAll(binDir, 0700); err != nil {
		t.Fatal(err)
	}
	want := filepath.Join(binDir, "harness")
	if err := os.WriteFile(want, []byte("#!/bin/sh\nexit 0\n"), 0700); err != nil {
		t.Fatal(err)
	}
	t.Setenv("CLAUDE_PLUGIN_ROOT", root)
	got, err := resolveHarnessBinary()
	if err != nil || got != want {
		t.Fatalf("resolveHarnessBinary() = %q, %v; want installed binary %q", got, err, want)
	}
}
