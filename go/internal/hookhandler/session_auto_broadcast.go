// Package hookhandler implements Go ports of the Harness hook handler scripts.
package hookhandler

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"time"
)

// autoBroadcastPatterns は自動ブロードキャスト対象のパス substring パターン一覧。
// session-auto-broadcast.sh の AUTO_BROADCAST_PATTERNS に対応。strings.Contains
// で評価される。API / schema 系の path-token を想定した命名で、web-API repo
// での「interfaces を触ったら教えてほしい」要求に応える。
var autoBroadcastPatterns = []string{
	"src/api/",
	"src/types/",
	"src/interfaces/",
	"api/",
	"types/",
	"schema.prisma",
	"openapi",
	"swagger",
	".graphql",
}

// autoBroadcastExtensions は file extension で fire させる対象。Phase 85.1.6
// で復活させた条件で、Harness 自身のような web-API ではない repo (typically
// Go コードと markdown を書く repo) でも broadcast が機能するようにする。
// substring ではなく filepath.Ext で評価することで "foo.gotcha" のような
// 紛らわしいパス名が ".go" を誤検出することを防ぐ。
//
// 2026-02 broadcast 死骸の根本原因はここに含まれていなかったこと: 当時の
// autoBroadcastPatterns は API/schema 系の path-token しか持たず、
// claude-code-harness の通常編集 (.go / .md / .sh) は一切マッチしなかった。
var autoBroadcastExtensions = []string{".go", ".md", ".sh"}

// autoBroadcastInput は session-auto-broadcast.sh に渡される stdin JSON。
type autoBroadcastInput struct {
	SessionID string `json:"session_id"`
	CWD       string `json:"cwd"`
	ToolInput struct {
		FilePath string `json:"file_path"`
		Path     string `json:"path"`
	} `json:"tool_input"`
}

// autoBroadcastConfig は .claude/sessions/auto-broadcast.json の設定。
type autoBroadcastConfig struct {
	Enabled  *bool    `json:"enabled"`
	Patterns []string `json:"patterns"`
}

// postToolOutput は PostToolUse フックのレスポンス形式。
type postToolOutput struct {
	HookSpecificOutput struct {
		HookEventName     string `json:"hookEventName"`
		AdditionalContext string `json:"additionalContext"`
	} `json:"hookSpecificOutput"`
}

// emptyPostToolOutput は追加コンテキストなしの PostToolUse レスポンスを返す。
func emptyPostToolOutput(w io.Writer) error {
	out := postToolOutput{}
	out.HookSpecificOutput.HookEventName = "PostToolUse"
	out.HookSpecificOutput.AdditionalContext = ""
	return writeJSON(w, out)
}

