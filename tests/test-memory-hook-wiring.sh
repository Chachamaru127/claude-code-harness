#!/bin/bash
# SessionStart/UserPromptSubmit/PostToolUse/Stop should be wired to harness-mem and
# SessionStart should surface memory resume context immediately.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

required_wrapper_files=(
  "${ROOT_DIR}/scripts/lib/harness-mem-bridge.sh"
  "${ROOT_DIR}/scripts/hook-handlers/memory-bridge.sh"
  "${ROOT_DIR}/scripts/hook-handlers/memory-session-start.sh"
  "${ROOT_DIR}/scripts/hook-handlers/memory-user-prompt.sh"
  "${ROOT_DIR}/scripts/hook-handlers/memory-post-tool-use.sh"
  "${ROOT_DIR}/scripts/hook-handlers/memory-stop.sh"
  "${ROOT_DIR}/scripts/hook-handlers/memory-codex-notify.sh"
)

for wrapper_file in "${required_wrapper_files[@]}"; do
  [ -f "${wrapper_file}" ] || {
    echo "Required harness-mem wrapper is missing: ${wrapper_file}"
    exit 1
  }
done

for hooks_file in "${ROOT_DIR}/hooks/hooks.json" "${ROOT_DIR}/.claude-plugin/hooks.json"; do
  # Matcher checks use strict pipe-token regex to avoid false positives on
  # typos like "startup-only" or "startup_special". The pattern matches
  # "startup" as a standalone token in pipe-separated matchers:
  #   - "startup"              → matches (whole string)
  #   - "startup|resume"       → matches (pipe-delimited token)
  #   - "resume|startup"       → matches (pipe-delimited token, end)
  #   - "startup-only"         → NO match (hyphen breaks boundary)
  jq -e '.hooks.SessionStart[] | select(.matcher | test("(^|\\|)startup($|\\|)")) | .hooks[] | select(.command | contains("memory-bridge"))' "${hooks_file}" >/dev/null || {
    echo "SessionStart startup is missing memory-bridge session-start in ${hooks_file}"
    exit 1
  }

  jq -e '.hooks.SessionStart[] | select(.matcher | test("(^|\\|)resume($|\\|)")) | .hooks[] | select(.command | contains("memory-bridge"))' "${hooks_file}" >/dev/null || {
    echo "SessionStart resume is missing memory-bridge session-start in ${hooks_file}"
    exit 1
  }

  jq -e '.hooks.UserPromptSubmit[] | .hooks[] | select(.command? | strings | contains("memory-bridge"))' "${hooks_file}" >/dev/null || {
    echo "UserPromptSubmit is missing memory-bridge user-prompt in ${hooks_file}"
    exit 1
  }

  jq -e '.hooks.PostToolUse[] | .hooks[] | select(.command? | strings | contains("memory-bridge"))' "${hooks_file}" >/dev/null || {
    echo "PostToolUse is missing memory-bridge post-tool-use in ${hooks_file}"
    exit 1
  }

  jq -e '.hooks.Stop[] | .hooks[] | select(.command? | strings | contains("memory-bridge"))' "${hooks_file}" >/dev/null || {
    echo "Stop is missing memory-bridge stop in ${hooks_file}"
    exit 1
  }

  # --- XR-003 / Phase 49: shell implementation resume-pack injection wiring verification ---
  # memory-session-start.sh must be present in SessionStart[startup|resume] (DoD a wiring)
  jq -e '.hooks.SessionStart[] | select(.matcher | test("(^|\\|)startup($|\\|)")) | .hooks[] | select(.command? | strings | contains("memory-session-start.sh"))' "${hooks_file}" >/dev/null || {
    echo "SessionStart startup is missing memory-session-start.sh (Phase 49) in ${hooks_file}"
    exit 1
  }
  jq -e '.hooks.SessionStart[] | select(.matcher | test("(^|\\|)resume($|\\|)")) | .hooks[] | select(.command? | strings | contains("memory-session-start.sh"))' "${hooks_file}" >/dev/null || {
    echo "SessionStart resume is missing memory-session-start.sh (Phase 49) in ${hooks_file}"
    exit 1
  }

  # userprompt-inject-policy.sh must be present in UserPromptSubmit (DoD a wiring)
  jq -e '.hooks.UserPromptSubmit[] | .hooks[] | select(.command? | strings | contains("userprompt-inject-policy.sh"))' "${hooks_file}" >/dev/null || {
    echo "UserPromptSubmit is missing userprompt-inject-policy.sh (Phase 49) in ${hooks_file}"
    exit 1
  }

  # UserPromptSubmit order: memory-bridge → userprompt-inject-policy.sh
  # The old Go inject-policy could emit the same additionalContext as the shell side,
  # so it is removed from UserPromptSubmit to prevent double injection.
  # Use `.command // ""` for null-safety: even when agent/http-type hooks (without .command) are mixed in,
  # subsequent `test(...)` will not error on null.
  order_check=$(jq -r '.hooks.UserPromptSubmit[] | select(.matcher=="*") | .hooks | map(.command // "") | map(
    if test("hook memory-bridge") then "1:memory-bridge"
    elif test("userprompt-inject-policy.sh") then "2:userprompt-inject-policy"
    else empty end
  ) | join(",")' "${hooks_file}")
  [[ "${order_check}" == "1:memory-bridge,2:userprompt-inject-policy" ]] || {
    echo "UserPromptSubmit hook order mismatch in ${hooks_file}: got '${order_check}'"
    echo "expected order: memory-bridge → userprompt-inject-policy.sh"
    exit 1
  }

  if jq -e '.hooks.UserPromptSubmit[] | .hooks[] | select(.command? | strings | contains("hook inject-policy"))' "${hooks_file}" >/dev/null; then
    echo "UserPromptSubmit still wires hook inject-policy in ${hooks_file}; this can duplicate additionalContext"
    exit 1
  fi
