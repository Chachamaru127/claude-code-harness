#!/bin/bash
# Regression checks for Windows Breezing worktree support.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

grep_file() {
  local pattern="$1"
  local file="$2"
  local label="$3"
  if ! grep -Eq "$pattern" "${ROOT_DIR}/${file}"; then
    fail "${label}: missing ${pattern} in ${file}"
  fi
}

grep_file 'mingw\*|msys\*|cygwin\*' "bin/harness" "shim maps Git Bash/MSYS/Cygwin to Windows"
grep_file 'EXT="\.exe"' "bin/harness" "shim appends Windows executable suffix"
grep_file 'harness-\$\{OS\}-\$\{ARCH\}\$\{EXT\}' "bin/harness" "shim resolves suffixed binary"

grep_file '"windows/amd64"' "go/scripts/build-all.sh" "build-all includes Windows amd64"
grep_file '\.exe' "go/scripts/build-all.sh" "build-all emits Windows .exe artifact"

grep_file 'filepath\.Join\(cwd, "\.claude", "state"\)' "go/internal/hookhandler/worktree_create.go" "WorktreeCreate uses platform path joining"
grep_file 'looksLikeHookDecisionJSON' "go/internal/hookhandler/worktree_create.go" "WorktreeCreate rejects hook decision JSON as cwd"
grep_file '//go:build windows' "go/internal/hookhandler/file_lock_windows.go" "Windows build has a file-lock fallback"
grep_file 'file lock unsupported on windows' "go/internal/hookhandler/file_lock_windows.go" "Windows build avoids syscall.Flock"

echo "PASS: Windows worktree support checks passed"
