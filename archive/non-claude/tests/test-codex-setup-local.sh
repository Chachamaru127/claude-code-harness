#!/usr/bin/env bash
#
# test-codex-setup-local.sh
# Regression tests for Codex local setup safety.
#
# The setup script must never follow a user-level skill symlink and move files
# out of the Harness source tree while trying to back up an existing install.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "${TMP_ROOT}"' EXIT

run_setup() {
  local home_dir="$1"
  local codex_home="$home_dir/.codex"

  HOME="$home_dir" \
    CODEX_HOME="$codex_home" \
    CLAUDE_PLUGIN_ROOT="$ROOT_DIR" \
    bash "$ROOT_DIR/scripts/codex-setup-local.sh" --user >/tmp/codex-setup-local.$$ 2>&1
}

assert_file() {
  local file="$1"
  if [ ! -f "$file" ]; then
    echo "expected file to exist: $file" >&2
    exit 1
  fi
}

assert_symlink() {
  local path="$1"
  if [ ! -L "$path" ]; then
    echo "expected symlink: $path" >&2
    exit 1
  fi
}

assert_not_symlink() {
  local path="$1"
  if [ -L "$path" ]; then
    echo "expected non-symlink path: $path" >&2
    exit 1
  fi
}

SOURCE_SKILL="$ROOT_DIR/codex/.codex/skills/breezing"
SOURCE_SKILL_FILE="$SOURCE_SKILL/SKILL.md"

assert_file "$SOURCE_SKILL_FILE"

# Case 1: the user skill is a symlink to the current source skill.
# This is already up to date, so setup should preserve the symlink and must not
# recurse into it as if it were a normal directory.
HOME_ONE="$TMP_ROOT/home-source-link"
CODEX_ONE="$HOME_ONE/.codex"
mkdir -p "$CODEX_ONE/skills"
ln -s "$SOURCE_SKILL" "$CODEX_ONE/skills/breezing"

run_setup "$HOME_ONE"

assert_symlink "$CODEX_ONE/skills/breezing"
assert_file "$SOURCE_SKILL_FILE"

# Case 2: the user skill is a symlink to some other local directory.
# Setup should back up the symlink itself, replace it with a real copied skill
# directory, and leave the external symlink target untouched.
HOME_TWO="$TMP_ROOT/home-stale-link"
CODEX_TWO="$HOME_TWO/.codex"
STALE_TARGET="$TMP_ROOT/stale-breezing"
mkdir -p "$CODEX_TWO/skills" "$STALE_TARGET"
printf 'stale skill target\n' > "$STALE_TARGET/SKILL.md"
ln -s "$STALE_TARGET" "$CODEX_TWO/skills/breezing"

run_setup "$HOME_TWO"

assert_not_symlink "$CODEX_TWO/skills/breezing"
assert_file "$CODEX_TWO/skills/breezing/SKILL.md"
assert_file "$STALE_TARGET/SKILL.md"
if ! grep -Fq 'stale skill target' "$STALE_TARGET/SKILL.md"; then
  echo "stale symlink target was modified" >&2
  exit 1
fi

# Case 3: multiple files with the same basename can be backed up in one run.
# Backups are stored in one flat directory, so the script must add a suffix
# instead of overwriting an earlier backup from the same second/process.
HOME_THREE="$TMP_ROOT/home-backup-collision"
CODEX_THREE="$HOME_THREE/.codex"
mkdir -p "$CODEX_THREE/skills/harness-loop" "$CODEX_THREE/skills/harness-plan"
printf 'old harness-loop\n' > "$CODEX_THREE/skills/harness-loop/SKILL.md"
printf 'old harness-plan\n' > "$CODEX_THREE/skills/harness-plan/SKILL.md"

run_setup "$HOME_THREE"

backup_count="$(
  find "$CODEX_THREE/backups/codex-setup-local" -type f -name 'SKILL.md.*' | wc -l | tr -d ' '
)"
if [ "$backup_count" -lt 2 ]; then
  echo "expected at least 2 SKILL.md backups, found $backup_count" >&2
  exit 1
fi

echo "OK"
