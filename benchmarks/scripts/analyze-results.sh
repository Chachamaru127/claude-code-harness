#!/bin/bash
# ======================================
# ベンチマーク結果分析スクリプト
# ======================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BENCHMARK_DIR="$(dirname "$SCRIPT_DIR")"
RESULTS_DIR="$BENCHMARK_DIR/results"

# レポート出力先
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
REPORT_FILE="$RESULTS_DIR/report-$TIMESTAMP.md"

# jq がインストールされているか確認
if ! command -v jq &> /dev/null; then
  echo "Error: jq がインストールされていません"
  echo "  macOS: brew install jq"
  echo "  Ubuntu: sudo apt-get install jq"
  exit 1
fi

echo "========================================"
echo "Claude harness ベンチマーク結果分析"
echo "========================================"
echo ""

# 結果ファイルがあるか確認
result_count=$(find "$RESULTS_DIR" -name "*.json" 2>/dev/null | wc -l | tr -d ' ')
if [[ "$result_count" -eq 0 ]]; then
  echo "Error: 結果ファイルが見つかりません: $RESULTS_DIR"
  echo "先にベンチマークを実行してください: ./scripts/run-benchmark.sh"
  exit 1
fi

echo "分析対象: $result_count 件の結果ファイル"
echo ""

# レポートヘッダー
cat > "$REPORT_FILE" << EOF
# Claude harness ベンチマークレポート

生成日時: $(date '+%Y-%m-%d %H:%M:%S')

## 概要

| メトリクス | 値 |
|-----------|-----|
| 総実行数 | $result_count |
| 分析期間 | $(find "$RESULTS_DIR" -name "*.json" -exec jq -r '.timestamp' {} \; | sort | head -1) - $(find "$RESULTS_DIR" -name "*.json" -exec jq -r '.timestamp' {} \; | sort | tail -1) |

---

## バージョン別サマリー

EOF

# バージョンごとの統計を計算
echo "バージョン別統計を計算中..."

