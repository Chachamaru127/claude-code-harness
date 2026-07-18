package main

import (
	"bytes"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"
	"testing"
	"time"

	"github.com/Chachamaru127/claude-code-harness/go/internal/gitport"
)

func initFixtureRepo(t *testing.T, changelog string) string {
	t.Helper()
	dir := t.TempDir()
	if err := gitport.Run(dir, "init"); err != nil {
		t.Fatalf("git init: %v", err)
	}
	if err := os.WriteFile(filepath.Join(dir, "CHANGELOG.md"), []byte(changelog), 0o644); err != nil {
		t.Fatalf("write CHANGELOG.md: %v", err)
	}
	if err := gitport.Run(dir, "add", "CHANGELOG.md"); err != nil {
		t.Fatalf("git add: %v", err)
	}
	if err := gitport.Run(dir, "-c", "user.email=test@example.com", "-c", "user.name=Test", "commit", "-m", "init"); err != nil {
		t.Fatalf("git commit: %v", err)
	}
	if err := gitport.Run(dir, "tag", "v1.0.0"); err != nil {
		t.Fatalf("git tag: %v", err)
	}
	return dir
}

type fileSnapshot struct {
	path    string
	content []byte
	modTime time.Time
}

func snapshotDir(t *testing.T, root string) []fileSnapshot {
	t.Helper()
	var snaps []fileSnapshot
	err := filepath.Walk(root, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if info.IsDir() {
			if info.Name() == ".git" {
				return filepath.SkipDir
			}
			return nil
		}
		data, readErr := os.ReadFile(path)
		if readErr != nil {
			return readErr
		}
		snaps = append(snaps, fileSnapshot{path: path, content: data, modTime: info.ModTime()})
		return nil
	})
	if err != nil {
		t.Fatalf("snapshotDir: %v", err)
	}
	return snaps
}

func assertSnapshotsUnchanged(t *testing.T, before, after []fileSnapshot) {
	t.Helper()
	afterByPath := make(map[string]fileSnapshot, len(after))
	for _, s := range after {
		afterByPath[s.path] = s
	}
	for _, b := range before {
		a, ok := afterByPath[b.path]
		if !ok {
			t.Fatalf("file missing after check: %s", b.path)
		}
		if !bytes.Equal(b.content, a.content) {
			t.Fatalf("file content changed: %s", b.path)
		}
		if !b.modTime.Equal(a.modTime) {
			t.Fatalf("mtime changed: %s (before %v, after %v)", b.path, b.modTime, a.modTime)
		}
	}
}

func TestReleaseCheck_ReadOnly(t *testing.T) {
	changelog := `# Changelog

## [Unreleased]

### Added
- Release train check
`
	root := initFixtureRepo(t, changelog)

	tagDateOut, err := gitport.Output(root, "log", "-1", "--format=%cI", "v1.0.0")
	if err != nil {
		t.Fatalf("git log tag date: %v", err)
	}
	tagDate, err := time.Parse(time.RFC3339, strings.TrimSpace(tagDateOut))
	if err != nil {
		t.Fatalf("parse tag date: %v", err)
	}
	now := tagDate.Add(8 * 24 * time.Hour)

	before := snapshotDir(t, root)

	var buf bytes.Buffer
	if err := releaseCheck(root, now, &buf); err != nil {
		t.Fatalf("releaseCheck: %v", err)
	}

	after := snapshotDir(t, root)
	assertSnapshotsUnchanged(t, before, after)

	status, err := gitport.Output(root, "status", "--porcelain")
	if err != nil {
		t.Fatalf("git status: %v", err)
	}
	if strings.TrimSpace(status) != "" {
		t.Fatalf("git status not clean after check:\n%s", status)
	}
}

func TestReleaseCheck_OutputFormat(t *testing.T) {
	candidateChangelog := `# Changelog

## [Unreleased]

### Added
- New feature
`
	root := initFixtureRepo(t, candidateChangelog)

	tagDateOut, err := gitport.Output(root, "log", "-1", "--format=%cI", "v1.0.0")
	if err != nil {
		t.Fatalf("git log tag date: %v", err)
	}
	tagDate, err := time.Parse(time.RFC3339, strings.TrimSpace(tagDateOut))
	if err != nil {
		t.Fatalf("parse tag date: %v", err)
	}
	now := tagDate.Add(8 * 24 * time.Hour)

	t.Run("candidate prints RELEASE_CANDIDATE line", func(t *testing.T) {
		var buf bytes.Buffer
		if err := releaseCheck(root, now, &buf); err != nil {
			t.Fatalf("releaseCheck: %v", err)
		}
		line := strings.TrimSpace(buf.String())
		re := regexp.MustCompile(`^RELEASE_CANDIDATE: bump=minor `)
		if !re.MatchString(line) {
			t.Fatalf("stdout = %q, want prefix RELEASE_CANDIDATE: bump=minor", line)
		}
		if !strings.Contains(line, "tag=v1.0.0") {
			t.Fatalf("stdout missing tag=v1.0.0: %q", line)
		}
	})

	t.Run("none prints empty stdout", func(t *testing.T) {
		noneChangelog := `# Changelog

## [Unreleased]

### Fixed
- Tiny fix
`
		noneRoot := initFixtureRepo(t, noneChangelog)
		noneTagDateOut, err := gitport.Output(noneRoot, "log", "-1", "--format=%cI", "v1.0.0")
		if err != nil {
			t.Fatalf("git log tag date: %v", err)
		}
		noneTagDate, err := time.Parse(time.RFC3339, strings.TrimSpace(noneTagDateOut))
		if err != nil {
			t.Fatalf("parse tag date: %v", err)
		}
		noneNow := noneTagDate.Add(1 * 24 * time.Hour)
		var buf bytes.Buffer
		if err := releaseCheck(noneRoot, noneNow, &buf); err != nil {
			t.Fatalf("releaseCheck: %v", err)
		}
		if strings.TrimSpace(buf.String()) != "" {
			t.Fatalf("stdout = %q, want empty", buf.String())
		}
	})
}

// Ensure exec.Command is not used directly in release_check.go (guard via compile-time
// dependency on gitport only). This test documents the seam contract.
func TestReleaseCheck_UsesGitportNotExec(t *testing.T) {
	data, err := os.ReadFile("release_check.go")
	if err != nil {
		// File does not exist yet in RED commit — expected.
		if os.IsNotExist(err) {
			t.Skip("release_check.go not yet implemented")
		}
		t.Fatal(err)
	}
	if strings.Contains(string(data), "exec.Command") {
		t.Fatal("release_check.go must use gitport, not exec.Command")
	}
	_ = exec.Command // keep import if file exists
}
