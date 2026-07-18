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

test_windows_native_fast_path() {
  local tmp_dir
  local output
  local exported_signal_output
  local symlink_output
  tmp_dir="$(mktemp -d)"
  mkdir -p "${tmp_dir}/bin" "${tmp_dir}/empty-path" "${tmp_dir}/link-bin"
  cp "${ROOT_DIR}/bin/harness" "${tmp_dir}/bin/harness"
  printf '%s\n' '#!/bin/sh' 'printf "windows-fast:%s\\n" "$*"' > "${tmp_dir}/bin/harness-windows-amd64.exe"
  chmod +x "${tmp_dir}/bin/harness" "${tmp_dir}/bin/harness-windows-amd64.exe"

  output="$(PATH="${tmp_dir}/empty-path" OSTYPE=msys /bin/sh "${tmp_dir}/bin/harness" hook pre-tool 2>/dev/null || true)"
  exported_signal_output="$(
    /usr/bin/env -u OSTYPE PATH="${tmp_dir}/empty-path" MSYSTEM=MINGW64 OS=Windows_NT \
      /bin/sh "${tmp_dir}/bin/harness" hook pre-tool 2>/dev/null || true
  )"
  ln -s "${tmp_dir}/bin/harness" "${tmp_dir}/link-bin/harness"
  printf '%s\n' '#!/bin/sh' 'echo SYMLINK_ADJACENT_EXECUTED' > "${tmp_dir}/link-bin/harness-windows-amd64.exe"
  chmod +x "${tmp_dir}/link-bin/harness-windows-amd64.exe"
  symlink_output="$(
    /usr/bin/env -u OSTYPE MSYSTEM=MINGW64 OS=Windows_NT \
      /bin/sh "${tmp_dir}/link-bin/harness" hook pre-tool 2>/dev/null || true
  )"
  rm -rf "${tmp_dir}"

  if [ "${output}" != "windows-fast:hook pre-tool" ]; then
    fail "Windows shim must exec harness-windows-amd64.exe before spawning discovery helpers (got: ${output:-<empty>})"
  fi
  if [ "${exported_signal_output}" != "windows-fast:hook pre-tool" ]; then
    fail "Windows shim must honor exported Git Bash signals when OSTYPE is not exported (got: ${exported_signal_output:-<empty>})"
  fi
  if [ "${symlink_output}" = "SYMLINK_ADJACENT_EXECUTED" ]; then
    fail "Windows fast path must not trust an executable adjacent to a shim symlink"
  fi
}

test_windows_native_fast_path

grep_file 'mingw\*|msys\*|cygwin\*' "bin/harness" "shim maps Git Bash/MSYS/Cygwin to Windows"
grep_file 'EXT="\.exe"' "bin/harness" "shim appends Windows executable suffix"
grep_file 'harness-\$\{OS\}-\$\{ARCH\}\$\{EXT\}' "bin/harness" "shim resolves suffixed binary"

grep_file '"windows/amd64"' "go/scripts/build-all.sh" "build-all includes Windows amd64"
grep_file '\.exe' "go/scripts/build-all.sh" "build-all emits Windows .exe artifact"

grep_file 'filepath\.Join\([A-Za-z]+, "\.claude", "state"\)' "go/internal/hookhandler/worktree_create.go" "WorktreeCreate uses platform path joining"
grep_file 'looksLikeHookDecisionJSON' "go/internal/hookhandler/worktree_create.go" "WorktreeCreate rejects hook decision JSON as cwd"
grep_file '//go:build windows' "go/internal/hookhandler/file_lock_windows.go" "Windows build has a file-lock fallback"
grep_file 'file lock unsupported on windows' "go/internal/hookhandler/file_lock_windows.go" "Windows build avoids syscall.Flock"

echo "PASS: Windows worktree support checks passed"
