package session

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestCleanupHandler_NoStateDir(t *testing.T) {
	dir := t.TempDir()
	h := &CleanupHandler{StateDir: filepath.Join(dir, "nonexistent")}

	var out bytes.Buffer
	err := h.Handle(strings.NewReader(`{}`), &out)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	var resp cleanupResponse
	if json.Unmarshal(bytes.TrimRight(out.Bytes(), "\n"), &resp) != nil {
		t.Fatalf("invalid JSON: %s", out.String())
	}
	if !resp.Continue {
		t.Errorf("expected continue=true")
	}
	if !strings.Contains(resp.Message, "No state directory") {
		t.Errorf("expected 'No state directory', got %q", resp.Message)
	}
}

func TestCleanupHandler_DeletesTempFiles(t *testing.T) {
	dir := t.TempDir()
	stateDir := filepath.Join(dir, "state")
	if err := os.MkdirAll(stateDir, 0700); err != nil {
		t.Fatal(err)
	}

	// Create temporary files
	tempFiles := []string{
		"pending-skill.json",
		"current-operation.json",
		"inbox-abc123.tmp",
		"inbox-def456.tmp",
	}
	for _, name := range tempFiles {
		if err := os.WriteFile(filepath.Join(stateDir, name), []byte("{}"), 0600); err != nil {
			t.Fatal(err)
		}
	}

	// Also create a file that should not be deleted
	keepFile := filepath.Join(stateDir, "session.json")
	if err := os.WriteFile(keepFile, []byte("{}"), 0600); err != nil {
		t.Fatal(err)
	}

	h := &CleanupHandler{StateDir: stateDir}
	var out bytes.Buffer
	err := h.Handle(strings.NewReader(`{}`), &out)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	var resp cleanupResponse
	if json.Unmarshal(bytes.TrimRight(out.Bytes(), "\n"), &resp) != nil {
		t.Fatalf("invalid JSON: %s", out.String())
	}
	if !resp.Continue {
		t.Errorf("expected continue=true")
	}

	// Verify that temporary files were deleted
	for _, name := range tempFiles {
		if _, err := os.Stat(filepath.Join(stateDir, name)); err == nil {
			t.Errorf("expected %s to be deleted", name)
		}
	}

	// Verify that session.json was preserved
	if _, err := os.Stat(keepFile); err != nil {
		t.Errorf("session.json should not be deleted: %v", err)
	}
}

func TestCleanupHandler_SymlinkStateDir(t *testing.T) {
	dir := t.TempDir()
	realDir := filepath.Join(dir, "real-state")
	if err := os.MkdirAll(realDir, 0700); err != nil {
		t.Fatal(err)
	}
	linkDir := filepath.Join(dir, "link-state")
	if err := os.Symlink(realDir, linkDir); err != nil {
		t.Skip("symlink creation not supported")
	}

	h := &CleanupHandler{StateDir: linkDir}
	var out bytes.Buffer
	err := h.Handle(strings.NewReader(`{}`), &out)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	var resp cleanupResponse
	if json.Unmarshal(bytes.TrimRight(out.Bytes(), "\n"), &resp) != nil {
		t.Fatalf("invalid JSON: %s", out.String())
	}
	if !resp.Continue {
		t.Errorf("expected continue=true")
	}
	if !strings.Contains(resp.Message, "symlink") {
		t.Errorf("expected symlink message, got %q", resp.Message)
	}
}

func TestCleanupHandler_InboxGlobPattern(t *testing.T) {
	dir := t.TempDir()
	stateDir := filepath.Join(dir, "state")
	if err := os.MkdirAll(stateDir, 0700); err != nil {
		t.Fatal(err)
	}

	// Create only inbox-*.tmp pattern files
	tmpFiles := []string{"inbox-1.tmp", "inbox-2.tmp", "inbox-3.tmp"}
	for _, name := range tmpFiles {
		if err := os.WriteFile(filepath.Join(stateDir, name), []byte("data"), 0600); err != nil {
			t.Fatal(err)
		}
	}
	// File that does not match inbox-*.tmp (should not be deleted)
	otherFile := filepath.Join(stateDir, "inbox-data.json")
	if err := os.WriteFile(otherFile, []byte("{}"), 0600); err != nil {
		t.Fatal(err)
	}

	h := &CleanupHandler{StateDir: stateDir}
	var out bytes.Buffer
	if err := h.Handle(strings.NewReader(`{}`), &out); err != nil {
		t.Fatal(err)
	}

	for _, name := range tmpFiles {
		if _, err := os.Stat(filepath.Join(stateDir, name)); err == nil {
			t.Errorf("expected %s to be deleted", name)
		}
	}
	if _, err := os.Stat(otherFile); err != nil {
		t.Errorf("inbox-data.json should not be deleted")
	}
}

func TestCleanupHandler_EmptyInput(t *testing.T) {
	dir := t.TempDir()
	h := &CleanupHandler{StateDir: filepath.Join(dir, "state")}

	var out bytes.Buffer
	err := h.Handle(strings.NewReader(""), &out)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	var resp cleanupResponse
	if json.Unmarshal(bytes.TrimRight(out.Bytes(), "\n"), &resp) != nil {
		t.Fatalf("invalid JSON: %s", out.String())
	}
	if !resp.Continue {
		t.Errorf("expected continue=true")
	}
}
