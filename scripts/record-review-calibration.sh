#!/bin/bash
# record-review-calibration.sh
# Append to the learning log when review-result.json contains a calibration entry.
#
# Usage: ./scripts/record-review-calibration.sh <review-result-file> [output-file] [--review-result <path>]

set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required" >&2
  exit 2
fi

INPUT_FILE=""
OUTPUT_FILE=".claude/state/review-calibration.jsonl"
REVIEW_RESULT_FILE=""

# Option parsing: absorb --review-result first, then process remaining positionals
_positional=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --review-result)
      shift
      REVIEW_RESULT_FILE="${1:-}"
      ;;
    --*)
      # Ignore unknown options and continue
      ;;
    *)
      _positional+=("$1")
      ;;
  esac
  shift
done

# Finalize positional arguments
if [ "${#_positional[@]}" -ge 1 ]; then
  INPUT_FILE="${_positional[0]}"
fi
if [ "${#_positional[@]}" -ge 2 ]; then
  OUTPUT_FILE="${_positional[1]}"
fi

if [ -z "$INPUT_FILE" ]; then
  echo "Usage: scripts/record-review-calibration.sh <review-result-file> [output-file] [--review-result <path>]" >&2
  exit 1
fi

if [ ! -f "$INPUT_FILE" ]; then
  echo "Input file not found: $INPUT_FILE" >&2
  exit 3
fi

LABEL="$(jq -r '.calibration.label // empty' "$INPUT_FILE")"
if [ -z "$LABEL" ]; then
  exit 0
fi

case "$LABEL" in
  false_positive|false_negative|missed_bug|overstrict_rule) ;;
  *)
    echo "Invalid calibration label: $LABEL" >&2
    exit 4
    ;;
esac

mkdir -p "$(dirname "$OUTPUT_FILE")"

# If --review-result is not explicitly specified, use INPUT_FILE as fallback
if [ -z "$REVIEW_RESULT_FILE" ]; then
  REVIEW_RESULT_FILE="$INPUT_FILE"
fi

# Error if --review-result file does not exist
if [ ! -f "$REVIEW_RESULT_FILE" ]; then
  echo "Review result file not found: $REVIEW_RESULT_FILE" >&2
  exit 3
fi

# Get task ID (used for score_delta calculation)
TASK_ID="$(jq -r '(.task.id // "") | ltrimstr("null")' "$INPUT_FILE")"

# Get the previous critical_count + major_count for the same task (null if not present)
PREV_SCORE="null"
if [ -n "$TASK_ID" ] && [ -f "$OUTPUT_FILE" ]; then
  _prev="$(jq -r --arg tid "$TASK_ID" \
    'select(.task.id == $tid) | (.critical_count // 0) + (.major_count // 0)' \
    "$OUTPUT_FILE" 2>/dev/null | tail -1)"
  if [ -n "$_prev" ]; then
    PREV_SCORE="$_prev"
  fi
fi

jq -c -n \
  --slurpfile src "$INPUT_FILE" \
  --slurpfile rr "$REVIEW_RESULT_FILE" \
  --arg generated_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --argjson prev_score "$PREV_SCORE" \
  '
  ($src[0] // {}) as $in
  | ($rr[0] // {}) as $rv
  # critical_count: aggregate all sources same as write-review-result.sh normalization
  #   1. legacy: critical_issues[] (old format)
  #   2. normalized: gaps[severity == "critical"]
  #   3. companion raw: findings[severity == "critical"]
  #   4. reviewer raw: observations[severity == "critical"]
  | ((($rv.critical_issues // []) | length)
     + (($rv.gaps // []) | map(select(.severity == "critical")) | length)
     + (($rv.findings // []) | map(select(.severity == "critical")) | length)
     + (($rv.observations // []) | map(select(.severity == "critical")) | length)) as $critical_count
  # major_count: aggregate all sources same as write-review-result.sh normalization
  #   1. legacy: major_issues[] (old format)
  #   2. normalized: gaps[severity == "major"]
  #   3. companion raw: findings[severity == "high"] (!! high is projected to major)
  #   4. reviewer raw: observations[severity == "major"]
  | ((($rv.major_issues // []) | length)
     + (($rv.gaps // []) | map(select(.severity == "major")) | length)
     + (($rv.findings // []) | map(select(.severity == "high")) | length)
     + (($rv.observations // []) | map(select(.severity == "major")) | length)) as $major_count
  | (if $prev_score == null then null
     else (($critical_count + $major_count) - $prev_score)
     end) as $score_delta
  | {
      schema_version: "review-calibration.v1",
      generated_at: $generated_at,
      task: ($in.task // {id: null, title: null}),
      reviewer_profile: ($in.reviewer_profile // "static"),
      review_type: ($in.type // "code"),
      verdict: ($in.verdict // "REQUEST_CHANGES"),
      calibration_label: ($in.calibration.label // null),
      calibration_source: ($in.calibration.source // "manual"),
      calibration_notes: ($in.calibration.notes // ""),
      prompt_hint: ($in.calibration.prompt_hint // ""),
      few_shot_ready: ($in.calibration.few_shot_ready // true),
      execution: ($in.execution // null),
      checks: ($in.checks // []),
      gaps: ($in.gaps // []),
      followups: ($in.followups // []),
      critical_count: $critical_count,
      major_count: $major_count,
      score_delta: $score_delta,
      review_result_snapshot: {
        schema_version: ($in.schema_version // "review-result.v1"),
        verdict: ($in.verdict // null),
        reviewer_profile: ($in.reviewer_profile // null),
        commit_hash: ($in.commit_hash // null)
      }
    }' >> "$OUTPUT_FILE"

echo "$OUTPUT_FILE"
