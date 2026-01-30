# Worklog Management

ultrawork のワークログ管理に関する詳細仕様。

---

## ファイル構造

### 保存場所

```
.claude/state/ultrawork.log.jsonl
```

### フォーマット

JSONL (JSON Lines) 形式。各行が1つのイベント。

---

## イベント種別

### start

セッション開始時に記録。

```json
{
  "ts": "2025-01-30T10:00:00Z",
  "event": "start",
  "range": "認証機能からユーザー管理まで",
  "tasks": [3, 4, 5, 6],
  "task_titles": ["ログイン機能", "認証ミドルウェア", "セッション管理", "ユーザー管理"],
  "max_iterations": 10,
  "completion_conditions": ["all_tasks_done", "build_pass", "tests_pass"]
}
```

### iteration_start

各イテレーション開始時。

```json
{
  "ts": "2025-01-30T10:00:05Z",
  "event": "iteration_start",
  "iteration": 1,
  "remaining_tasks": [3, 4, 5, 6],
  "learned_strategies": []
}
```

### task_start

タスク実行開始時。

```json
{
  "ts": "2025-01-30T10:00:10Z",
  "event": "task_start",
  "iteration": 1,
  "task_id": 3,
  "task_title": "ログイン機能",
  "strategy": null
}
```

### task_complete

タスク成功時。

```json
{
  "ts": "2025-01-30T10:00:35Z",
  "event": "task_complete",
  "iteration": 1,
  "task_id": 3,
  "task_title": "ログイン機能",
  "duration_s": 25,
  "changes": [
    {"file": "src/auth/login.ts", "action": "created"},
    {"file": "src/components/LoginForm.tsx", "action": "created"}
  ]
}
```

### task_failed

タスク失敗時。

```json
{
  "ts": "2025-01-30T10:01:00Z",
  "event": "task_failed",
  "iteration": 1,
  "task_id": 4,
  "task_title": "認証ミドルウェア",
  "error": "Type 'unknown' is not assignable to type 'User'",
  "error_type": "type_error",
  "attempted_fix": "Type assertion",
  "fix_result": "failed"
}
```

### learned

学習イベント（失敗からの学習）。

```json
{
  "ts": "2025-01-30T10:01:05Z",
  "event": "learned",
  "from_iteration": 1,
  "pattern": "type_error",
  "context": "User type not found",
  "strategy": "Check type definitions before implementation",
  "priority": "high"
}
```

### verify

検証結果。

```json
{
  "ts": "2025-01-30T10:02:00Z",
  "event": "verify",
  "iteration": 1,
  "build": "pass",
  "build_log": null,
  "test": "fail",
  "test_log": "1 test failed: should validate email",
  "review": "pending"
}
```

### iteration_end

イテレーション終了時。

```json
{
  "ts": "2025-01-30T10:02:05Z",
  "event": "iteration_end",
  "iteration": 1,
  "completed_tasks": [3],
  "failed_tasks": [4],
  "remaining_tasks": [4, 5, 6],
  "total_duration_s": 120
}
```

### checkpoint

中間コミット時。

```json
{
  "ts": "2025-01-30T10:02:10Z",
  "event": "checkpoint",
  "iteration": 1,
  "commit_hash": "abc1234",
  "commit_message": "wip: ログイン機能実装",
  "completed_tasks": [3]
}
```

### complete

全完了時。

```json
{
  "ts": "2025-01-30T10:10:00Z",
  "event": "complete",
  "iterations": 3,
  "total_duration_s": 600,
  "tasks_completed": 4,
  "tasks_failed": 0,
  "final_commit": "def5678",
  "learned_count": 2
}
```

### partial_complete

部分完了時（max-iterations到達）。

```json
{
  "ts": "2025-01-30T10:15:00Z",
  "event": "partial_complete",
  "iterations": 10,
  "total_duration_s": 900,
  "tasks_completed": 3,
  "tasks_failed": 1,
  "blocking_tasks": [4],
  "blocking_reasons": ["Type 'unknown' is not assignable (5 attempts)"]
}
```

### resume

再開時。

