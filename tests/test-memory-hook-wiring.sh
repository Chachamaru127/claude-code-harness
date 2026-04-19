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

  # --- XR-003 / Phase 49: shell 実装の resume-pack 注入 wiring 検証 ---
  # SessionStart[startup|resume] に memory-session-start.sh が入っていること (DoD a の配線)
  jq -e '.hooks.SessionStart[] | select(.matcher | test("(^|\\|)startup($|\\|)")) | .hooks[] | select(.command? | strings | contains("memory-session-start.sh"))' "${hooks_file}" >/dev/null || {
    echo "SessionStart startup is missing memory-session-start.sh (Phase 49) in ${hooks_file}"
    exit 1
  }
  jq -e '.hooks.SessionStart[] | select(.matcher | test("(^|\\|)resume($|\\|)")) | .hooks[] | select(.command? | strings | contains("memory-session-start.sh"))' "${hooks_file}" >/dev/null || {
    echo "SessionStart resume is missing memory-session-start.sh (Phase 49) in ${hooks_file}"
    exit 1
  }

  # UserPromptSubmit に userprompt-inject-policy.sh が入っていること (DoD a の配線)
  jq -e '.hooks.UserPromptSubmit[] | .hooks[] | select(.command? | strings | contains("userprompt-inject-policy.sh"))' "${hooks_file}" >/dev/null || {
    echo "UserPromptSubmit is missing userprompt-inject-policy.sh (Phase 49) in ${hooks_file}"
    exit 1
  }

  # UserPromptSubmit での順序: memory-bridge → userprompt-inject-policy.sh → inject-policy (DoD d: merge 競合しない配列順)
  order_check=$(jq -r '.hooks.UserPromptSubmit[] | select(.matcher=="*") | .hooks | map(.command) | map(
    if test("hook memory-bridge") then "1:memory-bridge"
    elif test("userprompt-inject-policy.sh") then "2:userprompt-inject-policy"
    elif test("hook inject-policy") then "3:inject-policy"
    else empty end
  ) | join(",")' "${hooks_file}")
  [[ "${order_check}" == "1:memory-bridge,2:userprompt-inject-policy,3:inject-policy" ]] || {
    echo "UserPromptSubmit hook order mismatch in ${hooks_file}: got '${order_check}'"
    echo "expected order: memory-bridge → userprompt-inject-policy.sh → inject-policy"
    exit 1
  }
done

# --- DoD (c): harness-mem daemon 不達時 userprompt-inject-policy.sh が silent skip する ---
# 空 stdin / state dir 無しでも exit 0 で JSON を返すこと
SILENT_TMP="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}" "${SILENT_TMP}"' EXIT
silent_out="$(cd "${SILENT_TMP}" && echo '' | bash "${ROOT_DIR}/scripts/userprompt-inject-policy.sh" 2>/dev/null || true)"
# state dir が無いため early exit し空出力になる — 既存 Go hooks と additionalContext merge が競合しない
if [ -n "${silent_out}" ]; then
  # 出力がある場合は valid な JSON schema であること
  echo "${silent_out}" | jq -e '.hookSpecificOutput.hookEventName == "UserPromptSubmit"' >/dev/null || {
    echo "userprompt-inject-policy.sh silent-skip output is not a valid UserPromptSubmit hook JSON"
    echo "output: ${silent_out}"
    exit 1
  }
fi

# state dir ありだが harness-mem daemon 不達（resume pending flag 無し）でも silent skip する
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
| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
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
init_output="$(cd "${TMP_DIR}" && bash "${TMP_DIR}/scripts/session-init.sh")"
init_context="$(printf '%s' "${init_output}" | jq -r '.hookSpecificOutput.additionalContext')"

echo "${init_context}" | grep -q 'Continuity Briefing' || {
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
resume_output="$(cd "${TMP_DIR}" && bash "${TMP_DIR}/scripts/session-resume.sh")"
resume_context="$(printf '%s' "${resume_output}" | jq -r '.hookSpecificOutput.additionalContext')"

echo "${resume_context}" | grep -q 'Continuity Briefing' || {
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
