#!/bin/bash
# ======================================
# ベンチマーク実行スクリプト
# ======================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BENCHMARK_DIR="$(dirname "$SCRIPT_DIR")"
PLUGIN_ROOT="$(dirname "$BENCHMARK_DIR")"
TASKS_DIR="$BENCHMARK_DIR/tasks"
RESULTS_DIR="$BENCHMARK_DIR/results"
TEST_PROJECT="$BENCHMARK_DIR/test-project"

# デフォルト設定
TASK=""
VERSION="latest"
ITERATIONS=3
RUN_ALL=false
RUN_HEAVY=false
COMPARE_MODE=false
TRACE_MODE=false
DEBUG_MODE=false

# ヘルプ表示
show_help() {
  cat << EOF
Claude harness ベンチマーク実行

Usage: $0 [OPTIONS]

OPTIONS:
  --task <name>       実行するタスク名
  --version <ver>     プラグインバージョン
  --iterations <n>    実行回数（デフォルト: 3）
  --all               全タスクを実行
  --heavy             重量タスクのみ実行（並列化効果測定向け）
  --compare           全バージョンを比較
  --trace             stream-json で実行ログを保存（tool_use/Task検出向け）
  --debug             Claude Code の debug ログも保存（ノイズ多め）
  --help              このヘルプを表示

EXAMPLES:
  # 単一タスク実行
  $0 --task plan-feature --version latest

  # 全タスク実行（1バージョン）
  $0 --all --version latest

  # 全バージョン比較
  $0 --all --compare

TASKS (軽量):
  plan-feature      計画タスク（Plans.md作成）
  impl-utility      実装タスク（ユーティリティ関数）
  impl-test         テスト作成タスク

TASKS (重量 - 並列化効果測定向け):
  complex-feature     複数ファイル機能実装（Plan→Work→Review）
  parallel-review     並列レビュー（セキュリティ+品質+パフォーマンス）
  multi-file-refactor 複数ファイルリファクタリング
  skill-routing       スキル評価フローテスト

TASKS (その他):
  impl-refactor     リファクタリングタスク
  review-security   セキュリティレビュー
  review-quality    品質レビュー

VERSIONS:
  latest            最新版（v2.4.1）
  no-plugin         プラグインなし
  v2.4.0            直前バージョン（並列サブエージェント対応）
  v2.3.1            スキル階層構造版
  v2.0.0            初期メジャー版
EOF
}

# 引数解析
while [[ $# -gt 0 ]]; do
  case "$1" in
    --task)
      TASK="$2"
      shift 2
      ;;
    --version)
      VERSION="$2"
      shift 2
      ;;
    --iterations)
      ITERATIONS="$2"
      shift 2
      ;;
    --all)
      RUN_ALL=true
      shift
      ;;
    --heavy)
      RUN_HEAVY=true
      shift
      ;;
    --compare)
      COMPARE_MODE=true
      shift
      ;;
    --trace)
      TRACE_MODE=true
      shift
      ;;
    --debug)
      DEBUG_MODE=true
      shift
      ;;
    --help)
      show_help
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      show_help
      exit 1
      ;;
  esac
done

# バリデーション
if [[ "$RUN_ALL" == "false" && "$RUN_HEAVY" == "false" && -z "$TASK" ]]; then
  echo "Error: --task, --all, または --heavy を指定してください"
  show_help
  exit 1
fi

# タスク一覧
# 軽量タスク
LIGHT_TASKS=("plan-feature" "impl-utility" "impl-test")
# 重量タスク（並列化効果を測定）
HEAVY_TASKS=("complex-feature" "parallel-review" "multi-file-refactor" "skill-routing")
# 全タスク
ALL_TASKS=("${LIGHT_TASKS[@]}" "${HEAVY_TASKS[@]}" "impl-refactor" "review-security" "review-quality")
ALL_VERSIONS=("latest" "no-plugin" "v2.4.0" "v2.3.1" "v2.0.0")

# バージョンに対応するプラグインパスを取得
get_plugin_path() {
  local ver="$1"
  case "$ver" in
    latest)
      echo "$PLUGIN_ROOT"
      ;;
    no-plugin)
      # 注意: --plugin-dir はグローバルプラグインを無効化しない
      # 真の「プラグインなし」テストを行うには ~/.claude/settings.json の
      # enabledPlugins を一時的に無効化する必要がある
      # 現状: グローバルプラグインは依然として読み込まれる（比較に限界あり）
      echo "__NO_PLUGIN__"
      ;;
    v2.4.0|v2.3.1|v2.0.0)
      # バージョン別のプラグインディレクトリ（fetch-versions.sh で取得）
      local ver_dir="$BENCHMARK_DIR/versions/$ver"
      if [[ -d "$ver_dir" ]]; then
        echo "$ver_dir"
      else
        echo ""
        echo "Warning: $ver のプラグインが見つかりません: $ver_dir" >&2
      fi
      ;;
    *)
      echo ""
      ;;
  esac
}

