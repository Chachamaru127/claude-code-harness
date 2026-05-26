#!/usr/bin/env bash
# check-residue.sh — Migration Residue Scanner (Phase 40)
#
# Purpose:
#   Reads .claude/rules/deleted-concepts.yaml and detects whether any
#   deleted paths or concepts still exist in the repository.
#   Exits 0 if none found, exits 1 if one or more are found.
#
# Usage:
#   bash scripts/check-residue.sh
#
# Python3 acts as the primary parser; bash is just a launcher.

set -euo pipefail

# Identify repository root (resolved relative to this script's location)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

export REPO_ROOT_PY="${REPO_ROOT}"

exec python3 - "$@" <<'PYEOF'
import yaml
import subprocess
import sys
import os
import time
import re

REPO_ROOT = os.path.normpath(
    os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
) if False else os.environ.get("REPO_ROOT_PY", "")

# When called via exec python3 - from bash, __file__ is unavailable.
# Infer the path from argv[0] instead of passing via environment variable.
# In heredoc exec mode, sys.argv[0] == '-', so resolve from getcwd().
if not REPO_ROOT:
    # The script is expected to be called from scripts/. cwd can be anything,
    # so use sys.argv if available; otherwise resolve from cwd.
    REPO_ROOT = os.getcwd()
    # check-residue.sh lives in scripts/, so if scripts/ is cwd, go up one level
    if os.path.basename(REPO_ROOT) == "scripts":
        REPO_ROOT = os.path.dirname(REPO_ROOT)

YAML_PATH = os.path.join(REPO_ROOT, ".claude/rules/deleted-concepts.yaml")

start_time = time.time()

# ─── Load YAML ─────────────────────────────────────────────────────────────
if not os.path.exists(YAML_PATH):
    print(f"ERROR: {YAML_PATH} not found", file=sys.stderr)
    sys.exit(2)

with open(YAML_PATH, "r", encoding="utf-8") as f:
    config = yaml.safe_load(f)

deleted_paths    = config.get("deleted_paths", [])
deleted_concepts = config.get("deleted_concepts", [])

# Skip entries with the scan_disabled flag set
deleted_concepts = [c for c in deleted_concepts if not c.get("_scan_disabled", False)]

n_paths    = len(deleted_paths)
n_concepts = len(deleted_concepts)

print("=== Migration Residue Scan ===")
print(f"Loaded: .claude/rules/deleted-concepts.yaml")
print(f"Entries: {n_paths} deleted_paths + {n_concepts} deleted_concepts")
print()

# ─── Allowlist check ─────────────────────────────────────────────────────────
def is_allowlisted(filepath: str, allowlist: list) -> bool:
    """
    Check whether filepath matches any prefix in the allowlist.
    Allowlist entries are prefix-matched.
    filepath is relative to the repository root (no ./ prefix).
    """
    # Strip ./ and normalize
    rel = filepath.lstrip("./")
    for entry in allowlist:
        entry_clean = entry.lstrip("./")
        if rel.startswith(entry_clean):
            return True
    return False

# ─── grep execution utility ─────────────────────────────────────────────────
def grep_files(term: str, repo_root: str) -> list:
    """
    Search tracked files for term as a fixed string.
    Returns a list of relative paths of matching files.
    """
    try:
        result = subprocess.run(
            ["git", "grep", "-l", "-F", "--", term, "."],
            cwd=repo_root,
            capture_output=True,
            text=True,
        )
        if result.returncode in (0, 1):
            return [f.strip() for f in result.stdout.splitlines() if f.strip()]
    except Exception:
        pass

    # Fallback for non-git checkouts. Keep the same exclusions as the legacy
    # scanner, but the normal repo path above should avoid ignored/local bulk.
    try:
        result = subprocess.run(
            [
                "grep",
                "-rln",
                "-F",
                "--exclude-dir=.git",
                "--exclude-dir=.agents",
                term,
                ".",
            ],
            cwd=repo_root,
            capture_output=True,
            text=True,
        )
        if result.returncode in (0, 1):
            return [f.strip() for f in result.stdout.splitlines() if f.strip()]
    except Exception as e:
        print(f"  WARNING: grep execution error: {e}", file=sys.stderr)
    return []