done

# --- Issue #94 Item 4: order_check must not break when agent/http-type hooks (no command field) are present ---
# The old implementation `map(.command)` would null → test() error causing exit 1, but after null-safe fix,
# verify that only command-type hooks are used for order judgment while agent hooks are ignored.
mixed_hooks_file="${TMP_DIR}/hooks-mixed.json"
cat > "${mixed_hooks_file}" <<'EOF'
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "matcher": "*",
        "hooks": [
          {"type": "command", "command": "bash /path/hook memory-bridge"},
          {"type": "agent", "agent": "some-agent"},
          {"type": "command", "command": "bash /path/userprompt-inject-policy.sh"}
        ]
      }
    ]
  }
}
EOF
mixed_order=$(jq -r '.hooks.UserPromptSubmit[] | select(.matcher=="*") | .hooks | map(.command // "") | map(
  if test("hook memory-bridge") then "1:memory-bridge"
  elif test("userprompt-inject-policy.sh") then "2:userprompt-inject-policy"
  else empty end
) | join(",")' "${mixed_hooks_file}")
[[ "${mixed_order}" == "1:memory-bridge,2:userprompt-inject-policy" ]] || {
  echo "mixed-type hook order_check failed (jq may have crashed due to mixed agent-type hooks): got '${mixed_order}'"
  exit 1
}

# --- DoD (c): userprompt-inject-policy.sh silently skips when harness-mem daemon is unreachable ---
# Must return JSON with exit 0 even on empty stdin / missing state dir
SILENT_TMP="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}" "${SILENT_TMP}"' EXIT
silent_out="$(cd "${SILENT_TMP}" && echo '' | bash "${ROOT_DIR}/scripts/userprompt-inject-policy.sh" 2>/dev/null || true)"
# Early exit due to missing state dir produces empty output — no conflict with existing Go hooks additionalContext merge
if [ -n "${silent_out}" ]; then
  # If there is output, it must be a valid JSON schema
  echo "${silent_out}" | jq -e '.hookSpecificOutput.hookEventName == "UserPromptSubmit"' >/dev/null || {
    echo "userprompt-inject-policy.sh silent-skip output is not a valid UserPromptSubmit hook JSON"
    echo "output: ${silent_out}"
    exit 1
  }
