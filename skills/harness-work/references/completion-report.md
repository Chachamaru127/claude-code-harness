# Harness Work Completion Report

The Lead writes this report after review passes. A Worker or hook must not
render the final closeout.

## Locale Selection

Resolve the active locale through `get_harness_locale` as required by the
parent `SKILL.md` output contract. Use the English template for unset, invalid,
or resolved `en`. Use the Japanese template only for resolved `ja`. Render one
locale only; do not combine labels from both templates.

For a forced single-task Parallel run, use the Solo template. For a multi-task
Parallel run, use the Breezing template.

## Evidence Rules

- Derive changes and files from git, validation from commands actually run,
  review from the review artifact, and remaining work from `Plans.md`.
- Keep status markers, review verdicts, commit hashes, paths, and commands in
  their machine-readable form.
- Omit an optional row when there is no corresponding evidence. Never invent a
  success, remaining task, or blocked task.

## Solo / Single Task

### English (default)

<!-- completion-report-template:solo:en:start -->
```
┌────────────────────────────────────────────────────┐
│  ✓ Task {task_id} complete: {task_title}           │
├────────────────────────────────────────────────────┤
│  ■ What changed                                    │
│    • {change_1}                                     │
│    • {change_2}                                     │
│                                                    │
│  ■ User impact                                     │
│    Before: {before}                                 │
│    After:  {after}                                  │
│                                                    │
│  ■ Changed files ({file_count} files)              │
│    {file_1}                                         │
│    {file_2}                                         │
│                                                    │
│  ■ Validation                                      │
│    • {validation_1}                                 │
│    • {validation_2}                                 │
│                                                    │
│  ■ Remaining work                                  │
│    • Task {remaining_task_id} ({status}):           │
│      {remaining_task_title} ← Plans.md              │
│    ({remaining_count} unfinished tasks)             │
│                                                    │
│  ■ Blocked work                                    │
│    {blocked_summary}                                │
│                                                    │
│  commit: {commit_hash} | review: {review_verdict}  │
└────────────────────────────────────────────────────┘
```
<!-- completion-report-template:solo:en:end -->

### Japanese (explicit `ja` only)

<!-- completion-report-template:solo:ja:start -->
```
┌────────────────────────────────────────────────────┐
│  ✓ タスク {task_id} 完了: {task_title}             │
├────────────────────────────────────────────────────┤
│  ■ 何をしたか                                      │
│    • {change_1}                                     │
│    • {change_2}                                     │
│                                                    │
│  ■ 何が変わるか                                    │
│    変更前: {before}                                 │
│    変更後: {after}                                  │
│                                                    │
│  ■ 変更ファイル（{file_count}件）                   │
│    {file_1}                                         │
│    {file_2}                                         │
│                                                    │
│  ■ 検証                                            │
│    • {validation_1}                                 │
│    • {validation_2}                                 │
│                                                    │
│  ■ 残りの課題                                      │
│    • タスク {remaining_task_id} ({status}):         │
│      {remaining_task_title} ← Plans.md              │
│    （未完了 {remaining_count} 件）                  │
│                                                    │
│  ■ ブロック中の課題                                │
│    {blocked_summary}                                │
│                                                    │
│  コミット: {commit_hash} | レビュー: {review_verdict} │
└────────────────────────────────────────────────────┘
```
<!-- completion-report-template:solo:ja:end -->

## Breezing / Multi Task

Before rendering, collect the task commits and aggregate diff from the run's
recorded base:

```bash
git log --oneline "${BASE_REF}..HEAD"
git diff --stat "${BASE_REF}..HEAD"
```

### English (default)

<!-- completion-report-template:breezing:en:start -->
```
┌─────────────────────────────────────────────────────────┐
│  ✓ Breezing complete: {completed_count}/{total_count} tasks │
├─────────────────────────────────────────────────────────┤
│  1. ✓ {task_1_title} [{task_1_commit}]                  │
│  2. ✓ {task_2_title} [{task_2_commit}]                  │
│  3. ✓ {task_3_title} [{task_3_commit}]                  │
│                                                         │
│  ■ Aggregate changes                                    │
│    {file_count} files changed, {insertions} insertions, │
│    {deletions} deletions                                │
│                                                         │
│  ■ Validation                                           │
│    {validation_summary}                                 │
│                                                         │
│  ■ Review                                               │
│    {review_summary}                                     │
│                                                         │
│  ■ Remaining work                                       │
│    {remaining_count} unfinished tasks in Plans.md       │
│    • Task {remaining_task_id}: {remaining_task_title}   │
│                                                         │
│  ■ Failed or blocked work                               │
│    {blocked_summary}                                    │
└─────────────────────────────────────────────────────────┘
```
<!-- completion-report-template:breezing:en:end -->

### Japanese (explicit `ja` only)

<!-- completion-report-template:breezing:ja:start -->
```
┌─────────────────────────────────────────────────────────┐
│  ✓ Breezing 完了: {completed_count}/{total_count}タスク │
├─────────────────────────────────────────────────────────┤
│  1. ✓ {task_1_title} [{task_1_commit}]                  │
│  2. ✓ {task_2_title} [{task_2_commit}]                  │
│  3. ✓ {task_3_title} [{task_3_commit}]                  │
│                                                         │
│  ■ 全体の変更                                           │
│    {file_count}ファイル変更、{insertions}行追加、       │
│    {deletions}行削除                                    │
│                                                         │
│  ■ 検証                                                 │
│    {validation_summary}                                 │
│                                                         │
│  ■ レビュー                                             │
│    {review_summary}                                     │
│                                                         │
│  ■ 残りの課題                                           │
│    Plans.md に未完了 {remaining_count} 件               │
│    • タスク {remaining_task_id}: {remaining_task_title} │
│                                                         │
│  ■ 失敗またはブロック中の課題                           │
│    {blocked_summary}                                    │
└─────────────────────────────────────────────────────────┘
```
<!-- completion-report-template:breezing:ja:end -->
