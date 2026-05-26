#!/bin/bash
# generate-browser-review-artifact.sh
# Generates a review artifact template for the browser profile.

set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required" >&2
  exit 2
fi

CONTRACT_FILE="${1:-}"
OUTPUT_FILE="${2:-}"

if [ -z "$CONTRACT_FILE" ]; then
  echo "Usage: scripts/generate-browser-review-artifact.sh <contract-file> [output-file]" >&2
  exit 1
fi

if [ ! -f "$CONTRACT_FILE" ]; then
  echo "Contract file not found: $CONTRACT_FILE" >&2
  exit 3
fi

TASK_ID="$(jq -r '.task.id // "unknown"' "$CONTRACT_FILE")"
TASK_TITLE="$(jq -r '.task.title // ""' "$CONTRACT_FILE")"
PROFILE="$(jq -r '.review.reviewer_profile // "static"' "$CONTRACT_FILE")"
BROWSER_MODE="$(jq -r '
  if (.review.browser_mode // "") != "" then
    .review.browser_mode
  elif ((.task.title // "") | test("(exploratory|agent-browser|snapshot)"; "i")) then
    "exploratory"
  elif ((.task.definition_of_done // .task.dod // "") | test("(exploratory|agent-browser|snapshot)"; "i")) then
    "exploratory"
  elif ((.contract.browser_validation // [] | tostring) | test("(exploratory|agent-browser|snapshot)"; "i")) then
    "exploratory"
  else
    "scripted"
  end
' "$CONTRACT_FILE")"

has_playwright_basis() {
  if [ -n "${HARNESS_BROWSER_REVIEW_DISABLE_PLAYWRIGHT:-}" ]; then
    return 1
  fi

  if [ -f "package.json" ] && jq -e '
    ((.scripts["test:e2e"]? // "") != "") or
    ((.devDependencies.playwright? // "") != "") or
    ((.devDependencies["@playwright/test"]? // "") != "") or
    ((.dependencies.playwright? // "") != "") or
    ((.dependencies["@playwright/test"]? // "") != "")
  ' package.json >/dev/null 2>&1; then
    return 0
  fi

  if command -v playwright >/dev/null 2>&1; then
    return 0
  fi

  return 1
}

has_agent_browser() {
  if [ -n "${HARNESS_BROWSER_REVIEW_DISABLE_AGENT_BROWSER:-}" ]; then
    return 1
  fi

  command -v agent-browser >/dev/null 2>&1
}

detect_route() {
  # Explicit override via environment variable (for testing)
  if [ -n "${HARNESS_BROWSER_REVIEW_ROUTE:-}" ]; then
    printf '%s' "${HARNESS_BROWSER_REVIEW_ROUTE}"
    return 0
  fi

  # Respect the route specified in the contract (when explicitly set in sprint-contract)
  local contract_route
  contract_route="$(jq -r '.review.route // ""' "$CONTRACT_FILE" 2>/dev/null)"
  if [ -n "$contract_route" ]; then
    printf '%s' "$contract_route"
    return 0
  fi

  if [ "$BROWSER_MODE" = "exploratory" ]; then
    if has_agent_browser; then
      printf '%s' "agent-browser"
      return 0
    fi

    if has_playwright_basis; then
      printf '%s' "playwright"
      return 0
    fi

    printf '%s' "chrome-devtools"
    return 0
  fi

  if has_playwright_basis; then
    printf '%s' "playwright"
    return 0
  fi

  # In scripted mode, do not fall back to agent-browser.
  # agent-browser is exploratory and snapshot/exploration-based, and is
  # incompatible with the trace/assertion evidence of a scripted contract,
  # so fall back directly to Chrome DevTools if Playwright is unavailable.
  printf '%s' "chrome-devtools"
}

if [ "$PROFILE" != "browser" ]; then
  echo "Contract is not browser profile: $PROFILE" >&2
  exit 4
fi

ROUTE="$(detect_route)"

if [ -z "$OUTPUT_FILE" ]; then
  OUTPUT_FILE=".claude/state/review/${TASK_ID}.browser-review.json"
fi

mkdir -p "$(dirname "$OUTPUT_FILE")"

jq -n \
  --arg generated_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg task_id "$TASK_ID" \
  --arg task_title "$TASK_TITLE" \
  --arg route "$ROUTE" \
  --arg browser_mode "$BROWSER_MODE" \
  --argjson checks "$(jq '.contract.browser_validation // []' "$CONTRACT_FILE")" \
  '{
    schema_version: "browser-review.v1",
    generated_at: $generated_at,
    task: { id: $task_id, title: $task_title },
    reviewer_profile: "browser",
    browser_mode: $browser_mode,
    route: $route,
    tool_matcher: (
      if $route == "playwright" then
        "mcp__playwright__*|mcp__plugin_playwright_playwright__*"
      elif $route == "agent-browser" then
        "agent-browser|bash agent-browser"
      else
        "mcp__chrome-devtools__*"
      end
    ),
    verdict: "PENDING_BROWSER",
    checks: $checks,
    required_artifacts: (
      if $route == "playwright" then
        ["trace", "screenshot", "ui-flow-log"]
      elif $route == "agent-browser" then
        ["snapshot", "ui-flow-log"]
      else
        (if $browser_mode == "exploratory" then ["snapshot", "screenshot", "ui-flow-log"]
         else ["screenshot", "ui-flow-log"] end)
      end
    ),
    execution_instructions: (
      if $route == "playwright" then
        [
          "Use Playwright MCP for browser review.",
          "Capture trace, screenshot, and UI flow log for each browser_validation check.",
          "If the repo has test:e2e, prefer aligning the review flow with that script.",
          ("browser_mode: " + $browser_mode)
        ]
      elif $route == "agent-browser" then
        [
          "Use agent-browser CLI for browser review.",
          "Capture snapshot and UI flow log for each browser_validation check.",
          "Prefer exploratory checks over fixed test scripts when the contract allows it.",
          ("browser_mode: " + $browser_mode)
        ]
      else
        [
          "Enable Chrome Integration with --chrome or /chrome before review.",
          "Use Chrome DevTools MCP to capture screenshot and UI flow log.",
          "Review layout regression and major user path defined in browser_validation.",
          ("browser_mode: " + $browser_mode)
        ]
      end
    ),
    note: "Run this contract with the selected browser-capable evaluator."
  }' > "$OUTPUT_FILE"

echo "$OUTPUT_FILE"
