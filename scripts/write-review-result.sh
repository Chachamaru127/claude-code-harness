#!/bin/bash
# write-review-result.sh
# さまざまな review 出力を review-result.v1 に正規化し、後方互換の review-approved.json も更新する。

set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required" >&2
  exit 2
fi

BROWSER_RESULT_FILE=""
POSITIONAL=()
while [ $# -gt 0 ]; do
  case "$1" in
    --browser-result)
      if [ $# -lt 2 ] || [ -z "${2:-}" ]; then
        echo "Usage: scripts/write-review-result.sh <input-json-file> [commit-hash] [output-file] [--browser-result <browser-json-file>]" >&2
        exit 1
      fi
      BROWSER_RESULT_FILE="$2"
      shift 2
      ;;
    --browser-result=*)
      BROWSER_RESULT_FILE="${1#*=}"
      shift
      ;;
    --)
      shift
      while [ $# -gt 0 ]; do
        POSITIONAL+=("$1")
        shift
      done
      ;;
    -*)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
    *)
      POSITIONAL+=("$1")
      shift
      ;;
  esac
done

INPUT_FILE="${POSITIONAL[0]:-}"
COMMIT_HASH="${POSITIONAL[1]:-}"
OUTPUT_FILE="${POSITIONAL[2]:-.claude/state/review-result.json}"
LEGACY_FILE=".claude/state/review-approved.json"

if [ -z "$INPUT_FILE" ]; then
  echo "Usage: scripts/write-review-result.sh <input-json-file> [commit-hash] [output-file] [--browser-result <browser-json-file>]" >&2
  exit 1
fi

if [ ! -f "$INPUT_FILE" ]; then
  echo "Input file not found: $INPUT_FILE" >&2
  exit 3
fi

if [ -n "$BROWSER_RESULT_FILE" ] && [ ! -f "$BROWSER_RESULT_FILE" ]; then
  echo "Browser result file not found: $BROWSER_RESULT_FILE" >&2
  exit 4
fi

mkdir -p "$(dirname "$OUTPUT_FILE")"
mkdir -p "$(dirname "$LEGACY_FILE")"

BROWSER_SLURP_FILE="$(mktemp)"
trap 'rm -f "$BROWSER_SLURP_FILE"' EXIT
if [ -n "$BROWSER_RESULT_FILE" ]; then
  cp "$BROWSER_RESULT_FILE" "$BROWSER_SLURP_FILE"
else
  printf 'null
' > "$BROWSER_SLURP_FILE"
fi

