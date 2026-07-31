#!/usr/bin/env bash
# plan-preapproval.sh — validate and reflect plan-time preapprovals.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCHEMA_V1="${ROOT}/templates/schemas/plan-preapproval.v1.json"
SCHEMA_V2="${ROOT}/templates/schemas/plan-preapproval.v2.json"

usage() {
  cat <<'EOF'
Usage:
  plan-preapproval.sh validate <plan-preapprovals.json>
  plan-preapproval.sh apply-secret-allow <project-root> [plan-preapprovals.json]
EOF
}

cmd_validate() {
  local state="${1:-}"
  if [ -z "${state}" ] || [ ! -f "${state}" ]; then
    echo "validate: file not found: ${state:-<missing>}" >&2
    exit 1
  fi
  if [ ! -f "${SCHEMA_V1}" ] || [ ! -f "${SCHEMA_V2}" ]; then
    echo "validate: plan-preapproval schema is missing" >&2
    exit 1
  fi

  python3 - "${state}" "${SCHEMA_V1}" "${SCHEMA_V2}" <<'PY'
from datetime import datetime
import json
import re
import sys

state_path, schema_v1_path, schema_v2_path = sys.argv[1:4]
with open(state_path, encoding="utf-8") as f:
    data = json.load(f)
schema_version = data.get("schema_version") if isinstance(data, dict) else None
schema_paths = {
    "plan-preapproval.v1": schema_v1_path,
    "plan-preapproval.v2": schema_v2_path,
}
schema_path = schema_paths.get(schema_version)
if schema_path is None:
    raise SystemExit(f"unsupported schema_version: {schema_version!r}")
with open(schema_path, encoding="utf-8") as f:
    schema = json.load(f)

try:
    import jsonschema  # type: ignore
except Exception:
    jsonschema = None

if jsonschema is not None:
    jsonschema.validate(
        instance=data,
        schema=schema,
        format_checker=jsonschema.FormatChecker(),
    )
else:
    rfc3339 = re.compile(
        r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?"
        r"(?:Z|[+-]\d{2}:\d{2})$"
    )

    def require_exact_keys(obj, allowed, required, label):
        unknown = set(obj) - allowed
        missing = required - set(obj)
        if unknown:
            raise SystemExit(f"{label} has unknown fields: {sorted(unknown)}")
        if missing:
            raise SystemExit(f"{label} missing fields: {sorted(missing)}")

    def require_nonempty_string(value, label):
        if not isinstance(value, str) or not value:
            raise SystemExit(f"{label} must be a non-empty string")

    def require_rfc3339(value, label):
        require_nonempty_string(value, label)
        if not rfc3339.fullmatch(value):
            raise SystemExit(f"{label} must be RFC3339")
        try:
            datetime.fromisoformat(value.replace("Z", "+00:00"))
        except ValueError as exc:
            raise SystemExit(f"{label} must be RFC3339: {exc}") from exc

    if not isinstance(data, dict):
        raise SystemExit("root must be object")
    require_exact_keys(
        data,
        {"schema_version", "approved_at", "approvals"},
        {"schema_version", "approved_at", "approvals"},
        "root",
    )
    if data["schema_version"] not in schema_paths:
        raise SystemExit("schema_version must be plan-preapproval.v1 or plan-preapproval.v2")
    require_rfc3339(data["approved_at"], "approved_at")
    approvals = data.get("approvals")
    if not isinstance(approvals, list):
        raise SystemExit("approvals must be an array")
    allowed_ops = {"secret-read", "external-send", "destructive"}
    for idx, item in enumerate(approvals):
        if not isinstance(item, dict):
            raise SystemExit(f"approvals[{idx}] must be object")
        allowed = {
            "item", "reason", "scope", "operations", "paths", "commands",
            "targets", "decision", "approved_at", "approved_by",
        }
        required = {"item", "reason", "scope", "operations", "decision", "approved_at"}
        if data["schema_version"] == "plan-preapproval.v2":
            allowed |= {"expires_at", "max_uses", "uses"}
            required.add("expires_at")
        require_exact_keys(item, allowed, required, f"approvals[{idx}]")
        require_nonempty_string(item["item"], f"approvals[{idx}].item")
        require_nonempty_string(item["reason"], f"approvals[{idx}].reason")
        scope = item["scope"]
        if not isinstance(scope, dict):
            raise SystemExit(f"approvals[{idx}].scope must be object")
        require_exact_keys(
            scope,
            {"phase", "task"},
            {"phase", "task"},
            f"approvals[{idx}].scope",
        )
        require_nonempty_string(scope["phase"], f"approvals[{idx}].scope.phase")
        require_nonempty_string(scope["task"], f"approvals[{idx}].scope.task")
        ops = item["operations"]
        if not isinstance(ops, list) or not ops:
            raise SystemExit(f"approvals[{idx}].operations must be non-empty array")
        if len(ops) != len(set(ops)):
            raise SystemExit(f"approvals[{idx}].operations must be unique")
        for op in ops:
            if op not in allowed_ops:
                raise SystemExit(f"approvals[{idx}] invalid operation {op!r}")
        for key in ("paths", "commands", "targets"):
            if key not in item:
                continue
            values = item[key]
            if not isinstance(values, list):
                raise SystemExit(f"approvals[{idx}].{key} must be an array")
            for value in values:
                require_nonempty_string(value, f"approvals[{idx}].{key} value")
        if item["decision"] not in {"approved", "denied"}:
            raise SystemExit(f"approvals[{idx}].decision invalid")
        require_rfc3339(item["approved_at"], f"approvals[{idx}].approved_at")
        if "approved_by" in item:
            require_nonempty_string(item["approved_by"], f"approvals[{idx}].approved_by")
        if not any(k in item for k in ("paths", "commands", "targets")):
            raise SystemExit(f"approvals[{idx}] must include paths, commands, or targets")
        if data["schema_version"] == "plan-preapproval.v2":
            require_rfc3339(item["expires_at"], f"approvals[{idx}].expires_at")
            max_uses = item.get("max_uses", 10)
            uses = item.get("uses", 0)
            if isinstance(max_uses, bool) or not isinstance(max_uses, int) or max_uses < 1:
                raise SystemExit(f"approvals[{idx}].max_uses must be an integer >= 1")
            if isinstance(uses, bool) or not isinstance(uses, int) or uses < 0:
                raise SystemExit(f"approvals[{idx}].uses must be an integer >= 0")
print("OK")
PY
}

