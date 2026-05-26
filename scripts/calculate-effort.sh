#!/bin/bash
# calculate-effort.sh
# Reads task information from Plans.md, calculates the effort level, and outputs it to stdout.
#
# Usage:
#   bash scripts/calculate-effort.sh "task description or task ID"
#   echo "task description" | bash scripts/calculate-effort.sh
#
# Output: low / medium / high (stdout)
#
# Scoring criteria:
#   4+ candidate files to change → +2
#   2+ dependent tasks           → +1
#   keywords (refactor, migration, security, cross-cutting) → +1
#   2+ conditions in DoD         → +1
#
# Score: 0-2 → low, 3-4 → medium, 5+ → high

set -euo pipefail

# Get task description from arguments or stdin
TASK_INPUT=""
if [ $# -gt 0 ]; then
  TASK_INPUT="$*"
elif [ ! -t 0 ]; then
  # Input from stdin (pipe)
  TASK_INPUT="$(cat)"
fi

if [ -z "$TASK_INPUT" ]; then
  # No input → fallback
  echo "medium"
  exit 0
fi

# Initialize score
SCORE=0

# Resolve Plans.md path (fallback order: git root → PROJECT_ROOT → cwd)
_GIT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
PLANS_MD="${PROJECT_ROOT:-${_GIT_ROOT:-$(pwd)}}/Plans.md"

# Extract task information from Plans.md
# Assumes v2 format: | Task | Content | DoD | Depends | Status |
TASK_CONTENT=""
TASK_DOD=""
TASK_DEPENDS=""

if [ -f "$PLANS_MD" ]; then
  # Search by task ID pattern (#123, 34.2.2, #34.2.2 format)
  TASK_ID_PATTERN=""
  if echo "$TASK_INPUT" | grep -qE '^#?[0-9]+(\.[0-9]+)*$'; then
    TASK_ID_PATTERN=$(echo "$TASK_INPUT" | tr -d '#')
    # Parse table row: | Number | Content | DoD | Depends | Status |
    TASK_ROW=$(grep -E "^\|[[:space:]]*${TASK_ID_PATTERN}[[:space:]]*\|" "$PLANS_MD" 2>/dev/null || true)
    if [ -n "$TASK_ROW" ]; then
      # Extract columns by pipe delimiter
      TASK_CONTENT=$(echo "$TASK_ROW" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $3); print $3}')
      TASK_DOD=$(echo "$TASK_ROW" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $4); print $4}')
      TASK_DEPENDS=$(echo "$TASK_ROW" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $5); print $5}')
    fi
  fi

  # If not found by task ID, search by keyword in description
  if [ -z "$TASK_CONTENT" ]; then
    # Extract table rows from Plans.md close to the task description
    TASK_ROW=$(grep -iF "$(echo "$TASK_INPUT" | cut -c1-50)" "$PLANS_MD" 2>/dev/null | grep "^|" | head -1 || true)
    if [ -n "$TASK_ROW" ]; then
      TASK_CONTENT=$(echo "$TASK_ROW" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $3); print $3}')
      TASK_DOD=$(echo "$TASK_ROW" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $4); print $4}')
      TASK_DEPENDS=$(echo "$TASK_ROW" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $5); print $5}')
    fi
  fi
fi

# If Plans.md did not return results, analyze the task input itself
if [ -z "$TASK_CONTENT" ]; then
  TASK_CONTENT="$TASK_INPUT"
fi

# Analysis target text (concatenation of task content + DoD + input text)
ANALYSIS_TEXT="${TASK_CONTENT} ${TASK_DOD} ${TASK_INPUT}"

# ---- Scoring ----

# 1. 4+ candidate files to change → +2
# Count file references in the task description (.ts .js .sh .json .md .go .py .rb .tsx .jsx)
FILE_REFS=$(echo "$ANALYSIS_TEXT" | { grep -oE '[a-zA-Z0-9_/-]+\.(ts|tsx|js|jsx|sh|json|md|go|py|rb|css|scss|yaml|yml)' || true; } | wc -l | tr -d '[:space:]')
if [ "${FILE_REFS:-0}" -ge 4 ]; then
  SCORE=$((SCORE + 2))
fi

# 2. 2+ dependent tasks → +1
if [ -n "$TASK_DEPENDS" ]; then
  # Count dependent tasks in the Depends column (dotted ID: 34.1.1, simple ID: #123, comma-separated, etc.)
  # Count dotted IDs first, then simple numeric IDs from the remainder
  DEP_COUNT=$(echo "$TASK_DEPENDS" | { grep -oE '#?[0-9]+(\.[0-9]+)+' || true; } | wc -l | tr -d '[:space:]')
  SIMPLE_COUNT=$(echo "$TASK_DEPENDS" | sed -E 's/#?[0-9]+(\.[0-9]+)+//g' | { grep -oE '#?[0-9]+' || true; } | wc -l | tr -d '[:space:]')
  DEP_COUNT=$((DEP_COUNT + SIMPLE_COUNT))
  if [ "${DEP_COUNT:-0}" -ge 2 ]; then
    SCORE=$((SCORE + 1))
  fi
fi

# 3. Keyword check → +1 (add once if 1 or more matches, no duplicates)
KEYWORDS="refactor migration security cross-cutting"
KEYWORD_MATCH=0
for kw in $KEYWORDS; do
  if echo "$ANALYSIS_TEXT" | grep -qi "$kw" 2>/dev/null; then
    KEYWORD_MATCH=1
    break
  fi
done
SCORE=$((SCORE + KEYWORD_MATCH))

# 4. 2+ conditions in DoD → +1
if [ -n "$TASK_DOD" ]; then
  # Count conditions separated by semicolons or commas (delimiters + 1 = condition count)
  DOD_DELIMITERS=$(echo "$TASK_DOD" | { grep -oE '[;,]' || true; } | wc -l | tr -d '[:space:]')
  DOD_TOTAL=$(( DOD_DELIMITERS + 1 ))
  if [ "${DOD_TOTAL:-1}" -ge 2 ]; then
    SCORE=$((SCORE + 1))
  fi
fi

# ---- Determine effort level ----
if [ "$SCORE" -ge 5 ]; then
  echo "high"
elif [ "$SCORE" -ge 3 ]; then
  echo "medium"
else
  echo "low"
fi