```json
{
  "ts": "2025-01-30T11:00:00Z",
  "event": "resume",
  "from_iteration": 3,
  "completed_tasks": [3, 5],
  "remaining_tasks": [4, 6],
  "inherited_learnings": 2
}
```

---

## 読み込みパターン

### 再開時の読み込み

```typescript
function loadWorklog(): WorklogState {
  const lines = fs.readFileSync(WORKLOG_PATH, 'utf-8').split('\n').filter(Boolean);
  const entries = lines.map(line => JSON.parse(line));

  // 最後の iteration_end または partial_complete を探す
  const lastState = entries.filter(e =>
    e.event === 'iteration_end' ||
    e.event === 'partial_complete'
  ).pop();

  // 完了タスクを集計
  const completedTasks = entries
    .filter(e => e.event === 'task_complete')
    .map(e => e.task_id);

  // 学習データを集計
  const learnings = entries
    .filter(e => e.event === 'learned')
    .map(e => ({ pattern: e.pattern, strategy: e.strategy }));

  return {
    lastIteration: lastState?.iteration || 0,
    completedTasks,
    learnings
  };
}
```

### 失敗パターン分析

```typescript
function analyzeFailures(entries: WorklogEntry[]): FailurePattern[] {
  const failures = entries.filter(e => e.event === 'task_failed');

  // 同じエラータイプをグループ化
  const grouped = groupBy(failures, 'error_type');

  return Object.entries(grouped).map(([type, items]) => ({
    pattern: type,
    count: items.length,
    examples: items.slice(0, 3),
    suggestedStrategy: deriveStrategy(type, items)
  }));
}
```

---

## 学習データの活用

### イテレーション開始時

```typescript
function prepareIteration(worklog: WorklogState): IterationPlan {
  const { learnings, completedTasks } = worklog;

  // 学習した戦略を優先度順に整理
  const strategies = learnings
    .sort((a, b) => b.priority - a.priority)
    .map(l => l.strategy);

  return {
    remainingTasks: allTasks.filter(t => !completedTasks.includes(t.id)),
    strategies,
    preChecks: generatePreChecks(strategies)
  };
}

function generatePreChecks(strategies: string[]): PreCheck[] {
  // 戦略に基づいて事前チェックを生成
  // 例: "Check type definitions" → 型定義ファイルを先に読む
  return strategies.map(s => {
    if (s.includes('type definition')) {
      return { action: 'read', pattern: '**/types/**/*.ts' };
    }
    if (s.includes('path')) {
      return { action: 'verify', pattern: 'import paths' };
    }
    return null;
  }).filter(Boolean);
}
```

---

## ワークログのクリーンアップ

### 古いログの管理

```typescript
// 30日以上前のログをアーカイブ
function archiveOldLogs() {
  const archiveDir = '.claude/state/archive/';
  const files = glob('.claude/state/ultrawork.*.log.jsonl');

  files.forEach(file => {
    const stat = fs.statSync(file);
    const ageInDays = (Date.now() - stat.mtime) / (1000 * 60 * 60 * 24);

    if (ageInDays > 30) {
      fs.renameSync(file, path.join(archiveDir, path.basename(file)));
    }
  });
}
```

### セッション分離

```typescript
// 新しい ultrawork セッションは新しいログファイルに
function initWorklog(sessionId: string): string {
  const filename = `ultrawork.${sessionId}.log.jsonl`;
  const path = `.claude/state/${filename}`;

  // シンボリックリンクで最新を指す
  fs.symlinkSync(path, '.claude/state/ultrawork.log.jsonl');

  return path;
}
```

---

## トラブルシューティング

### ログが破損した場合

```bash
# 破損行をスキップして読み込み
cat .claude/state/ultrawork.log.jsonl | jq -c '.' 2>/dev/null > repaired.jsonl
mv repaired.jsonl .claude/state/ultrawork.log.jsonl
```

### 学習データをリセット

```bash
# learned イベントのみ削除
cat .claude/state/ultrawork.log.jsonl | jq -c 'select(.event != "learned")' > temp.jsonl
mv temp.jsonl .claude/state/ultrawork.log.jsonl
```
