package hookhandler

import (
	"bytes"
	"crypto/rand"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"github.com/Chachamaru127/claude-code-harness/go/internal/gitport"
)

// EmitAgentTrace は emit-agent-trace.js の Go 移植。
// PostToolUse フックで agent-trace.jsonl にトレース記録を追記する。
// OTEL_EXPORTER_OTLP_ENDPOINT が設定されている場合は OTel Span を非同期 POST する。
//
// 元: scripts/emit-agent-trace.js
type EmitAgentTrace struct {
	// RepoRoot はリポジトリルートを指定する。
	// 空の場合は cwd から自動検出する。
	RepoRoot string
	// StateDir はトレースファイルの場所を指定する。
	// 空の場合は RepoRoot/.claude/state を使う。
	StateDir string
	// MaxFileSize はファイルローテーション閾値（バイト）。デフォルト 10MB。
	MaxFileSize int64
	// MaxGenerations はローテーション世代数。デフォルト 3。
	MaxGenerations int
	// HTTPClient は OTel エクスポート用 HTTP クライアント（テスト差し替え可能）。
	HTTPClient *http.Client
	// Now は現在時刻を返す関数（テスト用）。
	Now func() string
}

// traceVersion は agent-trace のバージョン。
const traceVersion = "0.3.0"

// eatMaxFileSizeDefault はデフォルトのファイルサイズ上限（10MB）。
const eatMaxFileSizeDefault int64 = 10 * 1024 * 1024

// eatMaxGenerationsDefault はデフォルトのローテーション世代数。
const eatMaxGenerationsDefault = 3

// traceCacheTTL はプロジェクトメタデータのキャッシュ TTL。
const traceCacheTTL = 60 * time.Second

// vcsCacheTTL は VCS 情報のキャッシュ TTL。
const vcsCacheTTL = 5 * time.Second

// traceRecord は agent-trace.jsonl の 1 レコード。
type traceRecord struct {
	Version     string                 `json:"version"`
	ID          string                 `json:"id"`
	Timestamp   string                 `json:"timestamp"`
	Tool        string                 `json:"tool"`
	Files       []traceFile            `json:"files"`
	VCS         *traceVCS              `json:"vcs,omitempty"`
	Metadata    map[string]interface{} `json:"metadata"`
	Attribution *traceAttribution      `json:"attribution,omitempty"`
	Metrics     *traceMetrics          `json:"metrics,omitempty"`
}

// traceFile はツールが操作したファイル情報。
type traceFile struct {
	Path   string `json:"path"`
	Action string `json:"action"`
	Range  string `json:"range"`
}

// traceVCS は VCS（Git）情報。
type traceVCS struct {
	Revision string `json:"revision"`
	Branch   string `json:"branch"`
	Dirty    bool   `json:"dirty"`
}

// traceAttribution はプラグイン帰属情報。
type traceAttribution struct {
	Plugin  string `json:"plugin"`
	Version string `json:"version"`
	License string `json:"license,omitempty"`
	Author  string `json:"author,omitempty"`
}

// traceMetrics は Task ツールのメトリクス情報。
type traceMetrics struct {
	TokenCount *int64   `json:"tokenCount,omitempty"`
	ToolUses   *int64   `json:"toolUses,omitempty"`
	Duration   *float64 `json:"duration,omitempty"`
}

// tracerCache はトレーサーレベルのキャッシュ。
type tracerCache struct {
	mu sync.Mutex

	// プロジェクトメタデータキャッシュ
	projMeta     map[string]string
	projMetaTime time.Time

	// VCS キャッシュ
	vcsInfo *traceVCS
	vcsTime time.Time

	// Attribution キャッシュ
	attr     *traceAttribution
	attrTime time.Time
}

// グローバルキャッシュ（プロセス内で共有）
var eatCache = &tracerCache{}

