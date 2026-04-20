package session

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func TestMonitorHandler_GeneratesSessionFile(t *testing.T) {
	dir := t.TempDir()
	stateDir := filepath.Join(dir, "state")
	plansFile := filepath.Join(dir, "Plans.md")

	// Plans.md を作成
	plans := "| t1 | cc:WIP |\n| t2 | cc:TODO |\n"
	if err := os.WriteFile(plansFile, []byte(plans), 0644); err != nil {
		t.Fatal(err)
	}

	h := &MonitorHandler{
		StateDir:  stateDir,
		PlansFile: plansFile,
		now:       func() time.Time { return time.Date(2026, 4, 5, 12, 0, 0, 0, time.UTC) },
	}

	inp := `{"cwd":"` + dir + `"}`
	var out bytes.Buffer
	if err := h.Handle(strings.NewReader(inp), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	// session.json が作成されたか
	sessionFile := filepath.Join(stateDir, "session.json")
	data, err := os.ReadFile(sessionFile)
	if err != nil {
		t.Fatalf("session.json not created: %v", err)
	}

	var sess sessionStateJSON
	if err := json.Unmarshal(data, &sess); err != nil {
		t.Fatalf("invalid session.json: %v", err)
	}

	if sess.State != "initialized" {
		t.Errorf("expected state=initialized, got %q", sess.State)
	}
	if sess.SessionID == "" {
		t.Errorf("expected non-empty session_id")
	}
	if sess.Plans.WIPTasks != 1 {
		t.Errorf("expected wip_tasks=1, got %d", sess.Plans.WIPTasks)
	}
	if sess.Plans.TODOTasks != 1 {
		t.Errorf("expected todo_tasks=1, got %d", sess.Plans.TODOTasks)
	}
}

func TestMonitorHandler_GeneratesToolingPolicy(t *testing.T) {
	dir := t.TempDir()
	stateDir := filepath.Join(dir, "state")

	h := &MonitorHandler{
		StateDir:  stateDir,
		PlansFile: filepath.Join(dir, "Plans.md"),
	}

	var out bytes.Buffer
	if err := h.Handle(strings.NewReader(`{"cwd":"`+dir+`"}`), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	policyFile := filepath.Join(stateDir, "tooling-policy.json")
	data, err := os.ReadFile(policyFile)
	if err != nil {
		t.Fatalf("tooling-policy.json not created: %v", err)
	}

	var policy toolingPolicyJSON
	if err := json.Unmarshal(data, &policy); err != nil {
		t.Fatalf("invalid tooling-policy.json: %v\nraw: %s", err, data)
	}

	if policy.LSP.Available {
		t.Errorf("expected lsp.available=false")
	}
	if policy.Skills.DecisionRequired {
		t.Errorf("expected skills.decision_required=false")
	}
}

func TestMonitorHandler_ResumesExistingSession(t *testing.T) {
	dir := t.TempDir()
	stateDir := filepath.Join(dir, "state")
	if err := os.MkdirAll(stateDir, 0700); err != nil {
		t.Fatal(err)
	}

	// 既存セッションを作成
	existingSession := sessionStateJSON{
		SessionID:          "session-existing",
		State:              "running",
		StateVersion:       1,
		StartedAt:          "2026-04-05T10:00:00Z",
		UpdatedAt:          "2026-04-05T10:00:00Z",
		ResumeToken:        "resume-token",
		EventSeq:           5,
		Plans:              plansStateJSON{Exists: false},
		Git:                gitStateJSON{Branch: "main"},
		ChangesThisSession: []interface{}{},
	}
	existingData, _ := json.MarshalIndent(existingSession, "", "  ")
	sessionFile := filepath.Join(stateDir, "session.json")
	if err := os.WriteFile(sessionFile, existingData, 0600); err != nil {
		t.Fatal(err)
	}

	h := &MonitorHandler{
		StateDir:  stateDir,
		PlansFile: filepath.Join(dir, "Plans.md"),
	}

	var out bytes.Buffer
	if err := h.Handle(strings.NewReader(`{"cwd":"`+dir+`"}`), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	// resume されたセッションの session_id は変わらない
	data, _ := os.ReadFile(sessionFile)
	var sess sessionStateJSON
	if err := json.Unmarshal(data, &sess); err != nil {
		t.Fatal(err)
	}

	if sess.SessionID != "session-existing" {
		t.Errorf("expected session_id=session-existing (resume), got %q", sess.SessionID)
	}
	if sess.ResumeToken != "resume-token" {
		t.Errorf("expected resume_token preserved, got %q", sess.ResumeToken)
	}
}

func TestMonitorHandler_NewSessionOnStopped(t *testing.T) {
	dir := t.TempDir()
	stateDir := filepath.Join(dir, "state")
	if err := os.MkdirAll(stateDir, 0700); err != nil {
		t.Fatal(err)
	}

	// 停止済みセッションを作成
	existingSession := map[string]interface{}{
		"session_id": "session-old",
		"state":      "stopped",
		"started_at": "2026-04-04T10:00:00Z",
	}
	existingData, _ := json.MarshalIndent(existingSession, "", "  ")
	sessionFile := filepath.Join(stateDir, "session.json")
	if err := os.WriteFile(sessionFile, existingData, 0600); err != nil {
		t.Fatal(err)
	}

	h := &MonitorHandler{
		StateDir:  stateDir,
		PlansFile: filepath.Join(dir, "Plans.md"),
	}

	var out bytes.Buffer
	if err := h.Handle(strings.NewReader(`{"cwd":"`+dir+`"}`), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	data, _ := os.ReadFile(sessionFile)
	var sess sessionStateJSON
	if err := json.Unmarshal(data, &sess); err != nil {
		t.Fatal(err)
	}

	// 新しい session_id が生成されているはず
	if sess.SessionID == "session-old" {
		t.Errorf("expected new session_id, got session-old")
	}
	if sess.State != "initialized" {
		t.Errorf("expected state=initialized, got %q", sess.State)
	}
}

func TestMonitorHandler_SymlinkStateDir(t *testing.T) {
	dir := t.TempDir()
	realDir := filepath.Join(dir, "real-state")
	if err := os.MkdirAll(realDir, 0700); err != nil {
		t.Fatal(err)
	}
	linkDir := filepath.Join(dir, "link-state")
	if err := os.Symlink(realDir, linkDir); err != nil {
		t.Skip("symlink creation not supported")
	}

	h := &MonitorHandler{StateDir: linkDir}
	var out bytes.Buffer
	// エラーにならないこと（早期リターン）
	err := h.Handle(strings.NewReader(`{}`), &out)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
}

func TestMonitorHandler_ReadGitBranch(t *testing.T) {
	dir := t.TempDir()
	runGitCmd(t, dir, "init", "-q")
	runGitCmd(t, dir, "config", "user.name", "Test User")
	runGitCmd(t, dir, "config", "user.email", "test@example.com")
	if err := os.WriteFile(filepath.Join(dir, "README.md"), []byte("hello\n"), 0644); err != nil {
		t.Fatal(err)
	}
	runGitCmd(t, dir, "add", "README.md")
	runGitCmd(t, dir, "commit", "-qm", "init")
	runGitCmd(t, dir, "checkout", "-qb", "feat/test")

	h := &MonitorHandler{}
	branch := h.readGitBranch(dir)
	if branch != "feat/test" {
		t.Errorf("expected branch=feat/test, got %q", branch)
	}
}

func TestMonitorHandler_CollectGitState_Worktree(t *testing.T) {
	repoDir := t.TempDir()
	runGitCmd(t, repoDir, "init", "-q")
	runGitCmd(t, repoDir, "config", "user.name", "Test User")
	runGitCmd(t, repoDir, "config", "user.email", "test@example.com")
	if err := os.WriteFile(filepath.Join(repoDir, "README.md"), []byte("hello\n"), 0644); err != nil {
		t.Fatal(err)
	}
	runGitCmd(t, repoDir, "add", "README.md")
	runGitCmd(t, repoDir, "commit", "-qm", "init")

	worktreeDir := filepath.Join(t.TempDir(), "feature-worktree")
	runGitCmd(t, repoDir, "worktree", "add", "-b", "feature/worktree", worktreeDir, "HEAD")

	h := &MonitorHandler{}
	gitState := h.collectGitState(worktreeDir)
	if gitState.Branch != "feature/worktree" {
		t.Fatalf("expected branch=feature/worktree, got %q", gitState.Branch)
	}
	if gitState.LastCommit == "none" || gitState.LastCommit == "unknown" || gitState.LastCommit == "" {
		t.Fatalf("expected last_commit from worktree, got %q", gitState.LastCommit)
	}
}

func runGitCmd(t *testing.T, dir string, args ...string) string {
	t.Helper()

	cmd := exec.Command("git", args...)
	cmd.Dir = dir
	output, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("git %s failed: %v\n%s", strings.Join(args, " "), err, output)
	}
	return strings.TrimSpace(string(output))
}

func TestMonitorHandler_WriteSummary(t *testing.T) {
	h := &MonitorHandler{}
	var out bytes.Buffer
	h.writeSummary(&out, "my-project", gitStateJSON{Branch: "main"}, plansStateJSON{
		Exists:    true,
		WIPTasks:  2,
		TODOTasks: 3,
	})

	s := out.String()
	if !strings.Contains(s, "my-project") {
		t.Errorf("expected project name in summary, got:\n%s", s)
	}
	if !strings.Contains(s, "main") {
		t.Errorf("expected branch in summary, got:\n%s", s)
	}
	if !strings.Contains(s, "WIP 2") {
		t.Errorf("expected WIP count in summary, got:\n%s", s)
	}
}

// ---------------------------------------------------------------------------
// 48.1.1: harness-mem health 検知テスト
// ---------------------------------------------------------------------------

func TestMonitorHandler_HarnessMemHealthy(t *testing.T) {
	dir := t.TempDir()
	stateDir := filepath.Join(dir, "state")

	h := &MonitorHandler{
		StateDir:  stateDir,
		PlansFile: filepath.Join(dir, "Plans.md"),
		MemHealthCommand: func(_ context.Context) (bool, string, error) {
			return true, "", nil
		},
	}

	var out bytes.Buffer
	if err := h.Handle(strings.NewReader(`{"cwd":"`+dir+`"}`), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	// healthy の場合は警告なし
	s := out.String()
	if strings.Contains(s, "harness-mem unhealthy") {
		t.Errorf("expected no unhealthy warning for healthy state, got:\n%s", s)
	}

	// session.json に harness_mem フィールドが書かれている
	sessionFile := filepath.Join(stateDir, "session.json")
	data, err := os.ReadFile(sessionFile)
	if err != nil {
		t.Fatalf("session.json not created: %v", err)
	}
	var sess sessionStateJSON
	if err := json.Unmarshal(data, &sess); err != nil {
		t.Fatalf("invalid session.json: %v", err)
	}
	if !sess.HarnessMem.Healthy {
		t.Errorf("expected harness_mem.healthy=true in session.json")
	}
}

func TestMonitorHandler_HarnessMemUnhealthy(t *testing.T) {
	dir := t.TempDir()
	stateDir := filepath.Join(dir, "state")

	h := &MonitorHandler{
		StateDir:  stateDir,
		PlansFile: filepath.Join(dir, "Plans.md"),
		MemHealthCommand: func(_ context.Context) (bool, string, error) {
			return false, "daemon-unreachable", nil
		},
	}

	var out bytes.Buffer
	if err := h.Handle(strings.NewReader(`{"cwd":"`+dir+`"}`), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	s := out.String()
	if !strings.Contains(s, "harness-mem unhealthy") {
		t.Errorf("expected unhealthy warning in output, got:\n%s", s)
	}
	if !strings.Contains(s, "daemon-unreachable") {
		t.Errorf("expected reason 'daemon-unreachable' in warning, got:\n%s", s)
	}

	// session.json の harness_mem.healthy が false
	sessionFile := filepath.Join(stateDir, "session.json")
	data, err := os.ReadFile(sessionFile)
	if err != nil {
		t.Fatalf("session.json not created: %v", err)
	}
	var sess sessionStateJSON
	if err := json.Unmarshal(data, &sess); err != nil {
		t.Fatalf("invalid session.json: %v", err)
	}
	if sess.HarnessMem.Healthy {
		t.Errorf("expected harness_mem.healthy=false in session.json")
	}
	if sess.HarnessMem.LastError != "daemon-unreachable" {
		t.Errorf("expected harness_mem.last_error=daemon-unreachable, got %q", sess.HarnessMem.LastError)
	}
}

// TestMonitorHandler_HarnessMemNotConfigured は harness-mem 未インストール
// ユーザーのセッションで `⚠️ harness-mem unhealthy` 警告が誤発火しないことを固定する。
// v4.3.1 で導入された mem health check が `~/.claude-mem/` 不在時に
// `not-initialized`/unhealthy を返し、監視対象外のユーザーにも警告が出ていた regression
// を v4.3.3 で修正 (opt-in 未使用 = healthy=true + reason="not-configured" 扱い)。
func TestMonitorHandler_HarnessMemNotConfigured(t *testing.T) {
	dir := t.TempDir()
	stateDir := filepath.Join(dir, "state")

	h := &MonitorHandler{
		StateDir:  stateDir,
		PlansFile: filepath.Join(dir, "Plans.md"),
		MemHealthCommand: func(_ context.Context) (bool, string, error) {
			return true, "not-configured", nil
		},
	}

	var out bytes.Buffer
	if err := h.Handle(strings.NewReader(`{"cwd":"`+dir+`"}`), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	s := out.String()
	if strings.Contains(s, "harness-mem unhealthy") {
		t.Errorf("not-configured must NOT emit unhealthy warning, got:\n%s", s)
	}

	// session.json の harness_mem.healthy=true、LastError は空 (healthy なので)
	sessionFile := filepath.Join(stateDir, "session.json")
	data, err := os.ReadFile(sessionFile)
	if err != nil {
		t.Fatalf("session.json not created: %v", err)
	}
	var sess sessionStateJSON
	if err := json.Unmarshal(data, &sess); err != nil {
		t.Fatalf("invalid session.json: %v", err)
	}
	if !sess.HarnessMem.Healthy {
		t.Errorf("expected harness_mem.healthy=true (monitor exclusion), got false")
	}
	if sess.HarnessMem.LastError != "" {
		t.Errorf("expected harness_mem.last_error=\"\" when healthy, got %q", sess.HarnessMem.LastError)
	}
}

func TestMonitorHandler_HarnessMemTimeout(t *testing.T) {
	dir := t.TempDir()
	stateDir := filepath.Join(dir, "state")

	h := &MonitorHandler{
		StateDir:  stateDir,
		PlansFile: filepath.Join(dir, "Plans.md"),
		MemHealthCommand: func(_ context.Context) (bool, string, error) {
			return false, "timeout", fmt.Errorf("context deadline exceeded")
		},
	}

	var out bytes.Buffer
	// タイムアウト/エラー時もハンドラ全体は止まらない
	if err := h.Handle(strings.NewReader(`{"cwd":"`+dir+`"}`), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	s := out.String()
	if !strings.Contains(s, "harness-mem unhealthy") {
		t.Errorf("expected unhealthy warning for timeout, got:\n%s", s)
	}
}

// ---------------------------------------------------------------------------
// 48.1.2: advisor/reviewer drift 検知テスト
// ---------------------------------------------------------------------------

func TestMonitorHandler_AdvisorDrift_Hit(t *testing.T) {
	dir := t.TempDir()
	stateDir := filepath.Join(dir, ".claude", "state")
	if err := os.MkdirAll(stateDir, 0700); err != nil {
		t.Fatal(err)
	}

	// 600秒以上前の advisor-request を書く（TTL=600 を超える）
	oldTime := time.Now().Add(-700 * time.Second).UTC().Format(time.RFC3339)
	eventsFile := filepath.Join(stateDir, "session.events.jsonl")
	line := fmt.Sprintf(`{"schema_version":"advisor-request.v1","task_id":"t1","trigger_hash":"abc123","ts":"%s"}`, oldTime)
	if err := os.WriteFile(eventsFile, []byte(line+"\n"), 0600); err != nil {
		t.Fatal(err)
	}

	now := time.Now()
	h := &MonitorHandler{
		StateDir:  stateDir,
		PlansFile: filepath.Join(dir, "Plans.md"),
		now:       func() time.Time { return now },
	}

	var out bytes.Buffer
	if err := h.Handle(strings.NewReader(`{"cwd":"`+dir+`"}`), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	s := out.String()
	if !strings.Contains(s, "advisor drift") {
		t.Errorf("expected advisor drift warning, got:\n%s", s)
	}
	if !strings.Contains(s, "waiting") {
		t.Errorf("expected 'waiting' in advisor drift output, got:\n%s", s)
	}
}

func TestMonitorHandler_AdvisorDrift_Miss(t *testing.T) {
	dir := t.TempDir()
	stateDir := filepath.Join(dir, ".claude", "state")
	if err := os.MkdirAll(stateDir, 0700); err != nil {
		t.Fatal(err)
	}

	// TTL 未満（50秒前）の advisor-request
	recentTime := time.Now().Add(-50 * time.Second).UTC().Format(time.RFC3339)
	eventsFile := filepath.Join(stateDir, "session.events.jsonl")
	line := fmt.Sprintf(`{"schema_version":"advisor-request.v1","task_id":"t2","trigger_hash":"xyz789","ts":"%s"}`, recentTime)
	if err := os.WriteFile(eventsFile, []byte(line+"\n"), 0600); err != nil {
		t.Fatal(err)
	}

	now := time.Now()
	h := &MonitorHandler{
		StateDir:  stateDir,
		PlansFile: filepath.Join(dir, "Plans.md"),
		now:       func() time.Time { return now },
	}

	var out bytes.Buffer
	if err := h.Handle(strings.NewReader(`{"cwd":"`+dir+`"}`), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	s := out.String()
	if strings.Contains(s, "advisor drift") {
		t.Errorf("expected no advisor drift warning for TTL-miss, got:\n%s", s)
	}
}

func TestMonitorHandler_AdvisorDrift_ConfigOverride(t *testing.T) {
	dir := t.TempDir()
	stateDir := filepath.Join(dir, ".claude", "state")
	if err := os.MkdirAll(stateDir, 0700); err != nil {
		t.Fatal(err)
	}

	// config.yaml で advisor_ttl_seconds=10 を設定
	configContent := `orchestration:
  advisor_ttl_seconds: 10
`
	if err := os.WriteFile(filepath.Join(dir, ".claude-code-harness.config.yaml"), []byte(configContent), 0644); err != nil {
		t.Fatal(err)
	}

	// 15秒前の advisor-request（TTL=10 を超える）
	oldTime := time.Now().Add(-15 * time.Second).UTC().Format(time.RFC3339)
	eventsFile := filepath.Join(stateDir, "session.events.jsonl")
	line := fmt.Sprintf(`{"schema_version":"advisor-request.v1","task_id":"t3","trigger_hash":"cfg001","ts":"%s"}`, oldTime)
	if err := os.WriteFile(eventsFile, []byte(line+"\n"), 0600); err != nil {
		t.Fatal(err)
	}

	now := time.Now()
	h := &MonitorHandler{
		StateDir:  stateDir,
		PlansFile: filepath.Join(dir, "Plans.md"),
		now:       func() time.Time { return now },
	}

	var out bytes.Buffer
	if err := h.Handle(strings.NewReader(`{"cwd":"`+dir+`"}`), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	s := out.String()
	if !strings.Contains(s, "advisor drift") {
		t.Errorf("expected advisor drift warning with config override TTL=10, got:\n%s", s)
	}
}

// ---------------------------------------------------------------------------
// 48.2.1: reviewer drift テスト（Phase 48.2 follow-up）
// reviewer drift は advisor drift と同一 TTL (orchestration.advisor_ttl_seconds) を共有する。
// 検出対象スキーマは review-request.v1 / review-result.v1。
// ---------------------------------------------------------------------------

func TestMonitorHandler_ReviewerDrift_Hit(t *testing.T) {
	dir := t.TempDir()
	stateDir := filepath.Join(dir, ".claude", "state")
	if err := os.MkdirAll(stateDir, 0700); err != nil {
		t.Fatal(err)
	}

	// 700秒前の review-request（TTL=600 を超える）
	oldTime := time.Now().Add(-700 * time.Second).UTC().Format(time.RFC3339)
	eventsFile := filepath.Join(stateDir, "session.events.jsonl")
	line := fmt.Sprintf(`{"schema_version":"review-request.v1","task_id":"rev1","trigger_hash":"rev0001","ts":"%s"}`, oldTime)
	if err := os.WriteFile(eventsFile, []byte(line+"\n"), 0600); err != nil {
		t.Fatal(err)
	}

	now := time.Now()
	h := &MonitorHandler{
		StateDir:  stateDir,
		PlansFile: filepath.Join(dir, "Plans.md"),
		now:       func() time.Time { return now },
	}

	var out bytes.Buffer
	if err := h.Handle(strings.NewReader(`{"cwd":"`+dir+`"}`), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	s := out.String()
	if !strings.Contains(s, "reviewer drift") {
		t.Errorf("expected reviewer drift warning, got:\n%s", s)
	}
	if !strings.Contains(s, "waiting") {
		t.Errorf("expected 'waiting' in reviewer drift output, got:\n%s", s)
	}
}

func TestMonitorHandler_ReviewerDrift_Miss(t *testing.T) {
	dir := t.TempDir()
	stateDir := filepath.Join(dir, ".claude", "state")
	if err := os.MkdirAll(stateDir, 0700); err != nil {
		t.Fatal(err)
	}

	// request は TTL 超過だが review-result.v1 が既に到着している → drift ではない
	baseTime := time.Now().Add(-700 * time.Second).UTC().Format(time.RFC3339)
	eventsFile := filepath.Join(stateDir, "session.events.jsonl")
	reqLine := fmt.Sprintf(`{"schema_version":"review-request.v1","task_id":"rev2","trigger_hash":"rev0002","ts":"%s"}`, baseTime)
	resLine := fmt.Sprintf(`{"schema_version":"review-result.v1","task_id":"rev2","trigger_hash":"rev0002","ts":"%s"}`, baseTime)
	if err := os.WriteFile(eventsFile, []byte(reqLine+"\n"+resLine+"\n"), 0600); err != nil {
		t.Fatal(err)
	}

	now := time.Now()
	h := &MonitorHandler{
		StateDir:  stateDir,
		PlansFile: filepath.Join(dir, "Plans.md"),
		now:       func() time.Time { return now },
	}

	var out bytes.Buffer
	if err := h.Handle(strings.NewReader(`{"cwd":"`+dir+`"}`), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	s := out.String()
	if strings.Contains(s, "reviewer drift") {
		t.Errorf("expected no reviewer drift warning when response exists, got:\n%s", s)
	}
}

func TestMonitorHandler_ReviewerDrift_ConfigOverride(t *testing.T) {
	dir := t.TempDir()
	stateDir := filepath.Join(dir, ".claude", "state")
	if err := os.MkdirAll(stateDir, 0700); err != nil {
		t.Fatal(err)
	}

	// config.yaml で advisor_ttl_seconds=10 を設定（reviewer drift も同 TTL を共有）
	configContent := `orchestration:
  advisor_ttl_seconds: 10
`
	if err := os.WriteFile(filepath.Join(dir, ".claude-code-harness.config.yaml"), []byte(configContent), 0644); err != nil {
		t.Fatal(err)
	}

	// 15秒前の review-request（TTL=10 を超える）
	oldTime := time.Now().Add(-15 * time.Second).UTC().Format(time.RFC3339)
	eventsFile := filepath.Join(stateDir, "session.events.jsonl")
	line := fmt.Sprintf(`{"schema_version":"review-request.v1","task_id":"rev3","trigger_hash":"rev0003","ts":"%s"}`, oldTime)
	if err := os.WriteFile(eventsFile, []byte(line+"\n"), 0600); err != nil {
		t.Fatal(err)
	}

	now := time.Now()
	h := &MonitorHandler{
		StateDir:  stateDir,
		PlansFile: filepath.Join(dir, "Plans.md"),
		now:       func() time.Time { return now },
	}

	var out bytes.Buffer
	if err := h.Handle(strings.NewReader(`{"cwd":"`+dir+`"}`), &out); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	s := out.String()
	if !strings.Contains(s, "reviewer drift") {
		t.Errorf("expected reviewer drift warning with config override TTL=10, got:\n%s", s)
	}
}

// ---------------------------------------------------------------------------
// 48.1.3: Plans.md 閾値判定テスト
// ---------------------------------------------------------------------------

func TestMonitorHandler_PlansDrift_WIPThresholdHit(t *testing.T) {
	dir := t.TempDir()
	stateDir := filepath.Join(dir, "state")

	now := time.Now()
	h := &MonitorHandler{
		StateDir:  stateDir,
		PlansFile: filepath.Join(dir, "Plans.md"),
		now:       func() time.Time { return now },
	}

	// WIPTasks=5 (default threshold)
	plans := plansStateJSON{
		Exists:       true,
		WIPTasks:     5,
		LastModified: now.Add(-1 * time.Hour).Unix(),
	}

	result := h.checkPlansDrift(plans, dir)
	if result == "" {
		t.Errorf("expected plans drift warning for WIP=5, got empty")
	}
	if !strings.Contains(result, "plans drift") {
		t.Errorf("expected 'plans drift' in output, got: %s", result)
	}
}

func TestMonitorHandler_PlansDrift_StaleHit(t *testing.T) {
	dir := t.TempDir()
	stateDir := filepath.Join(dir, "state")

	now := time.Now()
	h := &MonitorHandler{
		StateDir:  stateDir,
		PlansFile: filepath.Join(dir, "Plans.md"),
		now:       func() time.Time { return now },
	}

	// 25時間前の更新 (stale_hours=24 を超える)
	staleTime := now.Add(-25 * time.Hour)
	plans := plansStateJSON{
		Exists:       true,
		WIPTasks:     1,
		LastModified: staleTime.Unix(),
	}

	result := h.checkPlansDrift(plans, dir)
	if result == "" {
		t.Errorf("expected plans drift warning for stale Plans.md, got empty")
	}
	if !strings.Contains(result, "plans drift") {
		t.Errorf("expected 'plans drift' in output, got: %s", result)
	}
	if !strings.Contains(result, "stale_for=25h") {
		t.Errorf("expected stale_for=25h in output, got: %s", result)
	}
}

func TestMonitorHandler_PlansDrift_BelowThreshold(t *testing.T) {
	dir := t.TempDir()
	stateDir := filepath.Join(dir, "state")

	now := time.Now()
	h := &MonitorHandler{
		StateDir:  stateDir,
		PlansFile: filepath.Join(dir, "Plans.md"),
		now:       func() time.Time { return now },
	}

	// WIP=2（閾値5未満）、1時間前更新（stale_hours=24未満）
	plans := plansStateJSON{
		Exists:       true,
		WIPTasks:     2,
		LastModified: now.Add(-1 * time.Hour).Unix(),
	}

	result := h.checkPlansDrift(plans, dir)
	if result != "" {
		t.Errorf("expected no plans drift warning below threshold, got: %s", result)
	}
}

func TestMonitorHandler_PlansDrift_ConfigOverride(t *testing.T) {
	dir := t.TempDir()
	stateDir := filepath.Join(dir, "state")

	// config.yaml で wip_threshold=3 を設定
	configContent := `monitor:
  plans_drift:
    wip_threshold: 3
    stale_hours: 48
`
	if err := os.WriteFile(filepath.Join(dir, ".claude-code-harness.config.yaml"), []byte(configContent), 0644); err != nil {
		t.Fatal(err)
	}

	now := time.Now()
	h := &MonitorHandler{
		StateDir:  stateDir,
		PlansFile: filepath.Join(dir, "Plans.md"),
		now:       func() time.Time { return now },
	}

	// WIP=3 (config threshold=3 を満たす)
	plans := plansStateJSON{
		Exists:       true,
		WIPTasks:     3,
		LastModified: now.Add(-1 * time.Hour).Unix(),
	}

	result := h.checkPlansDrift(plans, dir)
	if result == "" {
		t.Errorf("expected plans drift warning for WIP=3 with config threshold=3, got empty")
	}
}

// ---------------------------------------------------------------------------
// Issue #94 Item 3: collectDrift の bounded memory (container/ring) 契約テスト
// ---------------------------------------------------------------------------

// TestCollectDrift_TailWindowBoundary は末尾 driftTailWindow (=200) 行のみが
// drift 判定対象となる境界を固定する回帰テスト。
//
// 500 行の events.jsonl のうち、末尾 200 行の内側の advisor-request だけが検出され、
// 外側 (先頭寄り) の advisor-request は無視されることを確認する。
// ring buffer 化後もこの境界を維持していることを保証する。
func TestCollectDrift_TailWindowBoundary(t *testing.T) {
	dir := t.TempDir()
	stateDir := filepath.Join(dir, ".claude", "state")
	if err := os.MkdirAll(stateDir, 0700); err != nil {
		t.Fatal(err)
	}
	eventsFile := filepath.Join(stateDir, "session.events.jsonl")

	oldTime := time.Now().Add(-700 * time.Second).UTC().Format(time.RFC3339)
	var buf bytes.Buffer

	// line 1..299: 無関係イベント (末尾 200 行の外側)
	for i := 0; i < 299; i++ {
		fmt.Fprintf(&buf, `{"schema_version":"other","task_id":"noise%d","trigger_hash":"nh%d","ts":"%s"}`+"\n", i, i, oldTime)
	}
	// line 300: outside の advisor-request → window 外なので検出されない期待
	fmt.Fprintf(&buf, `{"schema_version":"advisor-request.v1","task_id":"t_outside","trigger_hash":"outside","ts":"%s"}`+"\n", oldTime)
	// line 301..499: 無関係イベント (末尾 200 行 = line 301..500)
	for i := 0; i < 199; i++ {
		fmt.Fprintf(&buf, `{"schema_version":"other","task_id":"tail%d","trigger_hash":"th%d","ts":"%s"}`+"\n", i, i, oldTime)
	}
	// line 500: inside の advisor-request → window 内なので検出される期待
	fmt.Fprintf(&buf, `{"schema_version":"advisor-request.v1","task_id":"t_inside","trigger_hash":"inside","ts":"%s"}`+"\n", oldTime)

	if err := os.WriteFile(eventsFile, buf.Bytes(), 0600); err != nil {
		t.Fatal(err)
	}

	now := time.Now()
	h := &MonitorHandler{
		StateDir:  stateDir,
		PlansFile: filepath.Join(dir, "Plans.md"),
		now:       func() time.Time { return now },
	}

	warnings := h.collectDrift(stateDir, dir)
	joined := strings.Join(warnings, " | ")

	if !strings.Contains(joined, "t_inside") {
		t.Errorf("expected t_inside advisor drift warning (inside tail %d), got:\n%s", driftTailWindow, joined)
	}
	if strings.Contains(joined, "t_outside") {
		t.Errorf("expected NO t_outside advisor drift warning (outside tail %d), got:\n%s", driftTailWindow, joined)
	}
}

// benchCollectDrift は session.events.jsonl の行数を変えながら collectDrift の
// メモリ/時間コストを計測するためのヘルパー。
//
// Issue #94 Item 3 の Exit criteria「benchmark showing bounded growth with N lines」を
// 満たすため、`go test -bench=BenchmarkCollectDrift -benchmem` で N=200 と N=10000 を
// 並べて実行すると、ring buffer 化により **後段 retention** (`lines` slice 展開) が
// N に比例せず driftTailWindow (=200) に bounded であることを手動で確認できる。
// (scanner.Text() 由来の短命 string alloc は両実装共通で N に比例するが、
//  ピーク in-use はリングで固定される)。
func benchCollectDrift(b *testing.B, numLines int) {
	dir := b.TempDir()
	stateDir := filepath.Join(dir, ".claude", "state")
	if err := os.MkdirAll(stateDir, 0700); err != nil {
		b.Fatal(err)
	}
	eventsFile := filepath.Join(stateDir, "session.events.jsonl")

	f, err := os.Create(eventsFile)
	if err != nil {
		b.Fatal(err)
	}
	padding := strings.Repeat("x", 150)
	for i := 0; i < numLines; i++ {
		fmt.Fprintf(f, `{"schema_version":"other","task_id":"t%d","trigger_hash":"h%d","ts":"2026-01-01T00:00:00Z","padding":"%s"}`+"\n", i, i, padding)
	}
	if err := f.Close(); err != nil {
		b.Fatal(err)
	}

	now := time.Now()
	h := &MonitorHandler{
		StateDir:  stateDir,
		PlansFile: filepath.Join(dir, "Plans.md"),
		now:       func() time.Time { return now },
	}

	b.ReportAllocs()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = h.collectDrift(stateDir, dir)
	}
}

// BenchmarkCollectDrift_200Lines は末尾 window サイズ (=200) ちょうどの入力での基準値。
func BenchmarkCollectDrift_200Lines(b *testing.B) {
	benchCollectDrift(b, 200)
}

// BenchmarkCollectDrift_10000Lines は window の 50 倍の入力。
// ring buffer 化後、最終的に確保される lines slice は常に 200 要素 bounded のため、
// "final retained allocation" が 200-line ベンチと同オーダーにとどまることを showing する。
func BenchmarkCollectDrift_10000Lines(b *testing.B) {
	benchCollectDrift(b, 10000)
}
