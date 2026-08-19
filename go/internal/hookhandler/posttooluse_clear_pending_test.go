package hookhandler

import (
	"bytes"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestClearPendingHandler_NoPendingDir(t *testing.T) {
	dir := t.TempDir()

	h := &ClearPendingHandler{ProjectRoot: dir}

	var out bytes.Buffer
	err := h.Handle(strings.NewReader(`{}`), &out)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if out.Len() != 0 {
		t.Errorf("expected no success output, got: %s", out.String())
	}
}

func TestClearPendingHandler_DeletesPendingFiles(t *testing.T) {
	dir := t.TempDir()

	pendingDir := filepath.Join(dir, ".claude", "state", "pending-skills")
	if err := os.MkdirAll(pendingDir, 0700); err != nil {
		t.Fatal(err)
	}

	// .pending ファイルを作成
	pendingFiles := []string{"skill-a.pending", "skill-b.pending", "skill-c.pending"}
	for _, name := range pendingFiles {
		if err := os.WriteFile(filepath.Join(pendingDir, name), []byte("pending"), 0600); err != nil {
			t.Fatal(err)
		}
	}

	// .pending 以外のファイル（削除しないはず）
	otherFile := filepath.Join(pendingDir, "skill-a.json")
	if err := os.WriteFile(otherFile, []byte(`{}`), 0600); err != nil {
		t.Fatal(err)
	}

	h := &ClearPendingHandler{ProjectRoot: dir}

	var out bytes.Buffer
	err := h.Handle(strings.NewReader(`{}`), &out)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if out.Len() != 0 {
		t.Errorf("expected no success output, got: %s", out.String())
	}

	// .pending ファイルが削除されているか確認
	for _, name := range pendingFiles {
		if _, err := os.Stat(filepath.Join(pendingDir, name)); err == nil {
			t.Errorf("expected %s to be deleted", name)
		}
	}

	// .json ファイルは保持されているか確認
	if _, err := os.Stat(otherFile); err != nil {
		t.Errorf("skill-a.json should not be deleted")
	}
}

func TestClearPendingHandler_EmptyPendingDir(t *testing.T) {
	dir := t.TempDir()

	pendingDir := filepath.Join(dir, ".claude", "state", "pending-skills")
	if err := os.MkdirAll(pendingDir, 0700); err != nil {
		t.Fatal(err)
	}
	// 空ディレクトリ（.pending ファイルなし）

	h := &ClearPendingHandler{ProjectRoot: dir}

	var out bytes.Buffer
	err := h.Handle(strings.NewReader(`{}`), &out)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if out.Len() != 0 {
		t.Errorf("expected no success output, got: %s", out.String())
	}
}

func TestClearPendingHandler_EmptyInput(t *testing.T) {
	dir := t.TempDir()

	h := &ClearPendingHandler{ProjectRoot: dir}

	var out bytes.Buffer
	// 空の stdin でもエラーにならないこと
	err := h.Handle(strings.NewReader(""), &out)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if out.Len() != 0 {
		t.Errorf("expected no empty-input output, got: %s", out.String())
	}
}

func TestClearPendingHandler_MultipleRuns(t *testing.T) {
	dir := t.TempDir()

	pendingDir := filepath.Join(dir, ".claude", "state", "pending-skills")
	if err := os.MkdirAll(pendingDir, 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(pendingDir, "skill-x.pending"), []byte(""), 0600); err != nil {
		t.Fatal(err)
	}

	h := &ClearPendingHandler{ProjectRoot: dir}

	// 1 回目: ファイルを削除
	var out1 bytes.Buffer
	if err := h.Handle(strings.NewReader(`{}`), &out1); err != nil {
		t.Fatal(err)
	}

	// 2 回目: 既に削除済み → エラーにならないこと
	var out2 bytes.Buffer
	if err := h.Handle(strings.NewReader(`{}`), &out2); err != nil {
		t.Fatalf("second run should not error: %v", err)
	}

	if out2.Len() != 0 {
		t.Errorf("expected no second-run output, got: %s", out2.String())
	}
}
