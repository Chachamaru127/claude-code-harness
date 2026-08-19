package hookhandler

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/Chachamaru127/claude-code-harness/go/internal/gitport"
)

// UsageTrackerHandler は PostToolUse フックハンドラ（使用状況追跡）。
// Skill / SlashCommand / Task ツールの使用を .claude/state/usage-stats.jsonl に記録する。
// JSONL ファイルが 100KB を超えた場合は .bak にリネームしてローテーションする。
//
// shell 版: scripts/usage-tracker.sh
type UsageTrackerHandler struct {
	// ProjectRoot はプロジェクトルートのパス。空の場合は cwd を使用する。
	ProjectRoot string
}

// usageTrackerInput は PostToolUse フックの stdin JSON。
type usageTrackerInput struct {
	ToolName  string          `json:"tool_name"`
	ToolInput json.RawMessage `json:"tool_input"`
	CWD       string          `json:"cwd"`
}

// skillToolInput は Skill ツールの tool_input。
type skillToolInput struct {
	Skill string `json:"skill"`
}

// slashCommandInput は SlashCommand ツールの tool_input。
type slashCommandInput struct {
	Command string `json:"command"`
	Name    string `json:"name"`
}

// taskToolInput は Task ツールの tool_input。
type taskToolInput struct {
	SubagentType string `json:"subagent_type"`
}

// usageEntry は usage-stats.jsonl の 1 行エントリ。
type usageEntry struct {
	Type      string `json:"type"`
	Name      string `json:"name"`
	Digest    string `json:"digest,omitempty"`
	Timestamp string `json:"timestamp"`
}

const (
	usageStatsFile    = "usage-stats.jsonl"
	usageMaxSizeBytes = 100 * 1024 // 100KB
)

// Handle は stdin から PostToolUse ペイロードを読み取り、使用状況を記録する。
// 使用追跡はメインフローをブロックせず、成功時は親コンテキストへ何も返さない。
func (h *UsageTrackerHandler) Handle(r io.Reader, w io.Writer) error {
	data, _ := io.ReadAll(r)

	if len(data) > 0 {
		var inp usageTrackerInput
		if err := json.Unmarshal(data, &inp); err == nil && inp.ToolName != "" {
			// プロジェクトルートを決定（CWD フィールド優先）
			projectRoot := h.resolveProjectRoot(inp.CWD)
			h.track(inp, projectRoot)
		}
	}

	return nil
}

// resolveProjectRoot は記録先のプロジェクトルートを決定する。
// inp.CWD → git rev-parse → h.ProjectRoot → os.Getwd() の順で試みる。
func (h *UsageTrackerHandler) resolveProjectRoot(cwd string) string {
	if cwd != "" {
		if root, err := gitRepoRoot(cwd); err == nil {
			return root
		}
		return cwd
	}
	if h.ProjectRoot != "" {
		return h.ProjectRoot
	}
	wd, _ := os.Getwd()
	return wd
}

// gitRepoRoot は指定ディレクトリから git リポジトリルートを返す。
func gitRepoRoot(dir string) (string, error) {
	out, err := gitport.Output(dir, "rev-parse", "--show-toplevel")
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(out), nil
}

// track は tool_name に応じて使用状況を記録する。
func (h *UsageTrackerHandler) track(inp usageTrackerInput, projectRoot string) {
	var entry *usageEntry

	switch inp.ToolName {
	case "Skill":
		entry = h.trackSkill(inp, projectRoot)
	case "SlashCommand":
		entry = h.trackSlashCommand(inp, projectRoot)
	case "Task":
		entry = h.trackTask(inp)
	}

	if entry == nil {
		return
	}

	// JSONL ファイルに追記
	stateDir := filepath.Join(projectRoot, ".claude", "state")
	if err := os.MkdirAll(stateDir, 0700); err != nil {
		return
	}
	statsFile := filepath.Join(stateDir, usageStatsFile)
	h.appendEntry(statsFile, entry)
}

