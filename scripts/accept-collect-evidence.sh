#!/bin/bash
# scripts/accept-collect-evidence.sh
# Phase 134.4 - harness-accept 用 evidence 収集 (read-only)
#
# 4 artifact を読み、正規化 JSON (accept-evidence.v1) を stdout に返す。
# 書き込みは一切行わない。artifact の欠損はエラーにせず present:false + reason
# で返す (worker-report が無い旧タスクでも落ちない互換のため)。
#
# `.claude/state/review-result.json` はシングルトン (レビューのたびに上書きされる)
# なので、`.task.id` が引数の <task-id> と一致するときだけ採用する (鮮度チェック)。
# 他の 3 artifact はファイル名自体に <task-id> が入っているため鮮度チェック不要。
#
# Usage:
#   scripts/accept-collect-evidence.sh <task-id>
#
# 読む artifact (すべて cwd 相対の .claude/state/ 配下):
#   1. review/<task-id>.worker-report.json   (Worker self_review evidence)
#   2. review-result.json                    (Reviewer 判定 + pending_validations。task.id 一致時のみ採用)
#   3. review/<task-id>.runtime-review.json  (runtime profile 実行結果)
#   4. review/<task-id>.browser-result.json  (browser profile 実行結果)
#
# 出力 schema: accept-evidence.v1
#   {
#     "schema_version": "accept-evidence.v1",
#     "task_id": "...",
#     "generated_at": "ISO8601",
#     "worker_report":  { "path": "...", "present": bool, "reason": "..."|null, "data": {...}|null },
#     "review_result":  { "path": "...", "present": bool, "reason": "..."|null, "data": {...}|null },
#     "runtime_review": { "path": "...", "present": bool, "reason": "..."|null, "data": {...}|null },
#     "browser_result": { "path": "...", "present": bool, "reason": "..."|null, "data": {...}|null },
#     "pending_validations": [ {"layer": "...", "reason": "..."}, ... ],
#     "demo_artifacts": [ {"kind": "video", "path": "..."}, ... ]
#   }
#
# demo_artifacts (Phase 134.6): browser_result.data.artifacts のうち kind=="video" の
# エントリだけを流し込む (harness-accept skill の demo_artifacts に直接合流させるため。
# acceptance-context.v1 の demo_artifacts item と同じ {kind, path} 形状)。
#
# Exit code: 0=success (artifact 欠損があっても 0), 1=usage error, 2=jq missing

set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required" >&2
  exit 2
fi

TASK_ID="${1:-}"
if [ -z "$TASK_ID" ]; then
  echo "Usage: scripts/accept-collect-evidence.sh <task-id>" >&2
  exit 1
fi

STATE_DIR="$(pwd)/.claude/state"
REVIEW_DIR="${STATE_DIR}/review"

WORKER_REPORT_PATH="${REVIEW_DIR}/${TASK_ID}.worker-report.json"
REVIEW_RESULT_PATH="${STATE_DIR}/review-result.json"
RUNTIME_REVIEW_PATH="${REVIEW_DIR}/${TASK_ID}.runtime-review.json"
BROWSER_RESULT_PATH="${REVIEW_DIR}/${TASK_ID}.browser-result.json"

# read_artifact <real-path> <display-path>
# ファイル名自体が task-id scoped な artifact 用 (鮮度チェック不要)
read_artifact() {
  local path="$1"
  local display="$2"
  if [ ! -f "$path" ]; then
    jq -n --arg path "$display" '{path: $path, present: false, reason: "file not found", data: null}'
    return
  fi
  if ! jq -e '.' "$path" >/dev/null 2>&1; then
    jq -n --arg path "$display" '{path: $path, present: false, reason: "invalid JSON", data: null}'
    return
  fi
  jq -n --arg path "$display" --slurpfile d "$path" '{path: $path, present: true, reason: null, data: $d[0]}'
}

# read_review_result <real-path> <display-path> <expected-task-id>
# シングルトンファイル用: task.id が一致する時だけ採用する鮮度チェック付き
read_review_result() {
  local path="$1"
  local display="$2"
  local expected_task_id="$3"
  if [ ! -f "$path" ]; then
    jq -n --arg path "$display" '{path: $path, present: false, reason: "file not found", data: null}'
    return
  fi
  if ! jq -e '.' "$path" >/dev/null 2>&1; then
    jq -n --arg path "$display" '{path: $path, present: false, reason: "invalid JSON", data: null}'
    return
  fi
  local found_task_id
  found_task_id="$(jq -r '.task.id // empty' "$path")"
  if [ -z "$found_task_id" ]; then
    jq -n --arg path "$display" --arg expected "$expected_task_id" \
      '{path: $path, present: false, reason: ("stale: review-result.json has no task.id (expected " + $expected + ")"), data: null}'
    return
  fi
  if [ "$found_task_id" != "$expected_task_id" ]; then
    jq -n --arg path "$display" --arg expected "$expected_task_id" --arg found "$found_task_id" \
      '{path: $path, present: false, reason: ("stale: task.id mismatch (found " + $found + ", expected " + $expected + ")"), data: null}'
    return
  fi
  jq -n --arg path "$display" --slurpfile d "$path" '{path: $path, present: true, reason: null, data: $d[0]}'
}

WORKER_REPORT_JSON="$(read_artifact "$WORKER_REPORT_PATH" ".claude/state/review/${TASK_ID}.worker-report.json")"
REVIEW_RESULT_JSON="$(read_review_result "$REVIEW_RESULT_PATH" ".claude/state/review-result.json" "$TASK_ID")"
RUNTIME_REVIEW_JSON="$(read_artifact "$RUNTIME_REVIEW_PATH" ".claude/state/review/${TASK_ID}.runtime-review.json")"
BROWSER_RESULT_JSON="$(read_artifact "$BROWSER_RESULT_PATH" ".claude/state/review/${TASK_ID}.browser-result.json")"

# demo_artifacts (Phase 134.6): browser_result.data.artifacts の kind=="video" だけを転記
DEMO_ARTIFACTS_JSON="$(printf '%s' "$BROWSER_RESULT_JSON" | jq -c '
  if .present then [(.data.artifacts // [])[] | select(.kind == "video") | {kind, path}]
  else []
  end
')"

jq -n \
  --arg task_id "$TASK_ID" \
  --arg generated_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --argjson worker_report "$WORKER_REPORT_JSON" \
  --argjson review_result "$REVIEW_RESULT_JSON" \
  --argjson runtime_review "$RUNTIME_REVIEW_JSON" \
  --argjson browser_result "$BROWSER_RESULT_JSON" \
  --argjson demo_artifacts "$DEMO_ARTIFACTS_JSON" \
  '{
    schema_version: "accept-evidence.v1",
    task_id: $task_id,
    generated_at: $generated_at,
    worker_report: $worker_report,
    review_result: $review_result,
    runtime_review: $runtime_review,
    browser_result: $browser_result,
    pending_validations: (
      if $review_result.present then ($review_result.data.pending_validations // [])
      else []
      end
    ),
    demo_artifacts: $demo_artifacts
  }'
