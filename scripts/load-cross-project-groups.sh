#!/usr/bin/env bash
# load-cross-project-groups.sh
# Phase 65.3.1 - Cross-Project Group + 3-Layer Redaction
#
# Purpose:
#   .claude/rules/cross-project-groups.yaml を読み込み、JSON にパース。
#   schema validation を行い、不正な場合は exit 1。
#
# Usage:
#   load-cross-project-groups.sh                       # 全 groups を JSON 出力
#   load-cross-project-groups.sh --group <name>        # 特定 group の members を JSON array で出力
#   load-cross-project-groups.sh --yaml <path>         # yaml ファイル指定 (test 用、default は SSOT path)
#
# Exit code:
#   0 = success (yaml valid + 出力済み)
#   1 = schema validation failure / group not found / yaml file not found
#   2 = usage error (引数の組み合わせが不正)
#
# Schema: cross-project-group.v1
#   {schema_version: "cross-project-group.v1",
#    groups: [{name: string, members: string[], description?: string}]}
#
# Validation rules (D43 Option α):
#   - schema_version は "cross-project-group.v1" 固定
#   - groups は array (空 OK)
#   - groups[].name は unique かつ非空
#   - groups[].members は array (空 OK)、要素 unique かつ非空 string

set -euo pipefail

usage() {
  cat <<'USAGE' >&2
Usage:
  load-cross-project-groups.sh                       Output all groups as JSON
  load-cross-project-groups.sh --group <name>        Output members of a specific group as a JSON array
  load-cross-project-groups.sh --yaml <path>         Specify yaml file (default: .claude/rules/cross-project-groups.yaml)

Options:
  --group <name>   Specify group name (outputs members array)
  --yaml <path>    Path to yaml file (for testing)
  -h | --help      Show this help

Exit code:
  0 = success
  1 = schema validation failure / group not found / yaml file not found
  2 = usage error
USAGE
  exit 2
}

GROUP=""
YAML_PATH=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --group)  GROUP="${2:-}";  shift 2 ;;
    --yaml)   YAML_PATH="${2:-}"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "ERROR: unknown argument: $1" >&2; usage ;;
  esac
done

# default yaml path = repo root SSOT
if [[ -z "$YAML_PATH" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
  YAML_PATH="${REPO_ROOT}/.claude/rules/cross-project-groups.yaml"
fi

if [[ ! -f "$YAML_PATH" ]]; then
  echo "ERROR: yaml file not found: $YAML_PATH" >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "ERROR: python3 is required but not found" >&2
  exit 1
fi

export YAML_PATH_PY="$YAML_PATH"
export GROUP_FILTER="$GROUP"

exec python3 - <<'PYEOF'
import os
import sys
import json

try:
    import yaml
except ImportError:
    print("ERROR: python3-yaml (PyYAML) is required but not installed", file=sys.stderr)
    sys.exit(1)

YAML_PATH = os.environ["YAML_PATH_PY"]
GROUP_FILTER = os.environ.get("GROUP_FILTER", "")

EXPECTED_SCHEMA = "cross-project-group.v1"

# ---- yaml load ----
try:
    with open(YAML_PATH, "r", encoding="utf-8") as f:
        data = yaml.safe_load(f)
except yaml.YAMLError as e:
    print(f"ERROR: yaml parse failed: {e}", file=sys.stderr)
    sys.exit(1)

if data is None:
    print(f"ERROR: yaml is empty: {YAML_PATH}", file=sys.stderr)
    sys.exit(1)

# ---- schema_version check ----
schema_version = data.get("schema_version")
if schema_version != EXPECTED_SCHEMA:
    print(f"ERROR: schema_version must be '{EXPECTED_SCHEMA}', got: {schema_version!r}", file=sys.stderr)
    sys.exit(1)

# ---- groups check ----
groups = data.get("groups")
if groups is None:
    print("ERROR: 'groups' field is required (use empty array [] for default)", file=sys.stderr)
    sys.exit(1)

if not isinstance(groups, list):
    print(f"ERROR: 'groups' must be a list, got: {type(groups).__name__}", file=sys.stderr)
    sys.exit(1)

# ---- groups[] validation ----
seen_names = set()
for i, g in enumerate(groups):
    if not isinstance(g, dict):
        print(f"ERROR: groups[{i}] must be an object, got: {type(g).__name__}", file=sys.stderr)
        sys.exit(1)

    # name validation
    name = g.get("name")
    if name is None or not isinstance(name, str) or name == "":
        print(f"ERROR: groups[{i}].name must be a non-empty string", file=sys.stderr)
        sys.exit(1)
    if name in seen_names:
        print(f"ERROR: duplicate group name: {name!r}", file=sys.stderr)
        sys.exit(1)
    seen_names.add(name)

    # description validation (optional)
    desc = g.get("description")
    if desc is not None and not isinstance(desc, str):
        print(f"ERROR: groups[{i}].description must be a string if present", file=sys.stderr)
        sys.exit(1)

    # members validation
    members = g.get("members")
    if members is None:
        print(f"ERROR: groups[{i}].members is required (use empty array [] for none)", file=sys.stderr)
        sys.exit(1)
    if not isinstance(members, list):
        print(f"ERROR: groups[{i}].members must be a list", file=sys.stderr)
        sys.exit(1)

    seen_members = set()
    for j, m in enumerate(members):
        if not isinstance(m, str) or m == "":
            print(f"ERROR: groups[{i}].members[{j}] must be a non-empty string", file=sys.stderr)
            sys.exit(1)
        if m in seen_members:
            print(f"ERROR: groups[{i}].members has duplicate: {m!r}", file=sys.stderr)
            sys.exit(1)
        seen_members.add(m)

# ---- output ----
if GROUP_FILTER:
    target = next((g for g in groups if g.get("name") == GROUP_FILTER), None)
    if target is None:
        print(f"ERROR: group not found: {GROUP_FILTER}", file=sys.stderr)
        sys.exit(1)
    print(json.dumps(target.get("members", []), ensure_ascii=False))
else:
    print(json.dumps({"schema_version": schema_version, "groups": groups}, ensure_ascii=False, indent=2))

sys.exit(0)
PYEOF
