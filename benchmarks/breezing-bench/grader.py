#!/usr/bin/env python3
"""
Breezing Benchmark Grader
Deterministic grader that runs hidden tests and calculates scores
"""

import json
import subprocess
import shutil
from pathlib import Path
from typing import Dict, Any


class BreezingGrader:
    """Grader for the Breezing benchmark"""

    def __init__(self, project_dir: Path, task_dir: Path):
        """
        Args:
            project_dir: Project directory where the agent worked
            task_dir: Task definition directory (containing hidden-tests/)
        """
        self.project_dir = Path(project_dir).resolve()
        self.task_dir = Path(task_dir).resolve()
        self.hidden_tests_dir = self.task_dir / "hidden-tests"

    def grade(self) -> Dict[str, Any]:
        """Run grading"""
        result: Dict[str, Any] = {
            "primary": self._grade_correctness(),
            "secondary": {
                "typecheck": self._grade_typecheck(),
                "self_test_count": self._count_self_tests(),
            },
        }
        return result

    def _grade_correctness(self) -> Dict[str, Any]:
        """Primary endpoint: hidden test pass rate"""
        if not self.hidden_tests_dir.exists():
            return {"score": 0.0, "passed": 0, "total": 0, "error": "hidden-tests not found"}

        # Copy hidden tests into the project
        test_dest = self.project_dir / "src" / "__hidden_tests__"
        test_dest.mkdir(parents=True, exist_ok=True)

        hidden_test_files = list(self.hidden_tests_dir.glob("*.test.ts"))
        if not hidden_test_files:
            return {"score": 0.0, "passed": 0, "total": 0, "error": "no hidden test files"}

        for test_file in hidden_test_files:
            shutil.copy2(test_file, test_dest / test_file.name)

        try:
            # Install with npm ci (when lockfile exists)
            lock_file = self.project_dir / "package-lock.json"
            install_cmd = ["npm", "ci"] if lock_file.exists() else ["npm", "install"]
            subprocess.run(
                install_cmd,
                cwd=self.project_dir,
                capture_output=True,
                timeout=60,
            )

            # Run only hidden tests
            test_result = subprocess.run(
                ["npx", "vitest", "run", "--reporter=json", str(test_dest)],
                cwd=self.project_dir,
                capture_output=True,
                timeout=120,
                text=True,
            )

            # Parse JSON report
            try:
                # vitest JSON output goes to stdout
                report = json.loads(test_result.stdout)
                total = report.get("numTotalTests", 0)
                passed = report.get("numPassedTests", 0)
                failed = report.get("numFailedTests", 0)

                return {
                    "score": passed / total if total > 0 else 0.0,
                    "passed": passed,
                    "total": total,
                    "failed": failed,
                    "details": self._extract_test_details(report),
                }
            except (json.JSONDecodeError, KeyError):
                # Fall back to parsing text output when JSON parsing fails
                return self._parse_text_output(test_result)

        except subprocess.TimeoutExpired:
            return {"score": 0.0, "passed": 0, "total": 0, "error": "test timeout (120s)"}
        except FileNotFoundError:
            return {"score": 0.0, "passed": 0, "total": 0, "error": "npm/vitest not found"}
        finally:
            # Remove hidden tests (cleanup)
            if test_dest.exists():
                shutil.rmtree(test_dest)

    def _parse_text_output(self, result: subprocess.CompletedProcess) -> Dict[str, Any]:
        """Parse test results from text output"""
        import re
        output = result.stdout + result.stderr

        # Parse vitest summary line: "Tests  5 passed | 2 failed (7)"
        match = re.search(r"Tests\s+(\d+)\s+passed(?:\s*\|\s*(\d+)\s+failed)?\s*\((\d+)\)", output)
        if match:
            passed = int(match.group(1))
            failed = int(match.group(2) or 0)
            total = int(match.group(3))
            return {
                "score": passed / total if total > 0 else 0.0,
                "passed": passed,
                "total": total,
                "failed": failed,
            }

        # Parsing failed
        return {
            "score": 0.0,
            "passed": 0,
            "total": 0,
            "error": "failed to parse test output",
            "stdout": output[:2000],
        }

    def _extract_test_details(self, report: Dict[str, Any]) -> list:
        """Extract test details"""
        details = []
        for suite in report.get("testResults", []):
            for test in suite.get("assertionResults", []):
                details.append({
                    "name": test.get("fullName", ""),
                    "status": test.get("status", ""),
                    "duration": test.get("duration", 0),
                })
        return details

    def _grade_typecheck(self) -> Dict[str, Any]:
        """Secondary: tsc --noEmit result"""
        try:
            result = subprocess.run(
                ["npx", "tsc", "--noEmit"],
                cwd=self.project_dir,
                capture_output=True,
                timeout=30,
                text=True,
            )
            error_count = result.stdout.count("error TS") + result.stderr.count("error TS")
            return {
                "success": result.returncode == 0,
                "error_count": error_count,
            }
        except (subprocess.TimeoutExpired, FileNotFoundError):
            return {"success": False, "error_count": -1}

    def _count_self_tests(self) -> int:
        """Secondary: number of test files created by the agent"""
        test_patterns = ["*.test.ts", "*.spec.ts", "*.test.js", "*.spec.js"]
        count = 0
        for pattern in test_patterns:
            for path in self.project_dir.rglob(pattern):
                if "node_modules" not in str(path) and "__hidden_tests__" not in str(path):
                    count += 1
        return count


def main():
    import argparse

    parser = argparse.ArgumentParser(description="Breezing Benchmark Grader")
    parser.add_argument("--project-dir", required=True, help="Agent's project directory")
    parser.add_argument("--task-dir", required=True, help="Task definition directory")
    parser.add_argument("--json", action="store_true", help="JSON output")

    args = parser.parse_args()

    grader = BreezingGrader(
        project_dir=Path(args.project_dir),
        task_dir=Path(args.task_dir),
    )
    result = grader.grade()

    if args.json:
        print(json.dumps(result, indent=2, ensure_ascii=False))
    else:
        primary = result["primary"]
        print(f"Correctness: {primary['score']:.2%} ({primary['passed']}/{primary['total']})")
        print(f"Typecheck: {'PASS' if result['secondary']['typecheck']['success'] else 'FAIL'}")
        print(f"Self-tests: {result['secondary']['self_test_count']}")


if __name__ == "__main__":
    main()