jq -n   --slurpfile src "$INPUT_FILE"   --slurpfile browser "$BROWSER_SLURP_FILE"   --arg generated_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)"   --arg commit_hash "$COMMIT_HASH" '
  def as_array(v):
    if v == null then []
    elif (v | type) == "array" then v
    else [v]
    end;
  def normalize_gap(item; severity):
    if (item | type) == "string" then
      {severity: severity, issue: item}
    else
      item + {severity: (item.severity // severity)}
    end;
  def is_browser_pending(v):
    v == null or v == "" or v == "PENDING_BROWSER" or v == "SKIPPED" or v == "DOWNGRADE_TO_STATIC";
  # pending_validations 用: browser_verdict が明示的な縮退マーカーの時だけ layer を積む
  # (is_browser_pending は「browser を使っていない」null/"" も pending 扱いするため、
  #  fail-visible 表示にはこちらの厳密判定を使う)
  def is_pending_marker(v):
    v == "PENDING_BROWSER" or v == "SKIPPED" or v == "DOWNGRADE_TO_STATIC";
  # companion verdict 正規化: approve→APPROVE, needs-attention→REQUEST_CHANGES
  def normalize_verdict(v):
    if v == "approve" then "APPROVE"
    elif v == "needs-attention" then "REQUEST_CHANGES"
    else v
    end;
  def combine_verdict(static; browser):
    if is_browser_pending(browser) then static
    elif static == "REQUEST_CHANGES" or browser == "REQUEST_CHANGES" then "REQUEST_CHANGES"
    elif static == "APPROVE" and browser == "APPROVE" then "APPROVE"
    elif is_browser_pending(static) then browser
    else static
    end;
  # companion findings[] → gaps[] マッピング（引数で入力を受け取る）
  # companion findings → gaps（critical/high のみブロッキング）
  def findings_to_gaps(input):
    as_array(input.findings) | map({
      severity: .severity,
      issue: (.title // .body // ""),
      file: (.file // null),
      line_start: (.line_start // null),
      line_end: (.line_end // null),
      recommendation: (.recommendation // "")
    }) | map(select(.severity | IN("critical","high")));
  # companion findings → followups（medium/low は非ブロッキング）
  def findings_to_followups(input):
    as_array(input.findings) | map({
      severity: .severity,
      issue: (.title // .body // ""),
      file: (.file // null),
      recommendation: (.recommendation // "")
    }) | map(select(.severity | IN("medium","low")));
  ($src[0] // {}) as $in
  | ($browser[0] // {}) as $browser_in
  | (normalize_verdict($in.verdict // $in.judgment // "REQUEST_CHANGES")) as $static_verdict
  | (normalize_verdict($browser_in.browser_verdict // $browser_in.verdict // $in.browser_verdict // null)) as $browser_verdict
  | {
      schema_version: "review-result.v1",
      generated_at: $generated_at,
      verdict: combine_verdict($static_verdict; $browser_verdict),
      browser_verdict: $browser_verdict,
      reviewer_profile: ($in.reviewer_profile // $browser_in.reviewer_profile // "static"),
      task: ($in.task // $browser_in.task // null),
      type: ($in.type // $in.review_type // $browser_in.type // $browser_in.review_type // null),
      commit_hash: (if $commit_hash == "" then ($in.commit_hash // null) else $commit_hash end),
      execution: (
        if (($in.route // null) != null) or (($in.mode // null) != null) or (($in.browser_mode // null) != null) or (($in.tool_matcher // null) != null) or (($in.required_artifacts // null) != null) or (($in.execution_instructions // null) != null) or (($browser_in.route // null) != null) or (($browser_in.mode // null) != null) or (($browser_in.browser_mode // null) != null) or (($browser_in.tool_matcher // null) != null) or (($browser_in.required_artifacts // null) != null) or (($browser_in.execution_instructions // null) != null) then
          {
            route: ($in.route // $browser_in.route // null),
            mode: ($in.mode // $in.browser_mode // $browser_in.mode // $browser_in.browser_mode // null),
            tool_matcher: ($in.tool_matcher // $browser_in.tool_matcher // null),
            browser_mode: ($in.browser_mode // $browser_in.browser_mode // null),
            required_artifacts: (
              if ($in.required_artifacts // null) != null then $in.required_artifacts
              elif ($browser_in.required_artifacts // null) != null then $browser_in.required_artifacts
              else []
              end
            ),
            instructions: (
              if ($in.execution_instructions // null) != null then
                if ($in.execution_instructions | type) == "array" then $in.execution_instructions else [$in.execution_instructions] end
              elif ($browser_in.execution_instructions // null) != null then
                if ($browser_in.execution_instructions | type) == "array" then $browser_in.execution_instructions else [$browser_in.execution_instructions] end
              else []
              end
            )
          }
        else null
        end
      ),
      calibration: (
        if (($in.calibration // null) != null) or (($in.calibration_label // null) != null) then
          {
            label: ($in.calibration.label // $in.calibration_label // null),
            source: ($in.calibration.source // "manual"),
            notes: ($in.calibration.notes // ""),
            prompt_hint: ($in.calibration.prompt_hint // ""),
            few_shot_ready: ($in.calibration.few_shot_ready // true)
          }
        else null
        end
      ),
      checks: (
        if (($in.checks // null) != null) and (($in.checks | length) > 0) then $in.checks
        elif ($browser_in.checks // null) != null then $browser_in.checks
        else []
        end
      ),
      gaps: (
        (as_array($in.gaps) | map(normalize_gap(.; "major")))
        + (as_array($browser_in.gaps) | map(normalize_gap(.; "major")))
        + (as_array($in.critical_issues) | map(normalize_gap(.; "critical")))
        + (as_array($browser_in.critical_issues) | map(normalize_gap(.; "critical")))
        + (as_array($in.major_issues) | map(normalize_gap(.; "major")))
        + (as_array($browser_in.major_issues) | map(normalize_gap(.; "major")))
        + (as_array($in.observations) | map(select((.severity // "minor") | IN("critical","major"))))
        + (as_array($browser_in.observations) | map(select((.severity // "minor") | IN("critical","major"))))
        + findings_to_gaps($in)
        + findings_to_gaps($browser_in)
      ),
      followups: (
        as_array($in.followups)
        + as_array($browser_in.followups)
        + as_array($in.recommendations)
        + as_array($browser_in.recommendations)
        + (as_array($in.observations) | map(select((.severity // "minor") | IN("minor","recommendation"))))
        + (as_array($browser_in.observations) | map(select((.severity // "minor") | IN("minor","recommendation"))))
        + findings_to_followups($in)
        + findings_to_followups($browser_in)
      ),
      dual_review: ($in.dual_review // null),
      pending_validations: (
        (if is_pending_marker($browser_verdict) then
          [{layer: "browser", reason: ("browser verdict is " + $browser_verdict)}]
         else [] end)
        + (if ($in.verdict == "SKIPPED") and (($in.reviewer_profile // "static") != "static") then
          [{layer: "runtime", reason: ($in.note // "runtime artifact reported SKIPPED")}]
         else [] end)
      )
    }' > "$OUTPUT_FILE"

# blocking gaps がある場合は verdict を REQUEST_CHANGES に強制
BLOCKING_GAPS="$(jq '[.gaps[] | select(.severity == "critical" or .severity == "high" or .severity == "major")] | length' "$OUTPUT_FILE" 2>/dev/null || echo 0)"
if [ "$BLOCKING_GAPS" -gt 0 ]; then
  jq '.verdict = "REQUEST_CHANGES"' "$OUTPUT_FILE" > "${OUTPUT_FILE}.tmp" && mv "${OUTPUT_FILE}.tmp" "$OUTPUT_FILE"
fi

VERDICT="$(jq -r '.verdict' "$OUTPUT_FILE")"
CALIBRATION_PRESENT="$(jq -r '.calibration.label // empty' "$OUTPUT_FILE")"
if [ "$VERDICT" = "APPROVE" ]; then
  jq -n     --arg approved_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)"     --arg judgment "APPROVE"     --arg commit_hash "$COMMIT_HASH"     '{approved_at:$approved_at, judgment:$judgment, commit_hash:(if $commit_hash == "" then null else $commit_hash end)}' > "$LEGACY_FILE"
else
  rm -f "$LEGACY_FILE" 2>/dev/null || true
fi

if [ -n "$CALIBRATION_PRESENT" ]; then
  CALIBRATION_SCRIPT="$(dirname "$0")/record-review-calibration.sh"
  FEW_SHOT_SCRIPT="$(dirname "$0")/build-review-few-shot-bank.sh"
  CALIBRATION_LOG=".claude/state/review-calibration.jsonl"
  FEW_SHOT_BANK=".claude/state/review-few-shot-bank.json"
  if [ -x "$CALIBRATION_SCRIPT" ]; then
    "$CALIBRATION_SCRIPT" "$OUTPUT_FILE" >/dev/null
  fi
  if [ -x "$FEW_SHOT_SCRIPT" ] && [ -f "$CALIBRATION_LOG" ]; then
    "$FEW_SHOT_SCRIPT" "$CALIBRATION_LOG" "$FEW_SHOT_BANK" >/dev/null
  fi
fi

echo "$OUTPUT_FILE"