// Handle は PostToolUse 環境変数からトレースレコードを構築して JSONL に追記する。
// r は未使用（環境変数から情報を取得）。
func (e *EmitAgentTrace) Handle(r io.Reader, w io.Writer) error {
	toolName := os.Getenv("CLAUDE_TOOL_NAME")
	toolInput := os.Getenv("CLAUDE_TOOL_INPUT")
	toolResult := os.Getenv("CLAUDE_TOOL_RESULT")
	sessionID := os.Getenv("CLAUDE_SESSION_ID")

	// Edit / Write / Task のみ対象
	if !eatIsSupportedTool(toolName) {
		return nil
	}

	repoRoot := e.RepoRoot
	if repoRoot == "" {
		repoRoot = pcsFindRepoRoot()
	}

	files := e.parseToolInput(toolName, toolInput, repoRoot)
	if len(files) == 0 && toolName != "Task" {
		return nil
	}

	// パスを相対パスに変換
	for i, f := range files {
		if filepath.IsAbs(f.Path) {
			rel, err := filepath.Rel(repoRoot, f.Path)
			if err == nil {
				files[i].Path = rel
			}
		}
	}

	rec := traceRecord{
		Version:   traceVersion,
		ID:        eatGenerateUUID(),
		Timestamp: e.getNow(),
		Tool:      toolName,
		Files:     files,
		Metadata:  make(map[string]interface{}),
	}

	if sessionID != "" {
		rec.Metadata["sessionId"] = sessionID
	}

	// VCS 情報
	if vcs := e.getVCSInfo(); vcs != nil {
		rec.VCS = vcs
	}

	// プロジェクトメタデータ
	meta := e.getProjectMetadata(repoRoot)
	for k, v := range meta {
		rec.Metadata[k] = v
	}

	// Attribution
	if attr := e.getAttribution(); attr != nil {
		rec.Attribution = attr
	}

	// Task ツール専用フィールド
	if toolName == "Task" {
		if m := e.extractTaskMetrics(toolResult); m != nil {
			rec.Metrics = m
		}
		e.extractTaskMetadata(toolInput, &rec)
	}

	stateDir := e.StateDir
	if stateDir == "" {
		stateDir = filepath.Join(repoRoot, ".claude", "state")
	}
	tracePath := filepath.Join(stateDir, "agent-trace.jsonl")

	if err := e.appendTrace(repoRoot, stateDir, tracePath, &rec); err != nil {
		// トレース失敗はサイレントに無視（ツール実行をブロックしない）
		_, _ = fmt.Fprintf(os.Stderr, "[agent-trace] %v\n", err)
	}

	// OTel エクスポート（fire-and-forget）。
	// wg.Wait() で完了を待つと collector が遅い場合に 3 秒ブロックする問題があった。
	// JSONL 書き込み（本来の目的）は上記の appendTrace で同期的に完了済みなので、
	// OTel POST はベストエフォートで goroutine に任せる。
	// OTel がない環境（大多数）は影響なし。
	// OTel がある環境ではプロセス終了時に goroutine が kill される可能性があるが、
	// これは JS 版の detached child process と同等の「ベストエフォート」動作。
	if endpoint := os.Getenv("OTEL_EXPORTER_OTLP_ENDPOINT"); endpoint != "" {
		go e.emitOtelSpan(endpoint, &rec)
	}

	return nil
}

