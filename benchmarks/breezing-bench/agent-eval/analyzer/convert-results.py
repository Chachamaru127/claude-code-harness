#!/usr/bin/env python3
"""
Conversion script: agent-eval results -> Breezing analyzer format

agent-eval result directory structure:
  results/{experiment}/{timestamp}/
    ├── experiment.json
    └── {eval-name}/
        ├── summary.json
        └── run-{N}/
            ├── result.json
            └── transcript.jsonl

Output format (expected by analyzer.py):
  converted/{timestamp}/
    └── result.json (one file per run)
"""

import json
from pathlib import Path
from typing import Any, Dict, List


def convert_experiment(
    experiment_dir: Path, condition: str
) -> List[Dict[str, Any]]:
    """Convert a single experiment directory"""
    results = []

    for eval_dir in sorted(experiment_dir.iterdir()):
        if not eval_dir.is_dir():
            continue
        # Skip experiment.json
        if eval_dir.name.startswith(".") or eval_dir.name == "experiment.json":
            continue

        task_id = eval_dir.name  # e.g., "task-01"

        for run_dir in sorted(eval_dir.iterdir()):
            if not run_dir.is_dir() or not run_dir.name.startswith("run-"):
                continue

            result_file = run_dir / "result.json"
            if not result_file.exists():
                continue

            with open(result_file, "r", encoding="utf-8") as f:
                agent_result = json.load(f)

            # agent-eval result → analyzer format
            run_number = int(run_dir.name.replace("run-", ""))
            status = agent_result.get("status", "fail")
            duration = agent_result.get("duration", 0)
            is_pass = status in ("pass", "passed")

            score = 1.0 if is_pass else 0.0

            converted = {
                "task_id": task_id,
                "condition": condition,
                "iteration": run_number,
                "grading": {
                    "primary": {
                        "score": score,
                        "passed": 1 if is_pass else 0,
                        "total": 1,
                        "failed": 0 if is_pass else 1,
                        "details": [],
                    },
                    "secondary": {
                        "typecheck": {"success": is_pass, "error_count": 0},
                    },
                },
                "execution": {
                    "duration_seconds": duration,
                    "status": "completed" if is_pass else "failed",
                },
                "metadata": {
                    "source": "agent-eval",
                    "experiment": condition,
                },
            }
            results.append(converted)

    return results


def collect_sequential_results(
    results_dir: Path, condition: str
) -> List[Dict[str, Any]]:
    """Collect results from _seq_{condition}_task-XX directories"""
    all_results = []
    prefix = f"_seq_{condition}_"

    for seq_dir in sorted(results_dir.iterdir()):
        if not seq_dir.is_dir() or not seq_dir.name.startswith(prefix):
            continue

        # _seq_vanilla_task-01/<timestamp>/ → task-XX is inside the timestamp dir
        for timestamp_dir in sorted(seq_dir.iterdir()):
            if not timestamp_dir.is_dir():
                continue
            results = convert_experiment(timestamp_dir, condition)
            all_results.extend(results)

    return all_results


def main():
    import argparse

    parser = argparse.ArgumentParser(
        description="Convert agent-eval results to analyzer format"
    )
    parser.add_argument(
        "--vanilla-dir",
        type=Path,
        help="Path to vanilla experiment results (e.g., results/vanilla/2026-01-01T...)",
    )
    parser.add_argument(
        "--breezing-dir",
        type=Path,
        help="Path to breezing experiment results (e.g., results/breezing/2026-01-01T...)",
    )
    parser.add_argument(
        "--sequential",
        action="store_true",
        help="Collect from _seq_* directories (run-sequential.sh output)",
    )
    parser.add_argument(
        "--results-dir",
        type=Path,
        help="Base results directory (for --sequential mode)",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        required=True,
        help="Output directory for converted results",
    )

    args = parser.parse_args()

    output_dir = args.output_dir
    output_dir.mkdir(parents=True, exist_ok=True)

    all_results = []

    if args.sequential and args.results_dir:
        vanilla_results = collect_sequential_results(args.results_dir, "vanilla")
        all_results.extend(vanilla_results)
        print(f"Converted {len(vanilla_results)} vanilla results (sequential)")

        breezing_results = collect_sequential_results(args.results_dir, "breezing")
        all_results.extend(breezing_results)
        print(f"Converted {len(breezing_results)} breezing results (sequential)")
    else:
        if args.vanilla_dir and args.vanilla_dir.exists():
            vanilla_results = convert_experiment(args.vanilla_dir, "vanilla")
            all_results.extend(vanilla_results)
            print(f"Converted {len(vanilla_results)} vanilla results")

        if args.breezing_dir and args.breezing_dir.exists():
            breezing_results = convert_experiment(args.breezing_dir, "breezing")
            all_results.extend(breezing_results)
            print(f"Converted {len(breezing_results)} breezing results")

    # Save each result as an individual result.json
    for result in all_results:
        task_id = result["task_id"]
        condition = result["condition"]
        iteration = result["iteration"]
        result_dir = output_dir / f"{condition}-{task_id}-iter{iteration}"
        result_dir.mkdir(parents=True, exist_ok=True)
        with open(result_dir / "result.json", "w", encoding="utf-8") as f:
            json.dump(result, f, indent=2, ensure_ascii=False)

    print(f"\nTotal: {len(all_results)} results written to {output_dir}")


if __name__ == "__main__":
    main()
