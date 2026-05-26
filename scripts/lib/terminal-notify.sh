#!/bin/bash
# terminal-notify.sh
# Shared helper that builds the `terminalSequence` field for CC 2.1.141+ hook JSON output.
# Opt-in via HARNESS_TERMINAL_NOTIFY env (details: .claude/rules/hooks-2.1.139-plus.md)
#
# Usage: after sourcing, call build_terminal_sequence "<title>" "<body>" to
#        print the OSC sequence string to stdout. Returns empty string when env is unset.
#
# Env: HARNESS_TERMINAL_NOTIFY (optional)
#   unset / "0" : do not output sequence
#   "1" / "bell" : BEL (\x07)
#   "title"     : OSC 0 window title update
#   "osc9"      : OSC 9 macOS / iTerm notification
#   "notify"    : OSC 777 KDE/GNOME desktop notification
#
# Security:
#   - Control characters are stripped from title / body (prevents terminal corruption)
#   - Non-ASCII printable characters are passed through; ESC / BEL / ST etc. are excluded

set -euo pipefail

# Strip control characters (0x00-0x1F, 0x7F)
# Args:
#   $1: input string
# Stdout: string with control characters removed
_terminal_notify_sanitize() {
  # Use tr for safe removal (printf would interpret \xXX sequences)
  printf '%s' "${1:-}" | tr -d '\000-\037\177' 2>/dev/null || true
}

# Build terminal sequence
# Args:
#   $1: title (e.g. "Build complete")
#   $2: body (optional, used only by OSC 777)
# Stdout: constructed sequence string (escaped, JSON-safe)
build_terminal_sequence() {
  local mode="${HARNESS_TERMINAL_NOTIFY:-}"
  local title body
  title="$(_terminal_notify_sanitize "${1:-}")"
  body="$(_terminal_notify_sanitize "${2:-}")"

  # Return empty string when opt-in is not set
  case "${mode}" in
    ''|0) return 0 ;;
  esac

  # bell does not use title, so it fires even when title is empty.
  # All other modes do not generate a sequence when title is empty.
  if [ "${mode}" != "1" ] && [ "${mode}" != "bell" ] && [ -z "${title}" ]; then
    return 0
  fi

  # ESC = \x1b, BEL = \x07, ST = \x1b\\
  local ESC BEL
  ESC=$'\x1b'
  BEL=$'\x07'

  case "${mode}" in
    1|bell)
      printf '%s' "${BEL}"
      ;;
    title)
      printf '%s]0;%s%s' "${ESC}" "${title}" "${BEL}"
      ;;
    osc9)
      printf '%s]9;%s%s' "${ESC}" "${title}" "${BEL}"
      ;;
    notify)
      # OSC 777;notify;title;body
      if [ -n "${body}" ]; then
        printf '%s]777;notify;%s;%s%s' "${ESC}" "${title}" "${body}" "${BEL}"
      else
        printf '%s]777;notify;%s%s' "${ESC}" "${title}" "${BEL}"
      fi
      ;;
    *)
      # Unknown value is a no-op (silent ignore; value range is documented in the rule)
      ;;
  esac
}

# Encode a built sequence into a JSON-safe string
# Uses jq when available; falls back to a minimal \u escape implementation
# Args:
#   $1: sequence (raw bytes)
# Stdout: JSON string literal (without surrounding quotes)
encode_terminal_sequence_json() {
  local seq="${1:-}"
  if [ -z "${seq}" ]; then
    return 0
  fi
  if command -v jq >/dev/null 2>&1; then
    # jq -Rs encodes raw input as a JSON string (with quotes)
    # Output is intended to be used as-is as a JSON value (quotes are kept)
    printf '%s' "${seq}" | jq -Rs . 2>/dev/null || printf '""'
  else
    # Minimal fallback: escape only ESC / BEL
    local out
    out="$(printf '%s' "${seq}" \
      | sed -e 's/\\/\\\\/g' \
            -e 's/"/\\"/g' \
            -e $'s/\x1b/\\\\u001b/g' \
            -e $'s/\x07/\\\\u0007/g')"
    printf '"%s"' "${out}"
  fi
}