// appendTrace はセキュリティチェックを行いトレースを追記する。
func (e *EmitAgentTrace) appendTrace(repoRoot, stateDir, tracePath string, rec *traceRecord) error {
	claudeDir := filepath.Join(repoRoot, ".claude")

	// .claude シンボリックリンクチェック
	if info, err := os.Lstat(claudeDir); err == nil && info.Mode()&os.ModeSymlink != 0 {
		return fmt.Errorf(".claude symlink detected, refusing to write trace")
	}

	// stateDir 作成・セキュリティチェック
	if info, err := os.Lstat(stateDir); err == nil {
		if info.Mode()&os.ModeSymlink != 0 {
			return fmt.Errorf("stateDir is symlink, refusing to write trace")
		}
		_ = os.Chmod(stateDir, 0700)
	} else {
		if err := os.MkdirAll(stateDir, 0700); err != nil {
			return fmt.Errorf("creating stateDir: %w", err)
		}
	}

	// tracePath シンボリックリンクチェック
	if info, err := os.Lstat(tracePath); err == nil {
		if info.Mode()&os.ModeSymlink != 0 {
			return fmt.Errorf("tracePath is symlink, refusing to write trace")
		}
		if !info.Mode().IsRegular() {
			return fmt.Errorf("tracePath is not a regular file")
		}
	}

	e.rotateIfNeeded(tracePath)

	line, err := json.Marshal(rec)
	if err != nil {
		return fmt.Errorf("marshaling trace record: %w", err)
	}

	f, err := os.OpenFile(tracePath, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0600)
	if err != nil {
		return fmt.Errorf("opening trace file: %w", err)
	}
	defer f.Close()

	// 既存ファイルの権限を 0600 に修正する（os.OpenFile の perm 引数は新規作成時のみ適用される）。
	// JS 版は open 後に fchmodSync していた。
	_ = f.Chmod(0600)

	// 開いた fd が通常ファイルであることを確認
	info, err := f.Stat()
	if err != nil || !info.Mode().IsRegular() {
		return fmt.Errorf("opened fd is not a regular file")
	}

	if _, err := fmt.Fprintf(f, "%s\n", line); err != nil {
		return fmt.Errorf("writing trace: %w", err)
	}
	return nil
}

// rotateIfNeeded はファイルサイズが上限を超えた場合にローテーションする。
func (e *EmitAgentTrace) rotateIfNeeded(tracePath string) {
	maxSize := e.MaxFileSize
	if maxSize == 0 {
		maxSize = eatMaxFileSizeDefault
	}
	maxGen := e.MaxGenerations
	if maxGen == 0 {
		maxGen = eatMaxGenerationsDefault
	}

	info, err := os.Stat(tracePath)
	if err != nil || info.Size() < maxSize {
		return
	}

	// ロックファイルで同時ローテーション防止
	lockPath := tracePath + ".lock"
	lockF, err := os.OpenFile(lockPath, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0600)
	if err != nil {
		return // 別プロセスがローテーション中
	}
	lockF.Close()
	defer os.Remove(lockPath)

	// サイズ再確認
	info, err = os.Stat(tracePath)
	if err != nil || info.Size() < maxSize {
		return
	}

	// 世代ローテーション
	for i := maxGen - 1; i >= 1; i-- {
		oldPath := fmt.Sprintf("%s.%d", tracePath, i)
		newPath := fmt.Sprintf("%s.%d", tracePath, i+1)
		if _, err := os.Stat(oldPath); err == nil {
			if i == maxGen-1 {
				_ = os.Remove(oldPath)
			} else {
				_ = os.Rename(oldPath, newPath)
			}
		}
	}
	_ = os.Rename(tracePath, tracePath+".1")
}

// parseToolInput はツール入力からファイル情報を抽出する。
func (e *EmitAgentTrace) parseToolInput(toolName, toolInput, repoRoot string) []traceFile {
	if toolInput == "" {
		return nil
	}

	var input map[string]interface{}
	if err := json.Unmarshal([]byte(toolInput), &input); err != nil {
		return nil
	}

	var files []traceFile

	switch toolName {
	case "Edit":
		if fp, ok := input["file_path"].(string); ok && fp != "" {
			if eatIsPathWithinRepo(fp, repoRoot) {
				files = append(files, traceFile{Path: fp, Action: "modify", Range: "unknown"})
			}
		}
	case "Write":
		// PostToolUse 時点ではファイルが既に書き込まれているため os.Stat は常に成功し
		// create/modify を区別できない。tool_name ベースで判定する。
		// Write = 新規作成、Edit/MultiEdit = 既存ファイルの修正。
		if fp, ok := input["file_path"].(string); ok && fp != "" {
			if eatIsPathWithinRepo(fp, repoRoot) {
				files = append(files, traceFile{Path: fp, Action: "create", Range: "unknown"})
			}
		}
	case "MultiEdit":
		if fp, ok := input["file_path"].(string); ok && fp != "" {
			if eatIsPathWithinRepo(fp, repoRoot) {
				files = append(files, traceFile{Path: fp, Action: "modify", Range: "unknown"})
			}
		}
	}

	return files
}

