package session

import (
	"bufio"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

// MonitorHandler は SessionStart フックハンドラ（プロジェクト状態収集）。
// セッション開始時にプロジェクト状態を収集し、session.json と tooling-policy.json を生成する。
//
// shell 版: scripts/session-monitor.sh
type MonitorHandler struct {
	// StateDir はステートディレクトリのパス。空の場合は cwd から推定する。
	StateDir string
	// PlansFile は Plans.md のパス。空の場合は projectRoot/Plans.md を使う。
	PlansFile string
	// now は現在時刻の注入関数（テスト用）。nil の場合は time.Now() を使う。
	now func() time.Time
	// MemHealthCommand は harness-mem ヘルスチェック関数（テスト注入用）。
	// nil の場合は本番デフォルト実装（bin/harness mem health）を使う。
	MemHealthCommand func(ctx context.Context) (healthy bool, reason string, err error)
}

// monitorInput は SessionStart フックの stdin JSON。
type monitorInput struct {
	SessionID string `json:"session_id,omitempty"`
	CWD       string `json:"cwd,omitempty"`
}

// sessionStateJSON は session.json の完全なスキーマ。
type sessionStateJSON struct {
	SessionID          string            `json:"session_id"`
	ParentID           interface{}       `json:"parent_session_id"`
	State              string            `json:"state"`
	StateVersion       int               `json:"state_version"`
	StartedAt          string            `json:"started_at"`
	UpdatedAt          string            `json:"updated_at"`
	ResumeToken        string            `json:"resume_token"`
	EventSeq           int               `json:"event_seq"`
	LastEventID        string            `json:"last_event_id"`
	ForkCount          int               `json:"fork_count"`
	Orchestration      orchestrationJSON `json:"orchestration"`
	CWD                string            `json:"cwd"`
	ProjectName        string            `json:"project_name"`
	PromptSeq          int               `json:"prompt_seq"`
	Git                gitStateJSON      `json:"git"`
	Plans              plansStateJSON    `json:"plans"`
	HarnessMem         harnessMemJSON    `json:"harness_mem"`
	ChangesThisSession []interface{}     `json:"changes_this_session"`
}

// harnessMemJSON は session.json の harness_mem フィールドのスキーマ。
type harnessMemJSON struct {
	Healthy     bool   `json:"healthy"`
	LastChecked string `json:"last_checked"`
	LastError   string `json:"last_error"`
}

type orchestrationJSON struct {
	MaxStateRetries     int `json:"max_state_retries"`
	RetryBackoffSeconds int `json:"retry_backoff_seconds"`
}

type gitStateJSON struct {
	Branch             string `json:"branch"`
	UncommittedChanges int    `json:"uncommitted_changes"`
	LastCommit         string `json:"last_commit"`
}

type plansStateJSON struct {
	Exists         bool  `json:"exists"`
	LastModified   int64 `json:"last_modified"`
	WIPTasks       int   `json:"wip_tasks"`
	TODOTasks      int   `json:"todo_tasks"`
	PendingTasks   int   `json:"pending_tasks"`
	CompletedTasks int   `json:"completed_tasks"`
}

// toolingPolicyJSON は tooling-policy.json のスキーマ（簡略版）。
// LSP/MCP 検出の重い外部コマンド依存を避け、基本情報のみを生成する。
type toolingPolicyJSON struct {
	LSP     lspPolicyJSON    `json:"lsp"`
	Plugins pluginPolicyJSON `json:"plugins"`
	MCP     mcpPolicyJSON    `json:"mcp"`
	Skills  skillsPolicyJSON `json:"skills"`
}

type lspPolicyJSON struct {
	Available           bool            `json:"available"`
	Plugins             string          `json:"plugins"`
	AvailableByExt      map[string]bool `json:"available_by_ext"`
	LastUsedPromptSeq   int             `json:"last_used_prompt_seq"`
	LastUsedToolName    string          `json:"last_used_tool_name"`
	UsedSinceLastPrompt bool            `json:"used_since_last_prompt"`
}

type pluginPolicyJSON struct {
	Installed       *int   `json:"installed"`
	EnabledEstimate *int   `json:"enabled_estimate"`
	Source          string `json:"source"`
}

type mcpPolicyJSON struct {
	Configured      *int     `json:"configured"`
	Disabled        *int     `json:"disabled"`
	EnabledEstimate *int     `json:"enabled_estimate"`
	Sources         []string `json:"sources"`
}

type skillsPolicyJSON struct {
	Index            []interface{} `json:"index"`
	DecisionRequired bool          `json:"decision_required"`
}

// Handle は stdin から SessionStart ペイロードを読み取り、
// session.json と tooling-policy.json を生成して stdout に状態サマリーを書き出す。
func (h *MonitorHandler) Handle(r io.Reader, w io.Writer) error {
	data, _ := io.ReadAll(r)

	var inp monitorInput
	if len(data) > 0 {
		_ = json.Unmarshal(data, &inp)
	}

	projectRoot := resolveProjectRoot(inp.CWD)
	if projectRoot == "" {
		cwd, _ := os.Getwd()
		projectRoot = cwd
	}

	stateDir := h.StateDir
	if stateDir == "" {
		stateDir = filepath.Join(projectRoot, ".claude", "state")
	}

	// シンボリックリンクチェック
	if isSymlink(stateDir) || isSymlink(filepath.Dir(stateDir)) {
		fmt.Fprintf(os.Stderr, "[session-monitor] Warning: symlink detected in state directory path, aborting\n")
		return nil
	}

	if err := os.MkdirAll(stateDir, 0700); err != nil {
		return nil
	}

	plansFile := h.PlansFile
	if plansFile == "" {
		plansFile = filepath.Join(projectRoot, "Plans.md")
	}

	now := h.currentTime()
	nowStr := now.UTC().Format(time.RFC3339)

	// プロジェクト情報を収集
	projectName := filepath.Base(projectRoot)
	gitState := h.collectGitState(projectRoot)
	plansState := h.collectPlansState(plansFile)

	// 48.1.1: harness-mem ヘルスチェック
	memHealthy, memReason, _ := h.checkMemHealth(projectRoot)
	memState := harnessMemJSON{
		Healthy:     memHealthy,
		LastChecked: nowStr,
		LastError:   memReason,
	}
	if memHealthy {
		memState.LastError = ""
	}

	// session.json を生成（resume/新規を判定）
	sessionFile := filepath.Join(stateDir, "session.json")
	h.generateSessionFile(sessionFile, projectRoot, projectName, nowStr, gitState, plansState, memState)

	// tooling-policy.json を生成
	policyFile := filepath.Join(stateDir, "tooling-policy.json")
	h.generateToolingPolicy(policyFile)

	// サマリーを stdout に出力
	h.writeSummary(w, projectName, gitState, plansState)

	// 48.1.1: harness-mem unhealthy 警告
	if !memHealthy {
		reason := memReason
		if reason == "" {
			reason = "unknown"
		}
		fmt.Fprintf(w, "⚠️ harness-mem unhealthy: %s\n", reason)
	}

	// 48.1.2: advisor/reviewer drift 検知
	driftLines := h.collectDrift(stateDir, projectRoot)
	for _, line := range driftLines {
		fmt.Fprintln(w, line)
	}

	// 48.1.3: Plans.md 閾値判定
	if warning := h.checkPlansDrift(plansState, projectRoot); warning != "" {
		fmt.Fprintln(w, warning)
	}

	return nil
}

// collectGitState は git 情報を収集する。
func (h *MonitorHandler) collectGitState(projectRoot string) gitStateJSON {
	if !isGitRepository(projectRoot) {
		return gitStateJSON{
			Branch:             "(no git)",
			UncommittedChanges: 0,
			LastCommit:         "none",
		}
	}

	return gitStateJSON{
		Branch:             h.readGitBranch(projectRoot),
		UncommittedChanges: 0, // 重い操作を避けるため 0 固定
		LastCommit:         h.readGitLastCommit(projectRoot),
	}
}

// readGitBranch は git コマンド経由でブランチ名を読み取る。
func (h *MonitorHandler) readGitBranch(projectRoot string) string {
	branch, err := runGit(projectRoot, "rev-parse", "--abbrev-ref", "HEAD")
	if err == nil && branch != "" {
		return branch
	}

	sha, err := runGit(projectRoot, "rev-parse", "--short=7", "HEAD")
	if err == nil && sha != "" {
		return sha
	}
	return "unknown"
}

// readGitLastCommit は git コマンド経由で最新コミット SHA を読み取る。
func (h *MonitorHandler) readGitLastCommit(projectRoot string) string {
	sha, err := runGit(projectRoot, "rev-parse", "--short=7", "HEAD")
	if err == nil && sha != "" {
		return sha
	}
	return "none"
}

func isGitRepository(projectRoot string) bool {
	if _, err := runGit(projectRoot, "rev-parse", "--git-dir"); err != nil {
		return false
	}
	return true
}

func runGit(projectRoot string, args ...string) (string, error) {
	cmd := exec.Command("git", args...)
	cmd.Dir = projectRoot
	output, err := cmd.Output()
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(string(output)), nil
}

// collectPlansState は Plans.md の状態を収集する。
func (h *MonitorHandler) collectPlansState(plansFile string) plansStateJSON {
	fi, err := os.Stat(plansFile)
	if err != nil {
		return plansStateJSON{Exists: false}
	}

	wipCount := countMatches(plansFile, "cc:WIP")
	todoCount := countMatches(plansFile, "cc:TODO")
	pendingCount := countMatches(plansFile, "pm:依頼中", "cursor:依頼中")
	completedCount := countMatches(plansFile, "cc:完了")

	return plansStateJSON{
		Exists:         true,
		LastModified:   fi.ModTime().Unix(),
		WIPTasks:       wipCount,
		TODOTasks:      todoCount,
		PendingTasks:   pendingCount,
		CompletedTasks: completedCount,
	}
}

// generateSessionFile は session.json を生成する（resume/新規を判定）。
func (h *MonitorHandler) generateSessionFile(
	sessionFile, projectRoot, projectName, nowStr string,
	git gitStateJSON,
	plans plansStateJSON,
	mem harnessMemJSON,
) {
	if isSymlink(sessionFile) {
		return
	}

	resumeMode := false
	var existing sessionStateJSON

	// 既存セッションを読み込む
	if data, err := os.ReadFile(sessionFile); err == nil {
		if json.Unmarshal(data, &existing) == nil {
			// ended_at が設定されていないなら resume モード
			// ここでは EventSeq > 0 かつ State が active 系なら resume
			if existing.SessionID != "" && existing.State != "stopped" && existing.State != "completed" && existing.State != "failed" {
				resumeMode = true
			}
		}
	}

	forkMode := os.Getenv("HARNESS_SESSION_FORK") == "true"
	if forkMode {
		resumeMode = false
	}

	var sess sessionStateJSON

	if resumeMode {
		// 既存セッションを更新
		existing.CWD = projectRoot
		existing.ProjectName = projectName
		existing.UpdatedAt = nowStr
		existing.Git = git
		existing.Plans = plans
		existing.HarnessMem = mem
		existing.StateVersion = 1
		sess = existing
	} else {
		// 新規セッション
		sessionID := fmt.Sprintf("session-%d", time.Now().UnixNano())
		resumeToken := fmt.Sprintf("resume-%d", time.Now().UnixNano())
		parentID := interface{}(nil)
		if forkMode && existing.SessionID != "" {
			parentID = existing.SessionID
		}

		sess = sessionStateJSON{
			SessionID:    sessionID,
			ParentID:     parentID,
			State:        "initialized",
			StateVersion: 1,
			StartedAt:    nowStr,
			UpdatedAt:    nowStr,
			ResumeToken:  resumeToken,
			EventSeq:     0,
			LastEventID:  "",
			ForkCount:    0,
			Orchestration: orchestrationJSON{
				MaxStateRetries:     3,
				RetryBackoffSeconds: 10,
			},
			CWD:                projectRoot,
			ProjectName:        projectName,
			PromptSeq:          0,
			Git:                git,
			Plans:              plans,
			HarnessMem:         mem,
			ChangesThisSession: []interface{}{},
		}
	}

	data, err := json.MarshalIndent(sess, "", "  ")
	if err != nil {
		return
	}

	_ = writeFileAtomic(sessionFile, append(data, '\n'), 0600)
}

// generateToolingPolicy は tooling-policy.json を生成する。
// 重い外部コマンド依存（claude plugin list, MCP サーバー検索等）は避け、
// 基本的なスキャフォールドのみを生成する。
func (h *MonitorHandler) generateToolingPolicy(policyFile string) {
	if isSymlink(policyFile) {
		return
	}

	policy := toolingPolicyJSON{
		LSP: lspPolicyJSON{
			Available:           false,
			Plugins:             "",
			AvailableByExt:      map[string]bool{},
			LastUsedPromptSeq:   0,
			LastUsedToolName:    "",
			UsedSinceLastPrompt: false,
		},
		Plugins: pluginPolicyJSON{
			Installed:       nil,
			EnabledEstimate: nil,
			Source:          "",
		},
		MCP: mcpPolicyJSON{
			Configured:      nil,
			Disabled:        nil,
			EnabledEstimate: nil,
			Sources:         []string{},
		},
		Skills: skillsPolicyJSON{
			Index:            []interface{}{},
			DecisionRequired: false,
		},
	}

	data, err := json.MarshalIndent(policy, "", "  ")
	if err != nil {
		return
	}

	_ = writeFileAtomic(policyFile, append(data, '\n'), 0644)
}

// writeSummary はセッション状態サマリーを w に書き出す。
func (h *MonitorHandler) writeSummary(w io.Writer, projectName string, git gitStateJSON, plans plansStateJSON) {
	fmt.Fprintln(w, "")
	fmt.Fprintln(w, "セッション開始 - プロジェクト状態")
	fmt.Fprintln(w, strings.Repeat("─", 36))
	fmt.Fprintf(w, "プロジェクト: %s\n", projectName)
	fmt.Fprintf(w, "ブランチ: %s\n", git.Branch)

	if plans.Exists {
		total := plans.WIPTasks + plans.TODOTasks + plans.PendingTasks
		if total > 0 {
			fmt.Fprintf(w, "Plans.md: WIP %d件 / TODO %d件\n", plans.WIPTasks, plans.TODOTasks+plans.PendingTasks)
		}
	}

	fmt.Fprintln(w, strings.Repeat("─", 36))
	fmt.Fprintln(w, "")
}

// currentTime は現在時刻を返す。
func (h *MonitorHandler) currentTime() time.Time {
	if h.now != nil {
		return h.now()
	}
	return time.Now()
}

// formatInt は int をポインタで返す（tooling-policy の null 値用）。
func formatInt(v int) *int {
	return &v
}

// atoi は文字列を int に変換する。
func atoi(s string) int {
	v, _ := strconv.Atoi(strings.TrimSpace(s))
	return v
}

// ---------------------------------------------------------------------------
// 48.1.1: harness-mem ヘルスチェック
// ---------------------------------------------------------------------------

// resolveHarnessBinary は harness 実行バイナリの信頼可能なパスを返す。
// 優先順位:
//  1. os.Executable() — 現在実行中の harness binary（最も信頼可能）
//  2. CLAUDE_PLUGIN_ROOT/bin/harness — plugin インストール済みパス
//  3. exec.LookPath("harness") — PATH 上の harness
//
// projectRoot/bin/harness は信頼境界外（repo 内に悪意ある binary が混入する
// 可能性がある）のため解決対象に含めない。
func resolveHarnessBinary() (string, error) {
	if exe, err := os.Executable(); err == nil && exe != "" {
		return exe, nil
	}
	if root := os.Getenv("CLAUDE_PLUGIN_ROOT"); root != "" {
		candidate := filepath.Join(root, "bin", "harness")
		if _, statErr := os.Stat(candidate); statErr == nil {
			return candidate, nil
		}
	}
	if lookPath, lookErr := exec.LookPath("harness"); lookErr == nil {
		return lookPath, nil
	}
	return "", errors.New("harness binary not found")
}

// checkMemHealth は harness-mem のヘルスを検査する。
// h.MemHealthCommand が設定されている場合はそれを使う（テスト注入用）。
// nil の場合は本番デフォルト実装（bin/harness mem health を exec）を使う。
func (h *MonitorHandler) checkMemHealth(projectRoot string) (healthy bool, reason string, err error) {
	if h.MemHealthCommand != nil {
		ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
		defer cancel()
		return h.MemHealthCommand(ctx)
	}
	return h.defaultMemHealthCheck(projectRoot)
}

// defaultMemHealthCheck は bin/harness mem health を exec して結果を返す。
// projectRoot 引数は signature 後方互換のため保持しているが使用しない。
// 過去実装は projectRoot/bin/harness を exec していたが、repo 内に悪意ある
// binary が混入した場合に guardrail を bypass されるリスクがあった。
// v4.3.1 からは os.Executable() → CLAUDE_PLUGIN_ROOT/bin/harness → PATH
// の優先順で解決する（いずれも信頼可能なインストール済みパス）。
func (h *MonitorHandler) defaultMemHealthCheck(_ string) (healthy bool, reason string, err error) {
	binaryPath, resolveErr := resolveHarnessBinary()
	if resolveErr != nil {
		// バイナリが見つからない場合はスキップ（監視全体は止めない）
		return true, "", nil
	}

	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()

	cmd := exec.CommandContext(ctx, binaryPath, "mem", "health")
	output, cmdErr := cmd.Output()

	// タイムアウト・exec 失敗
	if ctx.Err() != nil {
		return false, "timeout", ctx.Err()
	}
	if cmdErr != nil {
		// exit code 1 は unhealthy を意味する（正常な失敗）
		// JSON 出力があれば解析する
		if len(output) > 0 {
			var result struct {
				Healthy bool   `json:"healthy"`
				Reason  string `json:"reason"`
			}
			if jsonErr := json.Unmarshal(output, &result); jsonErr == nil {
				return result.Healthy, result.Reason, nil
			}
		}
		return false, cmdErr.Error(), cmdErr
	}

	// exit 0: JSON をパース
	var result struct {
		Healthy bool   `json:"healthy"`
		Reason  string `json:"reason"`
	}
	if jsonErr := json.Unmarshal(output, &result); jsonErr != nil {
		return true, "", nil // パース失敗は楽観的に healthy 扱い
	}
	return result.Healthy, result.Reason, nil
}

// ---------------------------------------------------------------------------
// 48.1.2: advisor/reviewer drift 検知
// ---------------------------------------------------------------------------

// advisorEventJSON は session.events.jsonl の各行のスキーマ（最低限）。
type advisorEventJSON struct {
	SchemaVersion string `json:"schema_version"`
	TaskID        string `json:"task_id"`
	TriggerHash   string `json:"trigger_hash"`
	Ts            string `json:"ts"`
}

// collectDrift は session.events.jsonl を末尾 200 行スキャンして
// TTL 超過の未応答 advisor/reviewer request を検出し、警告行を返す。
func (h *MonitorHandler) collectDrift(stateDir, projectRoot string) []string {
	eventsFile := filepath.Join(stateDir, "session.events.jsonl")
	ttl := h.readAdvisorTTL(projectRoot)
	now := h.currentTime()

	f, err := os.Open(eventsFile)
	if err != nil {
		return nil
	}
	defer f.Close()

	// 末尾 200 行を収集
	var lines []string
	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		lines = append(lines, scanner.Text())
	}
	if len(lines) > 200 {
		lines = lines[len(lines)-200:]
	}

	// request と response を収集
	type requestInfo struct {
		ts    time.Time
		hasTs bool
		seq   int // ts がない場合の出現順
	}
	advisorRequests := make(map[string]requestInfo)  // key: task_id+trigger_hash
	advisorResponses := make(map[string]bool)         // key: task_id+trigger_hash
	reviewRequests := make(map[string]requestInfo)    // key: task_id+trigger_hash
	reviewResponses := make(map[string]bool)          // key: task_id+trigger_hash

	for seq, line := range lines {
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}
		var ev advisorEventJSON
		if err := json.Unmarshal([]byte(line), &ev); err != nil {
			continue
		}

		key := makeEventKey(ev.TaskID, ev.TriggerHash)

		var ts time.Time
		hasTs := false
		if ev.Ts != "" {
			if parsed, parseErr := time.Parse(time.RFC3339, ev.Ts); parseErr == nil {
				ts = parsed
				hasTs = true
			}
		}

		switch ev.SchemaVersion {
		case "advisor-request.v1":
			advisorRequests[key] = requestInfo{ts: ts, hasTs: hasTs, seq: seq}
		case "advisor-response.v1":
			advisorResponses[key] = true
		case "worker-report.v1", "review-request.v1":
			reviewRequests[key] = requestInfo{ts: ts, hasTs: hasTs, seq: seq}
		case "review-result.v1":
			reviewResponses[key] = true
		}
	}

	var warnings []string

	// advisor drift: 未応答 request で TTL 超過の最古 1 件のみ表示
	var oldestAdvisorKey string
	var oldestAdvisorElapsed int64 = -1
	var oldestAdvisorID string

	for key, req := range advisorRequests {
		if advisorResponses[key] {
			continue // 応答済みはスキップ
		}
		if !req.hasTs {
			continue // ts がない場合はスキップ
		}
		elapsed := int64(now.Sub(req.ts).Seconds())
		if elapsed <= ttl {
			continue // TTL 未満はスキップ
		}
		if oldestAdvisorElapsed < 0 || elapsed > oldestAdvisorElapsed {
			oldestAdvisorElapsed = elapsed
			oldestAdvisorKey = key
			// request_id: task_id か trigger_hash の short hash
			parts := strings.SplitN(key, ":", 2)
			if parts[0] != "" {
				oldestAdvisorID = parts[0]
			} else if len(parts) > 1 {
				h := parts[1]
				if len(h) > 7 {
					h = h[:7]
				}
				oldestAdvisorID = h
			}
		}
	}
	_ = oldestAdvisorKey
	if oldestAdvisorElapsed >= 0 {
		warnings = append(warnings,
			fmt.Sprintf("⚠️ advisor drift: request_id=%s, waiting %ds", oldestAdvisorID, oldestAdvisorElapsed))
	}

	// reviewer drift: 未応答 review request で TTL 超過
	var oldestReviewerKey string
	var oldestReviewerElapsed int64 = -1
	var oldestReviewerID string

	for key, req := range reviewRequests {
		if reviewResponses[key] {
			continue
		}
		if !req.hasTs {
			continue
		}
		elapsed := int64(now.Sub(req.ts).Seconds())
		if elapsed <= ttl {
			continue
		}
		if oldestReviewerElapsed < 0 || elapsed > oldestReviewerElapsed {
			oldestReviewerElapsed = elapsed
			oldestReviewerKey = key
			parts := strings.SplitN(key, ":", 2)
			if parts[0] != "" {
				oldestReviewerID = parts[0]
			} else if len(parts) > 1 {
				rh := parts[1]
				if len(rh) > 7 {
					rh = rh[:7]
				}
				oldestReviewerID = rh
			}
		}
	}
	_ = oldestReviewerKey
	if oldestReviewerElapsed >= 0 {
		warnings = append(warnings,
			fmt.Sprintf("⚠️ reviewer drift: request_id=%s, waiting %ds", oldestReviewerID, oldestReviewerElapsed))
	}

	return warnings
}

