#!/usr/bin/env bash
# diagnose-harness-skill-duplication.sh
# Dry-run inventory of Harness skill origins across Claude/Codex/Cursor paths.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

HOST="all"
PROFILE="clean"
JSON=0
HITS_FILE="$(mktemp)"
trap 'rm -f "$HITS_FILE"' EXIT

usage() {
  cat <<'EOF'
Usage: diagnose-harness-skill-duplication.sh [--host claude|codex|cursor|all] [--profile clean|compatibility] [--json]

Dry-run only. Never deletes or edits user configuration.
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --host)
      HOST="${2:-}"
      shift 2
      ;;
    --profile)
      PROFILE="${2:-}"
      shift 2
      ;;
    --json)
      JSON=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      usage
      exit 2
      ;;
  esac
done

case "$HOST" in
  claude|codex|cursor|all) ;;
  *)
    echo "invalid --host: $HOST" >&2
    exit 2
    ;;
esac

case "$PROFILE" in
  clean|compatibility) ;;
  *)
    echo "invalid --profile: $PROFILE" >&2
    exit 2
    ;;
esac

add_root() {
  local label="$1"
  local path="$2"
  [ -d "$path" ] || return 0
  printf '%s|%s\n' "$label" "$path" >> "$HITS_FILE.roots"
}

: > "$HITS_FILE.roots"
: > "$HITS_FILE"

if [ "$HOST" = "all" ] || [ "$HOST" = "claude" ]; then
  add_root "claude-project" "${ROOT_DIR}/.claude/skills"
  add_root "claude-plugin-ssot" "${ROOT_DIR}/skills"
  add_root "claude-user-skills" "${HOME}/.claude/skills"
  add_root "claude-plugin-cache" "${HOME}/.claude/plugins/cache"
fi

if [ "$HOST" = "all" ] || [ "$HOST" = "codex" ]; then
  add_root "codex-project" "${ROOT_DIR}/codex/.codex/skills"
  add_root "codex-user-skills" "${HOME}/.codex/skills"
  add_root "codex-plugin-cache" "${HOME}/.codex/plugins/cache"
  add_root "agents-user-skills" "${HOME}/.agents/skills"
fi

if [ "$HOST" = "all" ] || [ "$HOST" = "cursor" ]; then
  add_root "cursor-project" "${ROOT_DIR}/.cursor/skills"
  add_root "cursor-plugin-ssot" "${ROOT_DIR}/skills"
  add_root "cursor-agents" "${ROOT_DIR}/.cursor/agents"
  add_root "cursor-user-skills" "${HOME}/.cursor/skills"
  add_root "agents-user-skills" "${HOME}/.agents/skills"
  add_root "claude-compat-for-cursor" "${HOME}/.claude/skills"
  add_root "codex-compat-for-cursor" "${HOME}/.codex/skills"
fi

is_harness_skill_name() {
  case "$1" in
    harness-*|breezing|memory|cx-harness*) return 0 ;;
    *) return 1 ;;
  esac
}

while IFS='|' read -r label path; do
  [ -n "$label" ] || continue
  find "$path" -type f -name 'SKILL.md' 2>/dev/null | while IFS= read -r skill_md; do
    skill_name="$(basename "$(dirname "$skill_md")")"
    if is_harness_skill_name "$skill_name"; then
      printf '%s|%s|%s\n' "$skill_name" "$label" "$skill_md" >> "$HITS_FILE"
    fi
  done
done < "$HITS_FILE.roots"

duplicate_count=0
if [ -s "$HITS_FILE" ]; then
  duplicate_count="$(cut -d'|' -f1 "$HITS_FILE" | sort | uniq -c | awk '$1 > 1 { c++ } END { print c + 0 }')"
fi

recommend_primary() {
  case "$HOST" in
    claude) echo "claude-plugin-ssot or claude-code-harness marketplace plugin" ;;
    codex) echo "codex-project mirror or codex marketplace plugin (choose one route)" ;;
    cursor) echo "cursor-plugin-ssot / generated Cursor dist package" ;;
    all) echo "one primary route per host; see docs/local-harness-environment-cleanup.md" ;;
  esac
}

if [ "$JSON" -eq 1 ]; then
  node - "$HITS_FILE" "$PROFILE" "$HOST" "$duplicate_count" <<'NODE'
const fs = require("fs");
const [hitsPath, profile, host, duplicateCount] = process.argv.slice(2);
const lines = fs.readFileSync(hitsPath, "utf8").trim().split("\n").filter(Boolean);
const skills = new Map();
for (const line of lines) {
  const [name, label, path] = line.split("|");
  if (!skills.has(name)) skills.set(name, []);
  skills.get(name).push({ label, path });
}
const payload = {
  profile,
  host,
  duplicate_skill_count: Number(duplicateCount),
  skills: [...skills.entries()].map(([name, origins]) => ({
    name,
    origin_count: origins.length,
    origins,
  })),
};
console.log(JSON.stringify(payload));
NODE
  exit 0
fi

echo "Harness skill duplication diagnosis (dry-run)"
echo "profile: ${PROFILE}"
echo "host: ${HOST}"
echo "duplicate skill names: ${duplicate_count}"
echo

if [ ! -s "$HITS_FILE" ]; then
  echo "No Harness skill origins found in scanned paths."
  exit 0
fi

cut -d'|' -f1 "$HITS_FILE" | sort -u | while IFS= read -r skill_name; do
  [ -n "$skill_name" ] || continue
  hit_count="$(grep -F "${skill_name}|" "$HITS_FILE" | wc -l | tr -d ' ')"
  echo "skill: ${skill_name} (${hit_count} origins)"
  grep -F "${skill_name}|" "$HITS_FILE" | while IFS='|' read -r _ origin path; do
    echo "  - [${origin}] ${path}"
  done
  if [ "$hit_count" -gt 1 ]; then
    echo "  => duplicate detected"
  fi
  echo
done

echo "Recommended primary route: $(recommend_primary)"
if [ "$PROFILE" = "clean" ]; then
  echo "Clean Mode: archive or disable non-primary origins after manual confirmation."
  echo "Cursor Desktop Claude/Codex import ON can reintroduce duplicates; Harness cannot disable that import automatically."
else
  echo "Compatibility Mode: duplicates may remain visible; use explicit host-specific invocation."
fi

echo
echo "No files were changed. Re-run with --json for machine-readable output."
