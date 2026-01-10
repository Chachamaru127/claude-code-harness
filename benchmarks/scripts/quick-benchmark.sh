#!/bin/bash
# ======================================
# クイックベンチマーク実行スクリプト
# 実際のClaude実行で比較測定
# ======================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BENCHMARK_DIR="$(dirname "$SCRIPT_DIR")"
PLUGIN_ROOT="$(dirname "$BENCHMARK_DIR")"
RESULTS_DIR="$BENCHMARK_DIR/results"
TEST_PROJECT="$BENCHMARK_DIR/test-project"

# 予算設定（USD）
BUDGET=10.0

# 結果ディレクトリを作成
mkdir -p "$RESULTS_DIR"

# タイムスタンプ
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# ログファイル
LOG_FILE="$RESULTS_DIR/benchmark_${TIMESTAMP}.log"

log() {
  echo "$1" | tee -a "$LOG_FILE"
}

# バージョン別のプラグインパスを取得
get_plugin_path() {
  local ver="$1"
  case "$ver" in
    latest)
      echo "$PLUGIN_ROOT"
      ;;
    no-plugin)
      echo ""
      ;;
    v2.4.0|v2.3.1|v2.0.0)
      local ver_dir="$BENCHMARK_DIR/versions/$ver"
      if [[ -d "$ver_dir" ]]; then
        echo "$ver_dir"
      else
        echo ""
      fi
      ;;
    *)
      echo ""
      ;;
  esac
}

# 単一ベンチマーク実行
run_single_benchmark() {
  local version="$1"
  local task_name="$2"
  local prompt="$3"

  local plugin_path=$(get_plugin_path "$version")
  local result_file="$RESULTS_DIR/${task_name}_${version}_${TIMESTAMP}.json"

  log "----------------------------------------"
  log "Version: $version"
  log "Task: $task_name"
  log "----------------------------------------"

  # claude コマンドの構築
  local claude_cmd="claude --print --max-budget-usd $BUDGET --dangerously-skip-permissions"
  if [[ -n "$plugin_path" ]]; then
    claude_cmd="$claude_cmd --plugin-dir $plugin_path"
  fi

  cd "$TEST_PROJECT"

  # 開始時刻（ナノ秒精度）
  local start_time=$(python3 -c "import time; print(time.time())")

  # 実行
  local output=""
  local exit_code=0

  log "Executing: $claude_cmd \"$prompt\""

  if output=$($claude_cmd "$prompt" 2>&1); then
    exit_code=0
  else
    exit_code=$?
  fi

  # 終了時刻
  local end_time=$(python3 -c "import time; print(time.time())")
  local duration=$(python3 -c "print(round($end_time - $start_time, 3))")

  # 出力の長さ
  local output_length=${#output}

  # 結果をJSON保存
  cat > "$result_file" << EOF
{
  "task": "$task_name",
  "version": "$version",
  "timestamp": "$TIMESTAMP",
  "duration_seconds": $duration,
  "exit_code": $exit_code,
  "success": $([ $exit_code -eq 0 ] && echo "true" || echo "false"),
  "output_length": $output_length,
  "plugin_path": "$plugin_path"
}
EOF

  log "✓ Duration: ${duration}s"
  log "✓ Output length: $output_length chars"
  log "✓ Saved: $result_file"
  log ""

  # 出力の一部を表示（最初の500文字）
  if [[ $output_length -gt 0 ]]; then
    log "--- Output preview (first 500 chars) ---"
    echo "${output:0:500}" >> "$LOG_FILE"
    log "..."
  fi

  cd - > /dev/null

  echo "$duration"
}

# メイン処理
main() {
  log "========================================"
  log "Claude harness クイックベンチマーク"
  log "Timestamp: $TIMESTAMP"
  log "Budget: $BUDGET USD"
  log "========================================"
  log ""

  # テスト対象バージョン
  VERSIONS=("latest" "no-plugin" "v2.4.0")

  # テスト1: シンプルな計画タスク
  log "========== TEST 1: 計画タスク =========="
  PLAN_PROMPT="このプロジェクトを分析して、認証機能のセキュリティ改善計画を3点に絞って提案してください。Plans.mdに記載してください。"

  declare -A PLAN_RESULTS
  for ver in "${VERSIONS[@]}"; do
    duration=$(run_single_benchmark "$ver" "plan-task" "$PLAN_PROMPT")
    PLAN_RESULTS[$ver]=$duration
  done

  # テスト2: レビュータスク（並列効果測定）
  log "========== TEST 2: レビュータスク =========="
  REVIEW_PROMPT="src/api/auth-handler.ts をセキュリティ・品質・パフォーマンスの3観点で並列にレビューしてください。問題点と修正案を報告してください。"

  declare -A REVIEW_RESULTS
  for ver in "${VERSIONS[@]}"; do
    duration=$(run_single_benchmark "$ver" "review-task" "$REVIEW_PROMPT")
    REVIEW_RESULTS[$ver]=$duration
  done

  # テスト3: 実装タスク
  log "========== TEST 3: 実装タスク =========="
  IMPL_PROMPT="src/utils/validators.ts に入力バリデーション関数（email, password, username）を実装してください。テストも含めてください。"

  declare -A IMPL_RESULTS
  for ver in "${VERSIONS[@]}"; do
    duration=$(run_single_benchmark "$ver" "impl-task" "$IMPL_PROMPT")
    IMPL_RESULTS[$ver]=$duration
  done

  # 結果サマリー
  log "========================================"
  log "ベンチマーク結果サマリー"
  log "========================================"
  log ""
  log "| Task | latest | no-plugin | v2.4.0 |"
  log "|------|--------|-----------|--------|"
  log "| Plan | ${PLAN_RESULTS[latest]:-N/A}s | ${PLAN_RESULTS[no-plugin]:-N/A}s | ${PLAN_RESULTS[v2.4.0]:-N/A}s |"
  log "| Review | ${REVIEW_RESULTS[latest]:-N/A}s | ${REVIEW_RESULTS[no-plugin]:-N/A}s | ${REVIEW_RESULTS[v2.4.0]:-N/A}s |"
  log "| Impl | ${IMPL_RESULTS[latest]:-N/A}s | ${IMPL_RESULTS[no-plugin]:-N/A}s | ${IMPL_RESULTS[v2.4.0]:-N/A}s |"
  log ""
  log "詳細結果: $RESULTS_DIR/"
  log "ログファイル: $LOG_FILE"
}

main
