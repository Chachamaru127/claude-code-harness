package hookhandler

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/Chachamaru127/claude-code-harness/go/internal/gitport"
	"github.com/Chachamaru127/claude-code-harness/go/internal/writinglint"
)

func writeWritingLintDictFixture(t *testing.T, dir string) string {
	t.Helper()
	path := filepath.Join(dir, "rules.jsonl")
	content := `{"id": "meta-narration", "pattern": "以下に示します", "good": "結論から直接書く", "enabled": true, "severity": "warning"}
`
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}
	return path
}

func TestHandlePostToolUseWritingLint_EmptyInput(t *testing.T) {
	var out bytes.Buffer
	if err := HandlePostToolUseWritingLint(strings.NewReader(""), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if out.Len() != 0 {
		t.Errorf("expected no output for empty input, got %q", out.String())
	}
}

func TestHandlePostToolUseWritingLint_NonWriteEdit(t *testing.T) {
	input := `{"tool_name":"Read","tool_input":{"file_path":"README.md"},"cwd":"/tmp"}`
	var out bytes.Buffer
	if err := HandlePostToolUseWritingLint(strings.NewReader(input), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if out.Len() != 0 {
		t.Errorf("expected no output for non-Write/Edit tool, got %q", out.String())
	}
}

// (b) .go/.ts ファイルはスキップ
func TestHandlePostToolUseWritingLint_NonMDTxtFileSkipped(t *testing.T) {
	tmpDir := t.TempDir()
	origDir, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	if err := os.Chdir(tmpDir); err != nil {
		t.Fatal(err)
	}
	defer os.Chdir(origDir)

	config := "writing_lint:\n  enabled: true\n"
	if err := os.WriteFile(".claude-code-harness.config.yaml", []byte(config), 0o644); err != nil {
		t.Fatal(err)
	}

	for _, path := range []string{"src/main.go", "src/app.ts"} {
		input := `{"tool_name":"Write","tool_input":{"file_path":"` + path + `"}}`
		var out bytes.Buffer
		if err := HandlePostToolUseWritingLint(strings.NewReader(input), &out); err != nil {
			t.Fatalf("unexpected error: %v", err)
		}
		if out.Len() != 0 {
			t.Errorf("expected no output for %s, got %q", path, out.String())
		}
	}
}

func TestHandlePostToolUseWritingLint_ExcludedPath(t *testing.T) {
	tmpDir := t.TempDir()
	origDir, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	if err := os.Chdir(tmpDir); err != nil {
		t.Fatal(err)
	}
	defer os.Chdir(origDir)

	config := "writing_lint:\n  enabled: true\n"
	if err := os.WriteFile(".claude-code-harness.config.yaml", []byte(config), 0o644); err != nil {
		t.Fatal(err)
	}

	input := `{"tool_name":"Write","tool_input":{"file_path":"node_modules/pkg/README.md"}}`
	var out bytes.Buffer
	if err := HandlePostToolUseWritingLint(strings.NewReader(input), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if out.Len() != 0 {
		t.Errorf("expected no output for excluded path, got %q", out.String())
	}
}

// docs/ は専用除外リストの対象外（quality_pack と異なり対象に含める）ことの確認。
func TestIsWritingLintExcludedPath_DocsIncluded(t *testing.T) {
	if isWritingLintExcludedPath("docs/guide.md") {
		t.Error("docs/ must not be excluded for writing-lint")
	}
	if !isWritingLintExcludedPath(".claude/state/x.md") {
		t.Error(".claude/ must be excluded")
	}
	if !isWritingLintExcludedPath("node_modules/pkg/README.md") {
		t.Error("node_modules/ must be excluded")
	}
	if !isWritingLintExcludedPath(".git/COMMIT_EDITMSG.md") {
		t.Error(".git/ must be excluded")
	}
}

// (c) enabled:false（既定）でスキップ
func TestHandlePostToolUseWritingLint_DisabledByDefault(t *testing.T) {
	tmpDir := t.TempDir()
	origDir, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	if err := os.Chdir(tmpDir); err != nil {
		t.Fatal(err)
	}
	defer os.Chdir(origDir)

	dictPath := writeWritingLintDictFixture(t, tmpDir)
	t.Setenv(writinglint.EnvDictPath, dictPath)

	mdFile := filepath.Join(tmpDir, "notes.md")
	if err := os.WriteFile(mdFile, []byte("以下に示します。日本語の文章です。"), 0o644); err != nil {
		t.Fatal(err)
	}

	// config ファイルなし → enabled=false がデフォルト
	input := `{"tool_name":"Write","tool_input":{"file_path":"notes.md"}}`
	var out bytes.Buffer
	if err := HandlePostToolUseWritingLint(strings.NewReader(input), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if out.Len() != 0 {
		t.Errorf("expected no output when disabled (no config), got %q", out.String())
	}

	// enabled: false を明示しても同様にスキップ
	config := "writing_lint:\n  enabled: false\n"
	if err := os.WriteFile(".claude-code-harness.config.yaml", []byte(config), 0o644); err != nil {
		t.Fatal(err)
	}
	out.Reset()
	if err := HandlePostToolUseWritingLint(strings.NewReader(input), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if out.Len() != 0 {
		t.Errorf("expected no output when enabled:false explicit, got %q", out.String())
	}
}

// ひらがな含有ゲート: 英語ファイルはスキップされる。
func TestHandlePostToolUseWritingLint_EnglishFileSkipped(t *testing.T) {
	tmpDir := t.TempDir()
	origDir, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	if err := os.Chdir(tmpDir); err != nil {
		t.Fatal(err)
	}
	defer os.Chdir(origDir)

	dictPath := writeWritingLintDictFixture(t, tmpDir)
	t.Setenv(writinglint.EnvDictPath, dictPath)

	config := "writing_lint:\n  enabled: true\n  structural: false\n"
	if err := os.WriteFile(".claude-code-harness.config.yaml", []byte(config), 0o644); err != nil {
		t.Fatal(err)
	}

	mdFile := filepath.Join(tmpDir, "english.md")
	if err := os.WriteFile(mdFile, []byte("This is an English document without any Japanese text."), 0o644); err != nil {
		t.Fatal(err)
	}

	input := `{"tool_name":"Write","tool_input":{"file_path":"english.md"}}`
	var out bytes.Buffer
	if err := HandlePostToolUseWritingLint(strings.NewReader(input), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if out.Len() != 0 {
		t.Errorf("expected no output for English file (no hiragana), got %q", out.String())
	}
}

// (a) 辞書ヒット .md fixture で additionalContext に警告 + グッドパターン
func TestHandlePostToolUseWritingLint_DictHitReturnsWarningAndGoodPattern(t *testing.T) {
	tmpDir := t.TempDir()
	origDir, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	if err := os.Chdir(tmpDir); err != nil {
		t.Fatal(err)
	}
	defer os.Chdir(origDir)

	dictPath := writeWritingLintDictFixture(t, tmpDir)
	t.Setenv(writinglint.EnvDictPath, dictPath)

	config := "writing_lint:\n  enabled: true\n  structural: false\n"
	if err := os.WriteFile(".claude-code-harness.config.yaml", []byte(config), 0o644); err != nil {
		t.Fatal(err)
	}

	mdFile := filepath.Join(tmpDir, "notes.md")
	if err := os.WriteFile(mdFile, []byte("以下に示します。ここから本題です。"), 0o644); err != nil {
		t.Fatal(err)
	}

	input := `{"tool_name":"Write","tool_input":{"file_path":"notes.md"}}`
	var out bytes.Buffer
	if err := HandlePostToolUseWritingLint(strings.NewReader(input), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if out.Len() == 0 {
		t.Fatal("expected output for dictionary hit")
	}

	var result postToolOutput
	if jsonErr := json.Unmarshal(out.Bytes(), &result); jsonErr != nil {
		t.Fatalf("invalid JSON output: %v, raw: %s", jsonErr, out.String())
	}
	ctx := result.HookSpecificOutput.AdditionalContext
	if !strings.Contains(ctx, "以下に示します") {
		t.Errorf("expected matched text (warning) in additionalContext, got %q", ctx)
	}
	if !strings.Contains(ctx, "結論から直接書く") {
		t.Errorf("expected good pattern in additionalContext, got %q", ctx)
	}
}

// 上位 5 件キャップ + 超過数明記
func TestMatchFeedback_CapsAtFiveAndNotesExcess(t *testing.T) {
	var matches []writinglint.Match
	for i := 0; i < 7; i++ {
		matches = append(matches, writinglint.Match{RuleID: "r", Text: "x", Good: "g"})
	}
	lines := matchFeedback(matches, "ja")
	if len(lines) != writingLintMaxMatches+1 {
		t.Fatalf("expected %d lines (5 hits + 1 excess note), got %d: %v", writingLintMaxMatches+1, len(lines), lines)
	}
	last := lines[len(lines)-1]
	if !strings.Contains(last, "2") {
		t.Errorf("expected excess count 2 in %q", last)
	}
}

// 辞書未検出時は診断メッセージを一度だけ返す（ブロックはしない）。
func TestHandlePostToolUseWritingLint_MissingDictDiagnostics(t *testing.T) {
	tmpDir := t.TempDir()
	origDir, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	if err := os.Chdir(tmpDir); err != nil {
		t.Fatal(err)
	}
	defer os.Chdir(origDir)

	// 存在しない辞書パスを指す env
	t.Setenv(writinglint.EnvDictPath, filepath.Join(tmpDir, "nope", "rules.jsonl"))

	config := "writing_lint:\n  enabled: true\n  structural: false\n"
	if err := os.WriteFile(".claude-code-harness.config.yaml", []byte(config), 0o644); err != nil {
		t.Fatal(err)
	}

	mdFile := filepath.Join(tmpDir, "notes.md")
	if err := os.WriteFile(mdFile, []byte("これは日本語の文章です。"), 0o644); err != nil {
		t.Fatal(err)
	}

	input := `{"tool_name":"Write","tool_input":{"file_path":"notes.md"}}`
	var out bytes.Buffer
	if err := HandlePostToolUseWritingLint(strings.NewReader(input), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if out.Len() == 0 {
		t.Fatal("expected diagnostics output for missing dict")
	}
	var result postToolOutput
	if jsonErr := json.Unmarshal(out.Bytes(), &result); jsonErr != nil {
		t.Fatalf("invalid JSON output: %v, raw: %s", jsonErr, out.String())
	}
	ctx := result.HookSpecificOutput.AdditionalContext
	if !strings.Contains(ctx, "辞書") && !strings.Contains(ctx, "dictionary") {
		t.Errorf("expected dictionary diagnostics message, got %q", ctx)
	}
}

// TestHandlePostToolUseWritingLint_ConfigFoundFromRepoSubdirectory is the
// regression for the CWD-dependent silent-disable finding: before this fix,
// the config was read from a literal relative path
// (".claude-code-harness.config.yaml"), resolved against the process's raw
// working directory. When the process actually runs from a subdirectory of
// the project (monorepo subdir invocation), that literal path misses the
// repo-root config and writing_lint.enabled silently reads as false. Aligning
// with stop_writing_lint.go's resolveProjectRoot() join (git rev-parse
// --show-toplevel fallback) fixes this: the config at the repo root must
// still be found and enabled:true honored from a subdirectory.
func TestHandlePostToolUseWritingLint_ConfigFoundFromRepoSubdirectory(t *testing.T) {
	repoRoot := t.TempDir()
	if real, err := filepath.EvalSymlinks(repoRoot); err == nil {
		repoRoot = real
	}
	if err := gitport.Run(repoRoot, "init"); err != nil {
		t.Fatalf("git init: %v", err)
	}

	subDir := filepath.Join(repoRoot, "sub")
	if err := os.MkdirAll(subDir, 0o755); err != nil {
		t.Fatal(err)
	}

	origDir, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	if err := os.Chdir(subDir); err != nil {
		t.Fatal(err)
	}
	defer os.Chdir(origDir)

	dictPath := writeWritingLintDictFixture(t, repoRoot)
	t.Setenv(writinglint.EnvDictPath, dictPath)

	// config は repo ルートにだけ置く。sub/ には置かない。
	config := "writing_lint:\n  enabled: true\n  structural: false\n"
	if err := os.WriteFile(filepath.Join(repoRoot, harnessConfigFileName), []byte(config), 0o644); err != nil {
		t.Fatal(err)
	}

	mdFile := filepath.Join(subDir, "notes.md")
	if err := os.WriteFile(mdFile, []byte("以下に示します。ここから本題です。"), 0o644); err != nil {
		t.Fatal(err)
	}

	input := `{"tool_name":"Write","tool_input":{"file_path":"notes.md"}}`
	var out bytes.Buffer
	if err := HandlePostToolUseWritingLint(strings.NewReader(input), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if out.Len() == 0 {
		t.Fatal("expected a dictionary-hit warning: repo-root config (enabled:true) should be found from a subdirectory")
	}

	var result postToolOutput
	if jsonErr := json.Unmarshal(out.Bytes(), &result); jsonErr != nil {
		t.Fatalf("invalid JSON output: %v, raw: %s", jsonErr, out.String())
	}
	ctx := result.HookSpecificOutput.AdditionalContext
	if !strings.Contains(ctx, "以下に示します") {
		t.Errorf("expected matched text in additionalContext (proves repo-root config was honored), got %q", ctx)
	}
}

func TestContainsHiragana(t *testing.T) {
	if !containsHiragana("これはテストです") {
		t.Error("expected hiragana to be detected")
	}
	if containsHiragana("This is English only.") {
		t.Error("expected no hiragana in English text")
	}
	if containsHiragana("テストデータ") {
		t.Error("katakana-only text must not be treated as containing hiragana")
	}
}
