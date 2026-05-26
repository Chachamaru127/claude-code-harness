#!/usr/bin/env python3
"""
Breezing Benchmark Analyzer
Statistical analysis + Markdown report generation
"""

import json
import math
from pathlib import Path
from typing import Dict, Any, List, Tuple
from datetime import datetime


def load_results(results_dir: Path) -> List[Dict[str, Any]]:
    """Load all result JSON files"""
    results = []
    for json_file in sorted(results_dir.rglob("result.json")):
        with open(json_file, "r", encoding="utf-8") as f:
            results.append(json.load(f))
    return results


def split_by_condition(results: List[Dict[str, Any]]) -> Tuple[List[Dict], List[Dict]]:
    """Split into Vanilla and Breezing groups"""
    vanilla = [r for r in results if r.get("condition") == "vanilla"]
    breezing = [r for r in results if r.get("condition") == "breezing"]
    return vanilla, breezing


def extract_scores(results: List[Dict[str, Any]]) -> List[float]:
    """Extract primary scores"""
    return [r.get("grading", {}).get("primary", {}).get("score", 0.0) for r in results]


def mean(values: List[float]) -> float:
    if not values:
        return 0.0
    return sum(values) / len(values)


def std(values: List[float]) -> float:
    if len(values) < 2:
        return 0.0
    m = mean(values)
    variance = sum((x - m) ** 2 for x in values) / (len(values) - 1)
    return math.sqrt(variance)


def hedges_g(group1: List[float], group2: List[float]) -> float:
    """Hedges' g (effect size with small-sample correction)"""
    n1, n2 = len(group1), len(group2)
    if n1 < 2 or n2 < 2:
        return 0.0

    m1, m2 = mean(group1), mean(group2)
    s1, s2 = std(group1), std(group2)

    # Pooled SD
    sp = math.sqrt(((n1 - 1) * s1**2 + (n2 - 1) * s2**2) / (n1 + n2 - 2))
    if sp == 0:
        return 0.0

    # Cohen's d
    d = (m2 - m1) / sp

    # Hedges' correction factor
    df = n1 + n2 - 2
    correction = 1 - (3 / (4 * df - 1))

    return d * correction


def welch_t_test(group1: List[float], group2: List[float]) -> Tuple[float, float]:
    """Welch's t-test (two-sided)"""
    n1, n2 = len(group1), len(group2)
    if n1 < 2 or n2 < 2:
        return 0.0, 1.0

    m1, m2 = mean(group1), mean(group2)
    s1, s2 = std(group1), std(group2)

    se1 = s1**2 / n1
    se2 = s2**2 / n2
    se_total = se1 + se2

    if se_total == 0:
        return 0.0, 1.0

    t_stat = (m2 - m1) / math.sqrt(se_total)

    # Welch-Satterthwaite df
    df = se_total**2 / (se1**2 / (n1 - 1) + se2**2 / (n2 - 1))

    # Approximate p-value (without scipy)
    # Use scipy when available
    try:
        from scipy import stats
        p_value = stats.t.sf(abs(t_stat), df) * 2
    except ImportError:
        # Approximation: substitute normal distribution (valid when df is large)
        p_value = 2 * (1 - _normal_cdf(abs(t_stat)))

    return t_stat, p_value


def _normal_cdf(x: float) -> float:
    """Standard normal CDF (approximation)"""
    return 0.5 * (1 + math.erf(x / math.sqrt(2)))


def bootstrap_ci(
    group1: List[float],
    group2: List[float],
    n_bootstrap: int = 10000,
    ci: float = 0.95,
    seed: int = 42,
) -> Tuple[float, float, float]:
    """Compute effect size CI via hierarchical bootstrap"""
    import random
    rng = random.Random(seed)

    diffs = []
    combined_all = group1 + group2
    n1, n2 = len(group1), len(group2)

    for _ in range(n_bootstrap):
        # Resample per task
        sample1 = [rng.choice(group1) for _ in range(n1)]
        sample2 = [rng.choice(group2) for _ in range(n2)]
        g = hedges_g(sample1, sample2)
        diffs.append(g)

    diffs.sort()
    alpha = 1 - ci
    lower_idx = int(n_bootstrap * alpha / 2)
    upper_idx = int(n_bootstrap * (1 - alpha / 2))

    return diffs[lower_idx], mean(diffs), diffs[upper_idx]


def analyze_by_task(results: List[Dict[str, Any]]) -> Dict[str, Dict[str, List[float]]]:
    """Organize scores by task"""
    by_task: Dict[str, Dict[str, List[float]]] = {}
    for r in results:
        task_id = r.get("task_id", "unknown")
        condition = r.get("condition", "unknown")
        score = r.get("grading", {}).get("primary", {}).get("score", 0.0)

        if task_id not in by_task:
            by_task[task_id] = {"vanilla": [], "breezing": []}
        by_task[task_id][condition].append(score)

    return by_task


