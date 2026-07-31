#!/bin/bash
# BSD (macOS) mktemp only randomizes trailing X's. A template like
# /tmp/foo-XXXXXX.json (X's followed by a non-X suffix, e.g. an extension)
# is returned literally by BSD mktemp instead of being randomized, so a
# leftover file from a previous run causes every subsequent call to fail
# with EEXIST forever. GNU mktemp (Linux/CI) randomizes non-trailing X runs
# too, so this class of bug is invisible in CI and only bites on macOS.
#
# This test scans scripts/ tests/ hooks/ go/ for mktemp templates whose
# last run of X's is followed by extra characters, and fails if any exist.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT" || exit 1

VIOLATIONS="$(grep -rnE 'mktemp' --include="*.sh" scripts/ tests/ hooks/ go/ 2>/dev/null \
  | grep -vE '^\S+: *#' \
  | perl -ne '
    ($loc,$body) = /^([^:]+:\d+):(.*)$/ or next;
    while ($body =~ /mktemp((?:\s+-[a-zA-Z]+)*)\s+("([^"]*)"|([^\s;)|&]+))/g) {
      $tpl = defined $3 ? $3 : $4;
      next unless $tpl =~ /XX/;
      if ($tpl =~ /X([^X]+)$/) { print "$loc  $tpl\n"; }
    }
  ')"

if [ -z "$VIOLATIONS" ]; then
    echo "OK: no mktemp templates with a non-X suffix after the last X run"
    exit 0
else
    echo "FAIL: mktemp templates found where BSD mktemp will NOT randomize (trailing chars after last X):"
    echo "$VIOLATIONS"
    echo ""
    echo "Fix: use \"\${TMPDIR:-/tmp}/<name>.XXXXXX\" (X's at the very end, no suffix after them)."
    echo "     If a fixed extension is genuinely required by a consumer, use 'mktemp -d' and a"
    echo "     fixed filename inside the directory instead."
    exit 1
fi
