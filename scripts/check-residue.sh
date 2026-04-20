#!/usr/bin/env bash
# check-residue.sh — Migration Residue Scanner (Phase 40)
#
# Purpose:
#   .claude/rules/deleted-concepts.yaml を読み込み、
#   削除済みパス・概念がリポジトリ内に残存していないかを検出する。
#   0 件なら exit 0、1 件以上なら exit 1。
#
# Usage:
#   bash scripts/check-residue.sh
#
# Python3 が primary parser として動作する。bash はランチャーに徹する。

set -euo pipefail

# リポジトリルートを特定（スクリプトの位置から相対解決）
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

# bash から exec python3 - で呼ばれる場合、__file__ が使えないため
# 環境変数で渡す代わりに argv[0] から推定する
# ただし heredoc exec の場合は sys.argv[0] == '-' なので getcwd() ベースで解決
if not REPO_ROOT:
    # スクリプトは scripts/ から呼ばれる想定。cwd は任意なので
    # sys.argv に渡ってくる場合は使う。なければ cwd から解決
    REPO_ROOT = os.getcwd()
    # check-residue.sh が scripts/ にあるため、scripts/ が cwd であれば parent に
    if os.path.basename(REPO_ROOT) == "scripts":
        REPO_ROOT = os.path.dirname(REPO_ROOT)

YAML_PATH = os.path.join(REPO_ROOT, ".claude/rules/deleted-concepts.yaml")

start_time = time.time()

# ─── YAML 読み込み ─────────────────────────────────────────────────────────────
if not os.path.exists(YAML_PATH):
    print(f"ERROR: {YAML_PATH} が見つかりません", file=sys.stderr)
    sys.exit(2)

with open(YAML_PATH, "r", encoding="utf-8") as f:
    config = yaml.safe_load(f)

deleted_paths    = config.get("deleted_paths", [])
deleted_concepts = config.get("deleted_concepts", [])

# scan_disabled フラグが立っているエントリはスキップ
deleted_concepts = [c for c in deleted_concepts if not c.get("_scan_disabled", False)]

n_paths    = len(deleted_paths)
n_concepts = len(deleted_concepts)

print("=== Migration Residue Scan ===")
print(f"Loaded: .claude/rules/deleted-concepts.yaml")
print(f"Entries: {n_paths} deleted_paths + {n_concepts} deleted_concepts")
print()

# ─── allowlist 判定 ─────────────────────────────────────────────────────────
def is_allowlisted(filepath: str, allowlist: list) -> bool:
    """
    filepath が allowlist のいずれかのプレフィックスにマッチするか判定。
    allowlist エントリは prefix match。
    filepath はリポジトリルートからの相対パス（./ なし）。
    """
    # ./ を除去して正規化
    rel = filepath.lstrip("./")
    for entry in allowlist:
        entry_clean = entry.lstrip("./")
        if rel.startswith(entry_clean):
            return True
    return False

# ─── grep 実行ユーティリティ ─────────────────────────────────────────────────
def grep_files(term: str, repo_root: str) -> list:
    """
    term を固定文字列として repo_root 以下を grep -rln -F で検索。
    ヒットしたファイルの相対パスリストを返す。
    """
    try:
        result = subprocess.run(
            ["grep", "-rln", "-F",
             "--exclude-dir=.git",
             "--exclude-dir=.agents",
             term, "."],
            cwd=repo_root,
            capture_output=True,
            text=True,
        )
        if result.returncode not in (0, 1):
            # grep のエラー（returncode=2）は無視
            return []
        files = [f.strip() for f in result.stdout.splitlines() if f.strip()]
        return files
    except Exception as e:
        print(f"  WARNING: grep 実行エラー: {e}", file=sys.stderr)
        return []

def grep_line_numbers(term: str, filepath: str, repo_root: str) -> list:
    """
    filepath 内で term がヒットする行番号と行内容を返す。
    Returns: list of (lineno, line_content)
    """
    try:
        result = subprocess.run(
            ["grep", "-n", "-F", term, filepath],
            cwd=repo_root,
            capture_output=True,
            text=True,
        )
        lines = []
        for line in result.stdout.splitlines():
            # 形式: "27:    grep 'core/src/guardrails/rules.ts'"
            m = re.match(r"^(\d+):(.*)$", line)
            if m:
                lines.append((int(m.group(1)), m.group(2).strip()))
        return lines
    except Exception:
        return []

