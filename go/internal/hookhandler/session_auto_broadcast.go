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

	// Phase 85.1.7 fix (S2): refuse to broadcast paths that obviously carry
	// secrets, per-developer SSOT, or client-identifying names. The Phase
	// 65.3 cross-project redaction contract requires client-side
	// redaction before paths cross sessions; this deny list is the
	// minimum floor while a full redaction integration is out of scope.
	if isSensitiveBroadcastPath(filePath) {
		return emptyPostToolOutput(out)
	}

	// Phase 85.1.7 fix (S3): resolve sessionsDir from the project root, not
	// from cwd. inbox-check uses resolveProjectRoot() (git toplevel) so the
	// producer (this writer) and consumer (inbox-check reader) must agree
	// on the same path even when the hook fires from a subdirectory like
	// /repo/go/ while editing go/foo.go.
	sessionsDir := filepath.Join(resolveProjectRoot(), ".claude", "sessions")
	configFile := filepath.Join(sessionsDir, "auto-broadcast.json")
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

	// ブロードキャスト実行: .claude/sessions/broadcast.md に書き込む
	fileName := filepath.Base(filePath)
	if broadcastErr := writeBroadcastNotification(sessionsDir, filePath, matchedPattern, input.SessionID); broadcastErr != nil {
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
//
// Phase 85.1.7 fix (S1): file mode is 0o600 and the parent dir is 0o700 so
// "who edited what + when" is owner-only on shared hosts. The Phase 85
// lease lock files already use the same floor (session_lease.go:25-30).
//
// Phase 85.1.7 fix (C1): after a successful append, rotateBroadcastMD
// truncates the head to the last 400 entries when the entry count exceeds
// 500. Without this the file grows unboundedly under the Phase 85.1.6
// extension rule and inbox-check would eventually time out parsing it.
func writeBroadcastNotification(sessionsDir, filePath, matchedPattern, sessionID string) error {
	if err := os.MkdirAll(sessionsDir, 0o700); err != nil {
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

	f, err := os.OpenFile(broadcastFile, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o600)
	if err != nil {
		return fmt.Errorf("open broadcast file: %w", err)
	}
	defer f.Close()

	if _, err := f.WriteString(entry); err != nil {
		return fmt.Errorf("write broadcast entry: %w", err)
	}

	// Best-effort rotation. Errors are swallowed because losing the
	// rotation pass would only mean the file keeps growing for one more
	// edit; the next successful append will retry. Mirrors the swallow
	// pattern used by elicitation_handler.go and notification_handler.go
	// for their JSONL rotations.
	_ = rotateBroadcastMD(broadcastFile, 500, 400)
	return nil
}

// isSensitiveBroadcastPath returns true when filePath obviously carries
// secrets, per-developer SSOT content, or client-identifying names that
// should not cross session boundaries through broadcast.md. The patterns
// are intentionally conservative — the goal is to block the obvious
// leaks (Phase 65.3 redaction's job is fuller coverage), not to be a
// complete filter.
func isSensitiveBroadcastPath(filePath string) bool {
	cleaned := filepath.ToSlash(filepath.Clean(filePath))
	lower := strings.ToLower(cleaned)
	base := filepath.Base(cleaned)
	lowerBase := strings.ToLower(base)

	// Filename-level checks: .env exactly, .env.local, .env.production etc.
	if lowerBase == ".env" || strings.HasPrefix(lowerBase, ".env.") {
		return true
	}
	// Extension-based: cryptographic material.
	for _, ext := range []string{".key", ".pem", ".p12", ".pfx", ".crt"} {
		if strings.HasSuffix(lowerBase, ext) {
			return true
		}
	}
	// Path-segment checks: anchor on `/` boundaries so a filename
	// containing "secret" as a substring (e.g. "secret-helpers.go") does
	// not trigger; only path tokens like "/secrets/" do. Prepend "/" to
	// the cleaned path so a top-level token (".claude/memory/decisions.md"
	// without any parent) also matches the leading-/ patterns.
	anchored := "/" + lower
	for _, seg := range []string{
		"/secrets/",
		"/.claude/memory/",
		"/.ssh/",
		"/.aws/",
		"/clients/",
		"/credentials/",
	} {
		if strings.Contains(anchored, seg) {
			return true
		}
	}
	return false
}

// rotateBroadcastMD truncates broadcast.md from the head when the entry
// count exceeds maxEntries, keeping the trailing keepEntries entries.
// An entry is delimited by the "\n## " header sequence that every writer
// emits (and inbox-check's broadcastMsgRe parser also anchors on). Each
// rotation writes atomically via tmp + rename so partial state never
// reaches inbox-check.
//
// rotateJSONL's line-count shape would split entries mid-message because
// each broadcast entry is two lines, so this implementation counts by
// header instead. The atomic write + same-dir tmp pattern matches.
func rotateBroadcastMD(path string, maxEntries, keepEntries int) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil // file gone — nothing to rotate
	}
	if len(data) == 0 {
		return nil
	}

	// Split on the literal "\n## " separator. The first element is the
	// preamble (everything before the first header); the rest are entry
	// bodies stripped of their leading "\n## " prefix.
	parts := strings.Split(string(data), "\n## ")
	if len(parts) <= 1 {
		// No header at all — only preamble. Nothing to rotate.
		return nil
	}
	numEntries := len(parts) - 1
	if numEntries <= maxEntries {
		return nil
	}

	start := numEntries - keepEntries
	if start < 0 {
		start = 0
	}

	// Reconstruct: preamble + each kept entry re-prefixed with "\n## ".
	var sb strings.Builder
	sb.WriteString(parts[0])
	for _, body := range parts[1+start:] {
		sb.WriteString("\n## ")
		sb.WriteString(body)
	}
	trimmed := sb.String()

	tmpPath := path + ".tmp"
	if err := os.WriteFile(tmpPath, []byte(trimmed), 0o600); err != nil {
		return fmt.Errorf("write tmp rotation: %w", err)
	}
	if err := os.Rename(tmpPath, path); err != nil {
		_ = os.Remove(tmpPath)
		return fmt.Errorf("rename rotation: %w", err)
	}
	return nil
}
