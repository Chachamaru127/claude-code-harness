#!/usr/bin/env bash
# breezing-brief.sh — Brief Composer v0 helpers (Phase 93.3.1)
#
# Subcommands:
#   classify "<args>"   — structured vs free-text (deterministic regex/token parse)
#   validate <card.json>  — brief-card.v1 schema validation
#   confirm <yes|no> <card.json> — dispatch contract (no LLM)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCHEMA="${ROOT}/templates/schemas/brief-card.v1.json"

usage() {
  cat <<'EOF'
Usage:
  breezing-brief.sh classify "<args>"
  breezing-brief.sh validate <card.json>
  breezing-brief.sh confirm <yes|no> <card.json>
  breezing-brief.sh recall <goal-text> [--project P]
EOF
}

cmd_classify() {
  local args="${1-}"
  python3 - "$args" <<'PY'
import re
import sys

args = sys.argv[1] if len(sys.argv) > 1 else ""
text = args.strip()
if not text:
    print("structured")
    raise SystemExit(0)

tokens = text.split()
flags = {
    "--codex",
    "--cursor",
    "--reviewer-only",
    "--no-commit",
    "--no-discuss",
    "--no-review-gate",
    "--auto-mode",
}
range_re = re.compile(r"^[0-9]+(-[0-9]+)?$")
parallel_re = re.compile(r"^[0-9]+$")

i = 0
while i < len(tokens):
    token = tokens[i]
    if token == "--parallel":
        if i + 1 >= len(tokens) or not parallel_re.match(tokens[i + 1]):
            print("free-text")
            raise SystemExit(0)
        i += 2
        continue
    if token in flags:
        i += 1
        continue
    if token == "all":
        i += 1
        continue
    if range_re.match(token):
        i += 1
        continue
    print("free-text")
    raise SystemExit(0)

print("structured")
PY
}

cmd_validate() {
  local card_path="${1:-}"
  if [[ -z "$card_path" || ! -f "$card_path" ]]; then
    echo "validate: file not found: ${card_path:-<missing>}" >&2
    exit 1
  fi
  if [[ ! -f "$SCHEMA" ]]; then
    echo "validate: schema not found: $SCHEMA" >&2
    exit 1
  fi

  python3 - "$card_path" "$SCHEMA" <<'PY'
import json
import sys

card_path, schema_path = sys.argv[1], sys.argv[2]

try:
    with open(card_path, encoding="utf-8") as f:
        data = json.load(f)
except json.JSONDecodeError as exc:
    print(f"invalid JSON: {exc}", file=sys.stderr)
    raise SystemExit(1)

try:
    with open(schema_path, encoding="utf-8") as f:
        schema = json.load(f)
except json.JSONDecodeError as exc:
    print(f"invalid schema JSON: {exc}", file=sys.stderr)
    raise SystemExit(1)

try:
    import jsonschema  # type: ignore

    jsonschema.validate(instance=data, schema=schema)
    raise SystemExit(0)
except ImportError:
    pass
except Exception as exc:
    print(str(exc), file=sys.stderr)
    raise SystemExit(1)


def fail(message: str) -> None:
    print(message, file=sys.stderr)
    raise SystemExit(1)


def validate_card(data, schema):
    if not isinstance(data, dict):
        fail("root must be object")

    required = schema.get("required", [])
    properties = schema.get("properties", {})
    if schema.get("additionalProperties") is False:
        extra = set(data.keys()) - set(properties.keys())
        if extra:
            fail(f"additional properties not allowed: {sorted(extra)}")

    for key in required:
        if key not in data:
            fail(f"missing required property: {key}")

    goal_spec = properties.get("goal", {})
    if not isinstance(data["goal"], str) or (
        goal_spec.get("minLength", 0) and not data["goal"]
    ):
        fail("goal must be a non-empty string")

    subtasks_spec = properties.get("subtasks", {})
    subtasks = data["subtasks"]
    if not isinstance(subtasks, list):
        fail("subtasks must be an array")
    min_items = subtasks_spec.get("minItems")
    max_items = subtasks_spec.get("maxItems")
    if min_items is not None and len(subtasks) < min_items:
        fail(f"subtasks must have at least {min_items} items")
    if max_items is not None and len(subtasks) > max_items:
        fail(f"subtasks must have at most {max_items} items")

    item_spec = subtasks_spec.get("items", {})
    item_required = item_spec.get("required", [])
    item_props = item_spec.get("properties", {})
    for index, item in enumerate(subtasks):
        if not isinstance(item, dict):
            fail(f"subtasks[{index}] must be an object")
        if item_spec.get("additionalProperties") is False:
            extra = set(item.keys()) - set(item_props.keys())
            if extra:
                fail(f"subtasks[{index}] additional properties not allowed: {sorted(extra)}")
        for key in item_required:
            if key not in item:
                fail(f"subtasks[{index}] missing required property: {key}")
        for key in item_required:
            if not isinstance(item[key], str) or not item[key]:
                fail(f"subtasks[{index}].{key} must be a non-empty string")

    for array_key in ("scope_files", "risk_notes"):
        value = data[array_key]
        if not isinstance(value, list):
            fail(f"{array_key} must be an array")
        if not all(isinstance(entry, str) for entry in value):
            fail(f"{array_key} items must be strings")

    confidence_spec = properties.get("confidence", {})
    allowed = confidence_spec.get("enum", [])
    if data["confidence"] not in allowed:
        fail(f"confidence must be one of: {', '.join(allowed)}")


validate_card(data, schema)
PY
}

cmd_recall() {
  local goal_text=""
  local project=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --project)
        project="${2:-}"
        shift 2
        ;;
      *)
        goal_text="$1"
        shift
        ;;
    esac
  done

  if [[ -z "$goal_text" ]]; then
    echo "[]"
    return 0
  fi

  if [[ -z "$project" ]]; then
    project="$(git -C "$ROOT" rev-parse --show-toplevel 2>/dev/null || echo "$ROOT")"
  fi

  "$ROOT/bin/harness" mem search-similar --project "$project" --query "$goal_text" --format json
}

cmd_confirm() {
  local decision="${1:-}"
  local card_path="${2:-}"

  case "$decision" in
    yes|no) ;;
    *)
      echo "confirm: decision must be yes or no" >&2
      exit 1
      ;;
  esac

  if [[ -z "$card_path" || ! -f "$card_path" ]]; then
    echo "confirm: file not found: ${card_path:-<missing>}" >&2
    exit 1
  fi

  if ! cmd_validate "$card_path" >/dev/null 2>&1; then
    echo "confirm: invalid card" >&2
    exit 1
  fi

  if [[ "$decision" == "no" ]]; then
    echo "DISPATCH: 0"
    exit 0
  fi

  python3 - "$card_path" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as f:
    card = json.load(f)
print(f"DISPATCH: {len(card['subtasks'])}")
PY
}

main() {
  local cmd="${1:-}"
  shift || true

  case "$cmd" in
    classify)
      cmd_classify "${1-}"
      ;;
    validate)
      cmd_validate "${1:-}"
      ;;
    confirm)
      cmd_confirm "${1:-}" "${2:-}"
      ;;
    recall)
      cmd_recall "$@"
      ;;
    ""|-h|--help|help)
      usage
      exit 0
      ;;
    *)
      echo "unknown subcommand: $cmd" >&2
      usage
      exit 1
      ;;
  esac
}

main "$@"