def grep_h1_v3_files(repo_root: str) -> list:
    """
    SKILL.md / agents/*.md の H1 タイトルに '(v3)' サフィックスがあるファイルを検索。
    パターン: 行頭が '# ' で始まり '(v3)' を含む行。
    grep -rln は使えないため grep -rl を使う。
    """
    try:
        result = subprocess.run(
            ["grep", "-rln", "--include=*.md",
             "--exclude-dir=.git",
             "--exclude-dir=.agents",
             r"^# .*(v3)", "."],
            cwd=repo_root,
            capture_output=True,
            text=True,
        )
        if result.returncode not in (0, 1):
            return []
        files = [f.strip() for f in result.stdout.splitlines() if f.strip()]
        return files
    except Exception:
        return []

# ─── スキャン実行 ─────────────────────────────────────────────────────────────
violations = 0
violation_files = set()

# ── deleted_paths のスキャン ──
print("[scanning deleted_paths...]")
for entry in deleted_paths:
    path_term = entry["path"]
    allowlist  = entry.get("allowlist", [])
    reason     = entry.get("reason", "")

    # allowlist にデフォルト追加（全エントリ共通）
    default_allowlist = [
        "CHANGELOG.md",
        ".claude/memory/archive/",
        ".claude/worktrees/",
        ".claude/state/",
        "out/",
        "output/",          # 診断出力・生成物
        "benchmarks/",
        "tests/validate-plugin-v3.sh",  # v3 互換テスト（明示的に残存）
        ".claude/rules/deleted-concepts.yaml",  # 本ファイル自身
        "scripts/check-residue.sh",             # スキャナ自身
    ]
    effective_allowlist = list(set(allowlist + default_allowlist))

    matched_files = grep_files(path_term, REPO_ROOT)

    # allowlist でフィルタ
    filtered = [f for f in matched_files if not is_allowlisted(f, effective_allowlist)]

    if filtered:
        violations += len(filtered)
        violation_files.update(filtered)
        print(f"  ✗ {path_term}")
        for f in filtered:
            lines = grep_line_numbers(path_term, f, REPO_ROOT)
            if lines:
                for lineno, content in lines[:3]:  # 最大 3 行表示
                    print(f"    {f}:L{lineno} — \"{content}\"")
            else:
                print(f"    {f}")
        print(f"    (matched entry: {path_term}, reason: \"{reason[:60]}...\")" if len(reason) > 60 else f"    (matched entry: {path_term}, reason: \"{reason}\")")
        print()

# ── deleted_concepts のスキャン ──
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
        "output/",          # 診断出力・生成物
        "benchmarks/",
        ".claude/rules/deleted-concepts.yaml",  # 本ファイル自身は除外
        "scripts/check-residue.sh",             # スキャナ自身は除外
        "tests/validate-plugin-v3.sh",          # v3 互換テスト（明示的に残存）
    ]
    effective_allowlist = list(set(allowlist + default_allowlist))

    # 英語 term でスキャン
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

# ── H1 (v3) サフィックスのスキャン（特別処理）──
print("[scanning H1 (v3) suffix in skills/ and agents/...]")
h1_allowlist = [
    "CHANGELOG.md",
    ".claude/memory/archive/",
    ".claude/worktrees/",
    ".claude/state/",
    "out/",
    "output/",
    "benchmarks/",
    ".claude/rules/",  # rules/ 内の歴史ドキュメント
    "scripts/check-residue.sh",
    ".claude/rules/deleted-concepts.yaml",
    "tests/validate-plugin-v3.sh",  # v3 互換テスト（明示的に残存）
]

h1_files = grep_h1_v3_files(REPO_ROOT)
h1_filtered = [f for f in h1_files if not is_allowlisted(f, h1_allowlist)]

if h1_filtered:
    violations += len(h1_filtered)
    violation_files.update(h1_filtered)
    print(f"  ✗ H1 title with (v3) suffix")
    for f in h1_filtered:
        # 該当行を表示
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

# ─── サマリ出力 ────────────────────────────────────────────────────────────────
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
