// Package state は Harness v4 の SQLite 状態管理を提供する。
// TypeScript の core/src/state/schema.ts を Go に移植したもの。
package state

// SchemaVersion は現在のスキーマバージョン番号。
// マイグレーションが必要になるたびにインクリメントする。
const SchemaVersion = 1

// ============================================================
// DDL 定義
// ============================================================

// createSchemaMeta はスキーマバージョン管理テーブルの DDL。
// 他のすべてのテーブルより先に作成する必要がある。
const createSchemaMeta = `
CREATE TABLE IF NOT EXISTS schema_meta (
  key   TEXT NOT NULL PRIMARY KEY,
  value TEXT NOT NULL
)`

// createSessions は sessions テーブルの DDL。
// session_id: Claude Code が発行するセッション識別子
// mode: normal | work | codex | breezing
// project_root: セッションが紐付くプロジェクトルート
// started_at: セッション開始時刻（Unix タイムスタンプ秒）
// ended_at: セッション終了時刻（NULL = アクティブ）
// context_json: 任意の追加情報（JSON テキスト）
const createSessions = `
CREATE TABLE IF NOT EXISTS sessions (
  session_id   TEXT    NOT NULL PRIMARY KEY,
  mode         TEXT    NOT NULL CHECK(mode IN ('normal','work','codex','breezing')),
  project_root TEXT    NOT NULL,
  started_at   INTEGER NOT NULL,
  ended_at     INTEGER,
  context_json TEXT    NOT NULL DEFAULT '{}'
)`

// createSignals は signals テーブルの DDL。
// id: 自動採番 PK
// type: シグナル種別
// from_session_id: 送信元セッション
// to_session_id: 宛先セッション（NULL = ブロードキャスト）
// payload_json: ペイロード（JSON テキスト）
// sent_at: 送信時刻（Unix タイムスタンプ秒）
// consumed: 受信済みフラグ（0 = 未消費、1 = 消費済み）
const createSignals = `
CREATE TABLE IF NOT EXISTS signals (
  id              INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  type            TEXT    NOT NULL,
  from_session_id TEXT    NOT NULL,
  to_session_id   TEXT,
  payload_json    TEXT    NOT NULL DEFAULT '{}',
  sent_at         INTEGER NOT NULL,
  consumed        INTEGER NOT NULL DEFAULT 0 CHECK(consumed IN (0,1))
)`

// createTaskFailures は task_failures テーブルの DDL。
// id: 自動採番 PK
// task_id: 失敗したタスクの識別子
// session_id: タスクを実行していたセッション
// severity: warning | error | critical
// message: 失敗の説明
// detail: スタックトレース等の詳細情報（NULL 可）
// failed_at: 失敗時刻（Unix タイムスタンプ秒）
// attempt: 試行回数（1 始まり）
const createTaskFailures = `
CREATE TABLE IF NOT EXISTS task_failures (
  id         INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  task_id    TEXT    NOT NULL,
  session_id TEXT    NOT NULL,
  severity   TEXT    NOT NULL CHECK(severity IN ('warning','error','critical')),
  message    TEXT    NOT NULL,
  detail     TEXT,
  failed_at  INTEGER NOT NULL,
  attempt    INTEGER NOT NULL DEFAULT 1 CHECK(attempt >= 1)
)`

// createWorkStates は work_states テーブルの DDL。
// work-active.json の後継。work/codex/breezing モードの状態を管理する。
// session_id: 紐付くセッション ID（PK）
// codex_mode: codex モードフラグ（0/1）
// bypass_rm_rf: rm -rf ガードバイパスフラグ（0/1）
// bypass_git_push: git push ガードバイパスフラグ（0/1）
// expires_at: 有効期限（24 時間後の Unix タイムスタンプ秒）
// work_mode: work モードフラグ（0/1）
const createWorkStates = `
CREATE TABLE IF NOT EXISTS work_states (
  session_id      TEXT    NOT NULL PRIMARY KEY,
  codex_mode      INTEGER NOT NULL DEFAULT 0 CHECK(codex_mode IN (0,1)),
  bypass_rm_rf    INTEGER NOT NULL DEFAULT 0 CHECK(bypass_rm_rf IN (0,1)),
  bypass_git_push INTEGER NOT NULL DEFAULT 0 CHECK(bypass_git_push IN (0,1)),
  work_mode       INTEGER NOT NULL DEFAULT 0 CHECK(work_mode IN (0,1)),
  expires_at      INTEGER NOT NULL,
  FOREIGN KEY (session_id) REFERENCES sessions(session_id)
)`

