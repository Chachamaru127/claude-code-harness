package hookhandler

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestTrackCommandHandler_NoInput(t *testing.T) {
	dir := t.TempDir()
	h := &TrackCommandHandler{ProjectRoot: dir}

	var out bytes.Buffer
	err := h.Handle(strings.NewReader(""), &out)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	var resp trackCommandResponse
	if err := json.Unmarshal(bytes.TrimRight(out.Bytes(), "\n"), &resp); err != nil {
		t.Fatalf("invalid JSON: %s", out.String())
	}
	if !resp.Continue {
		t.Errorf("expected continue=true")
	}
}

func TestTrackCommandHandler_EmptyPrompt(t *testing.T) {
	dir := t.TempDir()
	h := &TrackCommandHandler{ProjectRoot: dir}

	var out bytes.Buffer
	err := h.Handle(strings.NewReader(`{"prompt":""}`), &out)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	var resp trackCommandResponse
	if err := json.Unmarshal(bytes.TrimRight(out.Bytes(), "\n"), &resp); err != nil {
		t.Fatalf("invalid JSON: %s", out.String())
	}
	if !resp.Continue {
		t.Errorf("expected continue=true")
	}
}

func TestTrackCommandHandler_NonSlashPrompt(t *testing.T) {
	dir := t.TempDir()
	h := &TrackCommandHandler{ProjectRoot: dir}

	var out bytes.Buffer
	err := h.Handle(strings.NewReader(`{"prompt":"This is a normal message"}`), &out)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	var resp trackCommandResponse
	if err := json.Unmarshal(bytes.TrimRight(out.Bytes(), "\n"), &resp); err != nil {
		t.Fatalf("invalid JSON: %s", out.String())
	}
	if !resp.Continue {
		t.Errorf("expected continue=true")
	}

	// Verify that no pending file was created
	pendingDir := filepath.Join(dir, ".claude", "state", "pending-skills")
	if _, err := os.Stat(pendingDir); err == nil {
		entries, _ := os.ReadDir(pendingDir)
		if len(entries) > 0 {
			t.Errorf("expected no pending files for non-slash command")
		}
	}
}

func TestTrackCommandHandler_SkillRequiredCommand_Work(t *testing.T) {
	dir := t.TempDir()
	h := &TrackCommandHandler{ProjectRoot: dir}

	var out bytes.Buffer
	err := h.Handle(strings.NewReader(`{"prompt":"/work implement task 3"}`), &out)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	var resp trackCommandResponse
	if err := json.Unmarshal(bytes.TrimRight(out.Bytes(), "\n"), &resp); err != nil {
		t.Fatalf("invalid JSON: %s", out.String())
	}
	if !resp.Continue {
		t.Errorf("expected continue=true")
	}

	// Verify that the pending file was created
	pendingFile := filepath.Join(dir, ".claude", "state", "pending-skills", "work.pending")
	data, err := os.ReadFile(pendingFile)
	if err != nil {
		t.Fatalf("expected pending file to be created: %v", err)
	}

	var entry pendingEntry
	if err := json.Unmarshal(data, &entry); err != nil {
		t.Fatalf("invalid pending file JSON: %s", string(data))
	}
	if entry.Command != "work" {
		t.Errorf("expected command=work, got %s", entry.Command)
	}
	if entry.StartedAt == "" {
		t.Errorf("expected started_at to be set")
	}
	if !strings.Contains(entry.PromptPreview, "task 3") {
		t.Errorf("expected prompt_preview to contain prompt text, got: %s", entry.PromptPreview)
	}
}

func TestTrackCommandHandler_SkillRequiredCommand_HarnessReview(t *testing.T) {
	dir := t.TempDir()
	h := &TrackCommandHandler{ProjectRoot: dir}

	var out bytes.Buffer
	err := h.Handle(strings.NewReader(`{"prompt":"/harness-review"}`), &out)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	var resp trackCommandResponse
	if err := json.Unmarshal(bytes.TrimRight(out.Bytes(), "\n"), &resp); err != nil {
		t.Fatalf("invalid JSON: %s", out.String())
	}
	if !resp.Continue {
		t.Errorf("expected continue=true")
	}

	pendingFile := filepath.Join(dir, ".claude", "state", "pending-skills", "harness-review.pending")
	if _, err := os.ReadFile(pendingFile); err != nil {
		t.Fatalf("expected harness-review.pending to be created: %v", err)
	}
}