// extractTaskMetadata は Task ツール入力からメタデータを抽出する。
func (e *EmitAgentTrace) extractTaskMetadata(toolInput string, rec *traceRecord) {
	if toolInput == "" {
		return
	}
	var input map[string]interface{}
	if err := json.Unmarshal([]byte(toolInput), &input); err != nil {
		return
	}
	if taskID, ok := input["task_id"].(string); ok && taskID != "" {
		rec.Metadata["taskId"] = taskID
	}
	if subagentType, ok := input["subagent_type"].(string); ok && subagentType != "" {
		rec.Metadata["subagentType"] = subagentType
		rec.Metadata["agentRole"] = eatNormalizeAgentRole(subagentType)
	} else if agentName, ok := input["agent_name"].(string); ok && agentName != "" {
		rec.Metadata["agentRole"] = eatNormalizeAgentRole(agentName)
	}
}

// extractTaskMetrics は Task ツール結果からメトリクスを抽出する。
func (e *EmitAgentTrace) extractTaskMetrics(toolResult string) *traceMetrics {
	if toolResult == "" {
		return nil
	}
	var result map[string]interface{}
	if err := json.Unmarshal([]byte(toolResult), &result); err != nil {
		return nil
	}
	metricsRaw, ok := result["metrics"].(map[string]interface{})
	if !ok {
		return nil
	}

	m := &traceMetrics{}
	hasValue := false

	if tc, ok := metricsRaw["tokenCount"].(float64); ok {
		v := int64(tc)
		m.TokenCount = &v
		hasValue = true
	}
	if tu, ok := metricsRaw["toolUses"].(float64); ok {
		v := int64(tu)
		m.ToolUses = &v
		hasValue = true
	}
	if d, ok := metricsRaw["duration"].(float64); ok {
		m.Duration = &d
		hasValue = true
	}

	if !hasValue {
		return nil
	}
	return m
}

// getVCSInfo は Git 情報を返す（キャッシュ付き）。
func (e *EmitAgentTrace) getVCSInfo() *traceVCS {
	eatCache.mu.Lock()
	defer eatCache.mu.Unlock()

	if eatCache.vcsInfo != nil && time.Since(eatCache.vcsTime) < vcsCacheTTL {
		return eatCache.vcsInfo
	}

	vcs := eatFetchVCSInfo()
	eatCache.vcsInfo = vcs
	eatCache.vcsTime = time.Now()
	return vcs
}

// eatFetchVCSInfo は git status から VCS 情報を取得する。
func eatFetchVCSInfo() *traceVCS {
	out, err := eatRunGitCmd("status", "--porcelain=2", "-b", "-uno")
	if err != nil || out == "" {
		return nil
	}

	var revision, branch string
	dirty := false

	for _, line := range strings.Split(out, "\n") {
		if strings.HasPrefix(line, "# branch.oid ") {
			revision = strings.TrimPrefix(line, "# branch.oid ")
		} else if strings.HasPrefix(line, "# branch.head ") {
			branch = strings.TrimPrefix(line, "# branch.head ")
		} else if line != "" && !strings.HasPrefix(line, "#") {
			dirty = true
		}
	}

	if revision == "" || branch == "" {
		return nil
	}
	return &traceVCS{Revision: revision, Branch: branch, Dirty: dirty}
}

// getProjectMetadata はプロジェクトメタデータを返す（キャッシュ付き）。
func (e *EmitAgentTrace) getProjectMetadata(repoRoot string) map[string]string {
	eatCache.mu.Lock()
	defer eatCache.mu.Unlock()

	if eatCache.projMeta != nil && time.Since(eatCache.projMetaTime) < traceCacheTTL {
		return eatCache.projMeta
	}

	meta := map[string]string{
		"project":     eatGetProjectName(repoRoot),
		"projectType": eatDetectProjectType(repoRoot),
	}
	eatCache.projMeta = meta
	eatCache.projMetaTime = time.Now()
	return meta
}

