#!/bin/bash
# browser-review-runner.sh
# Receives output from generate-browser-review-artifact.sh and returns
# a browser_verdict, reusing route / browser_mode / execution_instructions.

set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required" >&2
  exit 2
fi

ARTIFACT_FILE="${1:-}"
OUTPUT_FILE="${2:-}"

if [ -z "$ARTIFACT_FILE" ]; then
  echo "Usage: scripts/browser-review-runner.sh <browser-artifact-file> [output-file]" >&2
  exit 1
fi

if [ ! -f "$ARTIFACT_FILE" ]; then
  echo "Artifact file not found: $ARTIFACT_FILE" >&2
  exit 3
fi

TASK_ID="$(jq -r '.task.id // "unknown"' "$ARTIFACT_FILE")"
TASK_TITLE="$(jq -r '.task.title // ""' "$ARTIFACT_FILE")"
ROUTE="$(jq -r '.route // "chrome-devtools"' "$ARTIFACT_FILE")"
BROWSER_MODE="$(jq -r '.browser_mode // "scripted"' "$ARTIFACT_FILE")"
REQUIRED_ARTIFACTS="$(jq -c '.required_artifacts // []' "$ARTIFACT_FILE")"
EXECUTION_INSTRUCTIONS="$(jq -c '.execution_instructions // []' "$ARTIFACT_FILE")"

if [ -z "$OUTPUT_FILE" ]; then
  OUTPUT_FILE=".claude/state/review/${TASK_ID}.browser-result.json"
fi

mkdir -p "$(dirname "$OUTPUT_FILE")"
rm -f "$OUTPUT_FILE"

TIMEOUT_SECONDS="${HARNESS_BROWSER_REVIEW_TIMEOUT_SECONDS:-120}"
COMMAND="${HARNESS_BROWSER_REVIEW_COMMAND:-}"
RUNNER_STATUS="unavailable"
NOTE=""
COMMAND_OUTPUT=""
BROWSER_VERDICT=""

run_with_timeout() {
  local timeout_seconds="$1"
  shift

  if command -v timeout >/dev/null 2>&1; then
    timeout "${timeout_seconds}" "$@"
    return $?
  fi

  if command -v gtimeout >/dev/null 2>&1; then
    gtimeout "${timeout_seconds}" "$@"
    return $?
  fi

  if command -v python3 >/dev/null 2>&1; then
    python3 -c '
import subprocess
import sys

timeout_seconds = int(sys.argv[1])
cmd = sys.argv[2:]

def emit(stream, value):
    if not value:
        return
    if isinstance(value, bytes):
        stream.buffer.write(value)
    else:
        stream.write(value)

try:
    completed = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout_seconds)
    emit(sys.stdout, completed.stdout)
    emit(sys.stdout, completed.stderr)
    sys.exit(completed.returncode)
except subprocess.TimeoutExpired as exc:
    emit(sys.stdout, exc.stdout)
    emit(sys.stdout, exc.stderr)
    sys.exit(124)
' "$timeout_seconds" "$@"
    return $?
  fi

  "$@"
}

parse_verdict() {
  local source="$1"

  if printf '%s' "$source" | jq -e . >/dev/null 2>&1; then
    jq -r '.browser_verdict // .verdict // empty' <<EOF_JSON
$source
EOF_JSON
    return 0
  fi

  printf '%s' "$source" | grep -Eo 'APPROVE|REQUEST_CHANGES|PENDING_BROWSER' | head -1 || true
}