// trackSkill は Skill ツールの使用を記録し、エントリを返す。
// sync-ssot-from-memory / memory スキルの場合は ssot-synced フラグも作成する。
func (h *UsageTrackerHandler) trackSkill(inp usageTrackerInput, projectRoot string) *usageEntry {
	var toolIn skillToolInput
	if err := json.Unmarshal(inp.ToolInput, &toolIn); err != nil || toolIn.Skill == "" {
		return nil
	}

	// "claude-code-harness:impl" → "impl"
	baseName := extractBaseName(toolIn.Skill, ":")

	// SSOT 同期フラグ
	if baseName == "sync-ssot-from-memory" || baseName == "memory" ||
		strings.Contains(toolIn.Skill, "sync-ssot-from-memory") ||
		strings.Contains(toolIn.Skill, ":memory") {
		h.touchSSOTFlag(projectRoot)
	}

	return &usageEntry{
		Type:      "skill",
		Name:      baseName,
		Digest:    digest(inp.ToolInput),
		Timestamp: nowISO(),
	}
}

// trackSlashCommand は SlashCommand ツールの使用を記録し、エントリを返す。
func (h *UsageTrackerHandler) trackSlashCommand(inp usageTrackerInput, projectRoot string) *usageEntry {
	var toolIn slashCommandInput
	if err := json.Unmarshal(inp.ToolInput, &toolIn); err != nil {
		return nil
	}

	cmdName := toolIn.Command
	if cmdName == "" {
		cmdName = toolIn.Name
	}
	if cmdName == "" {
		return nil
	}

	// 先頭の "/" を除去
	baseName := strings.TrimPrefix(cmdName, "/")

	// SSOT 同期フラグ
	if strings.Contains(baseName, "sync-ssot-from-memory") || baseName == "memory" {
		h.touchSSOTFlag(projectRoot)
	}

	return &usageEntry{
		Type:      "command",
		Name:      baseName,
		Digest:    digest(inp.ToolInput),
		Timestamp: nowISO(),
	}
}

// trackTask は Task ツールの使用を記録し、エントリを返す。
func (h *UsageTrackerHandler) trackTask(inp usageTrackerInput) *usageEntry {
	var toolIn taskToolInput
	if err := json.Unmarshal(inp.ToolInput, &toolIn); err != nil || toolIn.SubagentType == "" {
		return nil
	}

	return &usageEntry{
		Type:      "agent",
		Name:      toolIn.SubagentType,
		Digest:    digest(inp.ToolInput),
		Timestamp: nowISO(),
	}
}

// touchSSOTFlag は .claude/state/.ssot-synced-this-session フラグファイルを作成する。
func (h *UsageTrackerHandler) touchSSOTFlag(projectRoot string) {
	stateDir := filepath.Join(projectRoot, ".claude", "state")
	_ = os.MkdirAll(stateDir, 0700)
	flag := filepath.Join(stateDir, ".ssot-synced-this-session")
	_ = os.WriteFile(flag, []byte(""), 0600)
}

// appendEntry は entry を JSONL ファイルに追記する。
// ファイルサイズが 100KB を超えていたら .bak にリネームしてから新規作成する。
func (h *UsageTrackerHandler) appendEntry(statsFile string, entry *usageEntry) {
	// ローテーション判定
	if fi, err := os.Stat(statsFile); err == nil && fi.Size() > usageMaxSizeBytes {
		bakFile := statsFile + ".bak"
		_ = os.Rename(statsFile, bakFile)
	}

	line, err := json.Marshal(entry)
	if err != nil {
		return
	}

	f, err := os.OpenFile(statsFile, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0600)
	if err != nil {
		return
	}
	defer f.Close()
	_, _ = fmt.Fprintf(f, "%s\n", line)
}

// extractBaseName はコロンまたはスラッシュで区切られた文字列の末尾セグメントを返す。
func extractBaseName(s, sep string) string {
	parts := strings.Split(s, sep)
	return parts[len(parts)-1]
}

// digest は raw JSON バイトの先頭 100 文字を返す（ログ用）。
func digest(raw json.RawMessage) string {
	s := string(raw)
	if len(s) > 100 {
		return s[:100]
	}
	return s
}

// nowISO は現在時刻を RFC3339 形式で返す。
func nowISO() string {
	return time.Now().UTC().Format(time.RFC3339)
}
