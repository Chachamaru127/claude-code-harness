#!/bin/bash
# run.sh
# Breezing v2 benchmark runner script
#
# Usage: ./run.sh --task <1-10|all> --iterations <N> --mode <vanilla|breezing|both>

set -euo pipefail

# macOS compatible: portable wrapper for the timeout command
if command -v timeout &>/dev/null; then
  TIMEOUT_CMD="timeout"
elif command -v gtimeout &>/dev/null; then
  TIMEOUT_CMD="gtimeout"
else
  # macOS fallback: implemented via background + kill
  portable_timeout() {
    local duration="$1"
    shift
    "$@" &
    local pid=$!
    ( sleep "$duration" && kill "$pid" 2>/dev/null ) &
    local watcher=$!
    wait "$pid" 2>/dev/null
    local exit_code=$?
    kill "$watcher" 2>/dev/null
    wait "$watcher" 2>/dev/null || true
    return $exit_code
  }
  TIMEOUT_CMD="portable_timeout"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RESULTS_DIR="$SCRIPT_DIR/results"
TASKS_DIR="$SCRIPT_DIR/tasks"

# Default values
TASK_NUM="all"
ITERATIONS=2
MODE="both"
MODEL="haiku"
MAX_TURNS=30
SEED=42
DRY_RUN=false

show_help() {
  cat <<EOF
Breezing v2 Benchmark Runner

Usage: $0 [OPTIONS]

OPTIONS:
  --task <1-10|all>       Task number or "all" (default: all)
  --iterations <N>        Repetitions per task (default: 2)
  --mode <mode>           vanilla, breezing, or both (default: both)
  --model <model>         Model to use (default: haiku)
  --max-turns <N>         Max turns for Lead (default: 30)
  --seed <N>              Random seed (default: 42)
  --results-dir <path>    Results directory (default: ./results)
  --dry-run               Show execution plan without running
  --help                  Show this help

EXAMPLES:
  # Smoke test: Task 1, 1 iteration, both modes
  $0 --task 1 --iterations 1 --mode both

  # Full benchmark: all tasks, 2 iterations
  $0 --task all --iterations 2 --mode both

  # Dry run to see execution plan
  $0 --task all --iterations 2 --dry-run
EOF
}

# Argument parsing
while [[ $# -gt 0 ]]; do
  case "$1" in
    --task) TASK_NUM="$2"; shift 2 ;;
    --iterations) ITERATIONS="$2"; shift 2 ;;
    --mode) MODE="$2"; shift 2 ;;
    --model) MODEL="$2"; shift 2 ;;
    --max-turns) MAX_TURNS="$2"; shift 2 ;;
    --seed) SEED="$2"; shift 2 ;;
    --results-dir) RESULTS_DIR="$2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    --help) show_help; exit 0 ;;
    *) echo "Unknown option: $1"; show_help; exit 1 ;;
  esac
done

# Build task list
if [[ "$TASK_NUM" == "all" ]]; then
  TASKS=(01 02 03 04 05 06 07 08 09 10)
else
  TASKS=($(printf "%02d" "$TASK_NUM"))
fi

