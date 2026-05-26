#!/bin/bash
# fix-symlinks.sh
# Detects broken symlinks / plain-text link projections in Windows environments and auto-repairs them with real copies.
#
# Usage: called from session-init.sh
# Behavior:
#   - Validates harness-* skill mirrors in codex/.codex/skills/ and opencode/skills/
#   - Repairs them with real copies from skills/ (SSOT)
#   - Outputs the number of repaired entries to stdout (JSON format)
#
# Output:
#   {"fixed": N, "checked": M, "details": ["codex/harness-work", ...]}

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

SKILLS_DIR="$PLUGIN_ROOT/skills"

# List of harness skills
HARNESS_SKILLS=("harness-plan" "harness-work" "harness-review" "harness-setup" "harness-release" "harness-sync")

# Mirror targets (skills/ is the SSOT and is excluded from checks)
MIRROR_ROOTS=(
  "codex/.codex/skills"
  "opencode/skills"
)

FIXED=0
CHECKED=0
FIXED_NAMES=()

for mirror_root in "${MIRROR_ROOTS[@]}"; do
  mirror_dir="$PLUGIN_ROOT/$mirror_root"
  [ -d "$mirror_dir" ] || continue

  for skill in "${HARNESS_SKILLS[@]}"; do
    CHECKED=$((CHECKED + 1))
    mirror_path="$mirror_dir/$skill"
    source_path="$SKILLS_DIR/$skill"

    # Skip if source does not exist
    [ -d "$source_path" ] || continue

    # OK: exists as a directory → skip
    if [ -d "$mirror_path" ] && [ ! -L "$mirror_path" ]; then
      continue
    fi

    # Broken plain-text link: exists as a regular file (occurs on Windows git clone)
    if [ -f "$mirror_path" ]; then
      rm -f "$mirror_path"
      cp -r "$source_path" "$mirror_path"
      FIXED=$((FIXED + 1))
      FIXED_NAMES+=("${mirror_root##*/}/$skill")
      continue
    fi

    # Replace symlinks with real copies as well
    if [ -L "$mirror_path" ]; then
      rm -f "$mirror_path"
      cp -r "$source_path" "$mirror_path"
      FIXED=$((FIXED + 1))
      FIXED_NAMES+=("${mirror_root##*/}/$skill")
      continue
    fi

    # Also copy when the path does not exist
    if [ ! -e "$mirror_path" ]; then
      cp -r "$source_path" "$mirror_path"
      FIXED=$((FIXED + 1))
      FIXED_NAMES+=("${mirror_root##*/}/$skill")
    fi
  done
done

# JSON output
NAMES_JSON="[]"
if [ ${#FIXED_NAMES[@]} -gt 0 ]; then
  NAMES_JSON="["
  for i in "${!FIXED_NAMES[@]}"; do
    [ "$i" -gt 0 ] && NAMES_JSON+=","
    NAMES_JSON+="\"${FIXED_NAMES[$i]}\""
  done
  NAMES_JSON+="]"
fi

echo "{\"fixed\":${FIXED},\"checked\":${CHECKED},\"details\":${NAMES_JSON}}"