// HandleSessionAutoBroadcast は session-auto-broadcast.sh の Go 移植。
//
// PostToolUse Write/Edit イベントで呼び出され、重要なファイルの変更を
// .claude/sessions/broadcast.md にチームメイト通知として書き込む。
// inbox_check が読む broadcast.md と同じファイルに書き込むことで
// プロデューサー/コンシューマーのパスが一致する。
//
// 対象パターン: src/api/, src/types/, src/interfaces/, api/, types/,
// schema.prisma, openapi, swagger, .graphql
func HandleSessionAutoBroadcast(in io.Reader, out io.Writer) error {
	// stdin から JSON を読み取る
	data, err := io.ReadAll(in)
	if err != nil {
		return emptyPostToolOutput(out)
	}

	// 入力がない場合は空レスポンスを返す
	if len(strings.TrimSpace(string(data))) == 0 {
		return emptyPostToolOutput(out)
	}

	var input autoBroadcastInput
	if err := json.Unmarshal(data, &input); err != nil {
		return emptyPostToolOutput(out)
	}

	if input.CWD != "" {
		info, statErr := os.Stat(input.CWD)
		if statErr != nil || !info.IsDir() {
			return emptyPostToolOutput(out)
		}
	}

	// file_path または path を取得
	filePath := input.ToolInput.FilePath
	if filePath == "" {
		filePath = input.ToolInput.Path
	}

	// ファイルパスがない場合は終了
	if filePath == "" {
		return emptyPostToolOutput(out)
	}

	// 設定ファイルを読み込む
	configFile := ".claude/sessions/auto-broadcast.json"
	enabled := true
	var customPatterns []string

	if cfgData, cfgErr := os.ReadFile(configFile); cfgErr == nil {
		var cfg autoBroadcastConfig
		if jsonErr := json.Unmarshal(cfgData, &cfg); jsonErr == nil {
			if cfg.Enabled != nil {
				enabled = *cfg.Enabled
			}
			customPatterns = cfg.Patterns
		}
	}

	// 自動ブロードキャストが無効な場合は終了
	if !enabled {
		return emptyPostToolOutput(out)
	}

	// パターンマッチング（組み込みパターン）
	matchedPattern := ""
	for _, pattern := range autoBroadcastPatterns {
		if strings.Contains(filePath, pattern) {
			matchedPattern = pattern
			break
		}
	}

	// カスタムパターンもチェック
	if matchedPattern == "" {
		for _, pattern := range customPatterns {
			if pattern != "" && strings.Contains(filePath, pattern) {
				matchedPattern = pattern
				break
			}
		}
	}

	// Extension match (Phase 85.1.6 revival): if no substring pattern hit,
	// try the extension allowlist so .go / .md / .sh edits also fire. Done
	// via filepath.Ext to avoid the "foo.gotcha contains '.go'" false
	// positive that strings.Contains would produce.
	if matchedPattern == "" {
		ext := filepath.Ext(filePath)
		if ext != "" {
			for _, allowedExt := range autoBroadcastExtensions {
				if ext == allowedExt {
					// Use a "*<ext>" label so it is obviously the
					// extension-rule rather than the substring rule
					// that fired; this shows up in the broadcast.md
					// entry and helps debugging.
					matchedPattern = "*" + allowedExt
					break
				}
			}
		}
	}

	// マッチしない場合は空レスポンスを返す
	if matchedPattern == "" {
		return emptyPostToolOutput(out)
	}

	// ブロードキャスト実行: .claude/state/broadcast.md に書き込む
	fileName := filepath.Base(filePath)
	if broadcastErr := writeBroadcastNotification(filePath, matchedPattern, input.SessionID); broadcastErr != nil {
		// 書き込み失敗は無視（フォールバックとして空レスポンスを返す）
		return emptyPostToolOutput(out)
	}

	// 通知メッセージを出力
	o := postToolOutput{}
	o.HookSpecificOutput.HookEventName = "PostToolUse"
	o.HookSpecificOutput.AdditionalContext = fmt.Sprintf(
		"自動ブロードキャスト: %s の変更を他セッションに通知しました", fileName,
	)
	return writeJSON(out, o)
}

// writeBroadcastNotification は .claude/sessions/broadcast.md にチームメイト通知を書き込む。
// inbox_check が読む .claude/sessions/broadcast.md と同じファイルに書き込む。
// ヘッダーフォーマット: ## <RFC3339 timestamp> [<session_id_prefix_8chars>]
// これは inbox_check の broadcastMsgRe パーサーが期待する形式に準拠する。
// sessionID を sender として使うことで、inbox_check が自セッションのメッセージを
// フィルタできるようになる（bash 版の動作と一致）。
func writeBroadcastNotification(filePath, matchedPattern, sessionID string) error {
	sessionsDir := ".claude/sessions"
	if err := os.MkdirAll(sessionsDir, 0o755); err != nil {
		return fmt.Errorf("mkdir sessions dir: %w", err)
	}

	broadcastFile := filepath.Join(sessionsDir, "broadcast.md")

	// sender タグ: session_id の先頭 12 文字を使用（bash 版に合わせた長さ）。
	// 空の場合は "unknown" にフォールバック（bash 版の動作と一致）。
	senderTag := sessionID
	if senderTag == "" {
		senderTag = "unknown"
	} else if len(senderTag) > 12 {
		senderTag = senderTag[:12]
	}

	// ヘッダーフォーマット: ## <timestamp> [<session_id_prefix>]
	// session-inbox-check.sh のパーサーが期待する形式に合わせる。
	ts := time.Now().UTC().Format("2006-01-02T15:04:05Z")
	entry := fmt.Sprintf("\n## %s [%s]\n📁 `%s` が変更されました: パターン '%s' にマッチ\n",
		ts, senderTag, filePath, matchedPattern)

	f, err := os.OpenFile(broadcastFile, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o644)
	if err != nil {
		return fmt.Errorf("open broadcast file: %w", err)
	}
	defer f.Close()

	if _, err := f.WriteString(entry); err != nil {
		return fmt.Errorf("write broadcast entry: %w", err)
	}
	return nil
}