cmd_apply_secret_allow() {
  local project_root="${1:-}"
  local state="${2:-}"
  if [ -z "${project_root}" ] || [ ! -d "${project_root}" ]; then
    echo "apply-secret-allow: project root not found: ${project_root:-<missing>}" >&2
    exit 1
  fi
  if [ -z "${state}" ]; then
    state="${project_root}/.claude/state/plan-preapprovals.json"
  fi
  cmd_validate "${state}" >/dev/null

  python3 - "${project_root}" "${state}" <<'PY'
from datetime import datetime, timezone
import json
import os
import sys

project_root, state_path = sys.argv[1], sys.argv[2]
config_path = os.path.join(project_root, ".claude-code-harness.config.json")

with open(state_path, encoding="utf-8") as f:
    state = json.load(f)

active_task_path = os.path.join(project_root, ".claude", "state", "active-task.json")
try:
    with open(active_task_path, encoding="utf-8") as f:
        active_scope = json.load(f)
except FileNotFoundError:
    active_scope = {
        "phase": os.environ.get("HARNESS_ACTIVE_PHASE", "").strip(),
        "task": os.environ.get("HARNESS_ACTIVE_TASK", "").strip(),
    }
except (OSError, json.JSONDecodeError) as exc:
    raise SystemExit(f"apply-secret-allow: active task is unreadable: {exc}") from exc

if (
    not isinstance(active_scope, dict)
    or set(active_scope) != {"phase", "task"}
    or not isinstance(active_scope.get("phase"), str)
    or not isinstance(active_scope.get("task"), str)
    or not active_scope["phase"].strip()
    or not active_scope["task"].strip()
):
    raise SystemExit("apply-secret-allow: active task scope is unavailable")
active_scope = {
    "phase": active_scope["phase"].strip(),
    "task": active_scope["task"].strip(),
}

approved_paths = []
for item in state.get("approvals", []):
    if item.get("decision") != "approved":
        continue
    if item.get("scope") != active_scope:
        continue
    if "secret-read" not in item.get("operations", []):
        continue
    if state.get("schema_version") == "plan-preapproval.v2":
        expires_at = datetime.fromisoformat(item["expires_at"].replace("Z", "+00:00"))
        if expires_at <= datetime.now(timezone.utc):
            continue
        if item.get("uses", 0) >= item.get("max_uses", 10):
            continue
    for path in item.get("paths", []):
        path = str(path).strip()
        if path and path not in ("*", "**", "/"):
            approved_paths.append(path)

if os.path.exists(config_path):
    with open(config_path, encoding="utf-8") as f:
        config = json.load(f)
else:
    config = {}

runtimefloor = config.setdefault("runtimefloor", {})
current = runtimefloor.get("secretAllow", [])
if not isinstance(current, list):
    current = []

merged = []
for path in list(current) + approved_paths:
    if isinstance(path, str) and path and path not in merged:
        merged.append(path)
runtimefloor["secretAllow"] = merged

tmp_path = config_path + ".tmp"
with open(tmp_path, "w", encoding="utf-8") as f:
    json.dump(config, f, ensure_ascii=False, indent=2)
    f.write("\n")
os.replace(tmp_path, config_path)
print(config_path)
PY
}

case "${1:-}" in
  validate)
    shift
    cmd_validate "$@"
    ;;
  apply-secret-allow)
    shift
    cmd_apply_secret_allow "$@"
    ;;
  -h|--help|help|"")
    usage
    ;;
  *)
    echo "unknown command: $1" >&2
    usage >&2
    exit 1
    ;;
esac