for version in latest no-plugin v2.4.0 v2.3.1 v2.0.0; do
  version_files=$(find "$RESULTS_DIR" -name "*_${version}_*.json" 2>/dev/null)

  if [[ -z "$version_files" ]]; then
    continue
  fi

  # 統計計算
  count=$(echo "$version_files" | wc -l | tr -d ' ')
  success_count=$(echo "$version_files" | xargs -I{} jq -r '.success' {} 2>/dev/null | grep -c "true" || true)

  # 観測メトリクス（trace 有効時のみ）
  trace_count=$(echo "$version_files" | xargs -I{} jq -r '.trace_enabled // false' {} 2>/dev/null | grep -c "true" || true)
  avg_tool_use="N/A"
  avg_task_tool_use="N/A"
  avg_subagent_type="N/A"

  if [[ "$trace_count" -gt 0 ]]; then
    avg_tool_use=$(echo "$version_files" | xargs -I{} jq -r 'select(.trace_enabled == true) | (.tool_use_count // 0)' {} 2>/dev/null | awk '{sum+=$1} END {if(NR>0) printf "%.2f", sum/NR; else print "N/A"}')
    avg_task_tool_use=$(echo "$version_files" | xargs -I{} jq -r 'select(.trace_enabled == true) | (.task_tool_use_count // 0)' {} 2>/dev/null | awk '{sum+=$1} END {if(NR>0) printf "%.2f", sum/NR; else print "N/A"}')
    avg_subagent_type=$(echo "$version_files" | xargs -I{} jq -r 'select(.trace_enabled == true) | (.subagent_type_count // 0)' {} 2>/dev/null | awk '{sum+=$1} END {if(NR>0) printf "%.2f", sum/NR; else print "N/A"}')
  fi

  # grader（outcome/transcript）統計
  grade_count=$(echo "$version_files" | xargs -I{} jq -r 'select(.grade != null) | "1"' {} 2>/dev/null | wc -l | tr -d ' ')
  grade_pass_count=$(echo "$version_files" | xargs -I{} jq -r 'select(.grade != null) | (.grade.pass // false)' {} 2>/dev/null | grep -c "true" || true)
  avg_grade_score="N/A"
  grade_pass_rate="N/A"
  if [[ "$grade_count" -gt 0 ]]; then
    grade_pass_rate=$(echo "scale=1; $grade_pass_count * 100 / $grade_count" | bc)
    avg_grade_score=$(echo "$version_files" | xargs -I{} jq -r 'select(.grade != null) | (.grade.score // empty)' {} 2>/dev/null | awk 'BEGIN{sum=0;count=0} $1 ~ /^[0-9]/ {sum+=$1;count++} END {if(count>0) printf "%.3f", sum/count; else print "N/A"}')
  fi

  # トークン/コスト統計（推定値）
  total_input_tokens=$(echo "$version_files" | xargs -I{} jq -r '.input_tokens // 0' {} 2>/dev/null | awk '{sum+=$1} END {print sum+0}')
  total_output_tokens=$(echo "$version_files" | xargs -I{} jq -r '.output_tokens // 0' {} 2>/dev/null | awk '{sum+=$1} END {print sum+0}')
  total_estimated_cost=$(echo "$version_files" | xargs -I{} jq -r '.estimated_cost_usd // .total_cost_usd // 0' {} 2>/dev/null | awk '{sum+=$1} END {printf "%.4f", sum}')
  avg_input_tokens="N/A"
  avg_output_tokens="N/A"
  avg_estimated_cost="N/A"
  if [[ "$count" -gt 0 && "$total_input_tokens" -gt 0 ]]; then
    avg_input_tokens=$(echo "scale=0; $total_input_tokens / $count" | bc)
    avg_output_tokens=$(echo "scale=0; $total_output_tokens / $count" | bc)
    avg_estimated_cost=$(echo "scale=4; $total_estimated_cost / $count" | bc)
  fi

  # 所要時間の中央値を計算
  durations=$(echo "$version_files" | xargs -I{} jq -r '.duration_seconds' {} 2>/dev/null | sort -n)
  duration_count=$(echo "$durations" | wc -l | tr -d ' ')

  if [[ "$duration_count" -gt 0 ]]; then
    median_index=$((duration_count / 2 + 1))
    median_duration=$(echo "$durations" | sed -n "${median_index}p")
    min_duration=$(echo "$durations" | head -1)
    max_duration=$(echo "$durations" | tail -1)
    avg_duration=$(echo "$durations" | awk '{sum+=$1} END {printf "%.2f", sum/NR}')
  else
    median_duration="N/A"
    min_duration="N/A"
    max_duration="N/A"
    avg_duration="N/A"
  fi

  success_rate=$(echo "scale=1; $success_count * 100 / $count" | bc)

  cat >> "$REPORT_FILE" << EOF
### $version

| メトリクス | 値 |
|-----------|-----|
| 実行数 | $count |
| 成功率 | ${success_rate}% ($success_count/$count) |
| 平均所要時間 | ${avg_duration}秒 |
| 中央値 | ${median_duration}秒 |
| 最小/最大 | ${min_duration}秒 / ${max_duration}秒 |
| trace 有効 | $trace_count / $count |
| tool_use 平均（traceのみ） | $avg_tool_use |
| Task tool 検出平均（traceのみ） | $avg_task_tool_use |
| subagent_type 検出平均（traceのみ） | $avg_subagent_type |
| grade あり | $grade_count / $count |
| grade pass | ${grade_pass_rate}% ($grade_pass_count/$grade_count) |
| grade score avg | $avg_grade_score |
| 平均 input tokens | $avg_input_tokens |
| 平均 output tokens | $avg_output_tokens |
| 推定コスト平均 (USD) | \$$avg_estimated_cost |
| 推定コスト合計 (USD) | \$$total_estimated_cost |