# タスクのプロンプトを取得
get_task_prompt() {
  local task="$1"
  local task_file="$TASKS_DIR/$task.md"

  if [[ ! -f "$task_file" ]]; then
    echo "Error: タスクファイルが見つかりません: $task_file" >&2
    exit 1
  fi

  # プロンプトセクションを抽出（```の間）
  sed -n '/^## プロンプト/,/^## /p' "$task_file" | \
    sed -n '/^```$/,/^```$/p' | \
    sed '1d;$d'
}

# ベンチマーク実行
run_benchmark() {
  local task="$1"
  local version="$2"
  local iteration="$3"

  local timestamp=$(date +%Y%m%d-%H%M%S)
  local result_prefix="$RESULTS_DIR/${task}_${version}_${iteration}_${timestamp}"
  local result_file="${result_prefix}.json"
  local output_file="${result_prefix}.output.txt"
  local trace_file="${result_prefix}.trace.jsonl"
  local debug_file="${result_prefix}.debug.log"

  echo "----------------------------------------"
  echo "Task: $task"
  echo "Version: $version"
  echo "Iteration: $iteration"
  echo "----------------------------------------"

  local plugin_path=$(get_plugin_path "$version")
  local prompt=$(get_task_prompt "$task")

  # テストプロジェクトをリセット
  "$SCRIPT_DIR/setup-test-project.sh" > /dev/null 2>&1

  cd "$TEST_PROJECT"

  # claude コマンドの構築（配列で安全に）
  local claude_cmd=(claude)
  if [[ -n "$plugin_path" && "$plugin_path" != "__NO_PLUGIN__" ]]; then
    claude_cmd+=(--plugin-dir "$plugin_path")
  fi
  # 注意: no-plugin でもグローバルプラグイン（~/.claude/settings.json の enabledPlugins）
  # は読み込まれる。Claude Code の仕様上、--plugin-dir はグローバルを置換しない。

  # 開始時刻
  local start_time=$(date +%s.%N)

  # Claude 実行（非対話モード）
  # 注意: 実際の実行にはAPIキーが必要
  echo "Executing: ${claude_cmd[*]}"
  echo "Prompt: $prompt"

  # 実行結果をキャプチャ（JSON形式で保存）
  local output=""
  local exit_code=0

  # タイムアウト付きで実行（5分）
  # 注意: --dangerously-skip-permissions はベンチマーク用途のみ
  # これにより Task ツール等の全ツールが許可される
  local claude_args=(--print --dangerously-skip-permissions)
  if [[ "$TRACE_MODE" == "true" ]]; then
    claude_args+=(--output-format stream-json --include-partial-messages --verbose)
  fi
  if [[ "$DEBUG_MODE" == "true" ]]; then
    claude_args+=(--debug)
  fi

  # macOS 対応: gtimeout（coreutils）または timeout を試す
  local timeout_cmd=""
  if command -v gtimeout &> /dev/null; then
    timeout_cmd="gtimeout 300"
  elif command -v timeout &> /dev/null; then
    timeout_cmd="timeout 300"
  fi

  if [[ -n "$timeout_cmd" ]]; then
    if $timeout_cmd "${claude_cmd[@]}" "${claude_args[@]}" "$prompt" > "$output_file" 2> "$debug_file"; then
      output=$(cat "$output_file")
      exit_code=0
    else
      exit_code=$?
      output=$(cat "$output_file" 2>/dev/null || echo "Timeout or error")
    fi
  else
    # タイムアウトなしで実行
    if "${claude_cmd[@]}" "${claude_args[@]}" "$prompt" > "$output_file" 2> "$debug_file"; then
      output=$(cat "$output_file")
      exit_code=0
    else
      exit_code=$?
      output=$(cat "$output_file" 2>/dev/null || echo "Error")
    fi
  fi

  if [[ "$TRACE_MODE" == "true" ]]; then
    cp -f "$output_file" "$trace_file" 2>/dev/null || true
  fi

  # 終了時刻
  local end_time=$(date +%s.%N)
  local duration=$(echo "$end_time - $start_time" | bc)

  # 追加メトリクス（trace ありの時のみ）
  local tool_use_count=0
  local task_tool_use_count=0
  local subagent_type_count=0
  local input_tokens=0
  local output_tokens=0
  local estimated_cost="0.0000"
  local cost_assumption="sonnet_3_5_input_3_per_mtok_output_15_per_mtok"

  if [[ "$TRACE_MODE" == "true" ]]; then
    tool_use_count=$(grep -c '"type":"tool_use"' "$trace_file" 2>/dev/null || echo "0")
    task_tool_use_count=$(grep -c '"name":"Task"' "$trace_file" 2>/dev/null || echo "0")
    subagent_type_count=$(grep -c '"subagent_type"' "$trace_file" 2>/dev/null || echo "0")

    # トークン使用量の抽出（stream-json の usage フィールドから）
    # 形式: {"type":"result","usage":{"input_tokens":N,"output_tokens":M}}
    if command -v jq &> /dev/null; then
      input_tokens=$(grep '"type":"result"' "$trace_file" 2>/dev/null | jq -r '.usage.input_tokens // 0' 2>/dev/null | awk '{sum+=$1} END {print sum+0}')
      output_tokens=$(grep '"type":"result"' "$trace_file" 2>/dev/null | jq -r '.usage.output_tokens // 0' 2>/dev/null | awk '{sum+=$1} END {print sum+0}')

      # コスト概算（Claude 3.5 Sonnet 基準: input=$3/MTok, output=$15/MTok）
      # 注意: これは推定値であり、実際のコストとは異なる場合があります
      if [[ "$input_tokens" -gt 0 || "$output_tokens" -gt 0 ]]; then
        estimated_cost=$(echo "scale=4; ($input_tokens * 0.000003) + ($output_tokens * 0.000015)" | bc 2>/dev/null || echo "0.0000")
      fi
    fi
  fi

  # outcome/transcript の最小 grader（失敗してもベンチ全体は止めない）
  local grade_json="null"
  if [[ -f "$SCRIPT_DIR/grade-task.sh" ]]; then
    grade_json=$(bash "$SCRIPT_DIR/grade-task.sh" \
      --task "$task" \
      --project-dir "$TEST_PROJECT" \
      --output-file "$output_file" \
      --trace-file "$trace_file" \
      2>/dev/null || echo "null")
  fi

  # 結果をJSONで保存
  cat > "$result_file" << EOF
{
  "task": "$task",
  "version": "$version",
  "iteration": $iteration,
  "timestamp": "$timestamp",
  "duration_seconds": $duration,
  "exit_code": $exit_code,
  "success": $([ $exit_code -eq 0 ] && echo "true" || echo "false"),
  "output_length": ${#output},
  "plugin_path": "$plugin_path",
  "trace_enabled": $([ "$TRACE_MODE" == "true" ] && echo "true" || echo "false"),
  "debug_enabled": $([ "$DEBUG_MODE" == "true" ] && echo "true" || echo "false"),
  "output_file": "$(basename "$output_file")",
  "trace_file": $([ "$TRACE_MODE" == "true" ] && echo "\"$(basename "$trace_file")\"" || echo "null"),
  "debug_file": "$(basename "$debug_file")",
  "tool_use_count": $tool_use_count,
  "task_tool_use_count": $task_tool_use_count,
  "subagent_type_count": $subagent_type_count,
  "input_tokens": $input_tokens,
  "output_tokens": $output_tokens,
  "estimated_cost_usd": $estimated_cost,
  "cost_assumption": "$cost_assumption",
  "grade": $grade_json
}
EOF

  echo "✓ 結果を保存しました: $result_file"
  echo "  出力ログ: $output_file"
  if [[ "$TRACE_MODE" == "true" ]]; then
    echo "  trace(jsonl): $trace_file"
    echo "    - tool_use_count: $tool_use_count"
    echo "    - task_tool_use_count: $task_tool_use_count"
    echo "    - subagent_type_count: $subagent_type_count"
  fi
  if [[ "$DEBUG_MODE" == "true" ]]; then
    echo "  debug log: $debug_file"
  fi
  echo "  所要時間: ${duration}秒"
  echo ""

  cd - > /dev/null
}

# メイン処理
main() {
  echo "========================================"
  echo "Claude harness ベンチマーク"
  echo "========================================"
  echo ""

  # 結果ディレクトリを作成
  mkdir -p "$RESULTS_DIR"

  local tasks_to_run=()
  local versions_to_run=()

  # タスクリストの決定
  if [[ "$RUN_ALL" == "true" ]]; then
    tasks_to_run=("${ALL_TASKS[@]}")
  elif [[ "$RUN_HEAVY" == "true" ]]; then
    tasks_to_run=("${HEAVY_TASKS[@]}")
  else
    tasks_to_run=("$TASK")
  fi

  # バージョンリストの決定
  if [[ "$COMPARE_MODE" == "true" ]]; then
    versions_to_run=("${ALL_VERSIONS[@]}")
  else
    versions_to_run=("$VERSION")
  fi

  echo "実行タスク: ${tasks_to_run[*]}"
  echo "対象バージョン: ${versions_to_run[*]}"
  echo "実行回数: $ITERATIONS"
  echo ""

  # ベンチマーク実行
  for task in "${tasks_to_run[@]}"; do
    for version in "${versions_to_run[@]}"; do
      for ((i=1; i<=ITERATIONS; i++)); do
        run_benchmark "$task" "$version" "$i"
      done
    done
  done

  echo "========================================"
  echo "ベンチマーク完了"
  echo "========================================"
  echo ""
  echo "結果ファイル: $RESULTS_DIR/"
  echo "分析を実行: ./scripts/analyze-results.sh"
}

main
