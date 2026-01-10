#!/bin/bash
# ======================================
# 分離環境ベンチマーク実行スクリプト
# ======================================
#
# HOME ディレクトリオーバーライドにより、グローバルプラグインを
# 完全に無効化した状態でベンチマークを実行します。
#
# これにより真の「no-plugin」テストが可能になります。

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BENCHMARK_DIR="$(dirname "$SCRIPT_DIR")"
PLUGIN_ROOT="$(dirname "$BENCHMARK_DIR")"
TASKS_DIR="$BENCHMARK_DIR/tasks"
RESULTS_DIR="$BENCHMARK_DIR/results"
TEST_PROJECT="$BENCHMARK_DIR/test-project"

# デフォルト設定
TASK=""
WITH_PLUGIN=false
PLUGIN_PATH=""
ITERATIONS=1
TRACE_MODE=true
API_KEY="${ANTHROPIC_API_KEY:-}"

# ヘルプ表示
show_help() {
  cat << EOF
分離環境ベンチマーク実行（HOME オーバーライド方式）

このスクリプトは一時的な HOME ディレクトリを使用し、
グローバルプラグインを完全に無効化してテストします。

Usage: $0 [OPTIONS]

OPTIONS:
  --task <name>       実行するタスク名（必須）
  --with-plugin       プラグインを有効化してテスト
  --plugin-path <p>   プラグインのパス（デフォルト: このリポジトリ）
  --iterations <n>    実行回数（デフォルト: 1）
  --api-key <key>     ANTHROPIC_API_KEY（環境変数優先）
  --no-trace          trace を無効化
  --help              このヘルプを表示

EXAMPLES:
  # プラグインなし（真の no-plugin）
  $0 --task parallel-review

  # プラグインあり
  $0 --task parallel-review --with-plugin

  # 比較実行（両方）
  $0 --task parallel-review && $0 --task parallel-review --with-plugin

TASKS:
  plan-feature        計画タスク
  impl-utility        実装タスク
  parallel-review     並列レビュー（重量）
  complex-feature     複合機能実装（重量）
EOF
}

# 引数解析
while [[ $# -gt 0 ]]; do
  case "$1" in
    --task)
      TASK="$2"
      shift 2
      ;;
    --with-plugin)
      WITH_PLUGIN=true
      shift
      ;;
    --plugin-path)
      PLUGIN_PATH="$2"
      shift 2
      ;;
    --iterations)
      ITERATIONS="$2"
      shift 2
      ;;
    --api-key)
      API_KEY="$2"
      shift 2
      ;;
    --no-trace)
      TRACE_MODE=false
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
if [[ -z "$TASK" ]]; then
  echo "Error: --task を指定してください"
  show_help
  exit 1
fi

# デフォルトのプラグインパス
if [[ "$WITH_PLUGIN" == "true" && -z "$PLUGIN_PATH" ]]; then
  PLUGIN_PATH="$PLUGIN_ROOT"
fi

# タスクのプロンプトを取得
get_task_prompt() {
  local task="$1"
  local task_file="$TASKS_DIR/$task.md"

  if [[ ! -f "$task_file" ]]; then
    echo "Error: タスクファイルが見つかりません: $task_file" >&2
    exit 1
  fi

  sed -n '/^## プロンプト/,/^## /p' "$task_file" | \
    sed -n '/^```$/,/^```$/p' | \
    sed '1d;$d'
}

