#!/usr/bin/env python3
"""Run one MergeGate check with the pinned Quint/TLC toolchain.

The project-local replacement for the route-project-setup run_check.py wrapper:
it reads report.json, verifies the source and model hashes, compiles the Quint
model and runs TLC with the same q_init/q_step/q_inv contract.
"""
import argparse
import hashlib
import json
import re
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent
PROJECT = ROOT.parents[2]
sys.path.insert(0, str(PROJECT))

from formal.quint.toolchain import compile_model, jar_path, java_command, run_command  # noqa: E402


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("check", help="check ID in report.json")
    parser.add_argument("--result", required=True, help="new path for result.json")
    parser.add_argument("--stdout", required=True, help="new path for the TLC stdout log")
    args = parser.parse_args()

    report = json.loads((ROOT / "report.json").read_text())
    model = PROJECT / report["model"]["path"]
    sources = {s["id"]: sha256(PROJECT / s["path"]) for s in report["sources"]}
    checks = {c["id"]: c for c in report["checks"]}
    if args.check not in checks:
        raise SystemExit("unknown check: " + args.check)
    check = checks[args.check]
    if sources != check["checked_sources"]:
        raise SystemExit("source snapshot mismatch; regenerate report.json and the evidence")
    if sha256(model) != report["model"]["sha256"]:
        raise SystemExit("model hash mismatch")

    result_path = Path(args.result).resolve()
    stdout_path = Path(args.stdout).resolve()
    if result_path.exists() or stdout_path.exists() or result_path == stdout_path:
        raise SystemExit("new evidence paths required")
    work = result_path.parent / (args.check + "-compile-" + str(time.time_ns()))
    if work.exists():
        raise SystemExit("new compilation directory required")
    work.mkdir(parents=True)

    result = {
        "status": "unverified",
        "tlc_exit": None,
        "property": check["symbol"],
        "main": report["model"]["main"],
        "model_sha256": report["model"]["sha256"],
        "checked_sources": sources,
        "command": check["command"],
        "observed_at": datetime.now(timezone.utc).isoformat(),
        "verification_scope": "finite_model_only",
        "kind": check.get("kind", "invariant"),
        "invocation": [sys.executable, *sys.argv],
    }
    output = ""
    status = 2
    try:
        tla = compile_model(model, report["model"]["main"], check["symbol"], work)
        config = work / "check.cfg"
        config.write_text("INIT q_init\nNEXT q_step\nINVARIANT q_inv\nCHECK_DEADLOCK FALSE\n")
        command = [
            java_command(), "-Xmx1g", "-Xss16m", "-cp", str(jar_path()),
            "tlc2.TLC", "-workers", "1", "-fp", "0", "-metadir", str(work / "states"),
            "-config", str(config), str(tla),
        ]
        done = run_command(command)
        output = done.stdout
        (work / "tlc.stderr.log").write_text(done.stderr)
        result["actual_checker_command"] = command
        result["tlc_exit"] = done.returncode
        result["state_counts"] = re.findall(
            r"\d+ states generated, \d+ distinct states found, \d+ states left on queue", output
        )
        if done.returncode == 0 and "Model checking completed. No error has been found." in output:
            result["status"], status = "pass", 0
        elif done.returncode == 12 and "Invariant q_inv is violated" in output:
            result["status"], status = "violation", 1
    except Exception as error:  # noqa: BLE001 - the result records the failure class
        result["reason"] = type(error).__name__ + ": " + str(error)

    result["stdout_sha256"] = hashlib.sha256(output.encode()).hexdigest()
    stdout_path.parent.mkdir(parents=True, exist_ok=True)
    stdout_path.write_text(output)
    result_path.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps(
        {"status": result["status"], "result": str(result_path), "tlc_exit": result["tlc_exit"]},
        ensure_ascii=False,
    ))
    return status


if __name__ == "__main__":
    raise SystemExit(main())