// makeEventKey は task_id と trigger_hash からイベントキーを生成する。
func makeEventKey(taskID, triggerHash string) string {
	return taskID + ":" + triggerHash
}

// readAdvisorTTL は config.yaml から orchestration.advisor_ttl_seconds を読み取る。
// 失敗時はデフォルト値 600 を返す。
func (h *MonitorHandler) readAdvisorTTL(projectRoot string) int64 {
	const defaultTTL = int64(600)

	configPath := filepath.Clean(filepath.Join(projectRoot, ".claude-code-harness.config.yaml"))
	f, err := os.Open(configPath)
	if err != nil {
		return defaultTTL
	}
	defer f.Close()

	inOrchestration := false
	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		line := scanner.Text()
		trimmed := strings.TrimSpace(line)

		// セクション検出（インデントなし）
		if !strings.HasPrefix(line, " ") && !strings.HasPrefix(line, "\t") {
			inOrchestration = strings.TrimRight(trimmed, ":") == "orchestration"
			continue
		}

		if !inOrchestration {
			continue
		}

		if strings.Contains(trimmed, "advisor_ttl_seconds:") {
			parts := strings.SplitN(trimmed, ":", 2)
			if len(parts) == 2 {
				val := strings.TrimSpace(parts[1])
				if v, err := strconv.ParseInt(val, 10, 64); err == nil {
					return v
				}
			}
		}
	}
	return defaultTTL
}

