#!/bin/bash
# auto-test-runner.sh - Automatic test execution on file changes
# Called from the PostToolUse hook

set +e  # do not stop on error

# Get the changed file (stdin JSON takes priority / fallback: $1,$2)
INPUT=""
if [ ! -t 0 ]; then
  INPUT="$(cat 2>/dev/null)"
fi

CHANGED_FILE="${1:-}"
TOOL_NAME="${2:-}"
CWD=""

if [ -n "$INPUT" ]; then
  if command -v jq >/dev/null 2>&1; then
    TOOL_NAME_FROM_STDIN="$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)"
    FILE_PATH_FROM_STDIN="$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // .tool_response.filePath // empty' 2>/dev/null)"
    CWD_FROM_STDIN="$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)"
  elif command -v python3 >/dev/null 2>&1; then
    eval "$(printf '%s' "$INPUT" | python3 -c '
import json, shlex, sys
try:
    data = json.load(sys.stdin)
except Exception:
    data = {}
tool_name = data.get("tool_name") or ""
cwd = data.get("cwd") or ""
tool_input = data.get("tool_input") or {}
tool_response = data.get("tool_response") or {}
file_path = tool_input.get("file_path") or tool_response.get("filePath") or ""
print(f"TOOL_NAME_FROM_STDIN={shlex.quote(tool_name)}")
print(f"CWD_FROM_STDIN={shlex.quote(cwd)}")
print(f"FILE_PATH_FROM_STDIN={shlex.quote(file_path)}")
' 2>/dev/null)"
  fi

  [ -z "$CHANGED_FILE" ] && CHANGED_FILE="${FILE_PATH_FROM_STDIN:-}"
  [ -z "$TOOL_NAME" ] && TOOL_NAME="${TOOL_NAME_FROM_STDIN:-}"
  CWD="${CWD_FROM_STDIN:-}"
fi

# Normalize to project-relative path if possible
if [ -n "$CWD" ] && [ -n "$CHANGED_FILE" ] && [[ "$CHANGED_FILE" == "$CWD/"* ]]; then
  CHANGED_FILE="${CHANGED_FILE#$CWD/}"
fi

# Files excluded from test triggering
EXCLUDED_PATTERNS=(
    "*.md"
    "*.json"
    "*.yml"
    "*.yaml"
    ".gitignore"
    "*.lock"
    "node_modules/*"
    ".git/*"
)

# Determine whether tests need to be run
should_run_tests() {
    local file="$1"

    # Skip if file is empty
    [ -z "$file" ] && return 1

    # Skip if file matches an excluded pattern
    for pattern in "${EXCLUDED_PATTERNS[@]}"; do
        if [[ "$file" == $pattern ]]; then
            return 1
        fi
    done

    # Change to a test file itself
    if [[ "$file" == *".test."* ]] || [[ "$file" == *".spec."* ]] || [[ "$file" == *"__tests__"* ]]; then
        return 0
    fi

    # Change to a source code file
    if [[ "$file" == *.ts ]] || [[ "$file" == *.tsx ]] || [[ "$file" == *.js ]] || [[ "$file" == *.jsx ]]; then
        return 0
    fi

    if [[ "$file" == *.py ]]; then
        return 0
    fi

    if [[ "$file" == *.go ]]; then
        return 0
    fi

    if [[ "$file" == *.rs ]]; then
        return 0
    fi

    return 1
}

# Detect the test command
detect_test_command() {
    # When package.json exists
    if [ -f "package.json" ]; then
        if grep -q '"test"' package.json 2>/dev/null; then
            echo "npm test"
            return 0
        fi
    fi

    # pytest
    if [ -f "pytest.ini" ] || [ -f "pyproject.toml" ] || [ -d "tests" ]; then
        if command -v pytest &>/dev/null; then
            echo "pytest"
            return 0
        fi
    fi

    # go test
    if [ -f "go.mod" ]; then
        echo "go test ./..."
        return 0
    fi

    # cargo test
    if [ -f "Cargo.toml" ]; then
        echo "cargo test"
        return 0
    fi

    return 1
}

# Detect related test files
find_related_tests() {
    local file="$1"
    local basename="${file%.*}"
    local dirname=$(dirname "$file")

    # Test file patterns
    local test_patterns=(
        "${basename}.test.ts"
        "${basename}.test.tsx"
        "${basename}.test.js"
        "${basename}.test.jsx"
        "${basename}.spec.ts"
        "${basename}.spec.tsx"
        "${basename}.spec.js"
        "${basename}.spec.jsx"
        "${dirname}/__tests__/$(basename "$basename").test.ts"
        "${dirname}/__tests__/$(basename "$basename").test.tsx"
        "test_${basename##*/}.py"
        "${basename##*/}_test.go"
    )

    for pattern in "${test_patterns[@]}"; do
        if [ -f "$pattern" ]; then
            echo "$pattern"
            return 0
        fi
    done

    return 1
}