EOF
done

# タスク別統計
cat >> "$REPORT_FILE" << EOF

---

## タスク別パフォーマンス

EOF

for task in plan-feature impl-utility impl-test impl-refactor review-security review-quality; do
  task_files=$(find "$RESULTS_DIR" -name "${task}_*.json" 2>/dev/null)

  if [[ -z "$task_files" ]]; then
    continue
  fi

  cat >> "$REPORT_FILE" << EOF
### $task

| バージョン | 平均時間(秒) | 成功率 |
|-----------|-------------|--------|
EOF

  for version in latest no-plugin v2.4.0 v2.3.1 v2.0.0; do
    version_task_files=$(find "$RESULTS_DIR" -name "${task}_${version}_*.json" 2>/dev/null)

    if [[ -z "$version_task_files" ]]; then
      continue
    fi

    count=$(echo "$version_task_files" | wc -l | tr -d ' ')
    success_count=$(echo "$version_task_files" | xargs -I{} jq -r '.success' {} 2>/dev/null | grep -c "true" || echo "0")
    avg_duration=$(echo "$version_task_files" | xargs -I{} jq -r '.duration_seconds' {} 2>/dev/null | awk '{sum+=$1} END {printf "%.2f", sum/NR}')
    success_rate=$(echo "scale=1; $success_count * 100 / $count" | bc)

    echo "| $version | $avg_duration | ${success_rate}% |" >> "$REPORT_FILE"
  done

  echo "" >> "$REPORT_FILE"
done

# 比較分析
cat >> "$REPORT_FILE" << EOF

---

## バージョン間比較

### latest vs no-plugin

EOF

# latest と no-plugin の比較
latest_avg=$(find "$RESULTS_DIR" -name "*_latest_*.json" -exec jq -r '.duration_seconds' {} \; 2>/dev/null | awk '{sum+=$1; count++} END {if(count>0) printf "%.2f", sum/count; else print "N/A"}')
noplugin_avg=$(find "$RESULTS_DIR" -name "*_no-plugin_*.json" -exec jq -r '.duration_seconds' {} \; 2>/dev/null | awk '{sum+=$1; count++} END {if(count>0) printf "%.2f", sum/count; else print "N/A"}')

if [[ "$latest_avg" != "N/A" && "$noplugin_avg" != "N/A" ]]; then
  improvement=$(echo "scale=1; ($noplugin_avg - $latest_avg) * 100 / $noplugin_avg" | bc 2>/dev/null || echo "N/A")

  cat >> "$REPORT_FILE" << EOF
| メトリクス | latest | no-plugin | 改善率 |
|-----------|--------|-----------|--------|
| 平均所要時間 | ${latest_avg}秒 | ${noplugin_avg}秒 | ${improvement}% |

EOF

  if [[ "$improvement" != "N/A" ]]; then
    if (( $(echo "$improvement > 0" | bc -l) )); then
      echo "**結論**: プラグインにより ${improvement}% の時間短縮を確認" >> "$REPORT_FILE"
    elif (( $(echo "$improvement < 0" | bc -l) )); then
      echo "**結論**: プラグインにより $(echo "$improvement * -1" | bc)% の時間増加（オーバーヘッド）" >> "$REPORT_FILE"
    else
      echo "**結論**: 有意な差なし" >> "$REPORT_FILE"
    fi
  fi
else
  echo "比較データが不足しています。両バージョンでベンチマークを実行してください。" >> "$REPORT_FILE"
fi

# フッター
cat >> "$REPORT_FILE" << EOF

---

## 注意事項

- 所要時間はネットワーク状況により変動します
- API呼び出しのレイテンシは Anthropic サーバーの負荷に依存します
- 複数回実行して中央値を参照することを推奨します

---

*Generated by Claude harness Benchmark Suite*
EOF

echo ""
echo "✓ レポートを生成しました: $REPORT_FILE"
echo ""
cat "$REPORT_FILE"