// createAssumptions は assumptions テーブルの DDL（新規テーブル）。
// エージェントが行った前提・仮定を追跡するためのテーブル。
// id: 自動採番 PK
// session_id: 前提を記録したセッション
// task_id: 関連するタスク識別子（NULL 可）
// assumption: 前提の内容（テキスト）
// confidence: 信頼度（0.0 〜 1.0）
// created_at: 記録時刻（Unix タイムスタンプ秒）
// validated_at: 検証時刻（NULL = 未検証）
const createAssumptions = `
CREATE TABLE IF NOT EXISTS assumptions (
  id           INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  session_id   TEXT    NOT NULL,
  task_id      TEXT,
  assumption   TEXT    NOT NULL,
  confidence   REAL    NOT NULL DEFAULT 1.0 CHECK(confidence >= 0.0 AND confidence <= 1.0),
  created_at   INTEGER NOT NULL,
  validated_at INTEGER
)`

// createAgentStates はエージェントのライフサイクル状態を永続化するテーブルの DDL。
// SubagentStart/Stop フックで記録され、harness status で表示される。
// agent_id: CC が発行するエージェント識別子（PK）
// agent_type: worker | reviewer | advisor 等
// session_id: 親セッション識別子
// state: SPAWNING | RUNNING | REVIEWING | APPROVED | COMMITTED | FAILED |
//
//	CANCELLED | STALE | RECOVERING | ABORTED
//
// started_at: 開始時刻（Unix タイムスタンプ秒）
// stopped_at: 停止時刻（NULL = 実行中）
// recovery_attempts: リカバリ試行回数
const createAgentStates = `
CREATE TABLE IF NOT EXISTS agent_states (
  agent_id          TEXT    NOT NULL PRIMARY KEY,
  agent_type        TEXT    NOT NULL DEFAULT '',
  session_id        TEXT    NOT NULL DEFAULT '',
  state             TEXT    NOT NULL DEFAULT 'SPAWNING',
  started_at        INTEGER NOT NULL,
  stopped_at        INTEGER,
  recovery_attempts INTEGER NOT NULL DEFAULT 0 CHECK(recovery_attempts >= 0)
)`

// ============================================================
// インデックス定義
// ============================================================

// createIndexes はクエリパフォーマンスを向上させるインデックス群。
var createIndexes = []string{
	`CREATE INDEX IF NOT EXISTS idx_signals_to_session
     ON signals(to_session_id, consumed)`,
	`CREATE INDEX IF NOT EXISTS idx_signals_from_session
     ON signals(from_session_id, sent_at)`,
	`CREATE INDEX IF NOT EXISTS idx_task_failures_task
     ON task_failures(task_id, failed_at)`,
	`CREATE INDEX IF NOT EXISTS idx_work_states_expires
     ON work_states(expires_at)`,
	`CREATE INDEX IF NOT EXISTS idx_assumptions_session
     ON assumptions(session_id, created_at)`,
	`CREATE INDEX IF NOT EXISTS idx_assumptions_task
     ON assumptions(task_id, created_at)`,
	`CREATE INDEX IF NOT EXISTS idx_agent_states_session
     ON agent_states(session_id, started_at)`,
	`CREATE INDEX IF NOT EXISTS idx_agent_states_state
     ON agent_states(state, started_at)`,
}

// ============================================================
// 初期化 DDL リスト
// ============================================================

// allDDL は DB 初期化時に順番に実行する DDL の配列。
// schema_meta を最初に作成し、次に各テーブル、最後にインデックスを作成する。
var allDDL []string

func init() {
	allDDL = append(allDDL,
		createSchemaMeta,
		createSessions,
		createSignals,
		createTaskFailures,
		createWorkStates,
		createAssumptions,
		createAgentStates,
	)
	allDDL = append(allDDL, createIndexes...)
}