# Actually run tests and write the result file (HARNESS_AUTO_TEST=run mode)
run_tests() {
    local test_cmd="$1"
    local related_test="$2"

    STATE_DIR=".claude/state"
    mkdir -p "$STATE_DIR"

    RESULT_FILE="${STATE_DIR}/test-result.json"
    TIMESTAMP="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

    # Determine execution command (narrow down to related tests if available)
    if [ -n "$related_test" ]; then
        EXEC_CMD="$test_cmd -- $related_test"
    else
        EXEC_CMD="$test_cmd"
    fi

    # Run tests with a timeout (maximum 60 seconds)
    TIMEOUT_CMD=$(command -v timeout || command -v gtimeout || echo "")
    TMP_OUT="${STATE_DIR}/test-output.tmp"

    if [ -n "$TIMEOUT_CMD" ]; then
        $TIMEOUT_CMD 60 bash -c "$EXEC_CMD" > "$TMP_OUT" 2>&1
        EXIT_CODE=$?
    else
        bash -c "$EXEC_CMD" > "$TMP_OUT" 2>&1
        EXIT_CODE=$?
    fi

    # Capture output (up to 200 lines)
    OUTPUT=$(head -200 "$TMP_OUT" 2>/dev/null || true)
    rm -f "$TMP_OUT"

    # Determine pass/fail
    if [ "$EXIT_CODE" -eq 0 ]; then
        STATUS="passed"
    elif [ "$EXIT_CODE" -eq 124 ]; then
        STATUS="timeout"
    else
        STATUS="failed"
    fi

    # Write result as JSON
    if command -v jq >/dev/null 2>&1; then
        jq -n \
            --arg ts "$TIMESTAMP" \
            --arg file "$CHANGED_FILE" \
            --arg cmd "$EXEC_CMD" \
            --arg status "$STATUS" \
            --argjson code "$EXIT_CODE" \
            --arg out "$OUTPUT" \
            '{timestamp:$ts,changed_file:$file,command:$cmd,status:$status,exit_code:$code,output:$out}' \
            > "$RESULT_FILE" 2>/dev/null || true
    else
        # Output minimal JSON when jq is not available
        ESCAPED_OUT=$(printf '%s' "$OUTPUT" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr '\n' ' ')
        cat > "$RESULT_FILE" << EOF
{"timestamp":"$TIMESTAMP","changed_file":"$CHANGED_FILE","command":"$EXEC_CMD","status":"$STATUS","exit_code":$EXIT_CODE,"output":"$ESCAPED_OUT"}
EOF
    fi

    return "$EXIT_CODE"
}

# Main process
main() {
    # Check whether tests need to run
    if ! should_run_tests "$CHANGED_FILE"; then
        exit 0
    fi

    # Detect the test command
    TEST_CMD=$(detect_test_command)
    if [ -z "$TEST_CMD" ]; then
        exit 0
    fi

    # Detect related test files
    RELATED_TEST=$(find_related_tests "$CHANGED_FILE")

    # Record to state file
    STATE_DIR=".claude/state"
    mkdir -p "$STATE_DIR"

    # If HARNESS_AUTO_TEST=run, actually run the tests
    if [ "${HARNESS_AUTO_TEST:-}" = "run" ]; then
        run_tests "$TEST_CMD" "$RELATED_TEST"
        EXIT_CODE=$?

        # Output result summary to stderr (for hooks log)
        RESULT_FILE="${STATE_DIR}/test-result.json"
        if [ -f "$RESULT_FILE" ]; then
            STATUS=$(command -v jq >/dev/null 2>&1 && jq -r '.status // "unknown"' "$RESULT_FILE" 2>/dev/null || grep -o '"status":"[^"]*"' "$RESULT_FILE" | head -1 | sed 's/"status":"\([^"]*\)"/\1/')
            OUTPUT_SNIPPET=$(command -v jq >/dev/null 2>&1 && jq -r '.output // ""' "$RESULT_FILE" 2>/dev/null | head -30 || true)
            echo "[auto-test-runner] run mode: $STATUS (exit=$EXIT_CODE) file=$CHANGED_FILE" >&2

            # Notify Claude of test result via additionalContext
            if [ "$STATUS" = "passed" ]; then
                CONTEXT_MSG="[Auto Test Runner] Tests passed
Command: $TEST_CMD
File: $CHANGED_FILE
Status: PASSED (exit=0)"
            elif [ "$STATUS" = "timeout" ]; then
                CONTEXT_MSG="[Auto Test Runner] Tests timed out (60s)
Command: $TEST_CMD
File: $CHANGED_FILE
Status: TIMEOUT

Output:
${OUTPUT_SNIPPET}"
            else
                CONTEXT_MSG="[Auto Test Runner] Tests failed
Command: $TEST_CMD
File: $CHANGED_FILE
Status: FAILED (exit=$EXIT_CODE)

Output:
${OUTPUT_SNIPPET}

Fix the implementation to make the tests pass."
            fi

            # JSON output (additionalContext)
            if command -v jq >/dev/null 2>&1; then
                jq -nc --arg ctx "$CONTEXT_MSG" \
                    '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$ctx}}'
            else
                ESCAPED_CTX=$(printf '%s' "$CONTEXT_MSG" | sed 's/\\/\\\\/g; s/"/\\"/g; s/$/\\n/' | tr -d '\n' | sed 's/\\n$//')
                printf '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"%s"}}\n' "$ESCAPED_CTX"
            fi
        fi
        exit 0
    fi

    # Default: recommend mode (record test recommendation)
    cat > "${STATE_DIR}/test-recommendation.json" << EOF
{
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "changed_file": "$CHANGED_FILE",
  "test_command": "$TEST_CMD",
  "related_test": "$RELATED_TEST",
  "recommendation": "Running tests is recommended"
}
EOF

    # Output notification
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🧪 Test run recommended"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📁 Changed file: $CHANGED_FILE"
    if [ -n "$RELATED_TEST" ]; then
        echo "🔗 Related test: $RELATED_TEST"
    fi
    echo "📋 Recommended command: $TEST_CMD"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

main