# Function to randomize execution order
generate_execution_order() {
  local seed="$1"
  local -a order=()

  for task in "${TASKS[@]}"; do
    for iter in $(seq 1 "$ITERATIONS"); do
      if [[ "$MODE" == "both" ]]; then
        # Determine order based on seed
        local hash_input="${seed}_${task}_${iter}"
        local hash_val
        hash_val=$(echo -n "$hash_input" | md5sum | cut -c1-8)
        local hash_num=$((16#$hash_val % 2))

        if [[ $hash_num -eq 0 ]]; then
          order+=("${task}:${iter}:vanilla" "${task}:${iter}:breezing")
        else
          order+=("${task}:${iter}:breezing" "${task}:${iter}:vanilla")
        fi
      else
        order+=("${task}:${iter}:${MODE}")
      fi
    done
  done

  printf '%s\n' "${order[@]}"
}

# Generate execution order
mapfile -t EXEC_ORDER < <(generate_execution_order "$SEED")

# Dry run
if [[ "$DRY_RUN" == true ]]; then
  echo "=== Breezing Benchmark Execution Plan ==="
  echo "Tasks: ${TASKS[*]}"
  echo "Iterations: $ITERATIONS"
  echo "Mode: $MODE"
  echo "Model: $MODEL"
  echo "Max turns: $MAX_TURNS"
  echo "Seed: $SEED"
  echo "Total executions: ${#EXEC_ORDER[@]}"
  echo ""
  echo "Execution order:"
  for i in "${!EXEC_ORDER[@]}"; do
    IFS=':' read -r task iter condition <<< "${EXEC_ORDER[$i]}"
    echo "  $((i+1)). Task $task, Iter $iter, $condition"
  done
  exit 0
fi

# Create results directory
mkdir -p "$RESULTS_DIR"

# Function to load task prompt
get_task_prompt() {
  local task_num="$1"
  local task_dir="$TASKS_DIR/task-${task_num}"
  local yaml_file="$task_dir/task.yaml"

  if [[ ! -f "$yaml_file" ]]; then
    echo "Error: $yaml_file not found" >&2
    return 1
  fi

  # Extract prompt from YAML (simple parse)
  grep '^prompt:' "$yaml_file" | sed 's/^prompt: *//' | sed 's/^"//' | sed 's/"$//'
}

# Function to copy setup files
setup_work_dir() {
  local task_num="$1"
  local work_dir="$2"
  local task_dir="$TASKS_DIR/task-${task_num}"

  mkdir -p "$work_dir"

  # Copy contents of setup/
  if [[ -d "$task_dir/setup" ]]; then
    cp -r "$task_dir/setup/"* "$work_dir/"
  fi
}

# Single run
run_single() {
  local task_num="$1"
  local iter="$2"
  local condition="$3"
  local timestamp
  timestamp=$(date +%Y%m%d-%H%M%S)

  local result_id="task-${task_num}_${condition}_iter-${iter}_${timestamp}"
  local work_dir
  work_dir=$(mktemp -d "/tmp/breezing-bench-${result_id}.XXXXXX")
  local result_dir="$RESULTS_DIR/$result_id"

  echo ""
  echo "=== Running: Task $task_num | Iter $iter | $condition ==="
  echo "  Work dir: $work_dir"

  # Setup
  setup_work_dir "$task_num" "$work_dir"

  # Task prompt
  local task_prompt
  task_prompt=$(get_task_prompt "$task_num")

  # Start time
  local start_time
  start_time=$(date +%s)

  # Run with Claude CLI
  local exit_code=0
  if [[ "$condition" == "vanilla" ]]; then
    run_vanilla "$work_dir" "$task_prompt" "$result_id" || exit_code=$?
  else
    run_breezing "$work_dir" "$task_prompt" "$result_id" || exit_code=$?
  fi

  # End time
  local end_time
  end_time=$(date +%s)
  local duration=$((end_time - start_time))

  echo "  Duration: ${duration}s"

  # Grading
  echo "  Grading..."
  local grade_output
  grade_output=$(python3 "$SCRIPT_DIR/grader.py" \
    --project-dir "$work_dir" \
    --task-dir "$TASKS_DIR/task-${task_num}" \
    --json 2>/dev/null || echo '{"primary":{"score":0.0,"passed":0,"total":0,"error":"grader failed"}}')

  # Save results
  mkdir -p "$result_dir"
  cp -r "$work_dir" "$result_dir/project" 2>/dev/null || true

  cat > "$result_dir/result.json" <<ENDJSON
{
  "task_id": "task-${task_num}",
  "iteration": ${iter},
  "condition": "${condition}",
  "timestamp": "${timestamp}",
  "execution": {
    "duration_seconds": ${duration},
    "exit_code": ${exit_code},
    "success": $([ $exit_code -eq 0 ] && echo true || echo false),
    "model": "${MODEL}",
    "max_turns": ${MAX_TURNS}
  },
  "grading": ${grade_output},
  "work_dir": "${work_dir}"
}
ENDJSON

  local score
  score=$(echo "$grade_output" | python3 -c "import sys,json; print(json.load(sys.stdin).get('primary',{}).get('score',0))" 2>/dev/null || echo "0")
  echo "  Score: $score"
  echo "  Result: $result_dir/result.json"

  # Clean up work directory
  rm -rf "$work_dir"
}

# Vanilla run
run_vanilla() {
  local work_dir="$1"
  local task_prompt="$2"
  local result_id="$3"

  local prompt="You are a developer. Complete this task:

${task_prompt}

Write clean TypeScript code with proper error handling.
Create tests for your implementation.
Make sure all existing tests still pass."

  # Run with Claude CLI (non-interactive, skip all permissions, no session persistence)
  ( cd "$work_dir" && \
    $TIMEOUT_CMD $((MAX_TURNS * 30)) claude \
      --model "$MODEL" \
      --max-budget-usd 0.50 \
      --output-format text \
      --dangerously-skip-permissions \
      --no-session-persistence \
      -p "$prompt" \
      --allowedTools "Read,Write,Edit,Bash,Glob,Grep" \
  ) 2>"$RESULTS_DIR/${result_id}.stderr" \
    >"$RESULTS_DIR/${result_id}.stdout" || true
}

# Breezing run
run_breezing() {
  local work_dir="$1"
  local task_prompt="$2"
  local result_id="$3"

  local prompt="You are a Breezing team lead. Create a team with an Implementer and a Reviewer.

## Task
${task_prompt}

## Instructions
1. Create a team with TeamCreate
2. Create implementation tasks with TaskCreate
3. Spawn an Implementer (subagent_type=general-purpose) with this prompt:
   \"You are an Implementer. Complete: ${task_prompt}
   - Write clean TypeScript with proper error handling
   - Handle edge cases (null, empty, boundary)
   - Create comprehensive tests
   - Do NOT weaken existing tests
   Report completion via SendMessage.\"
4. Wait for Implementer to complete
5. Spawn a Reviewer (subagent_type=general-purpose) with this prompt:
   \"You are a Reviewer. Review the code for: ${task_prompt}
   Check: correctness, edge cases, type safety, error handling, security, test quality.
   Report findings (CRITICAL/WARNING/SUGGESTION) via SendMessage.
   Do NOT modify code.\"
6. If Reviewer finds CRITICAL issues, message Implementer to fix them
7. After review cycle, clean up the team"

  # Increase budget for Breezing because it uses Teams
  ( cd "$work_dir" && \
    $TIMEOUT_CMD $((MAX_TURNS * 60)) claude \
      --model "$MODEL" \
      --max-budget-usd 1.50 \
      --output-format text \
      --dangerously-skip-permissions \
      --no-session-persistence \
      -p "$prompt" \
      --allowedTools "Read,Write,Edit,Bash,Glob,Grep,Task,TeamCreate,TeamDelete,TaskCreate,TaskUpdate,TaskList,TaskGet,SendMessage" \
  ) 2>"$RESULTS_DIR/${result_id}.stderr" \
    >"$RESULTS_DIR/${result_id}.stdout" || true
}

# Main execution loop
echo "=== Breezing v2 Benchmark ==="
echo "Tasks: ${TASKS[*]}"
echo "Iterations: $ITERATIONS"
echo "Mode: $MODE"
echo "Total executions: ${#EXEC_ORDER[@]}"
echo "Results: $RESULTS_DIR"
echo ""

TOTAL=${#EXEC_ORDER[@]}
CURRENT=0

for entry in "${EXEC_ORDER[@]}"; do
  CURRENT=$((CURRENT + 1))
  IFS=':' read -r task iter condition <<< "$entry"
  echo "[$CURRENT/$TOTAL] Task $task, Iter $iter, $condition"
  run_single "$task" "$iter" "$condition"
done

echo ""
echo "=== Benchmark Complete ==="
echo "Total executions: $TOTAL"
echo "Results: $RESULTS_DIR"
echo ""
echo "Run analysis:"
echo "  python3 $SCRIPT_DIR/analyzer.py --results-dir $RESULTS_DIR"
