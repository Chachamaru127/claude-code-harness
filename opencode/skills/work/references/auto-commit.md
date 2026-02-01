# Auto-commit

## Auto-commit behavior

```
Check auto-commit setting:
  1. --no-commit flag → Skip commit
  2. .claude-code-harness.config.yaml work.auto_commit: false → Skip commit
  3. .claude-code-harness.config.yaml work.commit_on_pm_approve: true
     AND 2-Agent mode → Defer commit (pending PM approval)
  4. Otherwise → Auto-commit with generated message
```

## commit_on_pm_approve モード (2-Agent 専用)

```
commit_on_pm_approve: true AND 2-Agent mode:
    ↓
Skip commit → Record pending state
    ↓
Handoff to PM with commit-pending flag:
  "変更はレビュー済みですが、未コミットです。
   approve 時にコミット指示を含めてください。"
    ↓
PM approves → Handoff includes commit instruction
    ↓
Next /work invocation: Detect "approved + commit pending"
    → Execute commit before starting new tasks
```

> **Solo モードでは無視**: `commit_on_pm_approve` は 2-Agent モードでのみ有効。

## Completion Reports

### With auto-commit

```
✅ /work Complete

| Item | Status |
|------|--------|
| Tasks | 5/5 implemented |
| Review | APPROVE |
| Iterations | 2 |
| Commit | abc1234 |

Changed files:
- src/components/Header.tsx (new)
- src/components/Footer.tsx (new)

Committed: feat: add Header, Footer components
```

### With --no-commit

```
✅ /work Complete

| Item | Status |
|------|--------|
| Tasks | 5/5 implemented |
| Review | APPROVE |
| Iterations | 2 |
| Commit | Skipped (--no-commit) |

Next steps:
1. Review changes: git diff
2. Commit when ready: git add . && git commit
```

### With commit_on_pm_approve (2-Agent)

```
✅ /work Complete (commit pending PM approval)

| Item | Status |
|------|--------|
| Tasks | 5/5 implemented |
| Review | APPROVE |
| Commit | ⏸️ Pending PM approval |

## Commit Status: Pending PM Approval

変更はハーネスレビュー済みですが、コミットを保留しています。
PM が approve した場合、次回 /work 実行時にコミットされます。
```

## Handoff commit-pending セクション

```
## Commit Status: Pending PM Approval

変更はハーネスレビュー済みですが、`commit_on_pm_approve` 設定により
コミットを保留しています。

approve の場合: ハンドオフに以下を含めてください:
  「前回の変更を承認します。コミットしてから次のタスクに進んでください。」

request_changes の場合: 通常通り修正指示を記載してください。
```