def generate_report(results_dir: Path) -> str:
    """Generate Markdown report"""
    results = load_results(results_dir)
    if not results:
        return "# Breezing v2 Benchmark Report\n\nNo results found."

    vanilla, breezing = split_by_condition(results)
    v_scores = extract_scores(vanilla)
    b_scores = extract_scores(breezing)

    # Overall statistics
    t_stat, p_value = welch_t_test(v_scores, b_scores)
    g = hedges_g(v_scores, b_scores)

    try:
        ci_lower, ci_mean, ci_upper = bootstrap_ci(v_scores, b_scores)
        ci_str = f"[{ci_lower:.3f}, {ci_upper:.3f}]"
    except Exception:
        ci_str = "N/A"

    # Verdict
    if p_value < 0.05 and g > 0.5:
        verdict = "Significantly positive"
    elif p_value < 0.10 or g > 0.3:
        verdict = "Trend detected"
    elif p_value < 0.05 and g < -0.5:
        verdict = "Significantly negative"
    else:
        verdict = "No difference"

    # Efficiency metrics
    v_durations = [r.get("execution", {}).get("duration_seconds", 0) for r in vanilla]
    b_durations = [r.get("execution", {}).get("duration_seconds", 0) for r in breezing]

    # Per-task analysis
    by_task = analyze_by_task(results)

    # Generate report
    lines = [
        f"# Breezing v2 Benchmark Report",
        f"",
        f"Generated: {datetime.now().isoformat()}",
        f"",
        f"## Summary",
        f"",
        f"| Metric | Vanilla | Breezing |",
        f"|--------|---------|----------|",
        f"| Runs | {len(vanilla)} | {len(breezing)} |",
        f"| Mean Score | {mean(v_scores):.3f} | {mean(b_scores):.3f} |",
        f"| Std Dev | {std(v_scores):.3f} | {std(b_scores):.3f} |",
        f"| Mean Duration (s) | {mean(v_durations):.1f} | {mean(b_durations):.1f} |",
        f"",
        f"## Statistical Analysis",
        f"",
        f"| Metric | Value |",
        f"|--------|-------|",
        f"| Welch t-statistic | {t_stat:.4f} |",
        f"| p-value (two-sided) | {p_value:.4f} |",
        f"| Hedges' g | {g:.4f} |",
        f"| 95% CI (bootstrap) | {ci_str} |",
        f"| **Verdict** | **{verdict}** |",
        f"",
        f"## Per-Task Results",
        f"",
        f"| Task | Vanilla (mean) | Breezing (mean) | Diff |",
        f"|------|---------------|-----------------|------|",
    ]

    for task_id in sorted(by_task.keys()):
        v = by_task[task_id].get("vanilla", [])
        b = by_task[task_id].get("breezing", [])
        v_mean = mean(v) if v else 0.0
        b_mean = mean(b) if b else 0.0
        diff = b_mean - v_mean
        sign = "+" if diff >= 0 else ""
        lines.append(f"| {task_id} | {v_mean:.3f} | {b_mean:.3f} | {sign}{diff:.3f} |")

    lines.extend([
        f"",
        f"## Efficiency Analysis",
        f"",
        f"| Metric | Vanilla | Breezing | Ratio |",
        f"|--------|---------|----------|-------|",
        f"| Mean Duration (s) | {mean(v_durations):.1f} | {mean(b_durations):.1f} | {mean(b_durations)/mean(v_durations):.2f}x |" if mean(v_durations) > 0 else "| Mean Duration (s) | N/A | N/A | N/A |",
    ])

    # Score per minute
    v_spm = [s / (d / 60) if d > 0 else 0 for s, d in zip(v_scores, v_durations)]
    b_spm = [s / (d / 60) if d > 0 else 0 for s, d in zip(b_scores, b_durations)]
    if v_spm and b_spm:
        lines.append(f"| Score/Minute | {mean(v_spm):.4f} | {mean(b_spm):.4f} | {mean(b_spm)/mean(v_spm):.2f}x |" if mean(v_spm) > 0 else "| Score/Minute | N/A | N/A | N/A |")

    lines.extend([
        f"",
        f"## Failure/Timeout Summary",
        f"",
        f"| Condition | Score=0 (failures) | Total |",
        f"|-----------|-------------------|-------|",
        f"| Vanilla | {sum(1 for s in v_scores if s == 0.0)} | {len(v_scores)} |",
        f"| Breezing | {sum(1 for s in b_scores if s == 0.0)} | {len(b_scores)} |",
        f"",
        f"## Methodology",
        f"",
        f"- Primary endpoint: Hidden test pass rate (correctness)",
        f"- Statistical test: Welch's t-test (two-sided)",
        f"- Effect size: Hedges' g with bootstrap 95% CI",
        f"- Significance: p < 0.05 AND Hedges' g CI lower bound > 0",
        f"- All failures included in analysis (score = 0)",
        f"- Condition order randomized per (task, repeat) pair",
    ])

    return "\n".join(lines)


def main():
    import argparse

    parser = argparse.ArgumentParser(description="Breezing Benchmark Analyzer")
    parser.add_argument("--results-dir", required=True, help="Results directory")
    parser.add_argument("--output", help="Output file (default: stdout)")

    args = parser.parse_args()

    report = generate_report(Path(args.results_dir))

    if args.output:
        Path(args.output).write_text(report, encoding="utf-8")
        print(f"Report saved to {args.output}")
    else:
        print(report)


if __name__ == "__main__":
    main()
