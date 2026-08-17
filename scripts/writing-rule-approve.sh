#!/usr/bin/env bash
# writing-rule-approve.sh — approve/reject a pending writing-rule proposal (Phase 135.4)
#
# Usage:
#   writing-rule-approve.sh --id <id> [--reject] [--proposals <path>] [--rules <path>]
#
# Default action approves a pending proposal.jsonl entry: marks it
# status=approved and appends the corresponding writing-rule.v1 record to
# rules.jsonl. --reject marks it status=rejected and never touches rules.jsonl.
#
# This is the ONLY promotion path from proposals.jsonl to rules.jsonl. It is a
# human-run CLI command — nothing in this repo invokes it automatically.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROPOSAL_SCHEMA="${ROOT}/templates/schemas/writing-rule-proposal.v1.json"
RULE_SCHEMA="${ROOT}/templates/schemas/writing-rule.v1.json"
HARNESS_BIN="${ROOT}/bin/harness"

DEFAULT_PROPOSALS="${HOME}/.claude/writing-lint/proposals.jsonl"
DEFAULT_RULES="${HOME}/.claude/writing-lint/rules.jsonl"

id=""
action="approve"
proposals_path="${CLAUDE_WRITING_LINT_PROPOSALS:-$DEFAULT_PROPOSALS}"
rules_path="${CLAUDE_WRITING_LINT_DICT:-$DEFAULT_RULES}"

usage() {
  cat <<'EOF'
Usage:
  writing-rule-approve.sh --id <id> [--reject] [--proposals <path>] [--rules <path>]
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --id) id="${2:-}"; shift 2 ;;
    --reject) action="reject"; shift ;;
    --proposals) proposals_path="${2:-}"; shift 2 ;;
    --rules) rules_path="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *)
      echo "writing-rule-approve.sh: unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$id" ]]; then
  echo "writing-rule-approve.sh: --id is required" >&2
  exit 1
fi

if [[ ! -f "$proposals_path" ]]; then
  echo "writing-rule-approve.sh: proposals file not found: $proposals_path" >&2
  exit 1
fi

python3 - "$PROPOSAL_SCHEMA" "$RULE_SCHEMA" "$proposals_path" "$rules_path" "$id" "$action" "$HARNESS_BIN" <<'PY'
import json
import os
import subprocess
import sys
from datetime import datetime, timezone

proposal_schema_path, rule_schema_path, proposals_path, rules_path, target_id, action, harness_bin_path = sys.argv[1:8]

with open(proposal_schema_path, encoding="utf-8") as f:
    proposal_schema = json.load(f)
with open(rule_schema_path, encoding="utf-8") as f:
    rule_schema = json.load(f)


def validate(data, schema):
    required = set(schema.get("required", []))
    props = schema.get("properties", {})
    if schema.get("additionalProperties") is False:
        extra = set(data.keys()) - set(props.keys())
        if extra:
            raise ValueError(f"additional properties not allowed: {sorted(extra)}")
    for key in required:
        if key not in data:
            raise ValueError(f"missing required property: {key}")


def vet_rule_pattern(rule, harness_bin_path):
    """Fail-closed RE2 compile + type/enum check via `harness writing-rule-vet`.

    validate() above only checks required keys / additionalProperties against
    the JSON schema — it never compiles `pattern`. Python's `re` accepts
    syntax (lookahead/lookbehind, backreferences) that Go's RE2 rejects, so a
    proposal could pass schema validation here yet break every writing-lint
    rule sharing the dictionary once writinglint.ScanText tries to compile it
    at scan time. This is the primary defense against that; the scan-time
    skip-on-compile-failure in ScanText is the fallback.

    The bin/harness shim exits 0 with EMPTY stdout when its platform binary
    is missing (hooks fail-open contract) — so success requires stdout ==
    "ok" exactly, not just returncode == 0, to stay fail-closed when the
    binary cannot be found or run.
    """
    try:
        proc = subprocess.run(
            [harness_bin_path, "writing-rule-vet"],
            input=json.dumps(rule, ensure_ascii=False).encode("utf-8"),
            capture_output=True,
            timeout=10,
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise ValueError(f"writing-rule-vet could not run ({exc}); refusing to promote (fail-closed)")
    stdout = proc.stdout.decode("utf-8", "replace").strip()
    stderr = proc.stderr.decode("utf-8", "replace").strip()
    if proc.returncode != 0 or stdout != "ok":
        detail = stderr or stdout or "no output (missing platform binary?)"
        raise ValueError(f"writing-rule-vet rejected pattern ({detail})")


records = []
with open(proposals_path, encoding="utf-8") as f:
    for raw in f:
        stripped = raw.rstrip("\n")
        if not stripped.strip():
            records.append(stripped)
            continue
        records.append(json.loads(stripped))

target = None
target_idx = None
for idx, rec in enumerate(records):
    if isinstance(rec, dict) and rec.get("id") == target_id:
        target = rec
        target_idx = idx
        break

if target is None:
    print(f"writing-rule-approve.sh: no proposal found with id={target_id}", file=sys.stderr)
    raise SystemExit(1)

if target.get("status") != "pending":
    print(
        f"writing-rule-approve.sh: proposal {target_id} is not pending "
        f"(status={target.get('status')})",
        file=sys.stderr,
    )
    raise SystemExit(1)

# rule の導出・検証・vet は proposals.jsonl の status 更新より先に行う。
# vet reject 後に status=approved で固まると同一 id を再承認できなくなるため、
# 失敗時は status を pending のまま残す (レビュー指摘 2026-08-17)。
rule = None
if action == "approve":
    rule = {
        "id": target["id"],
        "pattern": target["pattern"],
        "good": target["good"],
        "enabled": True,
    }
    if target.get("scenes"):
        rule["scenes"] = target["scenes"]
    if target.get("severity"):
        rule["severity"] = target["severity"]

    try:
        validate(rule, rule_schema)
    except ValueError as exc:
        print(f"writing-rule-approve.sh: derived rule failed schema validation ({exc})", file=sys.stderr)
        raise SystemExit(1)

    try:
        vet_rule_pattern(rule, harness_bin_path)
    except ValueError as exc:
        print(f"writing-rule-approve.sh: {exc}", file=sys.stderr)
        raise SystemExit(1)

new_status = "approved" if action == "approve" else "rejected"
target["status"] = new_status
target["decided_at"] = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

try:
    validate(target, proposal_schema)
except ValueError as exc:
    print(f"writing-rule-approve.sh: updated proposal failed schema validation ({exc})", file=sys.stderr)
    raise SystemExit(1)

records[target_idx] = target

with open(proposals_path, "w", encoding="utf-8") as f:
    for rec in records:
        if isinstance(rec, dict):
            f.write(json.dumps(rec, ensure_ascii=False) + "\n")
        else:
            f.write(rec + "\n")

if action == "approve":
    os.makedirs(os.path.dirname(rules_path) or ".", exist_ok=True)
    with open(rules_path, "a", encoding="utf-8") as f:
        f.write(json.dumps(rule, ensure_ascii=False) + "\n")

    print(f"approved: {target_id} -> {rules_path}")
else:
    print(f"rejected: {target_id}")
PY