default_command_for_route() {
  case "$ROUTE" in
    playwright)
      if [ -f package.json ] && command -v npm >/dev/null 2>&1 && jq -e '
        ((.scripts["test:e2e"]? // "") != "") or
        ((.devDependencies.playwright? // "") != "") or
        ((.devDependencies["@playwright/test"]? // "") != "") or
        ((.dependencies.playwright? // "") != "") or
        ((.dependencies["@playwright/test"]? // "") != "")
      ' package.json >/dev/null 2>&1; then
        printf '%s' "$(command -v npm) run test:e2e"
        return 0
      fi

      if command -v playwright >/dev/null 2>&1; then
        printf '%s' "$(command -v playwright) test"
        return 0
      fi

      if command -v npx >/dev/null 2>&1; then
        printf '%s' "$(command -v npx) playwright test"
        return 0
      fi

      return 1
      ;;
    agent-browser)
      if command -v agent-browser >/dev/null 2>&1; then
        printf '%s' "$(command -v agent-browser)"
        return 0
      fi

      return 1
      ;;
    chrome-devtools)
      return 1
      ;;
    *)
      return 1
      ;;
  esac
}

unavailable_note_for_route() {
  case "$ROUTE" in
    playwright)
      printf '%s' "route=playwright but no executable default was found (need package.json test:e2e, playwright, or npx)"
      ;;
    agent-browser)
      printf '%s' "route=agent-browser but agent-browser is not available on PATH"
      ;;
    chrome-devtools)
      printf '%s' "route=chrome-devtools has no shell-executable default; use HARNESS_BROWSER_REVIEW_COMMAND or connected Chrome tooling"
      ;;
    *)
      printf '%s' "route=$ROUTE has no known shell-executable default"
      ;;
  esac
}

if [ -n "$COMMAND" ]; then
  :
else
  COMMAND="$(default_command_for_route || true)"
  if [ -z "$COMMAND" ]; then
    NOTE="$(unavailable_note_for_route)"
  fi
fi

if [ -n "$COMMAND" ]; then
  export BROWSER_REVIEW_ARTIFACT="$ARTIFACT_FILE"
  export BROWSER_REVIEW_RESULT_FILE="$OUTPUT_FILE"
  export BROWSER_REVIEW_ROUTE="$ROUTE"
  export BROWSER_REVIEW_BROWSER_MODE="$BROWSER_MODE"
  export BROWSER_REVIEW_TASK_ID="$TASK_ID"
  export BROWSER_REVIEW_TASK_TITLE="$TASK_TITLE"
  export BROWSER_REVIEW_REQUIRED_ARTIFACTS="$REQUIRED_ARTIFACTS"
  export BROWSER_REVIEW_EXECUTION_INSTRUCTIONS="$EXECUTION_INSTRUCTIONS"
  export BROWSER_REVIEW_TIMEOUT_SECONDS="$TIMEOUT_SECONDS"

  LOG_FILE="$(mktemp)"
  trap 'rm -f "$LOG_FILE"' EXIT
  set +e
  run_with_timeout "$TIMEOUT_SECONDS" bash -lc "$COMMAND" >"$LOG_FILE" 2>&1
  EXIT_CODE=$?
  set -e
  COMMAND_OUTPUT="$(cat "$LOG_FILE")"

  if [ "$EXIT_CODE" -eq 124 ]; then
    RUNNER_STATUS="timeout"
    NOTE="browser review command timed out after ${TIMEOUT_SECONDS}s"
  else
    if [ -s "$OUTPUT_FILE" ] && jq -e . "$OUTPUT_FILE" >/dev/null 2>&1; then
      COMMAND_OUTPUT="$(cat "$OUTPUT_FILE")"
    fi
      BROWSER_VERDICT="$(parse_verdict "$COMMAND_OUTPUT")"
      if [ -n "$BROWSER_VERDICT" ]; then
        RUNNER_STATUS="ok"
        NOTE="browser review command completed"
      else
      RUNNER_STATUS="failed"
      NOTE="browser review command did not return a recognizable verdict"
    fi
  fi
fi

if [ -z "$BROWSER_VERDICT" ]; then
  BROWSER_VERDICT="PENDING_BROWSER"
fi

if [ -z "$NOTE" ]; then
  NOTE="$(unavailable_note_for_route)"
fi

jq -n \
  --slurpfile artifact "$ARTIFACT_FILE" \
  --arg generated_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg browser_verdict "$BROWSER_VERDICT" \
  --arg runner_status "$RUNNER_STATUS" \
  --arg note "$NOTE" \
  --arg command_output "$COMMAND_OUTPUT" '
  ($artifact[0] // {}) as $in
  | $in
  | .schema_version = "browser-review-result.v1"
  | .generated_at = $generated_at
  | .runner_status = $runner_status
  | .browser_verdict = $browser_verdict
  | .verdict = $browser_verdict
  | .note = $note
  | .command_output = (if $command_output == "" then null else $command_output end)
  ' > "$OUTPUT_FILE"

echo "$OUTPUT_FILE"