def grep_line_numbers(term: str, filepath: str, repo_root: str) -> list:
    """
    Returns line numbers and content of lines in filepath that match term.
    Returns: list of (lineno, line_content)
    """
    try:
        result = subprocess.run(
            ["git", "grep", "-n", "-F", "--", term, filepath],
            cwd=repo_root,
            capture_output=True,
            text=True,
        )
        if result.returncode not in (0, 1):
            result = subprocess.run(
                ["grep", "-n", "-F", term, filepath],
                cwd=repo_root,
                capture_output=True,
                text=True,
            )
        lines = []
        for line in result.stdout.splitlines():
            # git grep: "path:27:content"; grep: "27:content"
            m = re.match(r"^(?:(?:[^:]+):)?(\d+):(.*)$", line)
            if m:
                lines.append((int(m.group(1)), m.group(2).strip()))
        return lines
    except Exception:
        return []

def grep_h1_v3_files(repo_root: str) -> list:
    """
    Search for files whose H1 title in SKILL.md / agents/*.md has a '(v3)' suffix.
    Pattern: lines starting with '# ' that contain '(v3)'.
    Uses grep -rl because grep -rln is not available.
    """
    try:
        result = subprocess.run(
            [
                "git",
                "grep",
                "-l",
                "-E",
                r"^# .*(v3)",
                "--",
                "skills/*/SKILL.md",
                "codex/.codex/skills/*/SKILL.md",
                "opencode/skills/*/SKILL.md",
                "agents/*.md",
            ],
            cwd=repo_root,
            capture_output=True,
            text=True,
        )
        if result.returncode in (0, 1):
            return [f.strip() for f in result.stdout.splitlines() if f.strip()]
    except Exception:
        pass

    try:
        result = subprocess.run(
            [
                "grep",
                "-rln",
                "--include=*.md",
                "--exclude-dir=.git",
                "--exclude-dir=.agents",
                r"^# .*(v3)",
                "skills",
                "codex/.codex/skills",
                "opencode/skills",
                "agents",
            ],
            cwd=repo_root,
            capture_output=True,
            text=True,
        )
        if result.returncode in (0, 1):
            return [f.strip() for f in result.stdout.splitlines() if f.strip()]
    except Exception:
        pass
    return []

# ─── Run scan ─────────────────────────────────────────────────────────────
violations = 0
violation_files = set()

# ── Scan deleted_paths ──
print("[scanning deleted_paths...]")
for entry in deleted_paths:
    path_term = entry["path"]
    allowlist  = entry.get("allowlist", [])
    reason     = entry.get("reason", "")

    # Default allowlist additions (common to all entries)
    default_allowlist = [
        "CHANGELOG.md",
        ".claude/memory/archive/",
        ".claude/worktrees/",
        ".claude/state/",
        "out/",
        "output/",          # diagnostic output / generated artifacts
        "benchmarks/",
        "tests/validate-plugin-v3.sh",  # v3 compatibility test (intentionally retained)
        ".claude/rules/deleted-concepts.yaml",  # this file itself
        "scripts/check-residue.sh",             # the scanner itself
    ]
    effective_allowlist = list(set(allowlist + default_allowlist))

    matched_files = grep_files(path_term, REPO_ROOT)

    # Filter against allowlist
    filtered = [f for f in matched_files if not is_allowlisted(f, effective_allowlist)]

    if filtered:
        violations += len(filtered)
        violation_files.update(filtered)
        print(f"  ✗ {path_term}")
        for f in filtered:
            lines = grep_line_numbers(path_term, f, REPO_ROOT)
            if lines:
                for lineno, content in lines[:3]:  # show up to 3 lines
                    print(f"    {f}:L{lineno} — \"{content}\"")
            else:
                print(f"    {f}")
        print(f"    (matched entry: {path_term}, reason: \"{reason[:60]}...\")" if len(reason) > 60 else f"    (matched entry: {path_term}, reason: \"{reason}\")")
        print()

