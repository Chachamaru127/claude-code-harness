#!/usr/bin/env bash
# ======================================
# Scorecard 生成スクリプト
# ======================================
#
# 目的:
# - benchmarks/results/*.json から scorecard.md/json を生成
# - 成功率/grade平均/時間/推定コスト/比較差分を集計
#
# 出力:
# - benchmarks/results/scorecard-{timestamp}.json
# - benchmarks/results/scorecard-{timestamp}.md
#
# 依存:
# - python3, jq

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BENCHMARK_DIR="$(dirname "$SCRIPT_DIR")"
RESULTS_DIR="$BENCHMARK_DIR/results"
PLUGIN_ROOT="$(dirname "$BENCHMARK_DIR")"

# デフォルト設定
OUTPUT_DIR="$RESULTS_DIR"
FILTER_PATTERN=""
VERBOSE=false

# ヘルプ表示
show_help() {
  cat << EOF
Scorecard 生成スクリプト

Usage: $0 [OPTIONS]

OPTIONS:
  --output-dir <dir>    出力ディレクトリ（デフォルト: benchmarks/results）
  --filter <pattern>    ファイル名パターンでフィルタ（例: "20260111"）
  --verbose             詳細ログを表示
  --help                このヘルプを表示

EXAMPLES:
  # 全結果から scorecard 生成
  $0

  # 特定日付の結果のみ
  $0 --filter "20260111"

  # 詳細ログ付き
  $0 --verbose
EOF
}

# 引数解析
while [[ $# -gt 0 ]]; do
  case "$1" in
    --output-dir)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --filter)
      FILTER_PATTERN="$2"
      shift 2
      ;;
    --verbose)
      VERBOSE=true
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

# 依存チェック
if ! command -v python3 &> /dev/null; then
  echo "Error: python3 がインストールされていません"
  exit 1
fi

if ! command -v jq &> /dev/null; then
  echo "Error: jq がインストールされていません"
  exit 1
fi

# Python スクリプトで scorecard 生成
python3 - "$RESULTS_DIR" "$OUTPUT_DIR" "$FILTER_PATTERN" "$VERBOSE" "$PLUGIN_ROOT" <<'PYTHON'
import argparse
import glob
import json
import os
import subprocess
import sys
from datetime import datetime, timezone
from statistics import median, mean
from typing import List, Dict, Any, Optional


def get_harness_version(plugin_root: str) -> str:
    """VERSION ファイルからバージョンを取得"""
    version_file = os.path.join(plugin_root, "VERSION")
    if os.path.isfile(version_file):
        with open(version_file, "r") as f:
            return f.read().strip()
    return "unknown"


def get_harness_commit(plugin_root: str) -> str:
    """git commit hash を取得"""
    try:
        result = subprocess.run(
            ["git", "rev-parse", "--short", "HEAD"],
            cwd=plugin_root,
            capture_output=True,
            text=True,
            timeout=5
        )
        if result.returncode == 0:
            return result.stdout.strip()
    except Exception:
        pass
    return "unknown"


def get_os_info() -> tuple:
    """OS 情報を取得"""
    try:
        result = subprocess.run(
            ["uname", "-s"],
            capture_output=True,
            text=True,
            timeout=5
        )
        os_name = result.stdout.strip() if result.returncode == 0 else "unknown"

        result = subprocess.run(
            ["uname", "-r"],
            capture_output=True,
            text=True,
            timeout=5
        )
        os_version = result.stdout.strip() if result.returncode == 0 else "unknown"

        return os_name, os_version
    except Exception:
        return "unknown", "unknown"


def load_results(results_dir: str, filter_pattern: str) -> List[Dict[str, Any]]:
    """結果 JSON ファイルを読み込み"""
    results = []
    pattern = os.path.join(results_dir, "*.json")

    for filepath in glob.glob(pattern):
        filename = os.path.basename(filepath)

        # scorecard/report は除外
        if filename.startswith("scorecard") or filename.startswith("report"):
            continue

        # フィルタパターン
        if filter_pattern and filter_pattern not in filename:
            continue

        try:
            with open(filepath, "r") as f:
                data = json.load(f)
                data["_filepath"] = filepath
                results.append(data)
        except (json.JSONDecodeError, IOError) as e:
            print(f"Warning: {filepath} の読み込みに失敗: {e}", file=sys.stderr)

    return results