# 分離環境でベンチマーク実行
run_isolated_benchmark() {
  local iteration="$1"
  local version_label

  if [[ "$WITH_PLUGIN" == "true" ]]; then
    version_label="isolated-with-plugin"
  else
    version_label="isolated-no-plugin"
  fi

  local timestamp=$(date +%Y%m%d-%H%M%S)
  local result_prefix="$RESULTS_DIR/${TASK}_${version_label}_${iteration}_${timestamp}"
  local result_file="${result_prefix}.json"
  local output_file="${result_prefix}.output.txt"
  local trace_file="${result_prefix}.trace.jsonl"
  local debug_file="${result_prefix}.debug.log"

  echo "========================================"
  echo "分離環境ベンチマーク"
  echo "========================================"
  echo "Task: $TASK"
  echo "Mode: $version_label"
  echo "Iteration: $iteration"
  echo "Trace: $TRACE_MODE"
  echo "========================================"

  # 一時 HOME ディレクトリを作成
  local temp_home=$(mktemp -d)
  mkdir -p "$temp_home/.claude"

  echo "一時 HOME: $temp_home"

  # 認証方法の確認
  # 優先順位: 1. API_KEY引数 2. 環境変数 3. 認証ファイル 4. ログイン
  if [[ -n "$API_KEY" ]]; then
    echo "✓ ANTHROPIC_API_KEY が指定されています"
    export ANTHROPIC_API_KEY="$API_KEY"
  elif [[ -n "$ANTHROPIC_API_KEY" ]]; then
    echo "✓ ANTHROPIC_API_KEY 環境変数が設定されています"
  elif [[ -f "$HOME/.claude/.credentials.json" ]]; then
    # 認証ファイルがある場合はコピー（Claude Max サブスクリプション用）
    cp "$HOME/.claude/.credentials.json" "$temp_home/.claude/"
    echo "✓ 認証情報をコピーしました（Claude Max サブスクリプション）"
  else
    echo "⚠ 認証情報が見つかりません"
    echo "  以下のいずれかの方法で認証してください："
    echo "  1. --api-key オプションで API キーを指定"
    echo "  2. ANTHROPIC_API_KEY 環境変数を設定"
    echo "  3. 別ターミナルで 'claude login' を実行してから再試行"
    rm -rf "$temp_home"
    exit 1
  fi

  # テストプロジェクトをリセット
  "$SCRIPT_DIR/setup-test-project.sh" > /dev/null 2>&1

  cd "$TEST_PROJECT"

  # プロンプト取得
  local prompt=$(get_task_prompt "$TASK")

  # claude コマンドの構築
  local claude_args=(--print --dangerously-skip-permissions)

  if [[ "$WITH_PLUGIN" == "true" && -n "$PLUGIN_PATH" ]]; then
    claude_args+=(--plugin-dir "$PLUGIN_PATH")
    echo "プラグイン: $PLUGIN_PATH"
  else
    echo "プラグイン: なし（完全分離）"
  fi

  if [[ "$TRACE_MODE" == "true" ]]; then
    claude_args+=(--output-format stream-json --include-partial-messages --verbose)
  fi

  echo ""
  echo "実行コマンド: HOME=$temp_home claude ${claude_args[*]}"
  echo "プロンプト: ${prompt:0:100}..."
  echo ""

  # 開始時刻
  local start_time=$(date +%s.%N)

  # macOS 対応: gtimeout または timeout を使用
  local timeout_cmd=""
  if command -v gtimeout &> /dev/null; then
    timeout_cmd="gtimeout 300"
  elif command -v timeout &> /dev/null; then
    timeout_cmd="timeout 300"
  fi

  local exit_code=0

  # 分離環境で実行
  if [[ -n "$timeout_cmd" ]]; then
    if HOME="$temp_home" $timeout_cmd claude "${claude_args[@]}" "$prompt" > "$output_file" 2> "$debug_file"; then
      exit_code=0
    else
      exit_code=$?
    fi
  else
    if HOME="$temp_home" claude "${claude_args[@]}" "$prompt" > "$output_file" 2> "$debug_file"; then
      exit_code=0
    else
      exit_code=$?
    fi
  fi

  # 終了時刻
  local end_time=$(date +%s.%N)
  local duration=$(echo "$end_time - $start_time" | bc)

  # trace ファイルをコピー
  if [[ "$TRACE_MODE" == "true" ]]; then
    cp -f "$output_file" "$trace_file" 2>/dev/null || true
  fi

  # メトリクス計算
  local tool_use_count=0
  local task_tool_use_count=0
  local subagent_type_count=0
  local plugin_detected=0
  local input_tokens=0
  local output_tokens=0
  local estimated_cost="0.0000"
  local cost_assumption="sonnet_3_5_input_3_per_mtok_output_15_per_mtok"

  if [[ "$TRACE_MODE" == "true" && -f "$trace_file" ]]; then
    tool_use_count=$(grep -c '"type":"tool_use"' "$trace_file" 2>/dev/null || echo "0")
    task_tool_use_count=$(grep -c '"name":"Task"' "$trace_file" 2>/dev/null || echo "0")
    subagent_type_count=$(grep -c '"subagent_type"' "$trace_file" 2>/dev/null || echo "0")
    # プラグイン由来のエージェントが呼ばれたかチェック
    plugin_detected=$(grep -c 'claude-harness:' "$trace_file" 2>/dev/null || echo "0")

    # トークン使用量の抽出（stream-json の usage フィールドから）
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

  # 結果を JSON で保存
  local output_length=$(wc -c < "$output_file" 2>/dev/null || echo "0")

  # outcome/transcript の最小 grader（失敗してもベンチ全体は止めない）
  local grade_json="null"
  if [[ -f "$SCRIPT_DIR/grade-task.sh" ]]; then
    grade_json=$(bash "$SCRIPT_DIR/grade-task.sh" \
      --task "$TASK" \
      --project-dir "$TEST_PROJECT" \
      --output-file "$output_file" \
      --trace-file "$trace_file" \
      2>/dev/null || echo "null")
  fi

  cat > "$result_file" << EOF
{
  "task": "$TASK",
  "version": "$version_label",
  "iteration": $iteration,
  "timestamp": "$timestamp",
  "duration_seconds": $duration,
  "exit_code": $exit_code,
  "success": $([ $exit_code -eq 0 ] && echo "true" || echo "false"),
  "output_length": $output_length,
  "isolated_home": "$temp_home",
  "with_plugin": $WITH_PLUGIN,
  "plugin_path": $([ "$WITH_PLUGIN" == "true" ] && echo "\"$PLUGIN_PATH\"" || echo "null"),
  "trace_enabled": $([ "$TRACE_MODE" == "true" ] && echo "true" || echo "false"),
  "tool_use_count": $tool_use_count,
  "task_tool_use_count": $task_tool_use_count,
  "subagent_type_count": $subagent_type_count,
  "plugin_agent_detected": $plugin_detected,
  "input_tokens": $input_tokens,
  "output_tokens": $output_tokens,
  "estimated_cost_usd": $estimated_cost,
  "cost_assumption": "$cost_assumption",
  "grade": $grade_json,
  "output_file": "$(basename "$output_file")",
  "trace_file": $([ "$TRACE_MODE" == "true" ] && echo "\"$(basename "$trace_file")\"" || echo "null"),
  "debug_file": "$(basename "$debug_file")"
}
EOF

  # クリーンアップ
  rm -rf "$temp_home"

  echo ""
  echo "========================================"
  echo "結果"
  echo "========================================"
  echo "✓ 結果ファイル: $result_file"
  echo "  出力ログ: $output_file"
  if [[ "$TRACE_MODE" == "true" ]]; then
    echo "  trace: $trace_file"
    echo ""
    echo "メトリクス:"
    echo "  - tool_use_count: $tool_use_count"
    echo "  - task_tool_use_count: $task_tool_use_count"
    echo "  - subagent_type_count: $subagent_type_count"
    echo "  - plugin_agent_detected: $plugin_detected"

    if [[ "$WITH_PLUGIN" == "false" && "$plugin_detected" -gt 0 ]]; then
      echo ""
      echo "⚠ 警告: プラグインなしモードでプラグインエージェントが検出されました"
      echo "  HOME 分離が機能していない可能性があります"
    elif [[ "$WITH_PLUGIN" == "false" && "$plugin_detected" -eq 0 ]]; then
      echo ""
      echo "✓ 検証成功: プラグインエージェントは検出されませんでした（分離成功）"
    fi
  fi
  echo ""
  echo "所要時間: ${duration}秒"
  echo "========================================"

  cd - > /dev/null
}

# メイン処理
main() {
  mkdir -p "$RESULTS_DIR"

  for ((i=1; i<=ITERATIONS; i++)); do
    run_isolated_benchmark "$i"
  done

  echo ""
  echo "ベンチマーク完了"
  echo "結果ディレクトリ: $RESULTS_DIR/"
}

main
