package hookhandler

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestUsageTrackerHandler_AlwaysContinue(t *testing.T) {
	h := &UsageTrackerHandler{ProjectRoot: t.TempDir()}

	var out bytes.Buffer
	err := h.Handle(strings.NewReader(`{}`), &out)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	var resp usageTrackerResponse
	if err := json.Unmarshal(bytes.TrimRight(out.Bytes(), "\n"), &resp); err != nil {
		t.Fatalf("invalid JSON: %s", out.String())
	}
	if !resp.Continue {
		t.Errorf("expected continue=true")
	}
}

func TestUsageTrackerHandler_EmptyInput(t *testing.T) {
	h := &UsageTrackerHandler{ProjectRoot: t.TempDir()}

	var out bytes.Buffer
	err := h.Handle(strings.NewReader(""), &out)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	var resp usageTrackerResponse
	if err := json.Unmarshal(bytes.TrimRight(out.Bytes(), "\n"), &resp); err != nil {
		t.Fatalf("invalid JSON: %s", out.String())
	}
	if !resp.Continue {
		t.Errorf("expected continue=true")
	}
}

func TestUsageTrackerHandler_SkillTracking(t *testing.T) {
	dir := t.TempDir()
	h := &UsageTrackerHandler{ProjectRoot: dir}

	input := `{
		"tool_name": "Skill",
		"tool_input": {"skill": "claude-code-harness:harness-review"},
		"cwd": ""
	}`

	var out bytes.Buffer
	err := h.Handle(strings.NewReader(input), &out)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	var resp usageTrackerResponse
	if err := json.Unmarshal(bytes.TrimRight(out.Bytes(), "\n"), &resp); err != nil {
		t.Fatalf("invalid JSON: %s", out.String())
	}
	if !resp.Continue {
		t.Errorf("expected continue=true")
	}

	// Verify that the JSONL file was created
	statsFile := filepath.Join(dir, ".claude", "state", usageStatsFile)
	data, err := os.ReadFile(statsFile)
	if err != nil {
		t.Fatalf("usage-stats.jsonl not created: %v", err)
	}

	var entry usageEntry
	if err := json.Unmarshal(bytes.TrimRight(data, "\n"), &entry); err != nil {
		t.Fatalf("invalid entry JSON: %s", string(data))
	}
	if entry.Type != "skill" {
		t.Errorf("expected type=skill, got %q", entry.Type)
	}
	if entry.Name != "harness-review" {
		t.Errorf("expected name=harness-review, got %q", entry.Name)
	}
}

func TestUsageTrackerHandler_SkillTracking_BaseName(t *testing.T) {
	dir := t.TempDir()
	h := &UsageTrackerHandler{ProjectRoot: dir}

	// Fully-qualified name with colon separators
	input := `{"tool_name":"Skill","tool_input":{"skill":"plugin:category:work"}}`

	var out bytes.Buffer
	_ = h.Handle(strings.NewReader(input), &out)

	statsFile := filepath.Join(dir, ".claude", "state", usageStatsFile)
	data, err := os.ReadFile(statsFile)
	if err != nil {
		t.Fatalf("stats file not created: %v", err)
	}

	var entry usageEntry
	_ = json.Unmarshal(bytes.TrimRight(data, "\n"), &entry)
	if entry.Name != "work" {
		t.Errorf("expected name=work (base name), got %q", entry.Name)
	}
}

func TestUsageTrackerHandler_SlashCommandTracking(t *testing.T) {
	dir := t.TempDir()
	h := &UsageTrackerHandler{ProjectRoot: dir}

	input := `{"tool_name":"SlashCommand","tool_input":{"command":"/harness-review"}}`

	var out bytes.Buffer
	err := h.Handle(strings.NewReader(input), &out)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	statsFile := filepath.Join(dir, ".claude", "state", usageStatsFile)
	data, err := os.ReadFile(statsFile)
	if err != nil {
		t.Fatalf("stats file not created: %v", err)
	}

	var entry usageEntry
	_ = json.Unmarshal(bytes.TrimRight(data, "\n"), &entry)
	if entry.Type != "command" {
		t.Errorf("expected type=command, got %q", entry.Type)
	}
	// Verify that the leading slash was stripped
	if entry.Name != "harness-review" {
		t.Errorf("expected name=harness-review, got %q", entry.Name)
	}
}

func TestUsageTrackerHandler_TaskTracking(t *testing.T) {
	dir := t.TempDir()
	h := &UsageTrackerHandler{ProjectRoot: dir}

	input := `{"tool_name":"Task","tool_input":{"subagent_type":"claude-code-harness:worker"}}`

	var out bytes.Buffer
	err := h.Handle(strings.NewReader(input), &out)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	statsFile := filepath.Join(dir, ".claude", "state", usageStatsFile)
	data, err := os.ReadFile(statsFile)
	if err != nil {
		t.Fatalf("stats file not created: %v", err)
	}

	var entry usageEntry
	_ = json.Unmarshal(bytes.TrimRight(data, "\n"), &entry)
	if entry.Type != "agent" {
		t.Errorf("expected type=agent, got %q", entry.Type)
	}
}