def classify_results(results: List[Dict[str, Any]]) -> Dict[str, List[Dict[str, Any]]]:
    """結果をモード別に分類"""
    classified = {
        "with_plugin": [],
        "no_plugin": []
    }

    for r in results:
        version = r.get("version", "")
        if "with-plugin" in version or r.get("with_plugin", False):
            classified["with_plugin"].append(r)
        elif "no-plugin" in version or not r.get("with_plugin", True):
            classified["no_plugin"].append(r)

    return classified


def calculate_stats(results: List[Dict[str, Any]]) -> Dict[str, Any]:
    """統計を計算"""
    if not results:
        return {
            "total_trials": 0,
            "pass_rate": 0.0,
            "grade_score_avg": 0.0,
            "duration_median_seconds": 0.0,
            "estimated_cost_median_usd": 0.0,
            "input_tokens_avg": 0,
            "output_tokens_avg": 0
        }

    # grade.pass のカウント
    pass_count = 0
    grade_scores = []
    durations = []
    costs = []
    input_tokens = []
    output_tokens = []

    for r in results:
        grade = r.get("grade")
        if grade:
            if grade.get("pass", False):
                pass_count += 1
            score = grade.get("score")
            if score is not None:
                grade_scores.append(score)

        duration = r.get("duration_seconds")
        if duration is not None:
            durations.append(float(duration))

        cost = r.get("estimated_cost_usd") or r.get("total_cost_usd")
        if cost is not None:
            costs.append(float(cost))

        inp = r.get("input_tokens", 0)
        out = r.get("output_tokens", 0)
        if inp or out:
            input_tokens.append(inp)
            output_tokens.append(out)

    total = len(results)
    graded = len([r for r in results if r.get("grade")])

    return {
        "total_trials": total,
        "graded_trials": graded,
        "pass_count": pass_count,
        "pass_rate": pass_count / graded if graded > 0 else 0.0,
        "grade_score_avg": mean(grade_scores) if grade_scores else 0.0,
        "duration_median_seconds": median(durations) if durations else 0.0,
        "duration_avg_seconds": mean(durations) if durations else 0.0,
        "estimated_cost_median_usd": median(costs) if costs else 0.0,
        "estimated_cost_total_usd": sum(costs) if costs else 0.0,
        "input_tokens_avg": int(mean(input_tokens)) if input_tokens else 0,
        "output_tokens_avg": int(mean(output_tokens)) if output_tokens else 0
    }


def calculate_task_stats(results: List[Dict[str, Any]], tasks: List[str]) -> List[Dict[str, Any]]:
    """タスク別統計を計算"""
    task_results = []

    for task in tasks:
        task_data = [r for r in results if r.get("task") == task]
        if not task_data:
            continue

        stats = calculate_stats(task_data)
        stats["task"] = task
        task_results.append(stats)

    return task_results


def calculate_comparison(with_plugin: Dict[str, Any], no_plugin: Dict[str, Any]) -> Dict[str, Any]:
    """比較統計を計算"""
    comparison = {}

    # 成功率の差分
    comparison["pass_rate_diff"] = with_plugin["pass_rate"] - no_plugin["pass_rate"]

    # 所要時間の改善率
    if no_plugin["duration_median_seconds"] > 0:
        improvement = (no_plugin["duration_median_seconds"] - with_plugin["duration_median_seconds"]) / no_plugin["duration_median_seconds"] * 100
        comparison["duration_improvement_pct"] = round(improvement, 1)
    else:
        comparison["duration_improvement_pct"] = 0.0

    # コストの改善率
    if no_plugin["estimated_cost_median_usd"] > 0:
        improvement = (no_plugin["estimated_cost_median_usd"] - with_plugin["estimated_cost_median_usd"]) / no_plugin["estimated_cost_median_usd"] * 100
        comparison["cost_improvement_pct"] = round(improvement, 1)
    else:
        comparison["cost_improvement_pct"] = 0.0

    # Grade Score の差分
    comparison["grade_score_diff"] = with_plugin["grade_score_avg"] - no_plugin["grade_score_avg"]

    return comparison


