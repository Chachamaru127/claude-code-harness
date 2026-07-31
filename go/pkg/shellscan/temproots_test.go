package shellscan

import (
	"os"
	"path/filepath"
	"testing"
)

func TestIsAllowlistedTempPath(t *testing.T) {
	t.Setenv("TMPDIR", "/opt/harness-custom-tmp")
	t.Setenv("HOME", "/home/harness-test-user")

	allowed := []string{
		"/tmp/draft.md",
		"/var/tmp/build/output.txt",
		"/private/tmp/prompt.md",
		"/private/var/tmp/cache/result.json",
		"/opt/harness-custom-tmp/report.md",
		"/home/harness-test-user/.cache/tool/result.json",
		"/home/harness-test-user/Library/Caches/tool/result.json",
	}
	for _, path := range allowed {
		t.Run(path, func(t *testing.T) {
			if !IsAllowlistedTempPath(filepath.Clean(path)) {
				t.Errorf("expected %q to be under an allowlisted temporary root", path)
			}
		})
	}
}

func TestIsAllowlistedTempPathRejectsPrefixCollision(t *testing.T) {
	t.Setenv("TMPDIR", "/opt/harness-custom-tmp")
	t.Setenv("HOME", "/home/harness-test-user")

	rejected := []string{
		"/tmp-backup/draft.md",
		"/opt/harness-custom-tmp-backup/report.md",
		"/home/harness-test-user/.cache-backup/result.json",
		"/home/harness-test-user/Documents/important.md",
	}
	for _, path := range rejected {
		t.Run(path, func(t *testing.T) {
			if IsAllowlistedTempPath(filepath.Clean(path)) {
				t.Errorf("expected %q to remain outside allowlisted temporary roots", path)
			}
		})
	}
}

func TestIsAllowlistedTempPathSymlinkedTMPDIR(t *testing.T) {
	physicalRoot := t.TempDir()
	resolvedRoot, err := filepath.EvalSymlinks(physicalRoot)
	if err != nil {
		t.Fatal(err)
	}
	linkParent := t.TempDir()
	linkedRoot := filepath.Join(linkParent, "tmpdir")
	if err := os.Symlink(physicalRoot, linkedRoot); err != nil {
		t.Skipf("symlinks unavailable: %v", err)
	}
	t.Setenv("TMPDIR", linkedRoot)
	t.Setenv("HOME", filepath.Join(t.TempDir(), "missing-home"))

	tests := []struct {
		name string
		path string
	}{
		{
			name: "symlink path",
			path: filepath.Join(linkedRoot, "probe.txt"),
		},
		{
			name: "resolved path",
			path: filepath.Join(resolvedRoot, "probe.txt"),
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if !IsAllowlistedTempPath(tt.path) {
				t.Errorf("expected %q to be under symlinked TMPDIR %q", tt.path, linkedRoot)
			}
		})
	}
}

func TestIsAllowlistedTempPathRetainsNonexistentRoots(t *testing.T) {
	base := t.TempDir()
	missingTMPDIR := filepath.Join(base, "missing-tmpdir")
	t.Setenv("TMPDIR", missingTMPDIR)
	t.Setenv("HOME", filepath.Join(base, "missing-home"))

	tests := []struct {
		name string
		path string
	}{
		{
			name: "nonexistent TMPDIR remains allowlisted",
			path: filepath.Join(missingTMPDIR, "probe.txt"),
		},
		{
			name: "other root remains allowlisted",
			path: filepath.Join("/tmp", "probe.txt"),
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if !IsAllowlistedTempPath(tt.path) {
				t.Errorf("expected %q to remain under an allowlisted temporary root", tt.path)
			}
		})
	}
}
