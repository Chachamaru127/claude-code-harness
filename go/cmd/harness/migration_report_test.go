package main

import (
	"bytes"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestBuildExistingUserMigrationReportDetectsRisks(t *testing.T) {
	projectRoot := t.TempDir()
	home := t.TempDir()
	claudeCache := filepath.Join(home, ".claude", "plugins", "cache")
	harnessMemHome := filepath.Join(home, ".harness-mem")

	writeTestFile(t, filepath.Join(projectRoot, ".claude-plugin", "plugin.json"), `{"name":"claude-code-harness","version":"4.11.3","skills":["./skills/"]}`)

	cachedPlugin := filepath.Join(claudeCache, "claude-code-harness-old")
	writeTestFile(t, filepath.Join(cachedPlugin, "plugin.json"), `{"name":"claude-code-harness","version":"4.0.0","skills":["./skills/"]}`)
	writeSkill(t, filepath.Join(cachedPlugin, "skills", "harness-plan"), "harness-plan")

	writeTestFile(t, filepath.Join(projectRoot, ".harness-mem", "state", "continuity.json"), `{}`)
	writeTestFile(t, filepath.Join(harnessMemHome, "harness-mem.db"), ``)

	report := buildExistingUserMigrationReport(projectRoot, migrationReportEnv{
		Home:              home,
		ClaudePluginCache: claudeCache,
		HarnessMemHome:    harnessMemHome,
	})

	assertReportEntry(t, report, "Claude plugin cache", "warn", "stale plugin cache")
	assertReportEntry(t, report, "Claude slash entries", "warn", "missing harness-work")
	assertReportEntry(t, report, "harness-mem state", "observed", "harness-mem.db")
	assertReportEntry(t, report, "Destructive cleanup gate", "ok", "report never deletes")
}

func TestPrintExistingUserMigrationReportDocumentsRollbackBoundary(t *testing.T) {
	report := existingUserMigrationReport{
		ProjectRoot:        "/repo",
		DestructiveCleanup: "disabled: report only",
		Entries: []migrationReportEntry{
			{
				Area:             "harness-mem state",
				Status:           "observed",
				Path:             "/home/.harness-mem",
				Evidence:         "harness-mem.db",
				Impact:           "preserve memory",
				BackupLocation:   "/home/.harness-mem",
				RollbackProposal: "use harness mem doctor; purge only with explicit confirmation",
				SupportBoundary:  "The report does not read or delete the memory DB contents.",
			},
		},
	}

	var buf bytes.Buffer
	stdout := os.Stdout
	r, w, err := os.Pipe()
	if err != nil {
		t.Fatalf("pipe: %v", err)
	}
	os.Stdout = w
	printExistingUserMigrationReport(report)
	_ = w.Close()
	os.Stdout = stdout
	if _, err := buf.ReadFrom(r); err != nil {
		t.Fatalf("read pipe: %v", err)
	}
	out := buf.String()
	for _, want := range []string{
		"Existing User Migration Report",
		"Destructive cleanup: disabled",
		"rollback:",
		"purge only with explicit confirmation",
		"does not read or delete the memory DB contents",
	} {
		if !strings.Contains(out, want) {
			t.Fatalf("expected output to contain %q, got:\n%s", want, out)
		}
	}
}

func writeSkill(t *testing.T, dir, name string) {
	t.Helper()
	writeTestFile(t, filepath.Join(dir, "SKILL.md"), "---\nname: "+name+"\n---\n")
}

func writeTestFile(t *testing.T, path, contents string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatalf("mkdir %s: %v", filepath.Dir(path), err)
	}
	if err := os.WriteFile(path, []byte(contents), 0o644); err != nil {
		t.Fatalf("write %s: %v", path, err)
	}
}

func makeBrokenSymlink(t *testing.T, path, target string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatalf("mkdir %s: %v", filepath.Dir(path), err)
	}
	if err := os.Symlink(target, path); err != nil {
		t.Skipf("symlink unavailable: %v", err)
	}
}

func assertReportEntry(t *testing.T, report existingUserMigrationReport, area, status, evidenceContains string) {
	t.Helper()
	for _, entry := range report.Entries {
		if entry.Area != area {
			continue
		}
		if entry.Status != status {
			t.Fatalf("%s status = %q, want %q", area, entry.Status, status)
		}
		combined := strings.Join([]string{entry.Evidence, entry.Impact, entry.BackupLocation, entry.RollbackProposal, entry.SupportBoundary}, "\n")
		if !strings.Contains(combined, evidenceContains) {
			t.Fatalf("%s evidence does not contain %q:\n%s", area, evidenceContains, combined)
		}
		return
	}
	t.Fatalf("missing report entry %q", area)
}
