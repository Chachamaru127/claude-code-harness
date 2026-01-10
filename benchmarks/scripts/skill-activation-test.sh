#!/bin/bash
# スキル発動率テストスクリプト

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BENCHMARK_DIR="$(dirname "$SCRIPT_DIR")"
PLUGIN_ROOT="$(dirname "$BENCHMARK_DIR")"
RESULTS_DIR="$BENCHMARK_DIR/results"
TEST_PROJECT="$BENCHMARK_DIR/test-project"

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
RESULT_FILE="$RESULTS_DIR/skill-activation-${TIMESTAMP}.md"

# 予算設定
BUDGET=3.0

# テストケース定義
declare -a TEST_PROMPTS=(
  "src/api/auth-handler.ts のコードを見てほしい。品質的に問題ないか確認して"
  "CIが落ちた、原因を調べて"
  "新しいバリデーション関数を実装して"
)

declare -a EXPECTED_SKILLS=(
  "review"
  "ci"
  "impl"
)

# バージョン設定
VERSIONS=("latest" "v2.2.2" "no-plugin")

get_plugin_path() {
  local ver="$1"
  case "$ver" in
    latest) echo "$PLUGIN_ROOT" ;;
    v2.2.2) echo "$BENCHMARK_DIR/versions/v2.2.2" ;;
    no-plugin) echo "" ;;
    *) echo "" ;;
  esac
}

check_skill_activation() {
  local output="$1"
  local expected="$2"

  # スキル発動パターンを検索
  if echo "$output" | grep -qiE "(Skill tool|skill:.*${expected}|${expected}.*skill)"; then
    echo "1.0"  # 完全発動
  elif echo "$output" | grep -qiE "(スキル|skill|並列|サブエージェント|Task tool)"; then
    echo "0.5"  # 部分発動
  else
    echo "0.0"  # 非発動
  fi
}

# メイン処理
main() {
  mkdir -p "$RESULTS_DIR"

  echo "# スキル発動率テスト結果" > "$RESULT_FILE"
  echo "" >> "$RESULT_FILE"
  echo "**実行日時**: $TIMESTAMP" >> "$RESULT_FILE"
  echo "" >> "$RESULT_FILE"

  # 結果配列
  declare -A RESULTS

  cd "$TEST_PROJECT"

  for ver in "${VERSIONS[@]}"; do
    echo "=== Testing version: $ver ===" | tee -a "$RESULT_FILE"

    local plugin_path=$(get_plugin_path "$ver")
    local total_score=0

    for i in "${!TEST_PROMPTS[@]}"; do
      local prompt="${TEST_PROMPTS[$i]}"
      local expected="${EXPECTED_SKILLS[$i]}"
      local test_num=$((i + 1))

      echo "  Test $test_num: Expecting '$expected' skill..." | tee -a "$RESULT_FILE"

      # コマンド構築
      local claude_cmd="claude --print --max-budget-usd $BUDGET --dangerously-skip-permissions"
      if [[ -n "$plugin_path" ]]; then
        claude_cmd="$claude_cmd --plugin-dir $plugin_path"
      fi

      # 実行
      local output=""
      local tmp_file="/tmp/skill-test-${ver}-${test_num}.txt"

      if timeout 60 $claude_cmd "$prompt" > "$tmp_file" 2>&1; then
        output=$(cat "$tmp_file")
      else
        output="TIMEOUT or ERROR"
      fi

      # スキル発動チェック
      local score=$(check_skill_activation "$output" "$expected")
      total_score=$(python3 -c "print($total_score + $score)")

      echo "    Score: $score" | tee -a "$RESULT_FILE"
      RESULTS["${ver}_${test_num}"]="$score"
    done

    local rate=$(python3 -c "print(round($total_score / ${#TEST_PROMPTS[@]} * 100, 1))")
    RESULTS["${ver}_rate"]="$rate"
    echo "  発動率: ${rate}%" | tee -a "$RESULT_FILE"
    echo "" | tee -a "$RESULT_FILE"
  done

  # サマリー
  echo "## サマリー" >> "$RESULT_FILE"
  echo "" >> "$RESULT_FILE"
  echo "| バージョン | 発動率 |" >> "$RESULT_FILE"
  echo "|-----------|--------|" >> "$RESULT_FILE"
  for ver in "${VERSIONS[@]}"; do
    echo "| $ver | ${RESULTS[${ver}_rate]:-N/A}% |" >> "$RESULT_FILE"
  done

  echo "" | tee -a "$RESULT_FILE"
  echo "結果保存: $RESULT_FILE" | tee -a "$RESULT_FILE"
}

main "$@"