def extract_trials(results: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """各 trial の詳細を抽出"""
    trials = []
    for r in results:
        version = r.get("version", "")
        mode = "with-plugin" if ("with-plugin" in version or r.get("with_plugin", False)) else "no-plugin"

        trial = {
            "task": r.get("task", "unknown"),
            "mode": mode,
            "iteration": r.get("iteration", 1),
            "timestamp": r.get("timestamp", ""),
            "duration_seconds": r.get("duration_seconds", 0),
            "exit_code": r.get("exit_code", -1),
            "success": r.get("success", False)
        }

        grade = r.get("grade")
        if grade:
            trial["pass"] = grade.get("pass", False)
            trial["score"] = grade.get("score", 0)
            trial["checks"] = grade.get("checks", [])
            trial["error"] = grade.get("error")
        else:
            trial["pass"] = None
            trial["score"] = None
            trial["checks"] = []

        trial["input_tokens"] = r.get("input_tokens", 0)
        trial["output_tokens"] = r.get("output_tokens", 0)
        trial["estimated_cost_usd"] = r.get("estimated_cost_usd") or r.get("total_cost_usd")

        trials.append(trial)

    return trials


def generate_scorecard_json(
    meta: Dict[str, Any],
    with_plugin_stats: Dict[str, Any],
    no_plugin_stats: Dict[str, Any],
    comparison: Dict[str, Any],
    task_stats: Dict[str, List[Dict[str, Any]]],
    trials: List[Dict[str, Any]]
) -> Dict[str, Any]:
    """JSON 形式の Scorecard を生成"""
    return {
        "meta": meta,
        "summary": {
            "with_plugin": with_plugin_stats,
            "no_plugin": no_plugin_stats,
            "comparison": comparison
        },
        "tasks": {
            "with_plugin": task_stats.get("with_plugin", []),
            "no_plugin": task_stats.get("no_plugin", [])
        },
        "trials": trials
    }


def generate_scorecard_md(scorecard: Dict[str, Any]) -> str:
    """Markdown 形式の Scorecard を生成"""
    meta = scorecard["meta"]
    summary = scorecard["summary"]
    wp = summary["with_plugin"]
    np = summary["no_plugin"]
    comp = summary["comparison"]

    lines = []
    lines.append("# Claude harness Scorecard")
    lines.append("")
    lines.append(f"生成日時: {meta['generated_at']}")
    lines.append("")
    lines.append("---")
    lines.append("")
    lines.append("## メタ情報")
    lines.append("")
    lines.append("| 項目 | 値 |")
    lines.append("|------|-----|")
    lines.append(f"| Suite Version | {meta['suite_version']} |")
    lines.append(f"| Harness Version | {meta['harness_version']} |")
    lines.append(f"| Commit | {meta['harness_commit']} |")
    lines.append(f"| OS | {meta['os']} {meta['os_version']} |")
    lines.append(f"| Trials | {meta['trials']} |")
    lines.append(f"| コスト前提 | {meta['cost_assumption']} |")
    lines.append("")
    lines.append("> **注意**: 推定コストは参考値であり、実際の請求額ではありません。")
    lines.append("")
    lines.append("---")
    lines.append("")
    lines.append("## サマリー")
    lines.append("")
    lines.append("| 指標 | with-plugin | no-plugin | 差分 |")
    lines.append("|------|-------------|-----------|------|")
    lines.append(f"| Trial 数 | {wp['total_trials']} | {np['total_trials']} | - |")
    lines.append(f"| 成功率 | {wp['pass_rate']*100:.1f}% | {np['pass_rate']*100:.1f}% | {comp['pass_rate_diff']*100:+.1f}% |")
    lines.append(f"| Grade Score 平均 | {wp['grade_score_avg']:.3f} | {np['grade_score_avg']:.3f} | {comp['grade_score_diff']:+.3f} |")
    lines.append(f"| 所要時間（中央値） | {wp['duration_median_seconds']:.1f}s | {np['duration_median_seconds']:.1f}s | {comp['duration_improvement_pct']:+.1f}% |")
    lines.append(f"| 推定コスト（中央値） | ${wp['estimated_cost_median_usd']:.4f} | ${np['estimated_cost_median_usd']:.4f} | {comp['cost_improvement_pct']:+.1f}% |")
    lines.append(f"| Input Tokens 平均 | {wp['input_tokens_avg']:,} | {np['input_tokens_avg']:,} | - |")
    lines.append(f"| Output Tokens 平均 | {wp['output_tokens_avg']:,} | {np['output_tokens_avg']:,} | - |")
    lines.append("")
    lines.append("### 結論")
    lines.append("")

    if comp["pass_rate_diff"] > 0.1:
        lines.append(f"- **成功率**: プラグインにより **{comp['pass_rate_diff']*100:.1f}%** 向上")
    elif comp["pass_rate_diff"] < -0.1:
        lines.append(f"- **成功率**: プラグインにより {abs(comp['pass_rate_diff'])*100:.1f}% 低下")
    else:
        lines.append("- **成功率**: 有意な差なし")

    if comp["duration_improvement_pct"] > 5:
        lines.append(f"- **所要時間**: プラグインにより **{comp['duration_improvement_pct']:.1f}%** 短縮")
    elif comp["duration_improvement_pct"] < -5:
        lines.append(f"- **所要時間**: プラグインにより {abs(comp['duration_improvement_pct']):.1f}% 増加（オーバーヘッド）")
    else:
        lines.append("- **所要時間**: 有意な差なし")

    lines.append("")
    lines.append("---")
    lines.append("")
    lines.append("## タスク別詳細")
    lines.append("")

    # タスク別テーブル
    wp_tasks = {t["task"]: t for t in scorecard["tasks"].get("with_plugin", [])}
    np_tasks = {t["task"]: t for t in scorecard["tasks"].get("no_plugin", [])}
    all_tasks = set(wp_tasks.keys()) | set(np_tasks.keys())

    if all_tasks:
        lines.append("| Task | Mode | Pass Rate | Grade Avg | Duration |")
        lines.append("|------|------|-----------|-----------|----------|")

        for task in sorted(all_tasks):
            if task in wp_tasks:
                t = wp_tasks[task]
                lines.append(f"| {task} | with-plugin | {t['pass_rate']*100:.0f}% | {t['grade_score_avg']:.3f} | {t['duration_median_seconds']:.1f}s |")
            if task in np_tasks:
                t = np_tasks[task]
                lines.append(f"| {task} | no-plugin | {t['pass_rate']*100:.0f}% | {t['grade_score_avg']:.3f} | {t['duration_median_seconds']:.1f}s |")

        lines.append("")

    lines.append("---")
    lines.append("")
    lines.append("## 失敗した Trial")
    lines.append("")

    failed_trials = [t for t in scorecard["trials"] if t.get("pass") == False]
    if failed_trials:
        lines.append("| Task | Mode | Iteration | Score | Error |")
        lines.append("|------|------|-----------|-------|-------|")
        for t in failed_trials[:20]:  # 最大20件
            error = t.get("error", "")[:50] if t.get("error") else "-"
            lines.append(f"| {t['task']} | {t['mode']} | {t['iteration']} | {t.get('score', 0):.3f} | {error} |")
        lines.append("")
    else:
        lines.append("*失敗した Trial はありません*")
        lines.append("")

    lines.append("---")
    lines.append("")
    lines.append("## 再現手順")
    lines.append("")
    lines.append("```bash")
    lines.append("# Suite 実行")
    lines.append("./benchmarks/scripts/run-isolated-benchmark.sh --task <task> --with-plugin")
    lines.append("./benchmarks/scripts/run-isolated-benchmark.sh --task <task>")
    lines.append("")
    lines.append("# Scorecard 生成")
    lines.append("./benchmarks/scripts/generate-scorecard.sh")
    lines.append("```")
    lines.append("")
    lines.append("---")
    lines.append("")
    lines.append("*Generated by Claude harness Scorecard Generator*")

    return "\n".join(lines)


def main():
    results_dir = sys.argv[1]
    output_dir = sys.argv[2]
    filter_pattern = sys.argv[3] if len(sys.argv) > 3 else ""
    verbose = sys.argv[4].lower() == "true" if len(sys.argv) > 4 else False
    plugin_root = sys.argv[5] if len(sys.argv) > 5 else "."

    # 結果読み込み
    results = load_results(results_dir, filter_pattern)
    if not results:
        print("Error: 結果ファイルが見つかりません", file=sys.stderr)
        print(f"  対象: {results_dir}/*.json", file=sys.stderr)
        if filter_pattern:
            print(f"  フィルタ: {filter_pattern}", file=sys.stderr)
        sys.exit(1)

    if verbose:
        print(f"読み込み: {len(results)} 件の結果", file=sys.stderr)

    # 分類
    classified = classify_results(results)

    if verbose:
        print(f"  with-plugin: {len(classified['with_plugin'])} 件", file=sys.stderr)
        print(f"  no-plugin: {len(classified['no_plugin'])} 件", file=sys.stderr)

    # 統計計算
    wp_stats = calculate_stats(classified["with_plugin"])
    np_stats = calculate_stats(classified["no_plugin"])
    comparison = calculate_comparison(wp_stats, np_stats)

    # タスク別統計
    suite_tasks = [
        "plan-feature", "impl-utility", "impl-test", "impl-refactor",
        "review-security", "review-quality", "multi-file-refactor", "skill-routing"
    ]
    task_stats = {
        "with_plugin": calculate_task_stats(classified["with_plugin"], suite_tasks),
        "no_plugin": calculate_task_stats(classified["no_plugin"], suite_tasks)
    }

    # Trial 詳細
    trials = extract_trials(results)

    # 実際の試行数を計算（各タスクの最大イテレーション番号）
    actual_trials = max([t.get("iteration", 1) for t in trials], default=1) if trials else 0

    # メタ情報
    os_name, os_version = get_os_info()
    meta = {
        "suite_version": "v1",
        "harness_version": get_harness_version(plugin_root),
        "harness_commit": get_harness_commit(plugin_root),
        "generated_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "os": os_name,
        "os_version": os_version,
        "cost_assumption": "sonnet_3_5_input_3_per_mtok_output_15_per_mtok",
        "trials": actual_trials,
        "filter": filter_pattern if filter_pattern else None
    }

    # Scorecard 生成
    scorecard = generate_scorecard_json(meta, wp_stats, np_stats, comparison, task_stats, trials)

    # 出力
    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    json_path = os.path.join(output_dir, f"scorecard-{timestamp}.json")
    md_path = os.path.join(output_dir, f"scorecard-{timestamp}.md")

    os.makedirs(output_dir, exist_ok=True)

    with open(json_path, "w") as f:
        json.dump(scorecard, f, indent=2, ensure_ascii=False)

    with open(md_path, "w") as f:
        f.write(generate_scorecard_md(scorecard))

    print(f"✓ Scorecard を生成しました")
    print(f"  JSON: {json_path}")
    print(f"  Markdown: {md_path}")
    print("")
    print("=== サマリー ===")
    print(f"with-plugin: 成功率 {wp_stats['pass_rate']*100:.1f}%, Grade {wp_stats['grade_score_avg']:.3f}, 時間 {wp_stats['duration_median_seconds']:.1f}s")
    print(f"no-plugin:   成功率 {np_stats['pass_rate']*100:.1f}%, Grade {np_stats['grade_score_avg']:.3f}, 時間 {np_stats['duration_median_seconds']:.1f}s")
    print(f"差分: 成功率 {comparison['pass_rate_diff']*100:+.1f}%, 時間 {comparison['duration_improvement_pct']:+.1f}%")


if __name__ == "__main__":
    main()
PYTHON