# ── Scan deleted_concepts ──
print("[scanning deleted_concepts...]")
for entry in deleted_concepts:
    if entry.get("_scan_disabled", False):
        continue

    term       = entry["term"]
    term_ja    = entry.get("term_ja")
    replacement = entry.get("replacement", "")
    reason     = entry.get("reason", "")
    allowlist  = entry.get("allowlist", [])

    default_allowlist = [
        "CHANGELOG.md",
        ".claude/memory/archive/",
        ".claude/worktrees/",
        ".claude/state/",
        "out/",
        "output/",          # diagnostic output / generated artifacts
        "benchmarks/",
        ".claude/rules/deleted-concepts.yaml",  # exclude this file itself
        "scripts/check-residue.sh",             # exclude the scanner itself
        "tests/validate-plugin-v3.sh",          # v3 compatibility test (intentionally retained)
    ]
    effective_allowlist = list(set(allowlist + default_allowlist))

    # Scan with English term
    terms_to_scan = [term]
    if term_ja:
        terms_to_scan.append(term_ja)

    for scan_term in terms_to_scan:
        matched_files = grep_files(scan_term, REPO_ROOT)
        filtered = [f for f in matched_files if not is_allowlisted(f, effective_allowlist)]

        if filtered:
            violations += len(filtered)
            violation_files.update(filtered)
            display_term = scan_term
            display_replacement = f" → {replacement}" if replacement else ""
            print(f"  ✗ \"{display_term}\"")
            for f in filtered:
                lines = grep_line_numbers(scan_term, f, REPO_ROOT)
                if lines:
                    for lineno, content in lines[:3]:
                        print(f"    {f}:L{lineno} — \"{content}\"")
                else:
                    print(f"    {f}")
            print(f"    (matched entry: {display_term}{display_replacement})")
            print()

# ── Scan H1 (v3) suffix (special handling) ──
print("[scanning H1 (v3) suffix in skills/ and agents/...]")
h1_allowlist = [
    "CHANGELOG.md",
    ".claude/memory/archive/",
    ".claude/worktrees/",
    ".claude/state/",
    "out/",
    "output/",
    "benchmarks/",
    ".claude/rules/",  # historical documents inside rules/
    "scripts/check-residue.sh",
    ".claude/rules/deleted-concepts.yaml",
    "tests/validate-plugin-v3.sh",  # v3 compatibility test (intentionally retained)
]

h1_files = grep_h1_v3_files(REPO_ROOT)
h1_filtered = [f for f in h1_files if not is_allowlisted(f, h1_allowlist)]

if h1_filtered:
    violations += len(h1_filtered)
    violation_files.update(h1_filtered)
    print(f"  ✗ H1 title with (v3) suffix")
    for f in h1_filtered:
        # Show the matching line
        try:
            result = subprocess.run(
                ["grep", "-n", r"^# .*(v3)", f],
                cwd=REPO_ROOT,
                capture_output=True,
                text=True,
            )
            for line in result.stdout.splitlines()[:3]:
                m = re.match(r"^(\d+):(.*)$", line)
                if m:
                    print(f"    {f}:L{m.group(1)} — \"{m.group(2).strip()}\"")
        except Exception:
            print(f"    {f}")
    print("    (matched entry: H1 (v3) suffix → remove version suffix from H1 titles)")
    print()

# ─── Summary output ────────────────────────────────────────────────────────────────
elapsed = time.time() - start_time

print("=== Summary ===")
if violations == 0:
    print("  ✓ No migration residue detected")
    print(f"  Scan duration: {elapsed:.1f}s")
    print("  Exit: 0")
    sys.exit(0)
else:
    print(f"  Violations: {violations} (in {len(violation_files)} files)")
    print(f"  Scan duration: {elapsed:.1f}s")
    print("  Exit: 1 (residue detected)")
    sys.exit(1)

PYEOF
