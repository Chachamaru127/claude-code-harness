#!/usr/bin/env bash
# Phase 105.2: i18n contract ratchet for go/internal/hookhandler.
#
# The spec i18n contract requires user-facing runtime strings to go through the
# locale resolver (localizedHarnessMessage / resolveHarnessLocale), with English
# as the default and Japanese opt-in.
#
# This gate counts "bare" Japanese string literals — Japanese text in a string
# literal on a line that does NOT go through localizedHarnessMessage and is NOT
# a comment — and fails if any are present.
#
# Exit 0 if count <= baseline, exit 1 if it exceeds the baseline.
# Note: no `set -e` — grep returning 1 (no match) in the counting pipeline is
# expected and must not abort the script.
set -uo pipefail

ROOT="${1:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
HANDLER_DIR="$ROOT/go/internal/hookhandler"

# Phase 106.2: all hookhandler Japanese user-facing text is localized. Never
# raise this baseline to accommodate new debt.
BASELINE=0

if [ ! -d "$HANDLER_DIR" ]; then
  echo "i18n ratchet: hookhandler dir not found ($HANDLER_DIR) — skipping (not-configured)"
  exit 0
fi

# Count Japanese string-literal lines outside a localizedHarnessMessage(...)
# span with an explicit Unicode matcher. The old awk counter treated em dashes
# and box-drawing characters as Japanese under mawk, failing on Instabox.
count=$(python3 "$ROOT/scripts/ci/check_i18n_hookhandler_ratchet.py" "$ROOT") || {
  echo "i18n ratchet: checker failed" >&2
  exit 1
}

if [ "$count" -gt "$BASELINE" ]; then
  echo "❌ i18n ratchet: bare Japanese literals rose to $count (baseline $BASELINE)."
  echo "   New user-facing strings must use localizedHarnessMessage(locale, en, ja)."
  exit 1
fi

if [ "$count" -lt "$BASELINE" ]; then
  echo "✅ i18n ratchet: bare Japanese literals down to $count (baseline $BASELINE) — lower BASELINE in this script."
else
  echo "✅ i18n ratchet: bare Japanese literals at baseline ($count)."
fi
exit 0