fi

# state dir present but harness-mem daemon unreachable (no resume pending flag) should also silent skip
mkdir -p "${SILENT_TMP}/.claude/state"
echo '{"session_id":"test","prompt_seq":0}' > "${SILENT_TMP}/.claude/state/session.json"
no_resume_out="$(cd "${SILENT_TMP}" && echo '{"prompt":"test"}' | bash "${ROOT_DIR}/scripts/userprompt-inject-policy.sh" 2>/dev/null)"
echo "${no_resume_out}" | jq -e '.hookSpecificOutput.hookEventName == "UserPromptSubmit"' >/dev/null || {
  echo "userprompt-inject-policy.sh did not return valid UserPromptSubmit JSON when daemon unreachable"
  echo "output: ${no_resume_out}"
  exit 1
}

mkdir -p "${TMP_DIR}/.claude/state/snapshots"
mkdir -p "${TMP_DIR}/scripts/lib"
git -C "${TMP_DIR}" init -q

cp "${ROOT_DIR}/VERSION" "${TMP_DIR}/VERSION"
cp "${ROOT_DIR}/scripts/session-init.sh" "${TMP_DIR}/scripts/session-init.sh"
cp "${ROOT_DIR}/scripts/session-resume.sh" "${TMP_DIR}/scripts/session-resume.sh"
cp "${ROOT_DIR}/scripts/lib/progress-snapshot.sh" "${TMP_DIR}/scripts/lib/progress-snapshot.sh"

cat > "${TMP_DIR}/Plans.md" <<'EOF'
| Task | Description | DoD | Depends | Status |
|------|-------------|-----|---------|--------|
| 1.0 | sample | done | - | cc:WIP |
EOF

seed_memory_context() {
  cat > "${TMP_DIR}/.claude/state/memory-resume-context.md" <<'EOF'
# Continuity Briefing

## Current Focus
- Continue from the previous session
EOF
  : > "${TMP_DIR}/.claude/state/.memory-resume-pending"
}

seed_memory_context
init_output="$(cd "${TMP_DIR}" && bash "${TMP_DIR}/scripts/session-init.sh" < /dev/null)"
init_context="$(printf '%s' "${init_output}" | jq -r '.hookSpecificOutput.additionalContext')"

grep -q 'Continuity Briefing' <<<"${init_context}" || {
  echo "session-init additionalContext is missing memory continuity briefing"
  exit 1
}

[ ! -f "${TMP_DIR}/.claude/state/memory-resume-context.md" ] || {
  echo "session-init should consume memory-resume-context.md"
  exit 1
}

[ ! -f "${TMP_DIR}/.claude/state/.memory-resume-pending" ] || {
  echo "session-init should clear .memory-resume-pending"
  exit 1
}

seed_memory_context
resume_output="$(cd "${TMP_DIR}" && bash "${TMP_DIR}/scripts/session-resume.sh" < /dev/null)"
resume_context="$(printf '%s' "${resume_output}" | jq -r '.hookSpecificOutput.additionalContext')"

grep -q 'Continuity Briefing' <<<"${resume_context}" || {
  echo "session-resume additionalContext is missing memory continuity briefing"
  exit 1
}

[ ! -f "${TMP_DIR}/.claude/state/memory-resume-context.md" ] || {
  echo "session-resume should consume memory-resume-context.md"
  exit 1
}

[ ! -f "${TMP_DIR}/.claude/state/.memory-resume-pending" ] || {
  echo "session-resume should clear .memory-resume-pending"
  exit 1
}

echo "OK"