// getAttribution はプラグイン帰属情報を返す（キャッシュ付き）。
func (e *EmitAgentTrace) getAttribution() *traceAttribution {
	eatCache.mu.Lock()
	defer eatCache.mu.Unlock()

	if eatCache.attr != nil && time.Since(eatCache.attrTime) < traceCacheTTL {
		return eatCache.attr
	}

	attr := eatFetchAttribution()
	eatCache.attr = attr
	eatCache.attrTime = time.Now()
	return attr
}

// eatFetchAttribution は plugin.json からプラグイン情報を読み込む。
func eatFetchAttribution() *traceAttribution {
	pluginRoot := os.Getenv("CLAUDE_PLUGIN_ROOT")
	if pluginRoot == "" {
		return nil
	}
	data, err := os.ReadFile(filepath.Join(pluginRoot, "plugin.json"))
	if err != nil {
		return nil
	}
	var pkg map[string]interface{}
	if err := json.Unmarshal(data, &pkg); err != nil {
		return nil
	}

	attr := &traceAttribution{
		Plugin:  getString(pkg, "name", "unknown"),
		Version: getString(pkg, "version", "unknown"),
	}
	if lic := getString(pkg, "license", ""); lic != "" {
		attr.License = lic
	}
	if author := getString(pkg, "author", ""); author != "" {
		attr.Author = author
	}
	return attr
}

// emitOtelSpan は OTel Span を OTLP HTTP エンドポイントに POST する。
// 呼び出し元は同期呼び出しを前提にする。HTTP client に 3s timeout が設定されているため
// 長時間ブロックしない。失敗はサイレントに無視する。
func (e *EmitAgentTrace) emitOtelSpan(otlpEndpoint string, rec *traceRecord) {
	serviceVersion := eatReadServiceVersion()
	spanJSON := eatBuildOtelSpanJSON(rec, serviceVersion)

	data, err := json.Marshal(spanJSON)
	if err != nil {
		return
	}

	url := strings.TrimRight(otlpEndpoint, "/") + "/v1/traces"

	client := e.HTTPClient
	if client == nil {
		client = &http.Client{Timeout: 3 * time.Second}
	}

	req, err := http.NewRequest("POST", url, bytes.NewReader(data))
	if err != nil {
		return
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := client.Do(req)
	if err != nil {
		_, _ = fmt.Fprintf(os.Stderr, "[agent-trace] otel export failed: %v\n", err)
		return
	}
	defer resp.Body.Close()

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		_, _ = fmt.Fprintf(os.Stderr, "[agent-trace] otel export HTTP %d -> %s\n", resp.StatusCode, url)
	}
}

// eatBuildOtelSpanJSON は OTel Span JSON を構築する。
func eatBuildOtelSpanJSON(rec *traceRecord, serviceVersion string) map[string]interface{} {
	endMs := int64(0)
	if t, err := time.Parse(time.RFC3339, rec.Timestamp); err == nil {
		endMs = t.UnixMilli()
	}
	endNano := fmt.Sprintf("%d000000", endMs)

	// UUID からトレース ID とスパン ID を導出
	uuidHex := strings.ReplaceAll(rec.ID, "-", "")
	traceID := uuidHex
	spanID := uuidHex[:16]

	var attributes []map[string]interface{}

	if taskID, ok := rec.Metadata["taskId"].(string); ok && taskID != "" {
		attributes = append(attributes, map[string]interface{}{
			"key":   "task.id",
			"value": map[string]string{"stringValue": taskID},
		})
	}
	if agentRole, ok := rec.Metadata["agentRole"].(string); ok && agentRole != "" {
		attributes = append(attributes, map[string]interface{}{
			"key":   "agent.type",
			"value": map[string]string{"stringValue": agentRole},
		})
	}
	if effort, ok := rec.Metadata["effort"].(string); ok && effort != "" {
		attributes = append(attributes, map[string]interface{}{
			"key":   "effort",
			"value": map[string]string{"stringValue": effort},
		})
	}
	attributes = append(attributes, map[string]interface{}{
		"key":   "tool.name",
		"value": map[string]string{"stringValue": rec.Tool},
	})
	if rec.VCS != nil && rec.VCS.Branch != "" {
		attributes = append(attributes, map[string]interface{}{
			"key":   "vcs.branch",
			"value": map[string]string{"stringValue": rec.VCS.Branch},
		})
	}
	if sessionID, ok := rec.Metadata["sessionId"].(string); ok && sessionID != "" {
		attributes = append(attributes, map[string]interface{}{
			"key":   "session.id",
			"value": map[string]string{"stringValue": sessionID},
		})
	}

	agentRole, _ := rec.Metadata["agentRole"].(string)
	spanName := "harness." + strings.ToLower(rec.Tool)
	if agentRole != "" {
		spanName = "harness." + agentRole
	}

	return map[string]interface{}{
		"resourceSpans": []map[string]interface{}{
			{
				"resource": map[string]interface{}{
					"attributes": []map[string]interface{}{
						{"key": "service.name", "value": map[string]string{"stringValue": "claude-code-harness"}},
						{"key": "service.version", "value": map[string]string{"stringValue": serviceVersion}},
					},
				},
				"scopeSpans": []map[string]interface{}{
					{
						"scope": map[string]interface{}{"name": "harness.agent"},
						"spans": []map[string]interface{}{
							{
								"traceId":           traceID,
								"spanId":            spanID,
								"name":              spanName,
								"kind":              1,
								"startTimeUnixNano": endNano,
								"endTimeUnixNano":   endNano,
								"attributes":        attributes,
							},
						},
					},
				},
			},
		},
	}
}