func TestUsageTrackerHandler_UnknownTool_NoFile(t *testing.T) {
	dir := t.TempDir()
	h := &UsageTrackerHandler{ProjectRoot: dir}

	// Tool not subject to tracking (e.g. Read)
	input := `{"tool_name":"Read","tool_input":{"file_path":"/foo/bar.txt"}}`

	var out bytes.Buffer
	err := h.Handle(strings.NewReader(input), &out)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	// The JSONL file should not be created
	statsFile := filepath.Join(dir, ".claude", "state", usageStatsFile)
	if _, err := os.Stat(statsFile); err == nil {
		t.Errorf("usage-stats.jsonl should not be created for unknown tool")
	}
}

func TestUsageTrackerHandler_SSOTFlag_MemorySkill(t *testing.T) {
	dir := t.TempDir()
	h := &UsageTrackerHandler{ProjectRoot: dir}

	input := `{"tool_name":"Skill","tool_input":{"skill":"claude-code-harness:core:memory"}}`

	var out bytes.Buffer
	_ = h.Handle(strings.NewReader(input), &out)

	// Verify that the SSOT flag was created
	ssotFlag := filepath.Join(dir, ".claude", "state", ".ssot-synced-this-session")
	if _, err := os.Stat(ssotFlag); err != nil {
		t.Errorf("expected .ssot-synced-this-session to be created: %v", err)
	}
}

func TestUsageTrackerHandler_SSOTFlag_SyncSkill(t *testing.T) {
	dir := t.TempDir()
	h := &UsageTrackerHandler{ProjectRoot: dir}

	input := `{"tool_name":"Skill","tool_input":{"skill":"sync-ssot-from-memory"}}`

	var out bytes.Buffer
	_ = h.Handle(strings.NewReader(input), &out)

	ssotFlag := filepath.Join(dir, ".claude", "state", ".ssot-synced-this-session")
	if _, err := os.Stat(ssotFlag); err != nil {
		t.Errorf("expected .ssot-synced-this-session to be created: %v", err)
	}
}

func TestUsageTrackerHandler_SSOTFlag_MemoryCommand(t *testing.T) {
	dir := t.TempDir()
	h := &UsageTrackerHandler{ProjectRoot: dir}

	input := `{"tool_name":"SlashCommand","tool_input":{"command":"/memory"}}`

	var out bytes.Buffer
	_ = h.Handle(strings.NewReader(input), &out)

	ssotFlag := filepath.Join(dir, ".claude", "state", ".ssot-synced-this-session")
	if _, err := os.Stat(ssotFlag); err != nil {
		t.Errorf("expected .ssot-synced-this-session to be created: %v", err)
	}
}

func TestUsageTrackerHandler_Rotation(t *testing.T) {
	dir := t.TempDir()
	h := &UsageTrackerHandler{ProjectRoot: dir}

	stateDir := filepath.Join(dir, ".claude", "state")
	_ = os.MkdirAll(stateDir, 0700)

	// Create a dummy file exceeding 100 KB
	statsFile := filepath.Join(stateDir, usageStatsFile)
	large := bytes.Repeat([]byte("x"), usageMaxSizeBytes+1)
	_ = os.WriteFile(statsFile, large, 0600)

	// エントリを 1 件追加
	input := `{"tool_name":"Skill","tool_input":{"skill":"work"}}`
	var out bytes.Buffer
	_ = h.Handle(strings.NewReader(input), &out)

	// Verify that the .bak file was created
	bakFile := statsFile + ".bak"
	if _, err := os.Stat(bakFile); err != nil {
		t.Errorf("expected .bak file to be created: %v", err)
	}

	// Verify that the original file is now smaller (recreated)
	fi, err := os.Stat(statsFile)
	if err != nil {
		t.Fatalf("stats file not found after rotation: %v", err)
	}
	if fi.Size() >= int64(usageMaxSizeBytes) {
		t.Errorf("expected stats file to be smaller after rotation, got %d bytes", fi.Size())
	}
}

func TestUsageTrackerHandler_MultipleEntries(t *testing.T) {
	dir := t.TempDir()
	h := &UsageTrackerHandler{ProjectRoot: dir}

	inputs := []string{
		`{"tool_name":"Skill","tool_input":{"skill":"work"}}`,
		`{"tool_name":"SlashCommand","tool_input":{"command":"/harness-review"}}`,
		`{"tool_name":"Task","tool_input":{"subagent_type":"worker"}}`,
	}

	for _, inp := range inputs {
		var out bytes.Buffer
		_ = h.Handle(strings.NewReader(inp), &out)
	}

	statsFile := filepath.Join(dir, ".claude", "state", usageStatsFile)
	data, err := os.ReadFile(statsFile)
	if err != nil {
		t.Fatalf("stats file not created: %v", err)
	}

	lines := strings.Split(strings.TrimRight(string(data), "\n"), "\n")
	if len(lines) != 3 {
		t.Errorf("expected 3 entries, got %d", len(lines))
	}
}

func TestExtractBaseName(t *testing.T) {
	tests := []struct {
		input string
		sep   string
		want  string
	}{
		{"claude-code-harness:core:work", ":", "work"},
		{"work", ":", "work"},
		{"a:b:c:d", ":", "d"},
		{"", ":", ""},
	}
	for _, tt := range tests {
		got := extractBaseName(tt.input, tt.sep)
		if got != tt.want {
			t.Errorf("extractBaseName(%q, %q) = %q, want %q", tt.input, tt.sep, got, tt.want)
		}
	}
}