// ---------------------------------------------------------------------------
// 48.1.3: Plans.md 閾値判定
// ---------------------------------------------------------------------------

// checkPlansDrift は Plans.md の状態が閾値を超えているか検査し、
// 超えていれば警告行（⚠️ plans drift: ...）を返す。超えていなければ空文字を返す。
func (h *MonitorHandler) checkPlansDrift(plans plansStateJSON, projectRoot string) string {
	if !plans.Exists {
		return ""
	}

	wipThreshold, staleHours := h.readPlansDriftConfig(projectRoot)
	now := h.currentTime()

	wipHit := plans.WIPTasks >= wipThreshold

	lastMod := time.Unix(plans.LastModified, 0)
	elapsedHours := int64(now.Sub(lastMod).Hours())
	staleHit := elapsedHours >= staleHours

	if !wipHit && !staleHit {
		return ""
	}

	return fmt.Sprintf("⚠️ plans drift: WIP=%d, stale_for=%dh", plans.WIPTasks, elapsedHours)
}

// readPlansDriftConfig は config.yaml から monitor.plans_drift セクションを読み取る。
// 失敗時はデフォルト値（wip_threshold=5, stale_hours=24）を返す。
func (h *MonitorHandler) readPlansDriftConfig(projectRoot string) (wipThreshold int, staleHours int64) {
	wipThreshold = 5
	staleHours = 24

	configPath := filepath.Clean(filepath.Join(projectRoot, ".claude-code-harness.config.yaml"))
	f, err := os.Open(configPath)
	if err != nil {
		return
	}
	defer f.Close()

	inMonitor := false
	inPlansDrift := false

	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		line := scanner.Text()
		trimmed := strings.TrimSpace(line)

		// トップレベルセクション検出（インデントなし）
		if !strings.HasPrefix(line, " ") && !strings.HasPrefix(line, "\t") {
			sectionName := strings.TrimRight(trimmed, ":")
			inMonitor = sectionName == "monitor"
			inPlansDrift = false
			continue
		}

		if !inMonitor {
			continue
		}

		// plans_drift サブセクション検出（1レベルインデント）
		if strings.HasPrefix(line, "  ") && !strings.HasPrefix(line, "    ") {
			subSection := strings.TrimRight(trimmed, ":")
			inPlansDrift = subSection == "plans_drift"
			continue
		}

		if !inPlansDrift {
			continue
		}

		// 2レベルインデントのキー
		if strings.Contains(trimmed, "wip_threshold:") {
			parts := strings.SplitN(trimmed, ":", 2)
			if len(parts) == 2 {
				if v, err := strconv.Atoi(strings.TrimSpace(parts[1])); err == nil {
					wipThreshold = v
				}
			}
		} else if strings.Contains(trimmed, "stale_hours:") {
			parts := strings.SplitN(trimmed, ":", 2)
			if len(parts) == 2 {
				if v, err := strconv.ParseInt(strings.TrimSpace(parts[1]), 10, 64); err == nil {
					staleHours = v
				}
			}
		}
	}
	return
}