// eatReadServiceVersion は plugin.json または VERSION からバージョンを読み込む。
func eatReadServiceVersion() string {
	pluginRoot := os.Getenv("CLAUDE_PLUGIN_ROOT")
	if pluginRoot == "" {
		return "0.0.0"
	}

	if data, err := os.ReadFile(filepath.Join(pluginRoot, "plugin.json")); err == nil {
		var pkg map[string]interface{}
		if err := json.Unmarshal(data, &pkg); err == nil {
			if v, ok := pkg["version"].(string); ok && v != "" {
				return v
			}
		}
	}

	if data, err := os.ReadFile(filepath.Join(pluginRoot, "VERSION")); err == nil {
		return strings.TrimSpace(string(data))
	}

	return "0.0.0"
}

// eatGetProjectName はプロジェクト名を取得する。
func eatGetProjectName(repoRoot string) string {
	pkgPath := filepath.Join(repoRoot, "package.json")
	if data, err := os.ReadFile(pkgPath); err == nil {
		var pkg map[string]interface{}
		if err := json.Unmarshal(data, &pkg); err == nil {
			if name, ok := pkg["name"].(string); ok && name != "" {
				return name
			}
		}
	}
	return filepath.Base(repoRoot)
}

// eatDetectProjectType はプロジェクトタイプを検出する。
func eatDetectProjectType(repoRoot string) string {
	// JVM markers precede Node-family markers so a backend with frontend
	// tooling is not reduced to package.json. Language metadata comes from the
	// standard source layout; the Gradle DSL extension alone is not enough to
	// classify application sources as Kotlin.
	for _, marker := range []string{"pom.xml", "mvnw", "build.gradle.kts", "build.gradle", "gradlew"} {
		if _, err := os.Stat(filepath.Join(repoRoot, marker)); err == nil {
			return eatDetectJVMLanguage(repoRoot)
		}
	}

	checks := [][2]string{
		{"next.config.js", "nextjs"},
		{"next.config.ts", "nextjs"},
		{"nuxt.config.js", "nuxt"},
		{"nuxt.config.ts", "nuxt"},
		{"svelte.config.js", "svelte"},
		{"astro.config.mjs", "astro"},
		{"Cargo.toml", "rust"},
		{"go.mod", "go"},
		{"pyproject.toml", "python"},
		{"setup.py", "python"},
		{"requirements.txt", "python"},
		{"Gemfile", "ruby"},
		{"composer.json", "php"},
		{"package.json", "node"},
	}
	for _, check := range checks {
		if _, err := os.Stat(filepath.Join(repoRoot, check[0])); err == nil {
			return check[1]
		}
	}
	return "unknown"
}

