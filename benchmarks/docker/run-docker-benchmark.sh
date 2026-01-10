#!/bin/bash
# ======================================
# Docker ベースの分離ベンチマーク実行
# ======================================
#
# 完全に分離された Docker 環境で Claude Code を実行
# CI/CD 環境や、より厳密な分離が必要な場合に使用

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BENCHMARK_DIR="$(dirname "$SCRIPT_DIR")"
PLUGIN_ROOT="$(dirname "$BENCHMARK_DIR")"
TASKS_DIR="$BENCHMARK_DIR/tasks"
RESULTS_DIR="$BENCHMARK_DIR/results"

IMAGE_NAME="claude-benchmark"

# ヘルプ表示
show_help() {
  cat << EOF
Docker ベース分離ベンチマーク

Usage: $0 [OPTIONS]

OPTIONS:
  --task <name>       実行するタスク名（必須）
  --with-plugin       プラグインを有効化
  --build             Docker イメージをビルド
  --help              このヘルプを表示

EXAMPLES:
  # イメージをビルド
  $0 --build

  # プラグインなしで実行
  $0 --task parallel-review

  # プラグインありで実行
  $0 --task parallel-review --with-plugin
EOF
}

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

# Docker イメージのビルド
build_image() {
  echo "Docker イメージをビルド中..."
  docker build -t "$IMAGE_NAME" -f "$SCRIPT_DIR/Dockerfile" "$PLUGIN_ROOT"
  echo "✓ イメージ '$IMAGE_NAME' をビルドしました"
}

# メイン処理
TASK=""
WITH_PLUGIN=false
BUILD_ONLY=false

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
    --build)
      BUILD_ONLY=true
      shift
      ;;
    --help)
      show_help
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# ビルドのみ
if [[ "$BUILD_ONLY" == "true" ]]; then
  build_image
  exit 0
fi

# バリデーション
if [[ -z "$TASK" ]]; then
  echo "Error: --task を指定してください"
  show_help
  exit 1
fi

# イメージの存在確認
if ! docker image inspect "$IMAGE_NAME" > /dev/null 2>&1; then
  echo "イメージが見つかりません。ビルドします..."
  build_image
fi

# 認証情報の確認
if [[ -z "$ANTHROPIC_API_KEY" ]]; then
  echo "Error: ANTHROPIC_API_KEY 環境変数が設定されていません"
  echo "  export ANTHROPIC_API_KEY=your_api_key"
  exit 1
fi
echo "✓ ANTHROPIC_API_KEY が設定されています"

# テストプロジェクトをセットアップ
"$BENCHMARK_DIR/scripts/setup-test-project.sh" > /dev/null 2>&1

# プロンプト取得
PROMPT=$(get_task_prompt "$TASK")

# タイムスタンプとファイル名
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
if [[ "$WITH_PLUGIN" == "true" ]]; then
  VERSION_LABEL="docker-with-plugin"
else
  VERSION_LABEL="docker-no-plugin"
fi
RESULT_PREFIX="$RESULTS_DIR/${TASK}_${VERSION_LABEL}_1_${TIMESTAMP}"
OUTPUT_FILE="${RESULT_PREFIX}.output.txt"
TRACE_FILE="${RESULT_PREFIX}.trace.jsonl"
RESULT_FILE="${RESULT_PREFIX}.json"

mkdir -p "$RESULTS_DIR"

echo "========================================"
echo "Docker 分離ベンチマーク"
echo "========================================"
echo "Task: $TASK"
echo "Mode: $VERSION_LABEL"
echo "========================================"

# Docker 実行引数の構築
DOCKER_ARGS=(
  --rm
  -e "ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY"
  -v "$BENCHMARK_DIR/test-project:/workspace"
)

CLAUDE_ARGS=(
  --print
  --dangerously-skip-permissions
  --output-format stream-json
  --verbose
)

if [[ "$WITH_PLUGIN" == "true" ]]; then
  DOCKER_ARGS+=(-v "$PLUGIN_ROOT:/plugin:ro")
  CLAUDE_ARGS+=(--plugin-dir /plugin)
  echo "プラグイン: 有効（/plugin にマウント）"
else
  echo "プラグイン: 無効（完全分離）"
fi

echo ""
echo "実行中..."

START_TIME=$(date +%s.%N)

# Docker で実行
docker run "${DOCKER_ARGS[@]}" "$IMAGE_NAME" "${CLAUDE_ARGS[@]}" "$PROMPT" > "$OUTPUT_FILE" 2>&1 || true

END_TIME=$(date +%s.%N)
DURATION=$(echo "$END_TIME - $START_TIME" | bc)

# trace ファイルをコピー
cp -f "$OUTPUT_FILE" "$TRACE_FILE" 2>/dev/null || true

# メトリクス計算
TOOL_USE_COUNT=$(grep -c '"type":"tool_use"' "$TRACE_FILE" 2>/dev/null || echo "0")
TASK_TOOL_USE_COUNT=$(grep -c '"name":"Task"' "$TRACE_FILE" 2>/dev/null || echo "0")
SUBAGENT_TYPE_COUNT=$(grep -c '"subagent_type"' "$TRACE_FILE" 2>/dev/null || echo "0")
PLUGIN_DETECTED=$(grep -c 'claude-harness:' "$TRACE_FILE" 2>/dev/null || echo "0")

# 結果を JSON で保存
OUTPUT_LENGTH=$(wc -c < "$OUTPUT_FILE" 2>/dev/null || echo "0")

cat > "$RESULT_FILE" << EOF
{
  "task": "$TASK",
  "version": "$VERSION_LABEL",
  "iteration": 1,
  "timestamp": "$TIMESTAMP",
  "duration_seconds": $DURATION,
  "environment": "docker",
  "with_plugin": $WITH_PLUGIN,
  "output_length": $OUTPUT_LENGTH,
  "tool_use_count": $TOOL_USE_COUNT,
  "task_tool_use_count": $TASK_TOOL_USE_COUNT,
  "subagent_type_count": $SUBAGENT_TYPE_COUNT,
  "plugin_agent_detected": $PLUGIN_DETECTED,
  "output_file": "$(basename "$OUTPUT_FILE")",
  "trace_file": "$(basename "$TRACE_FILE")"
}
EOF

echo ""
echo "========================================"
echo "結果"
echo "========================================"
echo "✓ 結果ファイル: $RESULT_FILE"
echo ""
echo "メトリクス:"
echo "  - tool_use_count: $TOOL_USE_COUNT"
echo "  - task_tool_use_count: $TASK_TOOL_USE_COUNT"
echo "  - subagent_type_count: $SUBAGENT_TYPE_COUNT"
echo "  - plugin_agent_detected: $PLUGIN_DETECTED"

if [[ "$WITH_PLUGIN" == "false" && "$PLUGIN_DETECTED" -gt 0 ]]; then
  echo ""
  echo "⚠ 警告: プラグインなしモードでプラグインエージェントが検出されました"
elif [[ "$WITH_PLUGIN" == "false" && "$PLUGIN_DETECTED" -eq 0 ]]; then
  echo ""
  echo "✓ 検証成功: プラグインエージェントは検出されませんでした（分離成功）"
fi

echo ""
echo "所要時間: ${DURATION}秒"
echo "========================================"