func TestTrackCommandHandler_NonSkillSlashCommand(t *testing.T) {
	dir := t.TempDir()
	h := &TrackCommandHandler{ProjectRoot: dir}

	// /breezing is not in skillRequiredCommands
	var out bytes.Buffer
	err := h.Handle(strings.NewReader(`{"prompt":"/breezing all"}`), &out)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	var resp trackCommandResponse
	if err := json.Unmarshal(bytes.TrimRight(out.Bytes(), "\n"), &resp); err != nil {
		t.Fatalf("invalid JSON: %s", out.String())
	}
	if !resp.Continue {
		t.Errorf("expected continue=true")
	}

	// Verify that no pending file was created
	pendingFile := filepath.Join(dir, ".claude", "state", "pending-skills", "breezing.pending")
	if _, err := os.Stat(pendingFile); err == nil {
		t.Errorf("expected no pending file for non-skill-required command")
	}
}

func TestTrackCommandHandler_PluginPrefixCommand(t *testing.T) {
	dir := t.TempDir()
	h := &TrackCommandHandler{ProjectRoot: dir}

	// Command with a plugin prefix
	var out bytes.Buffer
	err := h.Handle(strings.NewReader(`{"prompt":"/company-ai-harness:core:work execute task"}`), &out)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	var resp trackCommandResponse
	if err := json.Unmarshal(bytes.TrimRight(out.Bytes(), "\n"), &resp); err != nil {
		t.Fatalf("invalid JSON: %s", out.String())
	}
	if !resp.Continue {
		t.Errorf("expected continue=true")
	}

	// Verify that the prefix is stripped and the command is recognised as "work"
	pendingFile := filepath.Join(dir, ".claude", "state", "pending-skills", "work.pending")
	if _, err := os.ReadFile(pendingFile); err != nil {
		t.Fatalf("expected work.pending to be created (after prefix strip): %v", err)
	}
}

func TestTrackCommandHandler_MultilinePrompt(t *testing.T) {
	dir := t.TempDir()
	h := &TrackCommandHandler{ProjectRoot: dir}

	// Verify that only the first line is checked
	prompt := "/work\nnext line content\nyet another line"
	input := `{"prompt":` + `"` + strings.ReplaceAll(prompt, "\n", `\n`) + `"}`

	var out bytes.Buffer
	err := h.Handle(strings.NewReader(input), &out)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	var resp trackCommandResponse
	if err := json.Unmarshal(bytes.TrimRight(out.Bytes(), "\n"), &resp); err != nil {
		t.Fatalf("invalid JSON: %s", out.String())
	}
	if !resp.Continue {
		t.Errorf("expected continue=true")
	}

	// /work should be recognised as the command
	pendingFile := filepath.Join(dir, ".claude", "state", "pending-skills", "work.pending")
	if _, err := os.ReadFile(pendingFile); err != nil {
		t.Fatalf("expected work.pending from multiline prompt: %v", err)
	}
}

func TestTrackCommandHandler_LongPromptTruncated(t *testing.T) {
	dir := t.TempDir()
	h := &TrackCommandHandler{ProjectRoot: dir}

	// Prompt exceeding 200 characters
	longText := "/work " + strings.Repeat("a", 300)
	inputJSON, _ := json.Marshal(map[string]string{"prompt": longText})

	var out bytes.Buffer
	err := h.Handle(bytes.NewReader(inputJSON), &out)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	pendingFile := filepath.Join(dir, ".claude", "state", "pending-skills", "work.pending")
	data, err := os.ReadFile(pendingFile)
	if err != nil {
		t.Fatalf("expected work.pending: %v", err)
	}

	var entry pendingEntry
	if err := json.Unmarshal(data, &entry); err != nil {
		t.Fatalf("invalid pending JSON: %s", string(data))
	}

	// preview should be at most 200 runes
	runeCount := len([]rune(entry.PromptPreview))
	if runeCount > 200 {
		t.Errorf("prompt_preview should be at most 200 runes, got %d", runeCount)
	}
}