func eatDetectJVMLanguage(repoRoot string) string {
	hasJava := eatHasProjectDir(repoRoot, "src/main/java") || eatHasProjectDir(repoRoot, "src/test/java")
	hasKotlin := eatHasProjectDir(repoRoot, "src/main/kotlin") || eatHasProjectDir(repoRoot, "src/test/kotlin")
	switch {
	case hasJava && hasKotlin:
		return "java-kotlin"
	case hasKotlin:
		return "kotlin"
	default:
		return "java"
	}
}

func eatHasProjectDir(repoRoot, relativePath string) bool {
	info, err := os.Stat(filepath.Join(repoRoot, relativePath))
	return err == nil && info.IsDir()
}

// eatNormalizeAgentRole はエージェント名を harness ロールに正規化する。
func eatNormalizeAgentRole(name string) string {
	v := strings.ToLower(strings.TrimSpace(name))
	if v == "" {
		return "unknown"
	}
	if strings.Contains(v, "review") {
		return "reviewer"
	}
	if strings.Contains(v, "lead") || strings.Contains(v, "planner") {
		return "lead"
	}
	if strings.Contains(v, "worker") || strings.Contains(v, "impl") {
		return "worker"
	}
	return v
}

// eatIsPathWithinRepo はパスがリポジトリ内かどうかを確認する。
func eatIsPathWithinRepo(filePath, repoRoot string) bool {
	if strings.Contains(filePath, "..") {
		return false
	}

	absPath := filePath
	if !filepath.IsAbs(filePath) {
		absPath = filepath.Join(repoRoot, filePath)
	}

	// リポジトリルートを実パスに解決
	resolvedRepo, err := filepath.EvalSymlinks(repoRoot)
	if err != nil {
		resolvedRepo = repoRoot
	}

	// ファイルが存在する場合は実パスで確認
	resolvedPath, err := filepath.EvalSymlinks(absPath)
	if err != nil {
		// ファイルが存在しない場合は親ディレクトリを確認
		parentDir := filepath.Dir(absPath)
		resolvedParent, err := filepath.EvalSymlinks(parentDir)
		if err != nil {
			resolvedPath = filepath.Clean(absPath)
		} else {
			resolvedPath = filepath.Join(resolvedParent, filepath.Base(absPath))
		}
	}

	return strings.HasPrefix(resolvedPath, resolvedRepo+string(filepath.Separator)) ||
		resolvedPath == resolvedRepo
}

// eatIsSupportedTool はトレース対象ツールかどうかを返す。
func eatIsSupportedTool(toolName string) bool {
	return toolName == "Edit" || toolName == "Write" || toolName == "MultiEdit" || toolName == "Task"
}

// eatGenerateUUID は UUID v4 を生成する。
func eatGenerateUUID() string {
	var b [16]byte
	if _, err := rand.Read(b[:]); err != nil {
		// フォールバック: タイムスタンプベース
		ts := time.Now().UnixNano()
		for i := 0; i < 8; i++ {
			b[i] = byte(ts >> (i * 8))
		}
	}
	// UUID v4 フォーマット
	b[6] = (b[6] & 0x0f) | 0x40
	b[8] = (b[8] & 0x3f) | 0x80
	return fmt.Sprintf("%08x-%04x-%04x-%04x-%12x",
		b[0:4], b[4:6], b[6:8], b[8:10], b[10:16])
}

// getNow は現在時刻文字列を返す。
func (e *EmitAgentTrace) getNow() string {
	if e.Now != nil {
		return e.Now()
	}
	return time.Now().UTC().Format(time.RFC3339)
}

// getString はマップから文字列を取得する。見つからない場合はデフォルト値を返す。
func getString(m map[string]interface{}, key, defaultVal string) string {
	if v, ok := m[key].(string); ok && v != "" {
		return v
	}
	return defaultVal
}

// eatRunGitCmd は git コマンドを実行して stdout を返す。
func eatRunGitCmd(args ...string) (string, error) {
	out, err := gitport.Output("", args...)
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(out), nil
}
